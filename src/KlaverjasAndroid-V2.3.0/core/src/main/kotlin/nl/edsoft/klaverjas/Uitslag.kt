package nl.edsoft.klaverjas

/** Wat een slag opleverde. */
data class SlagUitslag(val punten: Int, val roem: Int, val laatsteSlag: Int)

/** Wat een afgesloten spel opleverde, plus of de partij erdoor uit is. */
data class SpelUitslag(
    val tekst: String,
    val puntenZuid: Int,
    val puntenNoord: Int,
    val roemZuid: Int,
    val roemNoord: Int,
    /** De bonus voor alle acht slagen: 100, of 300 bij tegenpit. Nul zonder pit. */
    val pitRoem: Int,
    val tegenpit: Boolean,
    val partijUit: Boolean,
    val partijGewonnenDoorZuid: Boolean,
    val partijGelijkspel: Boolean,
)
