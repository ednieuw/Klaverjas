package nl.edsoft.klaverjas

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.booleanOrNull

/**
 * Eén regel van het samenspel-protocol (zelfde als in de Swift-app): ASCII, telkens één regel.
 * [DuoLijn] regelt het afsluitende regeleinde, [RegelBuffer] de opdeling in bluetooth-pakketjes;
 * dit type kent alleen de inhoud.
 *
 * De gastheer draait de enige echte motor en stuurt na elke wijziging de hele momentopname
 * ([Stand]), al ingericht voor het scherm van de gast. De gast stuurt alleen zijn eigen keuze
 * terug ([Zet]).
 */
sealed class DuoBericht {
    /** `KJ 1 <appversie> <naam>` - begroeting, door allebei de kanten gestuurd. */
    data class Begroeting(val versie: Int, val appversie: String, val naam: String) : DuoBericht()
    /** `JA 1` - de gast is akkoord; hierna stuurt de gastheer de eerste stand. */
    data class Akkoord(val versie: Int) : DuoBericht()
    /** `STAND <base64>` - een volledige, voor de ontvanger geredigeerde momentopname. */
    data class Stand(val json: String) : DuoBericht()
    /** `ZET <base64>` - de keuze van de gast (troef, kaart of verder). */
    data class Zet(val json: String) : DuoBericht()
    /** `STAT <base64>` - de tellingen die deze kant voor deze partner al had (of een lege). */
    data class Stat(val json: String) : DuoBericht()
    /** `P` - pols bij stilte. */
    object Pols : DuoBericht() { override fun toString() = "Pols" }

    /** De regel zoals hij over de lijn gaat, zonder regeleinde. */
    val regel: String
        get() = when (this) {
            is Begroeting -> "KJ $versie $appversie $naam"
            is Akkoord -> "JA $versie"
            is Stand -> "STAND $json"
            is Zet -> "ZET $json"
            is Stat -> "STAT $json"
            Pols -> "P"
        }

    companion object {
        /** Zoals Swift `split(separator: " ", maxSplits:)`: lege stukken tussen spaties vervallen. */
        private fun splits(regel: String, maxStukken: Int): List<String> {
            val uit = ArrayList<String>()
            var i = 0
            val n = regel.length
            while (i < n) {
                while (i < n && regel[i] == ' ') i++
                if (i >= n) break
                if (uit.size == maxStukken - 1) { uit.add(regel.substring(i)); return uit }
                val begin = i
                while (i < n && regel[i] != ' ') i++
                uit.add(regel.substring(begin, i))
            }
            return uit
        }

        /** Leest een regel terug; null bij alles wat niet aan de vorm voldoet. */
        fun uitRegel(regel: String): DuoBericht? {
            val kop = splits(regel, 2).firstOrNull() ?: return null
            return when (kop) {
                "KJ" -> {
                    val d = splits(regel, 4)
                    val versie = d.getOrNull(1)?.toIntOrNull()
                    if (d.size != 4 || versie == null) null else Begroeting(versie, d[2], d[3])
                }
                "JA" -> {
                    val d = splits(regel, Int.MAX_VALUE)
                    val versie = d.getOrNull(1)?.toIntOrNull()
                    if (d.size != 2 || versie == null) null else Akkoord(versie)
                }
                "STAND", "ZET", "STAT" -> {
                    val d = splits(regel, 2)
                    if (d.size != 2 || d[1].isEmpty()) null
                    else when (kop) { "STAND" -> Stand(d[1]); "ZET" -> Zet(d[1]); else -> Stat(d[1]) }
                }
                "P" -> if (regel == "P") Pols else null
                else -> null
            }
        }
    }
}

/**
 * De keuze van de gast, teruggestuurd na een stand waar de gast aan zet was: troef bij de
 * troefvraag, anders een kaart. [verder] mag altijd, ongeacht wie er aan zet is.
 */
data class GastZet(
    val troef: Int? = null,
    val kaart: Teken? = null,
    val kleur: Int? = null,
    val verder: Boolean? = null,
) {
    /** Zelfde JSON als Swift `Codable`: alleen de gezette velden, een Teken als `{"raw":65}`. */
    fun toJson(): JsonObject {
        val m = LinkedHashMap<String, JsonElement>()
        if (troef != null) m["troef"] = JsonPrimitive(troef)
        if (kaart != null) m["kaart"] = tekenJson(kaart)
        if (kleur != null) m["kleur"] = JsonPrimitive(kleur)
        if (verder != null) m["verder"] = JsonPrimitive(verder)
        return JsonObject(m)
    }

    companion object {
        fun uitJson(e: JsonElement): GastZet? {
            val o = e as? JsonObject ?: return null
            return GastZet(
                troef = (o["troef"] as? JsonPrimitive)?.intOrNull,
                kaart = o["kaart"]?.let { tekenUitJson(it) },
                kleur = (o["kleur"] as? JsonPrimitive)?.intOrNull,
                verder = (o["verder"] as? JsonPrimitive)?.booleanOrNull,
            )
        }
    }
}

/** Een [Teken] gaat over de lijn als `{"raw":65}` (Swift: struct met één UInt8). */
internal fun tekenJson(t: Teken): JsonElement = JsonObject(mapOf("raw" to JsonPrimitive(t.code)))

internal fun tekenUitJson(e: JsonElement): Teken? {
    val n = when (e) {
        is JsonObject -> (e["raw"] as? JsonPrimitive)?.intOrNull
        is JsonPrimitive -> e.intOrNull
        else -> null
    } ?: return null
    return n.toChar()
}
