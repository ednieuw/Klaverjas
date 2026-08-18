import Testing
@testable import KlaverjasKit

/// Vier gelijke kaarten in één slag: 100 roempunten, 200 bij vier boeren.
///
/// In het origineel werd deze roem nooit uitgekeerd. `bepaalroempunten` heeft
/// er een tak voor, maar `evalueer` groepeert de vier kaarten van een slag
/// eerst op kleur, en vier gelijke kaarten hebben per definitie vier
/// verschillende kleuren. Elk groepje bevat er dan precies één, en bij één
/// kaart wordt de functie niet eens aangeroepen — de teller stond altijd op nul.
///
/// De Swift-versie voert de regel wel uit. Deze test bewaakt dat: de situatie
/// komt voor, en elke keer dat hij voorkomt gaat de teller mee omhoog.
struct SuperroemTests {
    @Test("Vier gelijke kaarten worden geteld en leveren roem op")
    func superroemWordtGeteld() {
        let spellen = 20000
        var slagenMetVierGelijke = 0
        var boerenSlagen = 0

        let e = KjEngine(zaad: 31415)
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

            spel: do {
                s.slagNr = 1
                while s.slagNr < 9 {
                    for beurt in [e.speler1, e.tegenspeler1, e.speler2, e.tegenspeler2] {
                        s.tactiek = 0
                        beurt()
                        if !e.legKaart(s.lkaart, s.lkleur, s.vrager) || e.checkValid() != nil {
                            break spel
                        }
                        if s.slagKrtNo == 1 {
                            s.startVrager = s.vrager
                            if s.tactiek == 41 { s.tactiek41 = true }
                        }
                    }

                    // Zelf tellen wat er op tafel ligt, los van wat de engine doet.
                    let namen = (0..<4).map { s[slag: s.slagNr, i: $0].naam }
                    let vierGelijk = namen[0] != .nul && namen.allSatisfy { $0 == namen[0] }
                    if vierGelijk {
                        slagenMetVierGelijke += 1
                        if namen[0] == "B" { boerenSlagen += 1 }
                    }

                    let voor = s.roem[0] + s.roem[1]
                    let uitslag = e.evalueer()
                    let na = s.roem[0] + s.roem[1]

                    if vierGelijk {
                        let verwacht = namen[0] == "B" ? 200 : 100
                        #expect(uitslag.roem >= verwacht,
                                "slag met vier keer \(namen[0]) leverde maar \(uitslag.roem) roem op")
                        #expect(na - voor >= verwacht)
                    }

                    if s.slagNr != 8 { e.updateTafel(); s.slagKrtNo = 0 }
                    s.slagNr += 1
                }
                e.evalueerSpel()
            }
            s.slagKrtNo = 0
        }

        #expect(slagenMetVierGelijke > 0,
                "in \(spellen) spellen kwam geen enkele slag met vier gelijke kaarten voor")
        #expect(s.superroem == Int64(slagenMetVierGelijke),
                "teller staat op \(s.superroem), maar er waren \(slagenMetVierGelijke) slagen")

        print("vier gelijke: \(slagenMetVierGelijke) keer in \(spellen) spellen "
            + "(waarvan \(boerenSlagen) met boeren); teller: \(s.superroem)")
    }

    @Test("De roemwaarden zijn 100, en 200 voor vier boeren")
    func waardenKloppen() {
        let e = KjEngine(zaad: 1)
        #expect(e.bepaalRoemPunten("AAAA", 0) == 100)
        #expect(e.bepaalRoemPunten("BBBB", 0) == 200)
    }
}
