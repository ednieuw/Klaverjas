import Testing
import Foundation
@testable import KlaverjasApp
@testable import KlaverjasKit

/// Snel spelen zonder kaarten: er valt niets te klikken, dus de computer speelt
/// beide kanten en er wordt nergens meer gewacht. En het houdt een keer op.
@Suite(.serialized)
struct SnelTests {
    @Test("Snel spelen zet de demo aan en de kijkpauze uit")
    @MainActor
    func snelWachtNiet() async {
        let model = losModel()
        model.snel = true
        #expect(model.demo, "snel spelen hoort de computer beide kanten te laten spelen")

        // Uit snel spelen komen zet ook de demo weer uit: de speler speelt dan zelf verder.
        model.snel = false
        #expect(!model.demo, "na snel spelen hoort de demo uit te staan")
        model.snel = true

        model.stop()

        // Niet op de klok meten. Deze proef draait naast andere die volle
        // motoren aan het werk hebben, en dan duurt alleen al het overleg met
        // de hoofdtaak soms honderden milliseconden — dat zegt niets over de
        // pauze. De beslissing zelf is eenduidig te lezen.
        #expect(!model.tempo.magPauzeren(),
                "de brug zou nog steeds een kijkpauze inlassen")
    }

    @Test("Snel spelen loopt niet vast op een kaart die niemand kan aantikken")
    @MainActor
    func snelBlijftNietHangen() async {
        let model = losModel()
        defer { model.stop() }

        // Het spel wacht op een kaart van de speler; in het snelscherm zijn de
        // kaarten weg, dus die vraag moet losgelaten worden.
        async let gevraagd: Void = { _ = await model.vraagKaart(SpelView()) }()
        await Task.yield()
        #expect(model.modus == .kiesKaart)

        model.snel = true
        _ = await gevraagd                    // hangt dit, dan valt de toets stil

        #expect(model.demo)
        #expect(model.modus != .kiesKaart, "bleef op een kaart wachten")
    }

    @Test("Snel spelen slaat ook het wachten tussen de slagen over")
    @MainActor
    func snelGaatDoorNaEenSlag() async {
        let model = losModel()
        model.snel = true
        model.stop()

        let begin = ContinuousClock.now
        await model.vraagVerder(SpelView(), "uit")
        let duur = ContinuousClock.now - begin

        #expect(duur < .milliseconds(100), "bleef \(duur) staan wachten")
        #expect(model.modus == .wachten)
    }

    @Test("Bij snel spelen wordt er hooguit een paar keer per seconde getekend")
    @MainActor
    func snelTekentZuinig() async {
        let model = losModel()
        model.snel = true
        model.stop()
        var brug = Brug(model: model, tempo: model.tempo, generatie: model.huidigeGeneratie)

        // De eerste mag, de rest van de golf niet: anders houdt de motor de
        // hoofdtaak bezet en reageert de knop Stoppen niet meer.
        //
        // Elke kaart zijn eigen tekst, niet steeds dezelfde "x": anders is een
        // tweede tekening die toevallig dezelfde waarde zet niet te
        // onderscheiden van geen tekening, en bewijst de proef niets.
        var getekend = 0
        for i in 0..<500 {
            var v = SpelView()
            v.status = "x\(i)"
            let voor = model.view.status
            await brug.toon(v)
            if model.view.status != voor { getekend += 1 }
        }
        #expect(getekend == 1, "tekende \(getekend) keer in plaats van één keer")

        // Zonder snel spelen gaat elke kaart er gewoon doorheen. Een verse
        // `Brug`, net als productiecode altijd doet na `stop()`: die telt
        // een nieuwe generatie (zie `SpelModel.generatie`), dus de oude
        // `brug` hierboven zou vanaf hier terecht niets meer wegschrijven.
        model.snel = false
        model.stop()
        brug = Brug(model: model, tempo: model.tempo, generatie: model.huidigeGeneratie)
        var raak = 0
        for _ in 0..<3 {
            model.zetTekst("")
            var v = SpelView()
            v.status = "y"
            await brug.toon(v)
            if model.view.status == "y" { raak += 1 }
        }
        #expect(raak == 3, "buiten snel spelen hoort elke kaart getekend te worden")
    }

    @Test("De partij stopt vanzelf voordat de tellers overlopen")
    @MainActor
    func stoptOpTijd() {
        let model = losModel()
        model.demo = true

        var v = SpelView()
        v.statistiek.spellen = [Int64(SpelModel.maxSpellen) - 1, 0]
        model.toon(v)
        #expect(model.demo, "nog niet aan de grens, dus nog niet stoppen")

        v.statistiek.spellen = [Int64(SpelModel.maxSpellen) / 2, Int64(SpelModel.maxSpellen) / 2]
        model.toon(v)
        #expect(model.tekst == Taal.snelKlaar(SpelModel.maxSpellen),
                "verwacht de eindmelding, kreeg \"\(model.tekst)\"")
    }

    @Test("Een mens die zelf speelt wordt niet afgekapt")
    @MainActor
    func mensSpeeltDoor() {
        let model = losModel()
        model.demo = false

        var v = SpelView()
        v.statistiek.spellen = [Int64(SpelModel.maxSpellen), Int64(SpelModel.maxSpellen)]
        model.toon(v)

        #expect(model.tekst.isEmpty, "een mens hoort niet gestopt te worden")
    }
}
