extension KjEngine {
    /// Controleert of de gekozen kaart (s.lkaart / s.lkleur) volgens de regels
    /// gespeeld mag worden. Geeft nil als het mag, anders de reden.
    /// Dit is check_valid() uit KJJ.C.
    public func checkValid() -> String? {
        var i: Int, j: Int
        var hoogste: Teken = .nul
        let trKrt = CStr(16)
        let iKrt: Int, tKrt: Int
        var troefaanwezig = false

        let kaartkleurnul = s[slag: s.slagNr, i: 0].kleur
        if s.slagKrtNo <= 0 { return nil }
        if kaartkleurnul < 0 || kaartkleurnul > 3 { return nil }
        if s.lkleur < 0 || s.lkleur > 3 { return Taal.verkeerdeKaart }

        if s.vrager < 3 {
            trKrt.cpy(s.kHand[0][s.troef])
            tKrt = s.iKrt[s.troef][0]
            iKrt = s.iKrt[kaartkleurnul][0]
        } else {
            trKrt.cpy(s.kTafel[0][s.troef])
            tKrt = s.iKrtTafel[s.troef][0]
            iKrt = s.iKrtTafel[kaartkleurnul][0]
        }

        for n in 0..<s.slagKrtNo where s[slag: s.slagNr, i: n].kleur == s.troef {
            troefaanwezig = true
        }

        if troefaanwezig {
            i = 99
            for n in 0..<s.slagKrtNo {
                if s[slag: s.slagNr, i: n].kleur != s.troef { continue }
                j = CStr.pos(KjState.rangTroef, s[slag: s.slagNr, i: n].naam)
                if i > j { i = j; hoogste = s[slag: s.slagNr, i: n].naam }
            }

            // Het origineel test hier ook op "iKrt==0", maar vergelijkt daarbij
            // de array iKrt[][] met NUL in plaats van de lokale teller IKrt.
            // Die twee deelvoorwaarden zijn dus altijd onwaar; alleen de eerste
            // telt, en dat is hier zo gelaten.
            if kaartkleurnul == s.troef && tKrt != 0 {
                i = CStr.pos(KjState.rangTroef, hoogste)
                if CStr.pos(KjState.rangTroef, s.lkaart) < i && s.lkleur == s.troef { return nil }

                if s.lkleur != s.troef { return Taal.moetTroefBekennen }

                for _ in 0..<s.slagKrtNo where CStr.pos(KjState.rangTroef, s.lkaart) > i {
                    let len = trKrt.len
                    for n in 0..<len where CStr.pos(KjState.rangTroef, trKrt[n]) < i {
                        return Taal.moetOvertroeven
                    }
                }
            }
        }

        if iKrt > 0 && s.lkleur != kaartkleurnul { return Taal.moetKleurBekennen }

        if iKrt == 0 && tKrt > 0 {
            i = wieSlag()
            if i > 2 { i -= 2 }
            j = s.vrager
            if j > 2 { j -= 2 }
            if i == j { return nil }       // slag staat al op eigen naam

            i = CStr.pos(KjState.rangTroef, hoogste)
            if CStr.pos(KjState.rangTroef, s.lkaart) < i && s.lkleur == s.troef { return nil }

            let lenTr = trKrt.len
            for n in 0..<lenTr where CStr.pos(KjState.rangTroef, trKrt[n]) < i {
                return Taal.moetOvertroeven
            }

            if s.lkleur != s.troef && !troefaanwezig { return Taal.moetTroeven }
        }

        return nil
    }
}
