import Testing
@testable import KlaverjasKit

/// De tweede controle uit KlaverjasTest: de computer speelt beide kanten en er
/// wordt gekeken of hij verzaakt, of de puntensom per spel op 152 uitkomt en of
/// er precies 32 kaarten gespeeld worden. Hier met een bescheiden aantal
/// spellen zodat de test snel blijft; het aantal is de enige knop.
struct ZelfspelTests {
    @Test("De engine speelt 2000 spellen zonder te verzaken, met 152 punten per spel")
    func zelfspelKlopt() {
        let spellen = 2000
        var verzaakt = 0
        var somFout = 0
        var telFout = 0

        let e = KjEngine(zaad: 20260815)
        let s = e.s
        s.comp = true
        s.speler = s.random(2) + 1

        for _ in 1...spellen {
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
            e.troefBepalen()

            var gespeeld = 0
            spel: do {
                s.slagNr = 1
                while s.slagNr < 9 {
                    for beurt in [e.speler1, e.tegenspeler1, e.speler2, e.tegenspeler2] {
                        s.tactiek = 0
                        beurt()
                        if !e.legKaart(s.lkaart, s.lkleur, s.vrager) || e.checkValid() != nil {
                            verzaakt += 1
                            break spel
                        }
                        gespeeld += 1
                        // slagKrtNo is inmiddels opgehoogd: 1 betekent "dit was
                        // de eerste kaart van de slag".
                        if s.slagKrtNo == 1 {
                            s.startVrager = s.vrager
                            if s.tactiek == 41 { s.tactiek41 = true }
                        }
                    }
                    e.evalueer()
                    if s.slagNr != 8 { e.updateTafel(); s.slagKrtNo = 0 }
                    s.slagNr += 1
                }

                if s.puntenSpel[0] + s.puntenSpel[1] != 152 { somFout += 1 }
                if gespeeld != 32 { telFout += 1 }
                e.evalueerSpel()
            }

            s.slagKrtNo = 0
        }

        #expect(verzaakt == 0, "de computer verzaakte in \(verzaakt) van \(spellen) spellen")
        #expect(somFout == 0, "\(somFout) spellen kwamen niet op 152 kaartpunten uit")
        #expect(telFout == 0, "\(telFout) spellen speelden niet precies 32 kaarten")
    }
}
