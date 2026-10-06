package nl.edsoft.klaverjas

/**
 * De speelwijze van R. Loggen (KJBeide/KJ2.C), overgezet op de gegevens van deze
 * motor (Kotlin-port van ZoekAi.swift).
 *
 * Waar de tactiek van Ednieuw uit een lange reeks vuistregels bestaat, probeert
 * deze speler het uit: hij speelt elke eigen kaart proef, laat de tegenstander er
 * zijn beste antwoord op geven, speelt zelf zijn beste vervolg, en middelt over alle
 * kaarten die de tegenstander nog in handen kán hebben. De waarde van een slag is
 * punten plus roem, met een minteken als de tegenstander hem pakt.
 *
 * Alles is geheeltallig; er komt geen kommagetal en geen toeval in voor.
 */
internal class ZoekAi(private val e: KjEngine) {
    private val s: KjState get() = e.s

    /** Eén kaart op tafel tijdens het doorrekenen. */
    private class Zet(val kleur: Int, val naam: Teken, val mijn: Boolean)

    /** Een kaart in bezit: kleur en naam. */
    private class Kaart(val kleur: Int, val naam: Teken)

    // ------------------------------------------------------------- basis

    /** Hoe sterk is deze kaart binnen zijn kleur? Hoger is sterker. */
    private fun kracht(naam: Teken, kleur: Int): Int {
        val rang = if (kleur == s.troef) KjState.rangTroef else KjState.rangNorm
        val p = CStr.pos(rang, naam)
        return if (p == 0) 0 else 9 - p
    }

    /** Kaartpunten, troef telt anders. */
    private fun waarde(naam: Teken, kleur: Int): Int {
        val nr = KjState.kaartNr(kleur, naam)
        return if (nr in 0 until 32) s.kaart[nr].actWaarde else 0
    }

    /** Welke van de vier kaarten pakt de slag? */
    private fun winnaar(slag: List<Zet>): Int {
        val leidend = slag[0].kleur
        var troefErin = false
        for (i in 0 until 4) if (slag[i].kleur == s.troef) troefErin = true
        val telt = if (troefErin) s.troef else leidend

        var beste = -1
        var besteKracht = -1
        for (i in 0 until 4) {
            if (slag[i].kleur != telt) continue
            val k = kracht(slag[i].naam, slag[i].kleur)
            if (k > besteKracht) { besteKracht = k; beste = i }
        }
        return if (beste < 0) 0 else beste
    }

    /**
     * Punten plus roem van een volledige slag, gezien vanuit mijn kant: positief als
     * ik hem pak, negatief als de tegenstander hem pakt (kjmaakslagtest uit KJ0.C).
     */
    private fun slagWaarde(slag: List<Zet>): Int {
        var punten = 0
        for (i in 0 until 4) punten += waarde(slag[i].naam, slag[i].kleur)

        var roem = 0
        val sp = CStr(8)
        for (kleur in 0 until 4) {
            var n = 0
            for (i in 0 until 4) if (slag[i].kleur == kleur) { sp[n] = slag[i].naam; n += 1 }
            sp[n] = NUL
            if (n > 1) roem += e.bepaalRoemPunten(sp, kleur)
        }
        // Vier gelijke kaarten, net als in evalueer().
        if (slag[0].naam == slag[1].naam && slag[1].naam == slag[2].naam && slag[2].naam == slag[3].naam) {
            roem += if (slag[0].naam == 'B') 200 else 100
        }

        val totaal = punten + roem
        return if (slag[winnaar(slag)].mijn) totaal else -totaal
    }

    // -------------------------------------------------- reglementaire zetten

