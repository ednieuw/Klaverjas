package nl.edsoft.klaverjas.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import nl.edsoft.klaverjas.KaartView
import nl.edsoft.klaverjas.Pos
import nl.edsoft.klaverjas.SpelView
import nl.edsoft.klaverjas.Taal
import kotlin.math.roundToInt

/**
 * Het speelscherm voor een telefoon rechtop: een balk met de laatste melding, een
 * regel met troef en stand, het speelveld met vier rijen kaarten, en onderaan een paar
 * knoppen. Port van CompactScherm.swift.
 */
@Composable
fun SpelScherm(model: SpelModel) {
    // Bij een taalwissel alles opnieuw opbouwen: Taal is geen Compose-toestand.
    key(model.engels) { SpelSchermInhoud(model) }
}

@Composable
private fun SpelSchermInhoud(model: SpelModel) {
    var blad by remember { mutableStateOf<Blad?>(null) }
    BackHandler(enabled = blad != null) { blad = null }

    Box(Modifier.fillMaxSize()) {
        // Bij snel spelen is er geen speelscherm: het zou onder het snelle-spelenscherm alsnog de
        // kaarten van de laatste slag opbouwen en tekenen, bij elke verversing.
        if (!model.snel) Spelscherm(model, onBlad = { blad = it })
        // Het grote partijscherm: alleen als iemand meekijkt, dus niet in demo of automatisch.
        if (model.modus == Modus.VERDER && model.view.spelUit && model.view.partijUit) {
            PartijSplash(model.view) { model.gaVerder() }
        }
        if (model.snel) SnelScherm(model, toonStatistiek = { blad = Blad.STATISTIEK })
        when (blad) {
            Blad.OPTIES -> OptieBlad(model, sluit = { blad = null }, toonSpelregels = { blad = Blad.SPELREGELS })
            Blad.STATISTIEK -> StatistiekBlad(
                model.eigenStatistiek, wis = { model.wisStatistiek() }, sluit = { blad = null },
                duo = model.alleBewaardeDuoTellingen(), actievePartner = model.actievePartner,
                wisPartner = { model.wisDuoPartner(it) })
            Blad.SAMEN -> SamenSpelenBlad(model, sluit = { blad = null })
            Blad.SPELREGELS -> HandleidingBlad(sluit = { blad = null })
            null -> {}
        }
    }
}

/**
 * Staand: een balk met de melding, een regel met troef en stand, het speelveld en onderaan de
 * knoppen. Liggend: het speelveld met een paneel ernaast waar die dingen onder elkaar staan.
 */
@Composable
private fun Spelscherm(model: SpelModel, onBlad: (Blad) -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize().background(Kleuren.achtergrond)) {
        val liggend = maxWidth > maxHeight * 1.15f
        if (liggend) {
            Row(Modifier.fillMaxSize().systemBarsPadding()) {
                Speelveld(model, Modifier.weight(1f).fillMaxHeight())
                Paneel(model, onBlad, Modifier.width(250.dp).fillMaxHeight())
            }
        } else {
            Column(Modifier.fillMaxSize().systemBarsPadding()) {
                Balk(model.tekst, model.aansporing)
                Standregel(model.view, model.aansporing)
                Speelveld(model, Modifier.weight(1f).fillMaxWidth())
                Knoppenbalk(model, onBlad)
            }
        }
    }
}

