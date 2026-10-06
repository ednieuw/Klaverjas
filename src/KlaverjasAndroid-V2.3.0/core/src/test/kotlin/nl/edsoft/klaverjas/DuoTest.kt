package nl.edsoft.klaverjas

import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Het samenspel-protocol zonder radio: berichten, JSON-uitwisseling met de Swift-app, en een volledig duo over een lus. */
class DuoTest {
    // --- berichten -------------------------------------------------------------------------------

    @Test
    fun berichtenGaanHeenEnTerug() {
        val alle = listOf(
            DuoBericht.Begroeting(3, "2.2.0", "Eds iPhone 15"), DuoBericht.Akkoord(3),
            DuoBericht.Stand("abc="), DuoBericht.Zet("q1Yq"), DuoBericht.Stat("xyz"), DuoBericht.Pols,
        )
        for (b in alle) assertEquals(b, DuoBericht.uitRegel(b.regel))
        assertEquals("KJ 3 2.2.0 Eds iPhone 15", alle[0].regel)
        assertNull(DuoBericht.uitRegel(""))
        assertNull(DuoBericht.uitRegel("KJ x 1 naam"))
        assertNull(DuoBericht.uitRegel("KJ 3 1.0"))
        assertNull(DuoBericht.uitRegel("PP"))
        assertNull(DuoBericht.uitRegel("STAND"))
        assertNull(DuoBericht.uitRegel("JA 1 2"))
    }

    @Test
    fun regelBufferPlaktPakketjesAanElkaar() {
        val regel = "STAND " + "A".repeat(700)
        for (max in listOf(1, 20, 182, 512)) {
            val buf = RegelBuffer()
            val uit = ArrayList<String>()
            for (p in RegelPakketten.verdeel(regel, max) + RegelPakketten.verdeel("P", max)) uit += buf.neem(p)
            assertEquals(listOf(regel, "P"), uit)
        }
        // Twee regels in één pakketje.
        assertEquals(listOf("P", "JA 3"), RegelBuffer().neem("P\nJA 3\n".toByteArray()))
        // Een halve regel blijft liggen.
        val b = RegelBuffer()
        assertTrue(b.neem("STA".toByteArray()).isEmpty())
        assertEquals(listOf("STAND x"), b.neem("ND x\n".toByteArray()))
    }

    // --- JSON zoals de Swift-app die schrijft ---------------------------------------------------

    @Test
    fun leestWatDeSwiftAppStuurt() {
        // Door Swift gemaakt met DuoStand.codeer(GastZet(troef: 3)) en codeer(Statistiek()).
        val zet = GastZet.uitJson(DuoStand.decodeer("q1YqKcpPTVOyMq4FAA==")!!)!!
        assertEquals(GastZet(troef = 3), zet)
        val st = Statistiek.uitJson(DuoStand.decodeer(
            "q1Yqyk/NLSjNK0nNU7KKNtAxiNVRKgGKpWUnJhYhCxZkliAUpKan5qEIgHSgmVJckJqTg8TPS0SoLy4tSC0C2YwwITG5JDM1G8IfzBAUFMCQycxC8ho4rNADMb8kMTEHyq0FAA==")!!.toString())!!
        assertTrue(st.leeg)
        assertEquals(80, st.tactiek.size)
    }

    @Test
    fun codeerEnDecodeerGeeftHetzelfde() {
        val j = JsonObject(mapOf("a" to JsonPrimitive("hallo ".repeat(500)), "b" to JsonPrimitive(7)))
        assertEquals(j, DuoStand.decodeer(DuoStand.codeer(j)))
        assertNull(DuoStand.decodeer("geen base64 !!"))
        assertNull(DuoStand.decodeer("AAAA"))
    }

    @Test
    fun gastZetJsonIsDieVanSwift() {
        assertEquals("""{"troef":3}""", GastZet(troef = 3).toJson().toString())
        assertEquals("""{"verder":true}""", GastZet(verder = true).toJson().toString())
        assertEquals("""{"kaart":{"raw":65},"kleur":2}""", GastZet(kaart = 'A', kleur = 2).toJson().toString())
    }

