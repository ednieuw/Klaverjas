import Testing
@testable import KlaverjasKit

/// Claude mag alleen gebruiken wat de speler die aan zet is kan zien. Bij de opening zijn dat 16 van de 32
/// kaarten: de eigen hand (8), de eigen open tafel (4) en de open tafel van de tegenstander (4). De hand van
/// de tegenstander en de dichte kaarten onder beide tafels zijn verborgen.
///
/// De proef: verwissel de verborgen kaarten onderling, zodat de zichtbare kaarten gelijk blijven maar de
/// werkelijke verdeling een andere is. Rekent Claude alleen met wat hij ziet, dan zijn alle scores van een
/// zet of een troefkleur daarna exact gelijk. Piept hij naar de verborgen kaarten, dan wijkt minstens een
/// getal af. Als controle: verwissel ook één ZICHTBARE kaart met een verborgen, dan moeten de scores wél
/// veranderen, anders bewijst de proef niets.
struct ClaudeZichtTests {
    /// Een kleine, vaste toevalsbron voor het husselen, los van de engine.
    private struct Hussel {
        var stand: UInt64
        mutating func volgende(_ n: Int) -> Int {
            stand = stand &* 6364136223846793005 &+ 1442695040888963407
            return Int((stand >> 33) % UInt64(n))
        }
    }

    private static func opening(_ zaad: Int) -> KjEngine {
        let e = KjEngine(zaad: zaad)
        let s = e.s
        s.comp = true
        s.speler = s.random(2) + 1
        s.troef = 999
        s.slagNr = 0
        s.slagKrtNo = 0
        e.delen()
        s.speler = 1 - (s.speler - 1) + 1
        s.vrager = s.speler
        s.startVrager = s.speler
        for n in 0..<4 { s.tNoord[n] = 1; s.tZuid[n] = 1 }
        e.kaartenVrij()
        e.zetTafelPosities()
        e.vulhanden()
        s.slagNr = 0
        return e
    }

    private static func kant(_ vrager: Int) -> Int { (vrager > 2 ? vrager - 2 : vrager) - 1 }

    /// De kaarten die `ik` niet kan zien, uit de statuscodes van de engine.
    private static func verborgen(_ e: KjEngine, _ ik: Int) -> [Int] {
        let tegen = 1 - ik
        let codes: Set<Int> = [Pos.dicht, Pos.handZuid + tegen, Pos.dichtZuid, Pos.dichtNoord]
        return (0..<32).filter { codes.contains(e.s.kaart[$0].dichtIkHy) }
    }

    /// Husselt de statuscodes onder `kaarten` en geeft true als er echt iets verschoven is.
    private static func husselStatus(_ e: KjEngine, _ kaarten: [Int], _ rnd: inout Hussel) -> Bool {
        var codes = kaarten.map { e.s.kaart[$0].dichtIkHy }
        var i = codes.count - 1
        while i >= 1 { codes.swapAt(i, rnd.volgende(i + 1)); i -= 1 }
        var verschoven = false
        for (j, n) in kaarten.enumerated() {
            if e.s.kaart[n].dichtIkHy != codes[j] { verschoven = true }
            e.s.kaart[n].dichtIkHy = codes[j]
        }
        return verschoven
    }

