package nl.edsoft.klaverjas.kaarten

/**
 * Een kale afbeelding: pixels als 0xAARRGGBB (in een Int), rij voor rij.
 * Bewust geen Android-Bitmap: de kaarten worden per pixel opgebouwd en alleen op
 * hele veelvouden vergroot, zodat ze in de gewone JVM-tests te toetsen zijn. De
 * app zet dit pas om in iets wat het scherm kan tonen.
 */
class Afbeelding(val breedte: Int, val hoogte: Int, val pixels: IntArray) {
    constructor(breedte: Int, hoogte: Int, vulling: Int = 0) :
        this(breedte, hoogte, IntArray(breedte * hoogte) { vulling })

    operator fun get(x: Int, y: Int): Int = pixels[y * breedte + x]
    operator fun set(x: Int, y: Int, kleur: Int) { pixels[y * breedte + x] = kleur }

    /** Zet één pixel; buiten de afbeelding valt weg, net als in het origineel. */
    fun zet(x: Int, y: Int, kleur: Int) {
        if (x < 0 || y < 0 || x >= breedte || y >= hoogte) return
        pixels[y * breedte + x] = kleur
    }
}

/**
 * Bouwt de 32 kaarten precies zo op als KJKRT.C dat deed: een wit vlak van 53x83 met
 * zwarte rand, daarin de pixeltekening van de plaatkaart of de kleursymbolen van de
 * lage kaarten, plus de rangletter in de hoeken. Port van OrigineleKaarten.swift.
 */
object OrigineleKaarten {
    const val BREEDTE = 53   // rectangle(x,y,x+52,y+82) is 53 x 83 pixels
    const val HOOGTE = 83

    const val RANG_ROEM = "AHVBT987"

    /** Het EGA/VGA-palet waar de BGI-kleurnummers naar verwijzen. */
    private val ega: IntArray = intArrayOf(
        rgb(0, 0, 0),        //  0 BLACK
        rgb(0, 0, 170),      //  1 BLUE
        rgb(0, 170, 0),      //  2 GREEN
        rgb(0, 170, 170),    //  3 CYAN
        rgb(170, 0, 0),      //  4 RED
        rgb(170, 0, 170),    //  5 MAGENTA
        rgb(170, 85, 0),     //  6 BROWN
        rgb(170, 170, 170),  //  7 LIGHTGRAY
        rgb(85, 85, 85),     //  8 DARKGRAY
        rgb(85, 85, 255),    //  9 LIGHTBLUE
        rgb(85, 255, 85),    // 10 LIGHTGREEN
        rgb(85, 255, 255),   // 11 LIGHTCYAN
        rgb(255, 85, 85),    // 12 LIGHTRED
        rgb(255, 85, 255),   // 13 LIGHTMAGENTA
        rgb(255, 255, 85),   // 14 YELLOW
        rgb(255, 255, 255),  // 15 WHITE
    )

    fun rgb(r: Int, g: Int, b: Int): Int = (0xFF shl 24) or (r shl 16) or (g shl 8) or b

    // Kleur waarmee elk kleursymbool getekend wordt: zwart, donkergrijs, rood, lichtrood.
    private val symboolKleur = intArrayOf(0, 8, 4, 12)

    /**
     * De kleur waarin het symbool van deze kleur op de kaart getekend wordt. Vier
     * kleuren, geen twee: klaver zwart en schoppen donkergrijs, ruiten rood en harten
     * lichtrood. Het scherm gebruikt dezelfde kleuren voor het troefteken.
     */
    fun symboolKleurVoor(kleur: Int): Int =
        if (kleur < 0 || kleur > 3) ega[15] else ega[symboolKleur[kleur]]

    // Posities van de symbolen op de lage kaarten, uit Zeven()/Acht()/Negen()/Tien().
    private val zeven7X = intArrayOf(18, 11, 26, 11, 26, 11, 26)
    private val zeven7Y = intArrayOf(24, 9, 9, 38, 38, 52, 52)
    private val achtX = intArrayOf(11, 26, 11, 26, 11, 26, 11, 26)
    private val achtY = intArrayOf(10, 10, 24, 24, 38, 38, 52, 52)
    private val negenX = intArrayOf(11, 26, 3, 18, 34, 11, 26, 3, 34)
    private val negenY = intArrayOf(10, 10, 24, 24, 24, 38, 38, 52, 52)
    private val tienX = intArrayOf(11, 26, 3, 18, 34, 11, 26, 3, 18, 34)
    private val tienY = intArrayOf(10, 10, 24, 24, 24, 38, 38, 52, 52, 52)

