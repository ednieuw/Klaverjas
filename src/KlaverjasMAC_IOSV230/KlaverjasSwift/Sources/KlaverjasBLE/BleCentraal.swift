@preconcurrency import CoreBluetooth
import KlaverjasKit

/// De kant die zoekt: scant naar `UartDienst.dienst`, verbindt met de eerste
/// die hij vindt, en zoekt de twee karakteristieken op (B3/B9 uit het
/// bluetooth-plan). Schrijft naar `naarPerifeer`, luistert op `naarCentraal`.
/// Voldoet aan `DuoLijn`, net als `BlePerifeer` aan de andere kant.
///
/// Zelfde opzet als `BlePerifeer`: een actor voor de eigen toestand, en een
/// dun `NSObject`-klasje ervoor dat CoreBluetooth's aanroepen doorgeeft — met
/// alleen pure waarden de taak in, nooit CoreBluetooth-objecten zelf.
///
/// **Onbewezen zonder hardware**, net als `BlePerifeer` — zie de aantekening
/// daar.
public actor BleCentraal: DuoLijn {
    private var manager: CBCentralManager?
    private var afgevaardigde: Afgevaardigde?
    private var perifeer: CBPeripheral?
    private var naarPerifeerKarakteristiek: CBCharacteristic?

    /// Zie de gelijknamige eigenschap in `BlePerifeer`.
    private var maxPakket = 20

    private var leesBuffer = RegelBuffer()
    private var wachtrij: [DuoBericht] = []
    private var wachters: [CheckedContinuation<DuoBericht, Never>] = []

    /// Wacht op `peripheralIsReady(toSendWriteWithoutResponse:)` — zie de
    /// aantekening bij `stuur(_:)`.
    private var zendKlaarWachters: [CheckedContinuation<Void, Never>] = []

    private var statusContinuatie: AsyncStream<DuoStatus>.Continuation?

    public init() {}

    /// Voor het verbindingsscherm — zie de gelijknamige methode in
    /// `BlePerifeer`.
    public func statusStroom() -> AsyncStream<DuoStatus> {
        AsyncStream { continuatie in
            self.statusContinuatie = continuatie
        }
    }

    private func meldStatus(_ status: DuoStatus) {
        statusContinuatie?.yield(status)
    }

    /// Begint met scannen. Geen effect als er al een `CBCentralManager`
    /// loopt.
    public func start() {
        guard manager == nil else { return }
        BleLog.zeg("BleCentraal: start()")
        meldStatus(.bezig("Zoeken…"))
        let afgevaardigde = Afgevaardigde(actor: self)
        self.afgevaardigde = afgevaardigde
        manager = CBCentralManager(delegate: afgevaardigde, queue: nil)
    }

    public func stop() {
        if let perifeer, let manager { manager.cancelPeripheralConnection(perifeer) }
        manager?.stopScan()
        manager = nil
        afgevaardigde = nil
        perifeer = nil
        naarPerifeerKarakteristiek = nil
    }

    /// `canSendWriteWithoutResponse` kan `false` worden zodra CoreBluetooth's
    /// eigen zendwachtrij vol zit — een `writeValue(..., type: .withoutResponse)`
    /// daarna wordt dan stilzwijgend niets, zonder foutmelding. Bij een kort
    /// testregeltje (fase 3) paste alles toch in één pakket, dus dit bleef
    /// onopgemerkt; een hele gecomprimeerde stand (fase 5) gaat over meerdere
    /// pakketten, en zonder deze controle — wachten op
    /// `peripheralIsReady(toSendWriteWithoutResponse:)` zodra er geen ruimte
    /// is — kwam de regel nooit compleet aan de andere kant aan.
    public func stuur(_ bericht: DuoBericht) async {
        guard let perifeer, let karakteristiek = naarPerifeerKarakteristiek else {
            // Stil weggaan hielp niet om een verloren verbinding van een tik
            // die zomaar niets deed te onderscheiden — vandaar deze regel.
            BleLog.zeg("kon niet versturen (geen verbinding): \(bericht.regel)")
            return
        }
        for pakket in RegelPakketten.verdeel(bericht.regel, maxPakket: maxPakket) {
            while !perifeer.canSendWriteWithoutResponse {
                guard await wachtTotZendKlaar() else {
                    // Zie de aantekening bij `BlePerifeer.stuur(_:)`: zonder
                    // een grens hieraan kon dit de hele `KjSpel.loop()` voor
                    // eeuwig laten hangen — met als gevolg dat BEIDE schermen
                    // onbedienbaar werden, niet alleen de verbinding.
                    BleLog.zeg("verzenden opgegeven na te lang wachten op zendruimte: \(bericht.regel)")
                    return
                }
            }
            perifeer.writeValue(pakket, for: karakteristiek, type: .withoutResponse)
        }
        BleLog.zeg("verstuurd: \(bericht.regel)")
    }

    /// `true` zodra CoreBluetooth meldt dat er weer ruimte is; `false` als dat
    /// niet binnen een redelijke tijd gebeurt. Zie de aantekening bij `stuur(_:)`.
    private func wachtTotZendKlaar() async -> Bool {
        await withTaskGroup(of: Bool.self) { groep in
            groep.addTask { [weak self] in
                guard let self else { return false }
                return await self.wachtOpZendSignaal()
            }
            groep.addTask {
                try? await Task.sleep(for: .seconds(5))
                return false
            }
            let eerste = await groep.next() ?? false
            groep.cancelAll()
            return eerste
        }
    }

    private func wachtOpZendSignaal() async -> Bool {
        await withCheckedContinuation { c in zendKlaarWachters.append(c) }
        return true
    }

    fileprivate func zendKlaar() {
        let wachters = zendKlaarWachters
        zendKlaarWachters = []
        for wachter in wachters { wachter.resume() }
    }

    public func ontvang() async -> DuoBericht {
        if !wachtrij.isEmpty { return wachtrij.removeFirst() }
        return await withCheckedContinuation { c in wachters.append(c) }
    }

    // ------------------------------------------------- vanaf de afgevaardigde

    fileprivate func staatGewijzigd(_ toestand: CBManagerState) {
        BleLog.zeg("staat: \(toestand.omschrijving)")
        guard toestand != .poweredOn else { return }
        guard toestand == .poweredOff || toestand == .unauthorized || toestand == .unsupported
        else { return }
        meldStatus(.mislukt(toestand.omschrijving))
    }

    fileprivate func begonMetScannen(_ manager: CBCentralManager) {
        BleLog.zeg("scannen naar \(UartDienst.dienst)")
        manager.scanForPeripherals(withServices: [UartDienst.dienst])
    }

    fileprivate func gevonden(_ ontdekt: CBPeripheral) {
        // De eerste die gevonden wordt, telt: er wordt met precies twee
        // toestellen gespeeld, dus er hoeft niet gekozen te worden. Het
        // `delegate` staat al gezet, synchroon in de aanroep hiervoor — dat
        // hoort niet bij actor-beschermde toestand en zou een niet-`Sendable`
        // waarde de taak in smokkelen.
        guard perifeer == nil else { return }
        BleLog.zeg("gevonden: \(ontdekt.name ?? "naamloos"), verbinden…")
        meldStatus(.bezig("Gevonden, verbinden…"))
        perifeer = ontdekt
        manager?.stopScan()
        manager?.connect(ontdekt)
    }

    fileprivate func verbonden() {
        BleLog.zeg("verbonden, diensten opzoeken")
        perifeer?.discoverServices([UartDienst.dienst])
    }

    fileprivate func verbindenMislukt(_ fout: Error?) {
        let omschrijving = fout?.localizedDescription ?? "onbekende reden"
        BleLog.zeg("verbinden mislukt: \(omschrijving)")
        perifeer = nil
        meldStatus(.mislukt(omschrijving))
    }

    fileprivate func verbindingVerloren(_ fout: Error?) {
        let omschrijving = fout?.localizedDescription ?? "geen foutmelding"
        BleLog.zeg("verbinding verloren: \(omschrijving)")
        perifeer = nil
        naarPerifeerKarakteristiek = nil
        meldStatus(.mislukt(fout == nil ? "verbinding verloren" : omschrijving))
    }

    fileprivate func dienstGevonden(_ dienst: CBService) {
        BleLog.zeg("dienst gevonden, karakteristieken opzoeken")
        perifeer?.discoverCharacteristics([UartDienst.naarPerifeer, UartDienst.naarCentraal],
                                          for: dienst)
    }

    fileprivate func schrijfKarakteristiekGevonden(_ karakteristiek: CBCharacteristic,
                                                   maxSchrijfPakket: Int) {
        BleLog.zeg("schrijfkarakteristiek gevonden (pakketgrootte \(maxSchrijfPakket))")
        naarPerifeerKarakteristiek = karakteristiek
        maxPakket = max(maxPakket, maxSchrijfPakket)
        meldStatus(.verbonden)
    }

    fileprivate func ontvangenNotificatie(_ data: Data) {
        for regel in leesBuffer.neem(data) {
            guard let bericht = DuoBericht(regel: regel) else {
                BleLog.zeg("onherkenbare regel binnengekregen: \"\(regel)\"")
                continue
            }
            BleLog.zeg("ontvangen: \(bericht.regel)")
            if !wachters.isEmpty {
                wachters.removeFirst().resume(returning: bericht)
            } else {
                wachtrij.append(bericht)
            }
        }
    }

    /// Puur doorgeefluik naar de actor — zie de aantekening bij
    /// `BlePerifeer.Afgevaardigde`. Ook `CBPeripheralDelegate`: dat hoort
    /// bij de verbinding met het gevonden toestel, niet bij het scannen zelf,
    /// maar er is verder toch maar één afgevaardigde nodig.
    private final class Afgevaardigde: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
        weak var actor: BleCentraal?

        init(actor: BleCentraal) { self.actor = actor }

        func centralManagerDidUpdateState(_ central: CBCentralManager) {
            // Vooral déze regel loggen: bij een simulator, uitstaande
            // bluetooth, of een geweigerd recht komt hier nooit meer dan dit
            // uit, en zonder log lijkt de app dan gewoon niets te doen.
            guard let actor else { return }
            let toestand = central.state
            Task { await actor.staatGewijzigd(toestand) }
            guard toestand == .poweredOn else { return }
            Task { await actor.begonMetScannen(central) }
        }

        func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                            advertisementData: [String: Any], rssi RSSI: NSNumber) {
            BleLog.zeg("iets gevonden: \(peripheral.name ?? "naamloos") (rssi \(RSSI))")
            guard let actor else { return }
            peripheral.delegate = self
            Task { await actor.gevonden(peripheral) }
        }

        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            guard let actor else { return }
            Task { await actor.verbonden() }
        }

        func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                            error: Error?) {
            guard let actor else { return }
            Task { await actor.verbindenMislukt(error) }
        }

        func centralManager(_ central: CBCentralManager,
                            didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
            guard let actor else { return }
            Task { await actor.verbindingVerloren(error) }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            if let error { BleLog.zeg("diensten opzoeken mislukt: \(error)") }
            guard let actor, error == nil,
                  let dienst = peripheral.services?.first(where: { $0.uuid == UartDienst.dienst })
            else { return }
            Task { await actor.dienstGevonden(dienst) }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                        error: Error?) {
            if let error { BleLog.zeg("karakteristieken opzoeken mislukt: \(error)") }
            guard let actor, error == nil, let karakteristieken = service.characteristics
            else { return }
            // `setNotifyValue` is een gewone CoreBluetooth-aanroep, geen
            // actor-beschermde toestand — die kan meteen hier, synchroon.
            // Alleen de schrijfkarakteristiek zelf gaat de actor in, en dat
            // ook maar één voor één: een hele rij `[CBCharacteristic]` in
            // één keer doorgeven is niet `Sendable`, ook niet preconcurrency.
            let maxSchrijfPakket = peripheral.maximumWriteValueLength(for: .withoutResponse)
            for karakteristiek in karakteristieken {
                if karakteristiek.uuid == UartDienst.naarCentraal {
                    peripheral.setNotifyValue(true, for: karakteristiek)
                } else if karakteristiek.uuid == UartDienst.naarPerifeer {
                    Task {
                        await actor.schrijfKarakteristiekGevonden(karakteristiek,
                                                                  maxSchrijfPakket: maxSchrijfPakket)
                    }
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                        error: Error?) {
            if let error { BleLog.zeg("notificatie kwam met een fout: \(error)") }
            guard let actor, error == nil, characteristic.uuid == UartDienst.naarCentraal,
                  let waarde = characteristic.value
            else { return }
            Task { await actor.ontvangenNotificatie(waarde) }
        }

        /// CoreBluetooth heeft weer ruimte in zijn zendwachtrij — zie de
        /// aantekening bij `stuur(_:)`.
        func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
            guard let actor else { return }
            Task { await actor.zendKlaar() }
        }

        /// Zonder deze — optionele — methode klaagt CoreBluetooth in de
        /// console dat de afgevaardigde hem niet implementeert. Komt in de
        /// praktijk hier niet voor (geen vaste, andere verbinding die zijn
        /// diensten zou wijzigen); alleen loggen is dus genoeg.
        func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
            BleLog.zeg("diensten van de andere kant zijn gewijzigd")
        }
    }
}