    @Test
    fun spelViewOverJsonBlijftGelijk() {
        val spel = KjSpel(object : KjUi {
            override suspend fun toon(view: SpelView) {}
            override suspend fun kiesKaart(view: SpelView) = NUL to 0
            override suspend fun kiesTroef(view: SpelView) = 0
            override suspend fun verder(view: SpelView, tekst: String) {}
        }, zaad = 11)
        for (kant in 1..2) {
            val v = spel.snapshot(voorKant = kant)
            val terug = spelViewUitJson(DuoStand.decodeer(DuoStand.codeer(v.toJson()))!!)!!
            assertEquals(v.toJson(), terug.toJson())
            assertEquals(kant, terug.mijnKant)
        }
        // Alle sleutels, want de Swift-decoder eist ze.
        val sleutels = spel.snapshot().toJson().keys
        for (s in listOf("handZuid", "claude", "zoekt", "statistiek", "partijGelijkspel", "wachtOpVerder", "onderNoord"))
            assertTrue(s, s in sleutels)
    }

    @Test
    fun statistiekWisselenEnVerzoenen() {
        val a = Statistiek(spellen = longArrayOf(5, 3))
        val b = Statistiek(spellen = longArrayOf(3, 6))
        assertEquals(listOf(3L, 5L), a.kantenOmgewisseld.spellen.toList())
        // b (gezien vanaf de ander) telt 9 spellen tegen 8 van a: die wint, en staat dan al in mijn orde.
        val gekozen = StatistiekVerzoening.hoogste(a, b.kantenOmgewisseld)
        assertEquals(listOf(6L, 3L), gekozen.spellen.toList())
    }

    // --- begroeting ------------------------------------------------------------------------------

    @Test
    fun begroetingMetVerzoeningOverEenLus() = runBlocking {
        val (h, g) = LusLijn.paar()
        val hostEigen = mapOf("Gast" to Statistiek(spellen = longArrayOf(4, 1)))      // Host=Zuid 4, Gast 1
        val gastEigen = mapOf("Host" to Statistiek(spellen = longArrayOf(2, 9)))      // Gast 2, Host 9: verder
        val hr = launchRes { DuoOpzet.alsGastheer(h, "2.0.0", "Host", hostEigen) }
        val gr = launchRes { DuoOpzet.alsGast(g, "2.0.0", "Gast", gastEigen) }
        val rh = hr.await() as DuoOpzet.Resultaat.Klaar
        val rg = gr.await() as DuoOpzet.Resultaat.Klaar
        assertEquals("Gast", rh.naam); assertEquals("Host", rg.naam)
        // Host: eigen 5 spellen, die van Gast gezien (2 voor Gast, 9 voor Host) = 11: wint.
        assertEquals(listOf(9L, 2L), rh.statistiek.spellen.toList())
        assertEquals(listOf(2L, 9L), rg.statistiek.spellen.toList())
    }

    @Test
    fun eigenNaamVoorDeAnderVervangtDeProtocolnaam() = runBlocking {
        val (h, g) = LusLijn.paar()
        val bak = mapOf("Ed" to Statistiek(spellen = longArrayOf(8, 1)))
        val hr = launchRes { DuoOpzet.alsGastheer(h, "2.0.0", "Host", bak, partnerNaam = { if (it == "iPhone") "Ed" else it }) }
        val gr = launchRes { DuoOpzet.alsGast(g, "2.2.0", "iPhone") }
        val rh = hr.await() as DuoOpzet.Resultaat.Klaar
        gr.await()
        assertEquals("Ed", rh.naam)
        // De bak van "Ed" is gebruikt (8 spellen), niet een lege bak van "iPhone".
        assertEquals(8L, rh.statistiek.spellen[0])
    }

    @Test
    fun andereProtocolversieWeigert() = runBlocking {
        val (h, g) = LusLijn.paar()
        val hr = launchRes { DuoOpzet.alsGastheer(h, "2.0.0", "Host") }
        g.stuur(DuoBericht.Begroeting(2, "1.0", "Oud"))
        assertTrue(hr.await() is DuoOpzet.Resultaat.Versieverschil)
    }

