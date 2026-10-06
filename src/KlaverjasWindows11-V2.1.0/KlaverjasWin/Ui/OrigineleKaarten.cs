using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

namespace Klaverjas.Ui;

/// <summary>
/// Bouwt de 32 kaarten precies zo op als KJKRT.C dat deed: een wit vlak van
/// 53x83 met zwarte rand, daarin de pixeltekening van de plaatkaart of de
/// kleursymbolen van de lage kaarten, plus de rangletter in de hoeken.
/// De kaarten worden eenmalig gemaakt en daarna alleen nog geschaald getekend,
/// net als het origineel dat met getimage/putimage deed.
/// </summary>
internal static class OrigineleKaarten
{
    public const int Breedte = 53;   // rectangle(x,y,x+52,y+82) is 53 x 83 pixels
    public const int Hoogte = 83;

    private const string RangRoem = "AHVBT987";

    /// <summary>Het EGA/VGA-palet waar de BGI-kleurnummers naar verwijzen.</summary>
    private static readonly Color[] Ega =
    {
        Color.FromArgb(  0,   0,   0),  //  0 BLACK
        Color.FromArgb(  0,   0, 170),  //  1 BLUE
        Color.FromArgb(  0, 170,   0),  //  2 GREEN
        Color.FromArgb(  0, 170, 170),  //  3 CYAN
        Color.FromArgb(170,   0,   0),  //  4 RED
        Color.FromArgb(170,   0, 170),  //  5 MAGENTA
        Color.FromArgb(170,  85,   0),  //  6 BROWN
        Color.FromArgb(170, 170, 170),  //  7 LIGHTGRAY
        Color.FromArgb( 85,  85,  85),  //  8 DARKGRAY
        Color.FromArgb( 85,  85, 255),  //  9 LIGHTBLUE
        Color.FromArgb( 85, 255,  85),  // 10 LIGHTGREEN
        Color.FromArgb( 85, 255, 255),  // 11 LIGHTCYAN
        Color.FromArgb(255,  85,  85),  // 12 LIGHTRED
        Color.FromArgb(255,  85, 255),  // 13 LIGHTMAGENTA
        Color.FromArgb(255, 255,  85),  // 14 YELLOW
        Color.FromArgb(255, 255, 255),  // 15 WHITE
    };

    // Kleur waarmee elk kleursymbool getekend wordt, uit Klaver()/Schoppen()/Ruiten()/Harten().
    private static readonly int[] SymboolKleur = { 0, 8, 4, 12 };  // zwart, donkergrijs, rood, lichtrood

    // Posities van de symbolen op de lage kaarten, uit Zeven()/Acht()/Negen()/Tien().
    private static readonly int[] Zeven7X = { 18, 11, 26, 11, 26, 11, 26 };
    private static readonly int[] Zeven7Y = { 24, 9, 9, 38, 38, 52, 52 };
    private static readonly int[] AchtX = { 11, 26, 11, 26, 11, 26, 11, 26 };
    private static readonly int[] AchtY = { 10, 10, 24, 24, 38, 38, 52, 52 };
    private static readonly int[] NegenX = { 11, 26, 3, 18, 34, 11, 26, 3, 34 };
    private static readonly int[] NegenY = { 10, 10, 24, 24, 24, 38, 38, 52, 52 };
    private static readonly int[] TienX = { 11, 26, 3, 18, 34, 11, 26, 3, 18, 34 };
    private static readonly int[] TienY = { 10, 10, 24, 24, 24, 38, 38, 52, 52, 52 };

    /// <summary>
    /// Het 8x8 tekenblok waarmee BGI zijn standaardfont tekende, voor de paar
    /// tekens die op de kaarten voorkomen.
    /// </summary>
    private static readonly Dictionary<char, byte[]> Font = new()
    {
        ['A'] = new byte[] { 0x30, 0x78, 0xCC, 0xCC, 0xFC, 0xCC, 0xCC, 0x00 },
        ['H'] = new byte[] { 0xCC, 0xCC, 0xCC, 0xFC, 0xCC, 0xCC, 0xCC, 0x00 },
        ['V'] = new byte[] { 0xC6, 0xC6, 0xC6, 0xC6, 0x6C, 0x38, 0x10, 0x00 },
        ['B'] = new byte[] { 0xFC, 0x66, 0x66, 0x7C, 0x66, 0x66, 0xFC, 0x00 },
        ['0'] = new byte[] { 0x7C, 0xC6, 0xCE, 0xDE, 0xF6, 0xE6, 0x7C, 0x00 },
        ['1'] = new byte[] { 0x30, 0x70, 0x30, 0x30, 0x30, 0x30, 0xFC, 0x00 },
        ['7'] = new byte[] { 0xFE, 0xC6, 0x0C, 0x18, 0x30, 0x30, 0x30, 0x00 },
        ['8'] = new byte[] { 0x7C, 0xC6, 0xC6, 0x7C, 0xC6, 0xC6, 0x7C, 0x00 },
        ['9'] = new byte[] { 0x7C, 0xC6, 0xC6, 0x7E, 0x06, 0x0C, 0x78, 0x00 },
    };

