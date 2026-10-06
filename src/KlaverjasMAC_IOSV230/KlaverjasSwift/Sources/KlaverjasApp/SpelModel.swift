import Foundation
import Observation
import KlaverjasKit
import KlaverjasBLE

/// Waar het scherm op dit moment op wacht.
public enum Modus: Sendable, Equatable {
    case wachten      // de computer is aan zet
    case kiesKaart    // de speler moet een kaart aanklikken
    case kiesTroef    // de speler moet een troefkleur kiezen
    case verder       // klik of toets om door te gaan
}

/// Een doosje voor de menuschakelaars dat vanaf twee kanten benaderd wordt: het
/// scherm schrijft erin, de speeltaak leest eruit. Een slot is hier genoeg —
/// het gaat om twee jaknikkers.
final class Schakelaars: @unchecked Sendable {
    private let slot = NSLock()
    private var waarde = Instellingen()

    var huidig: Instellingen {
        get { slot.lock(); defer { slot.unlock() }; return waarde }
        set { slot.lock(); waarde = newValue; slot.unlock() }
    }
}

/// Wat de brug moet weten zonder naar de hoofdtaak te springen: of er snel
/// gespeeld wordt, en wanneer er voor het laatst getekend is.
///
/// Zonder dit vraagt de brug bij elke gelegde kaart twee keer iets aan het model,
/// en dat is een sprong naar de hoofdtaak. Bij snel spelen zijn dat er duizenden
/// per seconde, en dan gaat alle tijd naar het overleg in plaats van naar het
/// spel — de knop Stoppen reageert dan niet eens meer.
final class Tempo: @unchecked Sendable {
    private let slot = NSLock()
    private var snel = false
    private var laatst = ContinuousClock.now

    /// Hooguit vier keer per seconde tekenen, net als de Windows-versie doet.
    static let tekenpauze = Duration.milliseconds(250)

    var snelSpelen: Bool {
        get { slot.lock(); defer { slot.unlock() }; return snel }
        set { slot.lock(); snel = newValue; laatst = .now - Tempo.tekenpauze; slot.unlock() }
    }

    /// Hoort er na deze kaart een kijkpauze te komen? Bij snel spelen niet:
    /// er valt niets te volgen en het zou het spelen alleen ophouden.
    func magPauzeren() -> Bool { !snelSpelen }

    /// Mag er nu getekend worden? Buiten snel spelen altijd.
    func magTekenen() -> Bool {
        slot.lock()
        defer { slot.unlock() }
        if !snel { return true }
        let nu = ContinuousClock.now
        guard nu - laatst >= Tempo.tekenpauze else { return false }
        laatst = nu
        return true
    }
}

/// Het scherm praat met de speellogica via dit model. De speelloop draait op een
/// eigen taak en vraagt hier om invoer; het model zet die vraag om in iets wat
/// het scherm kan tonen, en wacht met een continuation tot er geklikt wordt.
/// `ObservableObject` en niet het nieuwere `@Observable`: dat laatste vraagt
/// iOS 17, en deze app draait vanaf iOS 16. Voor het scherm maakt het niets uit —
/// alleen de views moeten het model als `@StateObject` of `@ObservedObject`
/// vasthouden in plaats van als gewone eigenschap.
@MainActor
public final class SpelModel: ObservableObject {
    @Published public private(set) var view = SpelView()
    @Published public private(set) var modus: Modus = .wachten
    @Published public private(set) var tekst = ""

    /// Automatisch doorgaan na elke slag, zonder klikken.
    @Published public var automatisch = false

    /// Hoe lang een gelegde kaart blijft staan voordat de volgende volgt, als
    /// de computer beide kanten speelt. Zonder die pauze verschijnen alle vier
    /// de kaarten van een slag tegelijk en valt er niets te volgen.
    public static let demoPauze = Duration.milliseconds(450)

    /// Zoveel spellen achter elkaar en niet meer. Bij snel spelen haalt de
    /// computer er duizenden per minuut, en dan lopen de tellers een keer over —
    /// in de Windows-versie zijn het 32-bits gehele getallen, die bij ongeveer
    /// veertien miljoen spellen aan hun eind zijn. Een miljoen ligt daar ruim
    /// onder en is met de hand toch nooit te halen.
    public static let maxSpellen = 1_000_000

    /// Nederlands of Engels. Schrijft door naar Taal, waar zowel het scherm als
    /// de speellogica hun teksten vandaan halen.
    @Published public var engels: Bool = Taal.engels {
        didSet { Taal.engels = engels; bewaarVoorkeuren() }
    }

    @Published public var demo = false { didSet { schrijfSchakelaars() } }
    @Published public var openKaart = false { didSet { schrijfSchakelaars() } }

    /// Speelt deze kant volgens de zoekende speler in plaats van de vuistregels?
    /// Zuid staat standaard op doorrekenen en Noord op vuistregels, zodat een
    /// demo meteen de twee speelwijzen tegen elkaar zet.
    @Published public var zoektZuid = true { didSet { schrijfSchakelaars(); bewaarVoorkeuren() } }
    @Published public var zoektNoord = false { didSet { schrijfSchakelaars(); bewaarVoorkeuren() } }

