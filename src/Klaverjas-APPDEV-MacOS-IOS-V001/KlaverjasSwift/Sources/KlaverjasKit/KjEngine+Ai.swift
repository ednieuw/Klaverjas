/// De tactiek uit KJ.C: speler1 (uitkomen), tegenspeler1, speler2 en
/// tegenspeler2. Elke tak zet s.tactiek op het nummer uit het origineel, zodat
/// je in de UI nog steeds kunt zien welke regel de computer toepaste.
///
/// De lussen staan hier bewust als `while` en niet als `for n in 0..<8`. In C
/// leeft de teller op functieniveau, en het origineel leest hem na afloop van
/// een lus nog een keer uit — zie de tak "als ik A en hij kale tien", die
/// daardoor nooit uitgevoerd wordt. Met een Swift-`for` zou die teller
/// verdwijnen en zou het spel anders gaan lopen.
extension KjEngine {
    private func humaan() -> Bool {
        wachtOpMens = true
        return true
    }

    public func zetMensKlaar() { wachtOpMens = false }

    // -------------------------------------------------------- speler1

    /// Uitkomen: kiest de kaart waarmee de slag geopend wordt.
    public func speler1() {
        var m = 0, n = 0, i = 0
        var skleur = 5, skl = 5
        var skaart: Teken = .nul, ska: Teken = .nul
        var kansTroefkaarttp = 0

        if s.startVrager > 2 { s.startVrager -= 2 }
        s.vrager = s.startVrager
        let tss = (s.vrager == 1) ? 2 : 1
        s.slagKrtNo = 0

        vulhanden()

        skleur = 5
        skaart = .nul

        if s.iKrtTafel[s.troef][1] != 0 { kansTroefkaarttp = 100 }
        else { kansTroefkaarttp = Int(100 * kansKaart(s.troef, 0, s.vrager)) }
        if s.verzaakt[tss - 1][s.troef] != 0 && s.iKrtTafel[s.troef][1] == 0 { kansTroefkaarttp = 0 }
        // Het origineel test hier "Krt_dicht[TROEF]==0" op een array in plaats
        // van op de inhoud; die test is altijd onwaar en is daarom weggelaten.

        if !s.comp && (s.vrager == 1 || s.vrager == 3) { _ = humaan(); return }

        // Roem van tafel halen: gegarandeerde slag met de hoogste roemkans.
        m = 0; ska = .nul
        n = 0
        while n < 4 {
            if s.tafel[0][n].gegarandeerd == 1 {
                skaart = s.tafel[0][n].naam
                skleur = s.tafel[0][n].kleur
                i = bepaalHoogsteRoem(skleur, skaart)
                if m < i { ska = skaart; skl = skleur; m = i }
            }
            n += 1
        }
        n = 0
        while n < 8 {
            if s.hand[0][n].gegarandeerd == 1 {
                skaart = s.hand[0][n].naam
                skleur = s.hand[0][n].kleur
                i = bepaalHoogsteRoem(skleur, skaart)
                if m < i { ska = skaart; skl = skleur; m = i }
            }
            n += 1
        }
        if ska != .nul { skaart = ska; skleur = skl; s.tactiek = 7 }
        else { skaart = .nul }

        // Kale tien, of kale troefnegen, bij de tegenstander op tafel.
        n = 0
        while n < 4 {
            if skaart != .nul { break }
            if s.tafel[0][n].gegarandeerd != 0 {
                skleur = s.tafel[0][n].kleur
                if skleur >= 0 && skleur < 4 && s.iKrtTafel[skleur][1] == 1 {
                    if s.kTafel[1][skleur][0] == "T" { skaart = s.tafel[0][n].naam }
                    if s.kTafel[1][skleur][0] == "9" && skleur == s.troef { skaart = s.tafel[0][n].naam }
                    s.tactiek = 1
                }
            }
            n += 1
        }

        if skaart == .nul {
            n = 0
            while n < 8 {
                if skaart != .nul { break }
                if s.hand[0][n].gegarandeerd != 0 {
                    skleur = s.hand[0][n].kleur
                    if skleur >= 0 && skleur < 4 && s.iKrtTafel[skleur][1] == 1 {
                        if s.kTafel[1][skleur][0] == "T" { skaart = s.hand[0][n].naam }
                        if s.kTafel[1][skleur][0] == "9" && skleur == s.troef { skaart = s.hand[0][n].naam }
                        s.tactiek = 2
                    }
                }
                n += 1
            }
        }

        // Ik heb de aas en hij een kale tien van die kleur op tafel.
        if skaart == .nul {
            skleur = 5
            // Het origineel indexeert hier tafel[1][] met de teller van de
            // vorige lus (altijd 8, dus buiten de rij) in plaats van met m;
            // daardoor liep deze tak in de praktijk nooit. Dat gedrag is hier
            // bewaard met een expliciete bereikcontrole.
            m = 0
            while m < 4 {
                if skaart != .nul { s.tactiek = 50; break }
                if n >= 8 { m += 1; continue }
                if s.tafel[1][n].naam == "T" && s.iKrt[s.tafel[1][n].kleur][1] == 1
                    && s.tafel[1][n].kleur != s.troef {
                    skleur = s.tafel[1][n].kleur
                    n = 0
                    while n < 8 {
                        if s.hand[0][n].naam == "A" && s.hand[0][n].kleur == skleur
                            && s.hand[0][n].slagkans > KjState.slagkansLevel {
                            skaart = s.hand[0][n].naam; break
                        }
                        n += 1
                    }
                    if skaart == .nul {
                        n = 0
                        while n < 4 {
                            if s.tafel[0][n].naam == "A" && s.tafel[0][n].kleur == skleur
                                && s.tafel[0][n].slagkans > KjState.slagkansLevel {
                                skaart = s.tafel[0][n].naam; break
                            }
                            n += 1
                        }
                    }
                }
                m += 1
            }
            if skaart != .nul { s.tactiek = 50 }
        }

        // Ik heb troef op tafel en hij een kale A of T van een kleur die ik
        // niet heb: die troef mag weg zonder een zekere slag op te geven.
        if skaart == .nul && s.iKrtTafel[s.troef][0] != 0 {
            skleur = 5
            n = 0
            while n < 4 {
                if s.tafel[0][n].troef != 0 && s.tafel[0][n].gegarandeerd == 0 {
                    skleur = 6; s.skrt41 = s.tafel[0][n].naam
                }
                n += 1
            }

            if skleur == 6 {
                n = 0
                while n < 4 {
                    if (s.tafel[1][n].naam == "A" && s.tafel[1][n].kleur != s.troef)
                        || (s.tafel[1][n].naam == "T" && s.tafel[1][n].kleur != s.troef) {
                        let kl = s.tafel[1][n].kleur
                        if kl >= 0 && kl < 4 && s.iKrtTafel[kl][1] == 1 && s.iKrtTafel[kl][0] == 0 {
                            skleur = kl
                        }
                    }
                    n += 1
                }

                if skleur < 4 {
                    n = 0
                    while n < 8 {
                        if s.hand[0][n].kleur == skleur && s.hand[0][n].waarde < 5 {
                            skaart = s.hand[0][n].naam
                        }
                        n += 1
                    }
                    if skaart == .nul {
                        n = 0
                        while n < 8 {
                            if s.hand[0][n].kleur == skleur { skaart = s.hand[0][n].naam; break }
                            n += 1
                        }
                    }
                    if skaart != .nul { s.tactiek = 41 }
                }
            }
        }

        // Grootste roemkans bij een vrijwel zekere slag.
        if skaart == .nul {
            skleur = 5
            m = 0
            var j = 0
            n = 0
            while n < 4 {
                if s.tafel[0][n].slagkans > 85 && m <= s.tafel[0][n].slagkans {
                    i = bepaalHoogsteRoem(s.tafel[0][n].kleur, s.tafel[0][n].naam)
                    if i > j {
                        j = i; m = s.tafel[0][n].slagkans
                        skaart = s.tafel[0][n].naam; skleur = s.tafel[0][n].kleur
                        s.tactiek = 10
                    }
                }
                n += 1
            }
            n = 0
            while n < 8 {
                if s.hand[0][n].slagkans > 85 && m <= s.hand[0][n].slagkans {
                    i = bepaalHoogsteRoem(s.hand[0][n].kleur, s.hand[0][n].naam)
                    if i > j {
                        j = i; m = s.hand[0][n].slagkans
                        skaart = s.hand[0][n].naam; skleur = s.hand[0][n].kleur
                        s.tactiek = 62
                    }
                }
                n += 1
            }
        }

        // Laag uitkomen: als de partner de slag toch haalt, eerst de kaart met
        // de meeste roemkans van de andere stapel spelen.
        if skaart != .nul && s.tactiek != 41
            && !(skleur == s.troef && skaart == "V")
            && !(s.tactiek == 7 && skleur != s.troef) {
            s.vrager = wieVrager(skaart, skleur)
            s.lkaart = skaart
            s.lkleur = skleur
            var j = 0
            if skleur >= 0 && skleur < 4 {
                if s.vrager < 3 && s.iKrtTafel[skleur][0] != 0 {
                    m = 0
                    while m < s.iKrtTafel[skleur][0] {
                        if skleur == s.troef
                            && CStr.pos(KjState.rangTroef, s.kTafel[0][skleur][m])
                               < CStr.pos(KjState.rangTroef, s.lkaart) {
                            m += 1; continue
                        }
                        i = bepaalHoogsteRoem(skleur, s.kTafel[0][skleur][m])
                        if i >= j {
                            j = i; skaart = s.kTafel[0][skleur][m]
                            s.tactiekLaag = true; s.lkaart3 = s.lkaart; s.lkleur3 = s.lkleur
                        }
                        m += 1
                    }
                }
                if s.vrager > 2 && s.iKrt[skleur][0] != 0 {
                    m = 0
                    while m < s.iKrt[skleur][0] {
                        if skleur == s.troef
                            && CStr.pos(KjState.rangTroef, s.kHand[0][skleur][m])
                               < CStr.pos(KjState.rangTroef, s.lkaart) {
                            m += 1; continue
                        }
                        i = bepaalHoogsteRoem(skleur, s.kHand[0][skleur][m])
                        if i >= j {
                            j = i; skaart = s.kHand[0][skleur][m]
                            s.tactiekLaag = true; s.lkaart3 = s.lkaart; s.lkleur3 = s.lkleur
                        }
                        m += 1
                    }
                }
            }
            s.vrager = wieVrager(skaart, skleur)
            s.lkaart = skaart
            s.lkleur = skleur
            return
        }

        // Gegarandeerde slagen die geen troef zijn eerst uitspelen.
        if skaart == .nul {
            n = 0
            while n < 4 {
                if s.tafel[0][n].gegarandeerd == 1 {
                    if s.tafel[0][n].kleur == s.troef { n += 1; continue }
                    skaart = s.tafel[0][n].naam; skleur = s.tafel[0][n].kleur
                    s.tactiek = 9; break
                }
                n += 1
            }
        }
        if skaart == .nul {
            n = 0
            while n < 8 {
                if s.hand[0][n].gegarandeerd == 1 {
                    if s.hand[0][n].kleur == s.troef { n += 1; continue }
                    skaart = s.hand[0][n].naam; skleur = s.hand[0][n].kleur
                    s.tactiek = 8; break
                }
                n += 1
            }
        }

        // Gegarandeerde slagen, troef trekken zolang de tegenpartij nog troef kan hebben.
        if skaart == .nul {
            n = 0
            while n < 4 {
                if s.tafel[0][n].gegarandeerd == 1 {
                    if s.tafel[0][n].kleur == s.troef && kansTroefkaarttp < 30 { n += 1; continue }
                    skaart = s.tafel[0][n].naam; skleur = s.tafel[0][n].kleur
                    s.tactiek = 57; break
                }
                n += 1
            }
        }
        if skaart == .nul {
            n = 0
            while n < 8 {
                if s.hand[0][n].gegarandeerd == 1 {
                    if s.hand[0][n].kleur == s.troef && kansTroefkaarttp < 30 { n += 1; continue }
                    skaart = s.hand[0][n].naam; skleur = s.hand[0][n].kleur
                    s.tactiek = 58; break
                }
                n += 1
            }
        }

        // Ik heb troef op tafel en hij A, T of H van een kleur die ik niet heb.
        if skaart == .nul && s.iKrtTafel[s.troef][0] != 0 {
            skleur = 5
            n = 0
            while n < 4 {
                if (s.tafel[1][n].naam == "A" || s.tafel[1][n].naam == "T" || s.tafel[1][n].naam == "H")
                    && s.tafel[1][n].kleur != s.troef {
                    let kl = s.tafel[1][n].kleur
                    if kl >= 0 && kl < 4 && s.iKrtTafel[kl][1] == 1 && s.iKrtTafel[kl][0] == 0 {
                        skleur = kl
                    }
                }
                n += 1
            }
            if skleur < 4 {
                n = 0
                while n < 8 {
                    if s.hand[0][n].kleur == skleur && s.hand[0][n].waarde < 5 {
                        skaart = s.hand[0][n].naam
                    }
                    n += 1
                }
                if skaart == .nul {
                    n = 0
                    while n < 8 {
                        if s.hand[0][n].kleur == skleur { skaart = s.hand[0][n].naam; break }
                        n += 1
                    }
                }
                if skaart != .nul { s.tactiek = 47 }
            }
        }

        if skaart != .nul {
            s.vrager = wieVrager(skaart, skleur)
            s.lkaart = skaart
            s.lkleur = skleur
            return
        }

        // Grootste slagkans boven 75.
        m = 0
        n = 0
        while n < 4 {
            if s.tafel[0][n].kleur == s.troef && kansTroefkaarttp < 20 { n += 1; continue }
            if s.tafel[0][n].slagkans > 75 && m < s.tafel[0][n].slagkans {
                m = s.tafel[0][n].slagkans
                skaart = s.tafel[0][n].naam; skleur = s.tafel[0][n].kleur
                s.tactiek = 11
            }
            n += 1
        }
        n = 0
        while n < 8 {
            if s.hand[0][n].kleur == s.troef && kansTroefkaarttp < 20 { n += 1; continue }
            if s.hand[0][n].slagkans > 75 && m < s.hand[0][n].slagkans {
                m = s.hand[0][n].slagkans
                skaart = s.hand[0][n].naam; skleur = s.hand[0][n].kleur
                s.tactiek = 63
            }
            n += 1
        }

        // Troef van de tafel van de tegenstander trekken met een lage kaart.
        if skaart == .nul && s.iKrtTafel[s.troef][1] != 0 {
            n = 0
            while n < 4 {
                let kl = s.tafel[0][n].kleur
                if kl < 0 || kl > 3 { n += 1; continue }
                if s.iKrtTafel[kl][1] == 0 && s.tafel[0][n].waarde < 5 {
                    if s.iKrt[kl][0] == 1
                        && (s.kHand[0][kl][0] == "A" || s.kHand[0][kl][0] == "T") {
                        skaart = .nul
                    } else { skaart = s.tafel[0][n].naam; skleur = kl }
                }
                n += 1
            }
            if skaart == .nul {
                n = 0
                while n < 8 {
                    let kl = s.hand[0][n].kleur
                    if kl < 0 || kl > 3 { n += 1; continue }
                    if s.iKrt[kl][1] == 0 && s.hand[0][n].waarde < 5 {
                        if s.iKrt[kl][0] == 1
                            && (s.kTafel[0][kl][0] == "A" || s.kTafel[0][kl][0] == "T") {
                            skaart = .nul
                        } else { skaart = s.hand[0][n].naam; skleur = kl }
                    }
                    n += 1
                }
            }
            if skaart != .nul { s.tactiek = 5 }
        }

        // Overige gegarandeerde slagen, nu ook troef.
        if skaart == .nul {
            n = 0
            while n < 4 {
                if s.tafel[0][n].gegarandeerd == 1 {
                    skaart = s.tafel[0][n].naam; skleur = s.tafel[0][n].kleur
                    s.tactiek = 55; break
                }
                n += 1
            }
        }
        if skaart == .nul {
            n = 0
            while n < 8 {
                if s.hand[0][n].gegarandeerd == 1 {
                    skaart = s.hand[0][n].naam; skleur = s.hand[0][n].kleur
                    s.tactiek = 56; break
                }
                n += 1
            }
        }

        // Troef op tafel gebruiken om slagen te halen.
        if skaart == .nul && s.iKrtTafel[s.troef][0] != 0 {
            skleur = 5
            n = 0
            while n < 4 {
                let kl = s.tafel[1][n].kleur
                if kl >= 0 && kl < 4 && s.iKrtTafel[kl][0] == 0 && s.iKrtTafel[kl][1] != 0 {
                    skleur = kl
                }
                n += 1
            }
            if skleur < 5 {
                n = 0
                while n < 8 {
                    if s.hand[0][n].kleur == skleur && s.hand[0][n].waarde < 10 {
                        skaart = s.hand[0][n].naam; break
                    }
                    n += 1
                }
                if skaart == .nul {
                    n = 0
                    while n < 8 {
                        if s.hand[0][n].kleur == skleur { skaart = s.hand[0][n].naam; break }
                        n += 1
                    }
                }
            }
            if skaart != .nul { s.tactiek = 54; s.tactiekTT = true }
        }

        // Kom uit met een lage kaart zonder roemkans, geen troef.
        if skaart == .nul {
            m = 990
            n = 0
            while n < 32 {
                if s.kaart[n].dichtIkHy == s.vrager + 2 && m >= s.kaart[n].actWaarde
                    && s.kaart[n].kleur != s.troef {
                    // In het origineel staat achter de volgende test een losse
                    // puntkomma, waardoor het blok altijd wordt uitgevoerd.
                    _ = bepaalHoogsteRoem(s.kaart[n].kleur, s.kaart[n].naam)
                    m = s.kaart[n].actWaarde
                    skaart = s.kaart[n].naam
                    skleur = s.kaart[n].kleur
                    s.tactiek = 13
                }
                n += 1
            }
        }

        // Kom uit met een lage kaart, geen troef.
        if skaart == .nul {
            m = 990
            n = 0
            while n < 32 {
                if s.kaart[n].dichtIkHy == s.vrager && m >= s.kaart[n].actWaarde
                    && s.kaart[n].kleur != s.troef {
                    m = s.kaart[n].actWaarde
                    skaart = s.kaart[n].naam
                    skleur = s.kaart[n].kleur
                    s.tactiek = 14
                }
                n += 1
            }
        }

        // Kom uit met de laagste kaart die er is.
        if skaart == .nul {
            m = 990
            n = 0
            while n < 32 {
                if s.kaart[n].dichtIkHy == s.vrager && m >= s.kaart[n].actWaarde {
                    m = s.kaart[n].actWaarde
                    skaart = s.kaart[n].naam
                    skleur = s.kaart[n].kleur
                    s.tactiek = 15
                }
                n += 1
            }
        }

        s.vrager = wieVrager(skaart, skleur)
        s.lkaart = skaart
        s.lkleur = skleur
    }

