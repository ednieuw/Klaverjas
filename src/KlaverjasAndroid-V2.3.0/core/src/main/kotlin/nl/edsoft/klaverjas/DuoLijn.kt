package nl.edsoft.klaverjas

import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow

/**
 * Eén verbinding naar het andere toestel. De samenspel-logica praat alleen hiertegen, nooit
 * tegen bluetooth zelf: zo is ze met [LusLijn] zonder één toestel te toetsen.
 */
interface DuoLijn {
    /** Verstuurt één bericht; komt terug zodra het bij de andere kant in de wachtrij staat. */
    suspend fun stuur(bericht: DuoBericht)

    /** Wacht op het eerstvolgende bericht dat nog niet opgehaald is. */
    suspend fun ontvang(): DuoBericht
}

/** Waar een verbinding op staat, voor het verbindingsscherm. */
sealed class DuoStatus {
    /** Onderweg, met een tekst voor op het scherm: "Adverteren...", "Zoeken...". */
    data class Bezig(val tekst: String) : DuoStatus()
    object Verbonden : DuoStatus()
    /** De verbinding is er niet gekomen of weggevallen. */
    data class Mislukt(val reden: String) : DuoStatus()
}

/** Een [DuoLijn] met begin, einde en status: wat het verbindingsscherm van een radio nodig heeft. */
interface DuoRadio : DuoLijn {
    suspend fun start()
    suspend fun stop()
    /** Status van de verbinding; één afnemer tegelijk. */
    fun statusStroom(): Flow<DuoStatus>
}

/** Een lus-in-het-geheugen: wat de ene kant stuurt komt bij de andere binnen. [paar] maakt er twee. */
class LusLijn private constructor(
    private val uit: Channel<DuoBericht>,
    private val in_: Channel<DuoBericht>,
) : DuoRadio {
    override suspend fun stuur(bericht: DuoBericht) { uit.send(bericht) }
    override suspend fun ontvang(): DuoBericht = in_.receive()
    override suspend fun start() {}
    override suspend fun stop() {}
    /** Een lus valt nooit weg. */
    override fun statusStroom(): Flow<DuoStatus> = emptyFlow()

    companion object {
        fun paar(): Pair<LusLijn, LusLijn> {
            val a = Channel<DuoBericht>(Channel.UNLIMITED)
            val b = Channel<DuoBericht>(Channel.UNLIMITED)
            return LusLijn(a, b) to LusLijn(b, a)
        }
    }
}