    // [0..31] de kaarten, [32] de achterkant. _variant[schaal] bevat dezelfde
    // reeks, vergroot met Scale2x/Scale3x.
    private static Bitmap[] _kaarten;
    private static readonly Dictionary<int, Bitmap[]> _variant = new();

    public static Bitmap Achterkant(int schaal) => Blad(schaal)[32];

    /// <summary>Voorkant van kaart (kleur, naam); kleur 0..3, naam uit "AHVBT987".</summary>
    public static Bitmap Voor(char naam, int kleur, int schaal)
    {
        int rang = RangRoem.IndexOf(naam);
        if (rang < 0 || kleur < 0 || kleur > 3) return null;
        return Blad(schaal)[kleur * 8 + rang];
    }

    private static Bitmap[] Blad(int schaal)
    {
        Zorg();
        if (schaal <= 1) return _kaarten;
        if (_variant.TryGetValue(schaal, out var bestaand)) return bestaand;

        var reeks = new Bitmap[_kaarten.Length];
        for (int i = 0; i < _kaarten.Length; i++)
            reeks[i] = schaal == 3 ? Scale3x(_kaarten[i]) : Scale2x(_kaarten[i]);

        // Voor 4x en hoger: het 2x-resultaat nogmaals verdubbelen, enzovoort.
        for (int gedaan = schaal == 3 ? 3 : 2; gedaan < schaal; gedaan *= 2)
            for (int i = 0; i < reeks.Length; i++)
            {
                var oud = reeks[i];
                reeks[i] = Scale2x(oud);
                oud.Dispose();
            }

        _variant[schaal] = reeks;
        return reeks;
    }

    private static void Zorg()
    {
        if (_kaarten != null) return;
        var reeks = new Bitmap[33];
        for (int kleur = 0; kleur < 4; kleur++)
            for (int rang = 0; rang < 8; rang++)
                reeks[kleur * 8 + rang] = BouwKaart(RangRoem[rang], kleur);
        reeks[32] = BouwAchterkant();
        _kaarten = reeks;
    }

    // -------------------------------------------------- pixelkunst vergroten

    private static int[] Lees(Bitmap bm, out int breed, out int hoog)
    {
        breed = bm.Width;
        hoog = bm.Height;
        var uit = new int[breed * hoog];
        var slot = bm.LockBits(new Rectangle(0, 0, breed, hoog), ImageLockMode.ReadOnly,
                               PixelFormat.Format32bppArgb);
        try
        {
            for (int y = 0; y < hoog; y++)
                System.Runtime.InteropServices.Marshal.Copy(
                    slot.Scan0 + y * slot.Stride, uit, y * breed, breed);
        }
        finally { bm.UnlockBits(slot); }
        return uit;
    }

    private static Bitmap Schrijf(int[] pixels, int breed, int hoog)
    {
        var bm = new Bitmap(breed, hoog, PixelFormat.Format32bppArgb);
        var slot = bm.LockBits(new Rectangle(0, 0, breed, hoog), ImageLockMode.WriteOnly,
                               PixelFormat.Format32bppArgb);
        try
        {
            for (int y = 0; y < hoog; y++)
                System.Runtime.InteropServices.Marshal.Copy(
                    pixels, y * breed, slot.Scan0 + y * slot.Stride, breed);
        }
        finally { bm.UnlockBits(slot); }
        return bm;
    }

