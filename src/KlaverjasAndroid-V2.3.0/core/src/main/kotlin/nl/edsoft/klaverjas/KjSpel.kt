package nl.edsoft.klaverjas

import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.isActive
import kotlinx.coroutines.yield

/**
 * Wat de speellogica van de buitenwereld nodig heeft. In de C#-versie blokkeerden
 * deze vraag-methodes de speelthread tot de speler iets deed; hier zijn het
 * `suspend`-functies: de speelloop wacht netjes zonder een thread bezet te houden.
 */
interface KjUi {
    /** Nieuwe toestand tonen. */
    suspend fun toon(view: SpelView)

    /** Wacht tot de speler een kaart kiest. */
    suspend fun kiesKaart(view: SpelView): Pair<Teken, Int>

    /** Wacht tot de speler een troefkleur kiest (0..3). */
    suspend fun kiesTroef(view: SpelView): Int

    /** Wacht tot de speler verder wil. */
    suspend fun verder(view: SpelView, tekst: String)

    /**
     * Toont de uitslag van een slag zonder op een eigen tik te wachten - voor de kant
     * die niet zelf beslist wanneer de partij verdergaat (bij samenspel).
     */
    suspend fun toonUitslag(view: SpelView, tekst: String) = verder(view, tekst)

    /**
     * Wordt er snel gespeeld, zonder kaarten? Dan toont het scherm alleen tellers en bouwt de
     * speelloop geen kaartbeelden meer op: geen [toon] per kaart, en aan het eind van een slag en
     * van het spel een lichte momentopname zonder kaarten (zie [KjSpel.snapshot]).
     * Moet snel en zonder wachten te lezen zijn: de speelloop vraagt het bij elke kaart.
     */
    val snelSpelen: Boolean get() = false
}

/** De schakelaars uit het menu Opties. */
data class Instellingen(
    /** De computer speelt beide kanten. */
    val demo: Boolean = false,
    /** De kaarten van Noord open op tafel. */
    val openKaart: Boolean = false,
    /** Speelt Zuid volgens de zoekende speler (Ronlog) in plaats van de vuistregels? */
    val zoektZuid: Boolean = false,
    val zoektNoord: Boolean = false,
    /** Speelt deze kant volgens Claude? Gaat voor Ronlog. */
    val claudeZuid: Boolean = false,
    val claudeNoord: Boolean = false,
)

/**
 * De speelloop uit main() van KJ.C: delen, troef bepalen, acht slagen spelen,
 * afrekenen, opnieuw. Port van KjSpel.swift; de loop draait in één coroutine en
 * muteert de engine alleen daar.
 */
