/// De speelwijze van R. Loggen (KJBeide/KJ2.C), overgezet op de gegevens van
/// deze motor.
///
/// Waar de tactiek van Ednieuw uit een lange reeks vuistregels bestaat, probeert
/// deze speler het uit: hij speelt elke eigen kaart proef, laat de tegenstander
/// er zijn beste antwoord op geven, speelt zelf zijn beste vervolg, en middelt
/// over alle kaarten die de tegenstander nog in handen kán hebben. De waarde van
/// een slag is punten plus roem, met een minteken als de tegenstander hem pakt —
/// vandaar dat deze speler vanzelf op roem speelt.
///
/// Dat de eerste drie kaarten exact doorgerekend kunnen worden komt doordat de
/// tafelkaarten open liggen: alleen de handkaarten van de tegenstander zijn
/// onbekend, en dat is precies de vierde kaart van de slag.
///
/// Alles is geheeltallig; er komt geen kommagetal en geen toeval in voor. Bij
/// dezelfde stand komt er dus exact dezelfde kaart uit als in de C#-versie.
public final class ZoekAi {
    private let e: KjEngine
    private var s: KjState { e.s }

    public init(_ engine: KjEngine) { self.e = engine }

    /// Eén kaart op tafel tijdens het doorrekenen.
    private struct Zet {
        let kleur: Int
        let naam: Teken
        let mijn: Bool
    }

    /// Een kaart in bezit: kleur en naam.
    private typealias Kaart = (kleur: Int, naam: Teken)

    // ------------------------------------------------------------- basis

    /// Hoe sterk is deze kaart binnen zijn kleur? Hoger is sterker.
    private func kracht(_ naam: Teken, _ kleur: Int) -> Int {
        let rang = kleur == s.troef ? KjState.rangTroef : KjState.rangNorm
        let p = CStr.pos(rang, naam)
        return p == 0 ? 0 : 9 - p
    }

    /// Kaartpunten, troef telt anders.
    private func waarde(_ naam: Teken, _ kleur: Int) -> Int {
        let nr = KjState.kaartNr(kleur, naam)
        return (nr >= 0 && nr < 32) ? s.kaart[nr].actWaarde : 0
    }

    /// Welke van de vier kaarten pakt de slag?
    private func winnaar(_ slag: [Zet]) -> Int {
        let leidend = slag[0].kleur
        var troefErin = false
        for i in 0..<4 where slag[i].kleur == s.troef { troefErin = true }
        let telt = troefErin ? s.troef : leidend

        var beste = -1, besteKracht = -1
        for i in 0..<4 {
            if slag[i].kleur != telt { continue }
            let k = kracht(slag[i].naam, slag[i].kleur)
            if k > besteKracht { besteKracht = k; beste = i }
        }
        return beste < 0 ? 0 : beste
    }

    /// Punten plus roem van een volledige slag, gezien vanuit mijn kant:
    /// positief als ik hem pak, negatief als de tegenstander hem pakt. Dit is
    /// `kjmaakslagtest` uit KJ0.C.
    private func slagWaarde(_ slag: [Zet]) -> Int {
        var punten = 0
        for i in 0..<4 { punten += waarde(slag[i].naam, slag[i].kleur) }

        var roem = 0
        let sp = CStr(8)
        for kleur in 0..<4 {
            var n = 0
            for i in 0..<4 where slag[i].kleur == kleur { sp[n] = slag[i].naam; n += 1 }
            sp[n] = .nul
            if n > 1 { roem += e.bepaalRoemPunten(sp, kleur) }
        }
        // Vier gelijke kaarten, net als in evalueer().
        if slag[0].naam == slag[1].naam && slag[1].naam == slag[2].naam
            && slag[2].naam == slag[3].naam {
            roem += slag[0].naam == "B" ? 200 : 100
        }

        let totaal = punten + roem
        return slag[winnaar(slag)].mijn ? totaal : -totaal
    }

    // -------------------------------------------------- reglementaire zetten

