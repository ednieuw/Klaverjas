import Testing
import Foundation
@testable import KlaverjasApp
@testable import KlaverjasKit
import KlaverjasBLE

/// De echte productiebedrading voor samenspel: `SpelModel.startDuoAlsGastheer`/
/// `startDuoAlsGast`, over een `LusLijn` in plaats van bluetooth.
///
/// Sinds Ed's aanwijzing na de eerste hardwareproef — "laat de master het spel
/// beheersen" en, in het vervolg daarop, "een heel spel als struct/JSON heen
/// en weer sturen" — draait alleen de gastheer nog een echte `KjSpel`. Deze
/// proef bewijst dus dat de gast, die zelf geen motor meer heeft, een heel
/// spel kan uitspelen puur op de momentopnames die hij binnenkrijgt (`STAND`).
///
/// **Aansluiten begint altijd een verse partij**, ook als er al een liep —
/// dat bleek nodig na een tweede hardwareronde: "Als er een BLE verbinding
/// is moeten beide spelen eigenlijk stoppen en moet de master opnieuw gaan
/// delen." Een eerdere opzet liet de partij die al liep gewoon doorspelen
/// (via een wisselbare `KjUi` ervoor, `KjUiRouter`); dat werkte in deze
/// proeven met een lus-in-het-geheugen, maar gaf op hardware precies het
/// probleem dat dit zou moeten voorkomen: allebei de toestellen bleven hun
/// eigen, intussen al uiteengelopen partij spelen. `KjUiRouter` bestaat
/// daarom niet meer.
/// Een radio voor de proeven die, anders dan `LusLijn`, een verbinding kan
/// laten "wegvallen" (`laatVallen()`) en bijhoudt of hijzelf is afgesloten
/// (`gestopt`) — nodig om `SpelModel.bewaakVerbinding` en de reparatie van
/// `SpelModel.duoRadio` te toetsen zonder een echte radio. Wikkelt gewoon een
/// `LusLijn` in voor het versturen/ontvangen zelf.
actor WisselbareRadio: DuoRadio {
    private let lijn: LusLijn
    private var continuatie: AsyncStream<DuoStatus>.Continuation?
    private(set) var gestopt = false

    init(_ lijn: LusLijn) { self.lijn = lijn }

    func stuur(_ bericht: DuoBericht) async { await lijn.stuur(bericht) }
    func ontvang() async -> DuoBericht { await lijn.ontvang() }
    func start() async {}
    func stop() async { gestopt = true }
    func statusStroom() -> AsyncStream<DuoStatus> {
        AsyncStream { continuatie in self.continuatie = continuatie }
    }

    /// Doet alsof de verbinding wegvalt, zoals `didDisconnectPeripheral`
    /// (`BleCentraal`) of het nieuwe `didUnsubscribeFrom` (`BlePerifeer`) dat
    /// op echte hardware zouden melden.
    func laatVallen() {
        continuatie?.yield(.mislukt("test: verbinding weggehaald"))
    }
}

@Suite(.serialized)
@MainActor
struct StartDuoTests {
    /// Beantwoordt, als dat nu gevraagd wordt, de troefvraag of de
    /// kaartvraag — met de eerstvolgende kaart uit eigen hand of tafel, net
    /// als `MensTests.Automaat`. Werkt hetzelfde voor de gastheer en de gast:
    /// `SpelModel.klik(_:)`/`kiesTroef(_:)` sturen in gastmodus de keuze over
    /// de lijn in plaats van een lokale vraag te beantwoorden, dus deze
    /// automaat hoeft daar zelf geen onderscheid in te maken.
    @discardableResult
    private func speelEenZetAlsGevraagd(_ model: SpelModel, _ beurt: inout Int) -> Bool {
        switch model.modus {
        case .kiesTroef:
            model.kiesTroef(2)   // ruiten, altijd — het gaat hier niet om de kwaliteit van de zet
            return true
        case .kiesKaart:
            let v = model.view
            let keuzes: [KaartView]
            if v.slag.isEmpty {
                keuzes = v.mijnHand + v.mijnTafel
            } else if v.aanZet == v.mijnTafelPos {
                keuzes = v.mijnTafel
            } else {
                keuzes = v.mijnHand
            }
            guard !keuzes.isEmpty else { return false }
            let kaart = keuzes[beurt % keuzes.count]
            beurt += 1
            model.klik(kaart)
            return true
        case .verder:
            model.gaVerder()
            return true
        default:
            return false
        }
    }

    /// Bedient één model tot `voorwaarde()` waar is — voor het alvast een
    /// stukje laten spelen vóórdat er iemand bij aansluit.
    private func speelLokaalTot(_ voorwaarde: () -> Bool, _ model: SpelModel,
                                pogingen: Int = 500) async -> Bool {
        var beurt = 0
        for _ in 0..<pogingen {
            if voorwaarde() { return true }
            speelEenZetAlsGevraagd(model, &beurt)
            try? await Task.sleep(for: .milliseconds(2))
        }
        return voorwaarde()
    }