    /** Het 8x8 tekenblok waarmee BGI zijn standaardfont tekende, voor de paar tekens op de kaarten. */
    private val font: Map<Char, IntArray> = mapOf(
        'A' to intArrayOf(0x30, 0x78, 0xCC, 0xCC, 0xFC, 0xCC, 0xCC, 0x00),
        'H' to intArrayOf(0xCC, 0xCC, 0xCC, 0xFC, 0xCC, 0xCC, 0xCC, 0x00),
        'V' to intArrayOf(0xC6, 0xC6, 0xC6, 0xC6, 0x6C, 0x38, 0x10, 0x00),
        'B' to intArrayOf(0xFC, 0x66, 0x66, 0x7C, 0x66, 0x66, 0xFC, 0x00),
        '0' to intArrayOf(0x7C, 0xC6, 0xCE, 0xDE, 0xF6, 0xE6, 0x7C, 0x00),
        '1' to intArrayOf(0x30, 0x70, 0x30, 0x30, 0x30, 0x30, 0xFC, 0x00),
        '7' to intArrayOf(0xFE, 0xC6, 0x0C, 0x18, 0x30, 0x30, 0x30, 0x00),
        '8' to intArrayOf(0x7C, 0xC6, 0xC6, 0x7C, 0xC6, 0xC6, 0x7C, 0x00),
        '9' to intArrayOf(0x7C, 0xC6, 0xC6, 0x7E, 0x06, 0x0C, 0x78, 0x00),
    )

    // ------------------------------------------------------------ opbouw

    /** kaartvorm(): zwarte rand met wit vlak erbinnen. */
    private fun kaartvorm(): Afbeelding {
        val bm = Afbeelding(BREEDTE, HOOGTE, ega[15])
        for (x in 0 until BREEDTE) { bm.zet(x, 0, ega[0]); bm.zet(x, HOOGTE - 1, ega[0]) }
        for (y in 0 until HOOGTE) { bm.zet(0, y, ega[0]); bm.zet(BREEDTE - 1, y, ega[0]) }
        return bm
    }

    fun bouwKaart(naam: Char, kleur: Int): Afbeelding {
        val bm = kaartvorm()
        val plaat = KaartData.plaat(naam)
        if (plaat != null) tekenPlaatkaart(bm, plaat, KaartData.palet(naam)!!, kleur, naam)
        else tekenLageKaart(bm, naam, kleur)
        return bm
    }

    /** Kleine letter van een ASCII-teken; niet-letters blijven zoals ze zijn. */
    private fun klein(b: Int): Int = if (b in 65..90) b + 32 else b

    /** Aas, heer, vrouw of boer: de pixeltekening plus hoeksymbolen. */
    private fun tekenPlaatkaart(
        bm: Afbeelding, plaat: List<String>, palet: List<Pair<Char, Int>>, kleur: Int, naam: Char,
    ) {
        val tabel = IntArray(128) { -2 }   // -2 = niet in de tabel
        for ((teken, k) in palet) tabel[klein(teken.code)] = k

        for (n in plaat.indices) {
            val rij = plaat[n]
            for (m in 0 until minOf(48, rij.length)) {
                val c = klein(rij[m].code)
                var k = if (c < 128) tabel[c] else -2
                if (k == -2) continue
                if (k == -1) k = 2 + kleur                     // GREEN + kleurnummer
                bm.zet(m + 2, n + 17, ega[k and 15])
            }
        }

        // Rangletter midden tussen de twee hoeksymbolen.
        tekst(bm, 26, 9, naam.toString(), 2, ega[0])
        tekst(bm, 26, 74, naam.toString(), 2, ega[0])

        tekenSymbool(bm, 2, 2, kleur)
        tekenSymbool(bm, 37, 2, kleur)
        tekenSymbool(bm, 37, 67, kleur)
        tekenSymbool(bm, 2, 67, kleur)
    }

    /** Tien, negen, acht of zeven: symbolen in het vlak, cijfers in de hoeken. */
    private fun tekenLageKaart(bm: Afbeelding, naam: Char, kleur: Int) {
        val px: IntArray
        val py: IntArray
        val cijfer: String
        when (naam) {
            'T' -> { px = tienX; py = tienY; cijfer = "10" }
            '9' -> { px = negenX; py = negenY; cijfer = "9" }
            '8' -> { px = achtX; py = achtY; cijfer = "8" }
            else -> { px = zeven7X; py = zeven7Y; cijfer = "7" }
        }

        for (j in px.indices) tekenSymbool(bm, px[j] + 1, py[j] + 2, kleur)

        // Hoekcijfers met vier pixels marge aan alle kanten.
        if (cijfer == "10") {
            // De 1 en de 0 staan los, zes pixels uit elkaar.
            tekst(bm, 8, 7, "1", 1, ega[0])
            tekst(bm, 14, 7, "0", 1, ega[0])
            tekst(bm, 8, 75, "1", 1, ega[0])
            tekst(bm, 14, 75, "0", 1, ega[0])
            tekst(bm, 38, 7, "1", 1, ega[0])
            tekst(bm, 44, 7, "0", 1, ega[0])
            tekst(bm, 38, 75, "1", 1, ega[0])
            tekst(bm, 44, 75, "0", 1, ega[0])
        } else {
            tekst(bm, 8, 7, cijfer, 1, ega[0])
            tekst(bm, 8, 75, cijfer, 1, ega[0])
            tekst(bm, 44, 7, cijfer, 1, ega[0])
            tekst(bm, 44, 75, cijfer, 1, ega[0])
        }
    }

