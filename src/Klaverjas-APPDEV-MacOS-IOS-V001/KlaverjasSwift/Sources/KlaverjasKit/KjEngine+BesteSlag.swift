/// bekijk_beste_slag() uit KJ.C: kiest de bij te spelen kaart als de vaste
/// tactieken van speler1/speler2/tegenspeler geen uitkomst gaven. Werkt van
/// "ik kan de slag halen" via "ik kan roem pakken" naar "gooi maar wat".
extension KjEngine {
    public func bekijkBesteSlag(_ skleurIn: Int) {
        var skleur = skleurIn
        var w: Int, m: Int, i: Int, j: Int, ii: Int
        var rkleur = 0
        var kt = 0, kh = 0
        var troeff = false
        var skaart: Teken = .nul

        let slagstring = CStr(16)
        let troefstring = CStr(16)
        let roem = CStr(16)

        let slagvolgorde = s[slag: s.slagNr, i: 0].troef != 0 ? KjState.rangTroef : KjState.rangNorm

        i = 0
        for n in 0...s.slagKrtNo where s[slag: s.slagNr, i: n].troef != 0 {
            troefstring[i] = s[slag: s.slagNr, i: n].naam; i += 1
        }
        troefstring[i] = .nul

        if s[slag: s.slagNr, i: 0].troef == 0 {
            for n in stride(from: 1, through: s.slagKrtNo, by: 1)
            where s[slag: s.slagNr, i: n].troef != 0 {
                troeff = true   // er is ingetroefd
            }
        }

        i = 0
        for n in 0..<4 where s[slag: s.slagNr, i: n].kleur == skleur {
            slagstring[i] = s[slag: s.slagNr, i: n].naam; i += 1
        }
        slagstring[i] = .nul

        // skleur verandert onderweg: sommige takken nemen de kleur over van een
        // lege hand- of tafelpositie, en die staat op 5. Het origineel las dan
        // buiten kaart[] (wat toevallig niets opleverde); daarom hier telkens
        // opnieuw controleren in plaats van eenmalig vooraf.
        func kleurOk() -> Bool { skleur >= 0 && skleur < 4 }

        // ------------------------------------------------ tweede kaart
        if s.slagKrtNo == 1 {
            ii = -50
            if kleurOk() && s.iKrtTafel[skleur][0] != 0 {
                for n in 0..<4 where s.tafel[0][n].kleur == skleur && ii < s.tafel[0][n].slagkans {
                    ii = s.tafel[0][n].slagkans; kt = n
                }
            }

            if ii > KjState.slagkansLevel { skaart = s.tafel[0][kt].naam; s.tactiek = 16 }
        }

        // ------------------------------------------------- derde kaart
        if s.slagKrtNo == 2 {
            i = -50
            ii = -50
            if s.vrager > 2 && kleurOk() && s.iKrtTafel[skleur][0] != 0 {
                for n in 0..<4 where s.tafel[0][n].kleur == skleur && ii < s.tafel[0][n].slagkans {
                    ii = s.tafel[0][n].slagkans; kt = n
                }

                if ii > s[slag: s.slagNr, i: 0].kans && ii > KjState.slagkansLevel {
                    s.tactiek = 21; skaart = s.tafel[0][kt].naam
                }

                if skaart == .nul && wieSlag() == s.vrager - 2
                    && s[slag: s.slagNr, i: 0].kans > KjState.slagkansLevel {
                    s.tactiek = 22; skaart = hoogsteRoem(skleur)
                }
            }
            if s.vrager < 3 && kleurOk() && s.iKrt[skleur][0] != 0 {
                for n in 0..<8 where s.hand[0][n].kleur == skleur && i < s.hand[0][n].slagkans {
                    i = s.hand[0][n].slagkans; kh = n
                }

                if i > s[slag: s.slagNr, i: 0].kans && i > KjState.slagkansLevel {
                    skaart = s.hand[0][kh].naam; s.tactiek = 49
                }

                if skaart == .nul {
                    if wieSlag() == s.vrager + 2 && s[slag: s.slagNr, i: 0].kans > KjState.slagkansLevel {
                        s.tactiek = 4; skaart = hoogsteRoem(skleur)
                    } else {
                        s.tactiek = 23
                        skaart = laagsteRoem(skleur)
                        if skaart == "T" { skaart = .nul }
                    }
                }
            }
        }

        // ------------------------------------------------ laatste kaart
        if s.slagKrtNo == 3 {
            i = 0
            if wieSlag() == s.vrager + 2 {      // de slag is al aan mijn kant
                for n in 0..<s.slagKrtNo where s[slag: s.slagNr, i: n].kleur == skleur {
                    roem.append(s[slag: s.slagNr, i: n].naam)
                }

                j = roem.len
                for n in 0..<8 where s.hand[0][n].kleur == skleur {
                    roem[j] = s.hand[0][n].naam
                    roem[j + 1] = .nul
                    ii = bepaalRoemPunten(roem, skleur)
                    if ii > i { i = ii; s.tactiek = 24; skaart = s.hand[0][n].naam }
                }

                if skaart == .nul {
                    i = 0
                    for n in 0..<s.slagKrtNo where s[slag: s.slagNr, i: n].kleur == skleur {
                        roem.append(s[slag: s.slagNr, i: n].naam)
                    }

                    j = roem.len
                    for n in 0..<8 where s.hand[0][n].kleur == skleur
                        && KjEngine.hogere(s.hand[0][n].naam, slagstring, slagvolgorde) == 0 {
                        roem[j] = s.hand[0][n].naam
                        roem[j + 1] = .nul
                        ii = bepaalRoemPunten(roem, skleur)
                        if ii > i { i = ii; s.tactiek = 48; skaart = s.hand[0][n].naam }
                    }
                }
            }

            if skaart == .nul && !troeff {     // is er een hogere kaart?
                for n in 0..<8 where s.hand[0][n].kleur == skleur && skleur != s.troef
                    && KjEngine.hogere(s.hand[0][n].naam, slagstring, slagvolgorde) == 0 {
                    skaart = s.hand[0][n].naam; s.tactiek = 46
                }
            }

            if skaart == .nul { skaart = laagsteRoem(skleur); s.tactiek = 3 }
        }

        // ------------------------------------- kan ik de kleur bekennen?
        if skaart == .nul {
            if !kleurOk() { i = 0 }
            else { i = (s.vrager < 3) ? s.iKrt[skleur][0] : s.iKrtTafel[skleur][0] }

            if i == 0 {   // niet bekennen: troeven of afgooien
                if s.slagKrtNo > 1 {
                    j = (s.vrager > 2) ? s.vrager - 2 : s.vrager
                    m = wieSlag()
                    if m > 2 { m -= 2 }

                    if j == m {   // slag staat al op mijn naam
                        if s[slag: s.slagNr, i: s.slagKrtNo - 2].kans < KjState.slagkansLevel {
                            if s.vrager > 2 && s.iKrtTafel[s.troef][0] != 0 {
                                i = 1000
                                for n in 0..<4 where s.tafel[0][n].kleur == s.troef && troeff
                                    && KjEngine.hogere(s.tafel[0][n].naam, troefstring, KjState.rangTroef) == 0
                                    && s.tafel[0][n].slagkans < i {
                                    i = s.tafel[0][n].slagkans
                                    skaart = s.tafel[0][n].naam
                                    skleur = s.troef
                                    s.tactiek = 26
                                }
                            }
                            if s.vrager < 3 && s.iKrt[s.troef][0] != 0 {
                                i = 1000
                                for n in 0..<8 where s.hand[0][n].kleur == s.troef && troeff
                                    && KjEngine.hogere(s.hand[0][n].naam, troefstring, KjState.rangTroef) == 0
                                    && s.hand[0][n].slagkans < i {
                                    i = s.hand[0][n].slagkans
                                    skaart = s.hand[0][n].naam
                                    skleur = s.troef
                                    s.tactiek = 27
                                }
                            }
                        }
                    } else {   // slag aan de tegenpartij: overtroeven als het kan
                        if s.vrager > 2 && s.iKrtTafel[s.troef][0] != 0 {
                            i = 1000
                            for n in 0..<4 where s.tafel[0][n].kleur == s.troef
                                && KjEngine.hogere(s.tafel[0][n].naam, troefstring, KjState.rangTroef) == 0
                                && s.tafel[0][n].slagkans != 0 && s.tafel[0][n].waarde < i {
                                i = s.tafel[0][n].waarde
                                skaart = s.tafel[0][n].naam
                                skleur = s.troef
                                s.tactiek = 28
                            }
                        }
                        if s.vrager < 3 && s.iKrt[s.troef][0] != 0 {
                            i = 1000
                            for n in 0..<8 where s.hand[0][n].kleur == s.troef
                                && KjEngine.hogere(s.hand[0][n].naam, troefstring, KjState.rangTroef) == 0
                                && s.hand[0][n].slagkans != 0 && s.hand[0][n].waarde < i {
                                i = s.hand[0][n].waarde
                                skaart = s.hand[0][n].naam
                                s.tactiek = 29
                                skleur = s.troef
                            }
                        }
                    }
                }

                if skaart == .nul && s.slagKrtNo < 2 {
                    if s.vrager > 2 && s.iKrtTafel[s.troef][0] != 0 {
                        i = 1000
                        for n in 0..<4 where s.tafel[0][n].kleur == s.troef {
                            m = s.tafel[0][n].slagkans
                            if i < m && i != 0 {
                                i = s.tafel[0][n].slagkans
                                skaart = s.tafel[0][n].naam
                                skleur = s.troef
                                s.tactiek = 30
                            }
                        }
                    }
                    if s.vrager < 3 && s.iKrt[s.troef][0] != 0 {
                        i = 1000
                        for n in 0..<8 where s.hand[0][n].kleur == s.troef {
                            m = s.hand[0][n].slagkans
                            if i < m && i != 0 {
                                i = s.hand[0][n].slagkans
                                skaart = s.hand[0][n].naam
                                skleur = s.troef
                                s.tactiek = 31
                            }
                        }
                    }
                }
            }
        }

        // Is er ingetroefd en kan ik niet overtroeven, dan vervalt de keuze.
        if skaart != .nul && s[slag: s.slagNr, i: 0].troef == 0 {
            for n in stride(from: 1, to: s.slagKrtNo, by: 1)
            where s[slag: s.slagNr, i: n].troef != 0
                && CStr.pos(KjState.rangTroef, s[slag: s.slagNr, i: n].naam)
                   < CStr.pos(KjState.rangTroef, skaart) {
                skaart = .nul; s.tac[59] += 1; s.tactiek = 59
            }
        }

        if skaart == .nul {
            for n in 0..<32 where s.kaart[n].dichtIkHy == s.vrager && s.kaart[n].kleur == skleur {
                i = wieSlag(); ii = i
                if ii > 2 { ii -= 2 }
                j = s.vrager
                if j > 2 { j -= 2 }
                if ii == j {
                    for m in 0..<s.slagKrtNo {
                        if s[slag: s.slagNr, i: m].speler == i && s[slag: s.slagNr, i: m].kans > 50 {
                            s.tactiek = 43; skaart = hoogsteRoem(skleur)
                        } else {
                            s.tactiek = 32; skaart = laagsteRoem(skleur)
                        }
                    }
                }
            }
        }

        // ----------------------------------------- niet kunnen bekennen
        if skaart == .nul {
            i = wieSlag(); ii = i
            if ii > 2 { ii -= 2 }
            j = s.vrager
            if j > 2 { j -= 2 }

            if ii == j {   // slag is aan mij
                for m in 0..<s.slagKrtNo where s[slag: s.slagNr, i: m].speler == i
                    && s[slag: s.slagNr, i: m].kans > 75 {
                    if s.vrager < 3 {      // uit de hand
                        for jj in 0..<8 {
                            let kl = s.hand[0][jj].kleur
                            if kl < 0 || kl > 3 { continue }
                            if s.hand[0][jj].naam == "T" && s.iKrt[kl][0] == 1 {
                                if s.kTafel[0][kl].pos("A") == 0 &&              // geen aas op tafel
                                   KjEngine.hogere("T", s.krtVrij[kl], slagvolgorde) != 0 { // nog hogere in het spel
                                    skaart = s.hand[0][jj].naam
                                    skleur = kl
                                    s.tactiek = 51
                                }
                            }
                        }
                        if skaart == .nul {   // gooi de hoogste rommel bij
                            w = -1
                            for jj in 0..<8 where s.hand[0][jj].waarde > w
                                && s.hand[0][jj].slagkans0 < KjState.slagkansLevel + 10
                                && s.hand[0][jj].kleur != s.troef
                                && s.hand[0][jj].naam != "A" {
                                w = s.hand[0][jj].waarde
                                skaart = s.hand[0][jj].naam
                                skleur = s.hand[0][jj].kleur
                                s.tactiek = 68
                            }
                        }
                    } else {               // van tafel
                        for jj in 0..<4 {
                            let kl = s.tafel[0][jj].kleur
                            if kl < 0 || kl > 3 { continue }
                            if s.tafel[0][jj].naam == "T" && s.iKrt[kl][0] == 1 {
                                if s.kHand[0][kl].pos("A") == 0 &&
                                   KjEngine.hogere("T", s.krtVrij[kl], slagvolgorde) != 0 {
                                    skaart = s.tafel[0][jj].naam
                                    skleur = kl
                                    s.tactiek = 52
                                }
                            }
                        }
                        if skaart == .nul {
                            w = -1
                            for jj in 0..<4 where s.tafel[0][jj].waarde > w
                                && s.tafel[0][jj].slagkans0 < KjState.slagkansLevel + 10
                                && s.tafel[0][jj].kleur != s.troef
                                && s.tafel[0][jj].naam != "A" {
                                w = s.tafel[0][jj].waarde
                                skaart = s.tafel[0][jj].naam
                                skleur = s.tafel[0][jj].kleur
                                s.tactiek = 69
                            }
                        }
                    }
                }

                // Alleen introeven als daar roem mee te halen valt.
                if skaart == .nul && s.vrager < 3 && s.iKrt[s.troef][0] != 0 && s.slagKrtNo == 2 {
                    m = 999
                    for n in 0..<8 where s.hand[0][n].troef != 0 && s.hand[0][n].slagkans > 20
                        && m > s.hand[0][n].slagkans {
                        m = s.hand[0][n].slagkans; skaart = s.hand[0][n].naam; rkleur = s.troef
                    }

                    if skaart != .nul {
                        m = 0
                        roem.cpy(slagstring)
                        if kansKaart(rkleur, 1, s.vrager) > 0.3 && kleurOk() {
                            let lenDicht = s.krtDicht[skleur].len
                            let lenSlag = slagstring.len
                            for n in 0..<lenDicht {
                                roem[lenSlag] = s.krtDicht[skleur][n]
                                roem[lenSlag + 1] = .nul
                                i = bepaalRoemPunten(roem, skleur)
                                if i > m { m = i }
                            }
                        }
                        if m == 0 { skaart = .nul }
                        else { s.tactiek = 60; skleur = s.troef }
                    }
                }

                if skaart == .nul && s.vrager > 2 && s.iKrt[s.troef][0] != 0 && s.slagKrtNo == 2 {
                    m = 999
                    for n in 0..<8 where s.tafel[0][n].troef != 0 && s.tafel[0][n].slagkans > 20
                        && m > s.tafel[0][n].slagkans {
                        m = s.tafel[0][n].slagkans; skaart = s.tafel[0][n].naam; rkleur = s.troef
                    }

                    if skaart != .nul {
                        m = 0
                        roem.cpy(slagstring)
                        if kansKaart(rkleur, 1, s.vrager) > 0.30 && kleurOk() {
                            let lenDicht = s.krtDicht[skleur].len
                            let lenSlag = slagstring.len
                            for n in 0..<lenDicht {
                                roem[lenSlag] = s.krtDicht[skleur][n]
                                roem[lenSlag + 1] = .nul
                                i = bepaalRoemPunten(roem, skleur)
                                if i > m { m = i }
                            }
                        }
                        if m == 0 { skaart = .nul }
                        else { s.tactiek = 25; skleur = s.troef }
                    }
                }
            }
        }

        // ------------------------------------------------- restcategorie
        if skaart == .nul && kleurOk() {
            for n in (8 * skleur)..<(8 * (skleur + 1)) where s.kaart[n].dichtIkHy == s.vrager {
                skaart = laagsteRoem(skleur); s.tactiek = 34
            }
        }

        if skaart == .nul && skleur != s.troef && kleurOk() {
            m = 99
            for n in (8 * skleur)..<(8 * (skleur + 1)) where s.kaart[n].dichtIkHy == s.vrager {
                i = s.kaart[n].actWaarde
                if i < m { m = i; skaart = s.kaart[n].naam; s.tactiek = 33 }
            }
        }

        // Ingetroefd: hogere troef bijgooien.
        if skaart == .nul && troeff {
            let geenKleur = kleurOk()
                ? ((s.vrager < 3 && s.iKrt[skleur][0] == 0) || (s.vrager > 2 && s.iKrtTafel[skleur][0] == 0))
                : true
            if geenKleur {
                ii = wieSlag()
                if ii > 2 { ii -= 2 }
                j = s.vrager
                if j > 2 { j -= 2 }
                if ii != j {
                    i = 9
                    let lenTroef = troefstring.len
                    for m in 0..<lenTroef where CStr.pos(KjState.rangTroef, troefstring[m]) < i {
                        i = CStr.pos(KjState.rangTroef, troefstring[m])
                    }

                    j = 99
                    for n in stride(from: 8 * (s.troef + 1) - 1, through: 8 * s.troef, by: -1)
                    where s.kaart[n].dichtIkHy == s.vrager
                        && CStr.pos(KjState.rangTroef, s.kaart[n].naam) < i {
                        j = n
                    }

                    if j < 33 { skaart = s.kaart[j].naam; skleur = s.kaart[j].kleur; s.tactiek = 64 }
                }
            }
        }

        // Niet ingetroefd en geen kleur: laagste troef bijgooien.
        if skaart == .nul && !troeff {
            let geenKleur = kleurOk()
                ? ((s.vrager < 3 && s.iKrt[skleur][0] == 0) || (s.vrager > 2 && s.iKrtTafel[skleur][0] == 0))
                : true
            if geenKleur {
                ii = wieSlag()
                if ii > 2 { ii -= 2 }
                j = s.vrager
                if j > 2 { j -= 2 }
                if ii != j {
                    m = 99
                    for n in (8 * s.troef)..<(8 * (s.troef + 1)) where s.kaart[n].dichtIkHy == s.vrager {
                        i = s.kaart[n].actWaarde
                        if i <= m { m = i; skaart = s.kaart[n].naam; skleur = s.troef; s.tactiek = 65 }
                    }
                }
            }
        }

        if skaart == .nul {
            m = 99
            for n in 0..<32 where s.kaart[n].dichtIkHy == s.vrager && s.kaart[n].kleur != s.troef {
                i = s.kaart[n].actWaarde
                if i <= m { m = i; skaart = s.kaart[n].naam; skleur = s.kaart[n].kleur; s.tactiek = 53 }
            }
        }

        if skaart == .nul {   // gooi maar wat
            m = 99
            for n in 0..<32 where s.kaart[n].dichtIkHy == s.vrager {
                i = s.kaart[n].actWaarde
                if i <= m { m = i; skaart = s.kaart[n].naam; skleur = s.kaart[n].kleur; s.tactiek = 35 }
            }
        }

        s.lkaart = skaart
        s.lkleur = skleur
        s.vrager = wieVrager(s.lkaart, s.lkleur)
    }
}
