/// De spelmechanica uit KJJ.C: delen, handen vullen, kansberekening, roem,
/// slagbepaling en de regelcontrole. Alle schermuitvoer is eruit gestript; wat
/// overblijft is pure rekenlogica.
///
/// Het origineel is één groot bestand; de C#-versie splitste het in partials.
/// Hier doen extensions in de andere bestanden hetzelfde werk.
public final class KjEngine {
    public let s: KjState

    public init(zaad: Int? = nil) { s = KjState(zaad: zaad) }

    // Positie van elke kaart in de rij tafelkaarten (0..3); vervangt kaart[].postafel.
    var tafelPositie = [Int](repeating: 0, count: 32)

    /// true zolang de zet nog van de menselijke speler moet komen.
    public internal(set) var wachtOpMens = false

    // ---------------------------------------------------------------- Delen

    /// Deelt de 32 kaarten uit (Delen() uit KJJ.C).
    public func delen() {
        let pntwaarde = [11, 4, 3, 2, 10, 0, 0, 0]
        let troevwaarde = [11, 4, 3, 20, 10, 14, 0, 0]
        var wie = Pos.handZuid

        for n in 0..<32 { s.deeltabel[n] = n }

        var n = 1
        for m in stride(from: 31, through: 0, by: -1) {
            let card = s.random(m)
            s.kaart[s.deeltabel[card]].dichtIkHy = wie
            s.deeltabel[card] = s.deeltabel[m]
            if n == 8 { wie = Pos.handNoord }
            if n == 16 { wie = Pos.tafelZuid }
            if n == 20 { wie = Pos.tafelNoord }
            if n == 24 { wie = Pos.dichtZuid }
            if n == 28 { wie = Pos.dichtNoord }
            n += 1
        }

        for n in 0..<32 {
            let k = s.kaart[n]
            k.naam = KjState.rangRoem[n % 8]
            k.puntWaarde = pntwaarde[n % 8]
            k.troefWaarde = troevwaarde[n % 8]
            k.kleur = n / 8
        }

        for n in 1..<9 {
            for m in 0..<4 {
                s[slag: n, i: m].kleur = 9
                s[slag: n, i: m].naam = .nul
                s[slag: n, i: m].troef = 0
                s[slag: n, i: m].speler = 998
                s[slag: n, i: m].kans = -100
                s[slag: n, i: m].waarde = -100
                s[slag: n, i: m].tactiek = 255
            }
        }
    }

    // ----------------------------------------------------------- Vulhanden

    /// Bouwt hand[]/tafel[] opnieuw op vanuit het perspectief van de huidige
    /// VRAGER: index 0 is altijd "mijn" kant, index 1 de tegenpartij. Berekent
    /// meteen de slagkans van elke eigen kaart.
    public func vulhanden() {
        var mm = [Int](repeating: 0, count: 5)

        kaartenVrij()

        for wie in 0..<2 {
            for n in 0..<8 {
                s.hand[wie][n].naam = .nul
                s.hand[wie][n].kleur = 5
                s.hand[wie][n].waarde = 0
                s.hand[wie][n].troef = 0
                s.hand[wie][n].slagkans = -100
                if s.slagKrtNo == 0 { s.hand[wie][n].slagkans0 = -100 }

                s.tafel[wie][n].naam = .nul
                s.tafel[wie][n].kleur = 5
                s.tafel[wie][n].waarde = 5
                s.tafel[wie][n].troef = 0
                s.tafel[wie][n].slagkans = -100
                if s.slagKrtNo == 0 { s.tafel[wie][n].slagkans0 = -100 }
            }
        }

        let vraagkant = (s.vrager == 1 || s.vrager == 3) ? 1 : 2

        for n in 0..<32 {
            let k = s.kaart[n]
            let status = k.dichtIkHy

            if status == Pos.gespeeld { continue }
            if status == Pos.dicht { continue }
            if status > 30 { continue }

            let troefstatus = (s.troef == n / 8) ? 1 : 0
            k.troef = troefstatus

            var wie = (status == vraagkant) ? 1 : 2
            if status == vraagkant + 2 && status > 2 { wie = 3 }
            else if status > 2 { wie = 4 }

            if wie < 3 {
                s.hand[wie - 1][mm[wie]].naam = k.naam
                s.hand[wie - 1][mm[wie]].kleur = k.kleur
                s.hand[wie - 1][mm[wie]].waarde = k.actWaarde
                s.hand[wie - 1][mm[wie]].troef = troefstatus
                mm[wie] += 1
            } else {
                let twie = wie - 2
                s.tafel[twie - 1][mm[wie]].naam = k.naam
                s.tafel[twie - 1][mm[wie]].kleur = k.kleur
                s.tafel[twie - 1][mm[wie]].waarde = k.actWaarde
                s.tafel[twie - 1][mm[wie]].troef = troefstatus
                mm[wie] += 1
            }
        }

        for n in 0..<8 {
            s.hand[0][n].slagkans = bepaalSlagkans(s.hand[0][n].naam, s.hand[0][n].kleur)
            if s.slagKrtNo == 0 { s.hand[0][n].slagkans0 = s.hand[0][n].slagkans }
            s.hand[0][n].gegarandeerd = s.hand[0][n].slagkans > 95 ? 1 : 0
        }

        for n in 0..<4 {
            s.tafel[0][n].slagkans = bepaalSlagkans(s.tafel[0][n].naam, s.tafel[0][n].kleur)
            if s.slagKrtNo == 0 { s.tafel[0][n].slagkans0 = s.tafel[0][n].slagkans }
            s.tafel[0][n].gegarandeerd = s.tafel[0][n].slagkans > 95 ? 1 : 0
        }
    }

