import Foundation
import KlaverjasKit

/// Schrijft een spoor weg, net als `KlaverjasTest spoor` aan de C#-kant.
/// Zo zijn de twee engines op elk zaad met elkaar te vergelijken.
///
///     swift run spoor <spellen> <zaad> <pad>
@main
struct Gereedschap {
    static func main() {
        let a = CommandLine.arguments
        let spellen = a.count > 1 ? (Int(a[1]) ?? 200) : 200
        let zaad = a.count > 2 ? (Int(a[2]) ?? 1) : 1
        let pad = a.count > 3 ? a[3] : "spoor-swift.txt"

        let regels = Spoor.genereer(spellen: spellen, zaad: zaad)
        // CRLF, zodat het bestand naast dat van de C#-versie te leggen is.
        let tekst = regels.joined(separator: "\r\n") + "\r\n"
        do {
            try tekst.write(toFile: pad, atomically: true, encoding: .utf8)
            print("spoor geschreven: \(pad)")
            print("  \(regels.count) regels, \(spellen) spellen, zaad \(zaad)")
        } catch {
            FileHandle.standardError.write(Data("kon \(pad) niet schrijven: \(error)\n".utf8))
            exit(1)
        }
    }
}
