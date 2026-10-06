package nl.edsoft.klaverjas

/** Eén kaart zoals de UI hem moet tekenen. */
class KaartView {
    var index = 0        // 0..31, index in kaart[]
    var naam: Teken = NUL
    var kleur = 0
    var open = false     // false = achterkant tonen
    var klikbaar = false
    var plek = 0         // 0..3 voor tafelkaarten, anders volgnummer
}

/** Een gespeelde kaart in de huidige of vorige slag. */
data class SlagView(val kleur: Int, val naam: Teken, val speler: Int, val tactiek: Int)

/**
 * Momentopname van de speltoestand. De speellogica draait in een eigen coroutine; de
 * UI tekent uitsluitend uit zo'n momentopname, zodat er geen races op gedeelde
 * toestand kunnen ontstaan. Elke aanroep van [KjSpel.snapshot] maakt een nieuw object.
 *
 * Alle velden zijn absoluut (Zuid/Noord); de `mijn...`-eigenschappen vertalen naar het
 * perspectief van dit toestel ([mijnKant]).
 */
class SpelView {
    val handZuid = ArrayList<KaartView>()
    val handNoord = ArrayList<KaartView>()
    val tafelZuid = ArrayList<KaartView>()
    val tafelNoord = ArrayList<KaartView>()
    val dichtZuid = ArrayList<KaartView>()
    val dichtNoord = ArrayList<KaartView>()

    /** Per tafelplek 0..3: ligt daar nog een dichte kaart onder? (tZuid[]/tNoord[]) */
    val onderZuid = BooleanArray(4)
    val onderNoord = BooleanArray(4)
    var slag: List<SlagView> = emptyList()
    var vorigeSlag: List<SlagView> = emptyList()

    var troef = 999

    /** Wie troef maakte: 1 = Zuid, 2 = Noord, 0 = nog niet bekend. */
    var troefmaker = 0
    var slagNr = 0
    var aanZet = 0              // 1..4, wie moet er spelen
    var wachtOpSpeler = false   // true = de mens is aan zet
    var troefVraag = false      // true = de mens moet troef kiezen
    var wachtOpVerder = false   // true = een slag is net afgelopen, wacht op een tik

    var puntenZuid = 0
    var puntenNoord = 0
    var roemZuid = 0
    var roemNoord = 0
    var totaalZuid = 0L
    var totaalNoord = 0L
    var partijenZuid = 0
    var partijenNoord = 0

    /** Welke kant "ik" ben op dit toestel: 1 = Zuid, 2 = Noord. */
    var mijnKant = 1

    private val ikBenZuid get() = mijnKant != 2

    val mijnHand get() = if (ikBenZuid) handZuid else handNoord
    val zijnHand get() = if (ikBenZuid) handNoord else handZuid
    val mijnTafel get() = if (ikBenZuid) tafelZuid else tafelNoord
    val zijnTafel get() = if (ikBenZuid) tafelNoord else tafelZuid
    val mijnDicht get() = if (ikBenZuid) dichtZuid else dichtNoord
    val zijnDicht get() = if (ikBenZuid) dichtNoord else dichtZuid
    val mijnOnder get() = if (ikBenZuid) onderZuid else onderNoord
    val zijnOnder get() = if (ikBenZuid) onderNoord else onderZuid

    val mijnHandPos get() = if (ikBenZuid) Pos.HAND_ZUID else Pos.HAND_NOORD
    val mijnTafelPos get() = if (ikBenZuid) Pos.TAFEL_ZUID else Pos.TAFEL_NOORD

    /** Ben ik het die nu een kaart moet leggen? */
    val benIkAanZet get() = aanZet == mijnHandPos || aanZet == mijnTafelPos

    /** Vertaalt een absolute spelerpositie naar mijn kant (voor de kaarten midden in het veld). */
    fun relatieveSpeler(absoluut: Int): Int {
        if (mijnKant != 2) return absoluut
        return when (absoluut) {
            Pos.HAND_ZUID -> Pos.HAND_NOORD
            Pos.HAND_NOORD -> Pos.HAND_ZUID
            Pos.TAFEL_ZUID -> Pos.TAFEL_NOORD
            Pos.TAFEL_NOORD -> Pos.TAFEL_ZUID
            else -> absoluut
        }
    }

    val mijnPunten get() = if (ikBenZuid) puntenZuid else puntenNoord
    val zijnPunten get() = if (ikBenZuid) puntenNoord else puntenZuid
    val mijnRoem get() = if (ikBenZuid) roemZuid else roemNoord
    val zijnRoem get() = if (ikBenZuid) roemNoord else roemZuid
    val mijnTotaal get() = if (ikBenZuid) totaalZuid else totaalNoord
    val zijnTotaal get() = if (ikBenZuid) totaalNoord else totaalZuid
    val mijnPartijen get() = if (ikBenZuid) partijenZuid else partijenNoord
    val zijnPartijen get() = if (ikBenZuid) partijenNoord else partijenZuid

    /** Wie troef maakte, vanaf mijn kant: 0 = nog niet bekend, 1 = ik, 2 = hij. */
    val troefmakerRelatief get() = if (troefmaker == 0) 0 else if (troefmaker == mijnKant) 1 else 2

    var status = ""
    var melding = ""

    /** true zodra het spel is afgerekend: de getallen zijn dan de eindstand van dit spel. */
    var spelUit = false

    /** true zodra met dít spel ook de partij (1500 punten) klaar is; alleen met [spelUit]. */
    var partijUit = false
    var partijGewonnenDoorZuid = false
    var partijGelijkspel = false

    val partijGewonnenDoorMij get() = if (ikBenZuid) partijGewonnenDoorZuid else !partijGewonnenDoorZuid

    /** De tellers over de hele sessie, voor het statistiekenscherm. */
    var statistiek = Statistiek()

    /** Welke kant er op dit moment doorrekent in plaats van vuistregels te volgen. */
    var zoekt = booleanArrayOf(false, false)

    /** Welke kant er op dit moment volgens Claude speelt. Gaat voor [zoekt]. */
    var claude = booleanArrayOf(false, false)
}
