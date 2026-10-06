package nl.edsoft.klaverjas

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.longOrNull

/**
 * De tellingen die het origineel bij het afsluiten op het scherm zette (KJ.C, aan het
 * eind van main()), nu ook tijdens het spel op te vragen en over een herstart heen
 * bewaard. [0] = Zuid, [1] = Noord - dezelfde volgorde als in de engine.
 *
 * Het JSON-formaat is dat van de Swift-versie (zelfde sleutels), zodat een bewaard
 * bestand uit de ene app ook in de andere te lezen is.
 */
class Statistiek(
    val partijen: LongArray = LongArray(2),       // Gewonnen[]: partijen tot 1500
    val spellen: LongArray = LongArray(2),        // GewonnenTot[]: losse spellen
    val kaartpunten: LongArray = LongArray(2),
    val troefpunten: LongArray = LongArray(2),
    val troefkaarten: LongArray = LongArray(2),
    val roempunten: LongArray = LongArray(2),
    val pit: LongArray = LongArray(2),
    val tegenpit: LongArray = LongArray(2),
    val nat: LongArray = LongArray(2),
    val superroem: LongArray = LongArray(2),      // vier gelijke kaarten
    val totaal: LongArray = LongArray(2),         // stand van de lopende partij
    /** Hoe vaak elke tactiek is toegepast, 0..79 (nummers uit het origineel). */
    val tactiek: LongArray = LongArray(80),
) {
    /** De tactieken die daadwerkelijk gebruikt zijn, aflopend op aantal. */
    val gebruikteTactieken: List<Pair<Int, Long>>
        get() = tactiek.withIndex()
            .filter { it.index > 0 && it.value > 0 }
            .map { it.index to it.value }
            .sortedByDescending { it.second }

    /** Is er al iets te zien? */
    val leeg: Boolean get() = spellen[0] + spellen[1] == 0L

    fun toJson(): String {
        fun a(x: LongArray) = JsonArray(x.map { JsonPrimitive(it) })
        return JsonObject(mapOf(
            "partijen" to a(partijen), "spellen" to a(spellen), "kaartpunten" to a(kaartpunten),
            "troefpunten" to a(troefpunten), "troefkaarten" to a(troefkaarten),
            "roempunten" to a(roempunten), "pit" to a(pit), "tegenpit" to a(tegenpit),
            "nat" to a(nat), "superroem" to a(superroem), "totaal" to a(totaal),
            "tactiek" to a(tactiek),
        )).toString()
    }

    companion object {
        /**
         * Elk veld heeft een standaardwaarde, zodat een bestand waarin later een veld bijkomt
         * of wegvalt niet in zijn geheel onleesbaar wordt - dan zou de speler zijn hele
         * telling kwijt zijn. Een onleesbaar bestand geeft null: dan begint de telling opnieuw.
         */
        fun uitJson(tekst: String): Statistiek? {
            val o = try { Json.parseToJsonElement(tekst) as? JsonObject } catch (_: Exception) { null } ?: return null
            fun lijst(sleutel: String, n: Int): LongArray {
                val e: JsonElement? = o[sleutel]
                val r = LongArray(n)
                if (e is JsonArray) {
                    for (i in 0 until minOf(n, e.size)) r[i] = (e[i] as? JsonPrimitive)?.longOrNull ?: 0L
                } else if (e is JsonPrimitive) {
                    r[0] = e.longOrNull ?: 0L   // uit een versie die de superroem nog niet per kant bijhield
                }
                return r
            }
            return Statistiek(
                lijst("partijen", 2), lijst("spellen", 2), lijst("kaartpunten", 2),
                lijst("troefpunten", 2), lijst("troefkaarten", 2), lijst("roempunten", 2),
                lijst("pit", 2), lijst("tegenpit", 2), lijst("nat", 2), lijst("superroem", 2),
                lijst("totaal", 2), lijst("tactiek", 80),
            )
        }
    }
}

/** Een momentopname van de tellers, veilig mee te geven aan het scherm. */
val KjState.statistiek: Statistiek
    get() = Statistiek(
        longArrayOf(gewonnen[0].toLong(), gewonnen[1].toLong()), gewonnenTot.copyOf(),
        kaartpnt.copyOf(), troefpnt.copyOf(), troefkrt.copyOf(), roempnt.copyOf(),
        pit.copyOf(), tpit.copyOf(), nat.copyOf(), superroem.copyOf(),
        puntenTotaalSpel.copyOf(), tac.copyOf(),
    )

/** Zet bewaarde tellingen terug. Alleen aan te roepen voordat de speelloop begint. */
fun KjState.zetStatistiek(st: Statistiek) {
    gewonnen[0] = st.partijen[0].toInt(); gewonnen[1] = st.partijen[1].toInt()
    st.spellen.copyInto(gewonnenTot); st.kaartpunten.copyInto(kaartpnt)
    st.troefpunten.copyInto(troefpnt); st.troefkaarten.copyInto(troefkrt)
    st.roempunten.copyInto(roempnt); st.pit.copyInto(pit); st.tegenpit.copyInto(tpit)
    st.nat.copyInto(nat); st.superroem.copyInto(superroem)
    st.totaal.copyInto(puntenTotaalSpel); st.tactiek.copyInto(tac)
}

/**
 * De tellingen met de twee kanten omgewisseld: wat een partner in zijn eigen volgorde ([0] = hij)
 * stuurt, staat bij mij in omgekeerde volgorde. `tactiek` blijft staan: dat is geen Zuid/Noord-paar.
 */
val Statistiek.kantenOmgewisseld: Statistiek
    get() {
        fun w(x: LongArray) = longArrayOf(x[1], x[0])
        return Statistiek(
            w(partijen), w(spellen), w(kaartpunten), w(troefpunten), w(troefkaarten), w(roempunten),
            w(pit), w(tegenpit), w(nat), w(superroem), w(totaal), tactiek.copyOf(),
        )
    }

/**
 * Kiest van twee tellingen die al in hetzelfde kant-stelsel staan ([0] = ikzelf) de "verste":
 * zo kan geen van beide toestellen achteruit gaan als de rollen gastheer/gast wisselen.
 * `totaal` valt terug naar nul als een partij de 1500 haalt, dus telt het alleen als laatste.
 */
object StatistiekVerzoening {
    private fun grootte(st: Statistiek) = Triple(
        st.spellen[0] + st.spellen[1], st.partijen[0] + st.partijen[1], st.totaal[0] + st.totaal[1])

    fun hoogste(a: Statistiek, b: Statistiek): Statistiek {
        val x = grootte(a); val y = grootte(b)
        val aVerder = when {
            x.first != y.first -> x.first > y.first
            x.second != y.second -> x.second > y.second
            else -> x.third >= y.third
        }
        return if (aVerder) a else b
    }
}
