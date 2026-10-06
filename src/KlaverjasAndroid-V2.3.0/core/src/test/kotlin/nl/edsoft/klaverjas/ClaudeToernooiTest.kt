package nl.edsoft.klaverjas

import nl.edsoft.klaverjas.Toernooi.Stijl
import org.junit.Assert.assertEquals
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File

class ClaudeToernooiTest {
    /** Een korte rooktest: Claude speelt tegen Ednieuw zonder ooit te verzaken. */
    @Test
    fun claudeSpeeltZonderTeVerzaken() {
        val u = Toernooi.speel(12, 3, Stijl.CLAUDE, Stijl.EDNIEUW)
        assertEquals(0, u.verzaakt)
        assertEquals(24, u.gespeeld)
        assertEquals(200, ClaudeAi.standaardProeven)
    }

    /**
     * De meting: draait alleen als KJ_BENCH is gezet, want ze duurt minuten.
     *
     *     KJ_BENCH=1 KJ_N=200 ./gradlew :core:test --tests '*ClaudeToernooiTest.meting'
     *
     * De uitslag komt in core/build/claude-meting.txt.
     */
    @Test
    fun meting() {
        assumeTrue(System.getenv("KJ_BENCH") != null)
        val n = System.getenv("KJ_N")?.toIntOrNull() ?: 100
        val proeven = (System.getenv("KJ_PROEVEN") ?: "200").split(",").map { it.trim().toInt() }
        val uit = StringBuilder()
        val paren = listOf(Stijl.CLAUDE to Stijl.EDNIEUW, Stijl.CLAUDE to Stijl.RONLOG)
        for (p in proeven) for ((a, b) in paren) {
            ClaudeAi.standaardProeven = p
            val t0 = System.nanoTime()
            val u = Toernooi.speel(n, 1, a, b)
            val ms = (System.nanoTime() - t0) / 1_000_000
            uit.append("${a.naam} (proeven=$p) tegen ${b.naam}: $n spellen, elk twee keer gespeeld\n")
            for (r in Toernooi.verslag(u, a, b)) uit.append(r).append('\n')
            uit.append("Tijd: $ms ms\n\n")
            File("build/claude-meting.txt").writeText(uit.toString())
        }
    }
}
