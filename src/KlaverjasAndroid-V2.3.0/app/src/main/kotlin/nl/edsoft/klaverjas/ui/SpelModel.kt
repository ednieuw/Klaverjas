package nl.edsoft.klaverjas.ui

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.core.os.ConfigurationCompat
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.yield
import nl.edsoft.klaverjas.DuoGast
import nl.edsoft.klaverjas.DuoKoppeling
import nl.edsoft.klaverjas.DuoOpzet
import nl.edsoft.klaverjas.DuoRadio
import nl.edsoft.klaverjas.DuoStand
import nl.edsoft.klaverjas.DuoStatus
import nl.edsoft.klaverjas.DuoBericht
import nl.edsoft.klaverjas.GastZet
import nl.edsoft.klaverjas.GastheerUi
import nl.edsoft.klaverjas.Statistiek
import nl.edsoft.klaverjas.ble.BleCentraal
import nl.edsoft.klaverjas.ble.BleLog
import nl.edsoft.klaverjas.ble.BlePerifeer
import nl.edsoft.klaverjas.kantenOmgewisseld
import nl.edsoft.klaverjas.toJson
import nl.edsoft.klaverjas.Instellingen
import nl.edsoft.klaverjas.KaartView
import nl.edsoft.klaverjas.KjSpel
import nl.edsoft.klaverjas.KjUi
import nl.edsoft.klaverjas.SpelView
import nl.edsoft.klaverjas.Taal
import nl.edsoft.klaverjas.Teken

/** Waar de speelloop op wacht. */
enum class Modus { GEEN, KIES_KAART, KIES_TROEF, VERDER }

/** De vraag "met wie speel je?", als de ander zich met een algemene naam meldt. */
class NaamVraag(val basis: String, val voorstel: String, val bekend: List<String>)

/** Waar het verbinden voor samen spelen op staat, voor het blad "Samen spelen". */
sealed class VerbindStap {
    object Kiezen : VerbindStap()
    data class Bezig(val tekst: String) : VerbindStap()
    data class Mislukt(val tekst: String) : VerbindStap()
}

/**
 * Houdt de speelloop (een [KjSpel] in een coroutine) en de toestand voor het scherm. De
 * loop draait buiten de hoofdthread; het scherm leest alleen [view], [modus] en [tekst]
 * en geeft zijn tikken door via [klik], [kiesTroef] en [gaVerder].
 */
class SpelModel(app: Application) : AndroidViewModel(app) {
    private val bewaarplaats = Bewaarplaats(app)

    /** Versienaam uit het manifest, voor onderaan het optieblad. */
    val versie: String = try {
        app.packageManager.getPackageInfo(app.packageName, 0).versionName ?: ""
    } catch (_: Exception) { "" }

    var view by mutableStateOf(SpelView())
        private set
    var modus by mutableStateOf(Modus.GEEN)
        private set
    var tekst by mutableStateOf("")
        private set

    var demo by mutableStateOf(false)
        private set
    var openKaart by mutableStateOf(false)
        private set
    /** Speelwijze van Noord: 0 = Ednieuw (vuistregels), 1 = Ronlog (rekent een slag door), 2 = Claude (speelt het spel uit). */
    var stijlNoord by mutableStateOf(0)
        private set
    /** Speelwijze van Zuid; alleen van belang in demo. Standaard Ronlog, zodat een demo twee speelwijzen tegen elkaar zet. */
    var stijlZuid by mutableStateOf(1)
        private set
    var automatisch by mutableStateOf(false)
        private set
    var engels by mutableStateOf(false)
        private set

    /** Snel spelen zonder kaarten: de computer speelt beide kanten, er wordt niet gewacht. */
    var snel by mutableStateOf(false)
        private set
    /** Hoeveel spellen er in totaal zijn gespeeld, bijgewerkt tijdens snel spelen. */
    var snelGespeeld by mutableStateOf(0L)
        private set
    private var laatstGetekend = 0L

    @Volatile private var instellingen = Instellingen()
    private var job: Job? = null