    private static func meetTroef() -> (afwijking: String?, verschoven: Int, controleVerschilt: Int) {
        var rnd = Hussel(stand: 7)
        var afwijking: String?
        var verschoven = 0
        var controleVerschilt = 0
        for zaad in 1...40 {
            let e = opening(zaad)
            let ik = kant(e.s.startVrager)
            let vb = verborgen(e, ik)
            if vb.count != 16 { return ("de opening heeft \(vb.count) verborgen kaarten in plaats van 16", 0, 0) }
            let voor = ClaudeAi(e, proeven: 20).troefScores()

            for _ in 0..<3 {
                let zichtbaarVoor = (0..<32).filter { !vb.contains($0) }.map { e.s.kaart[$0].dichtIkHy }
                if husselStatus(e, vb, &rnd) { verschoven += 1 }
                let zichtbaarNa = (0..<32).filter { !vb.contains($0) }.map { e.s.kaart[$0].dichtIkHy }
                if zichtbaarVoor != zichtbaarNa { return ("de zichtbare kaarten zijn verschoven", 0, 0) }
                let na = ClaudeAi(e, proeven: 20).troefScores()
                if na != voor && afwijking == nil {
                    afwijking = "zaad \(zaad): de troefscores hangen af van verborgen kaarten: \(voor) tegen \(na)"
                }
            }

            // Controle: één zichtbare eigen handkaart ruilen met een verborgen kaart verandert de scores wel.
            let eigen = (0..<32).first { e.s.kaart[$0].dichtIkHy == Pos.handZuid + ik }!
            let ander = vb.first { e.s.kaart[$0].dichtIkHy == Pos.dichtZuid }!
            let a = e.s.kaart[eigen].dichtIkHy
            e.s.kaart[eigen].dichtIkHy = e.s.kaart[ander].dichtIkHy
            e.s.kaart[ander].dichtIkHy = a
            if ClaudeAi(e, proeven: 20).troefScores() != voor { controleVerschilt += 1 }
        }
        return (afwijking, verschoven, controleVerschilt)
    }

    private static func meetKaartkeuze() -> (afwijking: String?, getoetst: Int, verschoven: Int) {
        var rnd = Hussel(stand: 11)
        var afwijking: String?
        var getoetst = 0
        var verschoven = 0
        var teller = 0
        _ = Spoor.genereer(spellen: 60, zaad: 3) { e in
            teller += 1
            guard teller % 4 == 0, afwijking == nil else { return }
            let s = e.s
            let ik = kant(s.vrager)
            let vb = verborgen(e, ik)
            guard let voor = ClaudeAi(e, proeven: 12).kaartScores() else { return }

            let bewaard = vb.map { s.kaart[$0].dichtIkHy }
            for _ in 0..<2 {
                if husselStatus(e, vb, &rnd) { verschoven += 1 }
                if let na = ClaudeAi(e, proeven: 12).kaartScores() {
                    if na.kandidaten != voor.kandidaten || na.som != voor.som {
                        afwijking = "slag \(s.slagNr): scores \(voor.som) tegen \(na.som)"
                    }
                } else { afwijking = "slag \(s.slagNr): geen kandidaten meer na het verwisselen" }
                getoetst += 1
            }
            for (i, n) in vb.enumerated() { s.kaart[n].dichtIkHy = bewaard[i] }    // het spel loopt gewoon door
        }
        return (afwijking, getoetst, verschoven)
    }

    @Test("De troefkeuze kijkt alleen naar de 16 zichtbare kaarten van de opening")
    func troefkeuzeKijktAlleenNaarZichtbareKaarten() async {
        let r = await ClaudeTests.opEigenDraad { Self.meetTroef() }
        #expect(r.afwijking == nil, "\(r.afwijking ?? "")")
        #expect(r.verschoven > 100, "de verwisseling moest echt iets verschuiven (\(r.verschoven))")
        #expect(r.controleVerschilt >= 35,
                "de controle (een zichtbare kaart ruilen) veranderde de scores te weinig: \(r.controleVerschilt) van 40")
    }

    @Test("De kaartkeuze tijdens het spel kijkt alleen naar wat zichtbaar is")
    func kaartkeuzeKijktAlleenNaarWatZichtbaarIs() async {
        let r = await ClaudeTests.opEigenDraad { Self.meetKaartkeuze() }
        #expect(r.afwijking == nil, "\(r.afwijking ?? "")")
        #expect(r.getoetst > 300, "te weinig beslismomenten getoetst: \(r.getoetst)")
        #expect(r.verschoven > 200, "de verwisseling moest echt iets verschuiven (\(r.verschoven))")
    }
}