    /// Welke kaarten mag deze stapel spelen? Directe omzetting van `kjlegaal`
    /// uit KJ0.C: troef bekennen en overtroeven waar het moet, kleur bekennen,
    /// en bij niet kunnen bekennen wel of niet moeten troeven al naar gelang de
    /// slag al aan de eigen kant is.
    private func legaleZetten(_ bezit: [Kaart], _ opTafel: [Zet],
                              _ slagIsVanMij: Bool) -> [Kaart] {
        var uit: [Kaart] = []
        if opTafel.isEmpty { return bezit }

        let leidend = opTafel[0].kleur

        // Hoogste kaart die de slag nu zou pakken.
        var besteKracht = -1
        var troefErin = false
        for z in opTafel where z.kleur == s.troef { troefErin = true }
        let telt = troefErin ? s.troef : leidend
        for z in opTafel {
            if z.kleur != telt { continue }
            let k = kracht(z.naam, z.kleur)
            if k > besteKracht { besteKracht = k }
        }

        if leidend == s.troef {
            for b in bezit where b.kleur == s.troef && kracht(b.naam, b.kleur) > besteKracht {
                uit.append(b)
            }
            if uit.isEmpty { for b in bezit where b.kleur == leidend { uit.append(b) } }
            if uit.isEmpty { uit = bezit }
            return uit
        }

        for b in bezit where b.kleur == leidend { uit.append(b) }
        if !uit.isEmpty { return uit }

        if slagIsVanMij {
            // Slag staat al op eigen naam: alles mag, behalve ondertroeven als
            // er getroefd is.
            for b in bezit {
                if troefErin && b.kleur == s.troef && kracht(b.naam, b.kleur) <= besteKracht {
                    continue
                }
                uit.append(b)
            }
            if uit.isEmpty { uit = bezit }
            return uit
        }

        for b in bezit where b.kleur == s.troef && kracht(b.naam, b.kleur) > besteKracht {
            uit.append(b)
        }
        if uit.isEmpty { uit = bezit }
        return uit
    }

    // ------------------------------------------------------- kaarten tellen

    /// Kaarten van een eigen stapel: hand (false) of tafel (true) van mijn kant.
    private func eigenBezit(_ tafel: Bool) -> [Kaart] {
        var uit: [Kaart] = []
        let aantal = tafel ? 4 : 8
        for n in 0..<aantal {
            let d = tafel ? s.tafel[0][n] : s.hand[0][n]
            if d.naam != .nul && d.kleur >= 0 && d.kleur < 4 { uit.append((d.kleur, d.naam)) }
        }
        return uit
    }

    /// De open tafelkaarten van de tegenstander; die zijn bekend.
    private func tegenstanderTafel() -> [Kaart] {
        var uit: [Kaart] = []
        for n in 0..<4 {
            let d = s.tafel[1][n]
            if d.naam != .nul && d.kleur >= 0 && d.kleur < 4 { uit.append((d.kleur, d.naam)) }
        }
        return uit
    }

    /// Kaarten die de tegenstander nog in handen kán hebben. Dat is wat voor ons
    /// dicht is: zijn hand en de omgekeerde tafelkaarten. Kleuren waarin hij
    /// aantoonbaar verzaakt heeft vallen af.
    private func mogelijkeHand(_ kleurVoorkeur: Int) -> [Kaart] {
        var tegen = s.vrager > 2 ? s.vrager - 2 : s.vrager
        tegen = tegen == 1 ? 2 : 1

        var uit: [Kaart] = []
        func voeg(_ kleur: Int) {
            if kleur < 0 || kleur > 3 { return }
            if s.verzaakt[tegen - 1][kleur] != 0 { return }
            let len = s.krtDicht[kleur].len
            for i in 0..<len { uit.append((kleur, s.krtDicht[kleur][i])) }
        }
        voeg(kleurVoorkeur)
        if s.troef != kleurVoorkeur { voeg(s.troef) }
        return uit
    }

    // ------------------------------------------------------- troef kiezen

