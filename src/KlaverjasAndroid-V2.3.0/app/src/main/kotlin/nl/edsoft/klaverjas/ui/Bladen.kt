package nl.edsoft.klaverjas.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.foundation.layout.systemBarsPadding
import nl.edsoft.klaverjas.SpelView
import nl.edsoft.klaverjas.kaarten.OrigineleKaarten
import kotlin.math.roundToInt
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import nl.edsoft.klaverjas.Handleiding
import nl.edsoft.klaverjas.Statistiek
import nl.edsoft.klaverjas.Taal
import nl.edsoft.klaverjas.tactiekNaam

/** De bladen die over het speelscherm heen komen: opties, statistiek en spelregels. */
enum class Blad { OPTIES, STATISTIEK, SPELREGELS, SAMEN }

/** Gemeenschappelijke vorm: donkere ondergrond, titel, rollende inhoud, en onderaan een rij knoppen. */
@Composable
private fun BladKader(titel: String, onderrij: @Composable RowScope.() -> Unit, inhoud: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .background(Kleuren.paneel)
            .systemBarsPadding()
            .padding(18.dp),
    ) {
        Text(titel, color = Kleuren.geel, fontSize = 19.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(14.dp))
        Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState())) { inhoud() }
        Spacer(Modifier.height(12.dp))
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { onderrij() }
    }
}

@Composable
private fun TekstKnop(tekst: String, klik: () -> Unit) {
    Text(
        tekst, color = Kleuren.geel, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
        modifier = Modifier.clickable(onClick = klik).padding(horizontal = 10.dp, vertical = 10.dp),
    )
}

@Composable
private fun Scheiding() {
    Box(Modifier.fillMaxWidth().height(1.dp).background(Kleuren.geel.copy(alpha = 0.3f)))
}

// ---------------------------------------------------------------- opties

