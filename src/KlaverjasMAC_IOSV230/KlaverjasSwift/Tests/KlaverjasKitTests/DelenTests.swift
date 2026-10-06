import Testing
@testable import KlaverjasKit

/// Krijgen Zuid en Noord even goede kaarten?
///
/// Tot versie 1.1 niet. `Delen()` schudde met `random(m)` waar een eerlijke
/// Fisher-Yates `random(m+1)` nodig heeft: de kaart die op dat moment op plek m
/// lag kon bij die stap nooit gekozen worden. Zuid kreeg daardoor structureel
/// 0,687 kaartpunt per spel meer dan Noord — alles in de tafel- en dichte
/// stapels; de handen waren wel gelijk.
///
/// Deze proef zou met de oude schudding ruim omvallen.
struct DelenTests {
    private static let spellen = 40_000
    /// Ruim boven de ruis (ongeveer 0,08) en ruim onder de oude scheefheid.
    private static let marge = 0.3

    @Test("Beide kanten krijgen even veel kaartpunten")
    func delenIsEerlijk() {
        let e = KjEngine(zaad: 1)
        var perStapel = [Int: Int]()

        for _ in 0..<Self.spellen {
            e.delen()
            for n in 0..<32 {
                let k = e.s.kaart[n]
                perStapel[k.dichtIkHy, default: 0] += k.puntWaarde
            }
        }

        func punten(_ posities: [Int]) -> Double {
            Double(posities.reduce(0) { $0 + (perStapel[$1] ?? 0) }) / Double(Self.spellen)
        }
        let zuid = punten([Pos.handZuid, Pos.tafelZuid, Pos.dichtZuid])
        let noord = punten([Pos.handNoord, Pos.tafelNoord, Pos.dichtNoord])

        #expect(abs(zuid - noord) < Self.marge,
                "Zuid krijgt \(zuid) kaartpunten per spel en Noord \(noord)")

        // Ook per stapel, want daar zat de oude scheefheid: de handen waren
        // gelijk en juist tafel en dicht liepen uiteen.
        let paren = [("hand", Pos.handZuid, Pos.handNoord),
                     ("tafel", Pos.tafelZuid, Pos.tafelNoord),
                     ("dicht", Pos.dichtZuid, Pos.dichtNoord)]
        for (naam, z, n) in paren {
            let pz = punten([z]), pn = punten([n])
            #expect(abs(pz - pn) < Self.marge,
                    "\(naam): Zuid \(pz), Noord \(pn)")
        }
    }

    @Test("Elke stapel krijgt het juiste aantal kaarten")
    func aantallenKloppen() {
        let e = KjEngine(zaad: 7)
        e.delen()
        var telling = [Int: Int]()
        for n in 0..<32 { telling[e.s.kaart[n].dichtIkHy, default: 0] += 1 }

        #expect(telling[Pos.handZuid] == 8)
        #expect(telling[Pos.handNoord] == 8)
        #expect(telling[Pos.tafelZuid] == 4)
        #expect(telling[Pos.tafelNoord] == 4)
        #expect(telling[Pos.dichtZuid] == 4)
        #expect(telling[Pos.dichtNoord] == 4)
        #expect(telling.values.reduce(0, +) == 32)
    }
}
