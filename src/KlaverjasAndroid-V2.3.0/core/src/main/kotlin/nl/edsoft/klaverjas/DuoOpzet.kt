package nl.edsoft.klaverjas

import kotlinx.serialization.json.JsonElement

/**
 * Regelt de begroeting zodra twee toestellen verbonden zijn: een versiecontrole en een
 * verzoening van de bewaarde score. Wie zich openstelde is de gastheer (draait de enige echte
 * motor, altijd Zuid), wie zocht is de gast (altijd Noord, scherm + invoer). Zodra de gast
 * `JA` stuurt, stuurt de gastheer zijn eerste STAND.
 *
 * Score-verzoening (protocolversie 3): beide kanten wisselen na de begroeting hun bewaarde
 * telling voor déze partner uit en gaan verder met de "verste" ([StatistiekVerzoening]); zo kan
 * geen toestel achteruit gaan als de rollen wisselen.
 */
object DuoOpzet {
    /** Verhoog dit bij een niet-achterwaarts-compatibele wijziging. Twee versies weigeren te beginnen. */
    const val PROTOCOL_VERSIE = 3

    sealed class Resultaat {
        /** Gelukt: de naam van de ander en de verzoende telling om mee te beginnen. */
        data class Klaar(val naam: String, val statistiek: Statistiek) : Resultaat()
        data class Versieverschil(val andereVersie: Int) : Resultaat()
        data class Onverwacht(val regel: String) : Resultaat()
    }

    suspend fun alsGastheer(lijn: DuoLijn, appversie: String, naam: String,
                            eigenTellingen: Map<String, Statistiek> = emptyMap(),
                            /** Mag de naam van de ander vervangen (bv. door een eigen keuze), vóór de tellingen worden vergeleken. */
                            partnerNaam: suspend (String) -> String = { it }): Resultaat {
        lijn.stuur(DuoBericht.Begroeting(PROTOCOL_VERSIE, appversie, naam))

        val terug = lijn.ontvang()
        if (terug !is DuoBericht.Begroeting) return Resultaat.Onverwacht(terug.regel)
        if (terug.versie != PROTOCOL_VERSIE) return Resultaat.Versieverschil(terug.versie)

        val hunNaam = partnerNaam(terug.naam)
        val statistiek = verzoen(lijn, eigenTellingen[hunNaam] ?: Statistiek())
            ?: return Resultaat.Onverwacht("STAT")

        val akkoord = lijn.ontvang()
        if (akkoord !is DuoBericht.Akkoord) return Resultaat.Onverwacht(akkoord.regel)
        return Resultaat.Klaar(hunNaam, statistiek)
    }

    suspend fun alsGast(lijn: DuoLijn, appversie: String, naam: String,
                        eigenTellingen: Map<String, Statistiek> = emptyMap(),
                        /** Mag de naam van de ander vervangen (bv. door een eigen keuze), vóór de tellingen worden vergeleken. */
                        partnerNaam: suspend (String) -> String = { it }): Resultaat {
        lijn.stuur(DuoBericht.Begroeting(PROTOCOL_VERSIE, appversie, naam))

        val terug = lijn.ontvang()
        if (terug !is DuoBericht.Begroeting) return Resultaat.Onverwacht(terug.regel)
        if (terug.versie != PROTOCOL_VERSIE) return Resultaat.Versieverschil(terug.versie)

        val hunNaam = partnerNaam(terug.naam)
        val statistiek = verzoen(lijn, eigenTellingen[hunNaam] ?: Statistiek())
            ?: return Resultaat.Onverwacht("STAT")

        lijn.stuur(DuoBericht.Akkoord(PROTOCOL_VERSIE))
        return Resultaat.Klaar(hunNaam, statistiek)
    }

    /**
     * Stuurt [eigen] als STAT, wacht op de STAT van de ander en levert de verzoende telling in mijn
     * eigen kant-orde ([0] = ik). Wat binnenkomt staat in de orde van de ander en wordt eerst omgewisseld.
     */
    private suspend fun verzoen(lijn: DuoLijn, eigen: Statistiek): Statistiek? {
        lijn.stuur(DuoBericht.Stat(DuoStand.codeer(statistiekJson(eigen))))
        val bericht = lijn.ontvang()
        if (bericht !is DuoBericht.Stat) return null
        val vanPartner = DuoStand.decodeer(bericht.json)?.let { Statistiek.uitJson(it.toString()) } ?: Statistiek()
        return StatistiekVerzoening.hoogste(eigen, vanPartner.kantenOmgewisseld)
    }

    private fun statistiekJson(st: Statistiek): JsonElement =
        kotlinx.serialization.json.Json.parseToJsonElement(st.toJson())
}
