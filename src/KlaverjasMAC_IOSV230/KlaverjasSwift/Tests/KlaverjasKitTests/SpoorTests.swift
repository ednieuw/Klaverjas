import Foundation
import Testing
@testable import KlaverjasKit

/// Het ijkbestand: 200 spellen met zaad 1, 6601 regels, per gespeelde kaart één
/// regel. Levert de motor bij hetzelfde zaad exact dit bestand op, dan is er
/// niets aan zijn gedrag veranderd. De eerste afwijkende regel wijst de slag en
/// de kaart aan.
///
/// **Er zijn twee ijkbestanden.**
///
/// * `spoor-csharp.txt` komt van de C#-versie en hoort bij versie 1.0. Dat
///   bestand bewees dat de omzetting van C# naar Swift getrouw was.
/// * `spoor-v11.txt` hoort bij versie 1.1, waarin twee gebreken uit 1994 zijn
///   rechtgezet: de troefkeuze van Noord (punt A11) en het schudden (punt A13).
///   Daardoor speelt de motor anders en is `spoor-csharp.txt` niet meer na te
///   spelen. Dit is het bestand waar de proef nu op let.
///
/// Zolang Windows die twee reparaties nog niet heeft, is er geen kruiscontrole
/// tussen de twee talen. **`spoor-v11.txt` is het doel dat de C#-versie straks
/// moet halen**; komt hij er regel voor regel mee overeen, dan lopen ze weer
/// gelijk. Tot die tijd bewaakt deze proef alleen dat de Swift-motor niet
/// ongemerkt van gedrag verandert.
struct SpoorTests {
    static func ijkbestand() throws -> [String] {
        let url = try #require(Bundle.module.url(forResource: "spoor-v11", withExtension: "txt"))
        let tekst = try String(contentsOf: url, encoding: .utf8)
        // Het bestand komt van Windows en heeft CRLF-regeleindes. In Swift is
        // "\r\n" één Character, dus splitsen op "\n" levert niets op; splitsen
        // op "is dit een regeleinde" werkt wel, en meteen voor beide soorten.
        return tekst.split(whereSeparator: \.isNewline).map(String.init)
    }

    @Test("De motor levert regel voor regel het ijkspoor van versie 1.1")
    func spoorIsGelijk() throws {
        let verwacht = try Self.ijkbestand()
        let gekregen = Spoor.genereer(spellen: 200, zaad: 1)

        // Eerst de eerste afwijking aanwijzen: dat zegt meer dan "6601 != 6603".
        for i in 0..<min(verwacht.count, gekregen.count) where verwacht[i] != gekregen[i] {
            let omgeving = (max(0, i - 2)..<i).map { "    \($0 + 1): \(verwacht[$0])" }.joined(separator: "\n")
            Issue.record("""
                Eerste afwijking op regel \(i + 1):
                \(omgeving)
                  ijkbestand: \(verwacht[i])
                  motor     : \(gekregen[i])
                """)
            return
        }

        #expect(gekregen.count == verwacht.count,
                "Even ver gelijk, maar niet even lang: ijkbestand \(verwacht.count) regels, motor \(gekregen.count).")
    }

    @Test("Het ijkbestand is het verwachte bestand")
    func ijkbestandIsCompleet() throws {
        let verwacht = try Self.ijkbestand()
        #expect(verwacht.count == 6601)
        #expect(verwacht[0] == "# klaverjas spoor; spellen=200; zaad=1")
    }
}