    /**
     * Welke kaarten mag deze stapel spelen? Directe omzetting van kjlegaal uit
     * KJ0.C: troef bekennen en overtroeven waar het moet, kleur bekennen, en bij
     * niet kunnen bekennen wel of niet moeten troeven al naar gelang de slag al aan
     * de eigen kant is.
     */
    private fun legaleZetten(bezit: List<Kaart>, opTafel: List<Zet>, slagIsVanMij: Boolean): List<Kaart> {
        var uit = ArrayList<Kaart>()
        if (opTafel.isEmpty()) return bezit

        val leidend = opTafel[0].kleur

        // Hoogste kaart die de slag nu zou pakken.
        var besteKracht = -1
        var troefErin = false
        for (z in opTafel) if (z.kleur == s.troef) troefErin = true
        val telt = if (troefErin) s.troef else leidend
        for (z in opTafel) {
            if (z.kleur != telt) continue
            val k = kracht(z.naam, z.kleur)
            if (k > besteKracht) besteKracht = k
        }

        if (leidend == s.troef) {
            for (b in bezit) if (b.kleur == s.troef && kracht(b.naam, b.kleur) > besteKracht) uit.add(b)
            if (uit.isEmpty()) for (b in bezit) if (b.kleur == leidend) uit.add(b)
            if (uit.isEmpty()) uit = ArrayList(bezit)
            return uit
        }

        for (b in bezit) if (b.kleur == leidend) uit.add(b)
        if (uit.isNotEmpty()) return uit

        if (slagIsVanMij) {
            // Slag staat al op eigen naam: alles mag, behalve ondertroeven als er
            // getroefd is.
            for (b in bezit) {
                if (troefErin && b.kleur == s.troef && kracht(b.naam, b.kleur) <= besteKracht) continue
                uit.add(b)
            }
            if (uit.isEmpty()) uit = ArrayList(bezit)
            return uit
        }

        for (b in bezit) if (b.kleur == s.troef && kracht(b.naam, b.kleur) > besteKracht) uit.add(b)
        if (uit.isEmpty()) uit = ArrayList(bezit)
        return uit
    }

    // ------------------------------------------------------- kaarten tellen

    /** Kaarten van een eigen stapel: hand (false) of tafel (true) van mijn kant. */
    private fun eigenBezit(tafel: Boolean): MutableList<Kaart> {
        val uit = ArrayList<Kaart>()
        val aantal = if (tafel) 4 else 8
        for (n in 0 until aantal) {
            val d = if (tafel) s.tafel[0][n] else s.hand[0][n]
            if (d.naam != NUL && d.kleur in 0..3) uit.add(Kaart(d.kleur, d.naam))
        }
        return uit
    }

    /** De open tafelkaarten van de tegenstander; die zijn bekend. */
    private fun tegenstanderTafel(): MutableList<Kaart> {
        val uit = ArrayList<Kaart>()
        for (n in 0 until 4) {
            val d = s.tafel[1][n]
            if (d.naam != NUL && d.kleur in 0..3) uit.add(Kaart(d.kleur, d.naam))
        }
        return uit
    }

    /**
     * Kaarten die de tegenstander nog in handen kán hebben. Dat is wat voor ons dicht
     * is: zijn hand en de omgekeerde tafelkaarten. Kleuren waarin hij aantoonbaar
     * verzaakt heeft vallen af.
     */
    private fun mogelijkeHand(kleurVoorkeur: Int): MutableList<Kaart> {
        var tegen = if (s.vrager > 2) s.vrager - 2 else s.vrager
        tegen = if (tegen == 1) 2 else 1

        val uit = ArrayList<Kaart>()
        fun voeg(kleur: Int) {
            if (kleur < 0 || kleur > 3) return
            if (s.verzaakt[tegen - 1][kleur] != 0) return
            val len = s.krtDicht[kleur].len
            for (i in 0 until len) uit.add(Kaart(kleur, s.krtDicht[kleur][i]))
        }
        voeg(kleurVoorkeur)
        if (s.troef != kleurVoorkeur) voeg(s.troef)
        return uit
    }

    // ------------------------------------------------------- troef kiezen

