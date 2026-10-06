package nl.edsoft.klaverjas

/**
 * Speelt een vast aantal spellen computer-tegen-computer en schrijft per gespeelde
 * kaart één regel. Tegenhanger van Spoor.swift; de regels moeten teken voor teken
 * gelijk zijn aan het ijkspoor.
 *
 *     Regelvorm:  spel;slag;volgnr;speler;kleur;kaart;tactiek
 *     Afsluiting: spel;=;troef;puntenZuid;puntenNoord;roemZuid;roemNoord
 */
object Spoor {
    /**
     * @param hook wordt vlak voor elke gespeelde kaart aangeroepen, nadat de speler zijn kaart koos
     *   maar voordat die gelegd is; alleen voor testen.
     */
    fun genereer(spellen: Int, zaad: Long, hook: ((KjEngine) -> Unit)? = null): List<String> {
        val uit = ArrayList<String>(spellen * 34)

        val e = KjEngine(zaad)
        val s = e.s
        s.comp = true          // computer speelt beide kanten: geen invoer nodig

        uit.add("# klaverjas spoor; spellen=$spellen; zaad=$zaad")

        s.speler = s.random(2) + 1

        for (nr in 1..spellen) {
            s.troef = 999
            s.slagNr = 0
            s.slagKrtNo = 0
            e.delen()
            s.speler = 1 - (s.speler - 1) + 1
            s.vrager = s.speler
            s.startVrager = s.speler
            for (n in 0 until 4) { s.tNoord[n] = 1; s.tZuid[n] = 1 }
            e.kaartenVrij()
            e.zetTafelPosities()
            e.vulhanden()
            s.slagNr = 0
            e.troefBepalen()

            spel@ do {
                s.slagNr = 1
                while (s.slagNr < 9) {
                    val beurten: List<() -> Unit> =
                        listOf({ e.speler1() }, { e.tegenspeler1() }, { e.speler2() }, { e.tegenspeler2() })
                    for (beurt in beurten) {
                        s.tactiek = 0
                        beurt()
                        hook?.invoke(e)
                        val volgnr = s.slagKrtNo
                        val speler = s.vrager
                        val kleur = s.lkleur
                        val kaart = s.lkaart
                        val tactiek = s.tactiek

                        if (!e.legKaart(kaart, kleur, s.vrager) || e.checkValid() != null) {
                            uit.add("$nr;${s.slagNr};$volgnr;$speler;$kleur;$kaart;!verzaakt")
                            break@spel
                        }
                        uit.add("$nr;${s.slagNr};$volgnr;$speler;$kleur;$kaart;$tactiek")
                        if (volgnr == 0) s.startVrager = s.vrager
                        if (volgnr == 0 && s.tactiek == 41) s.tactiek41 = true
                    }

                    e.evalueer()
                    if (s.slagNr == 8) { /* laatste slag: tafel blijft staan */ }
                    else { e.updateTafel(); s.slagKrtNo = 0 }

                    s.slagNr += 1
                }

                uit.add("$nr;=;${s.troef};${s.puntenSpel[0]};${s.puntenSpel[1]};${s.roem[0]};${s.roem[1]}")
                e.evalueerSpel()
            } while (false)

            s.slagKrtNo = 0
        }

        return uit
    }
}
