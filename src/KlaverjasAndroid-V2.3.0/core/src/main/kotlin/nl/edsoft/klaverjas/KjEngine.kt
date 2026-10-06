package nl.edsoft.klaverjas

/**
 * De spelmechanica uit KJJ.C: delen, handen vullen, kansberekening, roem,
 * slagbepaling en de regelcontrole. Pure rekenlogica, geen scherm.
 *
 * Het origineel is één groot bestand; de uitbreidingen staan in aparte
 * bestanden (KjEngineRegels, KjEngineRoem, KjEngineBesteSlag, KjEngineAi).
 */
class KjEngine(zaad: Long? = null) {
    val s = KjState(zaad)

    // Positie van elke kaart in de rij tafelkaarten (0..3); vervangt kaart[].postafel.
    internal val tafelPositie = IntArray(32)

    /** true zolang de zet nog van de menselijke speler moet komen. */
    var wachtOpMens = false
        internal set

    private var zoekerInst: ZoekAi? = null
    private var claudeInst: ClaudeAi? = null

    /** De speler Claude, pas aangemaakt als hij nodig is. */
    internal fun claudeAi(): ClaudeAi = claudeInst ?: ClaudeAi(this).also { claudeInst = it }

    /** De zoekende speler, pas aangemaakt als hij nodig is. */
    internal fun zoeker(): ZoekAi = zoekerInst ?: ZoekAi(this).also { zoekerInst = it }

    // ---------------------------------------------------------------- Delen

    /** Deelt de 32 kaarten uit (Delen() uit KJJ.C). */
    fun delen() {
        val pntwaarde = intArrayOf(11, 4, 3, 2, 10, 0, 0, 0)
        val troevwaarde = intArrayOf(11, 4, 3, 20, 10, 14, 0, 0)
        var wie = Pos.HAND_ZUID

        for (n in 0 until 32) s.deeltabel[n] = n

        var n = 1
        for (m in 31 downTo 0) {
            // random(m + 1) en niet random(m): een eerlijke Fisher-Yates kiest uit
            // alle nog niet gedeelde kaarten, dus 0...m (punt A13 uit versie 1.1).
            val card = s.random(m + 1)
            s.kaart[s.deeltabel[card]].dichtIkHy = wie
            s.deeltabel[card] = s.deeltabel[m]
            if (n == 8) wie = Pos.HAND_NOORD
            if (n == 16) wie = Pos.TAFEL_ZUID
            if (n == 20) wie = Pos.TAFEL_NOORD
            if (n == 24) wie = Pos.DICHT_ZUID
            if (n == 28) wie = Pos.DICHT_NOORD
            n += 1
        }

        for (k in 0 until 32) {
            val kaart = s.kaart[k]
            kaart.naam = KjState.rangRoem[k % 8]
            kaart.puntWaarde = pntwaarde[k % 8]
            kaart.troefWaarde = troevwaarde[k % 8]
            kaart.kleur = k / 8
        }

        for (sl in 1 until 9) {
            for (m in 0 until 4) {
                val sk = s[sl, m]
                sk.kleur = 9
                sk.naam = NUL
                sk.troef = 0
                sk.speler = 998
                sk.kans = -100
                sk.waarde = -100
                sk.tactiek = 255
            }
        }
    }

    // ----------------------------------------------------------- Vulhanden

