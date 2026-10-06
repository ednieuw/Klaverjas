package nl.edsoft.klaverjas

import nl.edsoft.klaverjas.kaarten.Afbeelding
import nl.edsoft.klaverjas.kaarten.Kaartenset
import nl.edsoft.klaverjas.kaarten.OrigineleKaarten
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import javax.imageio.ImageIO

/**
 * `kaarten.png` is de contactafdruk die de C#-versie maakte met
 * `Klaverjas.exe kaartenblad kaarten.png 3`: 1511x1062, alle 32 kaarten plus de
 * achterkant op drievoudige vergroting. Tekent de Kotlin-versie exact dezelfde
 * pixels, dan is de kaartport net zo hard bewezen als de engine.
 */
class KaartenTest {
    private val marge = 8
    private val kb = OrigineleKaarten.BREEDTE * 3    // 159
    private val kh = OrigineleKaarten.HOOGTE * 3     // 249

    private fun ijkblad(): Afbeelding {
        val url = javaClass.classLoader.getResource("kaarten.png") ?: error("kaarten.png ontbreekt")
        val img = ImageIO.read(url)
        val w = img.width
        val h = img.height
        val px = IntArray(w * h)
        for (y in 0 until h) for (x in 0 until w) px[y * w + x] = img.getRGB(x, y) or (0xFF shl 24)
        return Afbeelding(w, h, px)
    }

    private fun afwijking(kaart: Afbeelding, blad: Afbeelding, x0: Int, y0: Int): String? {
        for (y in 0 until kaart.hoogte) for (x in 0 until kaart.breedte) {
            val v = blad[x0 + x, y0 + y]
            val g = kaart[x, y]
            if (v != g) return "pixel ($x, $y): ijkblad %08X, Kotlin %08X".format(v, g)
        }
        return null
    }

    @Test
    fun ijkbladHeeftDeVerwachteAfmetingen() {
        val blad = ijkblad()
        assertEquals(marge + 9 * (kb + marge), blad.breedte)        // 1511
        assertEquals(marge + 4 * (kh + marge) + 26, blad.hoogte)    // 1062
    }

    @Test
    fun alle32KaartenZijnPixelVoorPixelGelijk() {
        val blad = ijkblad()
        val set = Kaartenset(3)
        for (kleur in 0 until 4) for (rang in 0 until 8) {
            val naam = OrigineleKaarten.RANG_ROEM[rang]
            val kaart = set.voor(naam, kleur)!!
            val x0 = marge + rang * (kb + marge)
            val y0 = marge + kleur * (kh + marge)
            val fout = afwijking(kaart, blad, x0, y0)
            assertTrue("Kaart $naam kleur $kleur wijkt af op $fout", fout == null)
        }
    }

    @Test
    fun achterkantIsPixelVoorPixelGelijk() {
        val blad = ijkblad()
        val fout = afwijking(Kaartenset(3).achterkant, blad, marge + 8 * (kb + marge), marge)
        assertTrue("achterkant wijkt af op $fout", fout == null)
    }

    @Test
    fun scale3xLaatEenVlakMetRust() {
        val groot = OrigineleKaarten.scale3x(Afbeelding(4, 4, 0xFF00FF00.toInt()))
        assertTrue(groot.breedte == 12 && groot.hoogte == 12 && groot.pixels.all { it == 0xFF00FF00.toInt() })
    }
}
