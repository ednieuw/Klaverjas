package nl.edsoft.klaverjas

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.async
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.selects.select

/**
 * De [KjUi] die de gastheer gebruikt zodra er samen gespeeld wordt: de gastheer draait de enige
 * echte [KjSpel]; deze schil zit ertussen om na elke wijziging de hele momentopname naar de gast
 * te sturen en, als de gast aan zet is, zijn keuze terug te lezen in plaats van het lokale
 * scherm te vragen. Wat de gast ziet is altijd precies wat de gastheer net liet zien, van
 * zíjn kant bekeken ([KjSpel.snapshot] met `voorKant`).
 */
class GastheerUi(
    private val scherm: KjUi,
    private val koppeling: DuoKoppeling,
    mijnKant: Int = 1,
    /** Voor het bewaren van een onderbroken partij: elke nieuwe deal en elke zet, van welke kant ook. */
    private val opNieuweDeal: (() -> Unit)? = null,
    private val opNieuweZet: ((GastZet) -> Unit)? = null,
    /** Wacht de lokale kant nu echt op een eigen tik om verder te gaan? (Niet bij automatisch doorgaan.) */
    private val wachtLokaalOpTik: (() -> Boolean)? = null,
    /** Lost de lokale "verder"-wachttijd op, alsof de gastheer zelf getikt had. */
    private val gaVerder: (() -> Unit)? = null,
    private val log: ((String) -> Unit)? = null,
) : KjUi {
    private val gastKant = if (mijnKant == 2) 1 else 2
    private var spel: KjSpel? = null
    private var ontvangTaak: Job? = null

    // Eén vaste lezer van [koppeling] zet alles in de juiste postbus; de wachters wachten alleen
    // op hun eigen postbus. Een antwoord dat te vroeg komt blijft er gewoon liggen.
    private val troefKanaal = Channel<Int>(Channel.UNLIMITED)
    private val kaartKanaal = Channel<Pair<Teken, Int>>(Channel.UNLIMITED)
    private val verderKanaal = Channel<Unit>(Channel.UNLIMITED)

    /** Moet vóór `spel.loop()` aangeroepen zijn; start ook de vaste ontvangtaak. */
    fun koppel(nieuwSpel: KjSpel, scope: CoroutineScope) {
        spel = nieuwSpel
        if (ontvangTaak != null) return
        ontvangTaak = scope.launch {
            while (isActive) {
                val bericht = koppeling.volgende()
                if (koppeling.gestopt) return@launch
                verwerkGastBericht(bericht)
            }
        }
    }

    fun stop() {
        ontvangTaak?.cancel()
        ontvangTaak = null
        // Wie nog op de gast wacht (troef, kaart of verder) laten we los met een ongeldige keuze.
        troefKanaal.trySend(0)
        kaartKanaal.trySend(NUL to 0)
        verderKanaal.trySend(Unit)
    }

    override suspend fun toon(view: SpelView) {
        scherm.toon(view)
        stuurStand(view)
    }

    /**
     * De "verder"-tik kan van allebei de kanten komen; wie het eerst tikt wint. Bij snel spelen
     * of automatisch doorgaan wacht de gastheer zelf niet, dus dan ook niet op de gast.
     */
    override suspend fun verder(view: SpelView, tekst: String) {
        val magGastTikken = wachtLokaalOpTik?.invoke() ?: false
        leeg(verderKanaal)
        val origineel = view.kopie().also { it.wachtOpVerder = magGastTikken }
        stuurStand(origineel)

        if (!magGastTikken) {
            scherm.verder(view, tekst)
            return
        }
        coroutineScope {
            val lokaal = async { scherm.verder(view, tekst) }
            val gast = async { verderKanaal.receive() }
            select<Unit> {
                lokaal.onAwait { }
                gast.onAwait { }
            }
            gaVerder?.invoke()
            lokaal.cancel()
            gast.cancel()
        }
    }

    override suspend fun kiesTroef(view: SpelView): Int {
        opNieuweDeal?.invoke()
        leeg(troefKanaal)
        stuurStand(view)
        val kleur: Int
        if (view.benIkAanZet) {
            kleur = scherm.kiesTroef(view)
        } else {
            // Niet mijn kant die troef kiest: mijn eigen scherm moet dat ook zeggen.
            val wacht = view.kopie().also { it.status = Taal.zijnBeurt }
            scherm.toon(wacht)
            kleur = troefKanaal.receive()
        }
        opNieuweZet?.invoke(GastZet(troef = kleur))
        return kleur
    }

    override suspend fun kiesKaart(view: SpelView): Pair<Teken, Int> {
        leeg(kaartKanaal)
        stuurStand(view)
        val antwoord: Pair<Teken, Int>
        if (view.benIkAanZet) {
            antwoord = scherm.kiesKaart(view)
        } else {
            val wacht = view.kopie().also { it.status = Taal.zijnBeurt }
            scherm.toon(wacht)
            antwoord = kaartKanaal.receive()
        }
        opNieuweZet?.invoke(GastZet(kaart = antwoord.first, kleur = antwoord.second))
        return antwoord
    }

    // ------------------------------------------------------------------ hulp

    private fun <T> leeg(k: Channel<T>) { while (k.tryReceive().isSuccess) { /* oude, te late tik */ } }

    /**
     * `origineel` is de momentopname van de gastheer; de stand voor de gast wordt apart berekend
     * (anders zag de gast de kaarten van de gastheer). `snapshot` zet troefVraag/wachtOpSpeler/
     * status zelf niet: die komen van `origineel`, en de status wordt voor de gast opnieuw bepaald.
     */
    private suspend fun stuurStand(origineel: SpelView) {
        val spel = spel
        if (spel == null) {
            log?.invoke("stand overgeslagen: nog niet gekoppeld aan een partij")
            return
        }
        val g = spel.snapshot(voorKant = gastKant)
        g.troefVraag = origineel.troefVraag
        g.wachtOpSpeler = origineel.wachtOpSpeler
        g.wachtOpVerder = origineel.wachtOpVerder
        g.status = when {
            g.troefVraag -> if (g.benIkAanZet) Taal.welkeTroef else Taal.zijnBeurt
            g.wachtOpSpeler -> if (g.benIkAanZet) Taal.jouwBeurt else Taal.zijnBeurt
            else -> origineel.status
        }
        g.spelUit = origineel.spelUit
        if (origineel.spelUit) {
            g.puntenZuid = origineel.puntenZuid; g.puntenNoord = origineel.puntenNoord
            g.roemZuid = origineel.roemZuid; g.roemNoord = origineel.roemNoord
            g.partijUit = origineel.partijUit
            g.partijGewonnenDoorZuid = origineel.partijGewonnenDoorZuid
            g.partijGelijkspel = origineel.partijGelijkspel
        }
        // De melding komt uit de engine en is absoluut (Zuid/Noord); voor de gast is het omgekeerd.
        if (g.mijnKant == 2) g.melding = zuidNoordOmgewisseld(g.melding)
        val tekst = DuoStand.codeer(g.toJson())
        koppeling.stuur(DuoBericht.Stand(tekst))
    }

    private fun verwerkGastBericht(bericht: DuoBericht) {
        if (bericht !is DuoBericht.Zet) return
        val z = DuoStand.decodeer(bericht.json)?.let { GastZet.uitJson(it) } ?: return
        when {
            z.troef != null -> troefKanaal.trySend(z.troef)
            z.kaart != null && z.kleur != null -> kaartKanaal.trySend(z.kaart to z.kleur)
            z.verder == true -> verderKanaal.trySend(Unit)
        }
    }

    companion object {
        /** Wisselt "Zuid" en "Noord" (of South/North) om via een tussenwaarde. */
        fun zuidNoordOmgewisseld(tekst: String): String {
            if (tekst.isEmpty()) return tekst
            val (zuid, noord) = if (Taal.engels) "South" to "North" else "Zuid" to "Noord"
            val tussen = "\u0000"
            return tekst.replace(zuid, tussen).replace(noord, zuid).replace(tussen, noord)
        }
    }
}

/** Een ondiepe kopie, voor waar de gastheer één veld op een eigen exemplaar wil aanpassen. */
internal fun SpelView.kopie(): SpelView = spelViewUitJson(toJson())!!
