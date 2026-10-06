import Testing
import Foundation
@testable import KlaverjasApp
@testable import KlaverjasKit

/// De tellingen moeten een herstart overleven: op een telefoon veeg je het spel
/// omhoog en dan is een partij naar 1500 anders nooit af te maken.
@Suite(.serialized)
struct BewaarTests {
    /// Een eigen kladkast, zodat een toets niets van de speler aanraakt, twee
    /// toetsen elkaar niet in de weg zitten en er niets op schijf blijft staan.
    private func eigenPlaats() -> (Bewaarplaats, () -> Void) {
        (Bewaarplaats(opslag: Kladkast()), {})
    }

    private func gevuld() -> Statistiek {
        var st = Statistiek()
        st.partijen = [2, 1]
        st.spellen = [37, 41]
        st.kaartpunten = [3120, 2980]
        st.troefpunten = [800, 760]
        st.troefkaarten = [150, 148]
        st.roempunten = [420, 380]
        st.pit = [3, 1]
        st.tegenpit = [1, 0]
        st.nat = [5, 7]
        st.superroem = [2, 1]
        st.totaal = [1240, 990]
        st.tactiek[7] = 61
        st.tactiek[70] = 204
        return st
    }

    @Test("Bewaarde tellingen komen ongeschonden terug")
    func heenEnWeer() {
        let (plaats, opruimen) = eigenPlaats()
        defer { opruimen() }

        #expect(plaats.lees() == nil, "een verse plaats hoort leeg te zijn")

        let st = gevuld()
        plaats.schrijf(st)
        #expect(plaats.lees() == st, "wat eruit komt is niet wat erin ging")

        plaats.wis()
        #expect(plaats.lees() == nil, "na wissen hoort er niets meer te staan")
    }

    @Test("Een bestand van de vorige versie blijft leesbaar")
    func oudBestandBlijftLeesbaar() throws {
        // Zoals het er stond toen de superroem nog één getal was, en zonder de
        // velden die er later bij kwamen. Wie dit niet aankan, wist bij het
        // bijwerken stilletjes de hele telling van de speler.
        let oud = """
        {"partijen":[2,1],"spellen":[37,41],"kaartpunten":[3120,2980],
         "troefpunten":[800,760],"troefkaarten":[150,148],"roempunten":[420,380],
         "pit":[3,1],"tegenpit":[1,0],"nat":[5,7],"superroem":2,
         "totaal":[1240,990],"tactiek":[0,0,0]}
        """
        let st = try JSONDecoder().decode(Statistiek.self, from: Data(oud.utf8))

        #expect(st.spellen == [37, 41])
        #expect(st.totaal == [1240, 990])
        #expect(st.superroem == [2, 0], "de oude superroem ging verloren")
        #expect(st.tactiek.count == 80, "de tactieklijst is niet aangevuld")
        #expect(!st.leeg)
    }

    @Test("Een onvolledig bestand kost niet de hele telling")
    func onvolledigBestand() throws {
        let mager = #"{"spellen":[5,3]}"#
        let st = try JSONDecoder().decode(Statistiek.self, from: Data(mager.utf8))
        #expect(st.spellen == [5, 3])
        #expect(st.partijen == [0, 0])
        #expect(st.superroem == [0, 0])
        #expect(st.tactiek.count == 80)
    }

    @Test("De motor begint met de tellingen van de vorige keer")
    func motorNeemtOver() {
        let st = gevuld()
        let e = KjEngine(zaad: 1)
        e.s.zetStatistiek(st)
        #expect(e.s.statistiek == st, "de motor gaf andere tellingen terug dan hij kreeg")
    }

    @Test("Een oud bestand met een kortere tactieklijst breekt niets")
    func kortereLijst() {
        var st = Statistiek()
        st.spellen = [5, 3]
        st.tactiek = [0, 9, 4]          // veel korter dan de 80 van nu
        let e = KjEngine(zaad: 1)
        e.s.zetStatistiek(st)
        #expect(e.s.tac.count == 80)
        #expect(e.s.tac[1] == 9)
        #expect(e.s.tac[2] == 4)
        #expect(e.s.tac[79] == 0)
    }

    @Test("Aan het eind van een spel wordt er weggeschreven")
    @MainActor
    func schrijftNaEenSpel() {
        let (plaats, opruimen) = eigenPlaats()
        defer { opruimen() }
        let model = SpelModel(bewaarplaats: plaats)

        var v = SpelView()
        v.statistiek = gevuld()
        v.spelUit = true
        model.toon(v)

        #expect(plaats.lees() == gevuld(), "het einde van een spel werd niet bewaard")
    }

