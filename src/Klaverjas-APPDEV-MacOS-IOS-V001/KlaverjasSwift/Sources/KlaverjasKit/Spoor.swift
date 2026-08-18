
/// Speelt een vast aantal spellen computer-tegen-computer en schrijft per
/// gespeelde kaart één regel. Dit is de Swift-tegenhanger van Spoor() uit
/// KlaverjasTest/Program.cs; de regels moeten teken voor teken gelijk zijn.
///
///     Regelvorm:  spel;slag;volgnr;speler;kleur;kaart;tactiek
///     Afsluiting: spel;=;troef;puntenZuid;puntenNoord;roemZuid;roemNoord
public enum Spoor {
    public static func genereer(spellen: Int, zaad: Int) -> [String] {
        var uit: [String] = []
        uit.reserveCapacity(spellen * 34)

        let e = KjEngine(zaad: zaad)
        let s = e.s
        s.comp = true          // computer speelt beide kanten: geen invoer nodig

        uit.append("# klaverjas spoor; spellen=\(spellen); zaad=\(zaad)")

        s.speler = s.random(2) + 1

        for nr in 1...spellen {
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
                        let volgnr = s.slagKrtNo
                        let speler = s.vrager
                        let kleur = s.lkleur
                        let kaart = s.lkaart
                        let tactiek = s.tactiek

                        if !e.legKaart(kaart, kleur, s.vrager) || e.checkValid() != nil {
                            uit.append("\(nr);\(s.slagNr);\(volgnr);\(speler);\(kleur);\(kaart);!verzaakt")
                            break spel
                        }
                        uit.append("\(nr);\(s.slagNr);\(volgnr);\(speler);\(kleur);\(kaart);\(tactiek)")
                        if volgnr == 0 { s.startVrager = s.vrager }
                        if volgnr == 0 && s.tactiek == 41 { s.tactiek41 = true }
                    }

                    e.evalueer()
                    if s.slagNr == 8 { /* laatste slag: tafel blijft staan */ }
                    else { e.updateTafel(); s.slagKrtNo = 0 }

                    s.slagNr += 1
                }

                uit.append("\(nr);=;\(s.troef);\(s.puntenSpel[0]);\(s.puntenSpel[1]);\(s.roem[0]);\(s.roem[1])")
                e.evalueerSpel()
            }

            s.slagKrtNo = 0
        }

        return uit
    }
}
