import Testing
import Foundation
@testable import KlaverjasKit

/// Komt de speelwijze die je in het scherm kiest ook echt in de motor terecht?
///
/// Het toernooi bewijst al dat `zoekt[]` bínnen de motor aan de goede kant hangt:
/// die getallen komen exact overeen met de C#-versie, en daar wisselen de twee
/// spelers per ronde van plek. Wat het toernooi niet raakt is de weg ernaartoe —
/// van de schakelaar in het scherm, via `Instellingen`, naar `s.zoekt`. Dat is
/// wat hier gemeten wordt, aan de echte speelloop en niet aan een nabootsing.
struct SpeelwijzeTests {
    /// Een scherm dat niets doet en onthoudt wat de motor liet zien. De motor
    /// draait op een eigen taak en is van buiten niet te lezen; alles wat we van
    /// hem weten komt uit de momentopname.
    private final class StilleUi: KjUi, @unchecked Sendable {
        private let slot = NSLock()
        private var _spellen = 0
        private var _zoekt = [false, false]
        private var _tac70: Int64 = 0
        private var _gevraagd = false

        var spellen: Int { slot.withLock { _spellen } }
        var zoekt: [Bool] { slot.withLock { _zoekt } }
        var tac70: Int64 { slot.withLock { _tac70 } }
        var gevraagd: Bool { slot.withLock { _gevraagd } }

        func toon(_ view: SpelView) async { onthoud(view) }

        private func onthoud(_ view: SpelView) {
            slot.withLock {
                _zoekt = view.zoekt
                _tac70 = view.statistiek.tactiek[70]
                if view.spelUit { _spellen += 1 }
            }
        }
        func kiesKaart(_ view: SpelView) async -> (naam: Teken, kleur: Int) {
            slot.withLock { _gevraagd = true }
            return (.nul, 0)
        }
        func kiesTroef(_ view: SpelView) async -> Int {
            slot.withLock { _gevraagd = true }
            return 0
        }
        // Het eind van een spel komt via `verder` binnen, niet via `toon`:
        // alleen daar staat `spelUit` aan.
        func verder(_ view: SpelView, _ tekst: String) async { onthoud(view) }
    }

    /// Speelt met de opgegeven instellingen tot er genoeg spellen om zijn.
    /// De motor wordt binnen de taak gemaakt en komt er nooit uit, net als in
    /// de app — daarom loopt alles via het scherm.
    private func speel(_ i: Instellingen, zaad: Int, spellen: Int) async -> StilleUi {
        let ui = StilleUi()
        let taak = Task.detached {
            let spel = KjSpel(ui: ui, zaad: zaad, instellingen: { i })
            await spel.loop()
        }
        // Niet in een strakke lus wachten: dan houdt deze taak de kern bezet en
        // komt de motor er zelf niet aan toe.
        while ui.spellen < spellen { try? await Task.sleep(for: .milliseconds(5)) }
        taak.cancel()
        _ = await taak.value
        return ui
    }

    @Test("De gekozen speelwijze staat in de motor")
    func instellingKomtAan() async {
        for (zuid, noord) in [(false, false), (true, false), (false, true), (true, true)] {
            let ui = await speel(Instellingen(demo: true, zoektZuid: zuid, zoektNoord: noord),
                                 zaad: 5, spellen: 2)
            #expect(ui.zoekt == [zuid, noord],
                    "de motor stond op \(ui.zoekt) terwijl er (\(zuid), \(noord)) gevraagd was")
        }
    }

    @Test("Alleen wie erom vraagt rekent door")
    func alleenDeGekozenKant() async {
        // Tactiek 70 bestaat niet in de vuistregels van 1994; hij komt er
        // uitsluitend als de zoekende speler aan zet is geweest.
        let geen = await speel(Instellingen(demo: true), zaad: 5, spellen: 20)
        #expect(geen.tac70 == 0, "er werd doorgerekend terwijl niemand daarom vroeg")

        let zuid = await speel(Instellingen(demo: true, zoektZuid: true), zaad: 5, spellen: 20)
        #expect(zuid.tac70 > 0, "Zuid rekende niet door")

        let noord = await speel(Instellingen(demo: true, zoektNoord: true), zaad: 5, spellen: 20)
        #expect(noord.tac70 > 0, "Noord rekende niet door")

        let beide = await speel(Instellingen(demo: true, zoektZuid: true, zoektNoord: true),
                                zaad: 5, spellen: 20)
        // Twee kanten leggen samen alle kaarten; één kant hooguit de helft.
        #expect(beide.tac70 > zuid.tac70, "twee zoekers leverden niet meer zetten op dan één")
        #expect(beide.tac70 > noord.tac70)
    }

    @Test("De zoeker speelt nooit de kaarten van de mens")
    func mensGaatVoor() {
        // Buiten demo speelt Zuid zelf. De schakelaar voor Zuid staat dan wel in
        // de motor, maar mag zijn zetten niet overnemen — anders speelt de
        // computer jouw kaarten. Rechtstreeks op de motor, want hier is geen
        // speelloop voor nodig.
        let e = KjEngine(zaad: 5)
        let s = e.s
        s.comp = false                 // Zuid is een mens
        s.zoekt[0] = true              // en heeft toch "doorrekenen" staan
        s.speler = 1
        s.vrager = 1
        s.startVrager = 1
        e.delen()
        for n in 0..<4 { s.tNoord[n] = 1; s.tZuid[n] = 1 }
        e.kaartenVrij()
        e.zetTafelPosities()
        e.vulhanden()
        e.troefBepalen()

        s.slagNr = 1
        s.tactiek = 0
        e.speler1()

        #expect(e.wachtOpMens, "de motor vroeg de mens niet om een kaart")
        #expect(s.tactiek != 70, "de zoeker speelde een kaart voor de mens")
    }
}
