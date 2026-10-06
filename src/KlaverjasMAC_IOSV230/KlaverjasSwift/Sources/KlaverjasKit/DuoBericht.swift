/// Eén regel van het samenspel-protocol: ASCII, telkens één regel, zonder
/// vaste lengte — `DuoLijn` regelt het afsluitende regeleinde, `RegelBuffer`
/// de opdeling in bluetooth-pakketjes; dit type kent alleen de inhoud.
///
/// **Ontwerp (na het eerste hardwaregebruik herzien — zie
/// `Referentie/WIJZIGINGEN-Swift.md` en `LEESMIJ.md`):** niet langer losse
/// zetten die bij elkaar opgeteld de stand vormen, maar één architectuur waar
/// de gastheer de enige echte motor draait en na elke wijziging de hele
/// momentopname stuurt (`stand`, zie `DuoStand`) — voor de gast op zíjn
/// scherm, dus met zíjn hand open en de tegenpartij dicht. De gast stuurt op
/// zijn beurt alleen zijn eigen keuze terug (`zet`). Geen controlesom, geen
/// hernummerde zetten, geen "stuur nummer 1.5 opnieuw" meer nodig: een
/// volledige, actuele momentopname is zelfstandig genoeg om een gemist of
/// beschadigd bericht vanzelf te herstellen bij de eerstvolgende.
public enum DuoBericht: Sendable, Equatable {
    /// `KJ 1 <appversie> <naam>` — begroeting, door allebei de kanten gestuurd.
    case begroeting(versie: Int, appversie: String, naam: String)
    /// `JA 1` — de gast is akkoord; hierna stuurt de gastheer de eerste stand.
    case akkoord(versie: Int)
    /// `STAND <base64>` — een volledige, voor de ontvanger geredigeerde
    /// momentopname (`SpelView`, via `DuoStand.codeer`), altijd door de
    /// gastheer gestuurd.
    case stand(json: String)
    /// `ZET <base64>` — de keuze van de gast (troef of kaart, via
    /// `DuoStand.codeer(GastZet)`), als antwoord op een stand waar de gast aan
    /// zet was.
    case zet(json: String)
    /// `STAT <base64>` — vlak na de begroeting door allebei de kanten
    /// gestuurd: de tellingen (`Statistiek`, via `DuoStand.codeer`) die deze
    /// kant zelf al voor déze partner bewaard had, of een lege `Statistiek()`
    /// als die er nog niet was. Zo weet elke kant, vóór het eerste spel, of
    /// de ander verder was — zie `DuoOpzet` en `Statistiek.kantenOmgewisseld`.
    case stat(json: String)
    /// `P` — pols bij stilte.
    case pols

    /// De regel zoals hij over de lijn gaat, zonder regeleinde.
    public var regel: String {
        switch self {
        case .begroeting(let versie, let appversie, let naam):
            return "KJ \(versie) \(appversie) \(naam)"
        case .akkoord(let versie):
            return "JA \(versie)"
        case .stand(let json):
            return "STAND \(json)"
        case .zet(let json):
            return "ZET \(json)"
        case .stat(let json):
            return "STAT \(json)"
        case .pols:
            return "P"
        }
    }

    /// Leest een regel terug. `nil` bij alles wat niet aan de vorm voldoet —
    /// nooit stilzwijgend het dichtstbijzijnde geldige bericht raden.
    public init?(regel: String) {
        let woord = regel.split(separator: " ", maxSplits: 1)
        guard let soort = woord.first else { return nil }

        switch soort {
        case "KJ":
            let d = regel.split(separator: " ", maxSplits: 3)
            guard d.count == 4, let versie = Int(d[1]) else { return nil }
            self = .begroeting(versie: versie, appversie: String(d[2]), naam: String(d[3]))

        case "JA":
            let d = regel.split(separator: " ")
            guard d.count == 2, let versie = Int(d[1]) else { return nil }
            self = .akkoord(versie: versie)

        case "STAND":
            let d = regel.split(separator: " ", maxSplits: 1)
            guard d.count == 2, !d[1].isEmpty else { return nil }
            self = .stand(json: String(d[1]))

        case "ZET":
            let d = regel.split(separator: " ", maxSplits: 1)
            guard d.count == 2, !d[1].isEmpty else { return nil }
            self = .zet(json: String(d[1]))

        case "STAT":
            let d = regel.split(separator: " ", maxSplits: 1)
            guard d.count == 2, !d[1].isEmpty else { return nil }
            self = .stat(json: String(d[1]))

        case "P":
            guard regel == "P" else { return nil }
            self = .pols

        default:
            return nil
        }
    }
}

/// De keuze van de gast, teruggestuurd na een `stand` waar de gast aan zet
/// was — troef bij de troefvraag, anders een kaart.
public struct GastZet: Sendable, Equatable, Codable {
    public var troef: Int?
    public var kaart: Teken?
    public var kleur: Int?
    /// De gast tikt "verder" na een afgelopen slag — mag altijd, ongeacht
    /// wie er aan zet is. Zie `GastheerUi.verder(_:_:)`.
    public var verder: Bool?

    public init(troef: Int) {
        self.troef = troef
    }

    public init(kaart: Teken, kleur: Int) {
        self.kaart = kaart
        self.kleur = kleur
    }

    public init(verder: Bool) {
        self.verder = verder
    }
}