    /**
     * Bouwt hand[]/tafel[] opnieuw op vanuit het perspectief van de huidige
     * VRAGER: index 0 is altijd "mijn" kant, index 1 de tegenpartij. Berekent
     * meteen de slagkans van elke eigen kaart.
     */
    fun vulhanden() {
        val mm = IntArray(5)

        kaartenVrij()

        for (wie in 0 until 2) {
            for (n in 0 until 8) {
                val h = s.hand[wie][n]
                h.naam = NUL
                h.kleur = 5
                h.waarde = 0
                h.troef = 0
                h.slagkans = -100
                if (s.slagKrtNo == 0) h.slagkans0 = -100

                val t = s.tafel[wie][n]
                t.naam = NUL
                t.kleur = 5
                t.waarde = 5
                t.troef = 0
                t.slagkans = -100
                if (s.slagKrtNo == 0) t.slagkans0 = -100
            }
        }

        val vraagkant = if (s.vrager == 1 || s.vrager == 3) 1 else 2

        for (n in 0 until 32) {
            val k = s.kaart[n]
            val status = k.dichtIkHy

            if (status == Pos.GESPEELD) continue
            if (status == Pos.DICHT) continue
            if (status > 30) continue

            val troefstatus = if (s.troef == n / 8) 1 else 0
            k.troef = troefstatus

            var wie = if (status == vraagkant) 1 else 2
            if (status == vraagkant + 2 && status > 2) wie = 3
            else if (status > 2) wie = 4

            if (wie < 3) {
                val h = s.hand[wie - 1][mm[wie]]
                h.naam = k.naam
                h.kleur = k.kleur
                h.waarde = k.actWaarde
                h.troef = troefstatus
                mm[wie] += 1
            } else {
                val twie = wie - 2
                val t = s.tafel[twie - 1][mm[wie]]
                t.naam = k.naam
                t.kleur = k.kleur
                t.waarde = k.actWaarde
                t.troef = troefstatus
                mm[wie] += 1
            }
        }

        for (n in 0 until 8) {
            val h = s.hand[0][n]
            h.slagkans = bepaalSlagkans(h.naam, h.kleur)
            if (s.slagKrtNo == 0) h.slagkans0 = h.slagkans
            h.gegarandeerd = if (h.slagkans > 95) 1 else 0
        }

        for (n in 0 until 4) {
            val t = s.tafel[0][n]
            t.slagkans = bepaalSlagkans(t.naam, t.kleur)
            if (s.slagKrtNo == 0) t.slagkans0 = t.slagkans
            t.gegarandeerd = if (t.slagkans > 95) 1 else 0
        }
    }

    // ------------------------------------------------------- kaarten_vrij

