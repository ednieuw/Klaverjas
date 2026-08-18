/// Een kale afbeelding: pixels als 0xAARRGGBB, rij voor rij.
///
/// Bewust geen CGImage. De kaarten worden per pixel opgebouwd en alleen op hele
/// veelvouden vergroot; er komt geen tekenframework aan te pas. Het omzetten
/// naar iets wat het scherm kan tonen gebeurt pas in de app.
public struct Afbeelding: Sendable {
    public let breedte: Int
    public let hoogte: Int
    public var pixels: [UInt32]

    public init(breedte: Int, hoogte: Int, vulling: UInt32 = 0) {
        self.breedte = breedte
        self.hoogte = hoogte
        self.pixels = [UInt32](repeating: vulling, count: breedte * hoogte)
    }

    public init(breedte: Int, hoogte: Int, pixels: [UInt32]) {
        self.breedte = breedte
        self.hoogte = hoogte
        self.pixels = pixels
    }

    public subscript(x: Int, y: Int) -> UInt32 {
        get { pixels[y * breedte + x] }
        set { pixels[y * breedte + x] = newValue }
    }

    /// Zet één pixel; buiten de afbeelding valt weg, net als in het origineel.
    public mutating func zet(_ x: Int, _ y: Int, _ kleur: UInt32) {
        if x < 0 || y < 0 || x >= breedte || y >= hoogte { return }
        pixels[y * breedte + x] = kleur
    }
}

/// Bouwt de 32 kaarten precies zo op als KJKRT.C dat deed: een wit vlak van
/// 53x83 met zwarte rand, daarin de pixeltekening van de plaatkaart of de
/// kleursymbolen van de lage kaarten, plus de rangletter in de hoeken.
public enum OrigineleKaarten {
    public static let breedte = 53   // rectangle(x,y,x+52,y+82) is 53 x 83 pixels
    public static let hoogte = 83

    public static let rangRoem: [Character] = Array("AHVBT987")

    /// Het EGA/VGA-palet waar de BGI-kleurnummers naar verwijzen.
    static let ega: [UInt32] = [
        rgb(  0,   0,   0),  //  0 BLACK
        rgb(  0,   0, 170),  //  1 BLUE
        rgb(  0, 170,   0),  //  2 GREEN
        rgb(  0, 170, 170),  //  3 CYAN
        rgb(170,   0,   0),  //  4 RED
        rgb(170,   0, 170),  //  5 MAGENTA
        rgb(170,  85,   0),  //  6 BROWN
        rgb(170, 170, 170),  //  7 LIGHTGRAY
        rgb( 85,  85,  85),  //  8 DARKGRAY
        rgb( 85,  85, 255),  //  9 LIGHTBLUE
        rgb( 85, 255,  85),  // 10 LIGHTGREEN
        rgb( 85, 255, 255),  // 11 LIGHTCYAN
        rgb(255,  85,  85),  // 12 LIGHTRED
        rgb(255,  85, 255),  // 13 LIGHTMAGENTA
        rgb(255, 255,  85),  // 14 YELLOW
        rgb(255, 255, 255),  // 15 WHITE
    ]

    public static func rgb(_ r: UInt32, _ g: UInt32, _ b: UInt32) -> UInt32 {
        0xFF00_0000 | (r << 16) | (g << 8) | b
    }

    // Kleur waarmee elk kleursymbool getekend wordt, uit Klaver()/Schoppen()/Ruiten()/Harten().
    static let symboolKleur = [0, 8, 4, 12]   // zwart, donkergrijs, rood, lichtrood

    // Posities van de symbolen op de lage kaarten, uit Zeven()/Acht()/Negen()/Tien().
    static let zeven7X = [18, 11, 26, 11, 26, 11, 26]
    static let zeven7Y = [24, 9, 9, 38, 38, 52, 52]
    static let achtX = [11, 26, 11, 26, 11, 26, 11, 26]
    static let achtY = [10, 10, 24, 24, 38, 38, 52, 52]
    static let negenX = [11, 26, 3, 18, 34, 11, 26, 3, 34]
    static let negenY = [10, 10, 24, 24, 24, 38, 38, 52, 52]
    static let tienX = [11, 26, 3, 18, 34, 11, 26, 3, 18, 34]
    static let tienY = [10, 10, 24, 24, 24, 38, 38, 52, 52, 52]

