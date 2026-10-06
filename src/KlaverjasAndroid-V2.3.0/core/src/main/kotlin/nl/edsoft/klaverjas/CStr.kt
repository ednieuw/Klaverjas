package nl.edsoft.klaverjas

/**
 * Eén teken uit de originele C-code: ASCII, precies één byte, net als `char`.
 * In Kotlin is dat gewoon een [Char]; [NUL] is de afsluiter van een C-string.
 */
typealias Teken = Char

const val NUL: Char = '\u0000'

/** De tekens van een letterlijke reeks, voor de rangvolgordes. */
fun String.tekens(): CharArray = toCharArray()

/**
 * Bootst een C-string na: een tekenrij van vaste omvang met een afsluitende NUL.
 * Het origineel leunt zwaar op strlen/strcpy/strcat/strchr over char-arrays.
 *
 * Bewust een class: de code geeft `krtvrij[kleur]` door aan een hulproutine die
 * hem ter plekke aanpast, en verwacht dat de wijziging in de toestand terechtkomt.
 */
class CStr(size: Int) {
    private val buf = CharArray(size) { NUL }

    /** strlen() */
    val len: Int
        get() {
            for (i in buf.indices) if (buf[i] == NUL) return i
            return buf.size
        }

    /** Inhoud tot aan de NUL. */
    val string: String get() = String(buf, 0, len)

    /** De gevulde tekens, zonder de afsluitende NUL. */
    val tekens: CharArray get() = buf.copyOf(len)

    operator fun get(i: Int): Teken = buf[i]
    operator fun set(i: Int, v: Teken) { buf[i] = v }

    /** strcpy(dst, src) */
    fun cpy(src: CharArray) {
        val n = minOf(src.size, buf.size - 1)
        for (i in 0 until n) buf[i] = src[i]
        buf[n] = NUL
    }

    fun cpy(src: CStr) = cpy(src.tekens)
    fun cpy(src: String) = cpy(src.toCharArray())

    /** strcat(dst, src) */
    fun cat(src: CharArray) {
        val l = len
        val n = minOf(src.size, buf.size - 1 - l)
        for (i in 0 until n) buf[l + i] = src[i]
        buf[l + n] = NUL
    }

    fun cat(src: CStr) = cat(src.tekens)
    fun cat(src: String) = cat(src.toCharArray())

    /** Zet 1 teken achteraan (dst[strlen(dst)] = c). */
    fun append(c: Teken) {
        val l = len
        if (l + 1 >= buf.size) return
        buf[l] = c
        buf[l + 1] = NUL
    }

    fun clear() { buf[0] = NUL }

    /**
     * strpos() uit het origineel: 1-gebaseerde positie van x, of 0 als x er niet
     * in staat. De uitkomst wordt in het origineel ook als jaknikker gebruikt.
     */
    fun pos(x: Teken): Int {
        val n = len
        for (i in 0 until n) if (buf[i] == x) return i + 1
        return 0
    }

    companion object {
        fun new2(dim1: Int, size: Int): Array<CStr> = Array(dim1) { CStr(size) }
        fun new3(dim1: Int, dim2: Int, size: Int): Array<Array<CStr>> = Array(dim1) { new2(dim2, size) }

        /** Dezelfde strpos() op een vaste rangvolgorde. */
        fun pos(s: CharArray, x: Teken): Int {
            for (i in s.indices) if (s[i] == x) return i + 1
            return 0
        }
    }
}
