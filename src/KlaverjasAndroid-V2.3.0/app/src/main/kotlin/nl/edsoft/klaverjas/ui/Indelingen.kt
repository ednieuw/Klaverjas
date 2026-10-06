package nl.edsoft.klaverjas.ui

import androidx.compose.ui.geometry.Rect
import nl.edsoft.klaverjas.Pos
import nl.edsoft.klaverjas.kaarten.OrigineleKaarten
import kotlin.math.max
import kotlin.math.min

/** Waar alles op het speelscherm staat; zowel de smalle (telefoon rechtop) als de brede indeling kan het leveren. */
interface Speelindeling {
    /** Pixels per kaartpixel. */
    val k: Int
    val veld: Rect

    /** Hoeveel een kaart omhoog steekt als hij aangetikt mag worden. */
    val lift: Float

    /** Waar de troefvraag komt: linkerkant en bovenkant, en de breedte. */
    val troefVak: Rect

    /** De vakken van een handrij: mijn rij (onderaan) of die van de tegenstander (bovenaan). */
    fun handVakken(aantal: Int, mijn: Boolean): List<Rect>

    /** Eén van de vier tafelplekken van mijn rij of die van de tegenstander. */
    fun tafelVak(plek: Int, mijn: Boolean): Rect

    /** Plek van de kaart van speler 1..4 in het speelveld. */
    fun veldPlek(speler: Int): Rect
}

/**
 * De brede indeling (port van Indeling.swift): het speelveld van 130 bij 230 links, vier
 * rijen kaarten rechts, alle tegen dezelfde rechterkant, zoals het origineel ze neerlegde.
 * Alle maten zijn in schermpixels, met `k` pixels per kaartpixel.
 */
class BreedeIndeling(val breedte: Float, val hoogte: Float, override val k: Int) : Speelindeling {
    val cw = (OrigineleKaarten.BREEDTE * k).toFloat()
    val ch = (OrigineleKaarten.HOOGTE * k).toFloat()

    val spatieHand: Float
    val spatieNoordHand: Float
    val spatieTafel: Float
    val rechts: Float
    val yNoordHand: Float
    val yNoordTafel: Float
    val yZuidTafel: Float
    val yZuidHand: Float
    override val veld: Rect
    override val troefVak: Rect
    override val lift: Float get() = 3f * k

    init {
        val vakLinks = 20f * k
        val vakBreed = breedte - 40f * k
        val veldBreed = (VELD_BREEDTE * k).toFloat()

        // De rijen krijgen de gewone afstand, tenzij het dan niet past; dan schuiven de
        // kaarten wat verder over elkaar.
        fun spatie(aantal: Int, normaal: Float, krap: Float, ruimte: Float): Float {
            val passend = (ruimte - cw) / (aantal - 1)
            return min(normaal, max(cw * krap, passend))
        }
        spatieHand = spatie(8, 57f * k, HAND_KRAP, vakBreed)
        spatieNoordHand = spatie(8, 46f * k, HAND_KRAP, vakBreed)
        // De tafelrij krijgt niet de volle breedte: links ervan moet het speelveld nog passen.
        spatieTafel = spatie(4, 70f * k, TAFEL_KRAP, vakBreed - veldBreed - 24f * k)

        val handRij = spatieHand * 7 + cw
        val tafelRij = spatieTafel * 3 + cw
        val nodigBreed = max(handRij, veldBreed + 24f * k + tafelRij)
        rechts = vakLinks + vakBreed - max(0f, vakBreed - nodigBreed) / 2

        // Tussen de twee tafelrijen extra ruimte: daar steken de dichte kaarten naar elkaar
        // toe uit en die mogen elkaar niet raken.
        val extra = 12f * k
        val gap = max(4f, (hoogte - 4 * ch - extra) / 5)
        yNoordHand = gap
        yNoordTafel = yNoordHand + ch + gap
        yZuidTafel = yNoordTafel + ch + gap + extra
        yZuidHand = yZuidTafel + ch + gap

        // Het speelveld bij voorkeur rechts, in de vrije ruimte links van de tafelrijen en
        // tussen de handen in. Past het daar niet, dan valt hij terug naar links naast de rijen.
        val vh = (VELD_HOOGTE * k).toFloat()
        val x = rechts - tafelRij - 24f * k - veldBreed
        val bandTop = yNoordHand + ch
        val bandBot = yZuidTafel + ch + gap
        veld = if (x >= 8f * k && bandBot - bandTop >= vh + VELD_MARGE * k) {
            Rect(x, bandTop + (bandBot - bandTop - vh) / 2, x + veldBreed, bandTop + (bandBot - bandTop - vh) / 2 + vh)
        } else {
            Rect(vakLinks, (hoogte - vh) / 2, vakLinks + veldBreed, (hoogte - vh) / 2 + vh)
        }

        // De troefvraag komt boven op de twee rijen van de tegenstander: daar zit toch geen
        // informatie, en zo blijft je eigen hand zichtbaar terwijl je kiest.
        val handBreed = spatieNoordHand * 7 + cw
        troefVak = Rect(rechts - handBreed, yNoordHand, rechts, yNoordHand + 2 * ch + gap)
    }