    // ------------------------------------------------------- kaarten_vrij

    /// Verdeelt alle 32 kaarten over "vrij" (nog in het spel), "weg" (gespeeld)
    /// en "dicht" (voor de vrager onzichtbaar), per kleur en totaal, en telt de
    /// kaarten per kleur in hand en op tafel.
    public func kaartenVrij() {
        let nop = CStr(40), vrij = CStr(40), weg = CStr(40), dicht = CStr(40)
        var q = [Int](repeating: 0, count: 5)

        for n in 0..<4 {
            s.iKrt[n][0] = 0; s.iKrt[n][1] = 0
            s.iKrtTafel[n][0] = 0; s.iKrtTafel[n][1] = 0
            s.kHand[0][n].clear(); s.kHand[1][n].clear()
            s.kTafel[0][n].clear(); s.kTafel[1][n].clear()
        }

        var vragert = s.vrager
        if vragert > 2 { vragert -= 2 }

        s.krtTotVrij.clear()
        s.krtTotDicht.clear()
        s.krtTotWeg.clear()
        s.iKrtGespeeld = 0

        var n = -1
        var i = 0
        for x in 0..<4 {
            var m = 0, o = 0, p = 0
            q[1] = 0; q[2] = 0; q[3] = 0; q[4] = 0
            i = x

            for _ in 0..<8 {
                n += 1
                let stat = s.kaart[n].dichtIkHy
                i = s.kaart[n].kleur
                var wie = 1
                if stat == vragert { wie = 0 }
                if stat - 2 == vragert { wie = 0 }

                if stat == Pos.handZuid {
                    s.iKrt[i][wie] += 1
                    s.kHand[wie][i][q[1]] = s.kaart[n].naam; q[1] += 1
                    s.kHand[wie][i][q[1]] = .nul
                    if stat != vragert { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
                }
                if stat == Pos.handNoord {
                    s.iKrt[i][wie] += 1
                    s.kHand[wie][i][q[2]] = s.kaart[n].naam; q[2] += 1
                    s.kHand[wie][i][q[2]] = .nul
                    if stat != vragert { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
                }
                if stat == Pos.tafelZuid {
                    s.iKrtTafel[i][wie] += 1
                    s.kTafel[wie][i][q[3]] = s.kaart[n].naam; q[3] += 1
                    s.kTafel[wie][i][q[3]] = .nul
                }
                if stat == Pos.tafelNoord {
                    s.iKrtTafel[i][wie] += 1
                    s.kTafel[wie][i][q[4]] = s.kaart[n].naam; q[4] += 1
                    s.kTafel[wie][i][q[4]] = .nul
                }

                if stat != Pos.gespeeld { s.krtVrij[i][m] = s.kaart[n].naam; m += 1 }
                if stat == Pos.gespeeld {
                    s.krtWeg[i][o] = s.kaart[n].naam; o += 1
                    s.iKrtGespeeld += 1
                }
                if stat == Pos.dicht { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
                if stat == Pos.dichtZuid { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
                if stat == Pos.dichtNoord { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
                if stat == Pos.nieuwZuid { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
                if stat == Pos.nieuwNoord { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
            }

            s.krtVrij[i][m] = .nul
            s.krtWeg[i][o] = .nul
            s.krtDicht[i][p] = .nul
        }

        for kolor in 0..<4 {
            nop.cpy(kolor == s.troef ? KjState.rangTroef : KjState.rangNorm)

            var m = 0, o = 0, p = 0
            for n in 0..<8 {
                let x = nop[n]
                if s.krtVrij[kolor].pos(x) != 0 { vrij[m] = nop[n]; m += 1 }
                if s.krtWeg[kolor].pos(x) != 0 { weg[o] = nop[n]; o += 1 }
                if s.krtDicht[kolor].pos(x) != 0 { dicht[p] = nop[n]; p += 1 }
            }
            vrij[m] = .nul
            weg[o] = .nul
            dicht[p] = .nul

            s.krtVrij[kolor].cpy(vrij)
            s.krtWeg[kolor].cpy(weg)
            s.krtDicht[kolor].cpy(dicht)
            s.krtTotVrij.cat(vrij)
            s.krtTotWeg.cat(weg)
            s.krtTotDicht.cat(dicht)
        }
    }

    // ------------------------------------------------------- kansrekening

    /// Hypergeometrische kans (guillermie() uit KJJ.C).
    /// a = totaal dichte kaarten, h = kaarten in de betreffende hand,
    /// z = resterende kaarten van die kleur, x = gevraagd aantal van die kleur,
    /// s = gevraagd aantal specifieke kaarten.
    public static func guillermie(_ a: Int, _ h: Int, _ z: Int, _ x: Int, _ sIn: Int) -> Double {
        let f = KjState.fact
        var s = sIn

        if h - x < 0 { return 1.0 }
        if a - h < 0 { return 1.0 }
        if a - z <= 0 { return 1.0 }
        if z - s < 0 { s = z }
        if x - s < 0 { s = x }
        if z - x < 0 { return 0.0 }
        if (a - z) - (h - x) < 0 { return 1.0 }

        if a >= f.count || h >= f.count || z >= f.count { return 0.0 }

        let aa = f[h] * f[a - h] / f[h - x] * f[a - z] * f[z - s]
        let bb = f[(a - z) - (h - x)] * f[x - s] * f[z - x]
        let cc = f[a]

        if aa == 0 { return 0.0 }
        if bb == 0 { return 1.0 }
        if cc == 0 { return 1.0 }

        return (aa / bb) / cc
    }

    /// Kans dat de tegenpartij een hogere kaart van die kleur heeft.
    public func kansHoger(_ kaartenhoger: Int, _ kleur: Int, _ specifiek: Int, _ vragerIn: Int) -> Double {
        var vrager = vragerIn
        if vrager > 2 { vrager -= 2 }
        if vrager < 1 || vrager > 2 { return 0 }
        if s.verzaakt[vrager - 1][kleur] != 0 { return 0 }
        if s.krtVrij[kleur].len == 0 { return 0 }

        let ts = 1
        let a = s.krtTotDicht.len
        let h = s.iKrt[0][ts] + s.iKrt[1][ts] + s.iKrt[2][ts] + s.iKrt[3][ts]
        let x = kaartenhoger
        let spec = specifiek
        let z = s.krtDicht[kleur].len

        if z == 0 { return 0 }
        if x == 0 { return 0 }
        if x >= KjState.fact.count { return 1.0 }

        var res = KjEngine.guillermie(a, h, z, x, spec) * KjState.fact[x]
        if res > 1.0 { res = 1.0 }
        return res
    }

    /// Kans dat de tegenpartij überhaupt nog een kaart van die kleur heeft.
    public func kansKaart(_ kleur: Int, _ specifiekIn: Int, _ vragerIn: Int) -> Double {
        var specifiek = specifiekIn
        var vrager = vragerIn
        if specifiek != 0 { specifiek = 1 }
        if vrager > 2 { vrager -= 2 }
        if vrager < 1 || vrager > 2 { return 0 }
        if s.verzaakt[vrager - 1][kleur] != 0 { return 0 }
        if s.krtVrij[kleur].len == 0 { return 0 }

        let ts = 1
        let a = s.krtTotDicht.len
        let h = s.iKrt[0][ts] + s.iKrt[1][ts] + s.iKrt[2][ts] + s.iKrt[3][ts]
        let x = 1
        let spec = 0
        let z = s.krtDicht[kleur].len

        if z == 0 { return 0 }
        if z >= KjState.fact.count { return 1.0 }

        var res = KjEngine.guillermie(a, h, z, x, spec) * KjState.fact[z]
        if res > 1.0 { res = 1.0 }
        return res
    }

    // ------------------------------------------------------------ hulpjes

    /// Aantal kaarten in ks dat volgens 'volgorde' hoger is dan kv.
    public static func hogere(_ kv: Teken, _ ks: CStr, _ volgorde: [Teken]) -> Int {
        let nop1 = CStr(20)
        if ks.len == 0 { return 0 }

        var n = 0
        while n < 8 && n < volgorde.count {
            if volgorde[n] != kv { nop1[n] = volgorde[n] }
            else { nop1[n] = .nul; break }
            n += 1
        }
        // Komt kv niet in de volgorde voor, dan sluiten we hier af. In het
        // origineel bleef nop1 dan ongetermineerd (undefined behaviour).
        if n >= 8 { nop1[8] = .nul }

        var i = 0
        let len = ks.len
        for m in 0..<len where nop1.pos(ks[m]) != 0 { i += 1 }
        return i
    }

    public static func hogere(_ kv: Teken, _ ks: String, _ volgorde: [Teken]) -> Int {
        let buf = CStr(ks.count + 2)
        buf.cpy(ks)
        return hogere(kv, buf, volgorde)
    }

    /// Waar bevindt kaart (kleur, karte) zich? Geeft dichtIkHy of -1.
    public func wieVrager(_ karte: Teken, _ kleur: Int) -> Int {
        // Bewust met bereikcontrole: één aanroep in het origineel
        // (bepaal_laagsteroem) verwisselt de argumenten en leest daardoor
        // buiten kaart[] - daar leverde dat een willekeurige waarde op, hier
        // netjes -1, wat ook het pad is dat het origineel bedoelde.
        let van = 8 * kleur, tot = (1 + kleur) * 8
        if van < 0 || tot > 32 { return -1 }
        for n in van..<tot where s.kaart[n].naam == karte { return s.kaart[n].dichtIkHy }
        return -1
    }

    /// Wie heeft de slag op dit moment (1..4)?
    public func wieSlag() -> Int {
        let st = CStr(8)
        var sp = [Int](repeating: 0, count: 8)
        var troef = false
        var m = 0

        var kkleur = s[slag: s.slagNr, i: 0].kleur

        for n in 0..<s.slagKrtNo where s[slag: s.slagNr, i: n].troef != 0 { troef = true }

        let slagvolgorde = troef ? KjState.rangTroef : KjState.rangNorm
        if troef { kkleur = s.troef }

        var i = 0
        for n in 0..<s.slagKrtNo where s[slag: s.slagNr, i: n].kleur == kkleur {
            st[i] = s[slag: s.slagNr, i: n].naam
            sp[i] = s[slag: s.slagNr, i: n].speler
            i += 1
        }
        st[i] = .nul

        i = 10
        let len = st.len
        for n in 0..<len {
            let j = CStr.pos(slagvolgorde, st[n])
            if j != 0 && j < i { i = j; m = sp[n] }
        }
        return m
    }

    // -------------------------------------------------------- slagkans

    /// Schat de kans (0..100) dat kaart (kleur, karte) de slag haalt.
    /// Dit is het hart van de AI: bepaal_slagkans() uit KJ.C.
    public func bepaalSlagkans(_ karte: Teken, _ kleur: Int) -> Int {
        let nop = CStr(40), nop1 = CStr(40)
        var d = 0, i = 0, j = 0, n = 0
        var kansHogerr: Double

        if karte == .nul { return -100 }
        if kleur < 0 || kleur > 3 { return -100 }

        var vrager = wieVrager(karte, kleur)
        if vrager > 10 { vrager /= 10 }
        if vrager > 2 { vrager -= 2 }
        let ts = 1
        let tss = (vrager == 1) ? 2 : 1

        nop.cpy(kleur == s.troef ? KjState.rangTroef : KjState.rangNorm)

        let posKaartvrager = KjEngine.hogere(karte, s.krtVrij[kleur], nop.tekens) + 1
        kansHogerr = (posKaartvrager == 1) ? 1 : 0

        i = 0; j = 0
        if s.slagKrtNo != 0 {
            for n in 0...s.slagKrtNo where s[slag: s.slagNr, i: n].troef != 0 && kleur != s.troef { return 0 }

            if s[slag: s.slagNr, i: 0].kleur != kleur && kleur != s.troef { return 0 }

            for n in 0...s.slagKrtNo where s[slag: s.slagNr, i: n].kleur == kleur {
                nop1[j] = s[slag: s.slagNr, i: n].naam; j += 1
            }
            nop1[j] = .nul
            i = KjEngine.hogere(karte, nop1, nop.tekens)
            if i > 0 { return 0 }
        }

        n = 0
        while n < 8 {
            if nop[n] != karte { nop1[n] = nop[n] }
            else { nop1[n] = .nul; break }
            n += 1
        }
        if n >= 8 { n = 8 }
        nop1[n] = .nul

        d = 1; j = 1
        if s.slagKrtNo != 0 {
            n = 0
            while n <= s.slagKrtNo {
                if s[slag: s.slagNr, i: n].speler == tss + 2 { j = 0 }
                n += 1
            }
            // Let op: in het origineel staat de volgende test buiten de lus,
            // met n al voorbij het laatste element. Dat is hier bewust zo
            // gelaten (de platte slag-array vangt de overloop net als in C op).
            if s[slag: s.slagNr, i: n].speler == tss { d = 0 }
        }

        if j != 0 && posKaartvrager > 1 && s.kTafel[ts][kleur].len > 0 {
            i = KjEngine.hogere(karte, s.kTafel[ts][kleur], nop.tekens)
            if i > 0 { return 0 }
        }

        if j != 0 && s.troef != 999 && kleur != s.troef {
            if s.iKrtTafel[kleur][ts] == 0 && s.iKrtTafel[s.troef][ts] != 0 { return 0 }
        }

        if i == 0 && d == 0 && s.slagKrtNo != 0 {
            for n in 0...s.slagKrtNo where s[slag: s.slagNr, i: n].speler == tss { return 100 }
        }

        let aantalHoger = KjEngine.hogere(karte, s.krtDicht[kleur], nop.tekens)
        if s.slagNr == 8 && KjEngine.hogere(karte, s.krtVrij[kleur], nop.tekens) != 0 { return 0 }

        if aantalHoger > 0 {
            kansHogerr = 1 - kansHoger(aantalHoger, kleur, 0, vrager)
        } else {
            kansHogerr = 1
            if s.troef < 0 || s.troef > 3 { return Int(kansHogerr * 100) }
            if s.krtDicht[s.troef].len == 0 { return Int(kansHogerr * 100) }
            if tss >= 1 && tss <= 2 && s.verzaakt[tss - 1][s.troef] != 0 { return Int(kansHogerr * 100) }
        }

        if kleur != s.troef && s.troef != 999 {
            if s.slagKrtNo == 8 && s.krtDicht[s.troef].len != 0 { return 0 }

            var kansKaartt: Double
            if s.krtDicht[kleur].len == 0 { kansKaartt = 0 }
            else { kansKaartt = kansKaart(kleur, 0, vrager) }

            if kansKaartt < 0.6 && s.krtDicht[s.troef].len != 0 {
                let kansTroefkaartt = kansKaart(s.troef, 0, vrager)
                kansKaartt = 1 - kansTroefkaartt
            }
            kansHogerr *= kansKaartt
        }

        return Int(kansHogerr * 100)
    }

    // ------------------------------------------------------------- troef

    /// Laat de computer troef kiezen (troef_bepalen() uit KJJ.C).
    public func troefBepalen() {
        var sompunten = [Int](repeating: 0, count: 4)
        var aantalkrt = [Int](repeating: 0, count: 4)
        var zekereslagen = [Int](repeating: 0, count: 4)
        var somtroefpunten = [Int](repeating: 0, count: 4)
        var hijtroef = [Int](repeating: 0, count: 4)
        var hijtroefpunten = [Int](repeating: 0, count: 4)

        s.troef = 999

        // In het origineel wordt Hijtafel alleen gezet als startvrager==1 en
        // blijft hij anders ongeinitialiseerd - juist het geval dat in een
        // menselijk spel altijd optreedt. Hier expliciet op de bedoelde waarde
        // gezet: de tafelkaarten van de tegenstander.
        let hijtafel = (s.startVrager == 1) ? Pos.tafelNoord : Pos.tafelZuid

        for n in 0..<32 {
            let status = s.kaart[n].dichtIkHy
            if status == s.startVrager || status == s.startVrager + 2 {
                sompunten[s.kaart[n].kleur] += s.kaart[n].troefWaarde
                somtroefpunten[s.kaart[n].kleur] += s.kaart[n].troefWaarde
                aantalkrt[s.kaart[n].kleur] += 1
            }
            if status == hijtafel { somtroefpunten[s.kaart[n].kleur] -= s.kaart[n].troefWaarde }
        }

        for n in 0..<32 where s.kaart[n].dichtIkHy == hijtafel {
            hijtroef[s.kaart[n].kleur] += 1
            hijtroefpunten[s.kaart[n].kleur] += s.kaart[n].troefWaarde
        }

        // Heb ik de boer van een kleur, tel dan de laagste troef van de
        // tegenstander mee.
        for n in 0..<4 {
            let status = s.kaart[n * 8 + 3].dichtIkHy
            if status == s.startVrager || status == s.startVrager + 2 {
                for m in stride(from: 8 * (n + 1), through: n * 8, by: -1) {
                    if m > 31 { continue }   // het origineel liep hier buiten kaart[]
                    if s.kaart[m].dichtIkHy == hijtafel {
                        somtroefpunten[n] += 2 * s.kaart[n].troefWaarde
                        break
                    }
                }
            }
        }

        for n in 0..<8 where s.tafel[s.vrager - 1][n].gegarandeerd != 0 {
            zekereslagen[s.tafel[s.vrager - 1][n].kleur] += 1
        }

        for n in 0..<8 where s.hand[s.vrager - 1][n].gegarandeerd != 0 {
            zekereslagen[s.hand[s.vrager - 1][n].kleur] += 1
        }

        for n in 0..<4 {
            somtroefpunten[n] += 3 * zekereslagen[n] + 2 * aantalkrt[n]
        }

        // sompunten, hijtroef en hijtroefpunten worden in het origineel wel
        // gevuld maar nergens gelezen. Ze blijven staan zodat de vertaling
        // naast de C-code te leggen valt.
        _ = (sompunten, hijtroef, hijtroefpunten)

        var m = 0
        for n in 0..<4 where somtroefpunten[n] > m { m = somtroefpunten[n]; s.troef = n }

        if s.troef == 999 { s.troef = 0 }
        zetActWaarden()
    }

    /// Zet de actuele kaartwaarden zodra troef bekend is.
    public func zetActWaarden() {
        for n in 0..<32 {
            s.kaart[n].actWaarde = (s.kaart[n].kleur == s.troef)
                ? s.kaart[n].troefWaarde
                : s.kaart[n].puntWaarde
        }
    }

    // ----------------------------------------------------------- legkaart

    /// Legt een kaart op tafel. Geeft false als de kaart niet van de vrager is
    /// (dan heeft de AI verzaakt of klikte de speler op een verkeerde kaart).
    /// Draait daarbij zonodig een dichte tafelkaart om.
    @discardableResult
    public func legKaart(_ skaart: Teken, _ skleur: Int, _ vrager: Int) -> Bool {
        if skleur < 0 || skleur > 3 || skaart == .nul { return false }

        var vragert = wieVrager(skaart, skleur)
        let speler = vragert
        if vragert != vrager { return false }       // verkeerde kaart
        if vragert == Pos.gespeeld { return false } // al gespeeld
        if vragert > 4 { return false }             // dichte kaart
        if vragert > 2 { vragert -= 2 }

        let krtno = KjState.kaartNr(skleur, skaart)

        s[slag: s.slagNr, i: s.slagKrtNo].kleur = skleur
        s[slag: s.slagNr, i: s.slagKrtNo].naam = skaart
        s[slag: s.slagNr, i: s.slagKrtNo].speler = s.vrager
        s[slag: s.slagNr, i: s.slagKrtNo].waarde = s.kaart[krtno].actWaarde
        s[slag: s.slagNr, i: s.slagKrtNo].kans = bepaalSlagkans(skaart, skleur)
        s[slag: s.slagNr, i: s.slagKrtNo].tactiek = s.tactiek
        s[slag: s.slagNr, i: s.slagKrtNo].troef = (skleur == s.troef) ? 1 : 0

        s.kaart[krtno].dichtIkHy = Pos.gespeeld
        s.slagKrtNo += 1

        if speler > 2 {
            let postafel = min(max(tafelPos(krtno), 0), 3)
            if speler == Pos.tafelZuid && s.tZuid[postafel] == 0 { return true }
            if speler == Pos.tafelNoord && s.tNoord[postafel] == 0 { return true }

            let bijlegger = (speler == Pos.tafelZuid) ? Pos.dichtZuid : Pos.dichtNoord

            // Kies willekeurig een van de resterende dichte kaarten om om te draaien.
            let j = s.random(8) + 1
            var n = 0, i = 0
            while true {
                if s.kaart[n].dichtIkHy == bijlegger { i += 1 }
                if i == j { break }
                n += 1
                if n > 31 { n = 0; if i == 0 { return true } }
            }

            tafelPositie[n] = postafel
            if speler == Pos.tafelZuid { s.tZuid[postafel] = 0 }
            else { s.tNoord[postafel] = 0 }

            // De omgedraaide kaart wordt pas de volgende slag een echte
            // tafelkaart; tot die tijd 33->13 resp. 44->14.
            if s.kaart[n].dichtIkHy > 30 { s.kaart[n].dichtIkHy = s.kaart[n].dichtIkHy / 10 + 10 }
        }
        return true
    }

    /// Plek 0..3 van een tafelkaart in de rij.
    public func tafelPos(_ krtno: Int) -> Int { tafelPositie[krtno] }

    /// Kent de tafelkaarten hun plek 0..3 toe (wat leg_tafel() in KJJ.C deed).
    public func zetTafelPosities() {
        var i = 0
        for n in 0..<32 where s.kaart[n].dichtIkHy == Pos.tafelZuid { tafelPositie[n] = i; i += 1 }
        i = 0
        for n in 0..<32 where s.kaart[n].dichtIkHy == Pos.tafelNoord { tafelPositie[n] = i; i += 1 }
    }

    /// Maakt net omgedraaide tafelkaarten (13/14) tot echte tafelkaarten.
    public func updateTafel() {
        for n in 0..<32 {
            if s.kaart[n].dichtIkHy == Pos.nieuwZuid { s.kaart[n].dichtIkHy = Pos.tafelZuid }
            if s.kaart[n].dichtIkHy == Pos.nieuwNoord { s.kaart[n].dichtIkHy = Pos.tafelNoord }
        }
    }

    // ---------------------------------------------------------- evalueren

    /// Telt punten en roem van de zojuist gespeelde slag, en geeft terug wat
    /// die slag opleverde zodat de UI het kan melden.
    @discardableResult
    public func evalueer() -> SlagUitslag {
        let sp = CStr(8)
        var punten = 0

        for n in 0..<4 { punten += s[slag: s.slagNr, i: n].waarde }

        s.startVrager = wieSlag()
        if s.startVrager > 2 { s.startVrager -= 2 }
        if s.startVrager < 1 || s.startVrager > 2 { s.startVrager = 1 }
        s.puntenSpel[s.startVrager - 1] += punten

        var roem = 0
        for rkleur in 0..<4 {
            var i = 0
            for n in 0..<4 where s[slag: s.slagNr, i: n].kleur == rkleur {
                sp[i] = s[slag: s.slagNr, i: n].naam; i += 1
            }
            sp[i] = .nul
            if sp.len > 1 {
                roem += bepaalRoemPunten(sp, rkleur)
            }
        }

        // Vier gelijke kaarten, over de hele slag in plaats van per kleur.
        //
        // Het origineel kent deze roem wel — bepaalroempunten() heeft er een
        // tak voor, met een pieptoon en al — maar kan er nooit komen: evalueer()
        // groepeert de vier kaarten eerst op kleur, en vier gelijke kaarten
        // hebben per definitie vier verschillende kleuren. Elk groepje bevat er
        // dan precies één, en bij één kaart wordt bepaalroempunten() niet eens
        // aangeroepen. De teller Superroem stond daardoor altijd op nul.
        //
        // Hier wordt de bedoelde regel alsnog uitgevoerd. Dit is de enige plek
        // waar de Swift-versie bewust anders rekent dan de C#-versie; het komt
        // ongeveer eens per 1700 spellen voor.
        let namen = (0..<4).map { s[slag: s.slagNr, i: $0].naam }
        if namen[0] != .nul && namen.allSatisfy({ $0 == namen[0] }) {
            roem += (namen[0] == "B") ? 200 : 100
            s.superroem += 1
        }

        s.roem[s.startVrager - 1] += roem

        var laatsteSlag = 0
        if s.slagNr == 8 {
            laatsteSlag = 10
            s.roem[s.startVrager - 1] += laatsteSlag
        }

        if s[slag: s.slagNr, i: 0].kleur != s[slag: s.slagNr, i: 3].kleur {
            let sp3 = s[slag: s.slagNr, i: 3].speler
            if sp3 >= 1 && sp3 <= 2 {
                s.verzaakt[sp3 - 1][s[slag: s.slagNr, i: 0].kleur] = 1
            }
        }

        return SlagUitslag(punten: punten, roem: roem, laatsteSlag: laatsteSlag)
    }

    /// Sluit een heel spel (8 slagen) af en verwerkt pit, nat en de stand.
    @discardableResult
    public func evalueerSpel() -> String {
        if s.speler > 2 { s.speler -= 2 }
        s.slagNr -= 1
        var n = wieSlag()
        if n > 2 { n -= 2 }
        _ = n    // het origineel berekent dit wel, maar gebruikt het niet

        if s.puntenSpel[0] == 152 { s.roem[0] += 100; s.pit[0] += 1 }
        if s.puntenSpel[1] == 152 { s.roem[1] += 100; s.pit[1] += 1 }
        if s.puntenSpel[0] == 152 && s.speler == 2 { s.roem[0] += 200; s.tpit[0] += 1 }
        if s.puntenSpel[1] == 152 && s.speler == 1 { s.roem[1] += 200; s.tpit[1] += 1 }

        var a = s.puntenSpel[0] + s.roem[0]
        var b = s.puntenSpel[1] + s.roem[1]

        var nat = false
        if s.speler == 1 && a <= b { b += a; a = 0; s.nat[0] += 1; nat = true }
        if s.speler == 2 && b <= a { a += b; b = 0; s.nat[1] += 1; nat = true }

        s.puntenTotaalSpel[0] += Int64(a)
        s.puntenTotaalSpel[1] += Int64(b)
        if a < b { s.gewonnenTot[1] += 1 } else { s.gewonnenTot[0] += 1 }
        s.roempnt[0] += Int64(s.roem[0])
        s.roempnt[1] += Int64(s.roem[1])
        s.puntenSpel[0] = 0; s.puntenSpel[1] = 0
        s.roem[0] = 0; s.roem[1] = 0
        s.slagNr += 1

        var uitslag = Taal.wintDitSpel(a > b)
                    + (nat ? Taal.tegenpartijNat : "")
                    + Taal.standen(a, b)

        for n in 0..<4 { s.verzaakt[0][n] = 0; s.verzaakt[1][n] = 0 }

        if s.puntenTotaalSpel[0] >= 1500 || s.puntenTotaalSpel[1] >= 1500 {
            if s.puntenTotaalSpel[0] > s.puntenTotaalSpel[1] { s.gewonnen[0] += 1 }
            else { s.gewonnen[1] += 1 }
            if s.puntenTotaalSpel[0] == s.puntenTotaalSpel[1] { s.gewonnen[0] += 1 }
            s.puntenTotaalSpel[0] = 0
            s.puntenTotaalSpel[1] = 0
            uitslag += Taal.partijUit
        }
        return uitslag
    }
}
