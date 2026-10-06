import Foundation
import Testing
@testable import KlaverjasKit

/// De speelwijze Claude (`ClaudeStand`/`ClaudeAi`) is een port van de Android-versie. Drie proeven leggen
/// de snelle simulatie naast de engine, en een vierde legt de uitslag naast die van de Kotlin-versie:
/// omdat de toevalsreeks en alle stappen gelijk zijn, moet bij hetzelfde zaad elk getal gelijk zijn.
struct ClaudeTests {
    /// Draait rekenwerk op een eigen draad, buiten de gedeelde pool van Swift Testing. Veel rekenwerk dat de
    /// pool bezet houdt, laat andere proeven — vooral `SnelTests`, die tekenmomenten binnen 250 ms telt —
    /// op een vrije draad wachten en maakt die onbetrouwbaar in de volle run.
    static func opEigenDraad<T: Sendable>(_ werk: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { c in
            let draad = Thread { c.resume(returning: werk()) }
            draad.stackSize = 8 << 20
            draad.qualityOfService = .background     // laat andere proeven voorgaan
            draad.start()
        }
    }

    /// De stand uit de engine, zoals de engine hem op dit moment kent (zonder de dichte kaarten).
    static func bouw(_ e: KjEngine) -> ClaudeStand {
        let s = e.s
        let st = ClaudeStand()
        st.troef = s.troef
        st.speler = (s.speler > 2 ? s.speler - 2 : s.speler) - 1
        st.slagNr = s.slagNr
        for n in 0..<32 {
            switch s.kaart[n].dichtIkHy {
            case Pos.handZuid: st.hand[0] |= 1 << n
            case Pos.handNoord: st.hand[1] |= 1 << n
            case Pos.tafelZuid: st.open[0][e.tafelPos(n)] = n
            case Pos.tafelNoord: st.open[1][e.tafelPos(n)] = n
            case Pos.nieuwZuid: st.dicht[0][e.tafelPos(n)] = n
            case Pos.nieuwNoord: st.dicht[1][e.tafelPos(n)] = n
            case Pos.gespeeld: st.gespeeld |= 1 << n
            default: break
            }
        }
        let eerste = s[slag: s.slagNr, i: 0].speler
        st.leider = s.slagKrtNo == 0 ? (s.vrager > 2 ? s.vrager - 2 : s.vrager) - 1
                                     : (eerste > 2 ? eerste - 2 : eerste) - 1
        for k in 0..<min(s.slagKrtNo, 3) {
            let sk = s[slag: s.slagNr, i: k]
            st.legVast(ClaudeTabel.kaartNr(sk.kleur, sk.naam), (sk.speler > 2 ? sk.speler - 2 : sk.speler) - 1,
                       uitHand: sk.speler < 3)
        }
        return st
    }

    @Test("De toegestane kaarten van de simulatie komen overeen met checkValid()")
    func toegestaneKaartenKomenOverEen() async {
        let (beslissingen, getoetst, afwijking) = await Self.opEigenDraad { Self.meetToegestaan() }
        #expect(afwijking == nil, "\(afwijking ?? "")")
        #expect(beslissingen == 200 * 32)
        #expect(getoetst > 20_000)
    }

    private static func meetToegestaan() -> (Int, Int, String?) {
        var beslissingen = 0
        var getoetst = 0
        var afwijking: String?
        _ = Spoor.genereer(spellen: 200, zaad: 1) { e in
            guard afwijking == nil else { return }
            let s = e.s
            let st = Self.bouw(e)
            let code = s.vrager                       // de stapel waaruit de gekozen kaart komt
            let kant = (code > 2 ? code - 2 : code) - 1
            if kant != st.aanZet { afwijking = "kant \(kant) tegen \(st.aanZet)"; return }
            if st.fase > 0 && (code < 3) != st.uitHand {
                afwijking = "stapel bij fase \(st.fase): engine hand=\(code < 3), simulatie hand=\(st.uitHand)"
                return
            }
            let mijn = st.toegestaan()
            let bewaardKaart = s.lkaart, bewaardKleur = s.lkleur
            for n in 0..<32 where s.kaart[n].dichtIkHy == code {
                s.lkaart = s.kaart[n].naam
                s.lkleur = s.kaart[n].kleur
                let engine = e.checkValid() == nil
                let ik = mijn & (1 << n) != 0
                if engine != ik {
                    afwijking = "kaart \(s.kaart[n].naam) kleur \(s.kaart[n].kleur), slag \(s.slagNr), fase \(st.fase), "
                        + "troef \(s.troef): engine=\(engine) simulatie=\(ik)"
                }
                getoetst += 1
            }
            s.lkaart = bewaardKaart
            s.lkleur = bewaardKleur
            beslissingen += 1
        }
        return (beslissingen, getoetst, afwijking)
    }