    private var kaartWacht: CompletableDeferred<Pair<Teken, Int>>? = null
    private var troefWacht: CompletableDeferred<Int>? = null
    private var verderWacht: CompletableDeferred<Unit>? = null

    private val ui = object : KjUi {
        override val snelSpelen: Boolean get() = snel

        override suspend fun toon(view: SpelView) {
            // Snel spelen: geen kaart tekenen en niet wachten.
            if (snel) return
            this@SpelModel.view = view
            // Een wachttekst ("Zijn beurt", bij samenspel) hoort ook in de balk te staan.
            if (view.status.isNotEmpty()) tekst = view.status
            // Even de tijd om te zien welke kaart er viel.
            delay(if (instellingen.demo) 150 else 450)
        }

        override suspend fun kiesKaart(view: SpelView): Pair<Teken, Int> {
            val wacht = CompletableDeferred<Pair<Teken, Int>>()
            kaartWacht = wacht
            this@SpelModel.view = view
            tekst = view.melding.ifEmpty { view.status }
            modus = Modus.KIES_KAART
            return wacht.await()
        }

        override suspend fun kiesTroef(view: SpelView): Int {
            val wacht = CompletableDeferred<Int>()
            troefWacht = wacht
            this@SpelModel.view = view
            tekst = view.status
            modus = Modus.KIES_TROEF
            return wacht.await()
        }

        override suspend fun verder(view: SpelView, tekst: String) {
            if (snel) { snelStap(view); return }
            this@SpelModel.view = view
            this@SpelModel.tekst = tekst
            // De tellingen bewaren we na elke slag; het is een paar honderd bytes.
            bewaar(view, meteen = true)
            if (instellingen.demo || automatisch) {
                // Vanzelf doorgaan: in demo kijkt niemand mee met een vinger.
                delay(if (view.spelUit) 2500 else 1200)
                return
            }
            val wacht = CompletableDeferred<Unit>()
            verderWacht = wacht
            modus = Modus.VERDER
            wacht.await()
        }
    }

    init {
        val v = bewaarplaats.leesVoorkeuren()
        if (v != null) {
            stijlZuid = v.stijlZuid; stijlNoord = v.stijlNoord; engels = v.engels
        } else {
            // Nog nooit gekozen: de taal volgt het apparaat.
            val talen = ConfigurationCompat.getLocales(app.resources.configuration)
            engels = Taal.engelsVoor((0 until talen.size()).map { talen[it]?.language ?: "" })
        }
        Taal.engels = engels
        zetInstellingen()
    }

    private fun start(metBewaard: Boolean = true) {
        job?.cancel()
        stopDuo()
        modus = Modus.GEEN
        tekst = ""
        val begin = if (metBewaard) bewaarplaats.lees() else null
        view = SpelView().also { if (begin != null) it.statistiek = begin }
        val spel = KjSpel(ui, leesInstellingen = { instellingen }, beginStatistiek = begin)
        // Op de hoofdthread: schrijven naar de Compose-toestand vanaf Dispatchers.Default
        // kwam op de emulator niet in het scherm aan. De engine rekent per zet in
        // milliseconden, dus dat is voor nu geen bezwaar.
        job = viewModelScope.launch { spel.loop() }
    }

    fun nieuwSpel() = start()

    /**
     * Eén slag bij snel spelen: het scherm en de bewaarplaats worden hooguit een paar keer per
     * seconde bijgewerkt, anders kost het tekenen meer dan het spelen zelf. Aan het eind van
     * elk spel geven we de hoofdthread even de ruimte.
     */
    private suspend fun snelStap(v: SpelView) {
        if (!v.spelUit) return
        val nu = System.nanoTime()
        if (nu - laatstGetekend > 250_000_000L) {
            laatstGetekend = nu
            view = v
            snelGespeeld = v.statistiek.spellen[0] + v.statistiek.spellen[1]
            bewaarplaats.schrijf(v.statistiek)
        }
        // Een miljoen spellen is genoeg: daarboven lopen in de Windows-versie de tellers over.
        if (v.statistiek.spellen[0] + v.statistiek.spellen[1] >= MAX_SPELLEN) {
            bewaarplaats.schrijf(v.statistiek)
            stopSnel()
            return
        }
        yield()
    }

