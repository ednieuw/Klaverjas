import Testing
@testable import KlaverjasKit

/// `evalueerSpel()`'s partij-einde-detectie (1500 punten) — het fundament
/// onder het partij-splashscherm (`PartijSplash` in `KlaverjasApp`). Zet de
/// motor rechtstreeks vlak voor de 1500 in plaats van er een hele partij
/// naartoe te spelen: dat is deterministisch en er is geen natte kant of
/// pit-bonus in de weg die de som zou verstoren.
struct PartijSplashTests {
    @Test("Zuid over de 1500: partijUit en partijGewonnenDoorZuid staan aan, geen gelijkspel")
    func zuidWintDePartij() {
        let e = KjEngine(zaad: 1)
        let s = e.s
        s.speler = 1
        s.slagNr = 8
        s.puntenSpel[0] = 100
        s.puntenSpel[1] = 0
        s.puntenTotaalSpel[0] = 1400
        s.puntenTotaalSpel[1] = 500

        let eind = e.evalueerSpel()

        #expect(eind.partijUit)
        #expect(eind.partijGewonnenDoorZuid)
        #expect(!eind.partijGelijkspel)
        #expect(s.gewonnen[0] == 1)
        #expect(s.gewonnen[1] == 0)
        #expect(s.puntenTotaalSpel[0] == 0, "de partijtotalen moeten na afloop weer op nul staan")
        #expect(s.puntenTotaalSpel[1] == 0)
    }

    @Test("Noord over de 1500: partijGewonnenDoorZuid staat uit")
    func noordWintDePartij() {
        let e = KjEngine(zaad: 1)
        let s = e.s
        s.speler = 2
        s.slagNr = 8
        s.puntenSpel[0] = 0
        s.puntenSpel[1] = 100
        s.puntenTotaalSpel[0] = 500
        s.puntenTotaalSpel[1] = 1400

        let eind = e.evalueerSpel()

        #expect(eind.partijUit)
        #expect(!eind.partijGewonnenDoorZuid)
        #expect(!eind.partijGelijkspel)
        #expect(s.gewonnen[0] == 0)
        #expect(s.gewonnen[1] == 1)
    }

    @Test("Allebei tegelijk over de 1500, met evenveel: gelijkspel, beide kanten krijgen de partij")
    func gelijkspelOverDe1500() {
        let e = KjEngine(zaad: 1)
        let s = e.s
        s.speler = 1
        s.slagNr = 8
        s.puntenSpel[0] = 100
        s.puntenSpel[1] = 0
        s.puntenTotaalSpel[0] = 1400   // + 100 = 1500
        s.puntenTotaalSpel[1] = 1500   // + 0    = 1500, al aan de eis

        let eind = e.evalueerSpel()

        #expect(eind.partijUit)
        #expect(eind.partijGelijkspel)
        #expect(s.gewonnen[0] == 1, "bij gelijkspel telt de partij voor Zuid mee")
        #expect(s.gewonnen[1] == 1, "bij gelijkspel telt de partij voor Noord ook mee")
    }

    @Test("Onder de 1500: geen partij-einde, ook niet per ongeluk")
    func geenPartijZonderDe1500() {
        let e = KjEngine(zaad: 1)
        let s = e.s
        s.speler = 1
        s.slagNr = 8
        s.puntenSpel[0] = 40
        s.puntenSpel[1] = 60
        s.puntenTotaalSpel[0] = 300
        s.puntenTotaalSpel[1] = 300

        let eind = e.evalueerSpel()

        #expect(!eind.partijUit)
        #expect(!eind.partijGelijkspel)
        #expect(s.gewonnen[0] == 0)
        #expect(s.gewonnen[1] == 0)
    }
}