    /// Het 8x8 tekenblok waarmee BGI zijn standaardfont tekende, voor de paar
    /// tekens die op de kaarten voorkomen.
    static let font: [Character: [UInt8]] = [
        "A": [0x30, 0x78, 0xCC, 0xCC, 0xFC, 0xCC, 0xCC, 0x00],
        "H": [0xCC, 0xCC, 0xCC, 0xFC, 0xCC, 0xCC, 0xCC, 0x00],
        "V": [0xC6, 0xC6, 0xC6, 0xC6, 0x6C, 0x38, 0x10, 0x00],
        "B": [0xFC, 0x66, 0x66, 0x7C, 0x66, 0x66, 0xFC, 0x00],
        "0": [0x7C, 0xC6, 0xCE, 0xDE, 0xF6, 0xE6, 0x7C, 0x00],
        "1": [0x30, 0x70, 0x30, 0x30, 0x30, 0x30, 0xFC, 0x00],
        "7": [0xFE, 0xC6, 0x0C, 0x18, 0x30, 0x30, 0x30, 0x00],
        "8": [0x7C, 0xC6, 0xC6, 0x7C, 0xC6, 0xC6, 0x7C, 0x00],
        "9": [0x7C, 0xC6, 0xC6, 0x7E, 0x06, 0x0C, 0x78, 0x00],
    ]

    // ------------------------------------------------------------ opbouw

    /// kaartvorm(): zwarte rand met wit vlak erbinnen.
    static func kaartvorm() -> Afbeelding {
        var bm = Afbeelding(breedte: breedte, hoogte: hoogte, vulling: ega[15])
        for x in 0..<breedte { bm.zet(x, 0, ega[0]); bm.zet(x, hoogte - 1, ega[0]) }
        for y in 0..<hoogte { bm.zet(0, y, ega[0]); bm.zet(breedte - 1, y, ega[0]) }
        return bm
    }

    static func bouwKaart(_ naam: Character, _ kleur: Int) -> Afbeelding {
        var bm = kaartvorm()
        if let plaat = KaartData.plaat(naam) {
            tekenPlaatkaart(&bm, plaat, KaartData.palet(naam)!, kleur, naam)
        } else {
            tekenLageKaart(&bm, naam, kleur)
        }
        return bm
    }

    /// Kleine letter van een ASCII-teken; niet-letters blijven zoals ze zijn.
    static func klein(_ b: UInt8) -> UInt8 { (b >= 65 && b <= 90) ? b + 32 : b }

    /// Aas, heer, vrouw of boer: de pixeltekening plus hoeksymbolen.
    static func tekenPlaatkaart(_ bm: inout Afbeelding, _ plaat: [String],
                                _ palet: [(teken: Character, kleur: Int)],
                                _ kleur: Int, _ naam: Character) {
        var tabel = [Int](repeating: -2, count: 128)   // -2 = niet in de tabel
        for (teken, k) in palet {
            if let a = teken.asciiValue { tabel[Int(klein(a))] = k }
        }

        for n in 0..<plaat.count {
            let rij = Array(plaat[n].utf8)
            for m in 0..<min(48, rij.count) {
                let c = klein(rij[m])
                var k = c < 128 ? tabel[Int(c)] : -2
                if k == -2 { continue }
                if k == -1 { k = 2 + kleur }                     // GREEN + kleurnummer
                bm.zet(m + 2, n + 17, ega[k & 15])
            }
        }

        // Rangletter midden tussen de twee hoeksymbolen: die staan op x 2..15 en
        // x 37..50, dus het midden van de kaart (x 26) is precies de vrije ruimte.
        // Verticaal op dezelfde hoogte als de symbolen: 2..15 en 67..80.
        tekst(&bm, 26, 9, String(naam), 2, ega[0])
        tekst(&bm, 26, 74, String(naam), 2, ega[0])

        tekenSymbool(&bm, 2, 2, kleur)
        tekenSymbool(&bm, 37, 2, kleur)
        tekenSymbool(&bm, 37, 67, kleur)
        tekenSymbool(&bm, 2, 67, kleur)
    }

