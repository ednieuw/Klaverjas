import Testing
import Foundation
@testable import KlaverjasApp
@testable import KlaverjasKit

/// De pauze tussen twee gelegde kaarten als de computer beide kanten speelt.
///
/// Zonder die pauze verschijnen de vier kaarten van een slag tegelijk. Hij zit
/// bewust in de brug naar het scherm en niet in de speelloop, zodat de engine
/// er vrij van blijft — deze test bewaakt allebei die kanten.
///
/// Met een tijdslimiet: een paar proeven hierin wachten op een doorgeefluik
/// dat de brug hoort los te maken. Blijft dat uit, dan hangt de proef in
/// plaats van te zakken — en een proef die hangt zegt niets.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct PauzeTests {
    @Test("In demo wacht het scherm tussen twee kaarten")
    @MainActor
    func demoWacht() async {
        let model = SpelModel()
        model.demo = true
        let brug = Brug(model: model, tempo: model.tempo, generatie: model.huidigeGeneratie)

        let begin = ContinuousClock.now
        await brug.toon(SpelView())
        let duur = ContinuousClock.now - begin

        #expect(duur >= SpelModel.demoPauze,
                "wachtte maar \(duur), verwacht minstens \(SpelModel.demoPauze)")
    }

    @Test("Zonder demo wacht het scherm niet")
    @MainActor
    func gewoonSpelWachtNiet() async {
        let model = SpelModel()
        model.demo = false
        let brug = Brug(model: model, tempo: model.tempo, generatie: model.huidigeGeneratie)

        let begin = ContinuousClock.now
        await brug.toon(SpelView())
        let duur = ContinuousClock.now - begin

        // Ruim onder de pauze: een menselijke speler mag niet op de computer
        // hoeven wachten.
        #expect(duur < .milliseconds(100), "wachtte \(duur) terwijl demo uit staat")
    }

    @Test("Ook bij snel spelen wordt het paneel bij elke slag bijgewerkt")
    @MainActor
    func snelPaneelWerktElkeSlagBij() async {
        let model = losModel()
        model.snel = true
        model.stop()
        let brug = Brug(model: model, tempo: model.tempo, generatie: model.huidigeGeneratie)

        // Bewust géén afrem hier (zie A30 in WIJZIGINGEN-Swift.md): dat is
        // geprobeerd om het paneel net als de kaarten af te remmen, maar de
        // extra sprong naar de hoofdtaak om te kijken of er afgeremd moet
        // worden — bij snel spelen miljoenen keren per partij — kostte meer
        // snelheid dan het paneel ooit opleverde. Teruggedraaid; deze proef
        // legt vast dat het weer zo is.
        //
        // Elke slag zijn eigen tekst, niet steeds dezelfde: anders is een
        // update die toevallig dezelfde waarde zet niet te onderscheiden van
        // geen update, en bewijst de proef niets.
        var bijgewerkt = 0
        for i in 0..<500 {
            var v = SpelView()
            v.status = "x\(i)"
            let voor = model.view.status
            await brug.verder(v, "slag")
            if model.view.status != voor { bijgewerkt += 1 }
        }
        #expect(bijgewerkt == 500,
                "het paneel werd maar \(bijgewerkt) keer bijgewerkt van de 500")
    }

    @Test("Zonder snel spelen wordt het paneel bij elke slag bijgewerkt")
    @MainActor
    func gewoonPaneelWerktElkeSlagBij() async {
        let model = losModel()
        defer { model.stop() }
        let brug = Brug(model: model, tempo: model.tempo, generatie: model.huidigeGeneratie)

        // Buiten snel spelen wacht `vraagVerder` op een klik; die geeft de
        // proef hier met `gaVerder()`, net als bij een echte tik op het scherm.
        //
        // Een kale `Task.yield()` bleek hier niet robuust zodra er elders in
        // dezelfde testrun veel `print()`-regels langskomen (de BLE-diagnostiek
        // uit fase 5, die bij elke kaart van de gast een regel logt tijdens
        // `StartDuoTests`): dat gaf genoeg extra ruis om deze ene wissel te
        // missen, en dan bleef de proef voor eeuwig op een tik wachten die
        // nooit meer kwam — `.timeLimit` redt dat niet (zie de aantekening bij
        // `MensTests.noordSpeeltMee`). Een echte, kort pollende wacht is
        // robuuster, net als elders in deze suite.
        for i in 0..<3 {
            var v = SpelView()
            v.status = "y"
            async let werk: Void = brug.verder(v, "slag \(i)")
            var kwamAan = false
            for _ in 0..<200 {
                if model.modus == .verder { kwamAan = true; break }
                try? await Task.sleep(for: .milliseconds(5))
            }
            #expect(kwamAan, "kwam niet bij het wachten op een klik")
            guard kwamAan else { return }
            model.gaVerder()
            await werk
            #expect(model.tekst == "slag \(i)", "de \(i)e slag kwam niet door")
        }
    }
}
