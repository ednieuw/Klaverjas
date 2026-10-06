import Testing
import Foundation
@testable import KlaverjasKit

/// Alle acht slagen levert 100 punten roem op, en 300 als de tegenpartij het
/// doet terwijl jij troef maakte. Die bonus telt de motor pas op in
/// `evalueerSpel()`, ná de laatste slag — dus na het moment waarop de melding
/// van die slag gemaakt wordt. Zonder zorg valt hij daardoor buiten de uitslag
/// én buiten het paneel, en lijkt de stand uit de lucht te komen.
struct PitTests {
    /// Onthoudt de uitslag van het eerste spel waarin pit gehaald werd.
    private final class Vanger: KjUi, @unchecked Sendable {
        private let slot = NSLock()
        private var _melding = ""
        private var _view = SpelView()
        private var _gevonden = false
        private var _pitVoor: Int64 = 0

        var melding: String { slot.withLock { _melding } }
        var view: SpelView { slot.withLock { _view } }
        var gevonden: Bool { slot.withLock { _gevonden } }

        func toon(_ view: SpelView) async {}
        func kiesKaart(_ view: SpelView) async -> (naam: Teken, kleur: Int) { (.nul, 0) }
        func kiesTroef(_ view: SpelView) async -> Int { 0 }
        func verder(_ view: SpelView, _ tekst: String) async {
            let pit = view.statistiek.pit[0] + view.statistiek.pit[1]
            slot.withLock {
                defer { _pitVoor = pit }
                guard pit > _pitVoor, !_gevonden else { return }
                _melding = tekst
                _view = view
                _gevonden = true
            }
        }
    }

    @Test("Bij pit staat de roem in de uitslag en in het paneel")
    func pitWordtGemeld() async {
        let ui = Vanger()
        let taak = Task.detached {
            let spel = KjSpel(ui: ui, zaad: 1, instellingen: { Instellingen(demo: true) })
            await spel.loop()
        }
        while !ui.gevonden { try? await Task.sleep(for: .milliseconds(5)) }
        taak.cancel()
        _ = await taak.value

        let melding = ui.melding
        // Op de getallen en niet op de woorden: die hangen van de taal af.
        #expect(melding.contains("100") || melding.contains("300"),
                "de bonus voor pit stond niet in de uitslag: \"\(melding)\"")

        // En het paneel moet dezelfde bonus laten zien. Wie alle acht slagen
        // pakt heeft 152 kaartpunten; zijn roem is dan minstens 100.
        let v = ui.view
        let pitZuid = v.puntenZuid == 152
        let roem = pitZuid ? v.roemZuid : v.roemNoord
        let punten = pitZuid ? v.puntenZuid : v.puntenNoord
        #expect(punten == 152, "de kant met pit had \(punten) kaartpunten in plaats van 152")
        #expect(roem >= 100,
                "het paneel toonde \(roem) roem, terwijl pit er minstens 100 oplevert")
    }
}