    /**
     * Verdeelt alle 32 kaarten over "vrij" (nog in het spel), "weg" (gespeeld) en
     * "dicht" (voor de vrager onzichtbaar), per kleur en totaal, en telt de
     * kaarten per kleur in hand en op tafel.
     */
    fun kaartenVrij() {
        val nop = CStr(40)
        val vrij = CStr(40)
        val weg = CStr(40)
        val dicht = CStr(40)
        val q = IntArray(5)

        for (n in 0 until 4) {
            s.iKrt[n][0] = 0; s.iKrt[n][1] = 0
            s.iKrtTafel[n][0] = 0; s.iKrtTafel[n][1] = 0
            s.kHand[0][n].clear(); s.kHand[1][n].clear()
            s.kTafel[0][n].clear(); s.kTafel[1][n].clear()
        }

        var vragert = s.vrager
        if (vragert > 2) vragert -= 2

        s.krtTotVrij.clear()
        s.krtTotDicht.clear()
        s.krtTotWeg.clear()
        s.iKrtGespeeld = 0

        var n = -1
        var i: Int
        for (x in 0 until 4) {
            var m = 0
            var o = 0
            var p = 0
            q[1] = 0; q[2] = 0; q[3] = 0; q[4] = 0

            for (rep in 0 until 8) {
                n += 1
                val stat = s.kaart[n].dichtIkHy
                i = s.kaart[n].kleur
                var wie = 1
                if (stat == vragert) wie = 0
                if (stat - 2 == vragert) wie = 0

                if (stat == Pos.HAND_ZUID) {
                    s.iKrt[i][wie] += 1
                    s.kHand[wie][i][q[1]] = s.kaart[n].naam; q[1] += 1
                    s.kHand[wie][i][q[1]] = NUL
                    if (stat != vragert) { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
                }
                if (stat == Pos.HAND_NOORD) {
                    s.iKrt[i][wie] += 1
                    s.kHand[wie][i][q[2]] = s.kaart[n].naam; q[2] += 1
                    s.kHand[wie][i][q[2]] = NUL
                    if (stat != vragert) { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
                }
                if (stat == Pos.TAFEL_ZUID) {
                    s.iKrtTafel[i][wie] += 1
                    s.kTafel[wie][i][q[3]] = s.kaart[n].naam; q[3] += 1
                    s.kTafel[wie][i][q[3]] = NUL
                }
                if (stat == Pos.TAFEL_NOORD) {
                    s.iKrtTafel[i][wie] += 1
                    s.kTafel[wie][i][q[4]] = s.kaart[n].naam; q[4] += 1
                    s.kTafel[wie][i][q[4]] = NUL
                }

                if (stat != Pos.GESPEELD) { s.krtVrij[i][m] = s.kaart[n].naam; m += 1 }
                if (stat == Pos.GESPEELD) {
                    s.krtWeg[i][o] = s.kaart[n].naam; o += 1
                    s.iKrtGespeeld += 1
                }
                if (stat == Pos.DICHT) { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
                if (stat == Pos.DICHT_ZUID) { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
                if (stat == Pos.DICHT_NOORD) { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
                if (stat == Pos.NIEUW_ZUID) { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
                if (stat == Pos.NIEUW_NOORD) { s.krtDicht[i][p] = s.kaart[n].naam; p += 1 }
            }

            // i is hier de kleur van de laatste kaart, en dat is x.
            s.krtVrij[x][m] = NUL
            s.krtWeg[x][o] = NUL
            s.krtDicht[x][p] = NUL
        }

        for (kolor in 0 until 4) {
            nop.cpy(if (kolor == s.troef) KjState.rangTroef else KjState.rangNorm)

            var m = 0
            var o = 0
            var p = 0
            for (k in 0 until 8) {
                val x = nop[k]
                if (s.krtVrij[kolor].pos(x) != 0) { vrij[m] = nop[k]; m += 1 }
                if (s.krtWeg[kolor].pos(x) != 0) { weg[o] = nop[k]; o += 1 }
                if (s.krtDicht[kolor].pos(x) != 0) { dicht[p] = nop[k]; p += 1 }
            }
            vrij[m] = NUL
            weg[o] = NUL
            dicht[p] = NUL

            s.krtVrij[kolor].cpy(vrij)
            s.krtWeg[kolor].cpy(weg)
            s.krtDicht[kolor].cpy(dicht)
            s.krtTotVrij.cat(vrij)
            s.krtTotWeg.cat(weg)
            s.krtTotDicht.cat(dicht)
        }
    }

    // ------------------------------------------------------- kansrekening

    /** Kans dat de tegenpartij een hogere kaart van die kleur heeft. */
    fun kansHoger(kaartenhoger: Int, kleur: Int, specifiek: Int, vragerIn: Int): Double {
        var vrager = vragerIn
        if (vrager > 2) vrager -= 2
        if (vrager < 1 || vrager > 2) return 0.0
        if (s.verzaakt[vrager - 1][kleur] != 0) return 0.0
        if (s.krtVrij[kleur].len == 0) return 0.0

        val ts = 1
        val a = s.krtTotDicht.len
        val h = s.iKrt[0][ts] + s.iKrt[1][ts] + s.iKrt[2][ts] + s.iKrt[3][ts]
        val x = kaartenhoger
        val spec = specifiek
        val z = s.krtDicht[kleur].len

        if (z == 0) return 0.0
        if (x == 0) return 0.0
        if (x >= KjState.fact.size) return 1.0

        var res = guillermie(a, h, z, x, spec) * KjState.fact[x]
        if (res > 1.0) res = 1.0
        return res
    }

    /** Kans dat de tegenpartij überhaupt nog een kaart van die kleur heeft. */
    fun kansKaart(kleur: Int, specifiekIn: Int, vragerIn: Int): Double {
        var vrager = vragerIn
        if (vrager > 2) vrager -= 2
        if (vrager < 1 || vrager > 2) return 0.0
        if (s.verzaakt[vrager - 1][kleur] != 0) return 0.0
        if (s.krtVrij[kleur].len == 0) return 0.0

        val ts = 1
        val a = s.krtTotDicht.len
        val h = s.iKrt[0][ts] + s.iKrt[1][ts] + s.iKrt[2][ts] + s.iKrt[3][ts]
        val x = 1
        val spec = 0
        val z = s.krtDicht[kleur].len

        if (z == 0) return 0.0
        if (z >= KjState.fact.size) return 1.0

        var res = guillermie(a, h, z, x, spec) * KjState.fact[z]
        if (res > 1.0) res = 1.0
        return res
    }

    // ------------------------------------------------------------ hulpjes

    /** Waar bevindt kaart (kleur, karte) zich? Geeft dichtIkHy of -1. */
    fun wieVrager(karte: Teken, kleur: Int): Int {
        // Bewust met bereikcontrole: één aanroep in het origineel
        // (bepaal_laagsteroem) verwisselt de argumenten en leest daardoor buiten
        // kaart[]; hier netjes -1, wat ook het pad is dat het origineel bedoelde.
        val van = 8 * kleur
        val tot = (1 + kleur) * 8
        if (van < 0 || tot > 32) return -1
        for (n in van until tot) if (s.kaart[n].naam == karte) return s.kaart[n].dichtIkHy
        return -1
    }

    /** Wie heeft de slag op dit moment (1..4)? */
    fun wieSlag(): Int {
        val st = CStr(8)
        val sp = IntArray(8)
        var troef = false
        var m = 0

        var kkleur = s[s.slagNr, 0].kleur

        for (n in 0 until s.slagKrtNo) if (s[s.slagNr, n].troef != 0) troef = true

        val slagvolgorde = if (troef) KjState.rangTroef else KjState.rangNorm
        if (troef) kkleur = s.troef

        var i = 0
        for (n in 0 until s.slagKrtNo) {
            if (s[s.slagNr, n].kleur == kkleur) {
                st[i] = s[s.slagNr, n].naam
                sp[i] = s[s.slagNr, n].speler
                i += 1
            }
        }
        st[i] = NUL

        i = 10
        val len = st.len
        for (n in 0 until len) {
            val j = CStr.pos(slagvolgorde, st[n])
            if (j != 0 && j < i) { i = j; m = sp[n] }
        }
        return m
    }

    // -------------------------------------------------------- slagkans

    /**
     * Schat de kans (0..100) dat kaart (kleur, karte) de slag haalt. Dit is het
     * hart van de AI: bepaal_slagkans() uit KJ.C.
     */
    fun bepaalSlagkans(karte: Teken, kleur: Int): Int {
        val nop = CStr(40)
        val nop1 = CStr(40)
        var d: Int
        var i: Int
        var j: Int
        var n: Int
        var kansHogerr: Double

        if (karte == NUL) return -100
        if (kleur < 0 || kleur > 3) return -100

        var vrager = wieVrager(karte, kleur)
        if (vrager > 10) vrager /= 10
        if (vrager > 2) vrager -= 2
        val ts = 1
        val tss = if (vrager == 1) 2 else 1

        nop.cpy(if (kleur == s.troef) KjState.rangTroef else KjState.rangNorm)

        val posKaartvrager = hogere(karte, s.krtVrij[kleur], nop.tekens) + 1
        kansHogerr = if (posKaartvrager == 1) 1.0 else 0.0

        i = 0; j = 0
        if (s.slagKrtNo != 0) {
            for (k in 0..s.slagKrtNo) {
                if (s[s.slagNr, k].troef != 0 && kleur != s.troef) return 0
            }

            if (s[s.slagNr, 0].kleur != kleur && kleur != s.troef) return 0

            for (k in 0..s.slagKrtNo) {
                if (s[s.slagNr, k].kleur == kleur) { nop1[j] = s[s.slagNr, k].naam; j += 1 }
            }
            nop1[j] = NUL
            i = hogere(karte, nop1, nop.tekens)
            if (i > 0) return 0
        }

        n = 0
        while (n < 8) {
            if (nop[n] != karte) nop1[n] = nop[n]
            else { nop1[n] = NUL; break }
            n += 1
        }
        if (n >= 8) n = 8
        nop1[n] = NUL

        d = 1; j = 1
        if (s.slagKrtNo != 0) {
            n = 0
            while (n <= s.slagKrtNo) {
                if (s[s.slagNr, n].speler == tss + 2) j = 0
                n += 1
            }
            // In het origineel staat de volgende test buiten de lus, met n al
            // voorbij het laatste element. Bewust zo gelaten (de platte
            // slag-array vangt de overloop net als in C op).
            if (s[s.slagNr, n].speler == tss) d = 0
        }

        if (j != 0 && posKaartvrager > 1 && s.kTafel[ts][kleur].len > 0) {
            i = hogere(karte, s.kTafel[ts][kleur], nop.tekens)
            if (i > 0) return 0
        }

        if (j != 0 && s.troef != 999 && kleur != s.troef) {
            if (s.iKrtTafel[kleur][ts] == 0 && s.iKrtTafel[s.troef][ts] != 0) return 0
        }

        if (i == 0 && d == 0 && s.slagKrtNo != 0) {
            for (k in 0..s.slagKrtNo) if (s[s.slagNr, k].speler == tss) return 100
        }

        val aantalHoger = hogere(karte, s.krtDicht[kleur], nop.tekens)
        if (s.slagNr == 8 && hogere(karte, s.krtVrij[kleur], nop.tekens) != 0) return 0

        if (aantalHoger > 0) {
            kansHogerr = 1 - kansHoger(aantalHoger, kleur, 0, vrager)
        } else {
            kansHogerr = 1.0
            if (s.troef < 0 || s.troef > 3) return (kansHogerr * 100).toInt()
            if (s.krtDicht[s.troef].len == 0) return (kansHogerr * 100).toInt()
            if (tss in 1..2 && s.verzaakt[tss - 1][s.troef] != 0) return (kansHogerr * 100).toInt()
        }

        if (kleur != s.troef && s.troef != 999) {
            if (s.slagKrtNo == 8 && s.krtDicht[s.troef].len != 0) return 0

            var kansKaartt: Double =
                if (s.krtDicht[kleur].len == 0) 0.0 else kansKaart(kleur, 0, vrager)

            if (kansKaartt < 0.6 && s.krtDicht[s.troef].len != 0) {
                val kansTroefkaartt = kansKaart(s.troef, 0, vrager)
                kansKaartt = 1 - kansTroefkaartt
            }
            kansHogerr *= kansKaartt
        }

        return (kansHogerr * 100).toInt()
    }

    // ------------------------------------------------------------- troef

    /** Laat de computer troef kiezen (troef_bepalen() uit KJJ.C). */
    fun troefBepalen() {
        // Speelt de kant die troef mag maken volgens de zoekende speler, dan
        // kiest die zijn eigen troef.
        val kant = if (s.startVrager > 2) s.startVrager - 2 else s.startVrager
        if (kant in 1..2 && s.claude[kant - 1]) {
            s.troef = claudeAi().kiesTroef()
            zetActWaarden()
            return
        }
        if (kant in 1..2 && s.zoekt[kant - 1]) {
            s.troef = zoeker().kiesTroef()
            zetActWaarden()
            return
        }

        val aantalkrt = IntArray(4)
        val zekereslagen = IntArray(4)
        val somtroefpunten = IntArray(4)

        s.troef = 999

        // In het origineel wordt Hijtafel alleen gezet als startvrager==1 en blijft
        // hij anders ongeinitialiseerd. Hier expliciet: de tafelkaarten van de
        // tegenstander.
        val hijtafel = if (s.startVrager == 1) Pos.TAFEL_NOORD else Pos.TAFEL_ZUID

        for (n in 0 until 32) {
            val status = s.kaart[n].dichtIkHy
            if (status == s.startVrager || status == s.startVrager + 2) {
                somtroefpunten[s.kaart[n].kleur] += s.kaart[n].troefWaarde
                aantalkrt[s.kaart[n].kleur] += 1
            }
            if (status == hijtafel) somtroefpunten[s.kaart[n].kleur] -= s.kaart[n].troefWaarde
        }

        // Heb ik de boer van een kleur, tel dan de laagste troef van de
        // tegenstander mee.
        for (n in 0 until 4) {
            val status = s.kaart[n * 8 + 3].dichtIkHy
            if (status == s.startVrager || status == s.startVrager + 2) {
                for (m in 8 * (n + 1) downTo n * 8) {
                    if (m > 31) continue   // het origineel liep hier buiten kaart[]
                    if (s.kaart[m].dichtIkHy == hijtafel) {
                        somtroefpunten[n] += 2 * s.kaart[n].troefWaarde
                        break
                    }
                }
            }
        }

        // Zekere slagen tellen mee bij de troefkeuze. Ze horen uit de eigen kaarten
        // te komen, en die staan in hand[0] en tafel[0] (punt A11 uit versie 1.1;
        // het origineel las hand[VRAGER-1]).
        for (n in 0 until 8) if (s.tafel[0][n].gegarandeerd != 0) zekereslagen[s.tafel[0][n].kleur] += 1
        for (n in 0 until 8) if (s.hand[0][n].gegarandeerd != 0) zekereslagen[s.hand[0][n].kleur] += 1

        for (n in 0 until 4) somtroefpunten[n] += 3 * zekereslagen[n] + 2 * aantalkrt[n]

        var m = 0
        for (n in 0 until 4) if (somtroefpunten[n] > m) { m = somtroefpunten[n]; s.troef = n }

        if (s.troef == 999) s.troef = 0
        zetActWaarden()
    }

    /** Zet de actuele kaartwaarden zodra troef bekend is. */
    fun zetActWaarden() {
        for (n in 0 until 32) {
            s.kaart[n].actWaarde =
                if (s.kaart[n].kleur == s.troef) s.kaart[n].troefWaarde else s.kaart[n].puntWaarde
        }
    }

    // ----------------------------------------------------------- legkaart

    /**
     * Legt een kaart op tafel. Geeft false als de kaart niet van de vrager is (dan
     * heeft de AI verzaakt of klikte de speler op een verkeerde kaart). Draait
     * daarbij zonodig een dichte tafelkaart om.
     */
    fun legKaart(skaart: Teken, skleur: Int, vrager: Int): Boolean {
        if (skleur < 0 || skleur > 3 || skaart == NUL) return false

        var vragert = wieVrager(skaart, skleur)
        val speler = vragert
        if (vragert != vrager) return false       // verkeerde kaart
        if (vragert == Pos.GESPEELD) return false // al gespeeld
        if (vragert > 4) return false             // dichte kaart
        if (vragert > 2) vragert -= 2

        val krtno = KjState.kaartNr(skleur, skaart)

        val sk = s[s.slagNr, s.slagKrtNo]
        sk.kleur = skleur
        sk.naam = skaart
        sk.speler = s.vrager
        sk.waarde = s.kaart[krtno].actWaarde
        sk.kans = bepaalSlagkans(skaart, skleur)
        sk.tactiek = s.tactiek
        sk.troef = if (skleur == s.troef) 1 else 0

        s.kaart[krtno].dichtIkHy = Pos.GESPEELD
        s.slagKrtNo += 1

        if (speler > 2) {
            val postafel = tafelPos(krtno).coerceIn(0, 3)
            if (speler == Pos.TAFEL_ZUID && s.tZuid[postafel] == 0) return true
            if (speler == Pos.TAFEL_NOORD && s.tNoord[postafel] == 0) return true

            val bijlegger = if (speler == Pos.TAFEL_ZUID) Pos.DICHT_ZUID else Pos.DICHT_NOORD

            // Kies willekeurig een van de resterende dichte kaarten om om te draaien.
            val j = s.random(8) + 1
            var n = 0
            var i = 0
            while (true) {
                if (s.kaart[n].dichtIkHy == bijlegger) i += 1
                if (i == j) break
                n += 1
                if (n > 31) { n = 0; if (i == 0) return true }
            }

            tafelPositie[n] = postafel
            if (speler == Pos.TAFEL_ZUID) s.tZuid[postafel] = 0 else s.tNoord[postafel] = 0

            // De omgedraaide kaart wordt pas de volgende slag een echte tafelkaart;
            // tot die tijd 33->13 resp. 44->14.
            if (s.kaart[n].dichtIkHy > 30) s.kaart[n].dichtIkHy = s.kaart[n].dichtIkHy / 10 + 10
        }
        return true
    }

    /** Plek 0..3 van een tafelkaart in de rij. */
    fun tafelPos(krtno: Int): Int = tafelPositie[krtno]

    /** Kent de tafelkaarten hun plek 0..3 toe (wat leg_tafel() in KJJ.C deed). */
    fun zetTafelPosities() {
        var i = 0
        for (n in 0 until 32) if (s.kaart[n].dichtIkHy == Pos.TAFEL_ZUID) { tafelPositie[n] = i; i += 1 }
        i = 0
        for (n in 0 until 32) if (s.kaart[n].dichtIkHy == Pos.TAFEL_NOORD) { tafelPositie[n] = i; i += 1 }
    }

    /** Maakt net omgedraaide tafelkaarten (13/14) tot echte tafelkaarten. */
    fun updateTafel() {
        for (n in 0 until 32) {
            if (s.kaart[n].dichtIkHy == Pos.NIEUW_ZUID) s.kaart[n].dichtIkHy = Pos.TAFEL_ZUID
            if (s.kaart[n].dichtIkHy == Pos.NIEUW_NOORD) s.kaart[n].dichtIkHy = Pos.TAFEL_NOORD
        }
    }

    // ---------------------------------------------------------- evalueren

    /** Telt punten en roem van de zojuist gespeelde slag. */
    fun evalueer(): SlagUitslag {
        val sp = CStr(8)
        var punten = 0

        for (n in 0 until 4) punten += s[s.slagNr, n].waarde

        s.startVrager = wieSlag()
        if (s.startVrager > 2) s.startVrager -= 2
        if (s.startVrager < 1 || s.startVrager > 2) s.startVrager = 1
        s.puntenSpel[s.startVrager - 1] += punten

        var roem = 0
        for (rkleur in 0 until 4) {
            var i = 0
            for (n in 0 until 4) {
                if (s[s.slagNr, n].kleur == rkleur) { sp[i] = s[s.slagNr, n].naam; i += 1 }
            }
            sp[i] = NUL
            if (sp.len > 1) roem += bepaalRoemPunten(sp, rkleur)
        }

        // Vier gelijke kaarten, over de hele slag in plaats van per kleur (zie de
        // toelichting in de Swift-bron: de enige plek die bewust anders rekent
        // dan het origineel, ongeveer eens per 1700 spellen).
        val namen = (0 until 4).map { s[s.slagNr, it].naam }
        if (namen[0] != NUL && namen.all { it == namen[0] }) {
            roem += if (namen[0] == 'B') 200 else 100
            s.superroem[s.startVrager - 1] += 1
        }

        s.roem[s.startVrager - 1] += roem

        var laatsteSlag = 0
        if (s.slagNr == 8) {
            laatsteSlag = 10
            s.roem[s.startVrager - 1] += laatsteSlag
        }

        if (s[s.slagNr, 0].kleur != s[s.slagNr, 3].kleur) {
            val sp3 = s[s.slagNr, 3].speler
            if (sp3 in 1..2) s.verzaakt[sp3 - 1][s[s.slagNr, 0].kleur] = 1
        }

        return SlagUitslag(punten, roem, laatsteSlag)
    }

    /** Sluit een heel spel (8 slagen) af en verwerkt pit, nat en de stand. */
    fun evalueerSpel(): SpelUitslag {
        if (s.speler > 2) s.speler -= 2
        s.slagNr -= 1
        var n = wieSlag()
        if (n > 2) n -= 2

        var pitRoem = 0
        var tegenpit = false
        if (s.puntenSpel[0] == 152) { s.roem[0] += 100; s.pit[0] += 1; pitRoem += 100 }
        if (s.puntenSpel[1] == 152) { s.roem[1] += 100; s.pit[1] += 1; pitRoem += 100 }
        if (s.puntenSpel[0] == 152 && s.speler == 2) {
            s.roem[0] += 200; s.tpit[0] += 1; pitRoem += 200; tegenpit = true
        }
        if (s.puntenSpel[1] == 152 && s.speler == 1) {
            s.roem[1] += 200; s.tpit[1] += 1; pitRoem += 200; tegenpit = true
        }

        var a = s.puntenSpel[0] + s.roem[0]
        var b = s.puntenSpel[1] + s.roem[1]

        var nat = false
        if (s.speler == 1 && a <= b) { b += a; a = 0; s.nat[0] += 1; nat = true }
        if (s.speler == 2 && b <= a) { a += b; b = 0; s.nat[1] += 1; nat = true }

        s.puntenTotaalSpel[0] += a.toLong()
        s.puntenTotaalSpel[1] += b.toLong()
        if (a < b) s.gewonnenTot[1] += 1 else s.gewonnenTot[0] += 1
        s.roempnt[0] += s.roem[0].toLong()
        s.roempnt[1] += s.roem[1].toLong()
        val puntenZ = s.puntenSpel[0]
        val puntenN = s.puntenSpel[1]
        val roemZ = s.roem[0]
        val roemN = s.roem[1]
        s.puntenSpel[0] = 0; s.puntenSpel[1] = 0
        s.roem[0] = 0; s.roem[1] = 0
        s.slagNr += 1

        var uitslag = Taal.wintDitSpel(a > b) + (if (nat) Taal.tegenpartijNat else "") + Taal.standen(a, b)

        for (k in 0 until 4) { s.verzaakt[0][k] = 0; s.verzaakt[1][k] = 0 }

        var partijUit = false
        var partijGewonnenDoorZuid = false
        var partijGelijkspel = false
        if (s.puntenTotaalSpel[0] >= 1500 || s.puntenTotaalSpel[1] >= 1500) {
            partijUit = true
            if (s.puntenTotaalSpel[0] > s.puntenTotaalSpel[1]) { s.gewonnen[0] += 1; partijGewonnenDoorZuid = true }
            else s.gewonnen[1] += 1
            if (s.puntenTotaalSpel[0] == s.puntenTotaalSpel[1]) {
                // Allebei tegelijk over de 1500: telt voor beiden.
                s.gewonnen[0] += 1
                partijGewonnenDoorZuid = true
                partijGelijkspel = true
            }
            s.puntenTotaalSpel[0] = 0
            s.puntenTotaalSpel[1] = 0
            uitslag += Taal.partijUit
        }
        return SpelUitslag(uitslag, puntenZ, puntenN, roemZ, roemN, pitRoem, tegenpit,
            partijUit, partijGewonnenDoorZuid, partijGelijkspel)
    }

    companion object {
        /**
         * Hypergeometrische kans (guillermie() uit KJJ.C).
         * a = totaal dichte kaarten, h = kaarten in de betreffende hand,
         * z = resterende kaarten van die kleur, x = gevraagd aantal van die kleur,
         * sIn = gevraagd aantal specifieke kaarten.
         */
        fun guillermie(a: Int, h: Int, z: Int, x: Int, sIn: Int): Double {
            val f = KjState.fact
            var sp = sIn

            if (h - x < 0) return 1.0
            if (a - h < 0) return 1.0
            if (a - z <= 0) return 1.0
            if (z - sp < 0) sp = z
            if (x - sp < 0) sp = x
            if (z - x < 0) return 0.0
            if ((a - z) - (h - x) < 0) return 1.0

            if (a >= f.size || h >= f.size || z >= f.size) return 0.0

            val aa = f[h] * f[a - h] / f[h - x] * f[a - z] * f[z - sp]
            val bb = f[(a - z) - (h - x)] * f[x - sp] * f[z - x]
            val cc = f[a]

            if (aa == 0.0) return 0.0
            if (bb == 0.0) return 1.0
            if (cc == 0.0) return 1.0

            return (aa / bb) / cc
        }

        /** Aantal kaarten in ks dat volgens 'volgorde' hoger is dan kv. */
        fun hogere(kv: Teken, ks: CStr, volgorde: CharArray): Int {
            val nop1 = CStr(20)
            if (ks.len == 0) return 0

            var n = 0
            while (n < 8 && n < volgorde.size) {
                if (volgorde[n] != kv) nop1[n] = volgorde[n]
                else { nop1[n] = NUL; break }
                n += 1
            }
            // Komt kv niet in de volgorde voor, dan sluiten we hier af. In het
            // origineel bleef nop1 dan ongetermineerd.
            if (n >= 8) nop1[8] = NUL

            var i = 0
            val len = ks.len
            for (m in 0 until len) if (nop1.pos(ks[m]) != 0) i += 1
            return i
        }

        fun hogere(kv: Teken, ks: String, volgorde: CharArray): Int {
            val buf = CStr(ks.length + 2)
            buf.cpy(ks)
            return hogere(kv, buf, volgorde)
        }
    }

    // De niet-statische varianten, zodat de aanroepen naast de Swift-bron blijven lezen.
    internal fun hogere(kv: Teken, ks: CStr, volgorde: CharArray) = Companion.hogere(kv, ks, volgorde)
    internal fun hogere(kv: Teken, ks: String, volgorde: CharArray) = Companion.hogere(kv, ks, volgorde)
    internal fun guillermie(a: Int, h: Int, z: Int, x: Int, sIn: Int) = Companion.guillermie(a, h, z, x, sIn)
}