    /// <summary>
    /// Scale2x (ook bekend als EPX): verdubbelt de afbeelding en vult de hoeken
    /// van elk blokje met de buurkleur zodra twee buren aan weerszijden gelijk
    /// zijn. Trapjes in schuine lijnen worden daardoor afgerond, terwijl vlakken
    /// en rechte randen scherp blijven - vervagen doet het niet.
    /// </summary>
    private static Bitmap Scale2x(Bitmap src)
    {
        var p = Lees(src, out int w, out int h);
        var d = new int[w * 2 * h * 2];
        int dw = w * 2;

        int At(int x, int y) => p[Math.Clamp(y, 0, h - 1) * w + Math.Clamp(x, 0, w - 1)];

        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int e = p[y * w + x];
                int a = At(x, y - 1), b = At(x + 1, y), c = At(x - 1, y), dd = At(x, y + 1);

                int e0 = (c == a && c != dd && a != b) ? a : e;
                int e1 = (a == b && a != c && b != dd) ? b : e;
                int e2 = (dd == c && dd != b && c != a) ? c : e;
                int e3 = (b == dd && b != a && dd != c) ? dd : e;

                int o = y * 2 * dw + x * 2;
                d[o] = e0; d[o + 1] = e1;
                d[o + dw] = e2; d[o + dw + 1] = e3;
            }

