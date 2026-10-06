package nl.edsoft.klaverjas

/**
 * De gast-kant van een samenspel-partij: geen eigen motor, alleen scherm en invoer. Leest
 * standen van de gastheer en stuurt zijn eigen keuzes (troef, kaart, verder) terug.
 */
class DuoGast(private val koppeling: DuoKoppeling) {
    /**
     * Wacht op de eerstvolgende bruikbare STAND; andere of onleesbare berichten worden overgeslagen.
     * Na [DuoKoppeling.stop] levert dit null.
     */
    suspend fun volgendeStand(): SpelView? {
        while (true) {
            val b = koppeling.volgende()
            if (koppeling.gestopt) return null
            if (b !is DuoBericht.Stand) continue
            val v = DuoStand.decodeer(b.json)?.let(::spelViewUitJson) ?: continue
            return v
        }
    }

    suspend fun stuurZet(z: GastZet) {
        koppeling.stuur(DuoBericht.Zet(DuoStand.codeer(z.toJson())))
    }
}
