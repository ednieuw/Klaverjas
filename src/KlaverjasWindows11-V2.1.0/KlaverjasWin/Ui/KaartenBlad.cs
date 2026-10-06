using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

namespace Klaverjas.Ui;

/// <summary>
/// Zet alle kaarten naast elkaar op één afbeelding, in dezelfde indeling als
/// het originele programma die in het geheugen opbouwde: acht rangen naast
/// elkaar, vier kleuren onder elkaar, met de achterkant erachter.
/// </summary>
internal static class KaartenBlad
{
    private const string RangRoem = "AHVBT987";

    public static void Schrijf(string pad, int schaal)
    {
        int kb = OrigineleKaarten.Breedte * schaal;
        int kh = OrigineleKaarten.Hoogte * schaal;
        const int marge = 8;

        int breed = marge + 9 * (kb + marge);
        int hoog = marge + 4 * (kh + marge) + 26;

        using var blad = new Bitmap(breed, hoog, PixelFormat.Format32bppArgb);
        using var g = Graphics.FromImage(blad);
        g.Clear(Color.FromArgb(0, 100, 60));
        g.InterpolationMode = InterpolationMode.NearestNeighbor;
        g.PixelOffsetMode = PixelOffsetMode.Half;

        for (int kleur = 0; kleur < 4; kleur++)
        {
            for (int rang = 0; rang < 8; rang++)
            {
                var bm = OrigineleKaarten.Voor(RangRoem[rang], kleur, schaal);
                g.DrawImage(bm, marge + rang * (kb + marge), marge + kleur * (kh + marge), kb, kh);
            }
            if (kleur == 0)
                g.DrawImage(OrigineleKaarten.Achterkant(schaal), marge + 8 * (kb + marge), marge, kb, kh);
        }

        using var f = new Font("Segoe UI", 11f);
        using var wit = new SolidBrush(Color.White);
        g.DrawString("Kaarten uit KJKRT.C  -  rangen A H V B 10 9 8 7, kleuren klaver/schoppen/ruiten/harten",
                     f, wit, marge, hoog - 24);

        blad.Save(pad, ImageFormat.Png);
    }
}
