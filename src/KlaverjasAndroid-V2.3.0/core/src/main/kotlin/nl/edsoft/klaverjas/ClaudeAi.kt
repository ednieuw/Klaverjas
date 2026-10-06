package nl.edsoft.klaverjas

/**
 * De speelwijze Claude: kiest een kaart door het hele spel een aantal keer door te spelen.
 *
 * Wat de tegenstander in handen heeft is onbekend, dus worden zijn hand en de dichte kaarten
 * onder de tafels telkens opnieuw willekeurig verdeeld, binnen wat bekend is: de kaarten die al
 * gespeeld of getoond zijn, en de kleuren waarin hij niet kon bekennen. Voor elke toegestane
 * kaart wordt dan het rest van het spel doorgespeeld, met een eenvoudige speelwijze voor beide
 * kanten, tot en met de telling van pit en nat. De kaart met de beste gemiddelde uitslag wint.
 *
 * Anders dan Ednieuw (vuistregels) en Ronlog (rekent één slag door) kijkt deze speler dus naar de
 * uitslag van het héle spel. Het getal van de eigen kant minus dat van de tegenstander telt, dus
 * pit, roem en nat zitten er vanzelf in.
 *
 * De toevalsreeks is die van deze speler zelf en staat los van die van de engine: de spellen
 * die gedeeld worden veranderen er niet door, en bij hetzelfde zaad speelt hij hetzelfde.
 */
internal class ClaudeAi(private val e: KjEngine, zaad: Long = 20261003L, private val proeven: Int = standaardProeven) {
    private val s: KjState get() = e.s
    private val rnd = Toevalsreeks(zaad)

    private fun toeval(n: Int) = rnd.volgende(n)

    // ------------------------------------------------------ de stand uit de engine

    /**
     * Wat de speler die aan zet is weet, en niets meer: zijn eigen kaarten, de open tafels,
     * wat gespeeld is en welke kleuren de tegenstander niet in zijn hand heeft.
     */
    private inner class Zicht(val ik: Int, troefKiezen: Boolean) {
        val basis = ClaudeStand()
        val pool = IntArray(32)
        var poolN = 0
        var tegenstanderHand = 0
        val onbekendDicht = ArrayList<IntArray>()      // [kant, plek]
        val kleurLeeg = BooleanArray(4)                // de tegenstander heeft die kleur niet in zijn hand
        val tegen = 1 - ik

        init {
            val st = basis
            st.troef = if (troefKiezen) 0 else s.troef
            st.speler = if (troefKiezen) ik else (if (s.speler > 2) s.speler - 3 else s.speler - 1)
            st.slagNr = if (troefKiezen) 1 else s.slagNr
            for (k in 0..1) {
                st.punten[k] = s.puntenSpel[k]
                st.roem[k] = s.roem[k]
            }

            for (n in 0 until 32) {
                val pos = s.kaart[n].dichtIkHy
                when {
                    pos == Pos.HAND_ZUID + ik -> st.hand[ik] = st.hand[ik] or (1 shl n)
                    pos == Pos.TAFEL_ZUID + ik -> st.open[ik][e.tafelPos(n).coerceIn(0, 3)] = n
                    pos == Pos.TAFEL_ZUID + tegen -> st.open[tegen][e.tafelPos(n).coerceIn(0, 3)] = n
                    pos == Pos.NIEUW_ZUID + ik -> st.dicht[ik][e.tafelPos(n).coerceIn(0, 3)] = n
                    pos == Pos.NIEUW_ZUID + tegen -> st.dicht[tegen][e.tafelPos(n).coerceIn(0, 3)] = n
                    pos == Pos.GESPEELD -> st.gespeeld = st.gespeeld or (1 shl n)
                    else -> {
                        pool[poolN++] = n
                        if (pos == Pos.HAND_ZUID + tegen) tegenstanderHand++
                    }
                }
            }
            // Welke dichte plekken zijn nog onbekend? De vlag staat op 1 zolang er nog een dichte kaart ligt.
            for (k in 0..1) for (i in 0..3) {
                val vlag = if (k == 0) s.tZuid[i] else s.tNoord[i]
                if (vlag != 0 && st.dicht[k][i] < 0) onbekendDicht.add(intArrayOf(k, i))
            }

            if (!troefKiezen) {
                // De lopende slag.
                val aantal = s.slagKrtNo.coerceIn(0, 3)
                st.leider = if (aantal == 0) ik else kant(s[s.slagNr, 0].speler) - 1
                for (k in 0 until aantal) {
                    val sk = s[s.slagNr, k]
                    val c = ClaudeTabel.kaartNr(sk.kleur, sk.naam)
                    st.legVast(c, kant(sk.speler) - 1, sk.speler < 3)
                }
                // Kleuren waarin de tegenstander niet kon bekennen: in de afgelopen slagen en in deze.
                for (n in 1..s.slagNr) {
                    val tot = if (n == s.slagNr) aantal else 4
                    if (tot < 2) continue
                    val led = s[n, 0].kleur
                    for (k in 1 until tot) {
                        val sk = s[n, k]
                        if (sk.kleur != led && sk.speler == Pos.HAND_ZUID + tegen && led in 0..3) kleurLeeg[led] = true
                    }
                }
            } else {
                st.leider = ik
            }
        }

        /** Verdeelt de onbekende kaarten willekeurig en geeft een volledige stand. */
        fun trek(uit: ClaudeStand) {
            uit.zet(basis)
            val p = pool.copyOf(poolN)
            for (i in p.size - 1 downTo 1) {
                val j = toeval(i + 1)
                val x = p[i]; p[i] = p[j]; p[j] = x
            }
            var hand = 0
            var geplaatst = 0
            val rest = IntArray(p.size)
            var restN = 0
            for (c in p) {
                if (geplaatst < tegenstanderHand && !kleurLeeg[ClaudeTabel.kleur(c)]) {
                    hand = hand or (1 shl c); geplaatst++
                } else rest[restN++] = c
            }
            // Zo weinig keuze dat de kleuren niet pasten: dan toch opvullen.
            var r = 0
            while (geplaatst < tegenstanderHand && r < restN) { hand = hand or (1 shl rest[r++]); geplaatst++ }
            uit.hand[tegen] = hand
            for (plek in onbekendDicht) {
                if (r >= restN) break
                uit.dicht[plek[0]][plek[1]] = rest[r++]
            }
        }
    }