@Composable
fun OptieBlad(model: SpelModel, sluit: () -> Unit, toonSpelregels: () -> Unit) {
    BladKader(
        Taal.menuOpties,
        onderrij = {
            TekstKnop(Taal.menuSpelregels, toonSpelregels)
            Spacer(Modifier.weight(1f))
            TekstKnop(Taal.statSluiten, sluit)
        },
    ) {
        // Bij samenspel loopt de partij van de gastheer: alleen die kan de computer laten meespelen (demo).
        // Open kaart, doorgaan, snel spelen en de speelwijzen horen bij een partij tegen de computer.
        if (!model.inSamenspel || !model.benIkGast) Schakelaar(Taal.menuDemo, model.demo) { model.zetDemo(it) }
        if (!model.inSamenspel) {
            Schakelaar(Taal.menuOpenKaart, model.openKaart) { model.zetOpenKaart(it) }
            Schakelaar(Taal.menuAuto, model.automatisch) { model.zetAutomatisch(it) }
            Schakelaar(Taal.menuSnel, model.snel) { model.zetSnel(it); if (it) sluit() }

            Spacer(Modifier.height(10.dp))
            Scheiding()
            Spacer(Modifier.height(12.dp))

            Text(Taal.menuSpeelwijze, color = Kleuren.geel, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            SpeelwijzeKeuze(Taal.menuNoordSpeelt, model.stijlNoord) { model.zetStijlNoord(it) }
            // Zuid alleen als de computer die kant speelt; anders speel je zelf.
            if (model.demo) {
                Spacer(Modifier.height(10.dp))
                SpeelwijzeKeuze(Taal.menuZuidSpeelt, model.stijlZuid) { model.zetStijlZuid(it) }
            }

            Spacer(Modifier.height(14.dp))
            Scheiding()
            Spacer(Modifier.height(12.dp))
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(Taal.menuTaal, color = Kleuren.geel, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            Row(Modifier.border(1.dp, Kleuren.geel.copy(alpha = 0.45f))) {
                TaalKnop("NL", !model.engels) { model.zetEngels(false) }
                TaalKnop("EN", model.engels) { model.zetEngels(true) }
            }
        }

        VorigeSlagRij(model.view)

        Spacer(Modifier.height(24.dp))
        Text(
            Taal.menuVersie(model.versie), color = Kleuren.geel.copy(alpha = 0.5f), fontSize = 11.sp,
            modifier = Modifier.fillMaxWidth(), textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
    }
}

@Composable
private fun Schakelaar(tekst: String, aan: Boolean, wijzig: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable { wijzig(!aan) }.padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(tekst, color = Kleuren.geel, fontSize = 15.sp, modifier = Modifier.weight(1f))
        Switch(
            checked = aan, onCheckedChange = wijzig,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Kleuren.paneel, checkedTrackColor = Kleuren.geel,
                uncheckedThumbColor = Kleuren.geel, uncheckedTrackColor = Kleuren.achtergrond,
                uncheckedBorderColor = Kleuren.geel.copy(alpha = 0.5f),
            ),
        )
    }
}

@Composable
private fun TaalKnop(naam: String, gekozen: Boolean, klik: () -> Unit) {
    Box(
        Modifier
            .width(54.dp).height(32.dp)
            .background(if (gekozen) Kleuren.geel.copy(alpha = 0.85f) else Color.Transparent)
            .clickable(onClick = klik),
        contentAlignment = Alignment.Center,
    ) {
        Text(naam, color = if (gekozen) Kleuren.paneel else Kleuren.geel, fontSize = 13.sp, fontWeight = FontWeight.Bold)
    }
}

/** De speelwijze van één kant: de vuistregels van Ednieuw, het doorrekenen van Ronlog of het uitspelen van Claude. */
@Composable
private fun SpeelwijzeKeuze(kop: String, gekozen: Int, kies: (Int) -> Unit) {
    Text(kop, color = Kleuren.geel.copy(alpha = 0.8f), fontSize = 13.sp)
    Spacer(Modifier.height(4.dp))
    Column(Modifier.fillMaxWidth().border(1.dp, Kleuren.geel.copy(alpha = 0.45f))) {
        SpeelwijzeRij(Taal.menuAiEd, gekozen == 0) { kies(0) }
        SpeelwijzeRij(Taal.menuAiLoggen, gekozen == 1) { kies(1) }
        SpeelwijzeRij(Taal.menuAiClaude, gekozen == 2) { kies(2) }
    }
}

@Composable
private fun SpeelwijzeRij(naam: String, gekozen: Boolean, klik: () -> Unit) {
    Box(
        Modifier
            .fillMaxWidth().height(40.dp)
            .background(if (gekozen) Kleuren.geel.copy(alpha = 0.85f) else Color.Transparent)
            .clickable(onClick = klik)
            .padding(horizontal = 10.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        Text(
            naam, color = if (gekozen) Kleuren.paneel else Kleuren.geel, fontSize = 14.sp,
            fontWeight = if (gekozen) FontWeight.Bold else FontWeight.Normal, maxLines = 1,
        )
    }
}

// ------------------------------------------------------------ statistiek

/** De tellingen die het origineel bij het afsluiten afdrukte, met Zuid en Noord als kolommen. */
@Composable
fun StatistiekBlad(
    stat: Statistiek, wis: () -> Unit, sluit: () -> Unit,
    /** Samenspel-partners met hun eigen, losstaande tellingen; leeg als er nooit samen gespeeld is. */
    duo: Map<String, Statistiek> = emptyMap(),
    /** De partner met wie nu gespeeld wordt: die kan niet verwijderd worden. */
    actievePartner: String? = null,
    wisPartner: ((String) -> Unit)? = null,
) {
    var vraagtOmWissen by remember { mutableStateOf(false) }
    var partners by remember { mutableStateOf(duo) }
    var vraagtOmWissenPartner by remember { mutableStateOf<String?>(null) }
    BladKader(
        Taal.statTitel,
        onderrij = {
            // Wissen kan niet ongedaan gemaakt worden, dus er hoort een vraag tussen. Links, ver van Sluiten.
            // Alleen de eigen tellingen; de partners hebben ieder hun eigen prullenbak, zodat een foutje nooit alles kost.
            if (!stat.leeg && actievePartner == null) {
                if (vraagtOmWissen) {
                    Text(Taal.statWissenZeker, color = Kleuren.geel.copy(alpha = 0.85f), fontSize = 13.sp)
                    TekstKnop(Taal.statWissenJa) { vraagtOmWissen = false; wis(); sluit() }
                    TekstKnop(Taal.statWissenNee) { vraagtOmWissen = false }
                } else {
                    TekstKnop(Taal.statWissen) { vraagtOmWissen = true }
                }
            }
            Spacer(Modifier.weight(1f))
            TekstKnop(Taal.statSluiten, sluit)
        },
    ) {
        if (stat.leeg && partners.isEmpty()) {
            Text(Taal.statNogNiets, color = Kleuren.geel.copy(alpha = 0.8f), modifier = Modifier.padding(vertical = 20.dp))
        }
        if (!stat.leeg) {
            Row(Modifier.fillMaxWidth()) {
                Spacer(Modifier.weight(1f))
                Kolom(Taal.zuid, true); Kolom(Taal.noord, true)
            }
            Scheiding()
            Regel(Taal.statStand, stat.totaal)
            Regel(Taal.statPartijen, stat.partijen)
            Regel(Taal.statSpellen, stat.spellen)
            Regel(Taal.statKaartpunten, stat.kaartpunten)
            Regel(Taal.statTroefpunten, stat.troefpunten)
            Regel(Taal.statTroefkaarten, stat.troefkaarten)
            Regel(Taal.statRoempunten, stat.roempunten)
            Regel(Taal.statPit, stat.pit)
            Regel(Taal.statTegenpit, stat.tegenpit)
            Regel(Taal.statNat, stat.nat)
            Scheiding()
            Regel(Taal.statSuperroem, stat.superroem)
        }

        // Onder de eigen tellingen: elke samenspel-partner met zijn eigen, losstaande score.
        if (partners.isNotEmpty()) {
            run {
                if (!stat.leeg) { Spacer(Modifier.height(16.dp)); Scheiding(); Spacer(Modifier.height(16.dp)) }
                Text(Taal.statSamenspel, color = Kleuren.geel, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                // De actiefste partner (de meeste spellen) eerst.
                val gesorteerd = partners.entries.sortedWith(
                    compareByDescending<Map.Entry<String, Statistiek>> { it.value.spellen[0] + it.value.spellen[1] }.thenBy { it.key })
                for ((naam, st) in gesorteerd) {
                    Row(Modifier.fillMaxWidth().padding(vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(naam, color = Kleuren.geel.copy(alpha = 0.9f), fontSize = 13.sp, maxLines = 1, modifier = Modifier.weight(1f))
                        Text("${st.partijen[0]} \u2013 ${st.partijen[1]}", color = Kleuren.geel, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                        if (wisPartner != null && naam != actievePartner) {
                            if (vraagtOmWissenPartner == naam) {
                                Text(Taal.statPartnerWissenZeker(naam), color = Kleuren.geel.copy(alpha = 0.85f), fontSize = 11.sp, maxLines = 1)
                                TekstKnop(Taal.statWissenJa) { vraagtOmWissenPartner = null; wisPartner(naam); partners = partners - naam }
                                TekstKnop(Taal.statWissenNee) { vraagtOmWissenPartner = null }
                            } else {
                                TekstKnop(Taal.statPartnerWissen) { vraagtOmWissenPartner = naam }
                            }
                        }
                    }
                }
            }
        }

        if (!stat.leeg) {
            if (stat.gebruikteTactieken.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
                Scheiding()
                Spacer(Modifier.height(16.dp))
                Text(Taal.statTactiek, color = Kleuren.geel, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Text(Taal.statTactiekUitleg, color = Kleuren.geel.copy(alpha = 0.65f), fontSize = 11.sp)
                Spacer(Modifier.height(8.dp))
                for ((nr, aantal) in stat.gebruikteTactieken) {
                    Row(Modifier.fillMaxWidth().padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.width(26.dp).height(17.dp).background(Kleuren.geel.copy(alpha = 0.85f)), contentAlignment = Alignment.Center) {
                            Text("$nr", color = Kleuren.paneel, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                        Spacer(Modifier.width(8.dp))
                        // 70 is niet van 1994 maar van de zoekende speler.
                        Text(
                            when (nr) { 70 -> Taal.statTactiekZoeken; 71 -> Taal.statTactiekClaude; else -> Taal.tactiekNaam(nr) },
                            color = Kleuren.geel.copy(alpha = 0.9f), fontSize = 11.sp, maxLines = 1, modifier = Modifier.weight(1f),
                        )
                        Text("$aantal", color = Kleuren.geel, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}

@Composable
private fun Kolom(tekst: String, kop: Boolean) {
    Text(
        tekst, color = Kleuren.geel.copy(alpha = if (kop) 0.7f else 1f), fontSize = if (kop) 12.sp else 13.sp,
        fontWeight = if (kop) FontWeight.Bold else FontWeight.Normal,
        modifier = Modifier.width(76.dp).padding(vertical = 6.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End,
    )
}

@Composable
private fun Regel(kop: String, paar: LongArray) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(kop, color = Kleuren.geel, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f).padding(vertical = 4.dp))
        Kolom("${paar[0]}", false); Kolom("${paar[1]}", false)
    }
}

// ----------------------------------------------------------- spelregels

@Composable
fun HandleidingBlad(sluit: () -> Unit) {
    BladKader(
        Taal.menuSpelregels,
        onderrij = { Spacer(Modifier.weight(1f)); TekstKnop(Taal.statSluiten, sluit) },
    ) {
        for (stuk in Handleiding.stukken()) {
            Text(stuk.kop, color = Kleuren.geel, fontSize = 15.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(5.dp))
            Text(stuk.tekst, color = Kleuren.geel.copy(alpha = 0.85f), fontSize = 13.sp, lineHeight = 18.sp)
            Spacer(Modifier.height(16.dp))
        }
    }
}

// ------------------------------------------------------------ vorige slag

/** De kaarten van de vorige slag, zodat je nog even kunt nakijken wat er viel. Op een telefoon is er geen paneel, dus staat hij hier. */
@Composable
private fun VorigeSlagRij(view: SpelView) {
    if (view.vorigeSlag.isEmpty()) return
    val density = LocalDensity.current.density
    // Hele vergroting, zodat elke kaartpixel precies op schermpixels valt.
    val k = maxOf(1, density.roundToInt())
    val beelden = remember(k) { Kaartbeelden(k) }
    Spacer(Modifier.height(14.dp))
    Scheiding()
    Spacer(Modifier.height(12.dp))
    Text(Taal.vorigeSlag, color = Kleuren.geel.copy(alpha = 0.8f), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
    Spacer(Modifier.height(6.dp))
    val breed = with(LocalDensity.current) { (OrigineleKaarten.BREEDTE * k).toDp() }
    val hoog = with(LocalDensity.current) { (OrigineleKaarten.HOOGTE * k).toDp() }
    Row(horizontalArrangement = Arrangement.spacedBy((-6).dp)) {
        for (kaart in view.vorigeSlag) {
            val b = beelden.voor(kaart.naam, kaart.kleur) ?: continue
            Image(b, contentDescription = null, filterQuality = FilterQuality.None, modifier = Modifier.size(breed, hoog))
        }
    }
}

// ------------------------------------------------------- partij en snel spelen

/** Het grote scherm bij het einde van een partij (1500 punten). Dekt het hele speelveld af; een tik gaat verder. */
@Composable
fun PartijSplash(view: SpelView, tik: () -> Unit) {
    val kop = when {
        view.partijGelijkspel -> Taal.partijGelijk
        view.partijGewonnenDoorMij -> Taal.partijGewonnen
        else -> Taal.partijVerloren
    }
    Column(
        Modifier
            .fillMaxSize()
            .background(Kleuren.achtergrond.copy(alpha = 0.98f))
            .systemBarsPadding()
            .clickable(onClick = tik)
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        if (!view.partijGelijkspel) {
            Text(if (view.partijGewonnenDoorMij) "\uD83C\uDFC6" else "\uD83C\uDFC1", fontSize = 64.sp)
            Spacer(Modifier.height(16.dp))
        }
        Text(kop, color = Kleuren.geel, fontSize = 32.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Spacer(Modifier.height(16.dp))
        Text(Taal.partijStand(view.mijnPartijen, view.zijnPartijen), color = Color(245, 245, 240), fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(16.dp))
        Text(view.melding, color = Color(245, 245, 240).copy(alpha = 0.75f), fontSize = 13.sp, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 30.dp))
        Spacer(Modifier.height(26.dp))
        Text(Taal.tikVerder, color = Kleuren.geel.copy(alpha = 0.85f), fontSize = 13.sp, fontWeight = FontWeight.Medium)
    }
}

/** Snel spelen zonder kaarten: een teller, een knop voor de oplopende statistiek en een knop om te stoppen. */
@Composable
fun SnelScherm(model: SpelModel, toonStatistiek: () -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .background(Kleuren.achtergrond)
            .systemBarsPadding()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(Taal.snelBezig, color = Kleuren.geel, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(14.dp))
        Text(Taal.snelSpellen(model.snelGespeeld), color = Color(245, 245, 240), fontSize = 17.sp)
        Spacer(Modifier.height(30.dp))
        // De statistiek loopt vanzelf mee: het scherm wordt een paar keer per seconde ververst.
        Box(
            Modifier
                .border(1.dp, Kleuren.geel.copy(alpha = 0.6f))
                .clickable(onClick = toonStatistiek)
                .padding(horizontal = 36.dp, vertical = 12.dp),
        ) {
            Text(Taal.menuStatistieken, color = Kleuren.geel, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(14.dp))
        Box(
            Modifier
                .background(Kleuren.geel.copy(alpha = 0.85f))
                .clickable { model.zetSnel(false) }
                .padding(horizontal = 36.dp, vertical = 12.dp),
        ) {
            Text(Taal.snelUitzetten, color = Kleuren.paneel, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        }
    }
}

// ------------------------------------------------------------ samen spelen

/**
 * Twee toestellen verbinden over Bluetooth: één stelt zich open (de gastheer, die de partij draait), de
 * ander zoekt (de gast). Vraagt eerst de rechten die Android daarvoor eist.
 */
@Composable
fun SamenSpelenBlad(model: SpelModel, sluit: () -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var geweigerd by remember { mutableStateOf(false) }
    var wachtOpRechten by remember { mutableStateOf<Boolean?>(null) }
    val vraagRechten = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestMultiplePermissions(),
    ) { uitslag ->
        val rol = wachtOpRechten
        wachtOpRechten = null
        if (rol != null) { if (uitslag.values.all { it }) model.verbind(rol) else geweigerd = true }
    }
    fun begin(alsGastheer: Boolean) {
        geweigerd = false
        val mist = nl.edsoft.klaverjas.ble.BleRechten.ontbrekend(context, alsGastheer)
        if (mist.isEmpty()) model.verbind(alsGastheer)
        else { wachtOpRechten = alsGastheer; vraagRechten.launch(mist) }
    }

    // Zodra de verbinding er is en de partij loopt, is dit blad klaar.
    androidx.compose.runtime.LaunchedEffect(model.inSamenspel) { if (model.inSamenspel) sluit() }
    androidx.compose.runtime.DisposableEffect(Unit) { onDispose { model.stopVerbinden() } }

    BladKader(
        Taal.duoTitel,
        onderrij = {
            Spacer(Modifier.weight(1f))
            TekstKnop(Taal.duoAnnuleren) { model.stopVerbinden(); sluit() }
        },
    ) {
        when (val stap = model.verbindStap) {
            is VerbindStap.Kiezen -> {
                Text(Taal.duoUitleg, color = Kleuren.geel.copy(alpha = 0.85f), fontSize = 14.sp)
                Spacer(Modifier.height(18.dp))
                // Wie je bent in de lijst van de ander. iPhones geven apps alleen nog "iPhone" als toestelnaam,
                // dus twee toestellen met dezelfde naam zouden één telling delen: zelf een naam kiezen lost dat op.
                Text(Taal.duoMijnNaam, color = Kleuren.geel.copy(alpha = 0.7f), fontSize = 12.sp)
                androidx.compose.foundation.text.BasicTextField(
                    value = model.mijnNaam, onValueChange = { model.zetMijnNaam(it) }, singleLine = true,
                    textStyle = androidx.compose.ui.text.TextStyle(color = Kleuren.geel, fontSize = 16.sp),
                    cursorBrush = androidx.compose.ui.graphics.SolidColor(Kleuren.geel),
                    decorationBox = { veld ->
                        Box(Modifier.fillMaxWidth().border(1.dp, Kleuren.geel.copy(alpha = 0.45f)).padding(10.dp)) {
                            if (model.mijnNaam.isEmpty()) Text(Taal.duoNaamLeeg, color = Kleuren.geel.copy(alpha = 0.4f), fontSize = 16.sp)
                            veld()
                        }
                    },
                )
                Spacer(Modifier.height(18.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    GroteKnop(Taal.duoOpenstellen) { begin(true) }
                    GroteKnop(Taal.duoZoeken) { begin(false) }
                }
                if (geweigerd) {
                    Spacer(Modifier.height(14.dp))
                    Text(Taal.duoRechtenGeweigerd, color = Kleuren.geel, fontSize = 13.sp)
                }
            }
            is VerbindStap.Bezig -> if (model.naamVraag != null) {
                NaamVraagKader(model, model.naamVraag!!)
            } else {
                androidx.compose.material3.CircularProgressIndicator(color = Kleuren.geel, modifier = Modifier.size(28.dp))
                Spacer(Modifier.height(14.dp))
                Text(stap.tekst, color = Kleuren.geel.copy(alpha = 0.85f), fontSize = 14.sp)
            }
            is VerbindStap.Mislukt -> {
                Text(stap.tekst, color = Kleuren.geel, fontSize = 14.sp)
                Spacer(Modifier.height(14.dp))
                GroteKnop(Taal.duoOpnieuw) { model.stopVerbinden() }
            }
        }
    }
}

@Composable
private fun GroteKnop(tekst: String, klik: () -> Unit) {
    Box(
        Modifier
            .height(44.dp)
            .background(Kleuren.geel.copy(alpha = 0.16f), androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
            .border(1.dp, Kleuren.geel.copy(alpha = 0.55f), androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
            .clickable(onClick = klik)
            .padding(horizontal = 20.dp),
        contentAlignment = Alignment.Center,
    ) { Text(tekst, color = Kleuren.geel, fontSize = 15.sp, fontWeight = FontWeight.SemiBold) }
}

/** "Met wie speel je?": een naam voor de ander, met de al bekende partners als snelkeuze. */
@Composable
private fun NaamVraagKader(model: SpelModel, vraag: NaamVraag) {
    var naam by remember(vraag) { mutableStateOf(vraag.voorstel) }
    Text(Taal.duoMetWie, color = Kleuren.geel, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
    Spacer(Modifier.height(6.dp))
    Text(Taal.duoMetWieUitleg, color = Kleuren.geel.copy(alpha = 0.75f), fontSize = 13.sp)
    Spacer(Modifier.height(14.dp))
    androidx.compose.foundation.text.BasicTextField(
        value = naam, onValueChange = { naam = it.take(24) }, singleLine = true,
        textStyle = androidx.compose.ui.text.TextStyle(color = Kleuren.geel, fontSize = 16.sp),
        cursorBrush = androidx.compose.ui.graphics.SolidColor(Kleuren.geel),
        decorationBox = { veld ->
            Box(Modifier.fillMaxWidth().border(1.dp, Kleuren.geel.copy(alpha = 0.45f)).padding(10.dp)) { veld() }
        },
    )
    if (vraag.bekend.isNotEmpty()) {
        Spacer(Modifier.height(12.dp))
        androidx.compose.foundation.layout.FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            for (b in vraag.bekend) {
                Text(
                    b, color = Kleuren.geel, fontSize = 13.sp,
                    modifier = Modifier
                        .border(1.dp, Kleuren.geel.copy(alpha = 0.4f), androidx.compose.foundation.shape.RoundedCornerShape(14.dp))
                        .clickable { naam = b }
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                )
            }
        }
    }
    Spacer(Modifier.height(18.dp))
    GroteKnop(Taal.duoOk) { model.beantwoordNaam(naam) }
}
