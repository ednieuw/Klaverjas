package nl.edsoft.klaverjas

/*
 * Roemberekening. laagsteRoem()/hoogsteRoem() proberen alle mogelijke verdelingen
 * van de resterende kaarten van een kleur af en kiezen daaruit de kaart die de
 * minste resp. meeste roem weggeeft.
 */

/** Roempunten van een reeks kaarten van één kleur. */
fun KjEngine.bepaalRoemPunten(str: CStr, kolor: Int): Int {
    var stuk = 0
    var i = 0
    var j = 0

    for (n in 0 until 8) {
        if (str.pos(KjState.rangRoem[n]) != 0) {
            i += 1
            if (i > j) j = i
        } else i = 0
    }

    if (str.pos('V') != 0 && str.pos('H') != 0 && kolor == s.troef) stuk = 20

    if (j == 3) return stuk + 20   // drie opeenvolgend
    if (j == 4) return stuk + 50   // vier opeenvolgend

    if (str.len == 4) {
        when (str.string) {
            // Onbereikbaar (vier gelijke namen kunnen nooit dezelfde kleur hebben);
            // de tak blijft staan omdat hij in de C-code van 1994 ook staat.
            "7777", "8888", "9999", "TTTT", "VVVV", "HHHH", "AAAA" -> {
                stuk = 100; s.superroem[maxOf(0, minOf(1, s.startVrager - 1))] += 1
            }
            "BBBB" -> {
                stuk = 200; s.superroem[maxOf(0, minOf(1, s.startVrager - 1))] += 1
            }
            else -> {}
        }
    }
    return stuk
}

fun KjEngine.bepaalRoemPunten(str: String, kolor: Int): Int {
    val buf = CStr(str.length + 2)
    buf.cpy(str)
    return bepaalRoemPunten(buf, kolor)
}

/** Welke kaart van deze kleur levert de meeste roem op? */
fun KjEngine.hoogsteRoem(kkleur: Int): Teken {
    s.hoogste = 1
    val h = laagsteRoem(kkleur)
    s.hoogste = 0
    return h
}

/**
 * Welke kaart van deze kleur geeft de minste roem weg (of, met s.hoogste gezet, de
 * meeste)? Bouwt alle combinaties van één kaart per speler op en weegt die.
 */
fun KjEngine.laagsteRoem(kkleur: Int): Teken {
    if (kkleur < 0 || kkleur > 3) return NUL

    var m: Int
    var i: Int
    var j: Int
    var c: Int
    val roemStr = CStr(16)
    val roempnt = IntArray(64)
    val rr = CStr.new2(64, 16)
    val kt = CStr.new2(8, 16)   // kaarten van deze kleur per speler
    val t = IntArray(8)
    var skaart: Teken

    var vrager = s.vrager
    if (vrager > 2) vrager -= 2

    for (n in (kkleur * 8) until ((kkleur + 1) * 8)) {
        if (s.kaart[n].dichtIkHy >= Pos.GESPEELD) continue
        j = s.kaart[n].dichtIkHy
        if (j > 10) j = 1 - (vrager - 1) + 1   // net omgedraaide tafelkaart
        j -= 1
        if (j < 0) continue                    // 0 = dicht, telt niet mee
        if (j > 3) continue
        kt[j][t[j]] = s.kaart[n].naam
        kt[j][t[j] + 1] = NUL
        t[j] += 1
    }

    // Kaarten die deze slag al gespeeld zijn horen bij de roemreeks; de spelers die
    // ze legden doen niet meer mee.
    for (n in 0 until s.slagKrtNo) {
        if (s[s.slagNr, n].kleur != kkleur) continue
        val sp = s[s.slagNr, n].speler
        if (sp in 1..4) kt[sp - 1].clear()
        roemStr.append(s[s.slagNr, n].naam)
    }

    KjEngine.sorteerOpLengte(kt)

    var aa = kt[0].len
    var bb = kt[1].len
    var cc = kt[2].len
    var dd = kt[3].len
    if (aa == 0) aa += 1
    if (bb == 0) bb += 1
    if (cc == 0) cc += 1
    if (dd == 0) dd += 1

    i = 0
    j = roemStr.len
    val aantal = kt[0].len * bb * cc * dd
    var a = 0
    while (a < aantal && i < rr.size) { rr[i].cpy(roemStr); i += 1; a += 1 }

    i = 0
    outer@ for (b in 0 until aa) {
        for (c2 in 0 until bb) {
            for (d in 0 until cc) {
                for (e in 0 until dd) {
                    if (i >= rr.size) break@outer
                    rr[i][j + 0] = kt[0][b]
                    rr[i][j + 1] = kt[1][c2]
                    rr[i][j + 2] = kt[2][d]
                    rr[i][j + 3] = kt[3][e]
                    rr[i][j + 4] = NUL
                    i += 1
                }
            }
        }
    }

    i = aa * bb * cc * dd
    if (i > rr.size - 1) i = rr.size - 1
    skaart = NUL

    if (s.hoogste != 0) {
        m = 0
        for (n in 0 until (i + 1)) {
            roempnt[n] = bepaalRoemPunten(rr[n], kkleur)
            if (m <= roempnt[n]) {
                // Aflopend door de kleur, zo eindig je bij de hoogste kaart.
                for (jj in ((kkleur + 1) * 8 - 1) downTo (kkleur * 8)) {
                    if (s.kaart[jj].dichtIkHy != s.vrager) continue
                    val len = rr[n].len
                    for (aa2 in 0 until len) {
                        if (s.kaart[jj].naam == rr[n][aa2]) { skaart = rr[n][aa2]; m = roempnt[n] }
                    }
                }
            }
        }
        return skaart
    }

    m = 999; c = 999
    for (n in 0 until i) {
        roempnt[n] = bepaalRoemPunten(rr[n], kkleur)
        if (m >= roempnt[n]) {
            if (m > roempnt[n]) c = 999
            // Oplopend door de kleur, zo eindig je bij de laagste kaart.
            for (jj in (kkleur * 8) until ((kkleur + 1) * 8)) {
                if (s.kaart[jj].dichtIkHy != s.vrager) continue
                val len = rr[n].len
                for (aa2 in 0 until len) {
                    if (s.kaart[jj].naam != rr[n][aa2]) continue
                    if (m > roempnt[n]) {
                        c = s.kaart[jj].actWaarde; skaart = rr[n][aa2]; m = roempnt[n]
                    }
                    if (m == roempnt[n] && c >= s.kaart[jj].actWaarde) {
                        c = s.kaart[jj].actWaarde; skaart = rr[n][aa2]
                    }
                }
            }
        }
    }
    return skaart
}