    @Test("Punten en roem komen slag voor slag overeen met het ijkspoor")
    func puntenEnRoemKomenOverEen() throws {
        let regels = try SpoorTests.ijkbestand().filter { !$0.hasPrefix("#") }
        var spellen = 0
        var i = 0
        while i < regels.count {
            let spel = regels[i].split(separator: ";", omittingEmptySubsequences: false)[0]
            var kaarten: [(kaart: Int, kant: Int, stapel: Int)] = []
            var slot: [Substring]?
            while i < regels.count, regels[i].split(separator: ";", omittingEmptySubsequences: false)[0] == spel {
                let d = regels[i].split(separator: ";", omittingEmptySubsequences: false)
                if d[1] == "=" { slot = d } else {
                    let stapel = Int(d[3])!
                    kaarten.append((ClaudeTabel.kaartNr(Int(d[4])!, Teken(unicodeScalarLiteral: d[5].unicodeScalars.first!)),
                                    (stapel > 2 ? stapel - 2 : stapel) - 1, stapel))
                }
                i += 1
            }
            guard let slot, kaarten.count == 32 else { continue }   // een afgebroken spel heeft geen telling
            let st = ClaudeStand()
            st.troef = Int(slot[2])!
            for (n, k) in kaarten.enumerated() {
                if n % 4 == 0 { st.leider = k.kant }
                if n % 4 == 3 { st.speel(k.kaart) } else { st.legVast(k.kaart, k.kant, uitHand: k.stapel < 3) }
            }
            #expect(st.punten[0] == Int(slot[3])!, "spel \(spel) punten Zuid")
            #expect(st.punten[1] == Int(slot[4])!, "spel \(spel) punten Noord")
            #expect(st.roem[0] == Int(slot[5])!, "spel \(spel) roem Zuid")
            #expect(st.roem[1] == Int(slot[6])!, "spel \(spel) roem Noord")
            spellen += 1
        }
        #expect(spellen >= 190)
    }

    @Test("Pit, tegenpit en nat komen overeen met evalueerSpel()")
    func pitTegenpitEnNatKomenOverEen() {
        var stand: UInt64 = 5
        func volgende(_ n: Int) -> Int {
            stand = stand &* 6364136223846793005 &+ 1442695040888963407
            return Int((stand >> 33) % UInt64(n))
        }
        for _ in 0..<400 {
            let e = KjEngine(zaad: 1)
            let s = e.s
            let speler = 1 + volgende(2)
            let p0 = volgende(6) == 0 ? 152 * volgende(2) : volgende(153)
            s.speler = speler
            s.puntenSpel[0] = p0; s.puntenSpel[1] = 152 - p0
            s.roem[0] = 20 * volgende(6); s.roem[1] = 20 * volgende(6)
            s.slagNr = 9; s.slagKrtNo = 0

            let st = ClaudeStand()
            st.speler = speler - 1
            st.punten = [s.puntenSpel[0], s.puntenSpel[1]]
            st.roem = [s.roem[0], s.roem[1]]
            let uit = st.eindstand()

            _ = e.evalueerSpel()
            #expect(Int(s.puntenTotaalSpel[0]) == uit.zuid, "Zuid bij speler=\(speler) p0=\(p0)")
            #expect(Int(s.puntenTotaalSpel[1]) == uit.noord, "Noord bij speler=\(speler) p0=\(p0)")
        }
    }

    /// De getallen komen van de Kotlin-versie (`ClaudeToernooiTest.meting`, 10 spellen, zaad 1, 200 proeven).
    /// Bij gelijke toevalsreeks en gelijke stappen moet elk getal gelijk zijn; wijkt er één af, dan speelt
    /// de ene versie ergens een andere kaart dan de andere.
    ///
    /// Bewust klein en `.serialized`: Claude rekent veel, en twee argumenten naast elkaar hielden de machine
    /// zo bezig dat `SnelTests` (die tekenmomenten binnen 250 ms telt) er tijdens de volle run over struikelde.
    @Test("Claude geeft dezelfde uitslag als de Kotlin-versie", .serialized, arguments: [
        (Toernooi.Stijl.ednieuw, [15, 5], [2353, 1727], [670, 370], [0, 5], [1, 0]),
        (Toernooi.Stijl.ronlog, [14, 6], [2196, 1664], [620, 200], [1, 5], [1, 0]),
    ])
    func gelijkAanKotlin(tegen: Toernooi.Stijl, gewonnen: [Int64], punten: [Int64], roem: [Int64],
                         nat: [Int64], pit: [Int64]) async {
        let u = await Self.opEigenDraad {
            ClaudeAi.standaardProeven = 200
            return Toernooi.speel(spellen: 10, zaad: 1, a: .claude, b: tegen)
        }
        #expect(u.verzaakt == 0)
        #expect(u.gespeeld == 20)
        #expect(u.gewonnen == gewonnen)
        #expect(u.punten == punten)
        #expect(u.roem == roem)
        #expect(u.nat == nat)
        #expect(u.pit == pit)
    }
}
