import Foundation
import Testing
@testable import KlaverjasKit

/// Het ijkbestand `spoor-csharp.txt` is met de C#-engine gemaakt: 200 spellen
/// met zaad 1, 6601 regels. Levert de Swift-engine bij hetzelfde zaad exact
/// dit bestand op, dan speelt hij aantoonbaar dezelfde tactiek als het
/// origineel uit 1994. De eerste afwijkende regel wijst de slag en de kaart aan.
struct SpoorTests {
    static func ijkbestand() throws -> [String] {
        let url = try #require(Bundle.module.url(forResource: "spoor-csharp", withExtension: "txt"))
        let tekst = try String(contentsOf: url, encoding: .utf8)
        // Het bestand komt van Windows en heeft CRLF-regeleindes. In Swift is
        // "\r\n" één Character, dus splitsen op "\n" levert niets op; splitsen
        // op "is dit een regeleinde" werkt wel, en meteen voor beide soorten.
        return tekst.split(whereSeparator: \.isNewline).map(String.init)
    }

    @Test("De Swift-engine levert regel voor regel hetzelfde spoor als de C#-engine")
    func spoorIsGelijk() throws {
        let verwacht = try Self.ijkbestand()
        let gekregen = Spoor.genereer(spellen: 200, zaad: 1)

        // Eerst de eerste afwijking aanwijzen: dat zegt meer dan "6601 != 6603".
        for i in 0..<min(verwacht.count, gekregen.count) where verwacht[i] != gekregen[i] {
            let omgeving = (max(0, i - 2)..<i).map { "    \($0 + 1): \(verwacht[$0])" }.joined(separator: "\n")
            Issue.record("""
                Eerste afwijking op regel \(i + 1):
                \(omgeving)
                  C#   : \(verwacht[i])
                  Swift: \(gekregen[i])
                """)
            return
        }

        #expect(gekregen.count == verwacht.count,
                "Even ver gelijk, maar niet even lang: C# \(verwacht.count) regels, Swift \(gekregen.count).")
    }

    @Test("Het ijkbestand is het verwachte bestand")
    func ijkbestandIsCompleet() throws {
        let verwacht = try Self.ijkbestand()
        #expect(verwacht.count == 6601)
        #expect(verwacht[0] == "# klaverjas spoor; spellen=200; zaad=1")
    }
}
