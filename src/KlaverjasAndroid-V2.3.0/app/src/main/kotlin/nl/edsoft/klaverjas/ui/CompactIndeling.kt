package nl.edsoft.klaverjas.ui

import androidx.compose.ui.geometry.Rect
import nl.edsoft.klaverjas.Pos
import nl.edsoft.klaverjas.kaarten.OrigineleKaarten
import kotlin.math.max
import kotlin.math.min

/**
 * De indeling voor een smal scherm: de telefoon rechtop (port van CompactIndeling.swift).
 *
 * Alles is in schermpixels, met `k` = pixels per kaartpixel: een kaart is 53k bij 83k.
 * Zo valt elke kaart 1 op 1 op een schermpixel en hoeft er nergens te worden verkleind.
 * De handen liggen waaiervormig over elkaar; het speelveld is een blok van twee bij
 * twee waarin de plekken hun betekenis houden: Noord boven, Zuid onder, hand links,
 * tafel rechts.
 */
class CompactIndeling(val breedte: Float, hoogte: Float, override val k: Int) : Speelindeling {
    val cw = (OrigineleKaarten.BREEDTE * k).toFloat()
    val ch = (OrigineleKaarten.HOOGTE * k).toFloat()

    private val marge = 10f * k
    val handSpatie: Float
    val noordHandSpatie: Float
    val tafelSpatie: Float

    val yNoordHand: Float
    val yNoordTafel: Float
    val yZuidTafel: Float
    val yZuidHand: Float
    override val veld: Rect

    /** Hoe ver een handrij naar links opschuift ten opzichte van een tafelrij: een tiende kaartbreedte. */
    val handVerschuiving: Float get() = -cw / 10

    init {
        val bruikbaar = breedte - 2 * marge

        // De waaier vult de breedte, maar wordt nooit ijler dan de brede indeling hem
        // zou neerleggen, en nooit zo dicht dat er te weinig van een kaart overblijft.
        fun spatieVoor(aantal: Int, normaal: Float): Float {
            if (aantal <= 1) return normaal
            val passend = (bruikbaar - cw) / (aantal - 1)
            return min(normaal, max(cw * MIN_ZICHTBAAR, passend))
        }

        val veldHoog = veldHoogte(ch, k)
        val over = hoogte - (4 * ch + veldHoog)
        val ruimte = max(RUIMTE_NATUURLIJK * k, min(18f * k, over / 5))
        val blokHoog = 4 * ch + veldHoog + 4 * ruimte
        val boven = max(0f, (hoogte - blokHoog) / 2)

        val yNH = boven
        val yNT = yNH + ch + ruimte
        val yV = yNT + ch + ruimte
        val yZT = yV + veldHoog + ruimte
        val veldBreed = 2 * cw + 8 * k

        handSpatie = spatieVoor(8, 57f * k)
        noordHandSpatie = spatieVoor(8, 46f * k)
        tafelSpatie = spatieVoor(4, 70f * k)
        yNoordHand = yNH
        yNoordTafel = yNT
        yZuidTafel = yZT
        yZuidHand = yZT + ch + ruimte
        veld = Rect(breedte / 2 - veldBreed / 2, yV, breedte / 2 + veldBreed / 2, yV + veldHoog)
    }

    /** Waar de kaarten van een rij komen; gecentreerd, want op een smal scherm valt er niets uit te lijnen. */
    fun rij(aantal: Int, y: Float, spatie: Float, verschoven: Boolean = false): List<Rect> {
        if (aantal <= 0) return emptyList()
        val breed = spatie * (aantal - 1) + cw
        val x = (breedte - breed) / 2 + (if (verschoven) handVerschuiving else 0f)
        return (0 until aantal).map { Rect(x + it * spatie, y, x + it * spatie + cw, y + ch) }
    }

    override val lift: Float get() = 2f * k
    override val troefVak: Rect get() = Rect(0f, veld.top - 10f * k, breedte, veld.top - 10f * k + 1f)

    override fun handVakken(aantal: Int, mijn: Boolean): List<Rect> =
        if (mijn) rij(aantal, yZuidHand, handSpatie, verschoven = true)
        else rij(aantal, yNoordHand, noordHandSpatie, verschoven = true)

    override fun tafelVak(plek: Int, mijn: Boolean): Rect = tafelVakOpY(plek, if (mijn) yZuidTafel else yNoordTafel)

    /** De vier tafelplekken, altijd vier breed ook als er minder open liggen. */
    private fun tafelVakOpY(plek: Int, y: Float): Rect {
        val breed = tafelSpatie * 3 + cw
        val x = (breedte - breed) / 2 + plek * tafelSpatie
        return Rect(x, y, x + cw, y + ch)
    }

    /**
     * Plek van de kaart van speler 1..4 in het speelveld van twee bij twee. Wat uit een
     * hand gespeeld is schuift naar buiten, wat van tafel komt naar binnen, zodat je
     * ziet waar een gespeelde kaart vandaan kwam.
     */
    override fun veldPlek(speler: Int): Rect {
        val stap = ch / 10
        val x0 = veld.left + 4 * k
        val y0 = veld.top + 4 * k + stap
        val rechts = x0 + cw + 4 * k
        val onder = y0 + ch + 4 * k
        val (x, y) = when (speler) {
            Pos.TAFEL_NOORD -> x0 to y0 + stap
            Pos.HAND_NOORD -> rechts to y0 - stap
            Pos.HAND_ZUID -> x0 to onder + stap
            else -> rechts to onder - stap
        }
        return Rect(x, y, x + cw, y + ch)
    }

    companion object {
        /** Hoeveel van een kaart in de waaier zichtbaar moet blijven (de linker zeventig procent). */
        const val MIN_ZICHTBAAR = 0.7f
        const val RUIMTE_NATUURLIJK = 12f

        private fun veldHoogte(ch: Float, k: Int) = 2 * ch + 8 * k + 2 * (ch / 10)

        /** De hoogte die deze indeling op ware grootte nodig heeft. */
        fun natuurlijkeHoogte(k: Int): Float {
            val ch = (OrigineleKaarten.HOOGTE * k).toFloat()
            return 4 * ch + veldHoogte(ch, k) + 4 * RUIMTE_NATUURLIJK * k
        }

        /**
         * Grootste hele vergroting waarbij de waaier van acht in de breedte past én het
         * geheel in de hoogte. Past zelfs k = 1 niet, dan blijft het toch k = 1.
         */
        fun kies(breedte: Float, hoogte: Float): Int = kiesAlsHetPast(breedte, hoogte) ?: 1

        /** Dezelfde keuze, maar null als zelfs k = 1 niet past (dan kan de brede indeling het beter). */
        fun kiesAlsHetPast(breedte: Float, hoogte: Float): Int? {
            for (k in 8 downTo 1) {
                val cw = (OrigineleKaarten.BREEDTE * k).toFloat()
                if (cw + 7 * cw * MIN_ZICHTBAAR <= breedte - 20 * k && natuurlijkeHoogte(k) <= hoogte) return k
            }
            return null
        }
    }
}
