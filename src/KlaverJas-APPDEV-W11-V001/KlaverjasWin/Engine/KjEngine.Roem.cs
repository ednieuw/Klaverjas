namespace Klaverjas.Engine;

/// <summary>
/// Roemberekening. laagsteroem()/hoogsteroem() proberen alle mogelijke
/// verdelingen van de resterende kaarten van een kleur af en kiezen daaruit de
/// kaart die de minste resp. meeste roem weggeeft.
/// </summary>
public partial class KjEngine
{
    /// <summary>Roempunten van een reeks kaarten van één kleur.</summary>
    public int BepaalRoemPunten(char[] s, int kolor)
    {
        int stuk = 0;
        int i = 0, j = 0;

        for (int n = 0; n < 8; n++)
        {
            if (CStr.Pos(s, KjState.RangRoem[n]) != 0)
            {
                i++;
                if (i > j) j = i;
            }
            else i = 0;
        }

        if (CStr.Pos(s, 'V') != 0 && CStr.Pos(s, 'H') != 0 && kolor == S.Troef) stuk = 20;

        if (j == 3) return stuk + 20;   // drie opeenvolgend
        if (j == 4) return stuk + 50;   // vier opeenvolgend

        if (CStr.Len(s) == 4)
        {
            string t = CStr.Str(s);
            switch (t)
            {
                case "7777":
                case "8888":
                case "9999":
                case "TTTT":
                case "VVVV":
                case "HHHH":
                case "AAAA":
                    stuk = 100; S.Superroem++; break;
                case "BBBB":
                    stuk = 200; S.Superroem++; break;
            }
        }
        return stuk;
    }

    public int BepaalRoemPunten(string s, int kolor)
    {
        char[] buf = CStr.New(s.Length + 2);
        CStr.Cpy(buf, s);
        return BepaalRoemPunten(buf, kolor);
    }

    /// <summary>Welke kaart van deze kleur levert de meeste roem op?</summary>
    public char HoogsteRoem(int kkleur)
    {
        S.Hoogste = 1;
        char h = LaagsteRoem(kkleur);
        S.Hoogste = 0;
        return h;
    }