class KjSpel(
    private val ui: KjUi,
    zaad: Long? = null,
    private val leesInstellingen: () -> Instellingen = { Instellingen() },
    /** Welke kant "ik" ben op dit toestel: 1 = Zuid, 2 = Noord. */
    private val mijnKant: Int = 1,
    /** De tellingen van de vorige keer, voordat er ook maar één kaart valt. */
    beginStatistiek: Statistiek? = null,
) {
    val e = KjEngine(zaad)

    init { if (beginStatistiek != null) e.s.zetStatistiek(beginStatistiek) }
    private val s: KjState get() = e.s

    private var vorigeSlag: List<SlagView> = emptyList()
    private var melding = ""

    private fun pasInstellingenToe() {
        val i = leesInstellingen()
        s.comp = i.demo
        s.dicht = !i.openKaart
        s.zoekt[0] = i.zoektZuid
        s.zoekt[1] = i.zoektNoord
        s.claude[0] = i.claudeZuid
        s.claude[1] = i.claudeNoord
    }

    /** Speelt spel na spel tot de coroutine wordt afgebroken. */
    suspend fun loop() {
        s.speler = s.random(2) + 1
        while (currentCoroutineContext().isActive) speelEenSpel()
    }

    private suspend fun speelEenSpel() {
        pasInstellingenToe()
        s.troef = 999
        s.slagNr = 0
        s.slagKrtNo = 0
        vorigeSlag = emptyList()
        melding = ""

        e.delen()

        s.speler = 1 - (s.speler - 1) + 1      // wisselt tussen 1 en 2
        s.vrager = s.speler
        s.startVrager = s.speler

        for (n in 0 until 4) { s.tNoord[n] = 1; s.tZuid[n] = 1 }

        e.kaartenVrij()
        e.zetTafelPosities()
        e.vulhanden()

        s.slagNr = 0

        // Met mensIsAanZet krijgt ook Noord de vraag, zodra die kant als mens speelt.
        if (s.comp || !s.mensIsAanZet(s.startVrager)) {
            e.troefBepalen()
        } else {
            val v = snapshot()
            v.troefVraag = true
            v.status = Taal.welkeTroef
            s.troef = ui.kiesTroef(v)
            e.zetActWaarden()
        }

        // Statistiek over de verdeling van deze deal.
        for (n in 0 until 32) {
            val k = s.kaart[n]
            val kant = when (k.dichtIkHy) {
                Pos.HAND_ZUID, Pos.TAFEL_ZUID, Pos.DICHT_ZUID -> 0
                Pos.HAND_NOORD, Pos.TAFEL_NOORD, Pos.DICHT_NOORD -> 1
                else -> continue
            }
            s.kaartpnt[kant] += k.actWaarde.toLong()
            if (k.kleur == s.troef) {
                s.troefkrt[kant] += 1
                s.troefpnt[kant] += k.actWaarde.toLong()
            }
        }

        s.slagNr = 1
        while (s.slagNr < 9) {
            currentCoroutineContext().ensureActive()

            val beurten: List<() -> Unit> =
                listOf({ e.speler1() }, { e.tegenspeler1() }, { e.speler2() }, { e.tegenspeler2() })
            for ((nr, beurt) in beurten.withIndex()) {
                pasInstellingenToe()
                s.tactiek = 0
                beurt()
                if (!speelZet()) { errorLegKaart(); s.slagKrtNo = 0; return }
                if (nr == 0) {
                    s.startVrager = s.vrager
                    if (s.tactiek == 41) s.tactiek41 = true
                }
                s.tac[begrens(s.tactiek)] += 1
            }

            val uitslag = e.evalueer()

            var winnaar = e.wieSlag()
            if (winnaar > 2) winnaar -= 2
            if (s.slagNr < 8) melding = slagMelding(s.slagNr, winnaar == 1, uitslag)

            if (s.slagNr == 8) {
                // evalueerSpel() zet de tellers van dit spel op nul; hij geeft de
                // getallen daarom terug, inclusief de bonus voor pit.
                val eind = e.evalueerSpel()
                melding = slagMelding(s.slagNr, winnaar == 1, uitslag, eind.pitRoem, eind.tegenpit) +
                    Taal.scheiding + eind.tekst

                val v = snapshot(licht = ui.snelSpelen)      // met de bijgewerkte partijtotalen
                v.puntenZuid = eind.puntenZuid
                v.puntenNoord = eind.puntenNoord
                v.roemZuid = eind.roemZuid
                v.roemNoord = eind.roemNoord
                v.spelUit = true
                v.partijUit = eind.partijUit
                v.partijGewonnenDoorZuid = eind.partijGewonnenDoorZuid
                v.partijGelijkspel = eind.partijGelijkspel
                ui.verder(v, melding)
            } else {
                ui.verder(snapshot(licht = ui.snelSpelen), melding)
                vorigeSlag = huidigeSlag()
                e.updateTafel()
                s.slagKrtNo = 0
            }

            s.slagNr += 1
        }

        s.slagKrtNo = 0
    }

    private fun begrens(tactiek: Int): Int = if (tactiek in 0 until 80) tactiek else 0

    /** Regel bovenin: wie won de slag en wat leverde die op. */
    private fun slagMelding(
        slagNr: Int, zuidWon: Boolean, u: SlagUitslag, pitRoem: Int = 0, tegenpit: Boolean = false,
    ): String {
        var tekst = Taal.slagVoor(slagNr, zuidWon)
        if (u.roem > 0) tekst += Taal.metRoem(u.roem)
        if (u.laatsteSlag > 0) tekst += Taal.laatsteSlag(u.laatsteSlag, u.roem > 0)
        if (pitRoem > 0) tekst += if (tegenpit) Taal.voorTegenpit(pitRoem) else Taal.voorPit(pitRoem)
        return tekst
    }

    /**
     * Legt de zet die de AI koos, of vraagt de mens om er een. Geeft false als er een
     * onspeelbare kaart uit de tactiek kwam (verzaken door de computer).
     */
    private suspend fun speelZet(): Boolean {
        if (e.wachtOpMens) {
            e.zetMensKlaar()
            mensKiest()
        }

        if (!e.legKaart(s.lkaart, s.lkleur, s.vrager)) return false
        if (e.checkValid() != null) return false

        // Bij snel spelen valt er niets te tonen en kost het opbouwen van alle kaartbeelden meer dan
        // het spelen zelf.
        if (!ui.snelSpelen) ui.toon(snapshot())
        return true
    }

    /** humaan(): vraagt net zolang een kaart tot er een geldige komt. */
    private suspend fun mensKiest() {
        // Welke kant hier aan zet is, in Pos-codes; eenmaal bepaald bij binnenkomst.
        val kant = if (s.vrager > 2) s.vrager - 2 else s.vrager
        val eigenHand = if (kant == 2) Pos.HAND_NOORD else Pos.HAND_ZUID
        val eigenTafel = if (kant == 2) Pos.TAFEL_NOORD else Pos.TAFEL_ZUID

        while (true) {
            // Een stopgezette coroutine hoort hier uit te komen.
            currentCoroutineContext().ensureActive()
            yield()

            val v = snapshot()
            v.wachtOpSpeler = true
            v.status = Taal.jouwBeurt
            v.melding = melding

            val (naam, kleur) = ui.kiesKaart(v)
            s.lkaart = naam
            s.lkleur = kleur

            var found = false
            var i = 0
            if (kleur in 0..3) {
                for (n in (kleur * 8) until (kleur * 8 + 8)) {
                    if (s.kaart[n].naam == s.lkaart) i = s.kaart[n].dichtIkHy
                    if (s.slagKrtNo == 0 && (s.vrager == eigenHand || s.vrager == eigenTafel)) {
                        // Bij uitkomen mag je zelf kiezen: uit de hand of van tafel.
                        if (i == eigenHand || i == eigenTafel) { found = true; s.vrager = i }
                    } else if (s.vrager == i) {
                        found = true
                    }
                }
            }

            if (found) {
                val fout = e.checkValid()
                if (fout == null) {
                    // De klacht over de vorige poging is afgehandeld.
                    melding = ""
                    return
                }
                melding = fout
                continue
            }

            melding = when (i) {
                eigenTafel -> Taal.kaartLigtOpTafel
                eigenHand -> Taal.kaartZitInHand
                else -> Taal.kaartNietSpeelbaar
            }
        }
    }

    /** error_legkaart(): de computer koos een onspeelbare kaart; alle punten naar de tegenpartij. */
    private suspend fun errorLegKaart() {
        var vrager = s.vrager
        if (vrager > 2) vrager -= 2
        if (vrager < 1 || vrager > 2) vrager = 1
        val m = if (vrager == 1) 2 else 1

        s.puntenSpel[m - 1] += 152 + s.roem[vrager - 1] + s.roem[m - 1]
        s.puntenSpel[vrager - 1] = 0
        s.roem[vrager - 1] = 0

        s.puntenTotaalSpel[0] += (s.puntenSpel[0] + s.roem[0]).toLong()
        s.puntenTotaalSpel[1] += (s.puntenSpel[1] + s.roem[1]).toLong()
        s.puntenSpel[0] = 0; s.puntenSpel[1] = 0
        s.roem[0] = 0; s.roem[1] = 0
        for (n in 0 until 4) { s.verzaakt[0][n] = 0; s.verzaakt[1][n] = 0 }

        ui.verder(snapshot(licht = ui.snelSpelen), Taal.computerVerzaakte(s.tactiek, s.lkleur, s.lkaart))
    }

    // ------------------------------------------------------------ snapshot

    private fun huidigeSlag(): List<SlagView> =
        (0 until minOf(s.slagKrtNo, 4)).map {
            val sk = s[s.slagNr, it]
            SlagView(sk.kleur, sk.naam, sk.speler, sk.tactiek)
        }

    /**
     * Bouwt de momentopname waarop de UI tekent. `voorKant` is er voor samenspel: de
     * gastheer draait de enige echte motor en moet kunnen uitrekenen wat de andere
     * kant op zíjn scherm te zien mag krijgen. Standaard [mijnKant].
     *
     * [licht]: alleen de getallen en de tellingen, zonder de 32 kaartbeelden en hun sortering. Voor snel
     * spelen, waar het scherm geen kaarten tekent.
     */
    fun snapshot(voorKant: Int? = null, licht: Boolean = false): SpelView {
        val kant = voorKant ?: mijnKant
        pasInstellingenToe()
        val v = SpelView()
        v.mijnKant = kant
        v.troef = s.troef
        v.slagNr = s.slagNr
        v.aanZet = s.vrager
        v.puntenZuid = s.puntenSpel[0]
        v.puntenNoord = s.puntenSpel[1]
        v.roemZuid = s.roem[0]
        v.roemNoord = s.roem[1]
        v.totaalZuid = s.puntenTotaalSpel[0]
        v.totaalNoord = s.puntenTotaalSpel[1]
        v.zoekt = s.zoekt.copyOf()
        v.claude = s.claude.copyOf()
        v.troefmaker = if (s.speler == 1 || s.speler == 2) s.speler else 0
        v.partijenZuid = s.gewonnen[0]
        v.partijenNoord = s.gewonnen[1]
        // Bij licht ook geen kaarten van de lopende en de vorige slag.
        v.slag = if (licht) emptyList() else huidigeSlag()
        v.vorigeSlag = if (licht) emptyList() else vorigeSlag
        v.melding = melding
        v.statistiek = s.statistiek
        if (licht) return v

        for (i in 0 until 4) {
            v.onderZuid[i] = s.tZuid[i] != 0
            v.onderNoord[i] = s.tNoord[i] != 0
        }

        var volg = 0
        for (n in 0 until 32) {
            val k = s.kaart[n]
            val kv = KaartView()
            kv.index = n
            kv.naam = k.naam
            kv.kleur = k.kleur
            kv.open = true
            kv.plek = e.tafelPos(n)

            // Mijn eigen hand is altijd open; de andere hand alleen met "open kaart".
            when (k.dichtIkHy) {
                Pos.HAND_ZUID -> { kv.plek = volg; volg += 1; kv.open = (kant == 1) || !s.dicht; v.handZuid.add(kv) }
                Pos.HAND_NOORD -> { kv.open = (kant == 2) || !s.dicht; v.handNoord.add(kv) }
                Pos.TAFEL_ZUID, Pos.NIEUW_ZUID -> v.tafelZuid.add(kv)
                Pos.TAFEL_NOORD, Pos.NIEUW_NOORD -> v.tafelNoord.add(kv)
                Pos.DICHT_ZUID -> { kv.open = !s.dicht; v.dichtZuid.add(kv) }
                Pos.DICHT_NOORD -> { kv.open = !s.dicht; v.dichtNoord.add(kv) }
                else -> {}
            }
        }

        // Hand van Zuid op kleur en rang sorteren, dat speelt prettiger.
        v.handZuid.sortWith(::vergelijkKaart)
        v.tafelZuid.sortBy { it.plek }
        v.tafelNoord.sortBy { it.plek }

        for (i in v.handNoord.indices) v.handNoord[i].plek = i
        for (i in v.dichtZuid.indices) v.dichtZuid[i].plek = i
        for (i in v.dichtNoord.indices) v.dichtNoord[i].plek = i
        for (i in v.handZuid.indices) v.handZuid[i].plek = i

        return v
    }

    private fun vergelijkKaart(a: KaartView, b: KaartView): Int {
        if (a.kleur != b.kleur) {
            // Troef vooraan.
            val at = a.kleur == s.troef
            val bt = b.kleur == s.troef
            if (at != bt) return if (at) -1 else 1
            return a.kleur.compareTo(b.kleur)
        }
        val rang = if (a.kleur == s.troef) KjState.rangTroef else KjState.rangNorm
        return CStr.pos(rang, a.naam).compareTo(CStr.pos(rang, b.naam))
    }
}