    /** Waar de kaarten van een gewone rij komen, alle tegen dezelfde rechterkant. */
    private fun rij(aantal: Int, y: Float, spatie: Float): List<Rect> {
        if (aantal <= 0) return emptyList()
        val breed = spatie * (aantal - 1) + cw
        val x = rechts - breed
        return (0 until aantal).map { Rect(x + it * spatie, y, x + it * spatie + cw, y + ch) }
    }

    override fun handVakken(aantal: Int, mijn: Boolean): List<Rect> =
        if (mijn) rij(aantal, yZuidHand, spatieHand) else rij(aantal, yNoordHand, spatieNoordHand)

    /** Een tafelrij heeft altijd vier plekken, ook als er minder open liggen. */
    override fun tafelVak(plek: Int, mijn: Boolean): Rect {
        val breed = spatieTafel * 3 + cw
        val x = rechts - breed + plek * spatieTafel
        val y = if (mijn) yZuidTafel else yNoordTafel
        return Rect(x, y, x + cw, y + ch)
    }

    override fun veldPlek(speler: Int): Rect {
        val (x, y) = when (speler) {
            Pos.HAND_ZUID -> 10 to 135       // Zuid onderaan
            Pos.TAFEL_ZUID -> 65 to 95
            Pos.TAFEL_NOORD -> 10 to 50      // Noord bovenaan
            else -> 65 to 10
        }
        val l = veld.left + x * k
        val b = veld.top + y * k
        return Rect(l, b, l + cw, b + ch)
    }

    companion object {
        const val VELD_BREEDTE = 130
        const val VELD_HOOGTE = 230
        const val VELD_MARGE = 24f   // lucht boven en onder het veld samen
        const val HAND_KRAP = 0.75f
        const val TAFEL_KRAP = 0.85f

        private fun handRijBreed(k: Int): Float {
            val cw = OrigineleKaarten.BREEDTE * k
            return (cw * HAND_KRAP).toInt() * 7f + cw
        }

        private fun tafelRijBreed(k: Int): Float {
            val cw = OrigineleKaarten.BREEDTE * k
            return (cw * TAFEL_KRAP).toInt() * 3f + cw
        }

        /**
         * De vergroting waarop de brede indeling past, of null. Past hij niet, dan hoort de smalle
         * het over te nemen; anders wordt de onderste rij afgesneden.
         */
        fun schaalIndienPassend(breedte: Float, hoogte: Float): Int? {
            for (k in 8 downTo 1) {
                val ch = (OrigineleKaarten.HOOGTE * k).toFloat()
                val handRij = handRijBreed(k)
                val tafelRij = tafelRijBreed(k)
                val rijenHoog = 4 * ch + 12f * k + 20f * k

                // Speelveld tussen de handen in, links van de tafelrijen.
                val nodigBinnen = (5f * VELD_HOOGTE * k + 5f * VELD_MARGE * k + 2 * ch - 2 * 12f * k + 2f * k) / 3
                val binnen = 40f * k + max(handRij, VELD_BREEDTE * k + 24f * k + tafelRij) <= breedte && nodigBinnen <= hoogte

                // Of anders links naast alle rijen.
                val buiten = 40f * k + VELD_BREEDTE * k + 24f * k + handRij <= breedte && rijenHoog <= hoogte

                if (binnen || buiten) return k
            }
            return null
        }
    }
}