    /** Een 14x14 kleursymbool; 'w' blijft leeg, de rest krijgt de kleur. */
    private fun tekenSymbool(bm: Afbeelding, x: Int, y: Int, kleur: Int) {
        val data = KaartData.symbool(kleur)
        val c = ega[symboolKleur[kleur]]
        for (i in 0 until minOf(14, data.size)) {
            val rij = data[i]
            for (j in 0 until minOf(14, rij.length)) {
                if (klein(rij[j].code) != 'w'.code) bm.zet(x + j, y + i, c)
            }
        }
    }

    /**
     * Zet tekst met (x,y) als middelpunt. Er wordt gecentreerd op de pixels die
     * werkelijk gezet worden, niet op het 8x8 tekenvak.
     */
    private fun tekst(bm: Afbeelding, x: Int, y: Int, tekst: String, schaal: Int, kleur: Int) {
        var minX = Int.MAX_VALUE
        var maxX = Int.MIN_VALUE
        var minY = Int.MAX_VALUE
        var maxY = Int.MIN_VALUE

        for (t in tekst.indices) {
            val glyph = font[tekst[t]] ?: continue
            for (r in 0 until 8) {
                for (b in 0 until 8) {
                    if ((glyph[r] and (0x80 shr b)) == 0) continue
                    val gx = t * 8 + b
                    if (gx < minX) minX = gx
                    if (gx > maxX) maxX = gx
                    if (r < minY) minY = r
                    if (r > maxY) maxY = r
                }
            }
        }
        if (minX > maxX) return   // niets te tekenen

        val inktBreed = (maxX - minX + 1) * schaal
        val inktHoog = (maxY - minY + 1) * schaal
        val x0 = x - inktBreed / 2 - minX * schaal
        val y0 = y - inktHoog / 2 - minY * schaal

        for (t in tekst.indices) {
            val glyph = font[tekst[t]] ?: continue
            for (r in 0 until 8) {
                for (b in 0 until 8) {
                    if ((glyph[r] and (0x80 shr b)) == 0) continue
                    for (sy in 0 until schaal) {
                        for (sx in 0 until schaal) {
                            bm.zet(x0 + (t * 8 + b) * schaal + sx, y0 + r * schaal + sy, kleur)
                        }
                    }
                }
            }
        }
    }

    /**
     * De achterkant: een ruitpatroon van diagonalen met een dubbele rand eromheen, in
     * dezelfde EGA-kleuren als de kaarten zelf.
     */
    fun bouwAchterkant(): Afbeelding {
        val bm = kaartvorm()
        val veld = ega[1]    // blauw
        val ruit = ega[9]    // lichtblauw
        val stip = ega[11]   // lichtcyaan
        val rand = ega[15]   // wit

        for (y in 4 until (HOOGTE - 4)) {
            for (x in 4 until (BREEDTE - 4)) {
                // Twee stelsels diagonalen kruisen elkaar tot een ruitennet.
                val heen = (x + y) % 10
                val terug = (x - y + 500) % 10
                var c = veld
                if (heen < 2 || terug < 2) c = ruit
                if (heen < 2 && terug < 2) c = stip   // kruispunt licht op
                bm.zet(x, y, c)
            }
        }

        // Witte bies net binnen de zwarte kaartrand.
        for (x in 3 until (BREEDTE - 3)) { bm.zet(x, 3, rand); bm.zet(x, HOOGTE - 4, rand) }
        for (y in 3 until (HOOGTE - 3)) { bm.zet(3, y, rand); bm.zet(BREEDTE - 4, y, rand) }

        return bm
    }

    // -------------------------------------------------- pixelkunst vergroten

