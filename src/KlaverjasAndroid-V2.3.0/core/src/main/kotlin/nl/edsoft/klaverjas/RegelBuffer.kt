package nl.edsoft.klaverjas

/** Deelt één regel in pakketjes voor bluetooth en plakt binnenkomende pakketjes weer aan elkaar. */
object RegelPakketten {
    /** Elke regel eindigt hiermee; het gaat altijd mee, ook als het op een pakketgrens valt. */
    const val REGEL_EINDE: Byte = 0x0A

    fun verdeel(regel: String, maxPakket: Int): List<ByteArray> {
        require(maxPakket > 0) { "een pakket van nul bytes deelt een regel nooit op" }
        val bytes = regel.toByteArray(Charsets.UTF_8) + REGEL_EINDE
        val uit = ArrayList<ByteArray>()
        var i = 0
        while (i < bytes.size) {
            val eind = minOf(i + maxPakket, bytes.size)
            uit.add(bytes.copyOfRange(i, eind))
            i = eind
        }
        return uit
    }
}

/** Eén per richting van de verbinding; houdt bij welk deel van de eerstvolgende regel al binnen is. */
class RegelBuffer {
    private var opgeslagen = ByteArray(0)

    /** Verwerkt een pakketje en levert de regels op die daardoor compleet werden (mogelijk geen). */
    fun neem(pakket: ByteArray): List<String> {
        opgeslagen += pakket
        val regels = ArrayList<String>()
        var begin = 0
        for (i in opgeslagen.indices) {
            if (opgeslagen[i] == RegelPakketten.REGEL_EINDE) {
                regels.add(String(opgeslagen, begin, i - begin, Charsets.UTF_8))
                begin = i + 1
            }
        }
        opgeslagen = if (begin == 0) opgeslagen else opgeslagen.copyOfRange(begin, opgeslagen.size)
        // Zonder regeleinde boven deze lengte is er iets goed mis: leegmaken in plaats van groeien.
        if (opgeslagen.size > MAX_ONGEKNIPT) opgeslagen = ByteArray(0)
        return regels
    }

    companion object { const val MAX_ONGEKNIPT = 16384 }
}