    /// Speelt deze kant volgens Claude (brute force: het hele spel een aantal keer doorspelen)?
    /// Gaat voor `zoektZuid`/`zoektNoord`. Standaard uit.
    @Published public var claudeZuid = false { didSet { schrijfSchakelaars(); bewaarVoorkeuren() } }
    @Published public var claudeNoord = false { didSet { schrijfSchakelaars(); bewaarVoorkeuren() } }

    /// De speelwijze per kant als één keuze: 0 = Ednieuw, 1 = Ronlog, 2 = Claude. Het optieblad
    /// kiest uit drie; onder de motorkap blijven het de losse schakelaars hierboven.
    public var stijlZuid: Int {
        get { claudeZuid ? 2 : (zoektZuid ? 1 : 0) }
        set { zoektZuid = newValue == 1; claudeZuid = newValue == 2 }
    }
    public var stijlNoord: Int {
        get { claudeNoord ? 2 : (zoektNoord ? 1 : 0) }
        set { zoektNoord = newValue == 1; claudeNoord = newValue == 2 }
    }

    /// Snel spelen zonder kaarten: het SDEMO uit het origineel, waar het tekenen
    /// werd overgeslagen. Er valt dan niets te klikken, dus de computer speelt
    /// beide kanten en er wordt niet gewacht.
    @Published public var snel = false {
        didSet {
            guard snel != oldValue else { return }
            tempo.snelSpelen = snel
            if snel {
                demo = true
                // Stond het spel op een kaart van de speler te wachten, dan
                // blijft het daar staan: in het snelscherm zijn de kaarten weg
                // en valt er niets meer aan te tikken. Daarom niet doorgaan met
                // dit spel maar een nieuw beginnen, met de computer aan beide
                // kanten. De tellingen gaan eerst naar de bewaarplaats en komen
                // daar meteen weer uit, dus die blijven staan.
                naarDeAchtergrond()
                start()
            } else {
                // Uit snel spelen: ook de demo uit, zodat je weer zelf speelt. Anders blijft de
                // computer beide kanten spelen, en staat in het optieblad de speelwijze van Zuid er
                // nog bij.
                demo = false
            }
        }
    }

    private let schakelaars = Schakelaars()
    let tempo = Tempo()
    private var taak: Task<Void, Never>?

    /// De verbinding met de andere kant, in beide rollen. Alleen voor het
    /// opruimen in `stop()`; `GastheerUi` en de gast-ontvanglus houden zelf
    /// ook een verwijzing vast om ermee te werken.
    private var duoKoppeling: DuoKoppeling?

    /// De radio zelf, apart van `duoKoppeling` — nodig om hem ook echt te
    /// kunnen afsluiten. `startDuoAlsGastheer`/`startDuoAlsGast` kregen tot nu
    /// toe alleen het smallere `DuoLijn` binnen (stuur/ontvang), en die kent
    /// geen `stop()` — `DuoRadio` (in `KlaverjasBLE`) wel. Zonder deze
    /// bewaring bleef de echte `CBPeripheralManager`/`CBCentralManager` na elk
    /// `stop()` gewoon doorlopen: Ed's melding "als de verbinding wegvalt kan
    /// je niet opnieuw verbinden, tenzij je de app herstart" — de oude radio
    /// stond nog steeds te adverteren/scannen en blokkeerde de nieuwe.
    private var duoRadio: DuoRadio?

    /// Alleen gezet als gastheer — voor het opruimen in `stop()`
    /// (`gastheerUi.stop()`, ruimt zijn drie eigen wachters op de gast op).
    /// De gast heeft geen `GastheerUi`, dus blijft dit daar altijd `nil`.
    private var gastheerUi: GastheerUi?

    /// Luistert, ná de overdracht door `VerbindScherm`, mee op dezelfde
    /// `statusStroom()` als het verbindingsscherm zelf gebruikte — dat scherm
    /// stopt met luisteren zodra het overdraagt, dus zonder dit werd een
    /// verbinding die tijdens het spel wegvalt (`BleCentraal` hoort dat via
    /// `didDisconnectPeripheral`, `BlePerifeer` via het nieuwe
    /// `didUnsubscribeFrom`) door niemand meer opgemerkt: het scherm bleef
    /// gewoon bevroren staan en "Nieuw spel" bleef verstopt, want
    /// `inSamenspel` werd nooit meer `false`.
    private var verbindingsBewaker: Task<Void, Never>?

    /// Ben ik de gast in samenspel? Dan is er geen lokale `KjSpel` — `klik`/
    /// `kiesTroef` sturen de keuze over de lijn in plaats van een wachtende
    /// vraag van de speelloop te beantwoorden.
    private var benIkGast = false

    /// De naam van de huidige samenspel-partner (uit de begroeting, zie
    /// `DuoOpzet.Resultaat.klaar`), voor de duur van de partij. `nil` buiten
    /// samenspel — dan schrijft `bewaarAlsHetTijdIs` gewoon naar de
    /// solo-sleutel, zoals altijd.
    private var duoPartnerNaam: String?

    /// Zit ik nu in een samenspel-partij, als gastheer of als gast? Voor het
    /// scherm: "Nieuw spel" (en vergelijkbare knoppen die een lopende partij
    /// zouden vervangen of de schakelaars zouden aanraken) moeten hiermee
    /// verstopt of uitgezet worden. Zonder die bewaking kon één per ongeluk
    /// getikte knop een lopend samenspel gewoon vervangen door een eigen,
    /// nieuwe partij — precies wat leek op "de gast blijft in zijn eigen
    /// spel", zonder dat er ergens een echte fout in de bedrading zat.
    public var inSamenspel: Bool { benIkGast || duoKoppeling != nil }