    /// <summary>
    /// Welke kaart van deze kleur geeft de minste roem weg (of, met
    /// S.Hoogste gezet, de meeste)? Bouwt alle combinaties van één kaart per
    /// speler op en weegt die.
    /// </summary>
    public char LaagsteRoem(int kkleur)
    {
        if (kkleur < 0 || kkleur > 3) return (char)0;

        int m, n, i, j, a, b, c, d, e;
        char[] roemStr = CStr.New(16);
        int[] roempnt = new int[64];
        char[][] rr = CStr.New2(64, 16);
        char[][] kt = CStr.New2(8, 16);   // kaarten van deze kleur per speler
        int[] t = new int[8];
        char skaart;

        int vrager = S.Vrager;
        if (vrager > 2) vrager -= 2;

        for (n = 0; n < 8; n++) t[n] = 0;

        for (n = kkleur * 8; n < (kkleur + 1) * 8; n++)
        {
            if (S.Kaart[n].DichtIkHy < Pos.Gespeeld)
            {
                j = S.Kaart[n].DichtIkHy;
                if (j > 10) j = 1 - (vrager - 1) + 1;   // net omgedraaide tafelkaart
                if (--j < 0) continue;                   // 0 = dicht, telt niet mee
                if (j > 3) continue;
                kt[j][t[j]] = S.Kaart[n].Naam;
                kt[j][t[j] + 1] = CStr.Nul;
                t[j]++;
            }
        }

        // Kaarten die deze slag al gespeeld zijn horen bij de roemreeks; de
        // spelers die ze legden doen niet meer mee.
        for (n = 0; n < S.SlagKrtNo; n++)
        {
            if (S.Slag(S.SlagNr, n).Kleur == kkleur)
            {
                int sp = S.Slag(S.SlagNr, n).Speler;
                if (sp >= 1 && sp <= 4) CStr.Clear(kt[sp - 1]);
                CStr.Append(roemStr, S.Slag(S.SlagNr, n).Naam);
            }
        }

        SorteerOpLengte(kt);

        int aa = CStr.Len(kt[0]), bb = CStr.Len(kt[1]);
        int cc = CStr.Len(kt[2]), dd = CStr.Len(kt[3]);
        if (aa == 0) aa++;
        if (bb == 0) bb++;
        if (cc == 0) cc++;
        if (dd == 0) dd++;

        i = 0;
        j = CStr.Len(roemStr);
        int aantal = CStr.Len(kt[0]) * bb * cc * dd;
        for (a = 0; a < aantal && i < rr.Length; a++) CStr.Cpy(rr[i++], roemStr);

        i = 0;
        for (b = 0; b < aa; b++)
            for (c = 0; c < bb; c++)
                for (d = 0; d < cc; d++)
                    for (e = 0; e < dd; e++)
                    {
                        if (i >= rr.Length) break;
                        rr[i][j + 0] = kt[0][b];
                        rr[i][j + 1] = kt[1][c];
                        rr[i][j + 2] = kt[2][d];
                        rr[i][j + 3] = kt[3][e];
                        rr[i][j + 4] = CStr.Nul;
                        i++;
                    }

        i = aa * bb * cc * dd;
        if (i > rr.Length - 1) i = rr.Length - 1;
        skaart = (char)0;

        if (S.Hoogste != 0)
        {
            m = 0;
            for (n = 0; n < i + 1; n++)
            {
                roempnt[n] = BepaalRoemPunten(rr[n], kkleur);
                if (m <= roempnt[n])
                {
                    // Aflopend door de kleur, zo eindig je bij de hoogste kaart.
                    for (j = (kkleur + 1) * 8 - 1; j >= kkleur * 8; j--)
                        if (S.Kaart[j].DichtIkHy == S.Vrager)
                        {
                            int len = CStr.Len(rr[n]);
                            for (a = 0; a < len; a++)
                                if (S.Kaart[j].Naam == rr[n][a]) { skaart = rr[n][a]; m = roempnt[n]; }
                        }
                }
            }
            return skaart;
        }

        m = 999; c = 999;
        for (n = 0; n < i; n++)
        {
            roempnt[n] = BepaalRoemPunten(rr[n], kkleur);
            if (m >= roempnt[n])
            {
                if (m > roempnt[n]) c = 999;
                // Oplopend door de kleur, zo eindig je bij de laagste kaart.
                for (j = kkleur * 8; j < (kkleur + 1) * 8; j++)
                    if (S.Kaart[j].DichtIkHy == S.Vrager)
                    {
                        int len = CStr.Len(rr[n]);
                        for (a = 0; a < len; a++)
                            if (S.Kaart[j].Naam == rr[n][a])
                            {
                                if (m > roempnt[n])
                                { c = S.Kaart[j].ActWaarde; skaart = rr[n][a]; m = roempnt[n]; }
                                if (m == roempnt[n] && c >= S.Kaart[j].ActWaarde)
                                { c = S.Kaart[j].ActWaarde; skaart = rr[n][a]; }
                            }
                    }
            }
        }
        return skaart;
    }

    /// <summary>Hoogst haalbare roem als (kkleur, skaart) gespeeld wordt.</summary>
    public int BepaalHoogsteRoem(int kkleur, char skaart)
    {
        S.Hoogste = 1;
        int r = BepaalLaagsteRoem(kkleur, skaart);
        S.Hoogste = 0;
        return r;
    }