    /// Tien, negen, acht of zeven: symbolen in het vlak, cijfers in de hoeken.
    static func tekenLageKaart(_ bm: inout Afbeelding, _ naam: Character, _ kleur: Int) {
        let px: [Int], py: [Int]
        let cijfer: String
        switch naam {
        case "T": px = tienX; py = tienY; cijfer = "10"
        case "9": px = negenX; py = negenY; cijfer = "9"
        case "8": px = achtX; py = achtY; cijfer = "8"
        default:  px = zeven7X; py = zeven7Y; cijfer = "7"
        }

        for j in 0..<px.count {
            tekenSymbool(&bm, px[j] + 1, py[j] + 2, kleur)
        }

        // Hoekcijfers met vier pixels marge aan alle kanten. Het origineel zette
        // ze op x+4/x+40 en y+4/y+72, wat links en boven tegen de rand aan liep
        // en rechts en onder ruim negen pixels ruimte overliet.
        if cijfer == "10" {
            // De 1 en de 0 staan los, zes pixels uit elkaar.
            tekst(&bm, 8, 7, "1", 1, ega[0])
            tekst(&bm, 14, 7, "0", 1, ega[0])
            tekst(&bm, 8, 75, "1", 1, ega[0])
            tekst(&bm, 14, 75, "0", 1, ega[0])
            tekst(&bm, 38, 7, "1", 1, ega[0])
            tekst(&bm, 44, 7, "0", 1, ega[0])
            tekst(&bm, 38, 75, "1", 1, ega[0])
            tekst(&bm, 44, 75, "0", 1, ega[0])
        } else {
            tekst(&bm, 8, 7, cijfer, 1, ega[0])
            tekst(&bm, 8, 75, cijfer, 1, ega[0])
            tekst(&bm, 44, 7, cijfer, 1, ega[0])
            tekst(&bm, 44, 75, cijfer, 1, ega[0])
        }
    }

    /// Een 14x14 kleursymbool; 'w' blijft leeg, de rest krijgt de kleur.
    static func tekenSymbool(_ bm: inout Afbeelding, _ x: Int, _ y: Int, _ kleur: Int) {
        let data = KaartData.symbool(kleur)
        let c = ega[symboolKleur[kleur]]
        for i in 0..<min(14, data.count) {
            let rij = Array(data[i].utf8)
            for j in 0..<min(14, rij.count) where klein(rij[j]) != UInt8(ascii: "w") {
                bm.zet(x + j, y + i, c)
            }
        }
    }

    /// Zet tekst met (x,y) als middelpunt. Er wordt gecentreerd op de pixels die
    /// werkelijk gezet worden, niet op het 8x8 tekenvak: de letters vullen dat
    /// vak maar voor 6 a 7 pixels en zitten linksboven, zodat centreren op het
    /// vak alles naar linksboven laat schuiven.
    static func tekst(_ bm: inout Afbeelding, _ x: Int, _ y: Int,
                      _ tekst: String, _ schaal: Int, _ kleur: UInt32) {
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min

        let tekens = Array(tekst)
        for t in 0..<tekens.count {
            guard let glyph = font[tekens[t]] else { continue }
            for r in 0..<8 {
                for b in 0..<8 where (glyph[r] & (0x80 >> UInt8(b))) != 0 {
                    let gx = t * 8 + b
                    if gx < minX { minX = gx }
                    if gx > maxX { maxX = gx }
                    if r < minY { minY = r }
                    if r > maxY { maxY = r }
                }
            }
        }
        if minX > maxX { return }   // niets te tekenen

        let inktBreed = (maxX - minX + 1) * schaal
        let inktHoog = (maxY - minY + 1) * schaal
        let x0 = x - inktBreed / 2 - minX * schaal
        let y0 = y - inktHoog / 2 - minY * schaal

        for t in 0..<tekens.count {
            guard let glyph = font[tekens[t]] else { continue }
            for r in 0..<8 {
                for b in 0..<8 where (glyph[r] & (0x80 >> UInt8(b))) != 0 {
                    for sy in 0..<schaal {
                        for sx in 0..<schaal {
                            bm.zet(x0 + (t * 8 + b) * schaal + sx, y0 + r * schaal + sy, kleur)
                        }
                    }
                }
            }
        }
    }