    /** Snel spelen aan of uit. Aan: de computer speelt beide kanten, en er begint een nieuw spel. */
    fun zetSnel(aan: Boolean) {
        if (aan == snel || inSamenspel) return
        if (aan) {
            demo = true
            zetInstellingen()
            snel = true
            snelGespeeld = view.statistiek.spellen[0] + view.statistiek.spellen[1]
            start()
        } else {
            stopSnel()
        }
    }

    /** Uit snel spelen komen: ook de demo gaat uit, zodat je weer zelf speelt. */
    private fun stopSnel() {
        snel = false
        demo = false
        zetInstellingen()
        start()
    }

    private fun zetInstellingen() {
        instellingen = Instellingen(
            demo = demo, openKaart = openKaart,
            zoektZuid = stijlZuid == 1, zoektNoord = stijlNoord == 1,
            claudeZuid = stijlZuid == 2, claudeNoord = stijlNoord == 2,
        )
    }

    private fun bewaarVoorkeuren() =
        bewaarplaats.schrijfVoorkeuren(Bewaarplaats.Voorkeuren(stijlZuid, stijlNoord, engels))

    /**
     * Demo wisselt de rol van Zuid van mens naar computer. Wacht het spel op dat moment al
     * op een kaart of troefkeuze van de mens, dan kan die vraag niet meer terug; daarom
     * begint er een nieuw spel (de tellingen blijven).
     */
    fun zetDemo(aan: Boolean) {
        demo = aan; zetInstellingen()
        // Bij samenspel loopt de partij door: de computer speelt vanaf de eerstvolgende beurt, of niet meer.
        if (!inSamenspel) start()
    }
    fun zetOpenKaart(aan: Boolean) { openKaart = aan; zetInstellingen() }
    fun zetAutomatisch(aan: Boolean) { automatisch = aan; if (aan) gaVerder() }
    fun zetStijlNoord(stijl: Int) { stijlNoord = stijl; zetInstellingen(); bewaarVoorkeuren() }
    fun zetStijlZuid(stijl: Int) { stijlZuid = stijl; zetInstellingen(); bewaarVoorkeuren() }
    fun zetEngels(aan: Boolean) { engels = aan; Taal.engels = aan; bewaarVoorkeuren() }

    /** Alles op nul: de bewaarde tellingen weg en opnieuw beginnen. */
    fun wisStatistiek() {
        bewaarplaats.wis()
        start(metBewaard = false)
    }


    // ------------------------------------------------------------------------ samen spelen

    /** Zit ik nu in een samenspel-partij, als gastheer of als gast? Dan vervalt o.a. "Nieuw spel". */
    var inSamenspel by mutableStateOf(false)
        private set

    /** Waar het verbinden op staat; alleen van belang zolang het blad "Samen spelen" open is. */
    var verbindStap by mutableStateOf<VerbindStap>(VerbindStap.Kiezen)
        private set

    /** Ben ik de gast? Dan is er geen eigen motor: alles komt als momentopname van de gastheer. */
    var benIkGast by mutableStateOf(false)
        private set

    /** Gezet zolang er op een antwoord gewacht wordt; het blad "Samen spelen" toont dan de vraag. */
    var naamVraag by mutableStateOf<NaamVraag?>(null)
        private set
    private var naamAntwoord: CompletableDeferred<String>? = null

    fun beantwoordNaam(naam: String) {
        val a = naam.replace(Regex("[\\r\\n]"), " ").trim().take(24)
        naamAntwoord?.complete(a)
    }

    /**
     * Sommige toestellen melden zich met een algemene naam: iOS geeft apps sinds versie 16 alleen "iPhone" of
     * "iPad". Twee van die toestellen zouden één telling delen, dus vragen we dan hoe de ander heet.
     */
    private suspend fun kiesPartnerNaam(basis: String): String {
        if (basis !in ALGEMENE_NAMEN) return basis
        val wacht = CompletableDeferred<String>()
        naamAntwoord = wacht
        naamVraag = NaamVraag(basis, bewaarplaats.leesAlias(basis) ?: basis, bewaarplaats.leesAlleDuo().keys.sorted())
        try {
            val gekozen = wacht.await().ifEmpty { basis }
            bewaarplaats.schrijfAlias(basis, gekozen)
            return gekozen
        } finally { naamVraag = null; naamAntwoord = null }
    }