    /// Verhoogd bij elke `stop()`. Een `Brug` draagt de generatie van het
    /// moment waarop hij gemaakt is, en schrijft niet meer in `view`/`modus`
    /// zodra die niet meer de huidige is.
    ///
    /// Nodig omdat `stop()` de speeltaak wel annuleert en zijn wachtende
    /// continuations loslaat, maar dat maakt de taak niet meteen dood: hij
    /// staat nog gewoon aan zijn eigen `Brug` vast. Een losgelaten kaartvraag
    /// komt met een lege, ongeldige kaart terug bij `KjSpel.mensKiest()`, en
    /// die vraagt gewoon opnieuw — via diezelfde oude `Brug`. Zonder deze
    /// generatie schreef zo'n verweesde herhaalvraag over een net gestarte
    /// gastmodus (of een nieuwe partij) heen, en — erger — bleef dat zo als
    /// de speler vervolgens netjes op wat hij zag tikte: dat hield de oude,
    /// losgekoppelde partij juist in leven, terwijl de echte stand van de
    /// gastheer ondertussen gewoon bleef binnenkomen maar nooit te zien was.
    /// Precies dit — "de gast blijft na het verbinden in zijn eigen spel" —
    /// meldde Ed na de eerste hardwareproef van fase 5. `KjSpel.mensKiest()`
    /// stopt bovendien zelf ook als de taak is afgebroken (`Task.isCancelled`),
    /// zodat zo'n verweesde taak niet oneindig snel blijft doorvragen zodra
    /// deze generatie zijn antwoorden zonder gevolg maakt.
    fileprivate var generatie = 0

    /// Voor proeven die zelf een `Brug` bouwen, los van `start()`/
    /// `starten(...)` — die moeten net als productiecode de generatie van
    /// dít moment meegeven, niet een verzonnen waarde.
    var huidigeGeneratie: Int { generatie }

    /// Waar de tellingen blijven staan tussen twee keer opstarten.
    private let bewaarplaats: Bewaarplaats
    /// Wanneer er voor het laatst weggeschreven is. Bij snel spelen komen er
    /// duizenden spellen per minuut voorbij; dan is één keer per seconde genoeg.
    private var laatstBewaard = ContinuousClock.now
    private static let bewaarpauze = Duration.seconds(1)

    private var kaartAntwoord: CheckedContinuation<(naam: Teken, kleur: Int), Never>?
    private var troefAntwoord: CheckedContinuation<Int, Never>?
    private var verderAntwoord: CheckedContinuation<Void, Never>?

    public init(bewaarplaats: Bewaarplaats = Bewaarplaats()) {
        self.bewaarplaats = bewaarplaats
        // De keuzes van de vorige keer terugzetten. Rechtstreeks in de opslag
        // schrijven kan niet: `didSet` draait niet in een init, dus de taal moet
        // er hier met de hand bij.
        if let v = bewaarplaats.leesVoorkeuren() {
            zoektZuid = v.zoektZuid
            zoektNoord = v.zoektNoord
            claudeZuid = v.claudeZuid
            claudeNoord = v.claudeNoord
            engels = v.engels
            Taal.engels = v.engels
        }
        schrijfSchakelaars()
    }

    /// Alleen wat de speler zelf gekozen heeft; niet de schakelaars die bij
    /// deze ene zitting horen.
    private func bewaarVoorkeuren() {
        bewaarplaats.schrijfVoorkeuren(
            Bewaarplaats.Voorkeuren(zoektZuid: zoektZuid, zoektNoord: zoektNoord,
                                    engels: engels,
                                    claudeZuid: claudeZuid, claudeNoord: claudeNoord))
    }

    private func schrijfSchakelaars() {
        schakelaars.huidig = Instellingen(demo: demo, openKaart: openKaart,
                                          zoektZuid: zoektZuid, zoektNoord: zoektNoord,
                                          claudeZuid: claudeZuid, claudeNoord: claudeNoord)
    }

    // ------------------------------------------------------------ starten

    /// Start een nieuwe partij; een lopende partij wordt eerst afgebroken.
    public func start(zaad: Int? = nil) {
        stop()
        schrijfSchakelaars()

        let brug = Brug(model: self, tempo: tempo, generatie: generatie)
        let doos = schakelaars
        // De tellingen van de vorige keer gaan mee de motor in voordat hij
        // begint; daarna is hij van zijn eigen taak en schrijft niemand er meer
        // van buitenaf in.
        let begin = bewaarplaats.lees()
        let spel = KjSpel(ui: brug, zaad: zaad,
                          instellingen: { doos.huidig }, beginStatistiek: begin)
        taak = Task.detached(priority: .userInitiated) {
            await spel.loop()
        }
    }

