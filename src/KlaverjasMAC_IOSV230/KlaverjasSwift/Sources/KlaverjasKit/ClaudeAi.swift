/// De speelwijze Claude: kiest een kaart door het hele spel een aantal keer door te spelen.
///
/// Wat de tegenstander in handen heeft is onbekend, dus worden zijn hand en de dichte kaarten onder de
/// tafels telkens opnieuw willekeurig verdeeld, binnen wat bekend is: de kaarten die al gespeeld of
/// getoond zijn, en de kleuren waarin hij niet kon bekennen. Voor elke toegestane kaart wordt dan de
/// rest van het spel doorgespeeld, met een eenvoudige speelwijze voor beide kanten, tot en met de
/// telling van pit en nat. De kaart met de beste gemiddelde uitslag wint.
///
/// Anders dan Ednieuw (vuistregels) en Ronlog (rekent één slag door) kijkt deze speler dus naar de
/// uitslag van het héle spel. Het getal van de eigen kant minus dat van de tegenstander telt, dus pit,
/// roem en nat zitten er vanzelf in. In het scherm heet dit "brute force".
///
/// De toevalsreeks is die van deze speler zelf en staat los van die van de engine: de spellen die
/// gedeeld worden veranderen er niet door, en bij hetzelfde zaad speelt hij hetzelfde.
///
/// Port van ClaudeAi.kt uit de Android-versie. Omdat de toevalsreeks en de volgorde van alle stappen
/// gelijk zijn, kiest deze versie bij dezelfde stand dezelfde kaart als de Kotlin-versie.
public final class ClaudeAi {
    private let e: KjEngine
    private var s: KjState { e.s }
    private var rnd: Toevalsreeks
    private let proeven: Int

    /// Het nummer waaronder Claude in de tactiekstatistiek komt (70 is Ronlog).
    public static let tactiek = 71

    /// Hoeveel keer er per zet een verdeling van de onbekende kaarten wordt doorgespeeld. Meer is
    /// sterker en trager: bij 10 wint hij ongeveer 56% van de spellen van Ednieuw, bij 200 ongeveer 61%.
    nonisolated(unsafe) public static var standaardProeven = 200
    private static let troefFactor = 3

    init(_ engine: KjEngine, zaad: UInt32 = 20_261_003, proeven: Int = ClaudeAi.standaardProeven) {
        e = engine
        rnd = Toevalsreeks(zaad)
        self.proeven = proeven
    }

    private func toeval(_ n: Int) -> Int { rnd.volgende(n) }

    // ------------------------------------------------------ de stand uit de engine

    /// Wat de speler die aan zet is weet, en niets meer: zijn eigen kaarten, de open tafels, wat
    /// gespeeld is en welke kleuren de tegenstander niet in zijn hand heeft.
    private final class Zicht {
        let ik: Int
        let tegen: Int
        let basis = ClaudeStand()
        var pool = [Int](repeating: 0, count: 32)
        var poolN = 0
        var tegenstanderHand = 0
        var onbekendDicht: [(kant: Int, plek: Int)] = []
        var kleurLeeg = [Bool](repeating: false, count: 4)   // de tegenstander heeft die kleur niet in zijn hand

        init(_ e: KjEngine, ik: Int, troefKiezen: Bool) {
            let s = e.s
            self.ik = ik
            tegen = 1 - ik
            let st = basis
            st.troef = troefKiezen ? 0 : s.troef
            st.speler = troefKiezen ? ik : (s.speler > 2 ? s.speler - 3 : s.speler - 1)
            st.slagNr = troefKiezen ? 1 : s.slagNr
            for k in 0..<2 {
                st.punten[k] = s.puntenSpel[k]
                st.roem[k] = s.roem[k]
            }

            for n in 0..<32 {
                let pos = s.kaart[n].dichtIkHy
                if pos == Pos.handZuid + ik { st.hand[ik] |= 1 << n }
                else if pos == Pos.tafelZuid + ik { st.open[ik][min(max(e.tafelPos(n), 0), 3)] = n }
                else if pos == Pos.tafelZuid + tegen { st.open[tegen][min(max(e.tafelPos(n), 0), 3)] = n }
                else if pos == Pos.nieuwZuid + ik { st.dicht[ik][min(max(e.tafelPos(n), 0), 3)] = n }
                else if pos == Pos.nieuwZuid + tegen { st.dicht[tegen][min(max(e.tafelPos(n), 0), 3)] = n }
                else if pos == Pos.gespeeld { st.gespeeld |= 1 << n }
                else {
                    pool[poolN] = n; poolN += 1
                    if pos == Pos.handZuid + tegen { tegenstanderHand += 1 }
                }
            }
            // Welke dichte plekken zijn nog onbekend? De vlag staat op 1 zolang er nog een dichte kaart ligt.
            for k in 0..<2 {
                for i in 0..<4 {
                    let vlag = k == 0 ? s.tZuid[i] : s.tNoord[i]
                    if vlag != 0 && st.dicht[k][i] < 0 { onbekendDicht.append((k, i)) }
                }
            }

            if !troefKiezen {
                // De lopende slag.
                let aantal = min(max(s.slagKrtNo, 0), 3)
                let eerste = s[slag: s.slagNr, i: 0].speler
                st.leider = aantal == 0 ? ik : Zicht.kant(eerste) - 1
                for k in 0..<aantal {
                    let sk = s[slag: s.slagNr, i: k]
                    let c = ClaudeTabel.kaartNr(sk.kleur, sk.naam)
                    st.legVast(c, Zicht.kant(sk.speler) - 1, uitHand: sk.speler < 3)
                }
                // Kleuren waarin de tegenstander niet kon bekennen: in de afgelopen slagen en in deze.
                for n in 1...max(1, s.slagNr) {
                    let tot = n == s.slagNr ? aantal : 4
                    if tot < 2 { continue }
                    let led = s[slag: n, i: 0].kleur
                    for k in 1..<tot {
                        let sk = s[slag: n, i: k]
                        if sk.kleur != led && sk.speler == Pos.handZuid + tegen && led >= 0 && led <= 3 {
                            kleurLeeg[led] = true
                        }
                    }
                }
            } else {
                st.leider = ik
            }
        }

