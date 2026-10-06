package nl.edsoft.klaverjas

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import java.io.ByteArrayOutputStream
import java.util.Base64
import java.util.zip.Deflater
import java.util.zip.Inflater

/**
 * Codeert een JSON-waarde voor over de lijn: JSON-tekst, rauw deflate (zonder zlib-kop of
 * controlesom, zoals Apple's COMPRESSION_ZLIB), daarna base64 - één woord zonder spaties of
 * regeleinden, dus altijd één regel voor [DuoLijn]/[RegelBuffer].
 */
object DuoStand {
    private const val MAX_UIT = 1 shl 20

    fun codeer(json: JsonElement): String {
        val bron = json.toString().toByteArray(Charsets.UTF_8)
        val d = Deflater(Deflater.DEFAULT_COMPRESSION, true)
        try {
            d.setInput(bron); d.finish()
            val uit = ByteArrayOutputStream()
            val buf = ByteArray(4096)
            while (!d.finished()) { val n = d.deflate(buf); uit.write(buf, 0, n) }
            return Base64.getEncoder().encodeToString(uit.toByteArray())
        } finally { d.end() }
    }

    /** Null bij alles wat geen geldige, gecomprimeerde JSON is. */
    fun decodeer(tekst: String): JsonElement? {
        val bron = try { Base64.getDecoder().decode(tekst) } catch (_: IllegalArgumentException) { return null }
        val i = Inflater(true)
        try {
            i.setInput(bron)
            val uit = ByteArrayOutputStream()
            val buf = ByteArray(4096)
            while (!i.finished()) {
                val n = i.inflate(buf)
                if (n == 0 && (i.needsInput() || i.needsDictionary())) break
                uit.write(buf, 0, n)
                if (uit.size() > MAX_UIT) return null
            }
            if (!i.finished()) return null
            return try { Json.parseToJsonElement(uit.toString(Charsets.UTF_8)) } catch (_: Exception) { null }
        } catch (_: java.util.zip.DataFormatException) {
            return null
        } finally { i.end() }
    }
}