    // ---------------------------------------------------- tegenspeler1

    /// Tweede kaart van de slag: de tafelkaart van de tegenpartij.
    public func tegenspeler1() {
        let nop = CStr(16), nop1 = CStr(16)
        var m = 0, n = 0, i = 0, j = 0
        var sBeste = 0   // heet 's' in het origineel; die naam is hier bezet

        s.vrager = (s.startVrager == 1 || s.startVrager == 3) ? 4 : 3

        vulhanden()
        s.lkaart = .nul
        let skleur = s[slag: s.slagNr, i: 0].kleur
        let skaart = s[slag: s.slagNr, i: 0].naam
        s.lkleur = skleur

        let slagvolgorde = s[slag: s.slagNr, i: 0].troef != 0 ? KjState.rangTroef : KjState.rangNorm

        if !s.comp && s.vrager == 3 { _ = humaan(); return }
        if skleur < 0 || skleur > 3 { bekijkBesteSlag(skleur); return }

        if s.iKrtTafel[skleur][0] == 1 {
            s.lkaart = s.kTafel[0][skleur][0]; s.tactiek = 40; return
        }

        if s.iKrtTafel[skleur][0] > 1 && skleur == s.troef {
            n = 0
            while n < 8 {
                if slagvolgorde[n] != skaart { nop1[n] = slagvolgorde[n] }
                else { nop1[n] = .nul; break }
                n += 1
            }
            if n >= 8 { n = 8 }
            nop1[n] = .nul

            i = 0   // aantal hogere kaarten op mijn tafel
            m = 0
            while m < s.iKrtTafel[skleur][0] {
                if nop1.pos(s.kTafel[0][skleur][m]) == 0 { m += 1; continue }
                nop[i] = s.kTafel[0][skleur][m]; i += 1
                m += 1
            }
            nop[i] = .nul
            let aantalhoger = i

            sBeste = -110
            i = 0
            n = 0
            while n < aantalhoger {
                i = bepaalSlagkans(nop[n], skleur)
                if i >= sBeste { sBeste = i; j = n }
                n += 1
            }

            if aantalhoger == 1 { s.lkaart = nop[j]; s.tactiek = 18; return }
            if i > 40 { s.lkaart = nop[j]; s.tactiek = 19 }
            else {
                // Doe alsof alleen de hogere kaarten van mij zijn en vraag dan
                // welke daarvan de minste roem weggeeft.
                var ss = [Int](repeating: 0, count: 8)
                i = 0
                for k in (skleur * 8)..<((skleur + 1) * 8) { ss[i] = s.kaart[k].dichtIkHy; i += 1 }

                for k in (skleur * 8)..<((skleur + 1) * 8) where s.kaart[k].dichtIkHy == s.vrager {
                    s.kaart[k].dichtIkHy = Pos.gespeeld
                }

                let len = nop.len
                for mm in 0..<len {
                    for k in (skleur * 8)..<((skleur + 1) * 8) where s.kaart[k].naam == nop[mm] {
                        s.kaart[k].dichtIkHy = s.vrager
                    }
                }

                s.lkaart = laagsteRoem(skleur)
                s.tactiek = 42

                i = 0
                for k in (skleur * 8)..<((skleur + 1) * 8) { s.kaart[k].dichtIkHy = ss[i]; i += 1 }
            }
        }

        if s.lkaart == .nul { bekijkBesteSlag(s[slag: s.slagNr, i: 0].kleur) }
    }

