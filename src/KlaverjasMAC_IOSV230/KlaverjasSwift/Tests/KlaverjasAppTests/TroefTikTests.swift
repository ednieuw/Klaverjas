import Testing
import Foundation
@testable import KlaverjasApp
@testable import KlaverjasKit

/// Troef kiezen kan ook door een eigen kaart aan te tikken. De vier knoppen
/// blijven staan, maar met een kaart in beeld is die kaart de kortste weg —
/// precies zoals je aan tafel een kaart omhoog houdt.
// Met een tijdslimiet: deze proeven wachten op een doorgeefluik dat de tik
// hoort los te maken. Blijft dat uit, dan hangt de proef in plaats van te
// zakken — en een toets die hangt zegt niets.
@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct TroefTikTests {
    /// Maakt een kaart zoals de momentopname hem aanlevert.
    private func kaart(kleur: Int, open: Bool = true) -> KaartView {
        var k = KaartView()
        k.kleur = kleur
        k.naam = "A"
        k.open = open
        return k
    }

    @Test("Een tik op een eigen kaart maakt die kleur troef")
    func tikKiestTroef() async {
        let model = losModel()
        defer { model.stop() }

        async let gevraagd = model.vraagTroef(SpelView())
        await Task.yield()
        #expect(model.modus == .kiesTroef)
        #expect(model.neemtTik(), "de tik zou het model niet eens bereiken")

        model.klik(kaart(kleur: 2))
        #expect(await gevraagd == 2, "de kleur van de aangetikte kaart werd geen troef")
        #expect(model.modus == .wachten)
    }

    @Test("Alle vier de kleuren komen zo aan")
    func alleVierKleuren() async {
        for kleur in 0..<4 {
            let model = losModel()
            async let gevraagd = model.vraagTroef(SpelView())
            await Task.yield()
            model.klik(kaart(kleur: kleur))
            #expect(await gevraagd == kleur)
            model.stop()
        }
    }

    @Test("Een dichte kaart kiest geen troef")
    func dichteKaartDoetNiets() async {
        let model = losModel()
        defer { model.stop() }

        async let gevraagd = model.vraagTroef(SpelView())
        await Task.yield()

        // De kaart ligt met de rug naar boven; hem kunnen aanwijzen zou meer
        // verklappen dan het spel toestaat.
        model.klik(kaart(kleur: 0, open: false))
        #expect(model.modus == .kiesTroef, "een dichte kaart koos toch troef")

        model.klik(kaart(kleur: 3))
        #expect(await gevraagd == 3)
    }

    @Test("De knoppen blijven werken")
    func knopWerktNog() async {
        let model = losModel()
        defer { model.stop() }

        async let gevraagd = model.vraagTroef(SpelView())
        await Task.yield()
        model.kiesTroef(1)
        #expect(await gevraagd == 1)
    }

    @Test("Buiten de troefvraag verandert een tik niets aan de troef")
    func geenTroefBuitenDeVraag() async {
        let model = losModel()
        defer { model.stop() }

        // Bij het kiezen van een kaart is een tik gewoon een gelegde kaart.
        async let gelegd = model.vraagKaart(SpelView())
        await Task.yield()
        #expect(model.modus == .kiesKaart)
        model.klik(kaart(kleur: 2))
        let antwoord = await gelegd
        #expect(antwoord.kleur == 2 && antwoord.naam == "A")
    }

    @Test("Beide eigen rijen lichten op tijdens de troefvraag")
    func rijenLichtenOp() async {
        let model = losModel()
        defer { model.stop() }

        #expect(!model.magKlikken(true), "er wordt nog niets gevraagd")

        async let gevraagd = model.vraagTroef(SpelView())
        await Task.yield()
        #expect(model.magKlikken(true), "de hand lichtte niet op")
        #expect(model.magKlikken(false), "de tafel lichtte niet op")

        model.kiesTroef(0)
        _ = await gevraagd
    }
}
