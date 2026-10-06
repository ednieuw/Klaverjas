import Testing
import Foundation
@testable import KlaverjasKit

/// Wat de speler te horen krijgt als hij een kaart kiest die niet mag.
///
/// Twee dingen die misgingen: een tik op de verkeerde stapel leverde helemaal
/// geen tekst op (het scherm hield de tik tegen, zie `SpelModel.neemtTik`), en
/// een klacht die er eenmaal stond bleef er de rest van het spel staan — bij
/// elke volgende kaart weer, tot en met de laatste slag.
struct FoutmeldingTests {
    /// Een speler die op afroep een kaart van de verkeerde stapel aantikt en
    /// verder altijd iets speelt wat mag.
    ///
    /// Houdt de motor vast om zelf een geldige kaart te kunnen zoeken. Dat mag:
    /// `kiesKaart` wordt alleen vanuit de speeltaak aangeroepen, dus er is nooit
    /// iemand anders tegelijk in die toestand bezig.
    private final class Speler: KjUi, @unchecked Sendable {
        private let slot = NSLock()
        private var e: KjEngine?
        private var _meldingen: [String] = []
        /// De twee teksten voor "verkeerde stapel", gelezen op hetzelfde moment
        /// als de melding. `Taal.engels` is gedeeld en een andere proef kan hem
        /// ondertussen omzetten; dan vergelijk je Nederlands met Engels.
        private var _verwacht: [(String, String)] = []
        private var vragen = 0
        private var _misBijVraag: Int?

        /// Bij welke vraag er naast gegrepen is (0-gebaseerd).
        ///
        /// Niet van tevoren vastgelegd maar gekozen op het moment dat het nut
        /// heeft: bij `slagKrtNo == 1` ligt de stapel vast én komt er in
        /// dezelfde slag nog een vraag. Grijp je aan het eind van een slag mis,
        /// dan wist de slaguitslag de klacht toch al — en dan bewijst de proef
        /// niets.
        var misBijVraag: Int? { slot.withLock { _misBijVraag } }

        init() {}

        /// De motor komt pas nadat `KjSpel` gemaakt is; die wil dit scherm al
        /// bij zijn eigen aanmaak hebben.
        func koppel(_ motor: KjEngine) { slot.withLock { e = motor } }

        var meldingen: [String] { slot.withLock { _meldingen } }
        var verwacht: [(String, String)] { slot.withLock { _verwacht } }
        /// Geen geldige kaart meer kunnen vinden: dan is er iets grondig mis en
        /// moet de proef stoppen in plaats van eeuwig door te draaien.
        var vastgelopen: Bool { slot.withLock { _vastgelopen } }
        private var _vastgelopen = false

        func toon(_ view: SpelView) async {}
        func kiesTroef(_ view: SpelView) async -> Int { 0 }
        func verder(_ view: SpelView, _ tekst: String) async {}

        func kiesKaart(_ view: SpelView) async -> (naam: Teken, kleur: Int) {
            slot.withLock {
                _meldingen.append(view.melding)
                _verwacht.append((Taal.kaartLigtOpTafel, Taal.kaartZitInHand))
                vragen += 1
                if _misBijVraag == nil, e?.s.slagKrtNo == 1,
                   let mis = verkeerdeStapel() {
                    _misBijVraag = vragen - 1
                    return mis
                }
                if let goed = geldige() { return goed }
                _vastgelopen = true
                return (.nul, 0)
            }
        }

        /// Een kaart van de stapel die nu juist níet aan zet is.
        private func verkeerdeStapel() -> (naam: Teken, kleur: Int)? {
            guard let e else { return nil }
            let s = e.s
            guard s.slagKrtNo > 0 else { return nil }   // bij uitkomen mag allebei
            let anders = (s.vrager == Pos.handZuid) ? Pos.tafelZuid : Pos.handZuid
            for n in 0..<32 where s.kaart[n].dichtIkHy == anders {
                return (s.kaart[n].naam, s.kaart[n].kleur)
            }
            return nil
        }

        /// De eerste kaart van de eigen stapel die de regelcontrole goedkeurt.
        private func geldige() -> (naam: Teken, kleur: Int)? {
            guard let e else { return nil }
            let s = e.s
            let bewaardK = s.lkaart, bewaardC = s.lkleur
            defer { s.lkaart = bewaardK; s.lkleur = bewaardC }
            for n in 0..<32 {
                let k = s.kaart[n]
                let vanMij = s.slagKrtNo == 0
                    ? (k.dichtIkHy == Pos.handZuid || k.dichtIkHy == Pos.tafelZuid)
                    : (k.dichtIkHy == s.vrager)
                guard vanMij else { continue }
                s.lkaart = k.naam
                s.lkleur = k.kleur
                if e.checkValid() == nil { return (k.naam, k.kleur) }
            }
            return nil
        }
    }

    /// Achter `Taalslot`: de motor zet `melding` op grond van `Taal.engels`
    /// vóórdat `kiesKaart` hem doorgeeft, en `_verwacht` leest diezelfde
    /// schakelaar opnieuw uit zodra `kiesKaart` aangeroepen wordt — dat zijn
    /// twee losse momenten. Zet een andere proef `Taal.engels` daartussen om
    /// (`TaalTests`, `ObservatieTests`), dan vergelijkt deze proef Nederlands
    /// met Engels. Het slot sluit dat gat voor de hele speelduur.
    private func speel(vragen: Int) async
        -> (meldingen: [String], verwacht: [(String, String)], mis: Int) {
        await Taalslot.metSlot {
            let ui = Speler()
            let spel = KjSpel(ui: ui, zaad: 3, instellingen: { Instellingen(demo: false) })
            ui.koppel(spel.e)

            let taak = Task.detached { await spel.loop() }
            while ui.meldingen.count < vragen && !ui.vastgelopen {
                try? await Task.sleep(for: .milliseconds(5))
            }
            taak.cancel()
            _ = await taak.value

            #expect(!ui.vastgelopen, "geen geldige kaart meer kunnen vinden")
            let mis = ui.misBijVraag
            #expect(mis != nil, "er is nooit naast gegrepen; de proef meet dan niets")
            return (ui.meldingen, ui.verwacht, mis ?? 0)
        }
    }

    @Test("Een kaart van de verkeerde stapel levert een tekst op")
    func verkeerdeStapelMeldt() async {
        let (m, verwacht, mis) = await speel(vragen: 8)
        // De vraag ná de misgreep is dezelfde vraag opnieuw, nu met de klacht.
        #expect(m.count > mis + 1)
        let (opTafel, inHand) = verwacht[mis + 1]
        #expect(m[mis + 1] == opTafel || m[mis + 1] == inHand,
                "de verkeerde stapel leverde geen tekst op maar \"\(m[mis + 1])\"")
    }

    @Test("De melding verdwijnt zodra er goed gespeeld is")
    func meldingVerdwijnt() async {
        let (m, _, mis) = await speel(vragen: 10)
        let klacht = m[mis + 1]
        #expect(!klacht.isEmpty, "de klacht ontbrak")

        // Daarna speelt hij wél iets wat mag. Wat er vervolgens in de regel
        // staat mag van alles zijn — na een slag hoort de uitslag daar juist te
        // staan — maar de klacht mag niet terugkomen. De eerstvolgende vraag zit
        // nog in dezelfde slag, dus daar is geen uitslag die hem wegpoetst.
        for i in (mis + 2)..<m.count {
            #expect(m[i] != klacht,
                    "bij vraag \(i + 1) stond de oude klacht er nog: \"\(m[i])\"")
        }
    }
}
