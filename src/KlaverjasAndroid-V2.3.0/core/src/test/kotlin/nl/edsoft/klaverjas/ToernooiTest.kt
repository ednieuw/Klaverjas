package nl.edsoft.klaverjas

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Het tweede ijk: Ednieuw tegen Ronlog, 500 spellen, zaad 1, elk spel twee keer.
 * De getallen komen van `swift run -c release toernooi 500 1` (KlaverjasSwift) en
 * moeten exact kloppen; dan kiest de Kotlin-zoeker overal dezelfde kaart.
 */
class ToernooiTest {
    @Test
    fun toernooiGeeftDezelfdeGetallenAlsSwift() {
        val u = Toernooi.speel(500, 1)
        assertEquals(0, u.verzaakt)
        assertEquals(1000, u.gespeeld)
        assertEquals(listOf(489L, 511L), u.gewonnen.toList())
        assertEquals(listOf(92817L, 93403L), u.punten.toList())
        assertEquals(listOf(16560L, 17660L), u.roem.toList())
        assertEquals(listOf(117L, 106L), u.nat.toList())
        assertEquals(listOf(48L, 28L), u.pit.toList())
    }

    @Test
    fun verslagHeeftDeVorm() {
        val r = Toernooi.verslag(Toernooi.speel(20, 1))
        assertEquals("Ednieuw", r[0].trim().split(Regex("\\s+"))[0])
        assertEquals("-".repeat(42), r[1])
    }
}
