import Testing
import Foundation
@testable import KlaverjasApp
@testable import KlaverjasKit

/// De pauze tussen twee gelegde kaarten als de computer beide kanten speelt.
///
/// Zonder die pauze verschijnen de vier kaarten van een slag tegelijk. Hij zit
/// bewust in de brug naar het scherm en niet in de speelloop, zodat de engine
/// er vrij van blijft — deze test bewaakt allebei die kanten.
@Suite(.serialized)
struct PauzeTests {
    @Test("In demo wacht het scherm tussen twee kaarten")
    @MainActor
    func demoWacht() async {
        let model = SpelModel()
        model.demo = true
        let brug = Brug(model: model)

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
        let brug = Brug(model: model)

        let begin = ContinuousClock.now
        await brug.toon(SpelView())
        let duur = ContinuousClock.now - begin

        // Ruim onder de pauze: een menselijke speler mag niet op de computer
        // hoeven wachten.
        #expect(duur < .milliseconds(100), "wachtte \(duur) terwijl demo uit staat")
    }
}