    /// De achterkant. Het origineel vulde die met INTERLEAVE_FILL in geel, wat
    /// neerkomt op een egaal raster. Hier een ruitpatroon van diagonalen met een
    /// dubbele rand eromheen, in dezelfde EGA-kleuren als de kaarten zelf.
    static func bouwAchterkant() -> Afbeelding {
        var bm = kaartvorm()
        let veld = ega[1]    // blauw
        let ruit = ega[9]    // lichtblauw
        let stip = ega[11]   // lichtcyaan
        let rand = ega[15]   // wit

        for y in 4..<(hoogte - 4) {
            for x in 4..<(breedte - 4) {
                // Twee stelsels diagonalen kruisen elkaar tot een ruitennet.
                let heen = (x + y) % 10
                let terug = (x - y + 500) % 10
                var c = veld
                if heen < 2 || terug < 2 { c = ruit }
                if heen < 2 && terug < 2 { c = stip }   // kruispunt licht op
                bm.zet(x, y, c)
            }
        }

        // Witte bies net binnen de zwarte kaartrand.
        for x in 3..<(breedte - 3) { bm.zet(x, 3, rand); bm.zet(x, hoogte - 4, rand) }
        for y in 3..<(hoogte - 3) { bm.zet(3, y, rand); bm.zet(breedte - 4, y, rand) }

        return bm
    }

    // -------------------------------------------------- pixelkunst vergroten

    /// Scale2x (ook bekend als EPX): verdubbelt de afbeelding en vult de hoeken
    /// van elk blokje met de buurkleur zodra twee buren aan weerszijden gelijk
    /// zijn. Trapjes in schuine lijnen worden daardoor afgerond, terwijl vlakken
    /// en rechte randen scherp blijven - vervagen doet het niet.
    public static func scale2x(_ src: Afbeelding) -> Afbeelding {
        let w = src.breedte, h = src.hoogte
        let p = src.pixels
        var d = [UInt32](repeating: 0, count: w * 2 * h * 2)
        let dw = w * 2

        func at(_ x: Int, _ y: Int) -> UInt32 {
            p[min(max(y, 0), h - 1) * w + min(max(x, 0), w - 1)]
        }

        for y in 0..<h {
            for x in 0..<w {
                let e = p[y * w + x]
                let a = at(x, y - 1), b = at(x + 1, y), c = at(x - 1, y), dd = at(x, y + 1)

                let e0 = (c == a && c != dd && a != b) ? a : e
                let e1 = (a == b && a != c && b != dd) ? b : e
                let e2 = (dd == c && dd != b && c != a) ? c : e
                let e3 = (b == dd && b != a && dd != c) ? dd : e

                let o = y * 2 * dw + x * 2
                d[o] = e0; d[o + 1] = e1
                d[o + dw] = e2; d[o + dw + 1] = e3
            }
        }

        return Afbeelding(breedte: dw, hoogte: h * 2, pixels: d)
    }