    /// <summary>Laagst haalbare roem als (kkleur, skaart) gespeeld wordt.</summary>
    public int BepaalLaagsteRoem(int kkleur, char skaart)
    {
        if (kkleur < 0 || kkleur > 3) return 0;

        int m, n, i, j, b, c, d, e;
        int[] roempnt = new int[64];
        char[][] rr = CStr.New2(64, 16);
        char[][] kt = CStr.New2(8, 16);
        int[] t = new int[8];

        // Het origineel roept wie_vrager() hier met verwisselde argumenten aan,
        // waardoor de uitkomst altijd "niet gevonden" (-1) is. Dat pad is hier
        // behouden zodat de kaartkeuze gelijk blijft aan het origineel.
        int vrager = WieVrager((char)kkleur, skaart);
        if (vrager > 2) vrager -= 2;

        for (n = 0; n < 8; n++) t[n] = 0;

        for (n = kkleur * 8; n < (kkleur + 1) * 8; n++)
        {
            if (S.Kaart[n].DichtIkHy < Pos.Gespeeld)
            {
                j = S.Kaart[n].DichtIkHy;
                if (j > 10) j = 1 - (vrager - 1) + 1;
                if (--j < 0) continue;
                if (j > 3) continue;
                kt[j][t[j]] = S.Kaart[n].Naam;
                kt[j][t[j] + 1] = CStr.Nul;
                if (j + 1 == S.Vrager)
                {
                    kt[4][t[j]] = S.Kaart[n].Naam;
                    kt[4][t[j] + 1] = CStr.Nul;
                }
                t[j]++;
            }
        }
        CStr.Clear(kt[4]);

        // De te onderzoeken kaart wordt vastgezet in de string van zijn eigenaar.
        for (n = 0; n < 4; n++)
        {
            int len = CStr.Len(kt[n]);
            for (m = 0; m < len; m++)
                if (kt[n][m] == skaart) { kt[n][0] = skaart; kt[n][1] = CStr.Nul; }
        }

        SorteerOpLengte(kt);

        int aa = CStr.Len(kt[0]), bb = CStr.Len(kt[1]);
        int cc = CStr.Len(kt[2]), dd = CStr.Len(kt[3]);
        if (aa == 0) aa++;
        if (bb == 0) bb++;
        if (cc == 0) cc++;
        if (dd == 0) dd++;

        i = 0;
        j = 0;
        for (b = 0; b < aa; b++)
            for (c = 0; c < bb; c++)
                for (d = 0; d < cc; d++)
                    for (e = 0; e < dd; e++)
                    {
                        if (i >= rr.Length) break;
                        rr[i][j + 0] = kt[0][b];
                        rr[i][j + 1] = kt[1][c];
                        rr[i][j + 2] = kt[2][d];
                        rr[i][j + 3] = kt[3][e];
                        rr[i][j + 4] = CStr.Nul;
                        i++;
                    }

        i = aa * bb * cc * dd;
        if (i > rr.Length - 1) i = rr.Length - 1;

        if (S.Hoogste != 0)
        {
            m = 0;
            for (n = 0; n < i + 1; n++)
            {
                roempnt[n] += BepaalRoemPunten(rr[n], kkleur);
                if (m <= roempnt[n]) m = roempnt[n];
            }
            return m;
        }

        m = 999;
        for (n = 0; n < i; n++)
        {
            roempnt[n] += BepaalRoemPunten(rr[n], kkleur);
            if (m >= roempnt[n]) m = roempnt[n];
        }
        return m;
    }

    /// <summary>Bubbelsort van kt[0..4] op afnemende stringlengte, als in het origineel.</summary>
    private static void SorteerOpLengte(char[][] kt)
    {
        char[] tmp = CStr.New(16);
        for (int m = 0; m < 4; m++)
            for (int n = 0; n < 4; n++)
                if (CStr.Len(kt[n]) < CStr.Len(kt[n + 1]))
                {
                    CStr.Cpy(tmp, kt[n]);
                    CStr.Cpy(kt[n], kt[n + 1]);
                    CStr.Cpy(kt[n + 1], tmp);
                    CStr.Clear(tmp);
                }
    }
}
