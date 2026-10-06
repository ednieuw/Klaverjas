package nl.edsoft.klaverjas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * De snelle simulatie van Claude ([ClaudeStand]) moet dezelfde regels en dezelfde telling hebben
 * als de engine, anders speelt hij een ander spel dan het echte. Drie proeven:
 *
 *  1. de toegestane kaarten, op elk beslismoment van 200 spellen, voor elke kaart in de stapel;
 *  2. de telling van punten en roem, slag voor slag, tegen het ijkspoor;
 *  3. pit, tegenpit en nat tegen evalueerSpel().
 */
class ClaudeRegelsTest {
    private fun bouw(e: KjEngine): ClaudeStand {
        val s = e.s
        val st = ClaudeStand()
        st.troef = s.troef
        st.speler = (if (s.speler > 2) s.speler - 2 else s.speler) - 1
        st.slagNr = s.slagNr
        for (n in 0 until 32) {
            when (s.kaart[n].dichtIkHy) {
                Pos.HAND_ZUID -> st.hand[0] = st.hand[0] or (1 shl n)
                Pos.HAND_NOORD -> st.hand[1] = st.hand[1] or (1 shl n)
                Pos.TAFEL_ZUID -> st.open[0][e.tafelPos(n)] = n
                Pos.TAFEL_NOORD -> st.open[1][e.tafelPos(n)] = n
                Pos.NIEUW_ZUID -> st.dicht[0][e.tafelPos(n)] = n
                Pos.NIEUW_NOORD -> st.dicht[1][e.tafelPos(n)] = n
                Pos.GESPEELD -> st.gespeeld = st.gespeeld or (1 shl n)
            }
        }
        st.leider = if (s.slagKrtNo == 0) (if (s.vrager > 2) s.vrager - 2 else s.vrager) - 1
                    else (if (s[s.slagNr, 0].speler > 2) s[s.slagNr, 0].speler - 2 else s[s.slagNr, 0].speler) - 1
        for (k in 0 until s.slagKrtNo.coerceAtMost(3)) {
            val sk = s[s.slagNr, k]
            st.legVast(ClaudeTabel.kaartNr(sk.kleur, sk.naam), (if (sk.speler > 2) sk.speler - 2 else sk.speler) - 1, sk.speler < 3)
        }
        return st
    }

    @Test
    fun toegestaneKaartenKomenOverEenMetDeEngine() {
        var beslissingen = 0
        var kaartenGetoetst = 0
        Spoor.genereer(200, 1) { e ->
            val s = e.s
            val st = bouw(e)
            val code = s.vrager                       // de stapel waaruit de gekozen kaart komt
            val kant = (if (code > 2) code - 2 else code) - 1
            assertEquals("kant", kant, st.aanZet)
            if (st.fase > 0) assertEquals("stapel (hand of tafel) bij fase ${st.fase}", code < 3, st.uitHand)

            val mijnMasker = st.toegestaan()
            val bewaardKaart = s.lkaart
            val bewaardKleur = s.lkleur
            for (n in 0 until 32) {
                if (s.kaart[n].dichtIkHy != code) continue
                s.lkaart = s.kaart[n].naam
                s.lkleur = s.kaart[n].kleur
                val engine = e.checkValid() == null
                val ik = mijnMasker and (1 shl n) != 0
                assertEquals(
                    "kaart ${s.kaart[n].naam} van kleur ${s.kaart[n].kleur}, slag ${s.slagNr}, fase ${st.fase}, troef ${s.troef}: " +
                        "engine=$engine simulatie=$ik",
                    engine, ik,
                )
                kaartenGetoetst++
            }
            s.lkaart = bewaardKaart
            s.lkleur = bewaardKleur
            beslissingen++
        }
        assertEquals(200 * 32, beslissingen)       // elke kaart van elk spel is één beslismoment
        assertTrue(kaartenGetoetst > 20000)
    }

    @Test
    fun puntenEnRoemKomenOverEenMetHetIjkspoor() {
        val regels = javaClass.classLoader.getResource("spoor-v11.txt")!!.readText().lines().filter { it.isNotEmpty() && !it.startsWith("#") }
        var spellen = 0
        var i = 0
        while (i < regels.size) {
            val spel = regels[i].split(";")[0]
            val kaarten = ArrayList<Triple<Int, Int, Int>>()     // kaart, kant, stapel
            var slot: List<String>? = null
            while (i < regels.size && regels[i].split(";")[0] == spel) {
                val d = regels[i].split(";")
                if (d[1] == "=") slot = d else kaarten.add(Triple(ClaudeTabel.kaartNr(d[4].toInt(), d[5][0]), (d[3].toInt().let { if (it > 2) it - 2 else it }) - 1, d[3].toInt()))
                i++
            }
            slot ?: continue
            if (kaarten.size < 32) continue              // een afgebroken spel (verzaakt) heeft geen telling
            val st = ClaudeStand()
            st.troef = slot[2].toInt()
            for ((n, k) in kaarten.withIndex()) {
                if (n % 4 == 0) st.leider = k.second
                if (n % 4 == 3) st.speel(k.first) else st.legVast(k.first, k.second, k.third < 3)
            }
            assertEquals("spel $spel punten Zuid", slot[3].toInt(), st.punten[0])
            assertEquals("spel $spel punten Noord", slot[4].toInt(), st.punten[1])
            assertEquals("spel $spel roem Zuid", slot[5].toInt(), st.roem[0])
            assertEquals("spel $spel roem Noord", slot[6].toInt(), st.roem[1])
            spellen++
        }
        assertTrue("alle volledige spellen getoetst: $spellen", spellen >= 190)
    }

    @Test
    fun pitTegenpitEnNatKomenOverEenMetEvalueerSpel() {
        val rnd = java.util.Random(5)
        repeat(400) {
            val e = KjEngine(1)
            val s = e.s
            val speler = 1 + rnd.nextInt(2)
            val p0 = if (rnd.nextInt(6) == 0) 152 * rnd.nextInt(2) else rnd.nextInt(153)
            s.speler = speler
            s.puntenSpel[0] = p0; s.puntenSpel[1] = 152 - p0
            s.roem[0] = 20 * rnd.nextInt(6); s.roem[1] = 20 * rnd.nextInt(6)
            s.slagNr = 9; s.slagKrtNo = 0

            val st = ClaudeStand()
            st.speler = speler - 1
            st.punten[0] = s.puntenSpel[0]; st.punten[1] = s.puntenSpel[1]
            st.roem[0] = s.roem[0]; st.roem[1] = s.roem[1]
            val uit = IntArray(2)
            st.eindstand(uit)

            e.evalueerSpel()
            assertEquals("Zuid bij speler=$speler p0=$p0", s.puntenTotaalSpel[0].toInt(), uit[0])
            assertEquals("Noord bij speler=$speler p0=$p0", s.puntenTotaalSpel[1].toInt(), uit[1])
        }
    }
}
