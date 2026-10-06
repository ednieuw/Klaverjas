import Testing
@testable import KlaverjasKit

/// De ijkproef voor de zoekende speler: 500 spellen, zaad 1, elk twee keer
/// gespeeld met de kanten omgedraaid. Wijkt er één getal af, dan kiest de zoeker
/// ergens een andere kaart en verschuift alles erna.
///
/// Het is een sterkere toets dan het kaartspoor: duizend spellen lang telt elke
/// zet van beide kanten mee.
///
/// **De getallen zijn die van versie 1.1**, met de twee reparaties uit punt A11
/// en A13 erin. De C#-versie levert ze pas op zodra die reparaties daar ook
/// gedaan zijn; tot dan bewaakt deze proef dat de motor hier niet ongemerkt van
/// gedrag verandert. Ter vergelijking, de uitslag van versie 1.0 was
/// 484/516 gewonnen, 93774/92216 punten en 17190/16800 roem — toen lag Ednieuw
/// voor, nu Ronlog.
struct ZoekTests {
    @Test("Het toernooi levert de getallen van versie 1.1")
    func toernooiKlopt() {
        let u = Toernooi.speel(spellen: 500, zaad: 1)

        #expect(u.gewonnen == [489, 511])
        #expect(u.punten == [92817, 93403])
        #expect(u.roem == [16560, 17660])
        #expect(u.nat == [117, 106])
        #expect(u.pit == [48, 28])
        #expect(u.verzaakt == 0)
        #expect(u.gespeeld == 1000)

        let regels = Toernooi.verslag(u, spellen: 500)
        #expect(regels.contains("Puntenaandeel      : Ednieuw 49.8%   Ronlog 50.2%"))
        #expect(regels.contains("Spellen gewonnen   : Ednieuw 48.9%   Ronlog 51.1%"))
    }

    @Test("De zoekende speler verzaakt niet, aan geen van beide kanten")
    func zoekerVerzaaktNiet() {
        // Beide kanten zoekend: dan gaat elke kaart van het spel door zijn
        // keuze heen, en niet alleen die van één kant.
        var verzaakt = 0
        for (zuid, noord) in [(true, true), (true, false), (false, true)] {
            let u = ToernooiHulp.speelZelf(spellen: 300, zaad: 7, zuid: zuid, noord: noord)
            verzaakt += u
        }
        #expect(verzaakt == 0)
    }

    @Test("Tactieknummer 70 is van de zoeker en van niemand anders")
    func tactiek70IsVanDeZoeker() {
        // Zonder zoeker komt 70 niet voor: dat nummer bestaat niet in de
        // tactiek van 1994.
        let zonder = ToernooiHulp.tacTeller(spellen: 200, zaad: 3, zuid: false, noord: false)
        #expect(zonder == 0)

        let met = ToernooiHulp.tacTeller(spellen: 200, zaad: 3, zuid: true, noord: false)
        #expect(met > 0)
    }
}

/// Een kale speelloop voor de toetsen hierboven: hij hoeft alleen te weten of er
/// verzaakt is en hoe vaak tactiek 70 langskwam.
enum ToernooiHulp {
    static func speelZelf(spellen: Int, zaad: Int, zuid: Bool, noord: Bool) -> Int {
        speel(spellen: spellen, zaad: zaad, zuid: zuid, noord: noord).verzaakt
    }

    static func tacTeller(spellen: Int, zaad: Int, zuid: Bool, noord: Bool) -> Int64 {
        speel(spellen: spellen, zaad: zaad, zuid: zuid, noord: noord).tac70
    }

    private static func speel(spellen: Int, zaad: Int,
                              zuid: Bool, noord: Bool) -> (verzaakt: Int, tac70: Int64) {
        let e = KjEngine(zaad: zaad)
        let s = e.s
        s.comp = true
        s.zoekt[0] = zuid
        s.zoekt[1] = noord
        s.speler = s.random(2) + 1

        var verzaakt = 0
        for _ in 0..<spellen {
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
                    for (n, beurt) in [e.speler1, e.tegenspeler1, e.speler2, e.tegenspeler2].enumerated() {
                        s.tactiek = 0
                        beurt()
                        if !e.legKaart(s.lkaart, s.lkleur, s.vrager) || e.checkValid() != nil {
                            verzaakt += 1
                            break spel
                        }
                        // De uitkomer bepaalt wie er startvrager is; zonder deze
                        // regel klopt de regelcontrole van de volgende kaart niet.
                        if n == 0 {
                            s.startVrager = s.vrager
                            if s.tactiek == 41 { s.tactiek41 = true }
                        }
                        if s.tactiek >= 0 && s.tactiek < 80 { s.tac[s.tactiek] += 1 }
                    }
                    e.evalueer()
                    if s.slagNr < 8 { e.updateTafel(); s.slagKrtNo = 0 }
                    s.slagNr += 1
                }
                e.evalueerSpel()
            }
            s.slagKrtNo = 0
        }
        return (verzaakt, s.tac[70])
    }
}