    // ---------------------------------------------------- tegenspeler2

    /// Vierde en laatste kaart van de slag.
    public func tegenspeler2() {
        let nop = CStr(16), nop1 = CStr(16), khoger = CStr(16)
        let kname = CStr(24)
        var m = 0, n = 0, i = 0, j = 0, t = 0
        var sBeste = 0

        s.vrager = (s.startVrager == 1 || s.startVrager == 3) ? 2 : 1

        vulhanden()
        s.lkaart = .nul
        let skleur = s[slag: s.slagNr, i: 0].kleur
        var skaart = s[slag: s.slagNr, i: 0].naam
        let skleur1 = s[slag: s.slagNr, i: 1].kleur
        let skaart1 = s[slag: s.slagNr, i: 1].naam
        let skleur2 = s[slag: s.slagNr, i: 2].kleur
        let skaart2 = s[slag: s.slagNr, i: 2].naam
        s.lkleur = skleur

        if skleur < 0 || skleur > 3 { bekijkBesteSlag(skleur); return }

        kname.cpy(s.kHand[0][skleur])
        let ikarte = s.iKrt[skleur][0]

        let slagvolgorde = s[slag: s.slagNr, i: 0].troef != 0 ? KjState.rangTroef : KjState.rangNorm

        if !s.comp && s.vrager == 1 { _ = humaan(); return }

        if ikarte == 1 { s.lkaart = kname[0]; s.tactiek = 38; return }

        if ikarte > 1 && skleur == s.troef {
            i = 0
            n = 0
            while n < s.slagKrtNo {
                if s[slag: s.slagNr, i: n].troef != 0 { nop[i] = s[slag: s.slagNr, i: n].naam; i += 1 }
                n += 1
            }
            nop[i] = .nul

            if CStr.pos(KjState.rangTroef, skaart) > CStr.pos(KjState.rangTroef, skaart1)
                && skleur1 == s.troef {
                skaart = skaart1
            }
            if CStr.pos(KjState.rangTroef, skaart) > CStr.pos(KjState.rangTroef, skaart2)
                && skleur2 == s.troef {
                skaart = skaart2
            }

            n = 0
            while n < 8 {
                if slagvolgorde[n] != skaart { nop1[n] = slagvolgorde[n] }
                else { nop1[n] = .nul; break }
                n += 1
            }
            if n >= 8 { nop1[8] = .nul }

            i = 0
            m = 0
            while m < ikarte {
                if nop1.pos(kname[m]) == 0 { m += 1; continue }
                khoger[i] = kname[m]; i += 1
                m += 1
            }
            khoger[i] = .nul
            let aantalhoger = i

            sBeste = -110
            j = wieSlag()
            t = nop.len
            nop[t + 1] = .nul

            // Slag is al aan mijn kant en ik kan niet hoger: pak de roem mee.
            if j == s.vrager + 2 && aantalhoger == 0 {
                s.lkaart = hoogsteRoem(s.troef); s.tactiek = 17
            }

            if aantalhoger > 1 {
                n = 0
                while n < aantalhoger {
                    nop[t] = khoger[n]
                    i = bepaalRoemPunten(nop, s.troef)
                    if i >= sBeste { sBeste = i; j = n }
                    n += 1
                }
                s.lkaart = khoger[j]
                s.tactiek = 20
            }
            if j != s.vrager + 2 && aantalhoger == 0 {
                s.lkaart = laagsteRoem(s.troef); s.tactiek = 39
            }

            s.lkleur = s.troef
            if aantalhoger == 1 { s.lkaart = khoger[0]; s.tactiek = 30 }

            // Valt er geen roem, gooi dan geen troef weg.
            if aantalhoger == 0 && s.lkaart != .nul {
                nop[t] = s.lkaart
                if bepaalRoemPunten(nop, s.troef) == 0 { s.lkaart = .nul }
            }
        }

        if s.lkaart == .nul { bekijkBesteSlag(s[slag: s.slagNr, i: 0].kleur) }
    }