    /// Begint als gastheer (de opensteller) een verse partij, en stuurt hem
    /// naar de gast — niet de partij voortzetten die hier al liep vóór het
    /// verbinden. Ed's aanwijzing na het testen op hardware: "Als er een BLE
    /// verbinding is moeten beide [toestellen hun eigen] spelen eigenlijk
    /// stoppen en moet de master opnieuw gaan delen en dan het spel naar de
    /// slave sturen."
    ///
    /// (Een eerdere opzet liet de partij die al liep — begonnen bij het
    /// opstarten van de app — gewoon doorspelen, via een wisselbare `KjUi`
    /// ervoor. Dat werkte in de proeven met een lus-in-het-geheugen, maar gaf
    /// op hardware precies dit: allebei de toestellen bleven hun eigen,
    /// intussen al uiteengelopen partij spelen. Simpeler en robuuster om
    /// vanaf hier gewoon altijd opnieuw te delen.)
    ///
    /// `GastheerUi` draait de enige echte motor; de gast is puur scherm en
    /// invoer, zie de aantekening daar.
    ///
    /// `partnerNaam`/`beginStatistiek` komen uit `DuoOpzet.Resultaat.klaar`
    /// (de verzoende score-uitwisseling bij het verbinden, zie `DuoOpzet`) —
    /// niet meer uit `bewaarplaats.lees()`, dat blijft voortaan gereserveerd
    /// voor solo spelen. `partnerNaam` is verplicht, met opzet zonder
    /// standaardwaarde: een duo-partij zonder partnernaam is precies de bug
    /// die dit oplost.
    public func startDuoAlsGastheer(lijn: DuoRadio, partnerNaam: String,
                                     beginStatistiek: Statistiek = Statistiek()) {
        BleLog.zeg("startDuoAlsGastheer: begonnen")
        stop()
        benIkGast = false
        duoPartnerNaam = partnerNaam
        // Meteen op dit apparaat vastleggen, ook vóór er een kaart gespeeld
        // is: valt de verbinding meteen weer weg, dan is de verzoende score
        // van zojuist toch niet voor niets geweest.
        bewaarplaats.schrijfDuo(beginStatistiek, partner: partnerNaam)

        let brug = Brug(model: self, tempo: tempo, generatie: generatie)
        let koppeling = DuoKoppeling(lijn: lijn)
        duoKoppeling = koppeling
        duoRadio = lijn
        bewaakVerbinding(lijn)
        let gastheerUi = GastheerUi(scherm: brug, koppeling: koppeling, mijnKant: 1,
                                    wachtLokaalOpTik: { [weak self] in
                                        await self?.wachtOpTikVoorVerder ?? false
                                    },
                                    gaVerder: { [weak self] in await self?.gaVerder() },
                                    log: { BleLog.zeg($0) })
        self.gastheerUi = gastheerUi
        // Niet de volledige schakelaars mee: `openKaart`/`zoektZuid`/
        // `zoektNoord` blijven op hun standaardwaarde, want die zouden de
        // kaarten van de tegenpartij laten zien of de speelwijze van een kant
        // die niet van dit toestel is aanraken. Alleen `demo` gaat live mee —
        // Ed's wens om de BLE-verbinding en de snelheid te kunnen beproeven
        // zonder zelf 32 kaarten per kant aan te hoeven tikken: `s.comp`
        // (waar dat op uitkomt) slaat `mens` helemaal over
        // (`!s.comp && s.mensIsAanZet(...)` in `KjEngine+Ai.swift`/`KjSpel.swift`),
        // dus dit raakt nooit `GastheerUi.kiesKaart`/`kiesTroef` — geen tik
        // hoeft nog onderweg te zijn zodra dit aan gaat, alleen de eerst-
        // volgende beurt speelt de computer. Uit zetten gaat vanaf de
        // eerstvolgende beurt weer terug naar mensen.
        let doos = schakelaars
        let spel = KjSpel(ui: gastheerUi, zaad: nil,
                          instellingen: { Instellingen(demo: doos.huidig.demo) },
                          beginStatistiek: beginStatistiek, mijnKant: 1)
        spel.e.s.mens = [true, true]
        taak = Task.detached(priority: .userInitiated) {
            await koppeling.start()
            await gastheerUi.koppel(aan: spel)
            BleLog.zeg("startDuoAlsGastheer: partij gekoppeld, motor start")
            await spel.loop()
        }
    }

    /// Start als gast (de zoeker): geen eigen motor — alles komt van de
    /// gastheer als een complete momentopname (`STAND`, zie `DuoBericht`), en
    /// een eigen keuze gaat terug als `ZET`. Zie `klik(_:)`/`kiesTroef(_:)`,
    /// die in gastmodus niet een lokale vraag beantwoorden maar over de lijn
    /// sturen.
    public func startDuoAlsGast(lijn: DuoRadio, partnerNaam: String,
                                 beginStatistiek: Statistiek = Statistiek()) {
        BleLog.zeg("startDuoAlsGast: begonnen")
        stop()
        benIkGast = true
        duoPartnerNaam = partnerNaam
        bewaarplaats.schrijfDuo(beginStatistiek, partner: partnerNaam)

        let koppeling = DuoKoppeling(lijn: lijn)
        duoKoppeling = koppeling
        duoRadio = lijn
        bewaakVerbinding(lijn)
        taak = Task.detached(priority: .userInitiated) { [weak self] in
            await koppeling.start()
            guard let self else { return }
            while !Task.isCancelled {
                let bericht = await koppeling.volgende()
                guard case .stand(let json) = bericht,
                      let v = try? DuoStand.decodeer(json, als: SpelView.self) else { continue }
                await self.pasGastStandToe(v)
            }
        }
    }

