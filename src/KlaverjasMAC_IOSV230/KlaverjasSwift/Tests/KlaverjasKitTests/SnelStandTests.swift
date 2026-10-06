import Testing
import Foundation
@testable import KlaverjasKit

/// Snel spelen bouwt geen kaartbeelden meer op: het scherm toont dan alleen tellers. Wat die weglating
/// niet mag doen is het spel veranderen. Dezelfde spellen met en zonder `snelSpelen` moeten dezelfde
/// tellingen opleveren, en met `snelSpelen` mag de speelloop geen kaart meer tonen.
struct SnelStandTests {
    private final class Ui: KjUi, @unchecked Sendable {
        private let slot = NSLock()
        private let snel: Bool
        private let doel: Int
        private var _toon = 0
        private var _spellen = 0
        private var _kaartenGezien = 0
        private var _slagenGezien = 0
        private var _eind: Statistiek?

        init(snel: Bool, doel: Int) { self.snel = snel; self.doel = doel }

        var snelSpelen: Bool { snel }
        var toonAantal: Int { slot.withLock { _toon } }
        var spellen: Int { slot.withLock { _spellen } }
        var kaartenGezien: Int { slot.withLock { _kaartenGezien } }
        /// Kaarten van de lopende en de vorige slag in alles wat de speelloop liet zien.
        var slagenGezien: Int { slot.withLock { _slagenGezien } }
        var eind: Statistiek? { slot.withLock { _eind } }

        func toon(_ view: SpelView) async {
            slot.withLock { _toon += 1; _kaartenGezien += view.handZuid.count + view.tafelNoord.count }
        }
        func kiesKaart(_ view: SpelView) async -> (naam: Teken, kleur: Int) { (.nul, 0) }
        func kiesTroef(_ view: SpelView) async -> Int { 0 }
        func verder(_ view: SpelView, _ tekst: String) async {
            slot.withLock {
                _kaartenGezien += view.handZuid.count + view.tafelNoord.count
                _slagenGezien += view.slag.count + view.vorigeSlag.count
                if view.spelUit {
                    _spellen += 1
                    // De stand na precies `doel` spellen, niet na een onbepaald aantal.
                    if _spellen == doel { _eind = view.statistiek }
                }
            }
        }
    }

    private func speel(snel: Bool, spellen: Int) async -> (Ui, Duration) {
        let ui = Ui(snel: snel, doel: spellen)
        let begin = ContinuousClock.now
        let taak = Task.detached(priority: .background) {
            let spel = KjSpel(ui: ui, zaad: 11, instellingen: { Instellingen(demo: true) })
            await spel.loop()
        }
        while ui.eind == nil { try? await Task.sleep(for: .milliseconds(2)) }
        let duur = ContinuousClock.now - begin
        taak.cancel()
        _ = await taak.value
        return (ui, duur)
    }

    @Test("Zonder kaartbeelden speelt dezelfde reeks spellen, met dezelfde tellingen")
    func zelfdeSpellenZelfdeTellingen() async {
        let (gewoon, tGewoon) = await speel(snel: false, spellen: 40)
        let (snel, tSnel) = await speel(snel: true, spellen: 40)

        #expect(gewoon.eind == snel.eind, "de tellingen na 40 spellen zijn niet gelijk")
        #expect(gewoon.toonAantal > 0 && gewoon.kaartenGezien > 0, "zonder snel spelen horen de kaarten er te zijn")
        #expect(snel.toonAantal == 0, "bij snel spelen is er \(snel.toonAantal) keer een kaart getoond")
        #expect(snel.kaartenGezien == 0, "bij snel spelen zijn er \(snel.kaartenGezien) kaartbeelden opgebouwd")
        #expect(gewoon.slagenGezien > 0, "zonder snel spelen hoort de vorige slag er te zijn")
        #expect(snel.slagenGezien == 0, "bij snel spelen zijn er \(snel.slagenGezien) kaarten van een slag meegegeven")
        print("snel spelen, 40 spellen: met kaartbeelden \(tGewoon), zonder \(tSnel)")
    }
}
