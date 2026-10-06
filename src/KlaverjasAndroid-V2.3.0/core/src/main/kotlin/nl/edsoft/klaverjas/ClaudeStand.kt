package nl.edsoft.klaverjas

/**
 * Een compacte, snelle simulatie van één spel klaverjas voor de speelwijze Claude.
 *
 * Los van [KjEngine], die met globale toestand en C-strings werkt en daardoor te traag is om
 * tienduizenden keren door te rekenen. De regels zijn dezelfde: de testen leggen de
 * regelcontrole en de puntentelling naast die van de engine.
 *
 * Kaarten zijn getallen 0..31: kleur * 8 + plek in "AHVBT987" (zoals [KjState.kaartNr]).
 * Een stapel is een bitmasker. Per slag speelt elke kant één kaart uit zijn hand en één van zijn
 * tafel; de uitkomer kiest welke stapel hij het eerst speelt. De volgorde ligt vast:
 * uitkomer, tafel van de tegenstander, andere stapel van de uitkomer, hand van de tegenstander.
 */
internal object ClaudeTabel {
    /** Sterkte binnen de kleur: hoger is sterker. Index = plek in "AHVBT987". */
    private val krachtNorm = intArrayOf(7, 5, 4, 3, 6, 2, 1, 0)   // A H V B T 9 8 7 -> ATHVB987
    private val krachtTroef = intArrayOf(5, 3, 2, 7, 4, 6, 1, 0)  // -> B9ATHV87
    private val puntNorm = intArrayOf(11, 4, 3, 2, 10, 0, 0, 0)
    private val puntTroef = intArrayOf(11, 4, 3, 20, 10, 14, 0, 0)

    fun kleur(c: Int) = c ushr 3
    fun plek(c: Int) = c and 7
    fun kracht(c: Int, troef: Int) = if (kleur(c) == troef) krachtTroef[plek(c)] else krachtNorm[plek(c)]
    fun punten(c: Int, troef: Int) = if (kleur(c) == troef) puntTroef[plek(c)] else puntNorm[plek(c)]

    /** Alle kaarten van een kleur als masker. */
    fun kleurMasker(k: Int) = 0xFF shl (8 * k)

    /** Het kaartnummer van (kleur, naam), of -1. */
    fun kaartNr(kleur: Int, naam: Teken): Int {
        val p = KjState.rangRoem.indexOf(naam)
        return if (p < 0 || kleur !in 0..3) -1 else kleur * 8 + p
    }

    fun naam(c: Int): Teken = KjState.rangRoem[plek(c)]

    /**
     * Roem van de kaarten van één kleur in één slag, als in bepaalRoemPunten(): drie
     * opeenvolgend 20, vier opeenvolgend 50, en heer plus vrouw van troef (het stuk) 20 erbij.
     */
    fun roemKleur(gevonden: Int, kleur: Int, troef: Int): Int {
        // gevonden: bit p gezet als de kaart op plek p van deze kleur in de slag ligt.
        var i = 0
        var j = 0
        for (p in 0 until 8) {
            if (gevonden and (1 shl p) != 0) { i++; if (i > j) j = i } else i = 0
        }
        var roem = 0
        if (kleur == troef && gevonden and 0b110 == 0b110) roem = 20   // plek 1 = heer, plek 2 = vrouw
        if (j == 3) roem += 20
        if (j == 4) roem += 50
        return roem
    }
}

internal class ClaudeStand {
    var troef = 0
    /** Welke kant troef maakte: 0 = Zuid, 1 = Noord. */
    var speler = 0
    val hand = IntArray(2)
    /** Open tafelkaart per plek (of -1) en de kaart die er nog onder ligt (of -1). */
    val open = Array(2) { IntArray(4) { -1 } }
    val dicht = Array(2) { IntArray(4) { -1 } }
    val punten = IntArray(2)
    val roem = IntArray(2)
    var slagNr = 1
    var leider = 0
    var gespeeld = 0

    // De slag die nu ligt.
    val slag = IntArray(4)
    val wie = IntArray(4)
    var fase = 0
    private var leiderUitHand = true