    /// Verwerkt een momentopname van de gastheer: tonen, en alleen als ík aan
    /// zet ben (`v.benIkAanZet`, al vanuit mijn kant berekend door de
    /// gastheer) de bijbehorende invoerstand aanzetten. Anders — de gastheer
    /// is zelf aan zet, of niemand is dat (tussen twee slagen) — gewoon kijken.
    private func pasGastStandToe(_ v: SpelView) {
        view = v
        tekst = v.melding.isEmpty ? v.status : v.melding
        bewaarAlsHetTijdIs(v, meteen: v.spelUit && !snel)
        if v.troefVraag && v.benIkAanZet {
            modus = .kiesTroef
        } else if v.wachtOpSpeler && v.benIkAanZet {
            modus = .kiesKaart
        } else if v.wachtOpVerder {
            // Niet aan `benIkAanZet` gebonden, bewust: "verder" is geen
            // beurt, dus mag van allebei de kanten komen (Ed: "beide kanten
            // moeten een nieuwe beurt kunnen starten").
            modus = .verder
        } else {
            modus = .wachten
        }
    }

    /// Stuurt mijn keuze terug naar de gastheer — de gastmodus-tegenhanger
    /// van het beantwoorden van een lokale vraag in `klik(_:)`/`kiesTroef(_:)`.
    ///
    /// Gelogd via `BleLog`, ook al hoort dit bij `SpelModel` en niet bij de
    /// radiolaag zelf: zonder dit was er geen enkele manier om op het scherm
    /// te zien of een tik hier ooit aankwam, laat staan of hij daarna ook
    /// echt de lijn op ging (zie `BleCentraal`/`BlePerifeer.stuur(_:)`) —
    /// "tikken deed niets" bleek anders niet te onderscheiden van "de tik
    /// werd nooit als zet herkend".
    private func stuurGastZet(_ z: GastZet) {
        modus = .wachten
        guard let duoKoppeling else {
            BleLog.zeg("tik genegeerd (geen duo-verbinding meer)")
            return
        }
        BleLog.zeg("tik herkend als zet: \(z)")
        Task {
            guard let json = try? DuoStand.codeer(z) else {
                BleLog.zeg("kon zet niet coderen: \(z)")
                return
            }
            await duoKoppeling.stuur(.zet(json: json))
        }
    }

    /// Alle bewaarde duo-tellingen, per partnernaam — voor `VerbindScherm`,
    /// dat ze bij het verbinden meegeeft aan `DuoOpzet.alsGastheer`/`alsGast`
    /// zodat de score-verzoening iets heeft om mee te vergelijken.
    public func alleBewaardeDuoTellingen() -> [String: Statistiek] {
        bewaarplaats.leesAlleDuo()
    }

    /// Alles op nul: de bewaarde tellingen weg en opnieuw beginnen. De motor
    /// wordt daarvoor opnieuw opgezet, zodat er niemand van buitenaf in zijn
    /// tellers hoeft te schrijven terwijl hij draait.
    public func wisStatistiek() {
        // Volgorde telt. `stop()` legt de stand nog één keer vast, en `start()`
        // roept `stop()` aan — wis je eerst en start je daarna, dan schrijft dat
        // de zojuist gewiste tellingen meteen terug. Daarom eerst de motor stil,
        // dan de momentopname leegmaken zodat er niets meer te bewaren valt, en
        // pas dan wissen en opnieuw beginnen.
        stop()
        view = SpelView()
        // Alleen de eigen tellingen. De samenspel-partners blijven staan en gaan één voor één weg
        // (`wisDuoPartner`), zodat een foutje nooit alles tegelijk kost.
        bewaarplaats.wis()
        start()
    }

    /// Met wie wordt er nu samen gespeeld? Nil als er geen verbinding is. Die partner blijft in de lijst
    /// "Samen gespeeld" staan: de lopende partij schrijft zijn tellingen toch weer terug.
    public var actievePartner: String? { inSamenspel ? duoPartnerNaam : nil }

    /// Haalt één samenspel-partner uit de bewaarde tellingen.
    public func wisDuoPartner(_ naam: String) {
        guard naam != actievePartner else { return }
        bewaarplaats.wisDuo(partner: naam)
    }

    /// Blijft, ná de overdracht door `VerbindScherm`, meeluisteren op de
    /// status van de radio — dat scherm zelf stopt met luisteren zodra het
    /// overdraagt (het is dan al gesloten). Ed's melding: "als de verbinding
    /// wegvalt kan je niet opnieuw verbinden... de knop Nieuw spel is nu
    /// verdwenen." Zonder deze wacht bleef `duoKoppeling`/`benIkGast` gewoon
    /// staan na een weggevallen lijn, dus `inSamenspel` ook, dus "Nieuw spel"
    /// ook verstopt — er was dan geen weg terug zonder de app te herstarten.
    ///
    /// Alleen op `.mislukt` reageren: dat is het enige geval waarin de lijn
    /// zelf weg is (zie `DuoStatus`). Op `stop()` aanroepen — niet op een
    /// eigen "verbinding verloren"-functie — omdat dat precies is wat hier
    /// nodig is: alles opruimen en teruggaan naar een gewone, losse partij,
    /// niet proberen te hervatten (dat wilde Ed hier expliciet niet).
    private func bewaakVerbinding(_ radio: DuoRadio) {
        verbindingsBewaker = Task { [weak self] in
            for await status in await radio.statusStroom() {
                guard case .mislukt = status else { continue }
                guard !Task.isCancelled else { return }
                BleLog.zeg("verbinding tijdens het spel weggevallen — partij stopt")
                self?.stop()
                // Ná `stop()`, niet ervoor: die laat `tekst` verder met rust,
                // maar overschrijft hem ook niet. Zonder deze regel stopte de
                // partij hier wel degelijk (op de gastheer: de demo-lus zag
                // `Task.isCancelled` en hield op; op de gast: er kwamen geen
                // standen meer), maar bleef het scherm gewoon op de laatst
                // getoonde tekst staan — geen enkel teken waarom het spel
                // ophield. Ed, bij het beproeven van demo+samenspel: "hij zou
                // dan ook moeten stoppen met een melding 'Verbinding
                // verbroken'... op de slave moet de melding ook komen."
                self?.tekst = Taal.duoVerbindingVerbroken
                return
            }
        }
    }