    private fun kant(vrager: Int) = if (vrager > 2) vrager - 2 else vrager

    // ------------------------------------------------------------- de speelwijze

    private val eind = IntArray(2)

    /** Speelt het spel uit met de eenvoudige speelwijze voor beide kanten. */
    private fun speelUit(st: ClaudeStand) {
        while (!st.klaar) st.speel(kies(st))
    }

    private fun waarde(st: ClaudeStand, ik: Int): Int {
        st.eindstand(eind)
        return if (ik == 0) eind[0] - eind[1] else eind[1] - eind[0]
    }

    /**
     * De eenvoudige speelwijze waarmee de rest van het spel wordt doorgespeeld. Ze gebruikt alleen wat
     * de speler zelf kan zien, zodat de uitkomst niet beter wordt dan het spel toelaat.
     */
    private fun kies(st: ClaudeStand): Int {
        val mag = st.toegestaan()
        if (mag and (mag - 1) == 0) return Integer.numberOfTrailingZeros(mag)
        val kant = st.aanZet
        val troef = st.troef
        return if (st.fase == 0) uitkomen(st, mag, kant, troef) else bijspelen(st, mag, kant, troef)
    }

    /** Wat deze kant nog niet gezien heeft: niet gespeeld en niet van hemzelf. */
    private fun ongezien(st: ClaudeStand, kant: Int): Int =
        (st.gespeeld or st.hand[kant] or st.tafelMasker(kant)).inv()

    /** Is deze kaart de hoogste die er in zijn kleur nog kan zijn? */
    private fun hoogste(c: Int, troef: Int, ongezien: Int): Boolean {
        var m = ongezien and ClaudeTabel.kleurMasker(ClaudeTabel.kleur(c))
        val k = ClaudeTabel.kracht(c, troef)
        while (m != 0) {
            val x = Integer.numberOfTrailingZeros(m)
            m = m and (m - 1)
            if (ClaudeTabel.kracht(x, troef) > k) return false
        }
        return true
    }

    private fun uitkomen(st: ClaudeStand, mag: Int, kant: Int, troef: Int): Int {
        val weg = ongezien(st, kant)
        var beste = -1
        var besteScore = Int.MIN_VALUE
        var m = mag
        while (m != 0) {
            val c = Integer.numberOfTrailingZeros(m)
            m = m and (m - 1)
            val p = ClaudeTabel.punten(c, troef)
            val trf = ClaudeTabel.kleur(c) == troef
            val score = if (hoogste(c, troef, weg)) {
                // Een kaart die niet te kloppen is: eerst de punten ophalen, troef alleen als wij troef maakten.
                if (!trf) 200 + p else if (st.speler == kant) 130 + p else 60 + p
            } else {
                50 - 3 * p - ClaudeTabel.kracht(c, troef) - (if (trf) 40 else 0)
            }
            if (score > besteScore) { besteScore = score; beste = c }
        }
        return beste
    }

