package nl.edsoft.klaverjas

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.longOrNull

/**
 * De JSON van een [SpelView] zoals de Swift-app die verstuurt en verwacht. Let op: de Swift-kant
 * (synthesized Codable) eist álle sleutels, dus hier worden ze ook allemaal geschreven. Lezen is
 * juist ruimhartig: ontbrekende velden houden hun standaardwaarde.
 */
fun SpelView.toJson(): JsonObject {
    fun kaart(k: KaartView) = JsonObject(mapOf(
        "index" to JsonPrimitive(k.index), "naam" to tekenJson(k.naam), "kleur" to JsonPrimitive(k.kleur),
        "open" to JsonPrimitive(k.open), "klikbaar" to JsonPrimitive(k.klikbaar), "plek" to JsonPrimitive(k.plek)))
    fun kaarten(l: List<KaartView>) = JsonArray(l.map(::kaart))
    fun slagen(l: List<SlagView>) = JsonArray(l.map {
        JsonObject(mapOf("kleur" to JsonPrimitive(it.kleur), "naam" to tekenJson(it.naam),
            "speler" to JsonPrimitive(it.speler), "tactiek" to JsonPrimitive(it.tactiek)))
    })
    fun bools(b: BooleanArray) = JsonArray(b.map { JsonPrimitive(it) })
    return JsonObject(mapOf(
        "handZuid" to kaarten(handZuid), "handNoord" to kaarten(handNoord),
        "tafelZuid" to kaarten(tafelZuid), "tafelNoord" to kaarten(tafelNoord),
        "dichtZuid" to kaarten(dichtZuid), "dichtNoord" to kaarten(dichtNoord),
        "onderZuid" to bools(onderZuid), "onderNoord" to bools(onderNoord),
        "slag" to slagen(slag), "vorigeSlag" to slagen(vorigeSlag),
        "troef" to JsonPrimitive(troef), "troefmaker" to JsonPrimitive(troefmaker),
        "slagNr" to JsonPrimitive(slagNr), "aanZet" to JsonPrimitive(aanZet),
        "wachtOpSpeler" to JsonPrimitive(wachtOpSpeler), "troefVraag" to JsonPrimitive(troefVraag),
        "wachtOpVerder" to JsonPrimitive(wachtOpVerder),
        "puntenZuid" to JsonPrimitive(puntenZuid), "puntenNoord" to JsonPrimitive(puntenNoord),
        "roemZuid" to JsonPrimitive(roemZuid), "roemNoord" to JsonPrimitive(roemNoord),
        "totaalZuid" to JsonPrimitive(totaalZuid), "totaalNoord" to JsonPrimitive(totaalNoord),
        "partijenZuid" to JsonPrimitive(partijenZuid), "partijenNoord" to JsonPrimitive(partijenNoord),
        "mijnKant" to JsonPrimitive(mijnKant),
        "status" to JsonPrimitive(status), "melding" to JsonPrimitive(melding),
        "spelUit" to JsonPrimitive(spelUit), "partijUit" to JsonPrimitive(partijUit),
        "partijGewonnenDoorZuid" to JsonPrimitive(partijGewonnenDoorZuid),
        "partijGelijkspel" to JsonPrimitive(partijGelijkspel),
        "statistiek" to kotlinx.serialization.json.Json.parseToJsonElement(statistiek.toJson()),
        "zoekt" to bools(zoekt), "claude" to bools(claude),
    ))
}

/** Null als het geen JSON-object is; verder worden ontbrekende velden genegeerd. */
fun spelViewUitJson(e: JsonElement): SpelView? {
    val o = e as? JsonObject ?: return null
    fun int(n: String, d: Int) = (o[n] as? JsonPrimitive)?.intOrNull ?: d
    fun bool(n: String, d: Boolean = false) = (o[n] as? JsonPrimitive)?.booleanOrNull ?: d
    fun tekst(n: String) = (o[n] as? JsonPrimitive)?.takeIf { it.isString }?.content ?: ""
    fun kaart(x: JsonElement): KaartView? {
        val k = x as? JsonObject ?: return null
        return KaartView().also {
            it.index = (k["index"] as? JsonPrimitive)?.intOrNull ?: 0
            it.naam = k["naam"]?.let(::tekenUitJson) ?: NUL
            it.kleur = (k["kleur"] as? JsonPrimitive)?.intOrNull ?: 0
            it.open = (k["open"] as? JsonPrimitive)?.booleanOrNull ?: false
            it.klikbaar = (k["klikbaar"] as? JsonPrimitive)?.booleanOrNull ?: false
            it.plek = (k["plek"] as? JsonPrimitive)?.intOrNull ?: 0
        }
    }
    fun kaarten(n: String, naar: MutableList<KaartView>) {
        (o[n] as? JsonArray)?.forEach { x -> kaart(x)?.let(naar::add) }
    }
    fun slagen(n: String): List<SlagView> = (o[n] as? JsonArray)?.mapNotNull { x ->
        val s = x as? JsonObject ?: return@mapNotNull null
        SlagView(
            (s["kleur"] as? JsonPrimitive)?.intOrNull ?: 0,
            s["naam"]?.let(::tekenUitJson) ?: NUL,
            (s["speler"] as? JsonPrimitive)?.intOrNull ?: 0,
            (s["tactiek"] as? JsonPrimitive)?.intOrNull ?: 0)
    } ?: emptyList()
    fun bools(n: String, naar: BooleanArray) {
        (o[n] as? JsonArray)?.forEachIndexed { i, x ->
            if (i < naar.size) naar[i] = (x as? JsonPrimitive)?.booleanOrNull ?: false
        }
    }

    return SpelView().also { v ->
        kaarten("handZuid", v.handZuid); kaarten("handNoord", v.handNoord)
        kaarten("tafelZuid", v.tafelZuid); kaarten("tafelNoord", v.tafelNoord)
        kaarten("dichtZuid", v.dichtZuid); kaarten("dichtNoord", v.dichtNoord)
        bools("onderZuid", v.onderZuid); bools("onderNoord", v.onderNoord)
        v.slag = slagen("slag"); v.vorigeSlag = slagen("vorigeSlag")
        v.troef = int("troef", 999); v.troefmaker = int("troefmaker", 0)
        v.slagNr = int("slagNr", 0); v.aanZet = int("aanZet", 0)
        v.wachtOpSpeler = bool("wachtOpSpeler"); v.troefVraag = bool("troefVraag")
        v.wachtOpVerder = bool("wachtOpVerder")
        v.puntenZuid = int("puntenZuid", 0); v.puntenNoord = int("puntenNoord", 0)
        v.roemZuid = int("roemZuid", 0); v.roemNoord = int("roemNoord", 0)
        v.totaalZuid = (o["totaalZuid"] as? JsonPrimitive)?.longOrNull ?: 0L
        v.totaalNoord = (o["totaalNoord"] as? JsonPrimitive)?.longOrNull ?: 0L
        v.partijenZuid = int("partijenZuid", 0); v.partijenNoord = int("partijenNoord", 0)
        v.mijnKant = int("mijnKant", 1)
        v.status = tekst("status"); v.melding = tekst("melding")
        v.spelUit = bool("spelUit"); v.partijUit = bool("partijUit")
        v.partijGewonnenDoorZuid = bool("partijGewonnenDoorZuid")
        v.partijGelijkspel = bool("partijGelijkspel")
        o["statistiek"]?.let { s -> Statistiek.uitJson(s.toString())?.let { v.statistiek = it } }
        bools("zoekt", v.zoekt); bools("claude", v.claude)
    }
}