    private var duoPartnerNaam: String? = null
    private var duoRadio: DuoRadio? = null
    private var duoKoppeling: DuoKoppeling? = null
    private var gastheerUi: GastheerUi? = null
    private var gast: DuoGast? = null
    private var bewaker: Job? = null
    private var verbindJob: Job? = null
    private var verbindRadio: DuoRadio? = null
    private var laatstBewaard = 0L

    /** De naam van de huidige partner; null buiten samenspel. */
    val actievePartner: String? get() = if (inSamenspel) duoPartnerNaam else null

    fun alleBewaardeDuoTellingen(): Map<String, Statistiek> = bewaarplaats.leesAlleDuo()

    /** Eén partner uit de lijst halen, zonder de rest aan te raken. Niet de partner met wie nu gespeeld wordt. */
    fun wisDuoPartner(naam: String) {
        if (naam == actievePartner) return
        bewaarplaats.wisDuo(naam)
    }

    /** De tellingen zoals ze bij mij horen: de gast ziet zichzelf als Zuid. */
    val eigenStatistiek: Statistiek get() = if (benIkGast) view.statistiek.kantenOmgewisseld else view.statistiek

    /** De naam voor samen spelen; leeg = die van het toestel. Voor het veld in het blad "Samen spelen". */
    var mijnNaam by mutableStateOf(bewaarplaats.leesSpelerNaam() ?: "")
        private set

    fun zetMijnNaam(naam: String) {
        // Eén regel, niet te lang: de naam gaat in een regel van het protocol.
        mijnNaam = naam.replace(Regex("[\\r\\n]"), " ").take(24)
        bewaarplaats.schrijfSpelerNaam(mijnNaam)
    }

    /** Naam van dit toestel, zoals de andere kant die in zijn lijst "samen gespeeld" ziet. */
    private fun toestelNaam(): String {
        mijnNaam.trim().takeIf { it.isNotEmpty() }?.let { return it }
        val app = getApplication<Application>()
        val naam = try { android.provider.Settings.Global.getString(app.contentResolver, "device_name") } catch (_: Exception) { null }
        return (naam ?: android.os.Build.MODEL ?: "Android").replace(Regex("[\\r\\n]"), " ").trim().ifEmpty { "Android" }
    }

    /** Begint met verbinden als gastheer (openstellen) of gast (zoeken). De rechten zijn dan al verleend. */
    fun verbind(alsGastheer: Boolean) {
        stopVerbinden()
        val radio: DuoRadio = if (alsGastheer) BlePerifeer(getApplication()) else BleCentraal(getApplication())
        verbindRadio = radio
        verbindStap = VerbindStap.Bezig(if (alsGastheer) Taal.duoOpenstellen else Taal.duoZoeken)
        verbindJob = viewModelScope.launch {
            radio.start()
            val eind = radio.statusStroom()
                .onEach { if (it is DuoStatus.Bezig) verbindStap = VerbindStap.Bezig(it.tekst) }
                .first { it !is DuoStatus.Bezig }
            if (eind is DuoStatus.Mislukt) {
                verbindStap = VerbindStap.Mislukt(eind.reden)
                radio.stop(); verbindRadio = null
                return@launch
            }
            verbindStap = VerbindStap.Bezig(Taal.duoBegroeten)
            val naam = toestelNaam()
            val tellingen = bewaarplaats.leesAlleDuo()
            val versie = versie.ifEmpty { "2.0" }.replace(' ', '-')
            // Ruim, want de speler kan gevraagd worden hoe de ander heet.
            val res = withTimeoutOrNull(120_000) {
                if (alsGastheer) DuoOpzet.alsGastheer(radio, versie, naam, tellingen, ::kiesPartnerNaam)
                else DuoOpzet.alsGast(radio, versie, naam, tellingen, ::kiesPartnerNaam)
            }
            BleLog.zeg("begroeting klaar: $res")
            when (res) {
                is DuoOpzet.Resultaat.Klaar -> {
                    // Vanaf hier is de radio van de partij, niet meer van het verbindscherm.
                    verbindRadio = null
                    verbindStap = VerbindStap.Kiezen
                    if (alsGastheer) startDuoAlsGastheer(radio, res.naam, res.statistiek)
                    else startDuoAlsGast(radio, res.naam, res.statistiek)
                }
                is DuoOpzet.Resultaat.Versieverschil -> { verbindStap = VerbindStap.Mislukt(Taal.duoAndereVersie(res.andereVersie)); radio.stop(); verbindRadio = null }
                is DuoOpzet.Resultaat.Onverwacht, null -> { verbindStap = VerbindStap.Mislukt(Taal.duoOnverwacht); radio.stop(); verbindRadio = null }
            }
        }
    }

