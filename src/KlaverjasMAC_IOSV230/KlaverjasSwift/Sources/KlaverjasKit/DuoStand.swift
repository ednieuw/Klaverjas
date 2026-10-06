import Foundation
import Compression

/// Codeert een `SpelView` (of elk ander `Codable`-type) voor over de lijn:
/// JSON, daarna zlib-gecomprimeerd, daarna base64 — één woord, geen spaties
/// of regeleinden erin, dus altijd één regel voor `DuoLijn`/`RegelBuffer`.
///
/// Waarom een struct heen en weer sturen in plaats van losse zetten (B2, de
/// eerste opzet van dit protocol): een hele momentopname per kaart is een
/// zelfstandig, compleet bericht. Gaat er ergens onderweg één verloren of
/// beschadigd, dan herstelt de eerstvolgende gewoon alles — in tegenstelling
/// tot een groeiende reeks kleine zetten, waar één gemiste regel de kant die
/// hem miste voorgoed laat achterlopen tot er expliciet om herhaling wordt
/// gevraagd. Comprimeren houdt de regel ondanks dat kort genoeg voor de kleine
/// BLE-pakketten, ook al is de inhoud (32 kaarten × een paar velden) een stuk
/// groter dan de oude "T"/"K"-regels.
public enum DuoStand {
    public enum Fout: Error { case comprimeren, decomprimeren, decoderen }

    public static func codeer<T: Encodable>(_ waarde: T) throws -> String {
        let json = try JSONEncoder().encode(waarde)
        let gecomprimeerd = try comprimeer(json)
        return gecomprimeerd.base64EncodedString()
    }

    public static func decodeer<T: Decodable>(_ tekst: String, als: T.Type) throws -> T {
        guard let gecomprimeerd = Data(base64Encoded: tekst) else { throw Fout.decoderen }
        let json = try decomprimeer(gecomprimeerd)
        return try JSONDecoder().decode(T.self, from: json)
    }

    // ---------------------------------------------------------- zlib

    private static func comprimeer(_ bron: Data) throws -> Data {
        // Uitvoerbuffer met wat marge: gecomprimeerde data kan bij toeval iets
        // groter uitvallen dan de bron (bijvoorbeeld bij hele korte berichten).
        let capaciteit = max(64, bron.count + bron.count / 2 + 64)
        var uitvoer = [UInt8](repeating: 0, count: capaciteit)

        let geschreven = uitvoer.withUnsafeMutableBufferPointer { uitBuf -> Int in
            bron.withUnsafeBytes { bronBuf -> Int in
                compression_encode_buffer(uitBuf.baseAddress!, capaciteit,
                                          bronBuf.bindMemory(to: UInt8.self).baseAddress!,
                                          bron.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard geschreven > 0 else { throw Fout.comprimeren }
        return Data(uitvoer.prefix(geschreven))
    }

    private static func decomprimeer(_ bron: Data) throws -> Data {
        // De ontvanger kent de originele grootte niet vooraf; een JSON-momentopname
        // van dit spel is nooit in de buurt van een paar honderd kilobyte, dus een
        // ruime vaste bovengrens is eenvoudiger dan de buffer al herhaald op te
        // rekken.
        let capaciteit = 1 << 20
        var uitvoer = [UInt8](repeating: 0, count: capaciteit)

        let geschreven = uitvoer.withUnsafeMutableBufferPointer { uitBuf -> Int in
            bron.withUnsafeBytes { bronBuf -> Int in
                compression_decode_buffer(uitBuf.baseAddress!, capaciteit,
                                          bronBuf.bindMemory(to: UInt8.self).baseAddress!,
                                          bron.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard geschreven > 0 else { throw Fout.decomprimeren }
        return Data(uitvoer.prefix(geschreven))
    }
}
