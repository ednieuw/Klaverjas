package nl.edsoft.klaverjas

/**
 * Een piepkleine, volledig vastgelegde toevalsgenerator. Bewust niet die van het
 * systeem: bij hetzelfde startgetal moet elk platform exact dezelfde spellen
 * opleveren (het ijkspoor hangt eraan). Letterlijk de reeks uit Toevalsreeks.swift.
 */
class Toevalsreeks(zaad: Long) {
    // UInt32 in een Long; elke bewerking wordt met 0xFFFFFFFF afgekapt.
    private var stand: Long = if (zaad and MASK == 0L) 1L else zaad and MASK

    /**
     * Een getal 0 <= uitkomst < grens, en 0 als grens niet positief is - hetzelfde
     * gedrag als random() van Borland, dat met een vermenigvuldiging schaalde.
     */
    fun volgende(grens: Int): Int {
        stand = (stand * 1664525L + 1013904223L) and MASK
        if (grens <= 0) return 0
        return ((stand * grens.toLong()) ushr 32).toInt()
    }

    private companion object {
        const val MASK = 0xFFFFFFFFL
    }
}