    /// De stand wegschrijven. Aan het eind van een spel, en verder hooguit één
    /// keer per seconde.
    ///
    /// Buiten samenspel (`duoPartnerNaam == nil`) gaat dit, zoals altijd, naar
    /// de ene solo-sleutel. Tijdens samenspel gaat het naar de emmer van de
    /// huidige partner — `v.statistiek` staat daarbij altijd in absolute
    /// Zuid(gastheer)/Noord(gast)-orde, dus de gast wisselt hem eerst om naar
    /// zijn eigen kant-orde ([0] = ik) vóór hij hem bewaart; de gastheer is
    /// zelf al Zuid, dus voor hem verandert er niets.
    private func bewaarAlsHetTijdIs(_ v: SpelView, meteen: Bool = false) {
        guard !v.statistiek.leeg else { return }
        let nu = ContinuousClock.now
        guard meteen || nu - laatstBewaard >= Self.bewaarpauze else { return }
        laatstBewaard = nu
        guard let partnerNaam = duoPartnerNaam else {
            bewaarplaats.schrijf(v.statistiek)
            return
        }
        let inMijnOrde = benIkGast ? v.statistiek.kantenOmgewisseld : v.statistiek
        bewaarplaats.schrijfDuo(inMijnOrde, partner: partnerNaam)
    }

    public func stop() {
        bewaarAlsHetTijdIs(view, meteen: true)
        // Eerst: een oude `Brug` — nog onderweg naar zijn einde, bijvoorbeeld
        // via een herhaalvraag in `KjSpel.mensKiest()` ná het loslaten van
        // `kaartAntwoord` hieronder — moet zichzelf al herkennen als voorbij
        // vóórdat die kans zich voordoet. Zie de aantekening bij `generatie`.
        generatie += 1
        taak?.cancel()
        taak = nil
        benIkGast = false
        duoPartnerNaam = nil
        verbindingsBewaker?.cancel()
        verbindingsBewaker = nil
        if let duoKoppeling {
            Task { await duoKoppeling.stop() }
        }
        duoKoppeling = nil
        // Ruimt de drie wachters op wat de gást zou moeten sturen (troef,
        // kaart, verder) — zonder dit blijft er zo eentje voor eeuwig
        // hangen als de verbinding wegvalt terwijl de gastheer op de gast
        // wachtte. Alleen gezet als gastheer; bij de gast blijft dit `nil`.
        if let gastheerUi {
            Task { await gastheerUi.stop() }
        }
        gastheerUi = nil
        // De echte radio ook echt afsluiten — niet alleen `duoKoppeling`
        // (die kent alleen sturen/ontvangen, geen `stop()`). Zonder dit bleef
        // de vorige `CBPeripheralManager`/`CBCentralManager` gewoon
        // adverteren/scannen, en blokkeerde dat een volgende
        // verbindingspoging tot de app zelf herstart werd. Zie de
        // aantekening bij `duoRadio`.
        if let duoRadio {
            Task { await duoRadio.stop() }
        }
        duoRadio = nil
        // Een wachtende vraag moet losgelaten worden, anders blijft de taak
        // voor eeuwig in de continuation hangen.
        kaartAntwoord?.resume(returning: (naam: Teken.nul, kleur: 0)); kaartAntwoord = nil
        troefAntwoord?.resume(returning: 0); troefAntwoord = nil
        verderAntwoord?.resume(); verderAntwoord = nil
        modus = .wachten
    }

    // ------------------------------------------- vragen van de speelloop

    /// De regel bovenin zetten. Voor previews en schermafdrukken.
    public func zetTekst(_ t: String) { tekst = t }

    /// Het scherm in een vaste stand zetten zonder dat er een spel loopt.
    /// Alleen voor previews en schermafdrukken.
    public func zetModus(_ m: Modus) { modus = m }

    /// Een vaste toestand tonen. De speelloop gebruikt dit na elke zet; een
    /// preview of schermafdruk zet er een opgeslagen momentopname mee neer.
    public func toon(_ v: SpelView) {
        view = v
        // Normaal laat `toon()` de regel bovenin met rust — die hoort bij de
        // laatste vraag of slaguitslag. Bij samenspel gebruikt `GastheerUi`
        // dit pad juist om te melden dat de andere kant nu aan zet is
        // ("Zijn beurt"); zonder deze regel bleef daar de tekst van de vorige
        // eigen beurt gewoon staan.
        if !v.status.isEmpty { tekst = v.status }
        modus = .wachten
        bewaarAlsHetTijdIs(v, meteen: v.spelUit && !snel)
        kijkOfHetGenoegIs()
    }