        static func kant(_ vrager: Int) -> Int { vrager > 2 ? vrager - 2 : vrager }

        /// Verdeelt de onbekende kaarten willekeurig en geeft een volledige stand.
        func trek(_ uit: ClaudeStand, _ toeval: (Int) -> Int) {
            uit.zet(basis)
            var p = Array(pool[0..<poolN])
            var i = p.count - 1
            while i >= 1 {
                let j = toeval(i + 1)
                p.swapAt(i, j)
                i -= 1
            }
            var hand = 0
            var geplaatst = 0
            var rest = [Int](repeating: 0, count: p.count)
            var restN = 0
            for c in p {
                if geplaatst < tegenstanderHand && !kleurLeeg[ClaudeTabel.kleur(c)] {
                    hand |= 1 << c; geplaatst += 1
                } else { rest[restN] = c; restN += 1 }
            }
            // Zo weinig keuze dat de kleuren niet pasten: dan toch opvullen.
            var r = 0
            while geplaatst < tegenstanderHand && r < restN { hand |= 1 << rest[r]; r += 1; geplaatst += 1 }
            uit.hand[tegen] = hand
            for plek in onbekendDicht {
                if r >= restN { break }
                uit.dicht[plek.kant][plek.plek] = rest[r]; r += 1
            }
        }
    }

    private static func kant(_ vrager: Int) -> Int { vrager > 2 ? vrager - 2 : vrager }

    // ------------------------------------------------------------- de speelwijze

    /// Speelt het spel uit met de eenvoudige speelwijze voor beide kanten.
    private func speelUit(_ st: ClaudeStand) {
        while !st.klaar { st.speel(kies(st)) }
    }

    private func waarde(_ st: ClaudeStand, _ ik: Int) -> Int {
        let uit = st.eindstand()
        return ik == 0 ? uit.zuid - uit.noord : uit.noord - uit.zuid
    }

    /// De eenvoudige speelwijze waarmee de rest van het spel wordt doorgespeeld. Ze gebruikt alleen wat
    /// de speler zelf kan zien, zodat de uitkomst niet beter wordt dan het spel toelaat.
    private func kies(_ st: ClaudeStand) -> Int {
        let mag = st.toegestaan()
        if mag & (mag - 1) == 0 { return mag.trailingZeroBitCount }
        let kant = st.aanZet
        let troef = st.troef
        return st.fase == 0 ? uitkomen(st, mag, kant, troef) : bijspelen(st, mag, kant, troef)
    }

    /// Wat deze kant nog niet gezien heeft: niet gespeeld en niet van hemzelf.
    private func ongezien(_ st: ClaudeStand, _ kant: Int) -> Int {
        ~(st.gespeeld | st.hand[kant] | st.tafelMasker(kant))
    }

    /// Is deze kaart de hoogste die er in zijn kleur nog kan zijn?
    private func hoogste(_ c: Int, _ troef: Int, _ ongezien: Int) -> Bool {
        var m = ongezien & ClaudeTabel.kleurMasker(ClaudeTabel.kleur(c))
        let k = ClaudeTabel.kracht(c, troef)
        while m != 0 {
            let x = m.trailingZeroBitCount
            m &= m - 1
            if ClaudeTabel.kracht(x, troef) > k { return false }
        }
        return true
    }

    private func uitkomen(_ st: ClaudeStand, _ mag: Int, _ kant: Int, _ troef: Int) -> Int {
        let weg = ongezien(st, kant)
        var beste = -1
        var besteScore = Int.min
        var m = mag
        while m != 0 {
            let c = m.trailingZeroBitCount
            m &= m - 1
            let p = ClaudeTabel.punten(c, troef)
            let trf = ClaudeTabel.kleur(c) == troef
            let score: Int
            if hoogste(c, troef, weg) {
                // Een kaart die niet te kloppen is: eerst de punten ophalen, troef alleen als wij troef maakten.
                if !trf { score = 200 + p } else if st.speler == kant { score = 130 + p } else { score = 60 + p }
            } else {
                score = 50 - 3 * p - ClaudeTabel.kracht(c, troef) - (trf ? 40 : 0)
            }
            if score > besteScore { besteScore = score; beste = c }
        }
        return beste
    }