    private fun <T> kotlinx.coroutines.CoroutineScope.launchRes(blok: suspend () -> T) =
        async(start = CoroutineStart.UNDISPATCHED) { blok() }

    // --- een volledig duo over een lus -----------------------------------------------------------

    /** Probeert de kaarten van de beurt om de beurt; de engine weigert de ongeldige en vraagt opnieuw. */
    private class Bot {
        var poging = 0
        fun kies(v: SpelView): Pair<Teken, Int> {
            val kand = (if (v.aanZet == v.mijnHandPos) v.mijnHand else v.mijnTafel) +
                (if (v.aanZet == v.mijnHandPos) v.mijnTafel else v.mijnHand)
            val k = kand[poging % kand.size]
            poging++
            return k.naam to k.kleur
        }
    }

    @Test
    fun gastheerEnGastSpelenSamenSpellenUit() = runBlocking {
        withTimeout(120_000) {
            val (hl, gl) = LusLijn.paar()
            val spellenGast = intArrayOf(0)
            val gastGezien = ArrayList<SpelView>()
            var hostZet = 0
            var gastZetten = 0
            var verderVanGast = 0

            coroutineScope {
                val hk = DuoKoppeling(hl); val gk = DuoKoppeling(gl)
                hk.start(this); gk.start(this)

                // De gastheer: eigen bot voor Zuid.
                val hostBot = Bot()
                val scherm = object : KjUi {
                    override suspend fun toon(view: SpelView) {}
                    override suspend fun kiesTroef(view: SpelView): Int { hostZet++; return 3 }
                    override suspend fun kiesKaart(view: SpelView): Pair<Teken, Int> { hostZet++; return hostBot.kies(view) }
                    override suspend fun verder(view: SpelView, tekst: String) { kotlinx.coroutines.awaitCancellation() }
                }
                val ui = GastheerUi(scherm, hk, mijnKant = 1, wachtLokaalOpTik = { true })
                val spel = KjSpel(ui, zaad = 5, mijnKant = 1)
                spel.e.s.mens[0] = true; spel.e.s.mens[1] = true
                ui.koppel(spel, this)
                val spelJob: Job = launch { spel.loop() }

                // De gast: leest standen en antwoordt.
                val gast = DuoGast(gk)
                val gastBot = Bot()
                val gastJob = launch {
                    while (true) {
                        val v = gast.volgendeStand() ?: break
                        gastGezien.add(v)
                        when {
                            v.troefVraag && v.benIkAanZet -> { gastZetten++; gast.stuurZet(GastZet(troef = 0)) }
                            v.wachtOpSpeler && v.benIkAanZet -> {
                                gastZetten++
                                val (n, k) = gastBot.kies(v)
                                gast.stuurZet(GastZet(kaart = n, kleur = k))
                            }
                            v.wachtOpVerder -> {
                                gastBot.poging = 0
                                if (v.spelUit) spellenGast[0]++
                                verderVanGast++
                                gast.stuurZet(GastZet(verder = true))
                                if (spellenGast[0] >= 4) break
                            }
                            else -> gastBot.poging = 0
                        }
                    }
                }
                gastJob.join()
                spelJob.cancel(); ui.stop(); hk.stop(); gk.stop()
                this.coroutineContext[Job]!!.children.forEach { it.cancel() }
            }

            assertTrue("de gast kreeg standen", gastGezien.isNotEmpty())
            assertEquals(4, spellenGast[0])
            assertTrue("de gast speelde zelf kaarten", gastZetten >= 4 * 8 / 2 - 4)
            assertTrue("de gastheer speelde ook", hostZet >= 4 * 8 / 2 - 4)
            assertTrue(verderVanGast >= 4)
            // Wat de gast ziet is zijn eigen kant: Noord, met zijn hand open en die van de gastheer dicht.
            for (v in gastGezien) {
                assertEquals(2, v.mijnKant)
                assertTrue(v.handNoord.all { it.open })
                assertTrue(v.handZuid.none { it.open })
            }
            // In de eindstand van een spel staat de uitslag er ook echt in.
            assertTrue(gastGezien.any { it.spelUit && it.puntenZuid + it.puntenNoord > 0 })
            assertNotNull(gastGezien.last().statistiek)
        }
    }
}