    /// Het scherm gaat naar de achtergrond, of de app wordt weggeveegd. Dit is
    /// het laatste moment waarop er nog iets bewaard kan worden.
    public func naarDeAchtergrond() {
        bewaarAlsHetTijdIs(view, meteen: true)
    }

    /// Speelt de computer beide kanten, dan houdt hij op zichzelf nooit op.
    /// Bij `maxSpellen` gaat de partij uit, zodat de tellers heel blijven.
    private func kijkOfHetGenoegIs() {
        guard demo else { return }
        let gespeeld = view.statistiek.spellen[0] + view.statistiek.spellen[1]
        guard gespeeld >= Int64(Self.maxSpellen) else { return }
        snel = false
        stop()
        tekst = Taal.snelKlaar(Int(gespeeld))
    }

    func vraagKaart(_ v: SpelView) async -> (naam: Teken, kleur: Int) {
        view = v
        tekst = v.melding.isEmpty ? v.status : v.melding
        modus = .kiesKaart
        return await withCheckedContinuation { c in kaartAntwoord = c }
    }

    func vraagTroef(_ v: SpelView) async -> Int {
        view = v
        tekst = v.status
        modus = .kiesTroef
        return await withCheckedContinuation { c in troefAntwoord = c }
    }

    func vraagVerder(_ v: SpelView, _ melding: String) async {
        view = v
        tekst = melding
        if snel {
            modus = .wachten
            return
        }
        if automatisch {
            modus = .wachten
            try? await Task.sleep(for: .milliseconds(900))
            return
        }
        modus = .verder
        await withCheckedContinuation { c in verderAntwoord = c }
    }

    /// Als `vraagVerder(_:_:)`, maar zonder op een tik te wachten: de uitslag
    /// verschijnt gewoon, en de speelloop gaat meteen verder. Voor de gast in
    /// samenspel — die volgt het tempo van de gastheer, niet zijn eigen tik.
    func toonUitslag(_ v: SpelView, _ melding: String) async {
        view = v
        tekst = melding
        modus = .wachten
    }

    // --------------------------------- dezelfde vragen, met generatiebewaking

    /// `Brug` roept altijd deze overloads aan, nooit de kale versies
    /// hierboven rechtstreeks: één controle en de eigenlijke aanroep in
    /// dezelfde MainActor-beurt, zodat een verweesde `Brug` (zie
    /// `generatie`) niet meer kan schrijven, zonder daar een aparte
    /// `await`-stap voor te hoeven doen. Die aparte stap leek onschuldig,
    /// maar schoof de timing van `modus = .verder` net ver genoeg op om
    /// `PauzeTests.gewoonPaneelWerktElkeSlagBij` — die maar één keer
    /// `Task.yield()` doet vóór ze kijkt — voorgoed te laten hangen.
    func toon(_ v: SpelView, generatie: Int) {
        guard generatie == self.generatie else { return }
        toon(v)
    }

    func vraagKaart(_ v: SpelView, generatie: Int) async -> (naam: Teken, kleur: Int) {
        guard generatie == self.generatie else { return (naam: .nul, kleur: 0) }
        return await vraagKaart(v)
    }

    func vraagTroef(_ v: SpelView, generatie: Int) async -> Int {
        guard generatie == self.generatie else { return 0 }
        return await vraagTroef(v)
    }

    func vraagVerder(_ v: SpelView, _ melding: String, generatie: Int) async {
        guard generatie == self.generatie else { return }
        await vraagVerder(v, melding)
    }

    func toonUitslag(_ v: SpelView, _ melding: String, generatie: Int) async {
        guard generatie == self.generatie else { return }
        await toonUitslag(v, melding)
    }

    // --------------------------------------------------- antwoord geven

    /// De speler klikte op een kaart.
    ///
    /// Tijdens de troefvraag betekent dat iets anders: dan wordt de kleur van
    /// de aangetikte kaart troef. Dat mag alleen met een kaart die je ook echt
    /// ziet — een dichte kaart van je eigen tafel verraadt zijn kleur niet, en
    /// hem zo kunnen aanwijzen zou meer verklappen dan het spel toestaat.
    public func klik(_ kaart: KaartView) {
        if modus == .kiesTroef {
            if kaart.open { kiesTroef(kaart.kleur) }
            return
        }
        guard modus == .kiesKaart else { return }
        if benIkGast {
            stuurGastZet(GastZet(kaart: kaart.naam, kleur: kaart.kleur))
            return
        }
        guard let c = kaartAntwoord else { return }
        kaartAntwoord = nil
        modus = .wachten
        c.resume(returning: (naam: kaart.naam, kleur: kaart.kleur))
    }

    /// De speler koos een troefkleur (0..3).
    public func kiesTroef(_ kleur: Int) {
        guard modus == .kiesTroef else { return }
        if benIkGast {
            stuurGastZet(GastZet(troef: kleur))
            return
        }
        guard let c = troefAntwoord else { return }
        troefAntwoord = nil
        modus = .wachten
        c.resume(returning: kleur)
    }

