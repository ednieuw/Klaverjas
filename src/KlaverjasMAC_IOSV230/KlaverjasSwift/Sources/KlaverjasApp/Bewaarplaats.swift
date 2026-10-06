import Foundation
import KlaverjasKit

/// Waar de tellingen blijven staan als het spel dicht gaat.
///
/// Het origineel drukte ze bij het afsluiten af en gooide ze weg; op een telefoon
/// veeg je het spel tien keer per dag omhoog, en dan is een partij naar 1500 nooit
/// af te maken. Ze gaan als JSON in de gebruikersvoorkeuren — een paar honderd
/// bytes, en het werkt op iOS en macOS hetzelfde.
/// Waar de bewaarplaats zijn spullen kwijt kan. In het programma is dat
/// `UserDefaults`; een toets kan er iets in het geheugen voor in de plaats
/// zetten en laat dan niets op schijf achter.
public protocol Sleutelkast {
    func data(forKey sleutel: String) -> Data?
    func set(_ waarde: Any?, forKey sleutel: String)
    func removeObject(forKey sleutel: String)
}

extension UserDefaults: Sleutelkast {}

/// Bewust niet `Sendable`: `UserDefaults` is dat niet, en dit doosje wordt
/// alleen vanaf de hoofdtaak gebruikt — de motor komt er nooit bij.
public struct Bewaarplaats {
    private let sleutel = "klaverjas.statistiek.v1"
    private let sleutelVoorkeuren = "klaverjas.voorkeuren.v1"
    /// Los van `sleutel`: één emmer per samenspel-partner, zodat solo spelen
    /// en samen spelen met verschillende apparaten elkaar niet meer
    /// overschrijven. Zie `leesAlleDuo()`/`schrijfDuo(_:partner:)`.
    private let sleutelDuo = "klaverjas.statistiek.duo.v1"
    private let opslag: Sleutelkast

    public init(opslag: Sleutelkast = UserDefaults.standard) { self.opslag = opslag }

    /// Wat de speler zelf gekozen heeft en de volgende keer terug wil zien.
    ///
    /// Bewust niet demo, open kaart of snel spelen: die horen bij één zitting.
    /// In snel spelen opstarten omdat je dat gisteren aan had staan is geen
    /// prettige verrassing.
    public struct Voorkeuren: Codable, Equatable, Sendable {
        public var zoektZuid: Bool
        public var zoektNoord: Bool
        public var engels: Bool
        /// Speelt deze kant volgens Claude? Gaat voor `zoektZuid`/`zoektNoord`.
        public var claudeZuid: Bool
        public var claudeNoord: Bool

        public init(zoektZuid: Bool, zoektNoord: Bool, engels: Bool,
                    claudeZuid: Bool = false, claudeNoord: Bool = false) {
            self.zoektZuid = zoektZuid
            self.zoektNoord = zoektNoord
            self.engels = engels
            self.claudeZuid = claudeZuid
            self.claudeNoord = claudeNoord
        }

        /// Met de hand geschreven: een bewaard bestand van vóór Claude kent de twee `claude`-velden
        /// niet, en moet gewoon blijven werken in plaats van onleesbaar te worden.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            zoektZuid = try c.decode(Bool.self, forKey: .zoektZuid)
            zoektNoord = try c.decode(Bool.self, forKey: .zoektNoord)
            engels = try c.decode(Bool.self, forKey: .engels)
            claudeZuid = try c.decodeIfPresent(Bool.self, forKey: .claudeZuid) ?? false
            claudeNoord = try c.decodeIfPresent(Bool.self, forKey: .claudeNoord) ?? false
        }
    }

    /// De bewaarde voorkeuren, of niets als er nog nooit iets gekozen is. Dan
    /// beslissen de standaardwaarden: Zuid rekent door, Noord speelt op
    /// vuistregels, en de taal volgt het apparaat.
    public func leesVoorkeuren() -> Voorkeuren? {
        guard let data = opslag.data(forKey: sleutelVoorkeuren) else { return nil }
        return try? JSONDecoder().decode(Voorkeuren.self, from: data)
    }

    public func schrijfVoorkeuren(_ v: Voorkeuren) {
        guard let data = try? JSONEncoder().encode(v) else { return }
        opslag.set(data, forKey: sleutelVoorkeuren)
    }

    /// De bewaarde tellingen, of niets als er nog nooit gespeeld is.
    public func lees() -> Statistiek? {
        guard let data = opslag.data(forKey: sleutel) else { return nil }
        // Een onleesbaar bestand is geen reden om niet te kunnen spelen: dan
        // begint de telling gewoon opnieuw.
        return try? JSONDecoder().decode(Statistiek.self, from: data)
    }

    public func schrijf(_ st: Statistiek) {
        guard let data = try? JSONEncoder().encode(st) else { return }
        opslag.set(data, forKey: sleutel)
    }

    /// Alleen de tellingen; de voorkeuren blijven staan. Wie zijn statistiek
    /// wist, wil niet ook zijn taal kwijt.
    public func wis() {
        opslag.removeObject(forKey: sleutel)
    }

    // ------------------------------------------------- per samenspel-partner

    /// Alle bewaarde duo-tellingen, per partnernaam — altijd in eigen
    /// kant-orde ([0] = ik, [1] = die partner), nooit Zuid/Noord: welk fysiek
    /// apparaat gastheer (dus Zuid) is wisselt per sessie. Leeg als er nog
    /// nooit samen gespeeld is; een onleesbaar bestand levert net als
    /// `lees()` gewoon een lege start op in plaats van een crash.
    public func leesAlleDuo() -> [String: Statistiek] {
        guard let data = opslag.data(forKey: sleutelDuo),
              let alles = try? JSONDecoder().decode([String: Statistiek].self, from: data)
        else { return [:] }
        return alles
    }

    public func leesDuo(partner naam: String) -> Statistiek? {
        leesAlleDuo()[naam]
    }

    /// Eén partner uit de lijst halen; de andere partners en de solo-tellingen blijven staan.
    public func wisDuo(partner naam: String) {
        var alles = leesAlleDuo()
        guard alles.removeValue(forKey: naam) != nil else { return }
        if alles.isEmpty {
            opslag.removeObject(forKey: sleutelDuo)
        } else if let data = try? JSONEncoder().encode(alles) {
            opslag.set(data, forKey: sleutelDuo)
        }
    }

    public func schrijfDuo(_ st: Statistiek, partner naam: String) {
        var alles = leesAlleDuo()
        alles[naam] = st
        guard let data = try? JSONEncoder().encode(alles) else { return }
        opslag.set(data, forKey: sleutelDuo)
    }
}
