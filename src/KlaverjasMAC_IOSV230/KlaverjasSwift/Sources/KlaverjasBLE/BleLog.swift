import Foundation
@preconcurrency import CoreBluetooth

/// Een simpele `print()` met een vast voorvoegsel, om in de Xcode-console te
/// zien wat er onderweg werkelijk gebeurt — vooral belangrijk hier, want
/// CoreBluetooth faalt bij een verkeerde toestand of ontbrekend recht
/// doorgaans stil, zonder foutmelding (zie de aantekening bij `BlePerifeer`).
/// Bewust geen `os.Logger`: die vraagt Console.app of een filter om iets te
/// zien; `print()` staat meteen in het venster waar je toch al naar kijkt
/// tijdens het testen.
///
/// Later, als fase 3 bewezen is, kan dit weer weg of achter een schakelaar —
/// voor nu is zichtbaarheid belangrijker dan stilte.
public enum BleLog {
    public static func zeg(_ tekst: String) {
        print("[BLE] \(tekst)")
    }
}

extension CBManagerState {
    /// `.poweredOn` is de enige staat waarin er iets gebeurt; alle andere zijn
    /// hier de reden dat er "niets" lijkt te gebeuren. `.unsupported` komt
    /// bijvoorbeeld uit de simulator — die heeft geen bluetooth-radio.
    var omschrijving: String {
        switch self {
        case .poweredOn: return "aan"
        case .poweredOff: return "uit — bluetooth staat uit op dit toestel"
        case .unauthorized: return "geen toestemming — recht geweigerd of nog niet gevraagd"
        case .unsupported: return "geen bluetooth — komt dit uit de simulator?"
        case .resetting: return "start opnieuw op"
        case .unknown: return "nog onbekend"
        @unknown default: return "onbekende nieuwe staat (\(rawValue))"
        }
    }
}
