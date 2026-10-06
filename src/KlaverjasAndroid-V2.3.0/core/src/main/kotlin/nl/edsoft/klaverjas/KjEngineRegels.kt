package nl.edsoft.klaverjas

/**
 * Controleert of de gekozen kaart (s.lkaart / s.lkleur) volgens de regels
 * gespeeld mag worden. Geeft null als het mag, anders de reden.
 * Dit is check_valid() uit KJJ.C.
 */
fun KjEngine.checkValid(): String? {
    var i: Int
    var j: Int
    var hoogste: Teken = NUL
    val trKrt = CStr(16)
    val iKrt: Int
    val tKrt: Int
    var troefaanwezig = false

    val kaartkleurnul = s[s.slagNr, 0].kleur
    if (s.slagKrtNo <= 0) return null
    if (kaartkleurnul < 0 || kaartkleurnul > 3) return null
    if (s.lkleur < 0 || s.lkleur > 3) return Taal.verkeerdeKaart

    if (s.vrager < 3) {
        trKrt.cpy(s.kHand[0][s.troef])
        tKrt = s.iKrt[s.troef][0]
        iKrt = s.iKrt[kaartkleurnul][0]
    } else {
        trKrt.cpy(s.kTafel[0][s.troef])
        tKrt = s.iKrtTafel[s.troef][0]
        iKrt = s.iKrtTafel[kaartkleurnul][0]
    }

    for (n in 0 until s.slagKrtNo) if (s[s.slagNr, n].kleur == s.troef) troefaanwezig = true

    if (troefaanwezig) {
        i = 99
        for (n in 0 until s.slagKrtNo) {
            if (s[s.slagNr, n].kleur != s.troef) continue
            j = CStr.pos(KjState.rangTroef, s[s.slagNr, n].naam)
            if (i > j) { i = j; hoogste = s[s.slagNr, n].naam }
        }

        // Het origineel test hier ook op "iKrt==0", maar vergelijkt daarbij de
        // array iKrt[][] met NUL in plaats van de lokale teller IKrt. Alleen de
        // eerste deelvoorwaarde telt.
        if (kaartkleurnul == s.troef && tKrt != 0) {
            i = CStr.pos(KjState.rangTroef, hoogste)
            if (CStr.pos(KjState.rangTroef, s.lkaart) < i && s.lkleur == s.troef) return null

            if (s.lkleur != s.troef) return Taal.moetTroefBekennen

            for (rep in 0 until s.slagKrtNo) {
                if (CStr.pos(KjState.rangTroef, s.lkaart) > i) {
                    val len = trKrt.len
                    for (n in 0 until len) {
                        if (CStr.pos(KjState.rangTroef, trKrt[n]) < i) return Taal.moetOvertroeven
                    }
                }
            }
        }
    }

    if (iKrt > 0 && s.lkleur != kaartkleurnul) return Taal.moetKleurBekennen

    if (iKrt == 0 && tKrt > 0) {
        i = wieSlag()
        if (i > 2) i -= 2
        j = s.vrager
        if (j > 2) j -= 2
        if (i == j) return null       // slag staat al op eigen naam

        i = CStr.pos(KjState.rangTroef, hoogste)
        if (CStr.pos(KjState.rangTroef, s.lkaart) < i && s.lkleur == s.troef) return null

        val lenTr = trKrt.len
        for (n in 0 until lenTr) {
            if (CStr.pos(KjState.rangTroef, trKrt[n]) < i) return Taal.moetOvertroeven
        }

        if (s.lkleur != s.troef && !troefaanwezig) return Taal.moetTroeven
    }

    return null
}