    /// De troefkeuze van Loggen (`kj2troef` uit KJ2.C). Hij waardeert elke kleur
    /// alsof die troef is en kiest de hoogste.
    ///
    /// Anders dan `troefBepalen()` van Ednieuw op drie punten: troeflengte telt
    /// kwadratisch in plaats van lineair, hand en tafel worden apart geteld, en
    /// de zijkleuren worden gewaardeerd op hun drie hoogste kaarten in plaats
    /// van op zekere slagen.
    public func kiesTroef() -> Int {
        var mij = (s.startVrager > 2) ? s.startVrager - 2 : s.startVrager
        if mij < 1 || mij > 2 { mij = 1 }
        let mijnHand = mij
        let mijnTafel = mij + 2
        let hijTafel = (mij == 1) ? Pos.tafelNoord : Pos.tafelZuid

        var t = [Int](repeating: 0, count: 4)
        for y in 0..<4 {
            // De troefkleur zelf: mijn kaarten tellen mee, de open troeven van
            // de tegenstander gaan eraf.
            for idx in 0..<8 {
                let nr = KjState.kaartNr(y, KjState.rangTroef[idx])
                let w = s.kaart[nr].dichtIkHy
                let p = s.kaart[nr].troefWaarde
                if w == mijnHand || w == mijnTafel { t[y] += p }
                else if w == hijTafel { t[y] -= p }
            }

            // Zijn zichtbare troeven die ik kan afdekken tellen dubbel: van
            // onderaf zijn kaarten, van bovenaf de mijne.
            var x = 7, z = 0
            while x > 0 {
                let nrX = KjState.kaartNr(y, KjState.rangTroef[x])
                if s.kaart[nrX].dichtIkHy != hijTafel { x -= 1; continue }
                let nrZ = KjState.kaartNr(y, KjState.rangTroef[z])
                let wz = s.kaart[nrZ].dichtIkHy
                if wz != mijnHand && wz != mijnTafel { break }
                t[y] += s.kaart[nrX].troefWaarde * 2
                z += 1
                x -= 1
            }

            for x in 0..<4 {
                var trh = 0, trt = 0, p1 = 0, p2 = 0
                let rang = (x == y) ? KjState.rangTroef : KjState.rangNorm
                for idx in 0..<8 {
                    let nr = KjState.kaartNr(x, rang[idx])
                    let w = s.kaart[nr].dichtIkHy
                    let hoog = idx == 0 ? 200 : idx == 1 ? 100 : idx == 2 ? 20 : 8 - idx
                    if w == mijnHand { if x == y { trh += 1 } else { p1 += hoog } }
                    else if w == mijnTafel { if x == y { trt += 1 } else { p2 += hoog } }
                }
                // Lengte telt kwadratisch, hand en tafel apart: vier troeven in
                // één stapel zijn meer waard dan twee-en-twee verdeeld.
                if x == y { t[y] += trh * trh + trt * trt }
                t[y] += ZoekAi.ladder(p1) + ZoekAi.ladder(p2)
            }
        }

        var beste = 0
        for x in 1..<4 where t[x] > t[beste] { beste = x }
        return beste
    }

    /// Drempels waarmee Loggen een zijkleur waardeert.
    private static func ladder(_ p: Int) -> Int {
        p >= 320 ? 6 : p >= 300 ? 5 : p >= 220 ? 4 : p >= 200 ? 3 : p > 100 ? 1 : 0
    }

    // -------------------------------------------------------- de zoektocht

    /// Welke stapel speelt de zoveelste kaart van de slag? De volgorde ligt
    /// vast: uitkomer, tafel van de tegenstander, andere stapel van de
    /// uitkomer, hand van de tegenstander. Waarden 1..4 zoals VRAGER.
    private static func vragerOpPlek(_ leider: Int, _ plek: Int) -> Int {
        switch plek {
        case 0: return leider
        case 1: return (leider == 1 || leider == 3) ? 4 : 3
        case 2:
            switch leider {
            case 1: return 3
            case 2: return 4
            case 3: return 1
            default: return 2
            }
        default: return (leider == 1 || leider == 3) ? 2 : 1
        }
    }

    private static func kantVan(_ vrager: Int) -> Int { vrager > 2 ? vrager - 2 : vrager }

