package nl.edsoft.klaverjas

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Zit tussen de partij en de rauwe [DuoLijn]: een eigen luistertaak leest de lijn continu leeg,
 * ook terwijl niemand op een bericht wacht - een STAND of ZET kan op elk moment binnenkomen.
 * Berichten die niemand meteen ophaalt gaan in een wachtrij, in aankomstvolgorde.
 *
 * Er is geen "stuur nummer zoveel opnieuw": elke STAND is een complete momentopname, dus een
 * gemist bericht wordt door het volgende vanzelf ingehaald.
 */
class DuoKoppeling(private val lijn: DuoLijn) {
    private val wachtrij = Channel<DuoBericht>(Channel.UNLIMITED)
    private var luistertaak: Job? = null

    /** True zodra [stop] is aangeroepen. */
    @Volatile var gestopt = false
        private set

    /** Begint met luisteren, in de gegeven scope. Geen effect als dat al loopt. */
    fun start(scope: CoroutineScope) {
        if (luistertaak != null) return
        luistertaak = scope.launch {
            while (isActive) wachtrij.send(lijn.ontvang())
        }
    }

    fun stop() {
        gestopt = true
        luistertaak?.cancel()
        luistertaak = null
        // Wie nog wacht op een bericht krijgt een pols en kan zelf zijn eigen afsluiting doen.
        wachtrij.close()
    }

    suspend fun stuur(bericht: DuoBericht) = lijn.stuur(bericht)

    /** Wacht op het eerstvolgende bericht; na [stop] komt er een [DuoBericht.Pols]. */
    suspend fun volgende(): DuoBericht = wachtrij.receiveCatching().getOrNull() ?: DuoBericht.Pols
}