    /** Annuleren of opnieuw proberen: stopt een verbinding die nog niet aan de partij is overgedragen. */
    fun stopVerbinden() {
        verbindJob?.cancel(); verbindJob = null
        naamVraag = null
        val r = verbindRadio; verbindRadio = null
        if (r != null) viewModelScope.launch { r.stop() }
        verbindStap = VerbindStap.Kiezen
    }

    private fun startDuoAlsGastheer(radio: DuoRadio, partner: String, begin: Statistiek) {
        job?.cancel(); stopDuo()
        benIkGast = false; duoPartnerNaam = partner; duoRadio = radio; inSamenspel = true
        bewaarplaats.schrijfDuo(partner, begin)
        modus = Modus.GEEN; tekst = ""
        view = SpelView().also { it.statistiek = begin }

        val koppeling = DuoKoppeling(radio)
        duoKoppeling = koppeling
        val gUi = GastheerUi(
            ui, koppeling, mijnKant = 1,
            // Bij demo of automatisch doorgaan wacht de gastheer zelf niet, dus de gast ook niet.
            wachtLokaalOpTik = { !snel && !automatisch && !demo },
            gaVerder = { gaVerder() },
            log = { BleLog.zeg(it) })
        gastheerUi = gUi
        // Alleen demo gaat live mee: openKaart en de speelwijzen zouden de kaarten of de speelwijze
        // van de gast raken, en die kant is van een mens.
        val spel = nl.edsoft.klaverjas.KjSpel(gUi, leesInstellingen = { Instellingen(demo = demo) },
            mijnKant = 1, beginStatistiek = begin)
        spel.e.s.mens[1] = true
        koppeling.start(viewModelScope)
        gUi.koppel(spel, viewModelScope)
        job = viewModelScope.launch { spel.loop() }
        bewaakVerbinding(radio)
    }

    private fun startDuoAlsGast(radio: DuoRadio, partner: String, begin: Statistiek) {
        job?.cancel(); stopDuo()
        benIkGast = true; duoPartnerNaam = partner; duoRadio = radio; inSamenspel = true
        bewaarplaats.schrijfDuo(partner, begin)
        modus = Modus.GEEN; tekst = ""
        view = SpelView().also { it.mijnKant = 2; it.statistiek = begin.kantenOmgewisseld }

        val koppeling = DuoKoppeling(radio)
        duoKoppeling = koppeling
        koppeling.start(viewModelScope)
        val g = DuoGast(koppeling)
        gast = g
        job = viewModelScope.launch {
            while (isActive) {
                val v = g.volgendeStand() ?: break
                pasGastStandToe(v)
            }
        }
        bewaakVerbinding(radio)
    }

    /** Toont een momentopname van de gastheer en zet alleen de invoer aan als ik aan zet ben (of verder mag tikken). */
    private fun pasGastStandToe(v: SpelView) {
        view = v
        tekst = v.melding.ifEmpty { v.status }
        bewaar(v, meteen = v.spelUit)
        modus = when {
            v.troefVraag && v.benIkAanZet -> Modus.KIES_TROEF
            v.wachtOpSpeler && v.benIkAanZet -> Modus.KIES_KAART
            // "Verder" is geen beurt, dus mag van allebei de kanten komen.
            v.wachtOpVerder -> Modus.VERDER
            else -> Modus.GEEN
        }
    }