    /**
     * Scale2x (EPX): verdubbelt de afbeelding en vult de hoeken van elk blokje met de
     * buurkleur zodra twee buren aan weerszijden gelijk zijn. Trapjes in schuine lijnen
     * worden afgerond, vlakken en rechte randen blijven scherp.
     */
    fun scale2x(src: Afbeelding): Afbeelding {
        val w = src.breedte
        val h = src.hoogte
        val p = src.pixels
        val d = IntArray(w * 2 * h * 2)
        val dw = w * 2

        fun at(x: Int, y: Int): Int = p[y.coerceIn(0, h - 1) * w + x.coerceIn(0, w - 1)]

        for (y in 0 until h) {
            for (x in 0 until w) {
                val e = p[y * w + x]
                val a = at(x, y - 1)
                val b = at(x + 1, y)
                val c = at(x - 1, y)
                val dd = at(x, y + 1)

                val e0 = if (c == a && c != dd && a != b) a else e
                val e1 = if (a == b && a != c && b != dd) b else e
                val e2 = if (dd == c && dd != b && c != a) c else e
                val e3 = if (b == dd && b != a && dd != c) dd else e

                val o = y * 2 * dw + x * 2
                d[o] = e0; d[o + 1] = e1
                d[o + dw] = e2; d[o + dw + 1] = e3
            }
        }
        return Afbeelding(dw, h * 2, d)
    }

    /** Scale3x: hetzelfde idee, maar met een blok van drie bij drie. */
    fun scale3x(src: Afbeelding): Afbeelding {
        val w = src.breedte
        val h = src.hoogte
        val p = src.pixels
        val d = IntArray(w * 3 * h * 3)
        val dw = w * 3

        fun at(x: Int, y: Int): Int = p[y.coerceIn(0, h - 1) * w + x.coerceIn(0, w - 1)]

        for (y in 0 until h) {
            for (x in 0 until w) {
                val a = at(x - 1, y - 1)
                val b = at(x, y - 1)
                val c = at(x + 1, y - 1)
                val dd = at(x - 1, y)
                val e = p[y * w + x]
                val f = at(x + 1, y)
                val g = at(x - 1, y + 1)
                val hh = at(x, y + 1)
                val i = at(x + 1, y + 1)

                val e0 = if (dd == b && dd != hh && b != f) dd else e
                val e1 = if ((dd == b && dd != hh && b != f && e != c)
                    || (b == f && b != dd && f != hh && e != a)) b else e
                val e2 = if (b == f && b != dd && f != hh) f else e
                val e3 = if ((dd == b && dd != hh && b != f && e != g)
                    || (dd == hh && dd != b && hh != f && e != a)) dd else e
                val e5 = if ((b == f && b != dd && f != hh && e != i)
                    || (f == hh && dd != hh && b != f && e != c)) f else e
                val e6 = if (dd == hh && dd != b && hh != f) dd else e
                val e7 = if ((f == hh && dd != hh && b != f && e != g)
                    || (dd == hh && dd != b && hh != f && e != i)) hh else e
                val e8 = if (f == hh && dd != hh && b != f) f else e

                val o = y * 3 * dw + x * 3
                d[o] = e0; d[o + 1] = e1; d[o + 2] = e2
                d[o + dw] = e3; d[o + dw + 1] = e; d[o + dw + 2] = e5
                d[o + 2 * dw] = e6; d[o + 2 * dw + 1] = e7; d[o + 2 * dw + 2] = e8
            }
        }
        return Afbeelding(dw, h * 3, d)
    }
}

/**
 * De 32 kaarten plus de achterkant, eenmaal opgebouwd op een vaste vergroting.
 * Een gewoon object dat de app zelf vasthoudt; bij een andere schermgrootte maak je
 * er simpelweg een nieuwe.
 */
class Kaartenset(val schaal: Int = 1) {
    /** [0..31] de kaarten, [32] de achterkant. */
    val alle: List<Afbeelding>

    init {
        var reeks = ArrayList<Afbeelding>(33)
        for (kleur in 0 until 4) {
            for (rang in 0 until 8) reeks.add(OrigineleKaarten.bouwKaart(OrigineleKaarten.RANG_ROEM[rang], kleur))
        }
        reeks.add(OrigineleKaarten.bouwAchterkant())

        if (schaal > 1) {
            var gedaan = if (schaal == 3) 3 else 2
            var groot = reeks.map { if (schaal == 3) OrigineleKaarten.scale3x(it) else OrigineleKaarten.scale2x(it) }
            // Voor 4x en hoger: het 2x-resultaat nogmaals verdubbelen, enzovoort.
            while (gedaan < schaal) {
                groot = groot.map { OrigineleKaarten.scale2x(it) }
                gedaan *= 2
            }
            reeks = ArrayList(groot)
        }
        alle = reeks
    }

    val achterkant: Afbeelding get() = alle[32]

    /** Voorkant van kaart (naam, kleur); kleur 0..3, naam uit "AHVBT987". */
    fun voor(naam: Char, kleur: Int): Afbeelding? {
        val rang = OrigineleKaarten.RANG_ROEM.indexOf(naam)
        if (rang < 0 || kleur < 0 || kleur > 3) return null
        return alle[kleur * 8 + rang]
    }
}
