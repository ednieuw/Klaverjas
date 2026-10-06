package nl.edsoft.klaverjas

import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test

/**
 * Het ijkbestand: 200 spellen met zaad 1, 6601 regels, per gespeelde kaart één
 * regel. Levert de Kotlin-engine bij hetzelfde zaad exact dit bestand op, dan
 * gedraagt hij zich als de Swift-engine. `spoor-v11.txt` is hetzelfde bestand als
 * in KlaverjasSwift/Tests/KlaverjasKitTests/Bronnen.
 */
class SpoorTest {
    private fun ijkbestand(): List<String> {
        val url = javaClass.classLoader.getResource("spoor-v11.txt") ?: error("spoor-v11.txt ontbreekt")
        // CRLF of LF: lines() vangt beide.
        return url.readText(Charsets.UTF_8).lines().filter { it.isNotEmpty() }
    }

    @Test
    fun ijkbestandIsCompleet() {
        val verwacht = ijkbestand()
        assertEquals(6601, verwacht.size)
        assertEquals("# klaverjas spoor; spellen=200; zaad=1", verwacht[0])
    }

    @Test
    fun spoorIsGelijk() {
        val verwacht = ijkbestand()
        val gekregen = Spoor.genereer(200, 1)

        // Eerst de eerste afwijking aanwijzen: dat zegt meer dan "6601 != 6603".
        for (i in 0 until minOf(verwacht.size, gekregen.size)) {
            if (verwacht[i] != gekregen[i]) {
                val omgeving = (maxOf(0, i - 2) until i).joinToString("\n") { "    ${it + 1}: ${verwacht[it]}" }
                fail("Eerste afwijking op regel ${i + 1}:\n$omgeving\n  ijkbestand: ${verwacht[i]}\n  engine    : ${gekregen[i]}")
            }
        }
        assertEquals("Even ver gelijk, maar niet even lang", verwacht.size, gekregen.size)
    }
}