    /**
     * De troefkeuze van Loggen (kj2troef uit KJ2.C). Hij waardeert elke kleur alsof
     * die troef is en kiest de hoogste.
     */
    fun kiesTroef(): Int {
        var mij = if (s.startVrager > 2) s.startVrager - 2 else s.startVrager
        if (mij < 1 || mij > 2) mij = 1
        val mijnHand = mij
        val mijnTafel = mij + 2
        val hijTafel = if (mij == 1) Pos.TAFEL_NOORD else Pos.TAFEL_ZUID

        val t = IntArray(4)
        for (y in 0 until 4) {
            // De troefkleur zelf: mijn kaarten tellen mee, de open troeven van de
            // tegenstander gaan eraf.
            for (idx in 0 until 8) {
                val nr = KjState.kaartNr(y, KjState.rangTroef[idx])
                val w = s.kaart[nr].dichtIkHy
                val p = s.kaart[nr].troefWaarde
                if (w == mijnHand || w == mijnTafel) t[y] += p
                else if (w == hijTafel) t[y] -= p
            }

            // Zijn zichtbare troeven die ik kan afdekken tellen dubbel: van onderaf
            // zijn kaarten, van bovenaf de mijne.
            var x = 7
            var z = 0
            while (x > 0) {
                val nrX = KjState.kaartNr(y, KjState.rangTroef[x])
                if (s.kaart[nrX].dichtIkHy != hijTafel) { x -= 1; continue }
                val nrZ = KjState.kaartNr(y, KjState.rangTroef[z])
                val wz = s.kaart[nrZ].dichtIkHy
                if (wz != mijnHand && wz != mijnTafel) break
                t[y] += s.kaart[nrX].troefWaarde * 2
                z += 1
                x -= 1
            }

            for (xk in 0 until 4) {
                var trh = 0
                var trt = 0
                var p1 = 0
                var p2 = 0
                val rang = if (xk == y) KjState.rangTroef else KjState.rangNorm
                for (idx in 0 until 8) {
                    val nr = KjState.kaartNr(xk, rang[idx])
                    val w = s.kaart[nr].dichtIkHy
                    val hoog = if (idx == 0) 200 else if (idx == 1) 100 else if (idx == 2) 20 else 8 - idx
                    if (w == mijnHand) { if (xk == y) trh += 1 else p1 += hoog }
                    else if (w == mijnTafel) { if (xk == y) trt += 1 else p2 += hoog }
                }
                // Lengte telt kwadratisch, hand en tafel apart.
                if (xk == y) t[y] += trh * trh + trt * trt
                t[y] += ladder(p1) + ladder(p2)
            }
        }

        var beste = 0
        for (x in 1 until 4) if (t[x] > t[beste]) beste = x
        return beste
    }

    /** Drempels waarmee Loggen een zijkleur waardeert. */
    private fun ladder(p: Int): Int =
        if (p >= 320) 6 else if (p >= 300) 5 else if (p >= 220) 4 else if (p >= 200) 3 else if (p > 100) 1 else 0

    // -------------------------------------------------------- de zoektocht

    /**
     * Welke stapel speelt de zoveelste kaart van de slag? De volgorde ligt vast:
     * uitkomer, tafel van de tegenstander, andere stapel van de uitkomer, hand van de
     * tegenstander. Waarden 1..4 zoals VRAGER.
     */
    private fun vragerOpPlek(leider: Int, plek: Int): Int = when (plek) {
        0 -> leider
        1 -> if (leider == 1 || leider == 3) 4 else 3
        2 -> when (leider) { 1 -> 3; 2 -> 4; 3 -> 1; else -> 2 }
        else -> if (leider == 1 || leider == 3) 2 else 1
    }

    private fun kantVan(vrager: Int): Int = if (vrager > 2) vrager - 2 else vrager

