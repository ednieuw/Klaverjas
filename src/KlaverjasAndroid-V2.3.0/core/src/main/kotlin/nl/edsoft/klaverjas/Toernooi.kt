package nl.edsoft.klaverjas

/**
 * Laat de vuistregels van Ednieuw en de zoekende speler van Ronlog zonder scherm
 * tegen elkaar spelen (Kotlin-port van Toernooi.swift). Bij hetzelfde zaad en aantal
 * spellen horen er exact dezelfde getallen uit te komen.
 *
 * Elk spel wordt twee keer gespeeld met dezelfde kaarten, één keer met elk van
 * beiden als Zuid, zodat een gelukkige verdeling niet meetelt.
 */
object Toernooi {

    /** De drie speelwijzen die tegen elkaar kunnen spelen. */
    enum class Stijl(val naam: String) { EDNIEUW("Ednieuw"), RONLOG("Ronlog"), CLAUDE("Claude") }

    class Uitslag {
        /** index 0 = Ednieuw, 1 = Ronlog */
        val punten = LongArray(2)
        val gewonnen = LongArray(2)
        val roem = LongArray(2)
        val nat = LongArray(2)
        val pit = LongArray(2)
        var gespeeld = 0
        var verzaakt = 0
    }

    fun speel(spellen: Int, zaad: Long): Uitslag = speel(spellen, zaad, Stijl.EDNIEUW, Stijl.RONLOG)

    /**
     * Laat [a] (index 0 in de uitslag) en [b] (index 1) tegen elkaar spelen, elk spel twee keer met
     * dezelfde kaarten en elk één keer als Zuid.
     */
    fun speel(spellen: Int, zaad: Long, a: Stijl, b: Stijl): Uitslag {
        val u = Uitslag()

        for (ronde in 0 until 2) {
            // ronde 0: a is Zuid. ronde 1: b is Zuid, zelfde kaarten.
            val ednieuwIsZuid = ronde == 0
            val e = KjEngine(zaad)
            val s = e.s
            s.comp = true
            val zuid = if (ednieuwIsZuid) a else b
            val noord = if (ednieuwIsZuid) b else a
            s.zoekt[0] = zuid == Stijl.RONLOG; s.claude[0] = zuid == Stijl.CLAUDE
            s.zoekt[1] = noord == Stijl.RONLOG; s.claude[1] = noord == Stijl.CLAUDE

            val d = Beurt(e)
            repeat(spellen) {
                val gwZ = s.gewonnenTot[0]
                val gwN = s.gewonnenTot[1]
                val ntZ = s.nat[0]
                val ntN = s.nat[1]
                val ptZ = s.pit[0]
                val ptN = s.pit[1]
                d.roemZuid = 0
                d.roemNoord = 0

                if (d.speelEenSpel()) u.verzaakt += 1
                u.gespeeld += 1

                // Zuid is index 0 als Ednieuw Zuid speelt, anders is Ronlog dat.
                val ed = if (ednieuwIsZuid) 0 else 1
                val ro = if (ednieuwIsZuid) 1 else 0
                val kaartpnt = intArrayOf(d.puntenZuid, d.puntenNoord)
                val roempnt = intArrayOf(d.roemZuid, d.roemNoord)
                u.punten[0] += (kaartpnt[ed] + roempnt[ed]).toLong()
                u.punten[1] += (kaartpnt[ro] + roempnt[ro]).toLong()
                u.roem[0] += roempnt[ed].toLong()
                u.roem[1] += roempnt[ro].toLong()
                u.gewonnen[0] += if (ed == 0) s.gewonnenTot[0] - gwZ else s.gewonnenTot[1] - gwN
                u.gewonnen[1] += if (ro == 0) s.gewonnenTot[0] - gwZ else s.gewonnenTot[1] - gwN
                u.nat[0] += if (ed == 0) s.nat[0] - ntZ else s.nat[1] - ntN
                u.nat[1] += if (ro == 0) s.nat[0] - ntZ else s.nat[1] - ntN
                u.pit[0] += if (ed == 0) s.pit[0] - ptZ else s.pit[1] - ptN
                u.pit[1] += if (ro == 0) s.pit[0] - ptZ else s.pit[1] - ptN
            }
        }
        return u
    }