/** De kaarten: vier rijen en het veld in het midden. Kiest zelf de smalle of de brede indeling, wie de grootste kaarten geeft. */
@Composable
private fun Speelveld(model: SpelModel, modifier: Modifier) {
    BoxWithConstraints(modifier) {
        val wPx = constraints.maxWidth.toFloat()
        val hPx = constraints.maxHeight.toFloat()
        val ind: Speelindeling = remember(wPx, hPx) {
            val smal = CompactIndeling.kiesAlsHetPast(wPx, hPx)
            val breed = BreedeIndeling.schaalIndienPassend(wPx, hPx)
            if (breed != null && (smal == null || breed > smal)) BreedeIndeling(wPx, hPx, breed)
            else CompactIndeling(wPx, hPx, smal ?: 1)
        }
        val beelden = remember(ind.k) { Kaartbeelden(ind.k) }
        val v = model.view

        Canvas(
            Modifier
                .fillMaxSize()
                .pointerInput(model, v, ind) {
                    detectTapGestures { punt ->
                        if (model.modus == Modus.VERDER) { model.gaVerder(); return@detectTapGestures }
                        // Van achter naar voren: in een waaier ligt de rechter kaart bovenop.
                        for ((vak, kaart) in klikVakken(v, ind).asReversed()) {
                            if (vak.contains(punt)) { model.klik(kaart); return@detectTapGestures }
                        }
                    }
                },
        ) {
            teken(v, ind, beelden, liften = model.modus == Modus.KIES_KAART)
        }

        if (model.modus == Modus.KIES_TROEF) {
            val vak = ind.troefVak
            val breedDp = with(LocalDensity.current) { vak.width.toDp() }
            val hoogDp = with(LocalDensity.current) { vak.height.toDp() }
            TroefKeuze(
                model,
                Modifier
                    .offset { IntOffset(vak.left.roundToInt(), vak.top.roundToInt()) }
                    .width(breedDp)
                    // De brede indeling geeft een vak van twee rijen; de smalle laat de hoogte vrij.
                    .then(if (vak.height > 8f) Modifier.height(hoogDp) else Modifier),
            )
        }
    }
}

/** Altijd mijn eigen rijen, de onderste twee: ze staan toch altijd onderaan. */
private fun klikVakken(v: SpelView, ind: Speelindeling): List<Pair<Rect, KaartView>> {
    val uit = ArrayList<Pair<Rect, KaartView>>()
    for (kaart in v.mijnTafel) uit.add(ind.tafelVak(kaart.plek.coerceIn(0, 3), true) to kaart)
    val hand = v.mijnHand
    for ((i, vak) in ind.handVakken(hand.size, true).withIndex()) uit.add(vak to hand[i])
    return uit
}

// ------------------------------------------------------------ tekenen

private fun DrawScope.teken(v: SpelView, ind: Speelindeling, beelden: Kaartbeelden, liften: Boolean) {
    // Speelveld eerst, de kaarten liggen erop.
    rect(ind.veld, Kleuren.veld)
    drawRect(Kleuren.veldRand, ind.veld.topLeft, ind.veld.size, style = Stroke(2f * ind.k))

    val streep = Stroke(1f * ind.k, pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f * ind.k, 3f * ind.k)))
    for (speler in intArrayOf(Pos.HAND_ZUID, Pos.HAND_NOORD, Pos.TAFEL_ZUID, Pos.TAFEL_NOORD)) {
        if (v.slag.any { it.speler == speler }) continue
        val r = ind.veldPlek(v.relatieveSpeler(speler))
        drawRect(Kleuren.veldRand.copy(alpha = 0.45f), r.topLeft, r.size, style = streep)
    }
    // In speelvolgorde tekenen, zodat een latere kaart over een eerdere valt.
    for (s in v.slag) {
        val vak = ind.veldPlek(v.relatieveSpeler(s.speler))
        schaduw(vak, ind.k)
        beelden.voor(s.naam, s.kleur)?.let { beeld(it, vak) }
    }

    // Zijn hand, dicht of open, altijd bovenaan.
    for ((i, vak) in ind.handVakken(v.zijnHand.size, false).withIndex()) tekenKaart(v.zijnHand[i], vak, beelden, ind.k)

    tekenTafelRij(ind, beelden, v.zijnTafel, v.zijnOnder, mijn = false)
    tekenTafelRij(ind, beelden, v.mijnTafel, v.mijnOnder, mijn = true)

    val hand = v.mijnHand
    for ((i, vak) in ind.handVakken(hand.size, true).withIndex()) {
        // Aan de beurt: de kaarten steken iets omhoog.
        val op = if (liften) vak.translate(0f, -ind.lift) else vak
        tekenKaart(hand[i], op, beelden, ind.k)
    }
}