    /**
     * Kiest een kaart voor de stapel die aan zet is en zet die in s.lkaart /
     * s.lkleur, net als de tactiekroutines van Ednieuw doen.
     */
    fun kies() {
        val mijnKant = kantVan(s.vrager)
        val plek = s.slagKrtNo.coerceIn(0, 3)
        var leider = if (plek == 0) s.vrager else s[s.slagNr, 0].speler
        if (leider < 1 || leider > 4) leider = s.vrager

        val opTafel = ArrayList<Zet>()
        for (n in 0 until plek) {
            val sk = s[s.slagNr, n]
            opTafel.add(Zet(sk.kleur, sk.naam, kantVan(sk.speler) == mijnKant))
        }

        val bezit = eigenBezit(s.vrager > 2)
        if (bezit.isEmpty()) return

        // De regelcontrole van de motor is doorslaggevend, niet mijn omzetting van
        // kjlegaal: checkValid heeft eigenaardigheden uit 1994 die daar niet in
        // zitten, en een kaart die hij afkeurt kost het hele spel.
        var kandidaten: List<Kaart> = bezit.filter { toegestaan(it) }
        if (kandidaten.isEmpty()) kandidaten = legaleZetten(bezit, opTafel, slagIsVanMij(opTafel))
        if (kandidaten.isEmpty()) kandidaten = bezit

        val score = IntArray(kandidaten.size)
        for (i in kandidaten.indices) {
            val proef = ArrayList(opTafel)
            proef.add(Zet(kandidaten[i].kleur, kandidaten[i].naam, true))
            val gebruikt = listOf(kandidaten[i])
            score[i] = verder(proef, gebruikt, leider, mijnKant)
        }

        val beste = uitkiezen(kandidaten, score, opTafel)

        s.lkleur = kandidaten[beste].kleur
        s.lkaart = kandidaten[beste].naam
        s.tactiek = 70                       // 70 = gekozen door de zoekende speler
        s.vrager = e.wieVrager(s.lkaart, s.lkleur)
    }

    /**
     * Kiest uit de doorgerekende kaarten, met de voorkeuren uit kj2welke en het slot
     * van kj2uitkom0: bij gelijke opbrengst liever geen zekere slag weggeven en liever
     * geen troef.
     */
    private fun uitkiezen(kand: List<Kaart>, score: IntArray, opTafel: List<Zet>): Int {
        val leiden = opTafel.isEmpty()
        val troefGeleid = !leiden && opTafel[0].kleur == s.troef
        val troefOp = s.troef in 0..3 && s.krtDicht[s.troef].len == 0

        fun beste(mag: (Int) -> Boolean): Int {
            var k = -1
            for (i in kand.indices) {
                if (!mag(i)) continue
                if (k < 0 || score[i] > score[k]) k = i
            }
            return k
        }
        fun zeker(i: Int) = isZekereSlag(kand[i])
        fun isTroef(i: Int) = kand[i].kleur == s.troef

        var k: Int
        if (leiden) {
            // Zijn alle troeven op, dan liever een gewone kaart uitspelen.
            if (troefOp) {
                k = beste { !isTroef(it) }
                if (k >= 0 && score[k] > 0) return k
            }
            return maxOf(0, beste { true })
        }

        if (!troefGeleid) {
            k = beste { !zeker(it) && !isTroef(it) }
            if (k >= 0 && score[k] > 0) return k
        }
        k = beste { !zeker(it) }
        if (k >= 0 && score[k] > 0) return k
        return maxOf(0, beste { true })
    }

    /** Is dit een kaart die de slag vrijwel zeker pakt? (de 'Z' van kj2status) */
    private fun isZekereSlag(kaart: Kaart): Boolean {
        for (n in 0 until 8) {
            if (s.hand[0][n].naam == kaart.naam && s.hand[0][n].kleur == kaart.kleur) {
                return s.hand[0][n].gegarandeerd != 0
            }
        }
        for (n in 0 until 4) {
            if (s.tafel[0][n].naam == kaart.naam && s.tafel[0][n].kleur == kaart.kleur) {
                return s.tafel[0][n].gegarandeerd != 0
            }
        }
        return false
    }

