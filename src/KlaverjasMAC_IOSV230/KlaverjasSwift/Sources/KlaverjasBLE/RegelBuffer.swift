import Foundation

/// Deelt één regel van het protocol op in pakketjes voor bluetooth, en plakt
/// binnenkomende pakketjes weer aan elkaar tot volledige regels (B7/B9 uit het
/// bluetooth-plan).
///
/// Bewust niet overgenomen uit BLESerialPro: die chunker deelde op in stukken
/// van tachtig bytes met een pauze van 0,2 seconde ertussen, en ging ervan uit
/// dat één notificatie altijd precies één regel was. Dat laatste klopt hier
/// niet — een notificatie is een stuk van een regel, nooit meer en nooit
/// minder, en de ontvanger plakt ze aan elkaar tot hij het regeleinde ziet.
/// Geen pauze nodig: bluetooth zelf bewaakt de volgorde binnen één verbinding
/// al, dus een pakketje hoeft niet te wachten tot het vorige "aangekomen" is.

/// Splitst één regel (zonder regeleinde) in pakketjes van hooguit
/// `maxPakket` bytes, inclusief het regeleinde dat de ontvanger nodig heeft
/// om te weten waar de regel ophoudt.
public enum RegelPakketten {
    /// Elke regel van het protocol eindigt hiermee — vóór het opdelen in
    /// pakketjes toegevoegd, zodat het regeleinde altijd meegaat, ook als het
    /// toevallig op een pakketgrens valt.
    public static let regelEinde: UInt8 = 0x0A   // '\n'

    public static func verdeel(_ regel: String, maxPakket: Int) -> [Data] {
        precondition(maxPakket > 0, "een pakket van nul bytes deelt een regel nooit op")
        var bytes = Array(regel.utf8)
        bytes.append(regelEinde)

        var pakketten: [Data] = []
        var i = 0
        while i < bytes.count {
            let eind = min(i + maxPakket, bytes.count)
            pakketten.append(Data(bytes[i..<eind]))
            i = eind
        }
        return pakketten
    }
}

/// Plakt binnenkomende pakketjes aan elkaar tot volledige regels. Eén van
/// deze per richting van de verbinding — niet delen tussen twee lijnen, want
/// hij houdt precies bij welk deel van de eerstvolgende regel al binnen is.
public struct RegelBuffer {
    private var opgeslagen: [UInt8] = []

    /// Boven deze lengte zonder regeleinde is er iets goed mis — een
    /// kapotte verbinding die maar bytes blijft sturen, bijvoorbeeld. Dan
    /// wordt de buffer geleegd in plaats van onbeperkt te groeien.
    public static let maxOngeknipt = 4096

    public init() {}

    /// Verwerkt één binnengekomen pakketje en levert alle regels op die
    /// daardoor compleet werden. Normaal gesproken hooguit één; komen er
    /// twee pakketjes binnen voordat de aanroeper de vorige regel kan
    /// verwerken, dan kunnen het er ook meer zijn — of nul, als het pakketje
    /// het regeleinde nog niet bevatte.
    public mutating func neem(_ pakket: Data) -> [String] {
        opgeslagen.append(contentsOf: pakket)

        var regels: [String] = []
        while let idx = opgeslagen.firstIndex(of: RegelPakketten.regelEinde) {
            let stuk = opgeslagen[opgeslagen.startIndex..<idx]
            // Ongeldige UTF-8 wordt overgeslagen, niet als lege regel
            // doorgegeven: een halve emoji op een pakketgrens komt door de
            // opdeling in RegelPakketten nooit voor, dus dit hoort een echte
            // fout te zijn, geen normaal geval.
            if let regel = String(bytes: stuk, encoding: .utf8) {
                regels.append(regel)
            }
            opgeslagen.removeSubrange(opgeslagen.startIndex...idx)
        }

        if opgeslagen.count > Self.maxOngeknipt { opgeslagen.removeAll() }
        return regels
    }
}