    /// Scale3x: hetzelfde idee, maar met een blok van drie bij drie.
    public static func scale3x(_ src: Afbeelding) -> Afbeelding {
        let w = src.breedte, h = src.hoogte
        let p = src.pixels
        var d = [UInt32](repeating: 0, count: w * 3 * h * 3)
        let dw = w * 3

        func at(_ x: Int, _ y: Int) -> UInt32 {
            p[min(max(y, 0), h - 1) * w + min(max(x, 0), w - 1)]
        }

        for y in 0..<h {
            for x in 0..<w {
                let a = at(x - 1, y - 1), b = at(x, y - 1), c = at(x + 1, y - 1)
                let dd = at(x - 1, y), e = p[y * w + x], f = at(x + 1, y)
                let g = at(x - 1, y + 1), hh = at(x, y + 1), i = at(x + 1, y + 1)

                let e0 = (dd == b && dd != hh && b != f) ? dd : e
                let e1 = ((dd == b && dd != hh && b != f && e != c)
                       || (b == f && b != dd && f != hh && e != a)) ? b : e
                let e2 = (b == f && b != dd && f != hh) ? f : e
                let e3 = ((dd == b && dd != hh && b != f && e != g)
                       || (dd == hh && dd != b && hh != f && e != a)) ? dd : e
                let e5 = ((b == f && b != dd && f != hh && e != i)
                       || (f == hh && dd != hh && b != f && e != c)) ? f : e
                let e6 = (dd == hh && dd != b && hh != f) ? dd : e
                let e7 = ((f == hh && dd != hh && b != f && e != g)
                       || (dd == hh && dd != b && hh != f && e != i)) ? hh : e
                let e8 = (f == hh && dd != hh && b != f) ? f : e

                let o = y * 3 * dw + x * 3
                d[o] = e0; d[o + 1] = e1; d[o + 2] = e2
                d[o + dw] = e3; d[o + dw + 1] = e; d[o + dw + 2] = e5
                d[o + 2 * dw] = e6; d[o + 2 * dw + 1] = e7; d[o + 2 * dw + 2] = e8
            }
        }

        return Afbeelding(breedte: dw, hoogte: h * 3, pixels: d)
    }
}

/// De 32 kaarten plus de achterkant, eenmaal opgebouwd op een vaste vergroting.
///
/// De C#-versie hield dit in statische velden bij. Hier is het een gewoon
/// object dat de app zelf vasthoudt: geen gedeelde veranderlijke toestand, en
/// bij het wisselen van schermgrootte maak je er simpelweg een nieuwe.
public final class Kaartenset: Sendable {
    public let schaal: Int
    private let kaarten: [Afbeelding]   // [0..31] de kaarten, [32] de achterkant

    public init(schaal: Int = 1) {
        self.schaal = schaal

        var reeks: [Afbeelding] = []
        reeks.reserveCapacity(33)
        for kleur in 0..<4 {
            for rang in 0..<8 {
                reeks.append(OrigineleKaarten.bouwKaart(OrigineleKaarten.rangRoem[rang], kleur))
            }
        }
        reeks.append(OrigineleKaarten.bouwAchterkant())

        if schaal > 1 {
            reeks = reeks.map { schaal == 3 ? OrigineleKaarten.scale3x($0)
                                            : OrigineleKaarten.scale2x($0) }
            // Voor 4x en hoger: het 2x-resultaat nogmaals verdubbelen, enzovoort.
            var gedaan = schaal == 3 ? 3 : 2
            while gedaan < schaal {
                reeks = reeks.map { OrigineleKaarten.scale2x($0) }
                gedaan *= 2
            }
        }
        kaarten = reeks
    }

    public var achterkant: Afbeelding { kaarten[32] }

    /// Voorkant van kaart (naam, kleur); kleur 0..3, naam uit "AHVBT987".
    public func voor(_ naam: Character, _ kleur: Int) -> Afbeelding? {
        guard let rang = OrigineleKaarten.rangRoem.firstIndex(of: naam),
              kleur >= 0, kleur < 4 else { return nil }
        return kaarten[kleur * 8 + rang]
    }

    /// Alle 33 afbeeldingen, in de volgorde die het contactblad gebruikt.
    public var alle: [Afbeelding] { kaarten }
}
