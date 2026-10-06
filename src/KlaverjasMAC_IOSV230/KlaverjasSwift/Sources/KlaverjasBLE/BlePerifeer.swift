@preconcurrency import CoreBluetooth
import KlaverjasKit

/// De kant die zich openstelt: adverteert `UartDienst.dienst` en wacht tot de
/// andere kant verbindt en zich abonneert (B3/B9 uit het bluetooth-plan).
/// Ontvangt via een schrijfactie op `naarPerifeer`, verstuurt via een
/// notificatie op `naarCentraal`. Voldoet aan `DuoLijn`, zodat `DuoUi` niet
/// hoeft te weten dat dit bluetooth is in plaats van de `LusLijn` uit fase 2.
///
/// Een actor voor de eigen toestand (het postvak, de wachters, de bekende
/// karakteristiek): CoreBluetooth roept zijn afgevaardigde aan op zijn eigen
/// wachtrij, niet noodzakelijk dezelfde uitvoeringscontext als waar
/// `stuur(_:)`/`ontvang()` vandaan komen. De afgevaardigde zelf kan geen actor
/// zijn — CoreBluetooth verwacht een `NSObject` — dus is het een dun, gewoon
/// klasje dat elke aanroep meteen doorgeeft aan de actor.
///
/// **Onbewezen zonder hardware.** Deze klasse compileert en volgt de
/// CoreBluetooth-documentatie, maar niets hierin is met een echte verbinding
/// getoetst — dat kan pas met twee toestellen. `RegelBuffer`/`RegelPakketten`
/// eronder zijn dat wel, uitputtend.
public actor BlePerifeer: DuoLijn {
    private var manager: CBPeripheralManager?
    private var afgevaardigde: Afgevaardigde?
    private var naarCentraalKarakteristiek: CBMutableCharacteristic?

    /// Hoeveel bytes er in één pakket passen. Pas bekend zodra de andere kant
    /// zich abonneert (`maximumUpdateValueLength`); tot die tijd een
    /// behoudende standaardwaarde — ruim binnen wat elk toestel aankan, ook
    /// zonder de langere MTU die pas na het verbinden onderhandeld wordt.
    private var maxPakket = 20

    private var leesBuffer = RegelBuffer()
    private var wachtrij: [DuoBericht] = []
    private var wachters: [CheckedContinuation<DuoBericht, Never>] = []

    /// Wacht op `peripheralManagerIsReady(toUpdateSubscribers:)` — zie de
    /// aantekening bij `stuur(_:)`.
    private var zendKlaarWachters: [CheckedContinuation<Void, Never>] = []

    private var statusContinuatie: AsyncStream<DuoStatus>.Continuation?

    public init() {}

    /// Voor het verbindingsscherm (B9: "een duidelijke toestand als de lijn
    /// wegvalt"). Eén afnemer tegelijk: een nieuwe aanroep vervangt de vorige
    /// stroom, die dan stilvalt.
    public func statusStroom() -> AsyncStream<DuoStatus> {
        AsyncStream { continuatie in
            self.statusContinuatie = continuatie
        }
    }

    private func meldStatus(_ status: DuoStatus) {
        statusContinuatie?.yield(status)
    }

    /// Begint met adverteren. Geen effect als er al een `CBPeripheralManager`
    /// loopt — nogmaals aanroepen na een eerdere `start()` doet dus niets.
    public func start() {
        guard manager == nil else { return }
        BleLog.zeg("BlePerifeer: start()")
        meldStatus(.bezig("Openstellen…"))
        let afgevaardigde = Afgevaardigde(actor: self)
        self.afgevaardigde = afgevaardigde
        manager = CBPeripheralManager(delegate: afgevaardigde, queue: nil)
    }

    public func stop() {
        manager?.stopAdvertising()
        manager = nil
        afgevaardigde = nil
        naarCentraalKarakteristiek = nil
    }

    /// `updateValue(_:for:onSubscribedCentrals:)` geeft `false` terug als de
    /// eigen zendwachtrij van CoreBluetooth vol zit — dat pakket is dan
    /// gewoon niet verstuurd, stilzwijgend, zonder foutmelding. Bij een kort
    /// testregeltje (fase 3) paste alles toch in één pakket, dus dit bleef
    /// onopgemerkt; een hele gecomprimeerde stand (fase 5) gaat over meerdere
    /// pakketten, en zonder deze lus ("probeer opnieuw zodra
    /// `peripheralManagerIsReady(toUpdateSubscribers:)` meldt dat er weer
    /// ruimte is") kwam de regel nooit compleet aan de andere kant aan — de
    /// kaarten leken dan simpelweg nooit uitgewisseld.
    public func stuur(_ bericht: DuoBericht) async {
        guard let manager, let karakteristiek = naarCentraalKarakteristiek else {
            // Stil weggaan hielp niet om een verloren verbinding van een tik
            // die zomaar niets deed te onderscheiden — vandaar deze regel.
            BleLog.zeg("kon niet versturen (geen verbinding): \(bericht.regel)")
            return
        }
        for pakket in RegelPakketten.verdeel(bericht.regel, maxPakket: maxPakket) {
            while !manager.updateValue(pakket, for: karakteristiek, onSubscribedCentrals: nil) {
                guard await wachtTotZendKlaar() else {
                    // Kwam er ná een paar seconden nog steeds geen "er is weer
                    // ruimte" van CoreBluetooth? Dan blijven wachten helpt niet
                    // meer — dat bleek op hardware een hele `KjSpel.loop()`
                    // voorgoed te laten hangen (de motor draait op precies deze
                    // taak), met als zichtbaar gevolg dat BEIDE schermen
                    // onbedienbaar werden, niet alleen de verbinding. Beter
                    // hier opgeven met een duidelijke regel dan voor eeuwig
                    // vastzitten op een signaal dat misschien nooit meer komt.
                    BleLog.zeg("verzenden opgegeven na te lang wachten op zendruimte: \(bericht.regel)")
                    return
                }
            }
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
        // `.unknown`/`.resetting` zijn overgangen die vanzelf nog een andere
        // staat opleveren; alleen de blijvende, niet-werkende staten hier
        // als mislukking melden.
        guard toestand == .poweredOff || toestand == .unauthorized || toestand == .unsupported
        else { return }
        meldStatus(.mislukt(toestand.omschrijving))
    }

    fileprivate func klaarOmTeAdverteren() {
        guard let manager else { return }
        BleLog.zeg("dienst opzetten en adverteren")
        let naarPerifeer = CBMutableCharacteristic(
            type: UartDienst.naarPerifeer,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable])
        let naarCentraal = CBMutableCharacteristic(
            type: UartDienst.naarCentraal,
            properties: [.notify],
            value: nil,
            permissions: [])
        naarCentraalKarakteristiek = naarCentraal

        let dienst = CBMutableService(type: UartDienst.dienst, primary: true)
        dienst.characteristics = [naarPerifeer, naarCentraal]
        manager.add(dienst)

        manager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [UartDienst.dienst]])
    }

    fileprivate func ontvangenSchrijven(_ data: Data) {
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

    fileprivate func abonneeGevonden(maxPakket: Int) {
        BleLog.zeg("de andere kant abonneerde zich (pakketgrootte \(maxPakket))")
        // Nooit kleiner maken dan de standaardwaarde: een tweede, kleinere
        // waarde (bijvoorbeeld van een tweede abonnee) mag een al ruimere
        // pakketgrootte niet weer inperken.
        self.maxPakket = max(self.maxPakket, maxPakket)
        meldStatus(.verbonden)
    }

    /// De tegenpartij liet de verbinding los (uitgezet, buiten bereik, app
    /// dicht) — zonder dit hoorde de gastheer een weggevallen verbinding
    /// nooit: `BleCentraal` heeft `didDisconnectPeripheral` al, maar de
    /// gastheer-kant miste zijn tegenhanger. `stuur(_:)` viel daardoor stil
    /// zonder ooit "geen verbinding" te melden, en `SpelModel` — dat via
    /// `statusStroom()` meeluistert (zie daar) — kreeg nooit een `.mislukt`
    /// om op te reageren, dus bleef `inSamenspel` voor altijd waar staan
    /// (Ed: "de knop Nieuw spel is nu verdwenen").
    fileprivate func abonneeVerloren() {
        BleLog.zeg("de andere kant liet de verbinding los")
        naarCentraalKarakteristiek = nil
        meldStatus(.mislukt("verbinding verloren"))
    }

    fileprivate func melding(_ omschrijving: String) {
        BleLog.zeg(omschrijving)
        meldStatus(.mislukt(omschrijving))
    }

    /// Puur doorgeefluik naar de actor. Elke methode haalt eerst alles op wat
    /// hij nodig heeft — nooit CoreBluetooth-objecten zelf, die zijn niet
    /// `Sendable` — en geeft dan pure waarden door via een taak, want
    /// CoreBluetooth roept deze synchroon aan en de actor is alleen via
    /// `await` te bereiken. `actor` eerst in een eigen `let` vangen: anders
    /// vangt de taak stilzwijgend deze hele afgevaardigde (ook niet
    /// `Sendable`) om er telkens opnieuw bij te kunnen.
    private final class Afgevaardigde: NSObject, CBPeripheralManagerDelegate {
        weak var actor: BlePerifeer?

        init(actor: BlePerifeer) { self.actor = actor }

        func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
            // Vooral déze regel loggen: bij een simulator, uitstaande
            // bluetooth, of een geweigerd recht komt hier nooit meer dan dit
            // uit, en zonder log lijkt de app dan gewoon niets te doen.
            guard let actor else { return }
            let toestand = peripheral.state
            Task { await actor.staatGewijzigd(toestand) }
            guard toestand == .poweredOn else { return }
            Task { await actor.klaarOmTeAdverteren() }
        }

        func peripheralManager(_ peripheral: CBPeripheralManager,
                                didAdd service: CBService, error: Error?) {
            guard let actor else { return }
            if let error {
                Task { await actor.melding("dienst toevoegen mislukt: \(error.localizedDescription)") }
            } else {
                BleLog.zeg("dienst toegevoegd")
            }
        }

        func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
            guard let actor else { return }
            if let error {
                Task { await actor.melding("adverteren mislukt: \(error.localizedDescription)") }
            } else {
                BleLog.zeg("adverteren gestart")
            }
        }

        func peripheralManager(_ peripheral: CBPeripheralManager,
                                didReceiveWrite requests: [CBATTRequest]) {
            if let actor {
                let waarden = requests.compactMap(\.value)
                Task { for waarde in waarden { await actor.ontvangenSchrijven(waarde) } }
            }
            // Precies één keer beantwoorden per aanroep, niet per verzoek in
            // de rij — CoreBluetooth crasht bij een tweede `respond(to:...)`.
            if let eerste = requests.first {
                peripheral.respond(to: eerste, withResult: .success)
            }
        }

        func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                                didSubscribeTo characteristic: CBCharacteristic) {
            guard let actor else { return }
            let maxPakket = central.maximumUpdateValueLength
            Task { await actor.abonneeGevonden(maxPakket: maxPakket) }
        }

        func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                                didUnsubscribeFrom characteristic: CBCharacteristic) {
            guard let actor else { return }
            Task { await actor.abonneeVerloren() }
        }

        /// CoreBluetooth heeft weer ruimte in zijn zendwachtrij — zie de
        /// aantekening bij `stuur(_:)`.
        func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
            guard let actor else { return }
            Task { await actor.zendKlaar() }
        }
    }
}
