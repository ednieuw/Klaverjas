package nl.edsoft.klaverjas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Random

/**
 * Claude mag alleen gebruiken wat de speler die aan zet is kan zien. Bij de opening zijn dat 16 van de 32
 * kaarten: de eigen hand (8), de eigen open tafel (4) en de open tafel van de tegenstander (4). De hand van
 * de tegenstander en de dichte kaarten onder beide tafels zijn verborgen.
 *
 * De proef: verwissel de verborgen kaarten onderling, zodat de zichtbare kaarten gelijk blijven maar de
 * werkelijke verdeling een andere is. Rekent Claude alleen met wat hij ziet, dan zijn alle scores van een
 * zet of een troefkleur daarna exact gelijk. Piept hij naar de verborgen kaarten, dan wijkt minstens een
 * getal af. Als controle: verwissel ook één ZICHTBARE kaart met een verborgen, dan moeten de scores wél
 * veranderen, anders bewijst de proef niets.
 */
class ClaudeZichtTest {
    private fun opening(zaad: Long): KjEngine {
        val e = KjEngine(zaad)
        val s = e.s
        s.comp = true
        s.speler = s.random(2) + 1
        s.troef = 999
        s.slagNr = 0
        s.slagKrtNo = 0
        e.delen()
        s.speler = 1 - (s.speler - 1) + 1
        s.vrager = s.speler
        s.startVrager = s.speler
        for (n in 0 until 4) { s.tNoord[n] = 1; s.tZuid[n] = 1 }
        e.kaartenVrij()
        e.zetTafelPosities()
        e.vulhanden()
        s.slagNr = 0
        return e
    }

    private fun kant(vrager: Int) = (if (vrager > 2) vrager - 2 else vrager) - 1

    /** De kaarten die [ik] niet kan zien, uit de statuscodes van de engine. */
    private fun verborgen(e: KjEngine, ik: Int): List<Int> {
        val tegen = 1 - ik
        val codes = setOf(Pos.DICHT, Pos.HAND_ZUID + tegen, Pos.DICHT_ZUID, Pos.DICHT_NOORD)
        return (0 until 32).filter { e.s.kaart[it].dichtIkHy in codes }
    }

    /** Husselt de statuscodes onder [kaarten] en geeft true als er echt iets verschoven is. */
    private fun husselStatus(e: KjEngine, kaarten: List<Int>, rnd: Random): Boolean {
        val codes = kaarten.map { e.s.kaart[it].dichtIkHy }.toMutableList()
        java.util.Collections.shuffle(codes, rnd)
        var verschoven = false
        for ((i, n) in kaarten.withIndex()) {
            if (e.s.kaart[n].dichtIkHy != codes[i]) verschoven = true
            e.s.kaart[n].dichtIkHy = codes[i]
        }
        return verschoven
    }

    @Test
    fun troefkeuzeKijktAlleenNaarDeZestienZichtbareKaarten() {
        val rnd = Random(7)
        var verschoven = 0
        var controleVerschilt = 0
        for (zaad in 1L..40L) {
            val e = opening(zaad)
            val ik = kant(e.s.startVrager)
            val vb = verborgen(e, ik)
            assertEquals("de opening heeft 16 verborgen kaarten", 16, vb.size)
            val voor = ClaudeAi(e, proeven = 20).troefScores()

            // Drie keer anders verdeeld; de zichtbare kaarten blijven staan.
            repeat(3) {
                val zichtbaarVoor = (0 until 32).filter { it !in vb }.map { it to e.s.kaart[it].dichtIkHy }
                if (husselStatus(e, vb, rnd)) verschoven++
                val zichtbaarNa = (0 until 32).filter { it !in vb }.map { it to e.s.kaart[it].dichtIkHy }
                assertEquals("de zichtbare kaarten moeten gelijk blijven", zichtbaarVoor, zichtbaarNa)
                val na = ClaudeAi(e, proeven = 20).troefScores()
                assertEquals("zaad $zaad: de troefscores hangen af van verborgen kaarten", voor.toList(), na.toList())
            }

            // Controle: één zichtbare eigen handkaart ruilen met een verborgen kaart verandert de scores wel.
            val eigen = (0 until 32).first { e.s.kaart[it].dichtIkHy == Pos.HAND_ZUID + ik }
            val ander = vb.first { e.s.kaart[it].dichtIkHy == Pos.DICHT_ZUID }
            val a = e.s.kaart[eigen].dichtIkHy
            e.s.kaart[eigen].dichtIkHy = e.s.kaart[ander].dichtIkHy
            e.s.kaart[ander].dichtIkHy = a
            val controle = ClaudeAi(e, proeven = 20).troefScores()
            if (controle.toList() != voor.toList()) controleVerschilt++
        }
        assertTrue("de verwisseling moest echt iets verschuiven ($verschoven)", verschoven > 100)
        assertTrue("de controle (zichtbare kaart ruilen) veranderde de scores te weinig: $controleVerschilt van 40", controleVerschilt >= 35)
    }

    @Test
    fun kaartkeuzeTijdensHetSpelKijktAlleenNaarWatZichtbaarIs() {
        val rnd = Random(11)
        var getoetst = 0
        var verschoven = 0
        var teller = 0
        Spoor.genereer(60, 3) { e ->
            if (++teller % 4 != 0) return@genereer
            val s = e.s
            val ik = kant(s.vrager)
            val vb = verborgen(e, ik)
            val voor = ClaudeAi(e, proeven = 12).kaartScores() ?: return@genereer

            val bewaard = vb.map { s.kaart[it].dichtIkHy }
            repeat(2) {
                if (husselStatus(e, vb, rnd)) verschoven++
                val na = ClaudeAi(e, proeven = 12).kaartScores()!!
                assertEquals("kandidaten, slag ${s.slagNr}", voor.first, na.first)
                assertEquals("scores, slag ${s.slagNr}", voor.second.toList(), na.second.toList())
                getoetst++
            }
            for ((i, n) in vb.withIndex()) s.kaart[n].dichtIkHy = bewaard[i]       // het spel loopt gewoon door
        }
        assertTrue("te weinig beslismomenten getoetst: $getoetst", getoetst > 300)
        assertTrue("de verwisseling moest echt iets verschuiven ($verschoven)", verschoven > 200)
    }
}
