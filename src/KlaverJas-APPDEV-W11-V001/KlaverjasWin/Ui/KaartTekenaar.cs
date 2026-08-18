using System.Drawing.Drawing2D;
using System.Drawing.Text;

namespace Klaverjas.Ui;

/// <summary>
/// Tekent speelkaarten met GDI+. Het origineel bouwde elke kaart op uit losse
/// lijnen en floodfills voor een 640x350 EGA-scherm; dat is hier vervangen door
/// schaalbaar tekenwerk dat op elke resolutie scherp blijft.
/// </summary>
public static class KaartTekenaar
{
    public static readonly string[] SuitTeken = { "♣", "♠", "♦", "♥" }; // ♣ ♠ ♦ ♥
    // Voor de naam van een kleur: Taal.KleurNaam(), die de gekozen taal volgt.

    private static readonly Color Rood = Color.FromArgb(200, 30, 40);
    private static readonly Color Zwart = Color.FromArgb(25, 25, 30);

    public static Color KleurVan(int kleur) => (kleur == 2 || kleur == 3) ? Rood : Zwart;

    /// <summary>
    /// true = de zelfgetekende kaarten uit KJKRT.C gebruiken, false = de
    /// moderne vectorkaarten.
    /// </summary>
    public static bool Origineel { get; set; } = true;

    /// <summary>Breedte/hoogte van een kaart; het origineel is 53 bij 83.</summary>
    public const float Verhouding = 53f / 83f;

    /// <summary>
    /// Welke hele vergroting hoort bij deze kaartbreedte? De kaarten worden
    /// altijd met Scale2x/Scale3x vergroot, zodat schuine lijnen niet als
    /// trapjes verschijnen.
    /// </summary>
    private static int Schaal(float breedte)
        => Math.Clamp((int)Math.Round(breedte / OrigineleKaarten.Breedte), 1, 6);

    /// <summary>Rangletter uit het origineel omzetten naar wat je op de kaart ziet.</summary>
    public static string RangTekst(char naam) => naam switch
    {
        'T' => "10",
        'B' => "B",
        'V' => "V",
        'H' => "H",
        'A' => "A",
        _ => naam.ToString()
    };

    public static void TekenAchterkant(Graphics g, RectangleF r)
    {
        if (Origineel)
        {
            OrigineleKaarten.Teken(g, r, OrigineleKaarten.Achterkant(Schaal(r.Width)), false);
            return;
        }

        using var pad = Afgerond(r, r.Width * 0.09f);
        using var vul = new LinearGradientBrush(r, Color.FromArgb(40, 70, 130), Color.FromArgb(20, 40, 85), 45f);
        g.FillPath(vul, pad);

        var binnen = RectangleF.Inflate(r, -r.Width * 0.10f, -r.Width * 0.10f);
        using var lijn = new Pen(Color.FromArgb(150, 180, 220), Math.Max(1f, r.Width * 0.02f));
        using var padBinnen = Afgerond(binnen, binnen.Width * 0.08f);
        g.DrawPath(lijn, padBinnen);

        using var rand = new Pen(Color.FromArgb(15, 25, 55), Math.Max(1f, r.Width * 0.025f));
        g.DrawPath(rand, pad);
    }

    /// <summary>Tekent een open kaart.</summary>
    public static void TekenKaart(Graphics g, RectangleF r, char naam, int kleur, bool gemarkeerd = false)
    {
        if (Origineel)
        {
            var bm = OrigineleKaarten.Voor(naam, kleur, Schaal(r.Width));
            if (bm != null) { OrigineleKaarten.Teken(g, r, bm, gemarkeerd); return; }
        }

        using var pad = Afgerond(r, r.Width * 0.09f);
        using var vul = new SolidBrush(gemarkeerd ? Color.FromArgb(255, 250, 215) : Color.White);
        g.FillPath(vul, pad);
        using var rand = new Pen(gemarkeerd ? Color.FromArgb(210, 150, 20) : Color.FromArgb(120, 120, 130),
                                 Math.Max(1f, r.Width * 0.022f));
        g.DrawPath(rand, pad);

        if (kleur < 0 || kleur > 3) return;

        Color c = KleurVan(kleur);
        string rang = RangTekst(naam);
        string pip = SuitTeken[kleur];

        float hoekHoogte = r.Height * 0.20f;
        using var fRang = new Font("Segoe UI", hoekHoogte * 0.72f, FontStyle.Bold, GraphicsUnit.Pixel);
        using var fPip = new Font("Segoe UI Symbol", hoekHoogte * 0.62f, FontStyle.Regular, GraphicsUnit.Pixel);
        using var fGroot = new Font("Segoe UI Symbol", r.Height * 0.42f, FontStyle.Regular, GraphicsUnit.Pixel);
        using var kwast = new SolidBrush(c);

        var fmt = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };

        // Hoek linksboven.
        float hx = r.Left + r.Width * 0.16f;
        g.DrawString(rang, fRang, kwast, new PointF(hx, r.Top + hoekHoogte * 0.62f), fmt);
        g.DrawString(pip, fPip, kwast, new PointF(hx, r.Top + hoekHoogte * 1.42f), fmt);

        // Hoek rechtsonder, op zijn kop.
        var oud = g.Save();
        g.TranslateTransform(r.Right - r.Width * 0.16f, r.Bottom - hoekHoogte * 0.62f);
        g.RotateTransform(180f);
        g.DrawString(rang, fRang, kwast, PointF.Empty, fmt);
        g.TranslateTransform(0, hoekHoogte * 0.80f);
        g.DrawString(pip, fPip, kwast, PointF.Empty, fmt);
        g.Restore(oud);

        // Groot teken in het midden.
        g.DrawString(pip, fGroot, kwast,
            new PointF(r.Left + r.Width * 0.5f, r.Top + r.Height * 0.53f), fmt);
    }

    /// <summary>Kaart plus het label van de speler die hem legde.</summary>
    public static void TekenGespeeld(Graphics g, RectangleF r, char naam, int kleur, string label)
    {
        TekenKaart(g, r, naam, kleur);
        if (string.IsNullOrEmpty(label)) return;
        using var f = new Font("Segoe UI", r.Height * 0.11f, FontStyle.Bold, GraphicsUnit.Pixel);
        using var b = new SolidBrush(Color.FromArgb(235, 240, 245));
        var fmt = new StringFormat { Alignment = StringAlignment.Center };
        g.DrawString(label, f, b, new PointF(r.Left + r.Width / 2, r.Bottom + 3), fmt);
    }

    private static GraphicsPath Afgerond(RectangleF r, float straal)
    {
        var pad = new GraphicsPath();
        float d = straal * 2;
        pad.AddArc(r.Left, r.Top, d, d, 180, 90);
        pad.AddArc(r.Right - d, r.Top, d, d, 270, 90);
        pad.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        pad.AddArc(r.Left, r.Bottom - d, d, d, 90, 90);
        pad.CloseFigure();
        return pad;
    }

    public static void ZetKwaliteit(Graphics g)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
    }
}