    /// Wacht kort en begrensd tot `voorwaarde()` waar is, zonder zelf iets te
    /// bedienen — voor een uitkomst die alleen via een andere, asynchrone taak
    /// binnenkomt (een `STAND` over `LusLijn`), niet via een tik.
    private func wachtTot(_ voorwaarde: () -> Bool, pogingen: Int = 100) async -> Bool {
        for _ in 0..<pogingen {
            if voorwaarde() { return true }
            try? await Task.sleep(for: .milliseconds(2))
        }
        return voorwaarde()
    }

    /// Bedient beide kanten tot `voorwaarde()` waar is, met een grens: een
    /// proef die vast blijft staan moet zakken, niet de hele testrun ophouden.
    private func speelTot(_ voorwaarde: () -> Bool, _ gastheer: SpelModel, _ gast: SpelModel,
                          pogingen: Int = 2000) async -> Bool {
        var beurtGastheer = 0, beurtGast = 0
        for _ in 0..<pogingen {
            if voorwaarde() { return true }
            speelEenZetAlsGevraagd(gastheer, &beurtGastheer)
            speelEenZetAlsGevraagd(gast, &beurtGast)
            // Een kale `Task.yield()` bleek hier niet genoeg: de gedetacheerde
            // speeltaak — met daarin meerdere actor-wissels per zet (`GastheerUi`,
            // `DuoKoppeling`, `LusLijn`) — kreeg dan geen merkbare kans om
            // verder te komen. Een echte, korte pauze lost dat op, net als bij
            // `MensTests.speel(vragen:)`.
            try? await Task.sleep(for: .milliseconds(2))
        }
        return voorwaarde()
    }

    @Test("Troef en de eerste slag komen bij de gast precies zo aan als bij de gastheer")
    func eersteSlagKomtBijBeideKantenAan() async {
        let gastheer = losModel()
        let gast = losModel()
        defer { gastheer.stop(); gast.stop() }

        let (lijnGastheer, lijnGast) = LusLijn.paar()
        async let opzetGastheer = DuoOpzet.alsGastheer(lijn: lijnGastheer, appversie: "test", naam: "gastheer")
        async let opzetGast = DuoOpzet.alsGast(lijn: lijnGast, appversie: "test", naam: "gast")
        let (resultaatGastheer, resultaatGast) = await (opzetGastheer, opzetGast)
        guard case .klaar = resultaatGastheer else {
            Issue.record("begroeting als gastheer niet gelukt: \(resultaatGastheer)")
            return
        }
        guard case .klaar = resultaatGast else {
            Issue.record("begroeting als gast niet gelukt: \(resultaatGast)")
            return
        }

        gastheer.startDuoAlsGastheer(lijn: lijnGastheer, partnerNaam: "gast")
        gast.startDuoAlsGast(lijn: lijnGast, partnerNaam: "gastheer")

        // Ruim boven het standaardaantal (2000): onder volle belasting van de
        // rest van de testrun bleek dat soms net niet genoeg — dezelfde soort
        // ruis als bij `slagUitslagKloptOpBeideSchermen`, dat om diezelfde
        // reden van 3000 naar 8000 pogingen ging.
        let klaar = await speelTot({ gastheer.view.slagNr >= 2 && gast.view.slagNr >= 2 },
                                   gastheer, gast, pogingen: 6000)
        #expect(klaar, "de eerste slag kwam niet op tijd rond")
        guard klaar else { return }

        #expect(gastheer.view.troef == 2, "gastheer zag zijn eigen troefkeuze niet terug")
        #expect(gast.view.troef == 2, "gast zag de troefkeuze van de gastheer niet")
        #expect(gastheer.view.troefmaker == gast.view.troefmaker,
                "beide kanten moeten het eens zijn over wie troef maakte")