    /** Winnende kaart (index in [slag]) van wat er nu ligt. */
    private var beste = 0

    fun kopieer(): ClaudeStand {
        val s = ClaudeStand()
        s.zet(this)
        return s
    }

    fun zet(o: ClaudeStand) {
        troef = o.troef; speler = o.speler; slagNr = o.slagNr; leider = o.leider
        gespeeld = o.gespeeld; fase = o.fase; leiderUitHand = o.leiderUitHand; beste = o.beste
        for (k in 0..1) {
            hand[k] = o.hand[k]; punten[k] = o.punten[k]; roem[k] = o.roem[k]
            for (i in 0..3) { open[k][i] = o.open[k][i]; dicht[k][i] = o.dicht[k][i] }
        }
        for (i in 0..3) { slag[i] = o.slag[i]; wie[i] = o.wie[i] }
    }

    fun tafelMasker(kant: Int): Int {
        var m = 0
        for (i in 0..3) { val c = open[kant][i]; if (c >= 0) m = m or (1 shl c) }
        return m
    }

    /** Wie is er nu aan zet (0 = Zuid, 1 = Noord)? */
    val aanZet: Int get() = if (fase == 0 || fase == 2) leider else 1 - leider

    /** Uit welke stapel moet de volgende kaart komen? true = hand. */
    val uitHand: Boolean
        get() = when (fase) {
            1 -> false                 // de tafel van de tegenstander
            2 -> !leiderUitHand        // de andere stapel van de uitkomer
            3 -> true                  // de hand van de tegenstander
            else -> true
        }

    /** De kaarten waaruit de speler die aan zet is mag kiezen, regels meegerekend. */
    fun toegestaan(): Int {
        val kant = aanZet
        val pile: Int = when (fase) {
            0 -> hand[kant] or tafelMasker(kant)           // de uitkomer kiest vrij
            1 -> tafelMasker(kant)
            2 -> if (leiderUitHand) tafelMasker(kant) else hand[kant]
            else -> hand[kant]
        }
        if (fase == 0 || pile == 0) return pile
        return legaal(pile, kant)
    }

    private fun legaal(pile: Int, kant: Int): Int {
        val led = ClaudeTabel.kleur(slag[0])
        val tr = ClaudeTabel.kleurMasker(troef)
        var troefOp = false
        var hoogsteTroef = -1
        for (i in 0 until fase) {
            if (ClaudeTabel.kleur(slag[i]) == troef) {
                troefOp = true
                val k = ClaudeTabel.kracht(slag[i], troef)
                if (k > hoogsteTroef) hoogsteTroef = k
            }
        }
        val troeven = pile and tr
        if (led == troef) {
            if (troeven != 0) {
                val hoger = hogerDan(troeven, hoogsteTroef)
                return if (hoger != 0) hoger else troeven   // overtroeven als het kan
            }
            return pile
        }
        val volgen = pile and ClaudeTabel.kleurMasker(led)
        if (volgen != 0) return volgen                      // kleur bekennen
        if (winnaarKant() == kant) return pile              // de slag staat al op eigen naam
        if (troeven != 0) {
            if (troefOp) {
                val hoger = hogerDan(troeven, hoogsteTroef)
                return if (hoger != 0) hoger else pile
            }
            return troeven                                  // moet troeven
        }
        return pile
    }

    private fun hogerDan(masker: Int, kracht: Int): Int {
        var uit = 0
        var m = masker
        while (m != 0) {
            val c = Integer.numberOfTrailingZeros(m)
            m = m and (m - 1)
            if (ClaudeTabel.kracht(c, troef) > kracht) uit = uit or (1 shl c)
        }
        return uit
    }

    /** Welke kant heeft de slag op dit moment? */
    fun winnaarKant(): Int = wie[beste]

    val winnendeKaart: Int get() = slag[beste]