    /// Kiest een kaart voor de stapel die aan zet is en zet die in s.lkaart /
    /// s.lkleur, net als de tactiekroutines van Ednieuw doen.
    public func kies() {
        let mijnKant = ZoekAi.kantVan(s.vrager)
        let plek = min(max(s.slagKrtNo, 0), 3)
        var leider = plek == 0 ? s.vrager : s[slag: s.slagNr, i: 0].speler
        if leider < 1 || leider > 4 { leider = s.vrager }

        var opTafel: [Zet] = []
        for n in 0..<plek {
            let sk = s[slag: s.slagNr, i: n]
            opTafel.append(Zet(kleur: sk.kleur, naam: sk.naam,
                               mijn: ZoekAi.kantVan(sk.speler) == mijnKant))
        }

        let bezit = eigenBezit(s.vrager > 2)
        if bezit.isEmpty { return }

        // De regelcontrole van de motor is doorslaggevend, niet mijn omzetting
        // van kjlegaal: checkValid heeft eigenaardigheden uit 1994 die daar niet
        // in zitten, en een kaart die hij afkeurt kost het hele spel.
        var kandidaten = bezit.filter(toegestaan)
        if kandidaten.isEmpty {
            kandidaten = legaleZetten(bezit, opTafel, slagIsVanMij(opTafel))
        }
        if kandidaten.isEmpty { kandidaten = bezit }

        var score = [Int](repeating: 0, count: kandidaten.count)
        for i in 0..<kandidaten.count {
            var proef = opTafel
            proef.append(Zet(kleur: kandidaten[i].kleur, naam: kandidaten[i].naam, mijn: true))
            let gebruikt: [Kaart] = [kandidaten[i]]
            score[i] = verder(proef, gebruikt, leider, mijnKant)
        }

        let beste = uitkiezen(kandidaten, score, opTafel)

        s.lkleur = kandidaten[beste].kleur
        s.lkaart = kandidaten[beste].naam
        s.tactiek = 70                       // 70 = gekozen door de zoekende speler
        s.vrager = e.wieVrager(s.lkaart, s.lkleur)
    }

    /// Kiest uit de doorgerekende kaarten, met de voorkeuren uit `kj2welke` en
    /// het slot van `kj2uitkom0`: bij gelijke opbrengst liever geen zekere slag
    /// weggeven en liever geen troef. De hoogste score wint pas als die
    /// voorkeuren niets opleveren, of als de opbrengst toch al nul of minder is.
    private func uitkiezen(_ kand: [Kaart], _ score: [Int], _ opTafel: [Zet]) -> Int {
        let leiden = opTafel.isEmpty
        let troefGeleid = !leiden && opTafel[0].kleur == s.troef
        let troefOp = s.troef >= 0 && s.troef < 4 && s.krtDicht[s.troef].len == 0

        func beste(_ mag: (Int) -> Bool) -> Int {
            var k = -1
            for i in 0..<kand.count {
                if !mag(i) { continue }
                if k < 0 || score[i] > score[k] { k = i }
            }
            return k
        }
        func zeker(_ i: Int) -> Bool { isZekereSlag(kand[i]) }
        func isTroef(_ i: Int) -> Bool { kand[i].kleur == s.troef }

        var k: Int
        if leiden {
            // Zijn alle troeven op, dan liever een gewone kaart uitspelen.
            if troefOp {
                k = beste { !isTroef($0) }
                if k >= 0 && score[k] > 0 { return k }
            }
            return max(0, beste { _ in true })
        }

        if !troefGeleid {
            k = beste { !zeker($0) && !isTroef($0) }
            if k >= 0 && score[k] > 0 { return k }
        }
        k = beste { !zeker($0) }
        if k >= 0 && score[k] > 0 { return k }
        return max(0, beste { _ in true })
    }

    /// Is dit een kaart die de slag vrijwel zeker pakt? De motor rekent dat al
    /// uit in vulhanden; dat is hetzelfde als de 'Z' die `kj2status` zet.
    private func isZekereSlag(_ kaart: Kaart) -> Bool {
        for n in 0..<8 where s.hand[0][n].naam == kaart.naam && s.hand[0][n].kleur == kaart.kleur {
            return s.hand[0][n].gegarandeerd != 0
        }
        for n in 0..<4 where s.tafel[0][n].naam == kaart.naam && s.tafel[0][n].kleur == kaart.kleur {
            return s.tafel[0][n].gegarandeerd != 0
        }
        return false
    }

