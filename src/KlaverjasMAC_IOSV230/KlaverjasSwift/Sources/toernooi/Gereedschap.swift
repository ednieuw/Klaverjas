import Foundation
import KlaverjasKit

/// Laat de twee speelwijzen tegen elkaar spelen, net als `KlaverjasTest toernooi`
/// aan de C#-kant. De getallen horen exact overeen te komen.
///
///     swift run -c release toernooi <spellen> <zaad> [<a> <b>]
///
/// Zonder `a` en `b` spelen Ednieuw en Ronlog tegen elkaar. Met namen (`ednieuw`, `ronlog`,
/// `claude`) kan elke combinatie; Claude is traag genoeg om dat in release te willen draaien.
@main
struct Gereedschap {
    static func main() {
        let a = CommandLine.arguments
        let gevraagd = a.count > 1 ? (Int(a[1]) ?? 500) : 500
        // Elk spel wordt twee keer gespeeld, dus de helft van de grens.
        let spellen = min(max(gevraagd, 1), 500_000)
        if spellen != gevraagd { print("teruggebracht tot \(spellen) spellen: daarboven lopen de tellers over") }
        let zaad = a.count > 2 ? (Int(a[2]) ?? 1) : 1

        let stijlen = a.dropFirst(3).prefix(2).compactMap { naam in
            Toernooi.Stijl.allCases.first { $0.naam.lowercased() == naam.lowercased() }
        }
        let sa = stijlen.count == 2 ? stijlen[0] : .ednieuw
        let sb = stijlen.count == 2 ? stijlen[1] : .ronlog

        print("\(sa.naam) tegen \(sb.naam): \(spellen) spellen, elk twee keer gespeeld")
        print("")
        let begin = Date()
        let u = Toernooi.speel(spellen: spellen, zaad: zaad, a: sa, b: sb)
        let ms = Int(Date().timeIntervalSince(begin) * 1000)

        for r in Toernooi.verslag(u, spellen: spellen, a: sa, b: sb) { print(r) }
        print("Gespeeld           : \(u.gespeeld) spellen, \(ms) ms")
        exit(u.verzaakt == 0 ? 0 : 1)
    }
}
