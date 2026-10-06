package nl.edsoft.klaverjas.ui

import android.content.Context
import nl.edsoft.klaverjas.Statistiek
import org.json.JSONObject

/**
 * Waar de tellingen en voorkeuren blijven staan als het spel dicht gaat. Het
 * origineel drukte de tellingen bij het afsluiten af en gooide ze weg; op een
 * telefoon veeg je het spel tien keer per dag weg, en dan is een partij naar 1500
 * nooit af te maken. Ze gaan als JSON in SharedPreferences.
 */
class Bewaarplaats(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("klaverjas", Context.MODE_PRIVATE)

    /**
     * Wat de speler zelf gekozen heeft en de volgende keer terug wil zien. Bewust niet
     * demo, open kaart of automatisch doorgaan: die horen bij één zitting.
     */
    /** Speelwijze per kant: 0 = Ednieuw, 1 = Ronlog, 2 = Claude. */
    class Voorkeuren(val stijlZuid: Int, val stijlNoord: Int, val engels: Boolean)

    fun leesVoorkeuren(): Voorkeuren? {
        val tekst = prefs.getString(SLEUTEL_VOORKEUREN, null) ?: return null
        return try {
            val o = JSONObject(tekst)
            // Een bestand van vóór Claude kent alleen de schakelaars zoektZuid/zoektNoord.
            val zuid = o.optInt("stijlZuid", if (o.optBoolean("zoektZuid", true)) 1 else 0)
            val noord = o.optInt("stijlNoord", if (o.optBoolean("zoektNoord", false)) 1 else 0)
            Voorkeuren(zuid.coerceIn(0, 2), noord.coerceIn(0, 2), o.getBoolean("engels"))
        } catch (_: Exception) { null }
    }

    fun schrijfVoorkeuren(v: Voorkeuren) {
        val o = JSONObject()
            .put("stijlZuid", v.stijlZuid).put("stijlNoord", v.stijlNoord)
            .put("zoektZuid", v.stijlZuid == 1).put("zoektNoord", v.stijlNoord == 1)   // voor oudere versies
            .put("engels", v.engels)
        prefs.edit().putString(SLEUTEL_VOORKEUREN, o.toString()).apply()
    }

    /** De bewaarde tellingen, of null als er nog nooit gespeeld is (of het bestand onleesbaar is). */
    fun lees(): Statistiek? = prefs.getString(SLEUTEL_STATISTIEK, null)?.let { Statistiek.uitJson(it) }

    fun schrijf(st: Statistiek) {
        prefs.edit().putString(SLEUTEL_STATISTIEK, st.toJson()).apply()
    }

    /** Alleen de tellingen; de voorkeuren blijven staan. Wie zijn statistiek wist, wil niet ook zijn taal kwijt. */
    fun wis() {
        prefs.edit().remove(SLEUTEL_STATISTIEK).apply()
    }

    /** De naam waaronder deze telefoon bij een partner in de lijst "samen gespeeld" staat; null = zelf niet gekozen. */
    fun leesSpelerNaam(): String? = prefs.getString(SLEUTEL_NAAM, null)
    fun schrijfSpelerNaam(naam: String) { prefs.edit().putString(SLEUTEL_NAAM, naam).apply() }

    /** De laatst gekozen eigen naam voor een partner die zich met een algemene naam ("iPhone") meldt. */
    fun leesAlias(basis: String): String? = prefs.getString("klaverjas.alias.$basis", null)
    fun schrijfAlias(basis: String, alias: String) { prefs.edit().putString("klaverjas.alias.$basis", alias).apply() }

    /** Alle bewaarde samenspel-tellingen, per partnernaam, elk in mijn eigen kant-orde ([0] = ik). */
    fun leesAlleDuo(): Map<String, Statistiek> {
        val tekst = prefs.getString(SLEUTEL_DUO, null) ?: return emptyMap()
        return try {
            val o = JSONObject(tekst)
            val uit = LinkedHashMap<String, Statistiek>()
            for (naam in o.keys()) Statistiek.uitJson(o.getJSONObject(naam).toString())?.let { uit[naam] = it }
            uit
        } catch (_: Exception) { emptyMap() }
    }

    fun schrijfDuo(partner: String, st: Statistiek) {
        val o = JSONObject()
        for ((n, s) in leesAlleDuo()) o.put(n, JSONObject(s.toJson()))
        o.put(partner, JSONObject(st.toJson()))
        prefs.edit().putString(SLEUTEL_DUO, o.toString()).apply()
    }

    fun wisDuo(partner: String) {
        val alles = leesAlleDuo()
        if (partner !in alles) return
        val o = JSONObject()
        for ((n, s) in alles) if (n != partner) o.put(n, JSONObject(s.toJson()))
        prefs.edit().apply { if (o.length() == 0) remove(SLEUTEL_DUO) else putString(SLEUTEL_DUO, o.toString()) }.apply()
    }

    private companion object {
        const val SLEUTEL_NAAM = "klaverjas.spelernaam.v1"
        const val SLEUTEL_DUO = "klaverjas.statistiek.duo.v1"
        const val SLEUTEL_STATISTIEK = "klaverjas.statistiek.v1"
        const val SLEUTEL_VOORKEUREN = "klaverjas.voorkeuren.v1"
    }
}
