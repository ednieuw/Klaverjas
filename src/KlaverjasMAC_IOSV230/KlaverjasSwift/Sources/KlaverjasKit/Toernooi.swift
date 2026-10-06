/// Laat de vuistregels van Ednieuw en de zoekende speler van Ronlog zonder
/// scherm tegen elkaar spelen. Dit is de Swift-tegenhanger van `Toernooi()` uit
/// KlaverjasTest/Program.cs; bij hetzelfde zaad en aantal spellen horen er exact
/// dezelfde getallen uit te komen.
///
/// Elk spel wordt twee keer gespeeld met dezelfde kaarten, één keer met elk van
/// beiden als Zuid, zodat een gelukkige verdeling niet meetelt en het verschil
/// echt aan de speelwijze ligt.
public enum Toernooi {

    /// De drie speelwijzen die tegen elkaar kunnen spelen.
    public enum Stijl: String, Sendable, CaseIterable {
        case ednieuw = "Ednieuw", ronlog = "Ronlog", claude = "Claude"
        public var naam: String { rawValue }
    }

    public struct Uitslag: Sendable {
        /// index 0 = Ednieuw, 1 = Ronlog
        public var punten = [Int64](repeating: 0, count: 2)
        public var gewonnen = [Int64](repeating: 0, count: 2)
        public var roem = [Int64](repeating: 0, count: 2)
        public var nat = [Int64](repeating: 0, count: 2)
        public var pit = [Int64](repeating: 0, count: 2)
        public var gespeeld = 0
        public var verzaakt = 0
    }

    public static func speel(spellen: Int, zaad: Int) -> Uitslag {
        speel(spellen: spellen, zaad: zaad, a: .ednieuw, b: .ronlog)
    }

    /// Laat `a` (index 0 in de uitslag) en `b` (index 1) tegen elkaar spelen, elk spel twee keer met
    /// dezelfde kaarten en elk één keer als Zuid.
    public static func speel(spellen: Int, zaad: Int, a: Stijl, b: Stijl) -> Uitslag {
        var u = Uitslag()

        for ronde in 0..<2 {
            // ronde 0: `a` is Zuid. ronde 1: `b` is Zuid, zelfde kaarten.
            let ednieuwIsZuid = ronde == 0
            let e = KjEngine(zaad: zaad)
            let s = e.s
            s.comp = true
            let zuid = ednieuwIsZuid ? a : b
            let noord = ednieuwIsZuid ? b : a
            s.zoekt[0] = zuid == .ronlog; s.claude[0] = zuid == .claude
            s.zoekt[1] = noord == .ronlog; s.claude[1] = noord == .claude

            let d = Beurt(e)
            for _ in 0..<spellen {
                let gwZ = s.gewonnenTot[0], gwN = s.gewonnenTot[1]
                let ntZ = s.nat[0], ntN = s.nat[1]
                let ptZ = s.pit[0], ptN = s.pit[1]
                d.roemZuid = 0
                d.roemNoord = 0

                if d.speelEenSpel() { u.verzaakt += 1 }
                u.gespeeld += 1

                // Zuid is index 0 als Ednieuw Zuid speelt, anders is Ronlog dat.
                let ed = ednieuwIsZuid ? 0 : 1
                let ro = ednieuwIsZuid ? 1 : 0
                let kaartpnt = [d.puntenZuid, d.puntenNoord]
                let roempnt = [d.roemZuid, d.roemNoord]
                u.punten[0] += Int64(kaartpnt[ed] + roempnt[ed])
                u.punten[1] += Int64(kaartpnt[ro] + roempnt[ro])
                u.roem[0] += Int64(roempnt[ed])
                u.roem[1] += Int64(roempnt[ro])
                u.gewonnen[0] += (ed == 0 ? s.gewonnenTot[0] - gwZ : s.gewonnenTot[1] - gwN)
                u.gewonnen[1] += (ro == 0 ? s.gewonnenTot[0] - gwZ : s.gewonnenTot[1] - gwN)
                u.nat[0] += (ed == 0 ? s.nat[0] - ntZ : s.nat[1] - ntN)
                u.nat[1] += (ro == 0 ? s.nat[0] - ntZ : s.nat[1] - ntN)
                u.pit[0] += (ed == 0 ? s.pit[0] - ptZ : s.pit[1] - ptN)
                u.pit[1] += (ro == 0 ? s.pit[0] - ptZ : s.pit[1] - ptN)
            }
        }
        return u
    }