    private fun stuurGastZet(z: GastZet) {
        modus = Modus.GEEN
        val k = duoKoppeling
        if (k == null) { BleLog.zeg("tik genegeerd (geen duo-verbinding meer)"); return }
        viewModelScope.launch { k.stuur(DuoBericht.Zet(DuoStand.codeer(z.toJson()))) }
    }

    /** Valt de verbinding tijdens het spel weg, dan stopt de partij met een melding, bij beide kanten. */
    private fun bewaakVerbinding(radio: DuoRadio) {
        bewaker = viewModelScope.launch {
            radio.statusStroom().first { it is DuoStatus.Mislukt }
            BleLog.zeg("verbinding tijdens het spel weggevallen - partij stopt")
            job?.cancel()
            stopDuo()
            modus = Modus.GEEN
            tekst = Taal.duoVerbindingVerbroken
        }
    }

    /** Legt de tellingen vast, bij een samenspel in de bak van deze partner (in mijn eigen kant-orde). */
    private fun bewaar(v: SpelView, meteen: Boolean = false) {
        if (v.statistiek.leeg) return
        val nu = System.nanoTime()
        if (!meteen && nu - laatstBewaard < 1_000_000_000L) return
        laatstBewaard = nu
        val partner = duoPartnerNaam
        if (partner == null) { bewaarplaats.schrijf(v.statistiek); return }
        bewaarplaats.schrijfDuo(partner, if (benIkGast) v.statistiek.kantenOmgewisseld else v.statistiek)
    }

    /** Sluit een lopend samenspel netjes af; de partij zelf stopt de aanroeper. */
    private fun stopDuo() {
        if (duoPartnerNaam != null) bewaar(view, meteen = true)
        bewaker?.cancel(); bewaker = null
        duoKoppeling?.stop(); duoKoppeling = null
        gastheerUi?.stop(); gastheerUi = null
        // De echte radio ook echt afsluiten, anders blijft hij adverteren of scannen en blokkeert hij de volgende.
        duoRadio?.let { r -> viewModelScope.launch { r.stop() } }
        duoRadio = null
        gast = null
        benIkGast = false; duoPartnerNaam = null; inSamenspel = false
    }

    /** Stop samen: sluit de verbinding en begint weer een eigen partij. */
    fun stopSamen() = start()

    override fun onCleared() {
        stopVerbinden()
        super.onCleared()
    }

    /** Een tik op een eigen kaart (hand of tafel). */
    fun klik(kaart: KaartView) {
        when (modus) {
            Modus.KIES_KAART -> {
                if (benIkGast) { stuurGastZet(GastZet(kaart = kaart.naam, kleur = kaart.kleur)); return }
                modus = Modus.GEEN
                kaartWacht?.complete(kaart.naam to kaart.kleur)
            }
            Modus.KIES_TROEF -> kiesTroef(kaart.kleur)   // een kaart aantikken kiest zijn kleur
            Modus.VERDER -> gaVerder()
            Modus.GEEN -> {}
        }
    }

    fun kiesTroef(kleur: Int) {
        if (modus != Modus.KIES_TROEF) return
        if (benIkGast) { stuurGastZet(GastZet(troef = kleur)); return }
        modus = Modus.GEEN
        troefWacht?.complete(kleur)
    }

    fun gaVerder() {
        if (modus != Modus.VERDER) return
        if (benIkGast) { stuurGastZet(GastZet(verder = true)); return }
        modus = Modus.GEEN
        verderWacht?.complete(Unit)
    }

    /** De zin voor de balk bovenin als er niets bijzonders te melden is. */
    val aansporing: String? get() = if (modus == Modus.VERDER && view.spelUit) Taal.tikVerder else null

    // Als laatste: start() raakt ook de samenspel-velden hierboven, die dan al moeten bestaan.
    init { start() }

    private companion object {
        val ALGEMENE_NAMEN = setOf("iPhone", "iPad", "iPod touch", "Android")
        const val MAX_SPELLEN = 1_000_000L
    }
}
