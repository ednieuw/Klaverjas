/// Regelt de begroeting zodra twee toestellen verbonden zijn: een
/// versiecontrole en een verzoening van de bewaarde score. Wie zich
/// openstelde is de gastheer (draait de enige echte motor, altijd Zuid) en
/// wie zocht is de gast (altijd Noord, scherm + invoer); die rolverdeling
/// ligt al vast aan de keuze die de speler zelf in `VerbindScherm` maakte,
/// dus die hoeft hier niet meer over de lijn te gaan. Zodra de gast `JA`
/// stuurt, stuurt de gastheer zijn eerste `STAND` — het huidige spel (nieuw,
/// of hervat na een onderbreking) — en begint het samenspel. Zie
/// `DuoBericht`/`DuoStand`.
///
/// **De score-verzoening (sinds protocolversie 3):** wie gastheer is
/// wisselt soms tussen twee dezelfde apparaten — Ed: "als er gewisseld wordt
/// van master gaat het fout" met een score die alleen bij de gastheer
/// bewaard blijft. Daarom wisselen beide kanten, vlak na de begroeting, hun
/// eigen bewaarde telling voor déze partner uit (`eigenTellingen`, door de
/// aanroeper aangeleverd — meestal `SpelModel.alleBewaardeDuoTellingen()`)
/// en gaan allebei verder met de "verste" van de twee
/// (`StatistiekVerzoening.hoogste`). Zo maakt het niet uit wie er dit keer
/// opensteld: geen van beide apparaten kan hiermee ooit achteruit gaan.
///
/// Puur op `DuoLijn`, dus met `LusLijn` te toetsen zonder één toestel nodig
/// te hebben.
public enum DuoOpzet {
    /// Verhoog dit bij een niet-achterwaarts-compatibele wijziging aan het
    /// protocol. Twee verschillende versies weigeren te beginnen: een subtiel
    /// andere motor tussen twee appversies is erger dan gewoon niet verbinden.
    /// Van 2 naar 3: het nieuwe `STAT`-bericht (score-verzoening) tussen de
    /// begroeting en `JA` in — een oudere kant zou daar nooit op wachten.
    public static let protocolVersie = 3

    public enum Resultaat: Sendable, Equatable {
        /// De begroeting is gelukt: de naam van de andere kant (voor de
        /// per-partner-emmer in `Bewaarplaats`) en de verzoende telling
        /// waarmee de partij moet beginnen.
        case klaar(naam: String, statistiek: Statistiek)
        /// De andere kant praat een ander versienummer van het protocol.
        case versieverschil(andereVersie: Int)
        /// Er kwam iets binnen dat niet paste bij deze stap van de begroeting.
        case onverwacht(regel: String)
    }

    /// De kant die zich openstelde.
    public static func alsGastheer(lijn: DuoLijn, appversie: String, naam: String,
                                    eigenTellingen: [String: Statistiek] = [:]) async -> Resultaat {
        await lijn.stuur(.begroeting(versie: protocolVersie, appversie: appversie, naam: naam))

        let terug = await lijn.ontvang()
        guard case .begroeting(let versie, _, let hunNaam) = terug else {
            return .onverwacht(regel: terug.regel)
        }
        guard versie == protocolVersie else { return .versieverschil(andereVersie: versie) }

        guard let statistiek = await verzoen(lijn: lijn, eigen: eigenTellingen[hunNaam] ?? Statistiek())
        else { return .onverwacht(regel: "STAT") }

        let akkoord = await lijn.ontvang()
        guard case .akkoord = akkoord else { return .onverwacht(regel: akkoord.regel) }

        return .klaar(naam: hunNaam, statistiek: statistiek)
    }

    /// De kant die zocht.
    public static func alsGast(lijn: DuoLijn, appversie: String, naam: String,
                                eigenTellingen: [String: Statistiek] = [:]) async -> Resultaat {
        await lijn.stuur(.begroeting(versie: protocolVersie, appversie: appversie, naam: naam))

        let terug = await lijn.ontvang()
        guard case .begroeting(let versie, _, let hunNaam) = terug else {
            return .onverwacht(regel: terug.regel)
        }
        guard versie == protocolVersie else { return .versieverschil(andereVersie: versie) }

        guard let statistiek = await verzoen(lijn: lijn, eigen: eigenTellingen[hunNaam] ?? Statistiek())
        else { return .onverwacht(regel: "STAT") }

        await lijn.stuur(.akkoord(versie: protocolVersie))
        return .klaar(naam: hunNaam, statistiek: statistiek)
    }

    /// Stuurt `eigen` als `STAT`, wacht op de `STAT` van de ander, en levert
    /// de verzoende telling — al in mijn eigen kant-orde ([0] = ik). Wat
    /// binnenkomt staat in de kant-orde van de ánder, dus die wordt eerst
    /// omgewisseld (`kantenOmgewisseld`) vóór de vergelijking. `nil` als er
    /// iets anders dan `STAT` binnenkomt.
    private static func verzoen(lijn: DuoLijn, eigen: Statistiek) async -> Statistiek? {
        await lijn.stuur(.stat(json: (try? DuoStand.codeer(eigen)) ?? ""))
        let bericht = await lijn.ontvang()
        guard case .stat(let json) = bericht else { return nil }
        let vanPartner = (try? DuoStand.decodeer(json, als: Statistiek.self)) ?? Statistiek()
        return StatistiekVerzoening.hoogste(eigen, vanPartner.kantenOmgewisseld)
    }
}