private fun DrawScope.tekenTafelRij(
    ind: Speelindeling, beelden: Kaartbeelden, open: List<KaartView>, gedekt: BooleanArray, mijn: Boolean,
) {
    // Zeven pixels: één zwarte kaartrand, drie wit en drie blauw, zodat er net zoveel van
    // het ruitpatroon te zien is als van het witte kader. De achterkant hoort onder de plek
    // die hij werkelijk dekt.
    val peek = (if (mijn) -7f else 7f) * ind.k
    for (i in 0 until minOf(4, gedekt.size)) {
        if (gedekt[i]) beeld(beelden.achterkant, ind.tafelVak(i, mijn).translate(0f, peek))
    }
    for (kaart in open) {
        tekenKaart(kaart, ind.tafelVak(kaart.plek.coerceIn(0, 3), mijn), beelden, ind.k)
    }
}

private fun DrawScope.tekenKaart(kaart: KaartView, vak: Rect, beelden: Kaartbeelden, k: Int) {
    schaduw(vak, k)
    val b = if (kaart.open) beelden.voor(kaart.naam, kaart.kleur) else beelden.achterkant
    if (b != null) beeld(b, vak)
}

private fun DrawScope.rect(r: Rect, kleur: Color) = drawRect(kleur, r.topLeft, r.size)

private fun DrawScope.schaduw(r: Rect, k: Int) =
    drawRect(Color.Black.copy(alpha = 0.24f), Offset(r.left + 2f * k, r.top + 3f * k), r.size)

/** Een kaart 1 op 1 op de pixels; nergens geïnterpoleerd. */
private fun DrawScope.beeld(b: androidx.compose.ui.graphics.ImageBitmap, vak: Rect) {
    drawImage(
        b,
        srcOffset = IntOffset.Zero,
        srcSize = IntSize(b.width, b.height),
        dstOffset = IntOffset(vak.left.roundToInt(), vak.top.roundToInt()),
        dstSize = IntSize(vak.width.roundToInt(), vak.height.roundToInt()),
        filterQuality = FilterQuality.None,
    )
}

private fun Rect.translate(dx: Float, dy: Float) = Rect(left + dx, top + dy, right + dx, bottom + dy)

// --------------------------------------------------------- balken en knoppen

/** De laatste melding, bovenin. */
@Composable
private fun Balk(tekst: String, aansporing: String?) {
    Box(
        Modifier
            .fillMaxWidth()
            .background(Kleuren.paneel)
            .padding(horizontal = 12.dp, vertical = 6.dp)
            .height(44.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        Text(
            text = tekst.ifEmpty { aansporing ?: "" },
            color = Kleuren.geel,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 2,
        )
    }
}

/** Troef en stand op één regel. */
@Composable
private fun Standregel(v: SpelView, aansporing: String?) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(Kleuren.paneel.copy(alpha = 0.8f))
            .padding(horizontal = 12.dp)
            .height(34.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (v.spelUit) {
            deel(aansporing ?: Taal.spelUit, "")
        } else {
            TroefDeel(v)
            deel(Taal.slagVanAcht(maxOf(1, v.slagNr)), "")
        }
        Spacer(Modifier.weight(1f))
        deel(Taal.zuid, "${v.mijnPunten}+${v.mijnRoem}")
        deel(Taal.noord, "${v.zijnPunten}+${v.zijnRoem}")
    }
}

