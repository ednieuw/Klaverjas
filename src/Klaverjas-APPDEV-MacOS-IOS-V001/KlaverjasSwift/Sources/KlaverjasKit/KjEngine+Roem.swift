/// Roemberekening. laagsteroem()/hoogsteroem() proberen alle mogelijke
/// verdelingen van de resterende kaarten van een kleur af en kiezen daaruit de
/// kaart die de minste resp. meeste roem weggeeft.
extension KjEngine {
    /// Roempunten van een reeks kaarten van één kleur.
    public func bepaalRoemPunten(_ str: CStr, _ kolor: Int) -> Int {
        var stuk = 0
        var i = 0, j = 0

        for n in 0..<8 {
            if str.pos(KjState.rangRoem[n]) != 0 {
                i += 1
                if i > j { j = i }
            } else { i = 0 }
        }

        if str.pos("V") != 0 && str.pos("H") != 0 && kolor == s.troef { stuk = 20 }

        if j == 3 { return stuk + 20 }   // drie opeenvolgend
        if j == 4 { return stuk + 50 }   // vier opeenvolgend

        if str.len == 4 {
            switch str.string {
            case "7777", "8888", "9999", "TTTT", "VVVV", "HHHH", "AAAA":
                stuk = 100; s.superroem += 1
            case "BBBB":
                stuk = 200; s.superroem += 1
            default:
                break
            }
        }
        return stuk
    }

    public func bepaalRoemPunten(_ str: String, _ kolor: Int) -> Int {
        let buf = CStr(str.count + 2)
        buf.cpy(str)
        return bepaalRoemPunten(buf, kolor)
    }

    /// Welke kaart van deze kleur levert de meeste roem op?
    public func hoogsteRoem(_ kkleur: Int) -> Teken {
        s.hoogste = 1
        let h = laagsteRoem(kkleur)
        s.hoogste = 0
        return h
    }

    /// Welke kaart van deze kleur geeft de minste roem weg (of, met s.hoogste
    /// gezet, de meeste)? Bouwt alle combinaties van één kaart per speler op en
    /// weegt die.
    public func laagsteRoem(_ kkleur: Int) -> Teken {
        if kkleur < 0 || kkleur > 3 { return .nul }

        var m: Int, i: Int, j: Int, c: Int
        let roemStr = CStr(16)
        var roempnt = [Int](repeating: 0, count: 64)
        let rr = CStr.new2(64, 16)
        let kt = CStr.new2(8, 16)   // kaarten van deze kleur per speler
        var t = [Int](repeating: 0, count: 8)
        var skaart: Teken

        var vrager = s.vrager
        if vrager > 2 { vrager -= 2 }

        for n in 0..<8 { t[n] = 0 }

        for n in (kkleur * 8)..<((kkleur + 1) * 8) where s.kaart[n].dichtIkHy < Pos.gespeeld {
            j = s.kaart[n].dichtIkHy
            if j > 10 { j = 1 - (vrager - 1) + 1 }   // net omgedraaide tafelkaart
            j -= 1
            if j < 0 { continue }                    // 0 = dicht, telt niet mee
            if j > 3 { continue }
            kt[j][t[j]] = s.kaart[n].naam
            kt[j][t[j] + 1] = .nul
            t[j] += 1
        }

        // Kaarten die deze slag al gespeeld zijn horen bij de roemreeks; de
        // spelers die ze legden doen niet meer mee.
        for n in 0..<s.slagKrtNo where s[slag: s.slagNr, i: n].kleur == kkleur {
            let sp = s[slag: s.slagNr, i: n].speler
            if sp >= 1 && sp <= 4 { kt[sp - 1].clear() }
            roemStr.append(s[slag: s.slagNr, i: n].naam)
        }

        KjEngine.sorteerOpLengte(kt)

        var aa = kt[0].len, bb = kt[1].len
        var cc = kt[2].len, dd = kt[3].len
        if aa == 0 { aa += 1 }
        if bb == 0 { bb += 1 }
        if cc == 0 { cc += 1 }
        if dd == 0 { dd += 1 }

        i = 0
        j = roemStr.len
        let aantal = kt[0].len * bb * cc * dd
        var a = 0
        while a < aantal && i < rr.count { rr[i].cpy(roemStr); i += 1; a += 1 }

        i = 0
        outer: for b in 0..<aa {
            for c2 in 0..<bb {
                for d in 0..<cc {
                    for e in 0..<dd {
                        if i >= rr.count { break outer }
                        rr[i][j + 0] = kt[0][b]
                        rr[i][j + 1] = kt[1][c2]
                        rr[i][j + 2] = kt[2][d]
                        rr[i][j + 3] = kt[3][e]
                        rr[i][j + 4] = .nul
                        i += 1
                    }
                }
            }
        }

        i = aa * bb * cc * dd
        if i > rr.count - 1 { i = rr.count - 1 }
        skaart = .nul

        if s.hoogste != 0 {
            m = 0
            for n in 0..<(i + 1) {
                roempnt[n] = bepaalRoemPunten(rr[n], kkleur)
                if m <= roempnt[n] {
                    // Aflopend door de kleur, zo eindig je bij de hoogste kaart.
                    for jj in stride(from: (kkleur + 1) * 8 - 1, through: kkleur * 8, by: -1)
                    where s.kaart[jj].dichtIkHy == s.vrager {
                        let len = rr[n].len
                        for aa2 in 0..<len where s.kaart[jj].naam == rr[n][aa2] {
                            skaart = rr[n][aa2]; m = roempnt[n]
                        }
                    }
                }
            }
            return skaart
        }

        m = 999; c = 999
        for n in 0..<i {
            roempnt[n] = bepaalRoemPunten(rr[n], kkleur)
            if m >= roempnt[n] {
                if m > roempnt[n] { c = 999 }
                // Oplopend door de kleur, zo eindig je bij de laagste kaart.
                for jj in (kkleur * 8)..<((kkleur + 1) * 8)
                where s.kaart[jj].dichtIkHy == s.vrager {
                    let len = rr[n].len
                    for aa2 in 0..<len where s.kaart[jj].naam == rr[n][aa2] {
                        if m > roempnt[n] {
                            c = s.kaart[jj].actWaarde; skaart = rr[n][aa2]; m = roempnt[n]
                        }
                        if m == roempnt[n] && c >= s.kaart[jj].actWaarde {
                            c = s.kaart[jj].actWaarde; skaart = rr[n][aa2]
                        }
                    }
                }
            }
        }
        return skaart
    }