    /// Het verslag zoals de C#-versie het afdrukt, regel voor regel.
    public static func verslag(_ u: Uitslag, spellen: Int,
                               a: Stijl = .ednieuw, b: Stijl = .ronlog) -> [String] {
        func vul(_ t: String, _ n: Int) -> String {
            t.count >= n ? t : t + String(repeating: " ", count: n - t.count)
        }
        func rechts(_ t: String, _ n: Int) -> String {
            t.count >= n ? t : String(repeating: " ", count: n - t.count) + t
        }
        func rij(_ kop: String, _ e: Int64, _ l: Int64) -> String {
            vul(kop, 22) + rechts("\(e)", 10) + rechts("\(l)", 10)
        }
        func procent(_ deel: Int64, _ totaal: Int64) -> String {
            // Eén cijfer achter de komma, zoals "F1" in C#: halfweg naar boven.
            let tienden = (1000 * deel + totaal / 2) / totaal
            return "\(tienden / 10).\(tienden % 10)"
        }

        var uit: [String] = []
        uit.append(vul("", 22) + rechts(a.naam, 10) + rechts(b.naam, 10))
        uit.append(String(repeating: "-", count: 42))
        uit.append(rij("Spellen gewonnen", u.gewonnen[0], u.gewonnen[1]))
        uit.append(rij("Punten totaal", u.punten[0], u.punten[1]))
        uit.append(rij("Waarvan roem", u.roem[0], u.roem[1]))
        uit.append(rij("Nat gegaan", u.nat[0], u.nat[1]))
        uit.append(rij("Pit gehaald", u.pit[0], u.pit[1]))
        uit.append("")

        let tot = u.punten[0] + u.punten[1]
        if tot > 0 {
            uit.append("Puntenaandeel      : \(a.naam) \(procent(u.punten[0], tot))%"
                       + "   \(b.naam) \(procent(u.punten[1], tot))%")
        }
        let totG = u.gewonnen[0] + u.gewonnen[1]
        if totG > 0 {
            uit.append("Spellen gewonnen   : \(a.naam) \(procent(u.gewonnen[0], totG))%"
                       + "   \(b.naam) \(procent(u.gewonnen[1], totG))%")
        }
        uit.append("Afgebroken (verzaakt): \(u.verzaakt)")
        return uit
    }

    /// Speelt precies één spel, met dezelfde stappen als KjSpel maar zonder
    /// oneindige lus. Tegenhanger van `Driver` uit KlaverjasTest/Program.cs.
    private final class Beurt {
        private let e: KjEngine
        private var s: KjState { e.s }

        var puntenZuid = 0, puntenNoord = 0
        var roemZuid = 0, roemNoord = 0

        init(_ engine: KjEngine) {
            e = engine
            s.speler = s.random(2) + 1
        }

        /// Geeft true als het spel wegens verzaken is afgebroken.
        func speelEenSpel() -> Bool {
            s.troef = 999
            s.slagNr = 0
            s.slagKrtNo = 0

            e.delen()
            s.speler = 1 - (s.speler - 1) + 1
            s.vrager = s.speler
            s.startVrager = s.speler
            for n in 0..<4 { s.tNoord[n] = 1; s.tZuid[n] = 1 }

            e.kaartenVrij()
            e.zetTafelPosities()
            e.vulhanden()
            s.slagNr = 0
            e.troefBepalen()

            puntenZuid = 0
            puntenNoord = 0

            s.slagNr = 1
            while s.slagNr < 9 {
                s.tactiek = 0
                e.speler1()
                if !leg() { return true }
                s.startVrager = s.vrager
                if s.tactiek == 41 { s.tactiek41 = true }
                s.tac[grens(s.tactiek)] += 1

                for beurt in [e.tegenspeler1, e.speler2, e.tegenspeler2] {
                    s.tactiek = 0
                    beurt()
                    if !leg() { return true }
                    s.tac[grens(s.tactiek)] += 1
                }

                for n in 0..<4 {
                    let w = winnaarKant()
                    if w == 1 { puntenZuid += s[slag: s.slagNr, i: n].waarde }
                    else { puntenNoord += s[slag: s.slagNr, i: n].waarde }
                }

                e.evalueer()

                if s.slagNr == 8 {
                    // Vastleggen vóór evalueerSpel(), want die zet de tellers op nul.
                    roemZuid = s.roem[0]
                    roemNoord = s.roem[1]
                    e.evalueerSpel()
                } else {
                    e.updateTafel()
                    s.slagKrtNo = 0
                }

                s.slagNr += 1
            }
            return false
        }

        private func winnaarKant() -> Int {
            let w = e.wieSlag()
            return w > 2 ? w - 2 : w
        }

        private func grens(_ t: Int) -> Int { (t >= 0 && t < 80) ? t : 0 }

        private func leg() -> Bool {
            if e.wachtOpMens { return false }
            if !e.legKaart(s.lkaart, s.lkleur, s.vrager) { return false }
            return e.checkValid() == nil
        }
    }
}