    private func bijspelen(_ st: ClaudeStand, _ mag: Int, _ kant: Int, _ troef: Int) -> Int {
        let mijn = st.winnaarKant == kant
        let laatste = st.fase == 3
        let weg = ongezien(st, kant)
        let houdt = laatste || hoogste(st.winnendeKaart, troef, weg)
        var beste = -1
        var besteScore = Int.min
        var m = mag
        while m != 0 {
            let c = m.trailingZeroBitCount
            m &= m - 1
            let p = ClaudeTabel.punten(c, troef)
            let k = ClaudeTabel.kracht(c, troef)
            let trf = ClaudeTabel.kleur(c) == troef
            let score: Int
            if mijn {
                // Staat de slag op onze naam: smeren als hij blijft staan, anders zo goedkoop mogelijk.
                score = houdt ? p * 8 - k : -(p * 8 + k)
            } else if st.verslaatBeste(c) {
                // De goedkoopste kaart die de slag pakt.
                score = 1000 - (p * 8 + k)
            } else {
                // Kan de slag niet pakken: zo weinig mogelijk weggeven, en liever geen troef.
                score = -(p * 8 + k) - (trf ? 100 : 0)
            }
            if score > besteScore { besteScore = score; beste = c }
        }
        return beste
    }

    // --------------------------------------------------------------- kaart kiezen

    /// De toegestane kaarten en hun som van uitslagen over alle proeven, zonder iets in de engine te
    /// veranderen. Nil als er niets te kiezen valt. Apart van `kies()` zodat een proef kan aantonen dat de
    /// scores niet afhangen van wat de speler niet kan zien.
    func kaartScores() -> (kandidaten: [Int], som: [Int])? {
        let ik = ClaudeAi.kant(s.vrager) - 1
        let zicht = Zicht(e, ik: ik, troefKiezen: false)
        let basis = zicht.basis

        // De kaarten die de regelcontrole van de engine goedkeurt; die is doorslaggevend.
        let gok = basis.toegestaan()
        var kandidaten: [Int] = []
        for c in 0..<32 where gok & (1 << c) != 0 && engineKeurtGoed(c) { kandidaten.append(c) }
        if kandidaten.isEmpty { for c in 0..<32 where gok & (1 << c) != 0 { kandidaten.append(c) } }
        if kandidaten.isEmpty { return nil }

        var som = [Int](repeating: 0, count: kandidaten.count)
        if kandidaten.count > 1 {
            let trek = ClaudeStand()
            let werk = ClaudeStand()
            for _ in 0..<proeven {
                zicht.trek(trek) { self.toeval($0) }
                for i in kandidaten.indices {
                    werk.zet(trek)
                    werk.speel(kandidaten[i])
                    speelUit(werk)
                    som[i] += waarde(werk, ik)
                }
            }
        }
        return (kandidaten, som)
    }

    /// Kiest een kaart voor de stapel die aan zet is en zet die in `s.lkaart` / `s.lkleur`.
    func kies() {
        guard let (kandidaten, som) = kaartScores() else { return }
        var beste = 0
        for i in 1..<som.count where som[i] > som[beste] { beste = i }
        let gekozen = kandidaten[beste]

        s.lkleur = ClaudeTabel.kleur(gekozen)
        s.lkaart = ClaudeTabel.naam(gekozen)
        s.tactiek = ClaudeAi.tactiek
        s.vrager = e.wieVrager(s.lkaart, s.lkleur)
    }

    /// Keurt de regelcontrole van de engine deze kaart goed?
    private func engineKeurtGoed(_ c: Int) -> Bool {
        let bewaardKaart = s.lkaart
        let bewaardKleur = s.lkleur
        s.lkaart = ClaudeTabel.naam(c)
        s.lkleur = ClaudeTabel.kleur(c)
        let goed = e.checkValid() == nil
        s.lkaart = bewaardKaart
        s.lkleur = bewaardKleur
        return goed
    }

    // ----------------------------------------------------------------- troef kiezen

    /// De som van uitslagen per troefkleur over alle proeven (zie `kaartScores()`).
    func troefScores() -> [Int] {
        let ik = ClaudeAi.kant(s.startVrager) - 1
        let zicht = Zicht(e, ik: ik, troefKiezen: true)
        var som = [Int](repeating: 0, count: 4)
        let trek = ClaudeStand()
        let werk = ClaudeStand()
        for _ in 0..<(proeven * ClaudeAi.troefFactor) {
            zicht.trek(trek) { self.toeval($0) }
            for t in 0..<4 {
                werk.zet(trek)
                werk.troef = t
                speelUit(werk)
                som[t] += waarde(werk, ik)
            }
        }
        return som
    }

    /// Kiest de troefkleur met het beste gemiddelde over het hele spel.
    func kiesTroef() -> Int {
        let som = troefScores()
        var beste = 0
        for t in 1..<4 where som[t] > som[beste] { beste = t }
        return beste
    }
}