    // -------------------------------------------------------- speler2

    /// Derde kaart van de slag.
    public func speler2() {
        let nop = CStr(16), nop1 = CStr(16), khoger = CStr(16)
        let kname = CStr(24)
        var m = 0, n = 0, i = 0, j = 0, t = 0
        var sBeste = 0

        if s.startVrager == 1 { s.vrager = 3 }
        if s.startVrager == 2 { s.vrager = 4 }
        if s.startVrager == 3 { s.vrager = 1 }
        if s.startVrager == 4 { s.vrager = 2 }

        vulhanden()
        s.lkaart = .nul
        let skleur = s[slag: s.slagNr, i: 0].kleur
        var skaart = s[slag: s.slagNr, i: 0].naam
        let skleur1 = s[slag: s.slagNr, i: 1].kleur
        let skaart1 = s[slag: s.slagNr, i: 1].naam
        s.lkleur = skleur

        if skleur < 0 || skleur > 3 { bekijkBesteSlag(skleur); return }

        let ikarte: Int
        if s.startVrager > 2 {
            kname.cpy(s.kHand[0][skleur])
            ikarte = s.iKrt[skleur][0]
        } else {
            kname.cpy(s.kTafel[0][skleur])
            ikarte = s.iKrtTafel[skleur][0]
        }

        let slagvolgorde = s[slag: s.slagNr, i: 0].troef != 0 ? KjState.rangTroef : KjState.rangNorm

        if !s.comp && (s.vrager == 1 || s.vrager == 3) { _ = humaan(); return }

        // Speler1 hield bewust een kaart achter om nu laag mee te komen.
        if s.tactiekLaag {
            s.lkaart = s.lkaart3
            s.lkleur = s.lkleur3
            s.tactiek = 6
            s.tactiekLaag = false
            return
        }

        if s.tactiek41 {   // troef kwijtraken, A of T van de tegenstander trekken
            s.tactiek41 = false
            s.lkaart = s.skrt41
            s.lkleur = s.troef
            s.tactiek = 45
            if s.lkaart != .nul { return }
        }

        if s.tactiekTT {   // troef van tafel kwijtraken
            s.tactiekTT = false
            i = 0
            n = 0
            while n < 4 {
                if s.tafel[0][n].kleur == s.troef && i <= s.tafel[0][n].waarde {
                    i = s.tafel[0][n].waarde; s.lkaart = s.tafel[0][n].naam; s.lkleur = s.troef
                }
                n += 1
            }
            s.tactiek = 12
            if s.lkaart != .nul { return }
        }

        if ikarte == 1 { s.lkaart = kname[0]; s.tactiek = 36; return }

        if ikarte > 1 && skleur == s.troef {
            if skleur == skleur1
                && CStr.pos(KjState.rangTroef, skaart) > CStr.pos(KjState.rangTroef, skaart1) {
                skaart = skaart1
            }

            n = 0
            while n < 8 {
                if slagvolgorde[n] != skaart { nop1[n] = slagvolgorde[n] }
                else { nop1[n] = .nul; break }
                n += 1
            }
            if n >= 8 { nop1[8] = .nul }

            i = 0
            m = 0
            while m < ikarte {
                if nop1.pos(kname[m]) == 0 { m += 1; continue }
                nop[i] = kname[m]; i += 1
                m += 1
            }
            nop[i] = .nul
            khoger.cpy(nop)
            let aantalhoger = i

            sBeste = -110
            i = 0
            n = 0
            while n < aantalhoger {
                i = bepaalSlagkans(nop[n], s.troef)
                if i >= sBeste { sBeste = i; j = n }
                n += 1
            }

            if aantalhoger == 1 { s.lkaart = nop[j]; s.tactiek = 66; return }
            if i > 50 { s.lkaart = nop[j]; s.tactiek = 67; return }

            sBeste = -100
            if aantalhoger != 0 {
                i = 0
                n = 0
                while n < s.slagKrtNo {
                    if s[slag: s.slagNr, i: n].troef != 0 {
                        nop[i] = s[slag: s.slagNr, i: n].naam; i += 1
                    }
                    n += 1
                }
                nop[i] = .nul
                t = nop.len
                nop[t + 1] = .nul
                n = 0
                while n < aantalhoger {
                    nop[t] = khoger[n]
                    i = bepaalRoemPunten(nop, s.troef)
                    if i >= sBeste { sBeste = i; j = n }
                    n += 1
                }
                s.lkaart = khoger[j]
                s.tactiek = 37
            }
        }

        if s.lkaart == .nul { bekijkBesteSlag(s[slag: s.slagNr, i: 0].kleur) }
    }
}