    /// Hoogst haalbare roem als (kkleur, skaart) gespeeld wordt.
    public func bepaalHoogsteRoem(_ kkleur: Int, _ skaart: Teken) -> Int {
        s.hoogste = 1
        let r = bepaalLaagsteRoem(kkleur, skaart)
        s.hoogste = 0
        return r
    }

    /// Laagst haalbare roem als (kkleur, skaart) gespeeld wordt.
    public func bepaalLaagsteRoem(_ kkleur: Int, _ skaart: Teken) -> Int {
        if kkleur < 0 || kkleur > 3 { return 0 }

        var m: Int, i: Int, j: Int
        var roempnt = [Int](repeating: 0, count: 64)
        let rr = CStr.new2(64, 16)
        let kt = CStr.new2(8, 16)
        var t = [Int](repeating: 0, count: 8)

        // Het origineel roept wie_vrager() hier met verwisselde argumenten aan,
        // waardoor de uitkomst altijd "niet gevonden" (-1) is. Dat pad is hier
        // behouden zodat de kaartkeuze gelijk blijft aan het origineel.
        var vrager = wieVrager(Teken(raw: UInt8(truncatingIfNeeded: kkleur)), Int(skaart.raw))
        if vrager > 2 { vrager -= 2 }

        for n in 0..<8 { t[n] = 0 }

        for n in (kkleur * 8)..<((kkleur + 1) * 8) where s.kaart[n].dichtIkHy < Pos.gespeeld {
            j = s.kaart[n].dichtIkHy
            if j > 10 { j = 1 - (vrager - 1) + 1 }
            j -= 1
            if j < 0 { continue }
            if j > 3 { continue }
            kt[j][t[j]] = s.kaart[n].naam
            kt[j][t[j] + 1] = .nul
            if j + 1 == s.vrager {
                kt[4][t[j]] = s.kaart[n].naam
                kt[4][t[j] + 1] = .nul
            }
            t[j] += 1
        }
        kt[4].clear()

        // De te onderzoeken kaart wordt vastgezet in de string van zijn eigenaar.
        for n in 0..<4 {
            let len = kt[n].len
            for mm in 0..<len where kt[n][mm] == skaart {
                kt[n][0] = skaart; kt[n][1] = .nul
            }
        }

        KjEngine.sorteerOpLengte(kt)

        var aa = kt[0].len, bb = kt[1].len
        var cc = kt[2].len, dd = kt[3].len
        if aa == 0 { aa += 1 }
        if bb == 0 { bb += 1 }
        if cc == 0 { cc += 1 }
        if dd == 0 { dd += 1 }

        i = 0
        j = 0
        outer: for b in 0..<aa {
            for c in 0..<bb {
                for d in 0..<cc {
                    for e in 0..<dd {
                        if i >= rr.count { break outer }
                        rr[i][j + 0] = kt[0][b]
                        rr[i][j + 1] = kt[1][c]
                        rr[i][j + 2] = kt[2][d]
                        rr[i][j + 3] = kt[3][e]
                        rr[i][j + 4] = .nul
                        i += 1
                    }
                }
            }
        }

        i = aa * bb * cc * dd
        if i > rr.count - 1 { i = rr.count - 1 }

        if s.hoogste != 0 {
            m = 0
            for n in 0..<(i + 1) {
                roempnt[n] += bepaalRoemPunten(rr[n], kkleur)
                if m <= roempnt[n] { m = roempnt[n] }
            }
            return m
        }

        m = 999
        for n in 0..<i {
            roempnt[n] += bepaalRoemPunten(rr[n], kkleur)
            if m >= roempnt[n] { m = roempnt[n] }
        }
        return m
    }

    /// Bubbelsort van kt[0..4] op afnemende stringlengte, als in het origineel.
    static func sorteerOpLengte(_ kt: [CStr]) {
        let tmp = CStr(16)
        for _ in 0..<4 {
            for n in 0..<4 where kt[n].len < kt[n + 1].len {
                tmp.cpy(kt[n])
                kt[n].cpy(kt[n + 1])
                kt[n + 1].cpy(tmp)
                tmp.clear()
            }
        }
    }
}