        return Schrijf(d, dw, h * 2);
    }

    /// <summary>Scale3x: hetzelfde idee, maar met een blok van drie bij drie.</summary>
    private static Bitmap Scale3x(Bitmap src)
    {
        var p = Lees(src, out int w, out int h);
        var d = new int[w * 3 * h * 3];
        int dw = w * 3;

        int At(int x, int y) => p[Math.Clamp(y, 0, h - 1) * w + Math.Clamp(x, 0, w - 1)];

        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int a = At(x - 1, y - 1), b = At(x, y - 1), c = At(x + 1, y - 1);
                int dd = At(x - 1, y), e = p[y * w + x], f = At(x + 1, y);
                int g = At(x - 1, y + 1), hh = At(x, y + 1), i = At(x + 1, y + 1);

                int e0 = (dd == b && dd != hh && b != f) ? dd : e;
                int e1 = ((dd == b && dd != hh && b != f && e != c) ||
                          (b == f && b != dd && f != hh && e != a)) ? b : e;
                int e2 = (b == f && b != dd && f != hh) ? f : e;
                int e3 = ((dd == b && dd != hh && b != f && e != g) ||
                          (dd == hh && dd != b && hh != f && e != a)) ? dd : e;
                int e5 = ((b == f && b != dd && f != hh && e != i) ||
                          (f == hh && dd != hh && b != f && e != c)) ? f : e;
                int e6 = (dd == hh && dd != b && hh != f) ? dd : e;
                int e7 = ((f == hh && dd != hh && b != f && e != g) ||
                          (dd == hh && dd != b && hh != f && e != i)) ? hh : e;
                int e8 = (f == hh && dd != hh && b != f) ? f : e;

                int o = y * 3 * dw + x * 3;
                d[o] = e0; d[o + 1] = e1; d[o + 2] = e2;
                d[o + dw] = e3; d[o + dw + 1] = e; d[o + dw + 2] = e5;
                d[o + 2 * dw] = e6; d[o + 2 * dw + 1] = e7; d[o + 2 * dw + 2] = e8;
            }

        return Schrijf(d, dw, h * 3);
    }

    // ------------------------------------------------------------ opbouw

    /// <summary>kaartvorm(): zwarte rand met wit vlak erbinnen.</summary>
    private static Bitmap Kaartvorm()
    {
        var bm = new Bitmap(Breedte, Hoogte, PixelFormat.Format32bppArgb);
        using var g = Graphics.FromImage(bm);
        g.Clear(Ega[15]);
        using var pen = new Pen(Ega[0]);
        g.DrawRectangle(pen, 0, 0, Breedte - 1, Hoogte - 1);
        return bm;
    }

    private static Bitmap BouwKaart(char naam, int kleur)
    {
        var bm = Kaartvorm();
        var plaat = KaartData.Plaat(naam);

        if (plaat != null) TekenPlaatkaart(bm, plaat, KaartData.Palet(naam), kleur, naam);
        else TekenLageKaart(bm, naam, kleur);

        return bm;
    }

    /// <summary>Aas, heer, vrouw of boer: de pixeltekening plus hoeksymbolen.</summary>
    private static void TekenPlaatkaart(Bitmap bm, string[] plaat, (char Teken, int Kleur)[] palet,
                                        int kleur, char naam)
    {
        var tabel = new int[128];
        for (int i = 0; i < tabel.Length; i++) tabel[i] = -2;          // -2 = niet in de tabel
        foreach (var (teken, k) in palet) tabel[char.ToLower(teken)] = k;

        for (int n = 0; n < plaat.Length; n++)
        {
            string rij = plaat[n];
            for (int m = 0; m < 48 && m < rij.Length; m++)
            {
                char c = char.ToLower(rij[m]);
                int k = c < 128 ? tabel[c] : -2;
                if (k == -2) continue;
                if (k == -1) k = 2 + kleur;                             // GREEN + kleurnummer
                Zet(bm, m + 2, n + 17, Ega[k & 15]);
            }
        }

        // Rangletter midden tussen de twee hoeksymbolen: die staan op x 2..15 en
        // x 37..50, dus het midden van de kaart (x 26) is precies de vrije ruimte.
        // Verticaal op dezelfde hoogte als de symbolen: 2..15 en 67..80.
        Tekst(bm, 26, 9, naam.ToString(), 2, Ega[0]);
        Tekst(bm, 26, 74, naam.ToString(), 2, Ega[0]);

        TekenSymbool(bm, 2, 2, kleur);
        TekenSymbool(bm, 37, 2, kleur);
        TekenSymbool(bm, 37, 67, kleur);
        TekenSymbool(bm, 2, 67, kleur);
    }

    /// <summary>Tien, negen, acht of zeven: symbolen in het vlak, cijfers in de hoeken.</summary>
    private static void TekenLageKaart(Bitmap bm, char naam, int kleur)
    {
        int[] px, py;
        string cijfer;
        switch (naam)
        {
            case 'T': px = TienX; py = TienY; cijfer = "10"; break;
            case '9': px = NegenX; py = NegenY; cijfer = "9"; break;
            case '8': px = AchtX; py = AchtY; cijfer = "8"; break;
            default: px = Zeven7X; py = Zeven7Y; cijfer = "7"; break;
        }

        for (int j = 0; j < px.Length; j++)
            TekenSymbool(bm, px[j] + 1, py[j] + 2, kleur);

        // Hoekcijfers met vier pixels marge aan alle kanten. Het origineel zette
        // ze op x+4/x+40 en y+4/y+72, wat links en boven tegen de rand aan liep
        // en rechts en onder ruim negen pixels ruimte overliet.
        if (cijfer == "10")
        {
            // De 1 en de 0 staan los, zes pixels uit elkaar.
            Tekst(bm, 8, 7, "1", 1, Ega[0]);
            Tekst(bm, 14, 7, "0", 1, Ega[0]);
            Tekst(bm, 8, 75, "1", 1, Ega[0]);
            Tekst(bm, 14, 75, "0", 1, Ega[0]);
            Tekst(bm, 38, 7, "1", 1, Ega[0]);
            Tekst(bm, 44, 7, "0", 1, Ega[0]);
            Tekst(bm, 38, 75, "1", 1, Ega[0]);
            Tekst(bm, 44, 75, "0", 1, Ega[0]);
        }
        else
        {
            Tekst(bm, 8, 7, cijfer, 1, Ega[0]);
            Tekst(bm, 8, 75, cijfer, 1, Ega[0]);
            Tekst(bm, 44, 7, cijfer, 1, Ega[0]);
            Tekst(bm, 44, 75, cijfer, 1, Ega[0]);
        }
    }

    /// <summary>Een 14x14 kleursymbool; 'w' blijft leeg, de rest krijgt de kleur.</summary>
    private static void TekenSymbool(Bitmap bm, int x, int y, int kleur)
    {
        var data = KaartData.Symbool(kleur);
        var c = Ega[SymboolKleur[kleur]];
        for (int i = 0; i < 14 && i < data.Length; i++)
            for (int j = 0; j < 14 && j < data[i].Length; j++)
                if (char.ToLower(data[i][j]) != 'w')
                    Zet(bm, x + j, y + i, c);
    }

    /// <summary>
    /// Zet tekst met (x,y) als middelpunt. Er wordt gecentreerd op de pixels die
    /// werkelijk gezet worden, niet op het 8x8 tekenvak: de letters vullen dat
    /// vak maar voor 6 a 7 pixels en zitten linksboven, zodat centreren op het
    /// vak alles naar linksboven laat schuiven.
    /// </summary>
    private static void Tekst(Bitmap bm, int x, int y, string tekst, int schaal, Color kleur)
    {
        int minX = int.MaxValue, maxX = int.MinValue;
        int minY = int.MaxValue, maxY = int.MinValue;

        for (int t = 0; t < tekst.Length; t++)
        {
            if (!Font.TryGetValue(tekst[t], out var glyph)) continue;
            for (int r = 0; r < 8; r++)
                for (int b = 0; b < 8; b++)
                    if ((glyph[r] & (0x80 >> b)) != 0)
                    {
                        int gx = t * 8 + b;
                        if (gx < minX) minX = gx;
                        if (gx > maxX) maxX = gx;
                        if (r < minY) minY = r;
                        if (r > maxY) maxY = r;
                    }
        }
        if (minX > maxX) return;   // niets te tekenen

        int inktBreed = (maxX - minX + 1) * schaal;
        int inktHoog = (maxY - minY + 1) * schaal;
        int x0 = x - inktBreed / 2 - minX * schaal;
        int y0 = y - inktHoog / 2 - minY * schaal;

        for (int t = 0; t < tekst.Length; t++)
        {
            if (!Font.TryGetValue(tekst[t], out var glyph)) continue;
            for (int r = 0; r < 8; r++)
                for (int b = 0; b < 8; b++)
                    if ((glyph[r] & (0x80 >> b)) != 0)
                        for (int sy = 0; sy < schaal; sy++)
                            for (int sx = 0; sx < schaal; sx++)
                                Zet(bm, x0 + (t * 8 + b) * schaal + sx, y0 + r * schaal + sy, kleur);
        }
    }

    /// <summary>
    /// De achterkant. Het origineel vulde die met INTERLEAVE_FILL in geel, wat
    /// neerkomt op een egaal raster. Hier een ruitpatroon van diagonalen met een
    /// dubbele rand eromheen, in dezelfde EGA-kleuren als de kaarten zelf.
    /// </summary>
    private static Bitmap BouwAchterkant()
    {
        var bm = Kaartvorm();
        Color veld = Ega[1];    // blauw
        Color ruit = Ega[9];    // lichtblauw
        Color stip = Ega[11];   // lichtcyaan
        Color rand = Ega[15];   // wit

        for (int y = 4; y < Hoogte - 4; y++)
            for (int x = 4; x < Breedte - 4; x++)
            {
                // Twee stelsels diagonalen kruisen elkaar tot een ruitennet.
                int heen = (x + y) % 10;
                int terug = (x - y + 500) % 10;
                Color c = veld;
                if (heen < 2 || terug < 2) c = ruit;
                if (heen < 2 && terug < 2) c = stip;   // kruispunt licht op
                Zet(bm, x, y, c);
            }

        // Witte bies net binnen de zwarte kaartrand.
        for (int x = 3; x < Breedte - 3; x++) { Zet(bm, x, 3, rand); Zet(bm, x, Hoogte - 4, rand); }
        for (int y = 3; y < Hoogte - 3; y++) { Zet(bm, 3, y, rand); Zet(bm, Breedte - 4, y, rand); }

        return bm;
    }

    private static void Zet(Bitmap bm, int x, int y, Color c)
    {
        if (x < 0 || y < 0 || x >= Breedte || y >= Hoogte) return;   // buiten de kaart valt weg
        bm.SetPixel(x, y, c);
    }

    // ----------------------------------------------------------- tekenen

    /// <summary>Tekent een kaartafbeelding scherp geschaald in een vak.</summary>
    public static void Teken(Graphics g, RectangleF vak, Bitmap kaart, bool gemarkeerd)
    {
        if (kaart == null) return;
        var oudInt = g.InterpolationMode;
        var oudPix = g.PixelOffsetMode;
        g.InterpolationMode = InterpolationMode.NearestNeighbor;
        g.PixelOffsetMode = PixelOffsetMode.Half;
        g.DrawImage(kaart, vak.X, vak.Y, vak.Width, vak.Height);
        g.InterpolationMode = oudInt;
        g.PixelOffsetMode = oudPix;

        if (gemarkeerd)
        {
            using var pen = new Pen(Color.FromArgb(255, 210, 60), Math.Max(2f, vak.Width * 0.04f));
            g.DrawRectangle(pen, vak.X, vak.Y, vak.Width, vak.Height);
        }
    }
}