/** Hoogst haalbare roem als (kkleur, skaart) gespeeld wordt. */
fun KjEngine.bepaalHoogsteRoem(kkleur: Int, skaart: Teken): Int {
    s.hoogste = 1
    val r = bepaalLaagsteRoem(kkleur, skaart)
    s.hoogste = 0
    return r
}

/** Laagst haalbare roem als (kkleur, skaart) gespeeld wordt. */
fun KjEngine.bepaalLaagsteRoem(kkleur: Int, skaart: Teken): Int {
    if (kkleur < 0 || kkleur > 3) return 0

    var m: Int
    var i: Int
    var j: Int
    val roempnt = IntArray(64)
    val rr = CStr.new2(64, 16)
    val kt = CStr.new2(8, 16)
    val t = IntArray(8)

    // Het origineel roept wie_vrager() hier met verwisselde argumenten aan,
    // waardoor de uitkomst altijd "niet gevonden" (-1) is. Dat pad is hier
    // behouden zodat de kaartkeuze gelijk blijft aan het origineel.
    var vrager = wieVrager((kkleur and 0xFF).toChar(), skaart.code)
    if (vrager > 2) vrager -= 2

    for (n in (kkleur * 8) until ((kkleur + 1) * 8)) {
        if (s.kaart[n].dichtIkHy >= Pos.GESPEELD) continue
        j = s.kaart[n].dichtIkHy
        if (j > 10) j = 1 - (vrager - 1) + 1
        j -= 1
        if (j < 0) continue
        if (j > 3) continue
        kt[j][t[j]] = s.kaart[n].naam
        kt[j][t[j] + 1] = NUL
        if (j + 1 == s.vrager) {
            kt[4][t[j]] = s.kaart[n].naam
            kt[4][t[j] + 1] = NUL
        }
        t[j] += 1
    }
    kt[4].clear()

    // De te onderzoeken kaart wordt vastgezet in de string van zijn eigenaar.
    for (n in 0 until 4) {
        val len = kt[n].len
        for (mm in 0 until len) {
            if (kt[n][mm] == skaart) { kt[n][0] = skaart; kt[n][1] = NUL }
        }
    }

    KjEngine.sorteerOpLengte(kt)

    var aa = kt[0].len
    var bb = kt[1].len
    var cc = kt[2].len
    var dd = kt[3].len
    if (aa == 0) aa += 1
    if (bb == 0) bb += 1
    if (cc == 0) cc += 1
    if (dd == 0) dd += 1

    i = 0
    j = 0
    outer@ for (b in 0 until aa) {
        for (c in 0 until bb) {
            for (d in 0 until cc) {
                for (e in 0 until dd) {
                    if (i >= rr.size) break@outer
                    rr[i][j + 0] = kt[0][b]
                    rr[i][j + 1] = kt[1][c]
                    rr[i][j + 2] = kt[2][d]
                    rr[i][j + 3] = kt[3][e]
                    rr[i][j + 4] = NUL
                    i += 1
                }
            }
        }
    }

    i = aa * bb * cc * dd
    if (i > rr.size - 1) i = rr.size - 1

    if (s.hoogste != 0) {
        m = 0
        for (n in 0 until (i + 1)) {
            roempnt[n] += bepaalRoemPunten(rr[n], kkleur)
            if (m <= roempnt[n]) m = roempnt[n]
        }
        return m
    }

    m = 999
    for (n in 0 until i) {
        roempnt[n] += bepaalRoemPunten(rr[n], kkleur)
        if (m >= roempnt[n]) m = roempnt[n]
    }
    return m
}

/** Bubbelsort van kt[0..4] op afnemende stringlengte, als in het origineel. */
internal fun KjEngine.Companion.sorteerOpLengte(kt: Array<CStr>) {
    val tmp = CStr(16)
    for (rep in 0 until 4) {
        for (n in 0 until 4) {
            if (kt[n].len < kt[n + 1].len) {
                tmp.cpy(kt[n])
                kt[n].cpy(kt[n + 1])
                kt[n + 1].cpy(tmp)
                tmp.clear()
            }
        }
    }
}
