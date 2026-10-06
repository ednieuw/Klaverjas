package nl.edsoft.klaverjas

/**
 * bekijk_beste_slag() uit KJ.C: kiest de bij te spelen kaart als de vaste
 * tactieken van speler1/speler2/tegenspeler geen uitkomst gaven. Werkt van "ik kan
 * de slag halen" via "ik kan roem pakken" naar "gooi maar wat".
 *
 * De `for ... where`-lussen uit de Swift-bron zijn hier `for` met een `continue`:
 * de voorwaarde wordt dus bij elke ronde opnieuw gelezen, ook als de lus-inhoud de
 * variabelen erin verandert (dat gebeurt in de troeftakken).
 */
fun KjEngine.bekijkBesteSlag(skleurIn: Int) {
    var skleur = skleurIn
    var w: Int
    var m: Int
    var i: Int
    var j: Int
    var ii: Int
    var rkleur = 0
    var kt = 0
    var kh = 0
    var troeff = false
    var skaart: Teken = NUL

    val slagstring = CStr(16)
    val troefstring = CStr(16)
    val roem = CStr(16)

    val slagvolgorde = if (s[s.slagNr, 0].troef != 0) KjState.rangTroef else KjState.rangNorm

    i = 0
    for (n in 0..s.slagKrtNo) {
        if (s[s.slagNr, n].troef != 0) { troefstring[i] = s[s.slagNr, n].naam; i += 1 }
    }
    troefstring[i] = NUL

    if (s[s.slagNr, 0].troef == 0) {
        for (n in 1..s.slagKrtNo) {
            if (s[s.slagNr, n].troef != 0) troeff = true   // er is ingetroefd
        }
    }

    i = 0
    for (n in 0 until 4) {
        if (s[s.slagNr, n].kleur == skleur) { slagstring[i] = s[s.slagNr, n].naam; i += 1 }
    }
    slagstring[i] = NUL

    // skleur verandert onderweg: sommige takken nemen de kleur over van een lege
    // hand- of tafelpositie, en die staat op 5. Daarom telkens opnieuw controleren.
    fun kleurOk(): Boolean = skleur in 0..3

    // ------------------------------------------------ tweede kaart
    if (s.slagKrtNo == 1) {
        ii = -50
        if (kleurOk() && s.iKrtTafel[skleur][0] != 0) {
            for (n in 0 until 4) {
                if (s.tafel[0][n].kleur == skleur && ii < s.tafel[0][n].slagkans) {
                    ii = s.tafel[0][n].slagkans; kt = n
                }
            }
        }

        if (ii > KjState.SLAGKANS_LEVEL) { skaart = s.tafel[0][kt].naam; s.tactiek = 16 }
    }

    // ------------------------------------------------- derde kaart
    if (s.slagKrtNo == 2) {
        i = -50
        ii = -50
        if (s.vrager > 2 && kleurOk() && s.iKrtTafel[skleur][0] != 0) {
            for (n in 0 until 4) {
                if (s.tafel[0][n].kleur == skleur && ii < s.tafel[0][n].slagkans) {
                    ii = s.tafel[0][n].slagkans; kt = n
                }
            }

            if (ii > s[s.slagNr, 0].kans && ii > KjState.SLAGKANS_LEVEL) {
                s.tactiek = 21; skaart = s.tafel[0][kt].naam
            }

            if (skaart == NUL && wieSlag() == s.vrager - 2
                && s[s.slagNr, 0].kans > KjState.SLAGKANS_LEVEL) {
                s.tactiek = 22; skaart = hoogsteRoem(skleur)
            }
        }
        if (s.vrager < 3 && kleurOk() && s.iKrt[skleur][0] != 0) {
            for (n in 0 until 8) {
                if (s.hand[0][n].kleur == skleur && i < s.hand[0][n].slagkans) {
                    i = s.hand[0][n].slagkans; kh = n
                }
            }

            if (i > s[s.slagNr, 0].kans && i > KjState.SLAGKANS_LEVEL) {
                skaart = s.hand[0][kh].naam; s.tactiek = 49
            }

            if (skaart == NUL) {
                if (wieSlag() == s.vrager + 2 && s[s.slagNr, 0].kans > KjState.SLAGKANS_LEVEL) {
                    s.tactiek = 4; skaart = hoogsteRoem(skleur)
                } else {
                    s.tactiek = 23
                    skaart = laagsteRoem(skleur)
                    if (skaart == 'T') skaart = NUL
                }
            }
        }
    }

    // ------------------------------------------------ laatste kaart
    if (s.slagKrtNo == 3) {
        i = 0
        if (wieSlag() == s.vrager + 2) {      // de slag is al aan mijn kant
            for (n in 0 until s.slagKrtNo) {
                if (s[s.slagNr, n].kleur == skleur) roem.append(s[s.slagNr, n].naam)
            }

            j = roem.len
            for (n in 0 until 8) {
                if (s.hand[0][n].kleur != skleur) continue
                roem[j] = s.hand[0][n].naam
                roem[j + 1] = NUL
                ii = bepaalRoemPunten(roem, skleur)
                if (ii > i) { i = ii; s.tactiek = 24; skaart = s.hand[0][n].naam }
            }

            if (skaart == NUL) {
                i = 0
                for (n in 0 until s.slagKrtNo) {
                    if (s[s.slagNr, n].kleur == skleur) roem.append(s[s.slagNr, n].naam)
                }

                j = roem.len
                for (n in 0 until 8) {
                    if (!(s.hand[0][n].kleur == skleur
                            && hogere(s.hand[0][n].naam, slagstring, slagvolgorde) == 0)) continue
                    roem[j] = s.hand[0][n].naam
                    roem[j + 1] = NUL
                    ii = bepaalRoemPunten(roem, skleur)
                    if (ii > i) { i = ii; s.tactiek = 48; skaart = s.hand[0][n].naam }
                }
            }
        }

        if (skaart == NUL && !troeff) {     // is er een hogere kaart?
            for (n in 0 until 8) {
                if (s.hand[0][n].kleur == skleur && skleur != s.troef
                    && hogere(s.hand[0][n].naam, slagstring, slagvolgorde) == 0) {
                    skaart = s.hand[0][n].naam; s.tactiek = 46
                }
            }
        }

        if (skaart == NUL) { skaart = laagsteRoem(skleur); s.tactiek = 3 }
    }

    // ------------------------------------- kan ik de kleur bekennen?
    if (skaart == NUL) {
        i = if (!kleurOk()) 0 else if (s.vrager < 3) s.iKrt[skleur][0] else s.iKrtTafel[skleur][0]

        if (i == 0) {   // niet bekennen: troeven of afgooien
            if (s.slagKrtNo > 1) {
                j = if (s.vrager > 2) s.vrager - 2 else s.vrager
                m = wieSlag()
                if (m > 2) m -= 2

                if (j == m) {   // slag staat al op mijn naam
                    if (s[s.slagNr, s.slagKrtNo - 2].kans < KjState.SLAGKANS_LEVEL) {
                        if (s.vrager > 2 && s.iKrtTafel[s.troef][0] != 0) {
                            i = 1000
                            for (n in 0 until 4) {
                                if (s.tafel[0][n].kleur == s.troef && troeff
                                    && hogere(s.tafel[0][n].naam, troefstring, KjState.rangTroef) == 0
                                    && s.tafel[0][n].slagkans < i) {
                                    i = s.tafel[0][n].slagkans
                                    skaart = s.tafel[0][n].naam
                                    skleur = s.troef
                                    s.tactiek = 26
                                }
                            }
                        }
                        if (s.vrager < 3 && s.iKrt[s.troef][0] != 0) {
                            i = 1000
                            for (n in 0 until 8) {
                                if (s.hand[0][n].kleur == s.troef && troeff
                                    && hogere(s.hand[0][n].naam, troefstring, KjState.rangTroef) == 0
                                    && s.hand[0][n].slagkans < i) {
                                    i = s.hand[0][n].slagkans
                                    skaart = s.hand[0][n].naam
                                    skleur = s.troef
                                    s.tactiek = 27
                                }
                            }
                        }
                    }
                } else {   // slag aan de tegenpartij: overtroeven als het kan
                    if (s.vrager > 2 && s.iKrtTafel[s.troef][0] != 0) {
                        i = 1000
                        for (n in 0 until 4) {
                            if (s.tafel[0][n].kleur == s.troef
                                && hogere(s.tafel[0][n].naam, troefstring, KjState.rangTroef) == 0
                                && s.tafel[0][n].slagkans != 0 && s.tafel[0][n].waarde < i) {
                                i = s.tafel[0][n].waarde
                                skaart = s.tafel[0][n].naam
                                skleur = s.troef
                                s.tactiek = 28
                            }
                        }
                    }
                    if (s.vrager < 3 && s.iKrt[s.troef][0] != 0) {
                        i = 1000
                        for (n in 0 until 8) {
                            if (s.hand[0][n].kleur == s.troef
                                && hogere(s.hand[0][n].naam, troefstring, KjState.rangTroef) == 0
                                && s.hand[0][n].slagkans != 0 && s.hand[0][n].waarde < i) {
                                i = s.hand[0][n].waarde
                                skaart = s.hand[0][n].naam
                                s.tactiek = 29
                                skleur = s.troef
                            }
                        }
                    }
                }
            }

            if (skaart == NUL && s.slagKrtNo < 2) {
                if (s.vrager > 2 && s.iKrtTafel[s.troef][0] != 0) {
                    i = 1000
                    for (n in 0 until 4) {
                        if (s.tafel[0][n].kleur != s.troef) continue
                        m = s.tafel[0][n].slagkans
                        if (i < m && i != 0) {
                            i = s.tafel[0][n].slagkans
                            skaart = s.tafel[0][n].naam
                            skleur = s.troef
                            s.tactiek = 30
                        }
                    }
                }
                if (s.vrager < 3 && s.iKrt[s.troef][0] != 0) {
                    i = 1000
                    for (n in 0 until 8) {
                        if (s.hand[0][n].kleur != s.troef) continue
                        m = s.hand[0][n].slagkans
                        if (i < m && i != 0) {
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
    if (skaart != NUL && s[s.slagNr, 0].troef == 0) {
        for (n in 1 until s.slagKrtNo) {
            if (s[s.slagNr, n].troef != 0
                && CStr.pos(KjState.rangTroef, s[s.slagNr, n].naam)
                < CStr.pos(KjState.rangTroef, skaart)) {
                skaart = NUL; s.tac[59] += 1; s.tactiek = 59
            }
        }
    }

    if (skaart == NUL) {
        for (n in 0 until 32) {
            if (!(s.kaart[n].dichtIkHy == s.vrager && s.kaart[n].kleur == skleur)) continue
            i = wieSlag(); ii = i
            if (ii > 2) ii -= 2
            j = s.vrager
            if (j > 2) j -= 2
            if (ii == j) {
                for (mm in 0 until s.slagKrtNo) {
                    if (s[s.slagNr, mm].speler == i && s[s.slagNr, mm].kans > 50) {
                        s.tactiek = 43; skaart = hoogsteRoem(skleur)
                    } else {
                        s.tactiek = 32; skaart = laagsteRoem(skleur)
                    }
                }
            }
        }
    }

    // ----------------------------------------- niet kunnen bekennen
    if (skaart == NUL) {
        i = wieSlag(); ii = i
        if (ii > 2) ii -= 2
        j = s.vrager
        if (j > 2) j -= 2

        if (ii == j) {   // slag is aan mij
            for (mm in 0 until s.slagKrtNo) {
                if (!(s[s.slagNr, mm].speler == i && s[s.slagNr, mm].kans > 75)) continue
                if (s.vrager < 3) {      // uit de hand
                    for (jj in 0 until 8) {
                        val kl = s.hand[0][jj].kleur
                        if (kl < 0 || kl > 3) continue
                        if (s.hand[0][jj].naam == 'T' && s.iKrt[kl][0] == 1) {
                            if (s.kTafel[0][kl].pos('A') == 0 &&              // geen aas op tafel
                                hogere('T', s.krtVrij[kl], slagvolgorde) != 0) { // nog hogere in het spel
                                skaart = s.hand[0][jj].naam
                                skleur = kl
                                s.tactiek = 51
                            }
                        }
                    }
                    if (skaart == NUL) {   // gooi de hoogste rommel bij
                        w = -1
                        for (jj in 0 until 8) {
                            if (s.hand[0][jj].waarde > w
                                && s.hand[0][jj].slagkans0 < KjState.SLAGKANS_LEVEL + 10
                                && s.hand[0][jj].kleur != s.troef
                                && s.hand[0][jj].naam != 'A') {
                                w = s.hand[0][jj].waarde
                                skaart = s.hand[0][jj].naam
                                skleur = s.hand[0][jj].kleur
                                s.tactiek = 68
                            }
                        }
                    }
                } else {               // van tafel
                    for (jj in 0 until 4) {
                        val kl = s.tafel[0][jj].kleur
                        if (kl < 0 || kl > 3) continue
                        if (s.tafel[0][jj].naam == 'T' && s.iKrt[kl][0] == 1) {
                            if (s.kHand[0][kl].pos('A') == 0 &&
                                hogere('T', s.krtVrij[kl], slagvolgorde) != 0) {
                                skaart = s.tafel[0][jj].naam
                                skleur = kl
                                s.tactiek = 52
                            }
                        }
                    }
                    if (skaart == NUL) {
                        w = -1
                        for (jj in 0 until 4) {
                            if (s.tafel[0][jj].waarde > w
                                && s.tafel[0][jj].slagkans0 < KjState.SLAGKANS_LEVEL + 10
                                && s.tafel[0][jj].kleur != s.troef
                                && s.tafel[0][jj].naam != 'A') {
                                w = s.tafel[0][jj].waarde
                                skaart = s.tafel[0][jj].naam
                                skleur = s.tafel[0][jj].kleur
                                s.tactiek = 69
                            }
                        }
                    }
                }
            }

            // Alleen introeven als daar roem mee te halen valt.
            if (skaart == NUL && s.vrager < 3 && s.iKrt[s.troef][0] != 0 && s.slagKrtNo == 2) {
                m = 999
                for (n in 0 until 8) {
                    if (s.hand[0][n].troef != 0 && s.hand[0][n].slagkans > 20
                        && m > s.hand[0][n].slagkans) {
                        m = s.hand[0][n].slagkans; skaart = s.hand[0][n].naam; rkleur = s.troef
                    }
                }

                if (skaart != NUL) {
                    m = 0
                    roem.cpy(slagstring)
                    if (kansKaart(rkleur, 1, s.vrager) > 0.3 && kleurOk()) {
                        val lenDicht = s.krtDicht[skleur].len
                        val lenSlag = slagstring.len
                        for (n in 0 until lenDicht) {
                            roem[lenSlag] = s.krtDicht[skleur][n]
                            roem[lenSlag + 1] = NUL
                            i = bepaalRoemPunten(roem, skleur)
                            if (i > m) m = i
                        }
                    }
                    if (m == 0) skaart = NUL
                    else { s.tactiek = 60; skleur = s.troef }
                }
            }

            if (skaart == NUL && s.vrager > 2 && s.iKrt[s.troef][0] != 0 && s.slagKrtNo == 2) {
                m = 999
                for (n in 0 until 8) {
                    if (s.tafel[0][n].troef != 0 && s.tafel[0][n].slagkans > 20
                        && m > s.tafel[0][n].slagkans) {
                        m = s.tafel[0][n].slagkans; skaart = s.tafel[0][n].naam; rkleur = s.troef
                    }
                }

                if (skaart != NUL) {
                    m = 0
                    roem.cpy(slagstring)
                    if (kansKaart(rkleur, 1, s.vrager) > 0.30 && kleurOk()) {
                        val lenDicht = s.krtDicht[skleur].len
                        val lenSlag = slagstring.len
                        for (n in 0 until lenDicht) {
                            roem[lenSlag] = s.krtDicht[skleur][n]
                            roem[lenSlag + 1] = NUL
                            i = bepaalRoemPunten(roem, skleur)
                            if (i > m) m = i
                        }
                    }
                    if (m == 0) skaart = NUL
                    else { s.tactiek = 25; skleur = s.troef }
                }
            }
        }
    }

    // ------------------------------------------------- restcategorie
    if (skaart == NUL && kleurOk()) {
        for (n in (8 * skleur) until (8 * (skleur + 1))) {
            if (s.kaart[n].dichtIkHy == s.vrager) { skaart = laagsteRoem(skleur); s.tactiek = 34 }
        }
    }

    if (skaart == NUL && skleur != s.troef && kleurOk()) {
        m = 99
        for (n in (8 * skleur) until (8 * (skleur + 1))) {
            if (s.kaart[n].dichtIkHy != s.vrager) continue
            i = s.kaart[n].actWaarde
            if (i < m) { m = i; skaart = s.kaart[n].naam; s.tactiek = 33 }
        }
    }

    // Ingetroefd: hogere troef bijgooien.
    if (skaart == NUL && troeff) {
        val geenKleur = if (kleurOk())
            ((s.vrager < 3 && s.iKrt[skleur][0] == 0) || (s.vrager > 2 && s.iKrtTafel[skleur][0] == 0))
        else true
        if (geenKleur) {
            ii = wieSlag()
            if (ii > 2) ii -= 2
            j = s.vrager
            if (j > 2) j -= 2
            if (ii != j) {
                i = 9
                val lenTroef = troefstring.len
                for (mm in 0 until lenTroef) {
                    if (CStr.pos(KjState.rangTroef, troefstring[mm]) < i) {
                        i = CStr.pos(KjState.rangTroef, troefstring[mm])
                    }
                }

                j = 99
                for (n in (8 * (s.troef + 1) - 1) downTo (8 * s.troef)) {
                    if (s.kaart[n].dichtIkHy == s.vrager
                        && CStr.pos(KjState.rangTroef, s.kaart[n].naam) < i) {
                        j = n
                    }
                }

                if (j < 33) { skaart = s.kaart[j].naam; skleur = s.kaart[j].kleur; s.tactiek = 64 }
            }
        }
    }

    // Niet ingetroefd en geen kleur: laagste troef bijgooien.
    if (skaart == NUL && !troeff) {
        val geenKleur = if (kleurOk())
            ((s.vrager < 3 && s.iKrt[skleur][0] == 0) || (s.vrager > 2 && s.iKrtTafel[skleur][0] == 0))
        else true
        if (geenKleur) {
            ii = wieSlag()
            if (ii > 2) ii -= 2
            j = s.vrager
            if (j > 2) j -= 2
            if (ii != j) {
                m = 99
                for (n in (8 * s.troef) until (8 * (s.troef + 1))) {
                    if (s.kaart[n].dichtIkHy != s.vrager) continue
                    i = s.kaart[n].actWaarde
                    if (i <= m) { m = i; skaart = s.kaart[n].naam; skleur = s.troef; s.tactiek = 65 }
                }
            }
        }
    }

    if (skaart == NUL) {
        m = 99
        for (n in 0 until 32) {
            if (!(s.kaart[n].dichtIkHy == s.vrager && s.kaart[n].kleur != s.troef)) continue
            i = s.kaart[n].actWaarde
            if (i <= m) { m = i; skaart = s.kaart[n].naam; skleur = s.kaart[n].kleur; s.tactiek = 53 }
        }
    }

    if (skaart == NUL) {   // gooi maar wat
        m = 99
        for (n in 0 until 32) {
            if (s.kaart[n].dichtIkHy != s.vrager) continue
            i = s.kaart[n].actWaarde
            if (i <= m) { m = i; skaart = s.kaart[n].naam; skleur = s.kaart[n].kleur; s.tactiek = 35 }
        }
    }

    s.lkaart = skaart
    s.lkleur = skleur
    s.vrager = wieVrager(s.lkaart, s.lkleur)
}