    /// Keurt de regelcontrole van de motor deze kaart goed? Zij bepaalt of de
    /// zet doorgaat, dus daar moet de keuze op aansluiten.
    private func toegestaan(_ kaart: Kaart) -> Bool {
        let bewaardKaart = s.lkaart
        let bewaardKleur = s.lkleur
        s.lkaart = kaart.naam
        s.lkleur = kaart.kleur
        let goed = e.checkValid() == nil
        s.lkaart = bewaardKaart
        s.lkleur = bewaardKleur
        return goed
    }

    /// Staat de slag op dit moment op mijn naam?
    private func slagIsVanMij(_ opTafel: [Zet]) -> Bool {
        if opTafel.isEmpty { return false }
        let leidend = opTafel[0].kleur
        var troefErin = false
        for z in opTafel where z.kleur == s.troef { troefErin = true }
        let telt = troefErin ? s.troef : leidend
        var beste = 0, besteKracht = -1
        for i in 0..<opTafel.count {
            if opTafel[i].kleur != telt { continue }
            let k = kracht(opTafel[i].naam, opTafel[i].kleur)
            if k > besteKracht { besteKracht = k; beste = i }
        }
        return opTafel[beste].mijn
    }

    /// Vult de slag verder aan tot er vier kaarten liggen. Mijn eigen stapels
    /// kiezen het beste, de open tafel van de tegenstander het slechtste voor
    /// mij, en over zijn onbekende handkaart wordt gemiddeld — dat is de enige
    /// kaart die niemand kan zien.
    private func verder(_ opTafel: [Zet], _ gebruikt: [Kaart],
                        _ leider: Int, _ mijnKant: Int) -> Int {
        if opTafel.count >= 4 { return slagWaarde(opTafel) }

        let plek = opTafel.count
        let vrager = ZoekAi.vragerOpPlek(leider, plek)
        let isMijn = ZoekAi.kantVan(vrager) == mijnKant
        let slagVanMij = slagIsVanMij(opTafel)

        var bezit: [Kaart]
        if isMijn {
            bezit = eigenBezit(vrager > 2)
            bezit.removeAll { b in gebruikt.contains { $0.kleur == b.kleur && $0.naam == b.naam } }
        } else if vrager > 2 {
            bezit = tegenstanderTafel()                 // open, dus precies bekend
        } else {
            bezit = mogelijkeHand(opTafel.count > 0 ? opTafel[0].kleur : s.troef)
        }
        bezit.removeAll { b in opTafel.contains { $0.kleur == b.kleur && $0.naam == b.naam } }

        let zetten = legaleZetten(bezit, opTafel, isMijn ? slagVanMij : !slagVanMij)
        if zetten.isEmpty { return slagWaarde(ZoekAi.aanvullen(opTafel)) }

        if isMijn {
            var best = Int.min
            for z in zetten {
                var volgend = opTafel
                volgend.append(Zet(kleur: z.kleur, naam: z.naam, mijn: true))
                var nu = gebruikt
                nu.append(z)
                best = max(best, verder(volgend, nu, leider, mijnKant))
            }
            return best
        }

        if vrager > 2 {
            var slechtst = Int.max
            for z in zetten {
                var volgend = opTafel
                volgend.append(Zet(kleur: z.kleur, naam: z.naam, mijn: false))
                slechtst = min(slechtst, verder(volgend, gebruikt, leider, mijnKant))
            }
            return slechtst
        }

        var som = 0
        for z in zetten {
            var volgend = opTafel
            volgend.append(Zet(kleur: z.kleur, naam: z.naam, mijn: false))
            som += verder(volgend, gebruikt, leider, mijnKant)
        }
        return som / zetten.count
    }

    /// Vult een onvolledige slag aan met de laatst gelegde kaart, zodat er altijd
    /// gewaardeerd kan worden. Komt alleen voor als er niets legaals meer over is.
    private static func aanvullen(_ opTafel: [Zet]) -> [Zet] {
        var vier: [Zet] = []
        for i in 0..<4 { vier.append(i < opTafel.count ? opTafel[i] : opTafel[opTafel.count - 1]) }
        return vier
    }
}