    /** Keurt de regelcontrole van de motor deze kaart goed? */
    private fun toegestaan(kaart: Kaart): Boolean {
        val bewaardKaart = s.lkaart
        val bewaardKleur = s.lkleur
        s.lkaart = kaart.naam
        s.lkleur = kaart.kleur
        val goed = e.checkValid() == null
        s.lkaart = bewaardKaart
        s.lkleur = bewaardKleur
        return goed
    }

    /** Staat de slag op dit moment op mijn naam? */
    private fun slagIsVanMij(opTafel: List<Zet>): Boolean {
        if (opTafel.isEmpty()) return false
        val leidend = opTafel[0].kleur
        var troefErin = false
        for (z in opTafel) if (z.kleur == s.troef) troefErin = true
        val telt = if (troefErin) s.troef else leidend
        var beste = 0
        var besteKracht = -1
        for (i in opTafel.indices) {
            if (opTafel[i].kleur != telt) continue
            val k = kracht(opTafel[i].naam, opTafel[i].kleur)
            if (k > besteKracht) { besteKracht = k; beste = i }
        }
        return opTafel[beste].mijn
    }

    /**
     * Vult de slag verder aan tot er vier kaarten liggen. Mijn eigen stapels kiezen
     * het beste, de open tafel van de tegenstander het slechtste voor mij, en over
     * zijn onbekende handkaart wordt gemiddeld.
     */
    private fun verder(opTafel: List<Zet>, gebruikt: List<Kaart>, leider: Int, mijnKant: Int): Int {
        if (opTafel.size >= 4) return slagWaarde(opTafel)

        val plek = opTafel.size
        val vrager = vragerOpPlek(leider, plek)
        val isMijn = kantVan(vrager) == mijnKant
        val slagVanMij = slagIsVanMij(opTafel)

        val bezit: MutableList<Kaart>
        if (isMijn) {
            bezit = eigenBezit(vrager > 2)
            bezit.removeAll { b -> gebruikt.any { it.kleur == b.kleur && it.naam == b.naam } }
        } else if (vrager > 2) {
            bezit = tegenstanderTafel()                 // open, dus precies bekend
        } else {
            bezit = mogelijkeHand(if (opTafel.isNotEmpty()) opTafel[0].kleur else s.troef)
        }
        bezit.removeAll { b -> opTafel.any { it.kleur == b.kleur && it.naam == b.naam } }

        val zetten = legaleZetten(bezit, opTafel, if (isMijn) slagVanMij else !slagVanMij)
        if (zetten.isEmpty()) return slagWaarde(aanvullen(opTafel))

        if (isMijn) {
            var best = Int.MIN_VALUE
            for (z in zetten) {
                val volgend = ArrayList(opTafel)
                volgend.add(Zet(z.kleur, z.naam, true))
                val nu = ArrayList(gebruikt)
                nu.add(z)
                best = maxOf(best, verder(volgend, nu, leider, mijnKant))
            }
            return best
        }

        if (vrager > 2) {
            var slechtst = Int.MAX_VALUE
            for (z in zetten) {
                val volgend = ArrayList(opTafel)
                volgend.add(Zet(z.kleur, z.naam, false))
                slechtst = minOf(slechtst, verder(volgend, gebruikt, leider, mijnKant))
            }
            return slechtst
        }

        var som = 0
        for (z in zetten) {
            val volgend = ArrayList(opTafel)
            volgend.add(Zet(z.kleur, z.naam, false))
            som += verder(volgend, gebruikt, leider, mijnKant)
        }
        return som / zetten.size
    }

    /**
     * Vult een onvolledige slag aan met de laatst gelegde kaart, zodat er altijd
     * gewaardeerd kan worden. Komt alleen voor als er niets legaals meer over is.
     */
    private fun aanvullen(opTafel: List<Zet>): List<Zet> =
        (0 until 4).map { if (it < opTafel.size) opTafel[it] else opTafel[opTafel.size - 1] }
}