        // Vier kaarten in de vorige slag: de slag is echt gespeeld, niet
        // toevallig op nul blijven staan.
        #expect(gastheer.view.vorigeSlag.count == 4)
        #expect(gast.view.vorigeSlag.count == 4)
    }

    @Test("De gast ziet zijn eigen hand open en de hand van de gastheer dicht")
    func gastZietAlleenZijnEigenHandOpen() async {
        let gastheer = losModel()
        let gast = losModel()
        defer { gastheer.stop(); gast.stop() }

        let (lijnGastheer, lijnGast) = LusLijn.paar()
        async let opzetGastheer = DuoOpzet.alsGastheer(lijn: lijnGastheer, appversie: "test", naam: "gastheer")
        async let opzetGast = DuoOpzet.alsGast(lijn: lijnGast, appversie: "test", naam: "gast")
        _ = await (opzetGastheer, opzetGast)

        gastheer.startDuoAlsGastheer(lijn: lijnGastheer, partnerNaam: "gast")
        gast.startDuoAlsGast(lijn: lijnGast, partnerNaam: "gastheer")

        let klaar = await speelTot({ !gast.view.mijnHand.isEmpty }, gastheer, gast, pogingen: 500)
        #expect(klaar, "de gast kreeg nooit een hand te zien")
        guard klaar else { return }

        #expect(gast.view.mijnKant == 2, "de gast speelt Noord")
        #expect(gast.view.mijnHand.allSatisfy { $0.open },
                "de gast moet zijn eigen hand altijd open zien")
        #expect(gast.view.zijnHand.allSatisfy { !$0.open },
                "de gast mag de hand van de gastheer niet zien — dat lekte vóór deze reparatie")
    }

    @Test("Aansluiten als gastheer begint altijd een verse partij, ook als er al een liep")
    func aansluitenBegintAltijdEenVersePartij() async {
        let gastheer = losModel()
        defer { gastheer.stop() }
        gastheer.start(zaad: 555)

        // Doe alsof dit toestel al een tijdje alleen speelde vóórdat er iemand
        // aansloot: speel tot troef gekozen is.
        let troefGekozen = await speelLokaalTot({ gastheer.view.troef != 999 }, gastheer)
        #expect(troefGekozen, "de troef werd nooit gekozen — kan de rest van de proef niet bewijzen")
        guard troefGekozen else { return }

        let gast = losModel()
        defer { gast.stop() }
        let (lijnGastheer, lijnGast) = LusLijn.paar()
        async let opzetGastheer = DuoOpzet.alsGastheer(lijn: lijnGastheer, appversie: "test", naam: "gastheer")
        async let opzetGast = DuoOpzet.alsGast(lijn: lijnGast, appversie: "test", naam: "gast")
        _ = await (opzetGastheer, opzetGast)

        gastheer.startDuoAlsGastheer(lijn: lijnGastheer, partnerNaam: "gast")
        gast.startDuoAlsGast(lijn: lijnGast, partnerNaam: "gastheer")

        // De partij van vóór het verbinden had de troefvraag al gehad; een
        // verse partij moet die vraag opnieuw stellen — komt de speelloop
        // meteen bij kaarten spelen uit, dan speelde de oude partij gewoon
        // door.
        var beurtGastheer = 0, beurtGast = 0
        var kreegNieuweTroefvraag = false
        for _ in 0..<500 {
            if gastheer.modus == .kiesTroef {
                kreegNieuweTroefvraag = true
                break
            }
            speelEenZetAlsGevraagd(gastheer, &beurtGastheer)
            speelEenZetAlsGevraagd(gast, &beurtGast)
            try? await Task.sleep(for: .milliseconds(2))
        }
        #expect(kreegNieuweTroefvraag,
                "geen nieuwe troefvraag na het aansluiten — de al lopende partij speelde gewoon door")
        guard kreegNieuweTroefvraag else { return }

        // En die nieuwe troef komt, zoals altijd, ook bij de gast aan.
        let klaar = await speelTot({ gastheer.view.troef != 999 && gast.view.troef == gastheer.view.troef },
                                   gastheer, gast, pogingen: 500)
        #expect(klaar, "de gast kreeg de nieuwe troef niet te zien")
    }

    @Test("Een heel spel (acht slagen) komt bij beide kanten tot het eind")
    func heelSpelKomtTotHetEind() async {
        let gastheer = losModel()
        let gast = losModel()
        defer { gastheer.stop(); gast.stop() }

        let (lijnGastheer, lijnGast) = LusLijn.paar()
        async let opzetGastheer = DuoOpzet.alsGastheer(lijn: lijnGastheer, appversie: "test", naam: "gastheer")
        async let opzetGast = DuoOpzet.alsGast(lijn: lijnGast, appversie: "test", naam: "gast")
        _ = await (opzetGastheer, opzetGast)

        gastheer.startDuoAlsGastheer(lijn: lijnGastheer, partnerNaam: "gast")
        gast.startDuoAlsGast(lijn: lijnGast, partnerNaam: "gastheer")

        // 8000, niet 4000: zoals `slagUitslagKloptOpBeideSchermen` al
        // documenteert, is dat onder volle belasting van de rest van de
        // testrun soms net niet genoeg voor een heel spel van acht slagen.
        let klaar = await speelTot({ gastheer.view.spelUit && gast.view.spelUit },
                                   gastheer, gast, pogingen: 8000)
        #expect(klaar, "het spel kwam niet op tijd tot het eind — gastheer.modus=\(gastheer.modus) slagNr=\(gastheer.view.slagNr), gast.modus=\(gast.modus) slagNr=\(gast.view.slagNr)")
        guard klaar else { return }

        #expect(gastheer.view.totaalZuid + gastheer.view.totaalNoord > 0,
                "er zijn geen punten gevallen — het spel liep niet echt")
        #expect(gastheer.view.totaalZuid == gast.view.totaalZuid)
        #expect(gastheer.view.totaalNoord == gast.view.totaalNoord)
    }

    /// Ed's melding na de eerste hardwareproef van fase 5: "de Slave blijft
    /// na het verbinden in zijn eigen spel." Oorzaak: `startDuoAlsGast` roept
    /// `stop()` aan, en die trekt een openstaande lokale kaartvraag los met
    /// een lege, ongeldige kaart — maar dat maakt de oude speeltaak niet
    /// meteen dood, hij staat nog gewoon aan dezelfde `Brug` vast.
    /// `KjSpel.mensKiest()` vraagt bij een ongeldige kaart gewoon
    /// opnieuw, via diezelfde oude `Brug` — die schrijft dan een verweesde
    /// kaartvraag over de gastmodus heen. Het venijnige: tikt de speler
    /// vervolgens netjes op wat hij ziet (denkend dat het de echte partij is),
    /// dan houdt die tik de oude partij juist in leven — hij vraagt gewoon
    /// weer door, keer op keer, terwijl de echte stand van de gastheer
    /// intussen wel blijft binnenkomen maar nooit te zien is. Deze proef
    /// bootst precies dat na: de testautomaat bedient de gast net zo blind
    /// als een mens zou doen, zonder te weten of hij de oude of de nieuwe
    /// partij voor zich heeft. Gerepareerd met een generatie op `SpelModel`
    /// (`Brug.nogGeldig()`) plus een `Task.isCancelled`-uitgang in
    /// `KjSpel.mensKiest()` zodat een verweeste taak zichzelf ook echt
    /// opgeeft in plaats van oneindig snel te blijven navragen.
    @Test("Overschakelen naar gastmodus terwijl er nog een lokale kaartvraag openstond, laat de oude partij niet meer meespelen")
    func overschakelenNaarGastModusOverschrijftNietMeer() async {
        let gast = losModel()
        defer { gast.stop() }
        gast.start(zaad: 999)
        let kaartvraagOpen = await speelLokaalTot({ gast.modus == .kiesKaart }, gast)
        #expect(kaartvraagOpen, "de gast kwam nooit bij een openstaande kaartvraag — kan de rest niet bewijzen")
        guard kaartvraagOpen else { return }

        let gastheer = losModel()
        defer { gastheer.stop() }
        let (lijnGastheer, lijnGast) = LusLijn.paar()
        async let opzetGastheer = DuoOpzet.alsGastheer(lijn: lijnGastheer, appversie: "test", naam: "gastheer")
        async let opzetGast = DuoOpzet.alsGast(lijn: lijnGast, appversie: "test", naam: "gast")
        _ = await (opzetGastheer, opzetGast)

        gastheer.startDuoAlsGastheer(lijn: lijnGastheer, partnerNaam: "gast")
        // Precies op het moment dat de gast nog een openstaande lokale
        // kaartvraag had: overschakelen. Zie de aantekening hierboven.
        gast.startDuoAlsGast(lijn: lijnGast, partnerNaam: "gastheer")

        // Bedien allebei de kanten blind, zoals `heelSpelKomtTotHetEind` —
        // inclusief de gast, die zonder deze reparatie een verweesde,
        // zichzelf in leven houdende oude partij te zien zou krijgen in
        // plaats van de echte partij van de gastheer. 8000 in plaats van
        // 4000: zie de aantekening bij `heelSpelKomtTotHetEind`.
        let klaar = await speelTot({ gastheer.view.spelUit && gast.view.spelUit },
                                   gastheer, gast, pogingen: 8000)
        #expect(klaar, "het spel kwam niet op tijd tot het eind — gastheer.modus=\(gastheer.modus) slagNr=\(gastheer.view.slagNr), gast.modus=\(gast.modus) slagNr=\(gast.view.slagNr)")
        guard klaar else { return }

        #expect(gastheer.view.totaalZuid == gast.view.totaalZuid)
        #expect(gastheer.view.totaalNoord == gast.view.totaalNoord)
    }

    /// Ed na de eerste geslaagde partij: "jouw beurt klopt ook niet op een
    /// scherm. Dat moet dan zijn 'Zijn beurt'." Oorzaak: `GastheerUi.stuurStand`
    /// kopieerde de statustekst van de gastheer letterlijk naar de gast, en
    /// zijn eigen scherm liet bij het wachten op de gast gewoon de tekst van
    /// zijn vorige eigen beurt staan. Deze proef bewijst dat de tekst nu voor
    /// beide schermen klopt: "Jouw beurt" alleen bij wie echt aan zet is,
    /// "Zijn beurt" bij de ander — nooit allebei tegelijk hetzelfde.
    @Test("Op elk scherm staat Jouw beurt alleen bij wie aan zet is, Zijn beurt bij de ander")
    func statusTekstKloptOpBeideSchermen() async {
        let gastheer = losModel()
        let gast = losModel()
        defer { gastheer.stop(); gast.stop() }

        let (lijnGastheer, lijnGast) = LusLijn.paar()
        async let opzetGastheer = DuoOpzet.alsGastheer(lijn: lijnGastheer, appversie: "test", naam: "gastheer")
        async let opzetGast = DuoOpzet.alsGast(lijn: lijnGast, appversie: "test", naam: "gast")
        _ = await (opzetGastheer, opzetGast)

        gastheer.startDuoAlsGastheer(lijn: lijnGastheer, partnerNaam: "gast")
        gast.startDuoAlsGast(lijn: lijnGast, partnerNaam: "gastheer")

        var beurtGastheer = 0, beurtGast = 0
        var gezienGastheerAanZet = false
        var gezienGastAanZet = false
        for _ in 0..<2000 {
            // `gastheer.modus`/`gast.modus` wisselen op hun eigen toestel
            // synchroon met hun eigen `tekst` (`SpelModel.vraagKaart`/
            // `vraagTroef` zetten allebei in dezelfde aanroep). Maar de STAND
            // die de ANDERE kant vertelt "Zijn beurt" reist over `LusLijn` —
            // dat is een aparte, asynchrone taak — dus een korte, begrensde
            // wacht is hier nodig, niet een kale gelijk-op-dit-moment-toets:
            // anders vangt de proef de andere kant soms halverwege die reis.
            if gastheer.modus == .kiesKaart || gastheer.modus == .kiesTroef {
                #expect(gastheer.tekst == Taal.jouwBeurt || gastheer.tekst == Taal.welkeTroef,
                        "gastheer is aan zet maar zijn scherm zegt '\(gastheer.tekst)'")
                let kwamAan = await wachtTot({ gast.tekst == Taal.zijnBeurt })
                #expect(kwamAan,
                        "gastheer is aan zet maar de gast zag '\(gast.tekst)' in plaats van '\(Taal.zijnBeurt)'")
                gezienGastheerAanZet = true
            }
            if gast.modus == .kiesKaart || gast.modus == .kiesTroef {
                #expect(gast.tekst == Taal.jouwBeurt || gast.tekst == Taal.welkeTroef,
                        "gast is aan zet maar zijn scherm zegt '\(gast.tekst)'")
                let kwamAan = await wachtTot({ gastheer.tekst == Taal.zijnBeurt })
                #expect(kwamAan,
                        "gast is aan zet maar de gastheer zag '\(gastheer.tekst)' in plaats van '\(Taal.zijnBeurt)'")
                gezienGastAanZet = true
            }
            if gezienGastheerAanZet && gezienGastAanZet { break }
            speelEenZetAlsGevraagd(gastheer, &beurtGastheer)
            speelEenZetAlsGevraagd(gast, &beurtGast)
            try? await Task.sleep(for: .milliseconds(2))
        }
        #expect(gezienGastheerAanZet, "de gastheer kwam nooit zelf aan zet — kan de rest niet bewijzen")
        #expect(gezienGastAanZet, "de gast kwam nooit aan zet — kan de rest niet bewijzen")
    }

    /// Ed, in dezelfde melding als de vorige twee: "Slag 1 voor Noord moest
    /// zijn Slag 1 voor Zuid. Geldt voor alle slagen." Oorzaak:
    /// `GastheerUi.stuurStand` stuurde de meldingtekst van elke afgelopen slag
    /// ("Slag N voor Zuid/Noord", en bij de laatste slag van een spel ook nog
    /// de spelUitslag erachteraan) letterlijk door — die komt uit `KjSpel`/
    /// `KjEngine`, die alleen de vaste (absolute) kant van de gastheer kennen.
    /// Deze proef bewijst dat de gast nu precies het omgewisselde woord ziet
    /// van wat de gastheer zelf ziet, voor meerdere slagen — alleen de
    /// gastheer stuurt door (`benIkAanZet` is hier niet aan de orde, dit gaat
    /// over de uitslagtekst zelf, niet over wiens beurt het is).
    @Test("De slaguitslag toont Zuid/Noord verwisseld op het scherm van de gast")
    func slagUitslagKloptOpBeideSchermen() async {
        let gastheer = losModel()
        let gast = losModel()
        defer { gastheer.stop(); gast.stop() }

        let (lijnGastheer, lijnGast) = LusLijn.paar()
        async let opzetGastheer = DuoOpzet.alsGastheer(lijn: lijnGastheer, appversie: "test", naam: "gastheer")
        async let opzetGast = DuoOpzet.alsGast(lijn: lijnGast, appversie: "test", naam: "gast")
        _ = await (opzetGastheer, opzetGast)

        gastheer.startDuoAlsGastheer(lijn: lijnGastheer, partnerNaam: "gast")
        gast.startDuoAlsGast(lijn: lijnGast, partnerNaam: "gastheer")

        var beurtGastheer = 0, beurtGast = 0
        var gecontroleerd = 0
        // Ruim boven wat drie slagen (van de acht) normaal kost: onder
        // belasting van de rest van de testrun (`swift test` draait andere
        // suites hiernaast) bleek 3000 pogingen een keer net niet genoeg —
        // dezelfde soort ruis als bij `PauzeTests.gewoonPaneelWerktElkeSlagBij`.
        for _ in 0..<8000 {
            // `.verder` is alleen ooit de eigen modus van de gastheer (de gast
            // wacht bij een slaguitslag altijd passief, zie `pasGastStandToe`)
            // — precies het moment waarop `gastheer.tekst` de rauwe
            // meldingtekst van de zojuist afgelopen slag is.
            //
            // Niet op `Taal.engels` afgaan om te kiezen welk woordpaar het is:
            // dat is een globale, procesbrede vlag (`Taal.swift`) die
            // `TaalTests`/`ObservatieTests` ook omzetten, en Swift Testing
            // draait andere suites gelijktijdig met deze — die kan dus
            // ONDERWEG omslaan. Vandaar hieronder alle vier de woorden
            // beproeven in plaats van er één te kiezen: dat maakt deze proef
            // onafhankelijk van welke taal er toevallig net actief is.
            if gastheer.modus == .verder,
               let verwacht = Self.metZuidNoordOmgewisseld(gastheer.tekst) {
                let kwamAan = await wachtTot({ gast.tekst == verwacht })
                #expect(kwamAan,
                        "gastheer zag '\(gastheer.tekst)', de gast had '\(gast.tekst)' in plaats van '\(verwacht)'")
                gecontroleerd += 1
                if gecontroleerd >= 3 { break }
            }
            speelEenZetAlsGevraagd(gastheer, &beurtGastheer)
            speelEenZetAlsGevraagd(gast, &beurtGast)
            try? await Task.sleep(for: .milliseconds(2))
        }
        #expect(gecontroleerd >= 3, "te weinig slaguitslagen gezien om dit te bewijzen (\(gecontroleerd))")
    }

    /// `nil` als geen van beide woordparen in de tekst voorkomt, anders de
    /// tekst met dat paar omgewisseld — ongeacht welke taal actief is (zie de
    /// aantekening bij de aanroep hierboven).
    private static func metZuidNoordOmgewisseld(_ tekst: String) -> String? {
        for (a, b) in [("Zuid", "Noord"), ("South", "North")] {
            guard tekst.contains(a) || tekst.contains(b) else { continue }
            let tussenwaarde = "\u{0}"
            return tekst
                .replacingOccurrences(of: a, with: tussenwaarde)
                .replacingOccurrences(of: b, with: a)
                .replacingOccurrences(of: tussenwaarde, with: b)
        }
        return nil
    }

    /// Ed's antwoord op de vraag of "demo" ook in samenspel kan werken: "with
    /// a demo mode ran by two computers the BLE communication and game
    /// performance can be tested easily." `demo` bij de gastheer zet `s.comp`,
    /// en dat slaat `mens` voor BEIDE kanten over
    /// (`!s.comp && s.mensIsAanZet(...)` in `KjEngine+Ai.swift`/`KjSpel.swift`)
    /// — dus zonder dat `GastheerUi.kiesKaart`/`kiesTroef` ooit worden
    /// aangeroepen, en dus zonder het race-risico dat een over de lijn
    /// gestuurd "speel voor mij"-bericht tijdens een al openstaande vraag zou
    /// geven.
    ///
    /// `demo` alleen laat nog wel bij elke slaguitslag op een tik wachten
    /// (`SpelModel.vraagVerder`, hetzelfde in samenspel als bij één toestel)
    /// — dat is een apart, al bestaand schakelaartje (`automatisch`), geen
    /// nieuw gedrag hiervan. Voor een écht handenvrije proef staan hier dus
    /// beide aan. Ook geen `spelUit` afwachten hier: bij 450 ms per kaart
    /// (`SpelModel.demoPauze`) plus 900 ms per slag duurt een heel spel van
    /// acht slagen ruim twintig seconden — voor deze proef is genoeg dat de
    /// eerste slag vanzelf rondkomt, zonder ooit een tikvraag.
    @Test("demo (met automatisch) bij de gastheer laat de computer beide kanten spelen, zonder tikvraag")
    func demoLaatComputerBeideKantenSpelen() async {
        let gastheer = losModel()
        let gast = losModel()
        defer { gastheer.stop(); gast.stop() }

        let (lijnGastheer, lijnGast) = LusLijn.paar()
        async let opzetGastheer = DuoOpzet.alsGastheer(lijn: lijnGastheer, appversie: "test", naam: "gastheer")
        async let opzetGast = DuoOpzet.alsGast(lijn: lijnGast, appversie: "test", naam: "gast")
        _ = await (opzetGastheer, opzetGast)

        gastheer.demo = true
        gastheer.automatisch = true
        gastheer.startDuoAlsGastheer(lijn: lijnGastheer, partnerNaam: "gast")
        gast.startDuoAlsGast(lijn: lijnGast, partnerNaam: "gastheer")

        var nooitGetikt = true
        var eersteSlagRond = false
        for _ in 0..<3000 {
            if gastheer.view.slagNr >= 2 && gast.view.slagNr >= 2 { eersteSlagRond = true; break }
            if gastheer.modus == .kiesKaart || gastheer.modus == .kiesTroef || gastheer.modus == .verder ||
               gast.modus == .kiesKaart || gast.modus == .kiesTroef || gast.modus == .verder {
                nooitGetikt = false
                break
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(nooitGetikt, "de computer speelde niet alles zelf — er kwam ergens een tikvraag")
        #expect(eersteSlagRond,
                "de eerste slag kwam niet vanzelf rond — gastheer.modus=\(gastheer.modus), gast.modus=\(gast.modus)")
    }

    /// Ed na de eerste echte partij over BLE: "als de verbinding wegvalt kan
    /// je niet opnieuw verbinden en het spel vervolgen... dan maar een nieuw
    /// spel beginnen. Dat werkt nu goed als je de app opnieuw start.
    /// Waarschijnlijk gaat dat fout als de app niet volledig wordt
    /// afgesloten. 1) de knop Nieuw spel is nu verdwenen. 2) Bij openen
    /// nieuwe verbinding alles goed resetten."
    ///
    /// Twee samenhangende oorzaken, allebei zonder dat er een foutmelding
    /// verscheen:
    /// - `SpelModel.startDuoAlsGastheer`/`startDuoAlsGast` kregen tot nu toe
    ///   het smallere `DuoLijn` binnen — dat kent geen `stop()`, dus de echte
    ///   `CBPeripheralManager`/`CBCentralManager` werd bij `SpelModel.stop()`
    ///   nooit afgesloten en bleef adverteren/scannen, wat een volgende
    ///   verbindingspoging blokkeerde (alleen een app-herstart hielp, want
    ///   dat doodt het hele proces).
    /// - Niemand luisterde na de overdracht door `VerbindScherm` nog naar de
    ///   status van de radio, dus een weggevallen verbinding werd door
    ///   `SpelModel` nooit opgemerkt: `duoKoppeling` bleef staan, dus
    ///   `inSamenspel` ook, dus "Nieuw spel" bleef verstopt.
    ///
    /// Deze proef bootst een wegval na met `WisselbareRadio.laatVallen()` en
    /// bewijst dat: (1) de partij vanzelf stopt (`inSamenspel` weer `false`,
    /// "Nieuw spel" dus weer zichtbaar), (2) de oude radio daadwerkelijk
    /// `stop()` kreeg, en (3) een DAARNA gestarte nieuwe verbinding — precies
    /// wat Ed als voldoende omschreef, geen automatisch hervatten — gewoon
    /// weer een partij kan beginnen.
    @Test("Een weggevallen verbinding stopt de partij en laat een nieuwe verbinding weer toe")
    func verbindingWegvalHerstelt() async {
        let gastheer = losModel()
        defer { gastheer.stop() }

        let (oudeLijnGastheer, _) = LusLijn.paar()
        let oudeRadio = WisselbareRadio(oudeLijnGastheer)
        gastheer.startDuoAlsGastheer(lijn: oudeRadio, partnerNaam: "gast")
        #expect(gastheer.inSamenspel, "moet nu in samenspel zitten — anders bewijst de rest niets")

        var wegviel = false
        for _ in 0..<200 {
            await oudeRadio.laatVallen()
            if !gastheer.inSamenspel { wegviel = true; break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(wegviel, "na het wegvallen van de verbinding moet inSamenspel weer false worden")
        #expect(gastheer.tekst == Taal.duoVerbindingVerbroken,
                "het scherm moet zeggen dat de verbinding weg is, niet stil de laatste tekst laten staan")
        guard wegviel else { return }

        var oudeGestopt = false
        for _ in 0..<200 {
            if await oudeRadio.gestopt { oudeGestopt = true; break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(oudeGestopt,
                "de oude radio moet écht afgesloten zijn — anders blokkeert hij de volgende verbinding")

        // En nu, zoals Ed zou doen: gewoon opnieuw verbinden.
        let gast = losModel()
        defer { gast.stop() }
        let (nieuweLijnGastheer, nieuweLijnGast) = LusLijn.paar()
        async let opzetGastheer = DuoOpzet.alsGastheer(lijn: nieuweLijnGastheer, appversie: "test", naam: "gastheer")
        async let opzetGast = DuoOpzet.alsGast(lijn: nieuweLijnGast, appversie: "test", naam: "gast")
        _ = await (opzetGastheer, opzetGast)

        gastheer.startDuoAlsGastheer(lijn: nieuweLijnGastheer, partnerNaam: "gast")
        gast.startDuoAlsGast(lijn: nieuweLijnGast, partnerNaam: "gastheer")

        let troefKlaar = await speelTot({ gastheer.view.troef != 999 && gast.view.troef == gastheer.view.troef },
                                        gastheer, gast, pogingen: 500)
        #expect(troefKlaar, "na een weggevallen verbinding moet een nieuwe verbinding gewoon weer werken")
    }

    /// Ed, na het beproeven van `demo` + samenspel: "als de verbinding
    /// verbroken word speelde in demo de master gewoon door. Hij zou dan ook
    /// moeten stoppen met een melding 'Verbinding verbroken'. Op de slave
    /// moet de melding ook komen." Op echte hardware merkt elke kant een
    /// wegval onafhankelijk op zijn eigen radio (`didDisconnectPeripheral`
    /// voor de gast, `didUnsubscribeFrom` voor de gastheer) — deze proef
    /// bootst dat na door BEIDE kanten van de lijn apart te laten "wegvallen"
    /// en bewijst dat allebei de schermen `Taal.duoVerbindingVerbroken` laten
    /// zien, niet alleen `inSamenspel` stilzwijgend op `false` zetten.
    /// Ed: "de idee was dat de master, de opensteller, de score opslaat.
    /// Maar als er gewisseld wordt van master dan gaat het fout." Deze proef
    /// bootst precies dat na: apparaat A hostte sessie 1 (en won 3 partijen
    /// tegen B's 1), maar in sessie 2 host **B** — en toch moet de score bij
    /// het juiste fysieke apparaat blijven staan, niet omgedraaid worden
    /// alleen omdat de tafelpositie (Zuid/Noord) nu andersom ligt.
    @Test("Score blijft bij het juiste apparaat, ook als de gastheer-rol wisselt")
    @MainActor
    func rolwisselHoudtScoreBijHetJuisteApparaat() async {
        let plaatsA = Bewaarplaats(opslag: Kladkast())
        let plaatsB = Bewaarplaats(opslag: Kladkast())

        // Sessie 1 (hier niet echt gespeeld, alleen het resultaat neergezet):
        // A was gastheer (dus Zuid, 3 partijen), B was gast (dus Noord, 1
        // partij). A's eigen emmer staat al in A's kant-orde (geen wissel
        // nodig, A was zelf Zuid); B's eigen emmer is de omgewisselde versie
        // (B was Noord) — precies wat `bewaarAlsHetTijdIs` zelf ook zou doen.
        var uitslagSessie1 = Statistiek()
        uitslagSessie1.partijen = [3, 1]   // [Zuid=A, Noord=B]
        plaatsA.schrijfDuo(uitslagSessie1, partner: "B")
        plaatsB.schrijfDuo(uitslagSessie1.kantenOmgewisseld, partner: "A")

        // Sessie 2: ditmaal is B de gastheer.
        let modelA = SpelModel(bewaarplaats: plaatsA)
        let modelB = SpelModel(bewaarplaats: plaatsB)
        defer { modelA.stop(); modelB.stop() }

        let (lijnB, lijnA) = LusLijn.paar()
        async let opzetB = DuoOpzet.alsGastheer(lijn: lijnB, appversie: "test", naam: "B",
                                                eigenTellingen: modelB.alleBewaardeDuoTellingen())
        async let opzetA = DuoOpzet.alsGast(lijn: lijnA, appversie: "test", naam: "A",
                                            eigenTellingen: modelA.alleBewaardeDuoTellingen())
        let (resultaatB, resultaatA) = await (opzetB, opzetA)

        // De kern van de proef: B's eigen 1 partij hoort op Zuid (index 0,
        // want B is nu Zuid) te staan, A's 3 op Noord — niet omgedraaid.
        guard case .klaar(let naamVoorB, let statVoorB) = resultaatB else {
            Issue.record("begroeting bij B (gastheer) niet gelukt: \(resultaatB)")
            return
        }
        guard case .klaar(let naamVoorA, let statVoorA) = resultaatA else {
            Issue.record("begroeting bij A (gast) niet gelukt: \(resultaatA)")
            return
        }
        #expect(naamVoorB == "A")
        #expect(naamVoorA == "B")
        #expect(statVoorB.partijen == [1, 3], "B (nu Zuid) moet zijn eigen 1 partij op Zuid zien, A's 3 op Noord")
        #expect(statVoorA.partijen == [3, 1], "A (nu Noord) moet zijn eigen 3 partijen op Zuid zien, B's 1 op Noord")

        modelB.startDuoAlsGastheer(lijn: lijnB, partnerNaam: naamVoorB, beginStatistiek: statVoorB)
        modelA.startDuoAlsGast(lijn: lijnA, partnerNaam: naamVoorA, beginStatistiek: statVoorA)

        // En de twee apparaten moeten het na het verbinden weer roerend eens
        // zijn — elk in zijn eigen kant-orde, dus pas na terugwisselen gelijk.
        let vanB = plaatsB.leesDuo(partner: "A")
        let vanA = plaatsA.leesDuo(partner: "B")
        #expect(vanB != nil && vanA != nil)
        if let vanB, let vanA {
            #expect(vanB == vanA.kantenOmgewisseld,
                    "de emmers van A en B voor elkaar horen, omgewisseld, weer gelijk te zijn")
        }
    }

    @Test("Bij een wegval krijgen zowel gastheer als gast de melding Verbinding verbroken")
    func verbindingVerbrokenMeldingBeideKanten() async {
        let gastheer = losModel()
        let gast = losModel()
        defer { gastheer.stop(); gast.stop() }

        let (lijnGastheer, lijnGast) = LusLijn.paar()
        let radioGastheer = WisselbareRadio(lijnGastheer)
        let radioGast = WisselbareRadio(lijnGast)

        async let opzetGastheer = DuoOpzet.alsGastheer(lijn: radioGastheer, appversie: "test", naam: "gastheer")
        async let opzetGast = DuoOpzet.alsGast(lijn: radioGast, appversie: "test", naam: "gast")
        _ = await (opzetGastheer, opzetGast)

        gastheer.startDuoAlsGastheer(lijn: radioGastheer, partnerNaam: "gast")
        gast.startDuoAlsGast(lijn: radioGast, partnerNaam: "gastheer")
        #expect(gastheer.inSamenspel && gast.inSamenspel, "moeten allebei in samenspel zitten — anders bewijst de rest niets")

        var gastheerGoed = false, gastGoed = false
        for _ in 0..<200 {
            await radioGastheer.laatVallen()
            await radioGast.laatVallen()
            if gastheer.tekst == Taal.duoVerbindingVerbroken { gastheerGoed = true }
            if gast.tekst == Taal.duoVerbindingVerbroken { gastGoed = true }
            if gastheerGoed && gastGoed { break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(gastheerGoed, "de gastheer moet 'Verbinding verbroken' laten zien, niet gewoon doorspelen")
        #expect(gastGoed, "de gast moet 'Verbinding verbroken' laten zien")
    }
}
