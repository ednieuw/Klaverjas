package nl.edsoft.klaverjas

/** Eén van de 32 kaarten in het spel (struct krts uit KJ.C). */
class SpeelKaart {
    var naam: Teken = NUL            // 'A','H','V','B','T','9','8','7'
    var puntWaarde = 0               // waarde als niet-troef
    var troefWaarde = 0              // waarde als troef
    var actWaarde = 0                // actuele waarde, gezet zodra troef bekend is
    var dichtIkHy = 0                // zie Pos
    var troef = 0
    var kleur = 0                    // 0=Klaver 1=Schoppen 2=Ruiten 3=Harten
}

/** De waarden van kaart.dichtIkHy uit het origineel: waar een kaart zich bevindt. */
object Pos {
    const val DICHT = 0        // nog niet uitgedeeld / onbekend
    const val HAND_ZUID = 1
    const val HAND_NOORD = 2
    const val TAFEL_ZUID = 3   // open op tafel bij Zuid
    const val TAFEL_NOORD = 4
    const val GESPEELD = 5
    const val DICHT_ZUID = 33  // dicht onder de tafelkaarten van Zuid
    const val DICHT_NOORD = 44
    const val NIEUW_ZUID = 13  // net omgedraaid, wordt volgende slag TAFEL_ZUID
    const val NIEUW_NOORD = 14
}

/** Kaart in hand/tafel-overzicht met bijbehorende slagkans (struct deck). */
class Deck {
    var slagkans = 0
    var slagkans0 = 0          // slagkans aan het begin van de slag
    var naam: Teken = NUL
    var kleur = 0
    var waarde = 0
    var troef = 0
    var gegarandeerd = 0       // slagkans > 95
}

/** Eén gespeelde kaart binnen een slag (struct slach). */
class SlagKaart {
    var kleur = 0
    var naam: Teken = NUL
    var troef = 0
    var speler = 0
    var kans = 0
    var waarde = 0
    var tactiek = 0
}

/**
 * Alle globale toestand van het originele programma bij elkaar. Het origineel
 * werkt volledig met globals; die structuur is bewust overgenomen zodat de
 * vertaling van de speel- en tactiekroutines één-op-één blijft.
 */
class KjState(zaad: Long? = null) {
    val kaart = Array(32) { SpeelKaart() }
    val hand = Array(2) { Array(8) { Deck() } }
    val tafel = Array(2) { Array(8) { Deck() } }

    /**
     * slag[9][4] uit het origineel, maar plat opgeslagen. Het origineel indexeert
     * op een paar plaatsen buiten de rij (slag[SLAG][4]); met een platte rij valt
     * dat net als in C door naar slag[SLAG+1][0].
     */
    private val slagen = Array(48) { SlagKaart() }

    operator fun get(slag: Int, i: Int): SlagKaart = slagen[slag * 4 + i]

    val deeltabel = IntArray(32)
    val verzaakt = Array(2) { IntArray(4) }
    val tNoord = IntArray(4)   // ligt er nog een dichte kaart onder?
    val tZuid = IntArray(4)

    // Kaartverzamelingen als C-strings, per kleur en totaal.
    val krtWeg = CStr.new2(4, 16)
    val krtVrij = CStr.new2(4, 16)
    val krtDicht = CStr.new2(4, 16)
    val krtTotWeg = CStr(40)
    val krtTotVrij = CStr(40)
    val krtTotDicht = CStr(40)

    // [..][0] = kant van de huidige vrager, [..][1] = tegenpartij
    val iKrt = Array(4) { IntArray(2) }
    val iKrtTafel = Array(4) { IntArray(2) }
    val kHand = CStr.new3(2, 4, 16)
    val kTafel = CStr.new3(2, 4, 16)
    var iKrtGespeeld = 0

    var vrager = 0
    var startVrager = 0
    var troef = 999
    var speler = 0
    var slagNr = 0
    var slagKrtNo = 0

    /** Wie er op dit toestel met de hand speelt: [0] = Zuid, [1] = Noord. */
    val mens = booleanArrayOf(true, false)

    /** Wacht hier een mens op zijn beurt? Eén plek voor deze regel. */
    fun mensIsAanZet(vrager: Int): Boolean {
        val kant = if (vrager > 2) vrager - 2 else vrager
        if (kant < 1 || kant > 2) return false
        return mens[kant - 1]
    }

    val roem = IntArray(2)
    val gewonnen = IntArray(2)
    val puntenSpel = IntArray(2)
    val puntenTotaalSpel = LongArray(2)   // [0]=Zuid, [1]=Noord

    var lkaart: Teken = NUL
    var lkleur = 0
    var lkaart3: Teken = NUL
    var lkleur3 = 0
    var skrt41: Teken = NUL

    var hoogste = 0
    var tactiek = 0
    var tactiek41 = false
    var tactiekLaag = false
    var tactiekTT = false

    /** true = beide handen door de computer gespeeld (demo). */
    var comp = false
    /** Speelt deze kant volgens de zoekende speler? 0 = Zuid, 1 = Noord. */
    val zoekt = booleanArrayOf(false, false)
    /** Speelt deze kant volgens Claude (het hele spel doorspelen)? Gaat voor [zoekt]. */
    val claude = booleanArrayOf(false, false)
    /** true = kaarten van de tegenstander verborgen. */
    var dicht = true

    // Statistiek over de hele sessie.
    val kaartpnt = LongArray(2)
    val troefpnt = LongArray(2)
    val gewonnenTot = LongArray(2)
    val roempnt = LongArray(2)
    val troefkrt = LongArray(2)
    val pit = LongArray(2)
    val tpit = LongArray(2)
    val nat = LongArray(2)
    /** Vier gelijke kaarten in één slag, per kant geteld. */
    val superroem = LongArray(2)
    val tac = LongArray(80)

    /** Geen zaad: dan varieert het per keer. Wel een zaad: exact dezelfde spellen. */
    val rnd = Toevalsreeks(zaad ?: (1L + (Math.random() * 0xFFFFFFFEL).toLong()))

    /** Borland random(num): 0 <= resultaat < num, en 0 bij num <= 0. */
    fun random(num: Int): Int = rnd.volgende(num)

    companion object {
        const val SLAGKANS_LEVEL = 15

        // Volgorde van kaarten binnen een kleur, hoog -> laag.
        val rangTroef = "B9ATHV87".tekens()
        val rangNorm = "ATHVB987".tekens()
        val rangRoem = "AHVBT987".tekens()

        /** Faculteiten 0..18, gebruikt door guillermie(). */
        val fact = doubleArrayOf(
            1.0, 1.0, 2.0, 6.0, 24.0, 120.0, 720.0, 5040.0, 40320.0, 362880.0,
            3628800.0, 39916800.0, 479001600.0, 6227020800.0, 87178291200.0,
            1307674368000.0, 20922789888000.0, 355687428096000.0, 6402373705728000.0,
        )

        /** Index in kaart[] van kaart (kleur, naam). */
        fun kaartNr(kleur: Int, naam: Teken): Int = CStr.pos(rangRoem, naam) + kleur * 8 - 1
    }
}