    /** Speelt kaart [c] voor degene die aan zet is. */
    fun speel(c: Int) {
        val kant = aanZet
        val bit = 1 shl c
        if (hand[kant] and bit != 0) {
            hand[kant] = hand[kant] and bit.inv()
            if (fase == 0) leiderUitHand = true
        } else {
            for (i in 0..3) if (open[kant][i] == c) { open[kant][i] = -1; break }
            if (fase == 0) leiderUitHand = false
        }
        slag[fase] = c
        wie[fase] = kant
        if (fase > 0 && verslaat(c, slag[beste])) beste = fase
        fase++
        gespeeld = gespeeld or bit
        if (fase == 4) slagKlaar()
    }

    /** Zou [c] de kaart verslaan die nu de slag heeft? */
    fun verslaatBeste(c: Int): Boolean = verslaat(c, slag[beste])

    /**
     * Legt een kaart vast die al gespeeld is (en dus uit zijn stapel is), zoals de kaarten van de
     * lopende slag bij het opbouwen van de stand uit de engine.
     */
    fun legVast(c: Int, kant: Int, uitHand: Boolean) {
        if (fase == 0) leiderUitHand = uitHand
        slag[fase] = c
        wie[fase] = kant
        if (fase > 0 && verslaat(c, slag[beste])) beste = fase
        fase++
        gespeeld = gespeeld or (1 shl c)
    }

    /** Verslaat kaart [a] kaart [b] (die al ligt)? */
    private fun verslaat(a: Int, b: Int): Boolean {
        val ka = ClaudeTabel.kleur(a)
        val kb = ClaudeTabel.kleur(b)
        if (ka == kb) return ClaudeTabel.kracht(a, troef) > ClaudeTabel.kracht(b, troef)
        return ka == troef
    }

    /** Waarde van de slag voor de winnaar: kaartpunten plus roem. */
    private fun slagKlaar() {
        val w = wie[beste]
        var p = 0
        for (i in 0..3) p += ClaudeTabel.punten(slag[i], troef)
        punten[w] += p

        var r = 0
        for (k in 0..3) {
            var gevonden = 0
            var n = 0
            for (i in 0..3) if (ClaudeTabel.kleur(slag[i]) == k) { gevonden = gevonden or (1 shl ClaudeTabel.plek(slag[i])); n++ }
            if (n > 1) r += ClaudeTabel.roemKleur(gevonden, k, troef)
        }
        // Vier gelijke kaarten, over de hele slag.
        val p0 = ClaudeTabel.plek(slag[0])
        if (ClaudeTabel.plek(slag[1]) == p0 && ClaudeTabel.plek(slag[2]) == p0 && ClaudeTabel.plek(slag[3]) == p0) {
            r += if (p0 == 3) 200 else 100                  // vier boeren: 200
        }
        roem[w] += r
        if (slagNr == 8) roem[w] += 10                      // de laatste slag

        // De dichte kaarten onder een gespeelde tafelkaart draaien om.
        for (k in 0..1) for (i in 0..3) {
            if (open[k][i] < 0 && dicht[k][i] >= 0) { open[k][i] = dicht[k][i]; dicht[k][i] = -1 }
        }
        leider = w
        fase = 0
        beste = 0
        slagNr++
    }

    val klaar: Boolean get() = slagNr > 8

    /**
     * De uitslag van dit spel, als [ClaudeEind]: pit, tegenpit en nat zoals evalueerSpel() ze telt.
     * Alleen aan te roepen als [klaar].
     */
    fun eindstand(uit: IntArray) {
        val r = roem.copyOf()
        for (k in 0..1) if (punten[k] == 152) r[k] += 100
        // Tegenpit: alle slagen voor de kant die niet troef maakte.
        if (punten[0] == 152 && speler == 1) r[0] += 200
        if (punten[1] == 152 && speler == 0) r[1] += 200
        var a = punten[0] + r[0]
        var b = punten[1] + r[1]
        if (speler == 0 && a <= b) { b += a; a = 0 }        // nat
        if (speler == 1 && b <= a) { a += b; b = 0 }
        uit[0] = a
        uit[1] = b
    }
}
