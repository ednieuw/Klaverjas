package nl.edsoft.klaverjas

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StatistiekTest {
    @Test
    fun jsonRondreisEnOudFormaat() {
        val s = Statistiek(spellen = longArrayOf(5, 7), superroem = longArrayOf(1, 2))
        s.tactiek[41] = 9
        val terug = Statistiek.uitJson(s.toJson())!!
        assertArrayEquals(longArrayOf(5, 7), terug.spellen)
        assertEquals(9L, terug.tactiek[41])
        assertEquals(listOf(41 to 9L), terug.gebruikteTactieken)

        // Oudere versie: superroem als één getal, en velden die ontbreken.
        val oud = Statistiek.uitJson("""{"spellen":[3,0],"superroem":4}""")!!
        assertArrayEquals(longArrayOf(4, 0), oud.superroem)
        assertEquals(3L, oud.spellen[0])
        assertNull(Statistiek.uitJson("geen json"))
    }

    @Test
    fun tellingenOverleven() {
        val e = KjEngine(1)
        e.s.gewonnenTot[0] = 12; e.s.nat[1] = 3; e.s.gewonnen[0] = 2; e.s.tac[7] = 5
        val st = e.s.statistiek
        val f = KjEngine(2)
        f.s.zetStatistiek(Statistiek.uitJson(st.toJson())!!)
        assertEquals(12L, f.s.gewonnenTot[0]); assertEquals(3L, f.s.nat[1])
        assertEquals(2, f.s.gewonnen[0]); assertEquals(5L, f.s.tac[7])
        assertTrue(!st.leeg)
    }

    @Test
    fun tactiekNamenEnHandleiding() {
        assertNotNull(Taal.tactiekNaam(7))
        assertEquals("onbekend", Taal.tactiekNaam(44))
        assertEquals(8, Handleiding.stukken(engels = false).size)
        assertEquals(8, Handleiding.stukken(engels = true).size)
        assertTrue(Handleiding.stukken(false)[0].tekst.contains("1500 punten"))
        assertTrue(Taal.engelsVoor(listOf("en-GB")) && !Taal.engelsVoor(listOf("nl-NL")))
    }
}