    /** Het verslag zoals de Swift- en C#-versie het afdrukken, regel voor regel. */
    fun verslag(u: Uitslag, a: Stijl = Stijl.EDNIEUW, b: Stijl = Stijl.RONLOG): List<String> {
        fun vul(t: String, n: Int) = t.padEnd(n)
        fun rechts(t: String, n: Int) = t.padStart(n)
        fun rij(kop: String, e: Long, l: Long) = vul(kop, 22) + rechts("$e", 10) + rechts("$l", 10)
        fun procent(deel: Long, totaal: Long): String {
            // Eén cijfer achter de komma, zoals "F1" in C#: halfweg naar boven.
            val tienden = (1000 * deel + totaal / 2) / totaal
            return "${tienden / 10}.${tienden % 10}"
        }

        val uit = ArrayList<String>()
        uit.add(vul("", 22) + rechts(a.naam, 10) + rechts(b.naam, 10))
        uit.add("-".repeat(42))
        uit.add(rij("Spellen gewonnen", u.gewonnen[0], u.gewonnen[1]))
        uit.add(rij("Punten totaal", u.punten[0], u.punten[1]))
        uit.add(rij("Waarvan roem", u.roem[0], u.roem[1]))
        uit.add(rij("Nat gegaan", u.nat[0], u.nat[1]))
        uit.add(rij("Pit gehaald", u.pit[0], u.pit[1]))
        uit.add("")

        val tot = u.punten[0] + u.punten[1]
        if (tot > 0) {
            uit.add("Puntenaandeel      : ${a.naam} ${procent(u.punten[0], tot)}%   ${b.naam} ${procent(u.punten[1], tot)}%")
        }
        val totG = u.gewonnen[0] + u.gewonnen[1]
        if (totG > 0) {
            uit.add("Spellen gewonnen   : ${a.naam} ${procent(u.gewonnen[0], totG)}%   ${b.naam} ${procent(u.gewonnen[1], totG)}%")
        }
        uit.add("Afgebroken (verzaakt): ${u.verzaakt}")
        return uit
    }

    /**
     * Speelt precies één spel, met dezelfde stappen als KjSpel maar zonder oneindige
     * lus. Tegenhanger van Driver uit KlaverjasTest/Program.cs.
     */
    private class Beurt(private val e: KjEngine) {
        private val s: KjState get() = e.s

        var puntenZuid = 0
        var puntenNoord = 0
        var roemZuid = 0
        var roemNoord = 0

        init { s.speler = s.random(2) + 1 }

        /** Geeft true als het spel wegens verzaken is afgebroken. */
        fun speelEenSpel(): Boolean {
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

            puntenZuid = 0
            puntenNoord = 0

            s.slagNr = 1
            while (s.slagNr < 9) {
                s.tactiek = 0
                e.speler1()
                if (!leg()) return true
                s.startVrager = s.vrager
                if (s.tactiek == 41) s.tactiek41 = true
                s.tac[grens(s.tactiek)] += 1

                val beurten: List<() -> Unit> =
                    listOf({ e.tegenspeler1() }, { e.speler2() }, { e.tegenspeler2() })
                for (beurt in beurten) {
                    s.tactiek = 0
                    beurt()
                    if (!leg()) return true
                    s.tac[grens(s.tactiek)] += 1
                }

                for (n in 0 until 4) {
                    val w = winnaarKant()
                    if (w == 1) puntenZuid += s[s.slagNr, n].waarde
                    else puntenNoord += s[s.slagNr, n].waarde
                }

                e.evalueer()

                if (s.slagNr == 8) {
                    // Vastleggen vóór evalueerSpel(), want die zet de tellers op nul.
                    roemZuid = s.roem[0]
                    roemNoord = s.roem[1]
                    e.evalueerSpel()
                } else {
                    e.updateTafel()
                    s.slagKrtNo = 0
                }

                s.slagNr += 1
            }
            return false
        }

        private fun winnaarKant(): Int {
            val w = e.wieSlag()
            return if (w > 2) w - 2 else w
        }

        private fun grens(t: Int): Int = if (t in 0 until 80) t else 0

        private fun leg(): Boolean {
            if (e.wachtOpMens) return false
            if (!e.legKaart(s.lkaart, s.lkleur, s.vrager)) return false
            return e.checkValid() == null
        }
    }
}