    /// Wacht deze kant, als gastheer, straks echt op een eigen tik om verder
    /// te gaan? Bij snel spelen of automatisch doorgaan niet (zie
    /// `Brug.vraagVerder`/`vraagVerder`) — en dan moet de gast ook geen
    /// tikbare stand krijgen. `GastheerUi.verder(_:_:)` vraagt dit vóór hij
    /// `wachtOpVerder` op de uitgaande stand zet.
    var wachtOpTikVoorVerder: Bool { !snel && !automatisch }

    /// Klik of toets om verder te gaan. Bij samenspel mag dit van allebei de
    /// kanten: de gast stuurt zijn tik over de lijn in plaats van een lokale
    /// wachtende vraag te beantwoorden — precies zoals `klik(_:)`/
    /// `kiesTroef(_:)` dat al voor kaart en troef deden. Ed: "de volgende
    /// beurt kan alleen door degene die de laatste slag speelt worden
    /// gegeven, maak het zo dat beide kanten een nieuwe beurt kunnen
    /// starten."
    public func gaVerder() {
        guard modus == .verder else { return }
        if benIkGast {
            stuurGastZet(GastZet(verder: true))
            return
        }
        guard let c = verderAntwoord else { return }
        verderAntwoord = nil
        modus = .wachten
        c.resume()
    }

    /// Wordt er op dit moment een kaart van je gevraagd?
    ///
    /// Dit is de poort voor het aantikken, en die staat bewust wijder open dan
    /// `magKlikken`. Tik je op de verkeerde stapel, dan hoort de speelloop dat
    /// te zeggen — "die kaart ligt op tafel" — en dat kan alleen als de tik hem
    /// bereikt. Weigerde het scherm de tik zelf, dan gebeurde er helemaal niets
    /// en bleef de speler in het duister.
    /// Tijdens de troefvraag staat de poort ook open: een tik op een eigen
    /// kaart kiest die kleur als troef, naast de vier knoppen.
    public func neemtTik() -> Bool { modus == .kiesKaart || modus == .kiesTroef }

    /// Licht deze stapel op? Bij uitkomen mag je kiezen tussen je hand en je
    /// tafel; daarna licht alleen de stapel op die aan de beurt is. Alleen voor
    /// het tekenen — voor het aantikken geldt `neemtTik()`.
    public func magKlikken(_ uitHand: Bool) -> Bool {
        // Bij de troefvraag lichten beide eigen rijen op: elke kaart die je ziet
        // is een geldige keuze, en dat moet zichtbaar zijn, anders vindt niemand
        // deze manier van kiezen.
        if modus == .kiesTroef { return true }
        guard modus == .kiesKaart else { return false }
        if view.slag.isEmpty { return true }
        return uitHand ? view.aanZet == view.mijnHandPos : view.aanZet == view.mijnTafelPos
    }
}

/// De vertaling van de vier vragen van de speelloop naar het model. Een aparte
/// struct omdat de speelloop op een andere taak draait: dit is het enige stukje
/// dat de grens over gaat.
struct Brug: KjUi {
    let model: SpelModel
    let tempo: Tempo

    /// De generatie van `model.stop()` op het moment dat deze `Brug` gemaakt
    /// werd. Zie de aantekening bij `SpelModel.generatie`. Gaat als parameter
    /// mee naar de generatiebewaakte overloads op `model` — niet als aparte
    /// controle vooraf: dat voegde een extra actorwissel toe die de timing
    /// van `modus = .verder` net genoeg opschoof om een proef te laten
    /// hangen, zie de aantekening daar.
    let generatie: Int

    /// Snel spelen: de speelloop bouwt dan geen kaartbeelden op. Leest alleen het slot van `Tempo`,
    /// dus geen sprong naar de hoofdtaak.
    var snelSpelen: Bool { tempo.snelSpelen }

    func toon(_ view: SpelView) async {
        // Bij snel spelen niet elke kaart doorgeven: dat zou de hoofdtaak
        // volledig bezet houden. Het scherm laat toch alleen een teller zien.
        guard tempo.magTekenen() else { return }
        await model.toon(view, generatie: generatie)
        // De pauze hoort hier en niet in de speelloop: het is een kwestie van
        // kijken, niet van spelen. De engine zelf blijft er vrij van, en de
        // toetsen die hem nalopen draaien dus op volle snelheid.
        guard tempo.magPauzeren() else { return }
        if await model.demo {
            try? await Task.sleep(for: SpelModel.demoPauze)
        }
    }

    func kiesKaart(_ view: SpelView) async -> (naam: Teken, kleur: Int) {
        await model.vraagKaart(view, generatie: generatie)
    }

    func kiesTroef(_ view: SpelView) async -> Int {
        await model.vraagTroef(view, generatie: generatie)
    }

    func verder(_ view: SpelView, _ tekst: String) async {
        // Geen afrem hier, bewust. Dat is geprobeerd (A30) om het "lopen" van
        // het paneel bij snel spelen tegen te gaan, maar de extra sprong naar
        // de hoofdtaak om `model.snel` te lezen — één keer per slag, dus bij
        // snel spelen miljoenen keren — kostte meetbaar meer dan het paneel
        // ooit opleverde. Teruggedraaid.
        await model.vraagVerder(view, tekst, generatie: generatie)
    }

    func toonUitslag(_ view: SpelView, _ tekst: String) async {
        await model.toonUitslag(view, tekst, generatie: generatie)
    }
}
