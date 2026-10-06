package nl.edsoft.klaverjas

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** De speelloop met een nep-scherm: eerst demo (computer speelt alles), dan met een "mens". */
class SpelTest {
    private class Klaar : CancellationException("klaar")

    private class NepUi(val spellen: Int, val mens: Boolean) : KjUi {
        var spellenUit = 0
        var slagen = 0
        var poging = 0
        var geweigerd = 0
        var laatsteMelding = ""

        override suspend fun toon(view: SpelView) {}

        override suspend fun kiesTroef(view: SpelView): Int = 3

        override suspend fun kiesKaart(view: SpelView): Pair<Teken, Int> {
            // Probeer de kaarten van de beurt om de beurt; de engine weigert de ongeldige.
            val kand = (if (view.aanZet == view.mijnHandPos) view.mijnHand else view.mijnTafel) +
                (if (view.aanZet == view.mijnHandPos) view.mijnTafel else view.mijnHand)
            if (poging > 0) geweigerd++
            val k = kand.filter { it.klikbaar || true }[poging % kand.size]
            poging++
            return k.naam to k.kleur
        }

        override suspend fun verder(view: SpelView, tekst: String) {
            poging = 0
            laatsteMelding = tekst
            slagen++
            if (view.spelUit && ++spellenUit >= spellen) throw Klaar()
        }
    }

    @Test
    fun demoSpeeltSpellenUit() = runTest {
        val ui = NepUi(25, mens = false)
        val spel = KjSpel(ui, zaad = 7, leesInstellingen = { Instellingen(demo = true) })
        try { spel.loop() } catch (_: Klaar) {}
        assertEquals(25, ui.spellenUit)
        assertEquals(25 * 8, ui.slagen)          // acht slagen per spel, ook zonder verzaken
        assertTrue(ui.laatsteMelding.contains("wint dit spel"))
    }

    @Test
    fun mensDieAlleKaartenProbeertSpeeltEenGeldigSpel() = runTest {
        val ui = NepUi(5, mens = true)
        val spel = KjSpel(ui, zaad = 3)          // Zuid is mens
        try { spel.loop() } catch (_: Klaar) {}
        assertEquals(5, ui.spellenUit)
        assertEquals(5 * 8, ui.slagen)
        assertTrue("de engine hoort ongeldige kaarten te weigeren", ui.geweigerd > 0)
    }
}

/** Snel spelen bouwt geen kaartbeelden meer op; het spel zelf mag daar niet door veranderen. */
class SnelStandTest {
    private class Klaar : CancellationException("klaar")

    private class Ui(private val snel: Boolean, private val doel: Int) : KjUi {
        override val snelSpelen: Boolean get() = snel
        var toon = 0
        var spellen = 0
        var kaartenGezien = 0
        var slagenGezien = 0
        var eind: String? = null

        override suspend fun toon(view: SpelView) { toon++; kaartenGezien += view.handZuid.size + view.tafelNoord.size }
        override suspend fun kiesTroef(view: SpelView): Int = 0
        override suspend fun kiesKaart(view: SpelView): Pair<Teken, Int> = NUL to 0
        override suspend fun verder(view: SpelView, tekst: String) {
            kaartenGezien += view.handZuid.size + view.tafelNoord.size
            slagenGezien += view.slag.size + view.vorigeSlag.size
            if (view.spelUit && ++spellen == doel) { eind = view.statistiek.toJson(); throw Klaar() }
        }
    }

    private suspend fun speel(snel: Boolean): Ui {
        val ui = Ui(snel, 150)
        try { KjSpel(ui, zaad = 11, leesInstellingen = { Instellingen(demo = true) }).loop() } catch (_: Klaar) {}
        return ui
    }

    @Test
    fun zelfdeSpellenZelfdeTellingen() = runTest {
        val gewoon = speel(false)
        val snel = speel(true)
        assertEquals("de tellingen na 150 spellen", gewoon.eind, snel.eind)
        assertTrue(gewoon.toon > 0 && gewoon.kaartenGezien > 0)
        assertEquals("kaarten getoond bij snel spelen", 0, snel.toon)
        assertEquals("kaartbeelden opgebouwd bij snel spelen", 0, snel.kaartenGezien)
        assertTrue("zonder snel spelen hoort de vorige slag er te zijn", gewoon.slagenGezien > 0)
        assertEquals("kaarten van een slag bij snel spelen", 0, snel.slagenGezien)
    }
}