    @Test("Een leeg spel schrijft niets weg")
    @MainActor
    func schrijftNietsAlsErNietsIs() {
        let (plaats, opruimen) = eigenPlaats()
        defer { opruimen() }
        let model = SpelModel(bewaarplaats: plaats)

        var v = SpelView()
        v.spelUit = true                 // maar geen enkel spel gespeeld
        model.toon(v)

        #expect(plaats.lees() == nil, "er stond niets te bewaren en toch is er geschreven")
    }

    @Test("Bewaarde duo-tellingen komen ongeschonden terug, per partner los")
    func duoHeenEnWeer() {
        let (plaats, opruimen) = eigenPlaats()
        defer { opruimen() }

        #expect(plaats.leesAlleDuo().isEmpty, "een verse plaats hoort geen duo-tellingen te hebben")
        #expect(plaats.leesDuo(partner: "iPhone") == nil)

        let stIphone = gevuld()
        var stMac = gevuld()
        stMac.spellen = [9, 2]
        plaats.schrijfDuo(stIphone, partner: "iPhone")
        plaats.schrijfDuo(stMac, partner: "Mac")

        #expect(plaats.leesDuo(partner: "iPhone") == stIphone)
        #expect(plaats.leesDuo(partner: "Mac") == stMac)
        #expect(plaats.leesAlleDuo().count == 2, "twee partners horen twee losse emmers te geven")
    }

    @Test("De duo-emmer en de solo-sleutel raken elkaar niet")
    func duoEnSoloBlijvenGescheiden() {
        let (plaats, opruimen) = eigenPlaats()
        defer { opruimen() }

        plaats.schrijf(gevuld())
        #expect(plaats.leesAlleDuo().isEmpty, "schrijven op de solo-sleutel mag de duo-emmer niet vullen")

        var duoSt = Statistiek()
        duoSt.spellen = [4, 1]
        plaats.schrijfDuo(duoSt, partner: "iPhone")
        #expect(plaats.lees() == gevuld(), "schrijven in de duo-emmer mag de solo-tellingen niet aanraken")
    }

    @Test("Eén samenspel-partner verwijderen laat de rest staan")
    func duoPartnerWissen() {
        let (plaats, opruimen) = eigenPlaats()
        defer { opruimen() }

        plaats.schrijf(gevuld())
        for naam in ["iPhone", "Mac", "iPad"] {
            var st = gevuld()
            st.spellen = [Int64(naam.count), 1]
            plaats.schrijfDuo(st, partner: naam)
        }

        plaats.wisDuo(partner: "Mac")
        #expect(Set(plaats.leesAlleDuo().keys) == ["iPhone", "iPad"], "alleen Mac hoorde te verdwijnen")
        #expect(plaats.leesDuo(partner: "iPhone") != nil && plaats.leesDuo(partner: "iPad") != nil)
        #expect(plaats.lees() == gevuld(), "de solo-tellingen mogen er niet door veranderen")

        plaats.wisDuo(partner: "bestaat niet")          // geen partner, geen gevolg
        #expect(plaats.leesAlleDuo().count == 2)

        plaats.wisDuo(partner: "iPhone")
        plaats.wisDuo(partner: "iPad")
        #expect(plaats.leesAlleDuo().isEmpty, "na de laatste partner hoort de lijst leeg te zijn")
        #expect(plaats.lees() == gevuld())
    }

    @Test("Wissen wist de eigen tellingen en laat de samenspel-partners staan")
    @MainActor
    func wissenWist() {
        let (plaats, opruimen) = eigenPlaats()
        defer { opruimen() }
        let model = SpelModel(bewaarplaats: plaats)

        // Zoals het in het echt gaat: er staat een partij op het scherm en er
        // is al bewaard. Zonder een gevulde momentopname bewijst deze proef
        // niets — het stilzetten van de motor legt de stand namelijk nog één
        // keer vast, en dat mag het wissen niet ongedaan maken.
        var v = SpelView()
        v.statistiek = gevuld()
        v.spelUit = true
        model.toon(v)
        #expect(plaats.lees() != nil, "er had juist wél iets bewaard moeten zijn")
        plaats.schrijfDuo(gevuld(), partner: "iPhone")
        plaats.schrijfDuo(gevuld(), partner: "Mac")

        // Eén partner via het model verwijderen, zoals de prullenbak in het statistiekenscherm doet.
        model.wisDuoPartner("Mac")
        #expect(Set(model.alleBewaardeDuoTellingen().keys) == ["iPhone"], "alleen Mac hoorde te verdwijnen")

        model.wisStatistiek()
        defer { model.stop() }

        #expect(plaats.lees() == nil, "na wissen stond er nog iets in de voorkeuren")
        #expect(Set(plaats.leesAlleDuo().keys) == ["iPhone"],
                "Wissen mag de samenspel-partners niet aanraken; die gaan één voor één weg")
        #expect(model.view.statistiek.leeg, "het scherm toonde de oude tellingen nog")
    }
}