    private fun bijspelen(st: ClaudeStand, mag: Int, kant: Int, troef: Int): Int {
        val mijn = st.winnaarKant() == kant
        val laatste = st.fase == 3
        val weg = ongezien(st, kant)
        val houdt = laatste || hoogste(st.winnendeKaart, troef, weg)
        var beste = -1
        var besteScore = Int.MIN_VALUE
        var m = mag
        while (m != 0) {
            val c = Integer.numberOfTrailingZeros(m)
            m = m and (m - 1)
            val p = ClaudeTabel.punten(c, troef)
            val k = ClaudeTabel.kracht(c, troef)
            val trf = ClaudeTabel.kleur(c) == troef
            val score: Int = if (mijn) {
                // Staat de slag op onze naam: smeren als hij blijft staan, anders zo goedkoop mogelijk.
                if (houdt) p * 8 - k else -(p * 8 + k)
            } else if (st.verslaatBeste(c)) {
                // De goedkoopste kaart die de slag pakt.
                1000 - (p * 8 + k)
            } else {
                // Kan de slag niet pakken: zo weinig mogelijk weggeven, en liever geen troef.
                -(p * 8 + k) - (if (trf) 100 else 0)
            }
            if (score > besteScore) { besteScore = score; beste = c }
        }
        return beste
    }

    // --------------------------------------------------------------- kaart kiezen

    /**
     * De toegestane kaarten en hun som van uitslagen over alle proeven, zonder iets in de engine te
     * veranderen. Leeg als er niets te kiezen valt. Apart van [kies] zodat een proef kan aantonen dat de
     * scores niet afhangen van wat de speler niet kan zien.
     */
    internal fun kaartScores(): Pair<List<Int>, LongArray>? {
        val ik = kant(s.vrager) - 1
        val zicht = Zicht(ik, troefKiezen = false)
        val basis = zicht.basis

        // De kaarten die de regelcontrole van de engine goedkeurt; die is doorslaggevend.
        val gok = basis.toegestaan()
        val kandidaten = ArrayList<Int>()
        for (c in 0 until 32) if (gok and (1 shl c) != 0 && engineKeurtGoed(c)) kandidaten.add(c)
        if (kandidaten.isEmpty()) for (c in 0 until 32) if (gok and (1 shl c) != 0) kandidaten.add(c)
        if (kandidaten.isEmpty()) return null

        val som = LongArray(kandidaten.size)
        if (kandidaten.size > 1) {
            val trek = ClaudeStand()
            val werk = ClaudeStand()
            repeat(proeven) {
                zicht.trek(trek)
                for (i in kandidaten.indices) {
                    werk.zet(trek)
                    werk.speel(kandidaten[i])
                    speelUit(werk)
                    som[i] += waarde(werk, ik).toLong()
                }
            }
        }
        return kandidaten to som
    }

    /** Kiest een kaart voor de stapel die aan zet is en zet die in s.lkaart / s.lkleur. */
    fun kies() {
        val (kandidaten, som) = kaartScores() ?: return
        var beste = 0
        for (i in 1 until som.size) if (som[i] > som[beste]) beste = i
        val gekozen = kandidaten[beste]

        s.lkleur = ClaudeTabel.kleur(gekozen)
        s.lkaart = ClaudeTabel.naam(gekozen)
        s.tactiek = TACTIEK
        s.vrager = e.wieVrager(s.lkaart, s.lkleur)
    }

    /** Keurt de regelcontrole van de engine deze kaart goed? */
    private fun engineKeurtGoed(c: Int): Boolean {
        val bewaardKaart = s.lkaart
        val bewaardKleur = s.lkleur
        s.lkaart = ClaudeTabel.naam(c)
        s.lkleur = ClaudeTabel.kleur(c)
        val goed = e.checkValid() == null
        s.lkaart = bewaardKaart
        s.lkleur = bewaardKleur
        return goed
    }

    // ----------------------------------------------------------------- troef kiezen

    /** De som van uitslagen per troefkleur over alle proeven (zie [kaartScores]). */
    internal fun troefScores(): LongArray {
        val ik = kant(s.startVrager) - 1
        val zicht = Zicht(ik, troefKiezen = true)
        val som = LongArray(4)
        val trek = ClaudeStand()
        val werk = ClaudeStand()
        repeat(proeven * TROEF_FACTOR) {
            zicht.trek(trek)
            for (t in 0..3) {
                werk.zet(trek)
                werk.troef = t
                speelUit(werk)
                som[t] += waarde(werk, ik).toLong()
            }
        }
        return som
    }

    /** Kiest de troefkleur met het beste gemiddelde over het hele spel. */
    fun kiesTroef(): Int {
        val som = troefScores()
        var beste = 0
        for (t in 1..3) if (som[t] > som[beste]) beste = t
        return beste
    }

    companion object {
        /** Het nummer waaronder Claude in de tactiekstatistiek komt (70 is Ronlog). */
        const val TACTIEK = 71
        /** Hoeveel keer er per zet een verdeling van de onbekende kaarten wordt doorgespeeld. */
        var standaardProeven = 200
        private const val TROEF_FACTOR = 3
    }
}