@Composable
private fun deel(kop: String, waarde: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(kop, color = Kleuren.geel.copy(alpha = 0.7f), fontSize = 12.sp)
        if (waarde.isNotEmpty()) Text(waarde, color = Kleuren.geel, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun TroefDeel(v: SpelView) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        if (v.troefmaker != 0) {
            Text(Taal.kantKort(v.troefmakerRelatief), color = Kleuren.geel, fontSize = 15.sp, fontWeight = FontWeight.Bold)
        }
        Text(Taal.troef, color = Kleuren.geel, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        if (v.troef in 0..3) Troefteken(v.troef, 22) else Text("-", color = Kleuren.geel, fontSize = 15.sp)
    }
}

/** Het kleurteken op een wit vlakje: zwart leest niet op donkergroen. */
@Composable
fun Troefteken(kleur: Int, grootte: Int) {
    Box(
        Modifier
            .size(grootte.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(Kleuren.kaartWit),
        contentAlignment = Alignment.Center,
    ) {
        Text(Taal.kleurTeken(kleur), color = Kleuren.kaartKleur(kleur), fontSize = (grootte * 0.75).sp, textAlign = TextAlign.Center)
    }
}

/** De vier troefknoppen, midden op het speelveld. */
@Composable
private fun TroefKeuze(model: SpelModel, modifier: Modifier) {
    Column(
        modifier
            .background(Color(14, 28, 20).copy(alpha = 0.86f))
            .border(2.dp, Kleuren.geel)
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(Taal.kiesDeTroefkleur, color = Kleuren.geel, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            for (kleur in 0 until 4) {
                Box(
                    Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(Kleuren.kaartWit)
                        .pointerInput(kleur) { detectTapGestures { model.kiesTroef(kleur) } }
                        .size(width = 60.dp, height = 52.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(Taal.kleurTeken(kleur), color = Kleuren.kaartKleur(kleur), fontSize = 32.sp)
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(Taal.troefViaKaart, color = Kleuren.geel.copy(alpha = 0.8f), fontSize = 12.sp)
    }
}

/** Liggend: melding, troef, stand en knoppen onder elkaar naast het speelveld. */
@Composable
private fun Paneel(model: SpelModel, onBlad: (Blad) -> Unit, modifier: Modifier) {
    val v = model.view
    Column(
        modifier.background(Kleuren.paneel).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = model.tekst.ifEmpty { model.aansporing ?: "" },
            color = Kleuren.geel, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
            modifier = Modifier.fillMaxWidth().heightIn(min = 60.dp),
        )
        if (v.spelUit) {
            deel(model.aansporing ?: Taal.spelUit, "")
        } else {
            TroefDeel(v)
            deel(Taal.slagVanAcht(maxOf(1, v.slagNr)), "")
        }
        deel(Taal.zuid, "${v.mijnPunten}+${v.mijnRoem}")
        deel(Taal.noord, "${v.zijnPunten}+${v.zijnRoem}")
        Spacer(Modifier.weight(1f))
        // Tijdens samenspel verstopt: die knop zou de lopende, gedeelde partij afbreken.
        if (!model.inSamenspel) Knop(Taal.nieuwSpel, false, Modifier.fillMaxWidth()) { model.nieuwSpel() }
        if (model.inSamenspel) Knop(Taal.duoStopSamen, false, Modifier.fillMaxWidth()) { model.stopSamen() }
        else Knop(Taal.menuSamenSpelen, false, Modifier.fillMaxWidth()) { onBlad(Blad.SAMEN) }
        Knop(Taal.menuStatistieken, false, Modifier.fillMaxWidth()) { onBlad(Blad.STATISTIEK) }
        Knop(Taal.menuOpties, false, Modifier.fillMaxWidth()) { onBlad(Blad.OPTIES) }
    }
}

/** Nieuw spel, statistieken en de opties, onderaan. */
@Composable
private fun Knoppenbalk(model: SpelModel, onBlad: (Blad) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(Kleuren.paneel)
            .padding(horizontal = 8.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (!model.inSamenspel) Knop(Taal.nieuwSpel, false, Modifier.weight(1f)) { model.nieuwSpel() }
        // "Stop samen" is de nette manier om een samenspel af te sluiten, naast een verbinding die vanzelf wegvalt.
        if (model.inSamenspel) Knop(Taal.duoStopSamen, false, Modifier.weight(1f)) { model.stopSamen() }
        else Knop(Taal.menuSamenSpelen, false, Modifier.weight(1f)) { onBlad(Blad.SAMEN) }
        Knop(Taal.menuStatistieken, false, Modifier.weight(1f)) { onBlad(Blad.STATISTIEK) }
        Knop(Taal.menuOpties, false, Modifier.weight(1f)) { onBlad(Blad.OPTIES) }
    }
}

@Composable
private fun Knop(tekst: String, aan: Boolean, modifier: Modifier, klik: () -> Unit) {
    Box(
        modifier
            .height(40.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(if (aan) Kleuren.geel else Kleuren.achtergrond)
            .pointerInput(klik) { detectTapGestures { klik() } },
        contentAlignment = Alignment.Center,
    ) {
        Text(tekst, color = if (aan) Kleuren.paneel else Kleuren.geel, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, softWrap = false)
    }
}
