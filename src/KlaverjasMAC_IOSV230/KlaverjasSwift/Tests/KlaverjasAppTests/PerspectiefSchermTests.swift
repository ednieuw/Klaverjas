import Testing
import Foundation
@testable import KlaverjasApp
@testable import KlaverjasKit

/// `SpelModel.magKlikken(_:)` volgt het perspectief uit `SpelView.mijnKant`
/// (B5 uit het bluetooth-plan): welke rij oplicht hoort bij wie op dit
/// toestel speelt, niet hardgecodeerd bij Zuid.
// Met een tijdslimiet: deze proeven wachten op een doorgeefluik dat het
// model hoort los te maken. Blijft dat uit, dan hangt de proef in plaats van
// te zakken.
@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct PerspectiefSchermTests {
    /// Eén kaart op tafel, zodat `v.slag` niet leeg is — bij een lege slag
    /// (uitkomen) lichten toch al beide eigen rijen op, en zou deze proef
    /// niets onderscheiden.
    private func nietLegeSlag() -> [SlagView] {
        [SlagView(kleur: 0, naam: "A", speler: Pos.handZuid, tactiek: 0)]
    }

    @Test("Met mijnKant = 2 licht Noords rij op, niet Zuids")
    func noordsRijLichtOp() async {
        let model = losModel()
        defer { model.stop() }

        let eigenKaart = KaartView()
        var v = SpelView()
        v.mijnKant = 2
        v.slag = nietLegeSlag()
        v.aanZet = Pos.handNoord
        v.handNoord = [eigenKaart]

        async let gevraagd = model.vraagKaart(v)
        await Task.yield()

        #expect(model.magKlikken(true), "Noords hand moet oplichten, dat is nu mijn kant")
        #expect(!model.magKlikken(false), "Noords tafel is niet aan zet, de hand wel")

        model.klik(eigenKaart)
        _ = await gevraagd
    }

    @Test("Met mijnKant = 1 (standaard) blijft het oude Zuid-gedrag")
    func zuidsRijLichtOpStandaard() async {
        let model = losModel()
        defer { model.stop() }

        let eigenKaart = KaartView()
        var v = SpelView()
        v.slag = nietLegeSlag()
        v.aanZet = Pos.handZuid
        v.handZuid = [eigenKaart]

        async let gevraagd = model.vraagKaart(v)
        await Task.yield()

        #expect(model.magKlikken(true))
        #expect(!model.magKlikken(false))

        model.klik(eigenKaart)
        _ = await gevraagd
    }

    @Test("Met mijnKant = 2 licht Zuids rij niet meer op, ook al staat aanZet erop")
    func zuidsRijLichtNietOpAlsIkNoordBen() async {
        let model = losModel()

        var v = SpelView()
        v.mijnKant = 2
        v.slag = nietLegeSlag()
        v.aanZet = Pos.handZuid    // Zuid is aan zet — niet wie hier speelt
        v.handNoord = [KaartView()]

        async let gevraagd = model.vraagKaart(v)
        await Task.yield()

        #expect(!model.magKlikken(true), "het is Zuids beurt, niet de mijne")
        #expect(!model.magKlikken(false))

        // Niets om hier op te klikken; `stop()` laat de wachtende vraag los
        // (zie SpelModel.stop()), zodat `gevraagd` niet blijft hangen.
        model.stop()
        _ = await gevraagd
    }
}
