namespace Klaverjas.Engine;

/// <summary>
/// bekijk_beste_slag() uit KJ.C: kiest de bij te spelen kaart als de vaste
/// tactieken van speler1/speler2/tegenspeler geen uitkomst gaven. Werkt van
/// "ik kan de slag halen" via "ik kan roem pakken" naar "gooi maar wat".
/// </summary>
public partial class KjEngine
{
    public void BekijkBesteSlag(int skleur)
    {
        int w, m, n, i, j, ii, jj;
        int rkleur = 0;
        int kt = 0, kh = 0;
        bool troeff = false;
        char skaart = (char)0;

        char[] slagstring = CStr.New(16);
        char[] troefstring = CStr.New(16);
        char[] roem = CStr.New(16);

        string slagvolgorde = S.Slag(S.SlagNr, 0).Troef != 0 ? KjState.RangTroef : KjState.RangNorm;

        i = 0;
        for (n = 0; n <= S.SlagKrtNo; n++)
            if (S.Slag(S.SlagNr, n).Troef != 0) troefstring[i++] = S.Slag(S.SlagNr, n).Naam;
        troefstring[i] = CStr.Nul;

        if (S.Slag(S.SlagNr, 0).Troef == 0)
            for (n = 1; n <= S.SlagKrtNo; n++)
                if (S.Slag(S.SlagNr, n).Troef != 0) troeff = true;   // er is ingetroefd

        i = 0;
        for (n = 0; n < 4; n++)
            if (S.Slag(S.SlagNr, n).Kleur == skleur) slagstring[i++] = S.Slag(S.SlagNr, n).Naam;
        slagstring[i] = CStr.Nul;

        // skleur verandert onderweg: sommige takken nemen de kleur over van een
        // lege hand- of tafelpositie, en die staat op 5. Het origineel las dan
        // buiten kaart[] (wat toevallig niets opleverde); daarom hier telkens
        // opnieuw controleren in plaats van eenmalig vooraf.
        bool KleurOk() => skleur >= 0 && skleur < 4;

        // ------------------------------------------------ tweede kaart
        if (S.SlagKrtNo == 1)
        {
            ii = -50;
            if (KleurOk() && S.IKrtTafel[skleur, 0] != 0)
                for (n = 0; n < 4; n++)
                    if (S.Tafel[0, n].Kleur == skleur && ii < S.Tafel[0, n].Slagkans)
                    { ii = S.Tafel[0, n].Slagkans; kt = n; }

            if (ii > KjState.SlagkansLevel) { skaart = S.Tafel[0, kt].Naam; S.Tactiek = 16; }
        }

        // ------------------------------------------------- derde kaart
        if (S.SlagKrtNo == 2)
        {
            i = -50;
            ii = -50;
            if (S.Vrager > 2 && KleurOk() && S.IKrtTafel[skleur, 0] != 0)
            {
                for (n = 0; n < 4; n++)
                    if (S.Tafel[0, n].Kleur == skleur && ii < S.Tafel[0, n].Slagkans)
                    { ii = S.Tafel[0, n].Slagkans; kt = n; }

                if (ii > S.Slag(S.SlagNr, 0).Kans && ii > KjState.SlagkansLevel)
                { S.Tactiek = 21; skaart = S.Tafel[0, kt].Naam; }

                if (skaart == 0 && WieSlag() == S.Vrager - 2 && S.Slag(S.SlagNr, 0).Kans > KjState.SlagkansLevel)
                { S.Tactiek = 22; skaart = HoogsteRoem(skleur); }
            }
            if (S.Vrager < 3 && KleurOk() && S.IKrt[skleur, 0] != 0)
            {
                for (n = 0; n < 8; n++)
                    if (S.Hand[0, n].Kleur == skleur && i < S.Hand[0, n].Slagkans)
                    { i = S.Hand[0, n].Slagkans; kh = n; }

                if (i > S.Slag(S.SlagNr, 0).Kans && i > KjState.SlagkansLevel)
                { skaart = S.Hand[0, kh].Naam; S.Tactiek = 49; }

                if (skaart == 0)
                {
                    if (WieSlag() == S.Vrager + 2 && S.Slag(S.SlagNr, 0).Kans > KjState.SlagkansLevel)
                    { S.Tactiek = 4; skaart = HoogsteRoem(skleur); }
                    else
                    {
                        S.Tactiek = 23;
                        skaart = LaagsteRoem(skleur);
                        if (skaart == 'T') skaart = (char)0;
                    }
                }
            }
        }

        // ------------------------------------------------ laatste kaart
        if (S.SlagKrtNo == 3)
        {
            i = 0;
            if (WieSlag() == S.Vrager + 2)      // de slag is al aan mijn kant
            {
                for (n = 0; n < S.SlagKrtNo; n++)
                    if (S.Slag(S.SlagNr, n).Kleur == skleur) CStr.Append(roem, S.Slag(S.SlagNr, n).Naam);

                j = CStr.Len(roem);
                for (n = 0; n < 8; n++)
                    if (S.Hand[0, n].Kleur == skleur)
                    {
                        roem[j] = S.Hand[0, n].Naam;
                        roem[j + 1] = CStr.Nul;
                        ii = BepaalRoemPunten(roem, skleur);
                        if (ii > i) { i = ii; S.Tactiek = 24; skaart = S.Hand[0, n].Naam; }
                    }

                if (skaart == 0)
                {
                    i = 0;
                    for (n = 0; n < S.SlagKrtNo; n++)
                        if (S.Slag(S.SlagNr, n).Kleur == skleur) CStr.Append(roem, S.Slag(S.SlagNr, n).Naam);

                    j = CStr.Len(roem);
                    for (n = 0; n < 8; n++)
                        if (S.Hand[0, n].Kleur == skleur &&
                            Hogere(S.Hand[0, n].Naam, slagstring, slagvolgorde) == 0)
                        {
                            roem[j] = S.Hand[0, n].Naam;
                            roem[j + 1] = CStr.Nul;
                            ii = BepaalRoemPunten(roem, skleur);
                            if (ii > i) { i = ii; S.Tactiek = 48; skaart = S.Hand[0, n].Naam; }
                        }
                }
            }

            if (skaart == 0 && !troeff)     // is er een hogere kaart?
                for (n = 0; n < 8; n++)
                    if (S.Hand[0, n].Kleur == skleur && skleur != S.Troef &&
                        Hogere(S.Hand[0, n].Naam, slagstring, slagvolgorde) == 0)
                    { skaart = S.Hand[0, n].Naam; S.Tactiek = 46; }

            if (skaart == 0) { skaart = LaagsteRoem(skleur); S.Tactiek = 3; }
        }

        // ------------------------------------- kan ik de kleur bekennen?
        if (skaart == 0)
        {
            if (!KleurOk()) i = 0;
            else i = (S.Vrager < 3) ? S.IKrt[skleur, 0] : S.IKrtTafel[skleur, 0];

            if (i == 0)   // niet bekennen: troeven of afgooien
            {
                if (S.SlagKrtNo > 1)
                {
                    j = (S.Vrager > 2) ? S.Vrager - 2 : S.Vrager;
                    m = WieSlag();
                    if (m > 2) m -= 2;

                    if (j == m)   // slag staat al op mijn naam
                    {
                        if (S.Slag(S.SlagNr, S.SlagKrtNo - 2).Kans < KjState.SlagkansLevel)
                        {
                            if (S.Vrager > 2 && S.IKrtTafel[S.Troef, 0] != 0)
                            {
                                i = 1000;
                                for (n = 0; n < 4; n++)
                                    if (S.Tafel[0, n].Kleur == S.Troef && troeff &&
                                        Hogere(S.Tafel[0, n].Naam, troefstring, KjState.RangTroef) == 0 &&
                                        S.Tafel[0, n].Slagkans < i)
                                    {
                                        i = S.Tafel[0, n].Slagkans;
                                        skaart = S.Tafel[0, n].Naam;
                                        skleur = S.Troef;
                                        S.Tactiek = 26;
                                    }
                            }
                            if (S.Vrager < 3 && S.IKrt[S.Troef, 0] != 0)
                            {
                                i = 1000;
                                for (n = 0; n < 8; n++)
                                    if (S.Hand[0, n].Kleur == S.Troef && troeff &&
                                        Hogere(S.Hand[0, n].Naam, troefstring, KjState.RangTroef) == 0 &&
                                        S.Hand[0, n].Slagkans < i)
                                    {
                                        i = S.Hand[0, n].Slagkans;
                                        skaart = S.Hand[0, n].Naam;
                                        skleur = S.Troef;
                                        S.Tactiek = 27;
                                    }
                            }
                        }
                    }
                    else   // slag aan de tegenpartij: overtroeven als het kan
                    {
                        if (S.Vrager > 2 && S.IKrtTafel[S.Troef, 0] != 0)
                        {
                            i = 1000;
                            for (n = 0; n < 4; n++)
                                if (S.Tafel[0, n].Kleur == S.Troef &&
                                    Hogere(S.Tafel[0, n].Naam, troefstring, KjState.RangTroef) == 0 &&
                                    S.Tafel[0, n].Slagkans != 0 && S.Tafel[0, n].Waarde < i)
                                {
                                    i = S.Tafel[0, n].Waarde;
                                    skaart = S.Tafel[0, n].Naam;
                                    skleur = S.Troef;
                                    S.Tactiek = 28;
                                }
                        }
                        if (S.Vrager < 3 && S.IKrt[S.Troef, 0] != 0)
                        {
                            i = 1000;
                            for (n = 0; n < 8; n++)
                                if (S.Hand[0, n].Kleur == S.Troef &&
                                    Hogere(S.Hand[0, n].Naam, troefstring, KjState.RangTroef) == 0 &&
                                    S.Hand[0, n].Slagkans != 0 && S.Hand[0, n].Waarde < i)
                                {
                                    i = S.Hand[0, n].Waarde;
                                    skaart = S.Hand[0, n].Naam;
                                    S.Tactiek = 29;
                                    skleur = S.Troef;
                                }
                        }
                    }
                }

                if (skaart == 0 && S.SlagKrtNo < 2)
                {
                    if (S.Vrager > 2 && S.IKrtTafel[S.Troef, 0] != 0)
                    {
                        i = 1000;
                        for (n = 0; n < 4; n++)
                            if (S.Tafel[0, n].Kleur == S.Troef)
                            {
                                m = S.Tafel[0, n].Slagkans;
                                if (i < m && i != 0)
                                {
                                    i = S.Tafel[0, n].Slagkans;
                                    skaart = S.Tafel[0, n].Naam;
                                    skleur = S.Troef;
                                    S.Tactiek = 30;
                                }
                            }
                    }
                    if (S.Vrager < 3 && S.IKrt[S.Troef, 0] != 0)
                    {
                        i = 1000;
                        for (n = 0; n < 8; n++)
                            if (S.Hand[0, n].Kleur == S.Troef)
                            {
                                m = S.Hand[0, n].Slagkans;
                                if (i < m && i != 0)
                                {
                                    i = S.Hand[0, n].Slagkans;
                                    skaart = S.Hand[0, n].Naam;
                                    skleur = S.Troef;
                                    S.Tactiek = 31;
                                }
                            }
                    }
                }
            }
        }

        // Is er ingetroefd en kan ik niet overtroeven, dan vervalt de keuze.
        if (skaart != 0 && S.Slag(S.SlagNr, 0).Troef == 0)
        {
            for (n = 1; n < S.SlagKrtNo; n++)
                if (S.Slag(S.SlagNr, n).Troef != 0 &&
                    CStr.Pos(KjState.RangTroef, S.Slag(S.SlagNr, n).Naam) < CStr.Pos(KjState.RangTroef, skaart))
                { skaart = (char)0; S.Tac[59]++; S.Tactiek = 59; }
        }

        if (skaart == 0)
        {
            for (n = 0; n < 32; n++)
                if (S.Kaart[n].DichtIkHy == S.Vrager && S.Kaart[n].Kleur == skleur)
                {
                    ii = i = WieSlag();
                    if (ii > 2) ii -= 2;
                    j = S.Vrager;
                    if (j > 2) j -= 2;
                    if (ii == j)
                        for (m = 0; m < S.SlagKrtNo; m++)
                            if (S.Slag(S.SlagNr, m).Speler == i && S.Slag(S.SlagNr, m).Kans > 50)
                            { S.Tactiek = 43; skaart = HoogsteRoem(skleur); }
                            else
                            { S.Tactiek = 32; skaart = LaagsteRoem(skleur); }
                }
        }

        // ----------------------------------------- niet kunnen bekennen
        if (skaart == 0)
        {
            ii = i = WieSlag();
            if (ii > 2) ii -= 2;
            j = S.Vrager;
            if (j > 2) j -= 2;

            if (ii == j)   // slag is aan mij
            {
                for (m = 0; m < S.SlagKrtNo; m++)
                    if (S.Slag(S.SlagNr, m).Speler == i && S.Slag(S.SlagNr, m).Kans > 75)
                    {
                        if (S.Vrager < 3)      // uit de hand
                        {
                            for (jj = 0; jj < 8; jj++)
                            {
                                int kl = S.Hand[0, jj].Kleur;
                                if (kl < 0 || kl > 3) continue;
                                if (S.Hand[0, jj].Naam == 'T' && S.IKrt[kl, 0] == 1)
                                    if (CStr.Pos(S.KTafel[0][kl], 'A') == 0 &&        // geen aas op tafel
                                        Hogere('T', S.KrtVrij[kl], slagvolgorde) != 0) // nog hogere in het spel
                                    {
                                        skaart = S.Hand[0, jj].Naam;
                                        skleur = kl;
                                        S.Tactiek = 51;
                                    }
                            }
                            if (skaart == 0)   // gooi de hoogste rommel bij
                            {
                                w = -1;
                                for (jj = 0; jj < 8; jj++)
                                    if (S.Hand[0, jj].Waarde > w &&
                                        S.Hand[0, jj].Slagkans0 < KjState.SlagkansLevel + 10 &&
                                        S.Hand[0, jj].Kleur != S.Troef &&
                                        S.Hand[0, jj].Naam != 'A')
                                    {
                                        w = S.Hand[0, jj].Waarde;
                                        skaart = S.Hand[0, jj].Naam;
                                        skleur = S.Hand[0, jj].Kleur;
                                        S.Tactiek = 68;
                                    }
                            }
                        }
                        else                   // van tafel
                        {
                            for (jj = 0; jj < 4; jj++)
                            {
                                int kl = S.Tafel[0, jj].Kleur;
                                if (kl < 0 || kl > 3) continue;
                                if (S.Tafel[0, jj].Naam == 'T' && S.IKrt[kl, 0] == 1)
                                    if (CStr.Pos(S.KHand[0][kl], 'A') == 0 &&
                                        Hogere('T', S.KrtVrij[kl], slagvolgorde) != 0)
                                    {
                                        skaart = S.Tafel[0, jj].Naam;
                                        skleur = kl;
                                        S.Tactiek = 52;
                                    }
                            }
                            if (skaart == 0)
                            {
                                w = -1;
                                for (jj = 0; jj < 4; jj++)
                                    if (S.Tafel[0, jj].Waarde > w &&
                                        S.Tafel[0, jj].Slagkans0 < KjState.SlagkansLevel + 10 &&
                                        S.Tafel[0, jj].Kleur != S.Troef &&
                                        S.Tafel[0, jj].Naam != 'A')
                                    {
                                        w = S.Tafel[0, jj].Waarde;
                                        skaart = S.Tafel[0, jj].Naam;
                                        skleur = S.Tafel[0, jj].Kleur;
                                        S.Tactiek = 69;
                                    }
                            }
                        }
                    }

                // Alleen introeven als daar roem mee te halen valt.
                if (skaart == 0 && S.Vrager < 3 && S.IKrt[S.Troef, 0] != 0 && S.SlagKrtNo == 2)
                {
                    m = 999;
                    for (n = 0; n < 8; n++)
                        if (S.Hand[0, n].Troef != 0 && S.Hand[0, n].Slagkans > 20 &&
                            m > S.Hand[0, n].Slagkans)
                        { m = S.Hand[0, n].Slagkans; skaart = S.Hand[0, n].Naam; rkleur = S.Troef; }

                    if (skaart != 0)
                    {
                        m = 0;
                        CStr.Cpy(roem, slagstring);
                        if (KansKaart(rkleur, 1, S.Vrager) > 0.3 && KleurOk())
                        {
                            int lenDicht = CStr.Len(S.KrtDicht[skleur]);
                            int lenSlag = CStr.Len(slagstring);
                            for (n = 0; n < lenDicht; n++)
                            {
                                roem[lenSlag] = S.KrtDicht[skleur][n];
                                roem[lenSlag + 1] = CStr.Nul;
                                i = BepaalRoemPunten(roem, skleur);
                                if (i > m) m = i;
                            }
                        }
                        if (m == 0) skaart = (char)0;
                        else { S.Tactiek = 60; skleur = S.Troef; }
                    }
                }

                if (skaart == 0 && S.Vrager > 2 && S.IKrt[S.Troef, 0] != 0 && S.SlagKrtNo == 2)
                {
                    m = 999;
                    for (n = 0; n < 8; n++)
                        if (S.Tafel[0, n].Troef != 0 && S.Tafel[0, n].Slagkans > 20 &&
                            m > S.Tafel[0, n].Slagkans)
                        { m = S.Tafel[0, n].Slagkans; skaart = S.Tafel[0, n].Naam; rkleur = S.Troef; }

                    if (skaart != 0)
                    {
                        m = 0;
                        CStr.Cpy(roem, slagstring);
                        if (KansKaart(rkleur, 1, S.Vrager) > 0.30 && KleurOk())
                        {
                            int lenDicht = CStr.Len(S.KrtDicht[skleur]);
                            int lenSlag = CStr.Len(slagstring);
                            for (n = 0; n < lenDicht; n++)
                            {
                                roem[lenSlag] = S.KrtDicht[skleur][n];
                                roem[lenSlag + 1] = CStr.Nul;
                                i = BepaalRoemPunten(roem, skleur);
                                if (i > m) m = i;
                            }
                        }
                        if (m == 0) skaart = (char)0;
                        else { S.Tactiek = 25; skleur = S.Troef; }
                    }
                }
            }
        }

        // ------------------------------------------------- restcategorie
        if (skaart == 0 && KleurOk())
        {
            for (n = 8 * skleur; n < 8 * (skleur + 1); n++)
                if (S.Kaart[n].DichtIkHy == S.Vrager)
                { skaart = LaagsteRoem(skleur); S.Tactiek = 34; }
        }

        if (skaart == 0 && skleur != S.Troef && KleurOk())
        {
            m = 99;
            for (n = 8 * skleur; n < 8 * (skleur + 1); n++)
                if (S.Kaart[n].DichtIkHy == S.Vrager)
                {
                    i = S.Kaart[n].ActWaarde;
                    if (i < m) { m = i; skaart = S.Kaart[n].Naam; S.Tactiek = 33; }
                }
        }

        // Ingetroefd: hogere troef bijgooien.
        if (skaart == 0 && troeff)
        {
            bool geenKleur = KleurOk()
                ? ((S.Vrager < 3 && S.IKrt[skleur, 0] == 0) || (S.Vrager > 2 && S.IKrtTafel[skleur, 0] == 0))
                : true;
            if (geenKleur)
            {
                ii = WieSlag();
                if (ii > 2) ii -= 2;
                j = S.Vrager;
                if (j > 2) j -= 2;
                if (ii != j)
                {
                    i = 9;
                    int lenTroef = CStr.Len(troefstring);
                    for (m = 0; m < lenTroef; m++)
                        if (CStr.Pos(KjState.RangTroef, troefstring[m]) < i)
                            i = CStr.Pos(KjState.RangTroef, troefstring[m]);

                    j = 99;
                    for (n = 8 * (S.Troef + 1) - 1; n >= 8 * S.Troef; n--)
                        if (S.Kaart[n].DichtIkHy == S.Vrager && CStr.Pos(KjState.RangTroef, S.Kaart[n].Naam) < i)
                            j = n;

                    if (j < 33) { skaart = S.Kaart[j].Naam; skleur = S.Kaart[j].Kleur; S.Tactiek = 64; }
                }
            }
        }

        // Niet ingetroefd en geen kleur: laagste troef bijgooien.
        if (skaart == 0 && !troeff)
        {
            bool geenKleur = KleurOk()
                ? ((S.Vrager < 3 && S.IKrt[skleur, 0] == 0) || (S.Vrager > 2 && S.IKrtTafel[skleur, 0] == 0))
                : true;
            if (geenKleur)
            {
                ii = WieSlag();
                if (ii > 2) ii -= 2;
                j = S.Vrager;
                if (j > 2) j -= 2;
                if (ii != j)
                {
                    m = 99;
                    for (n = 8 * S.Troef; n < 8 * (S.Troef + 1); n++)
                        if (S.Kaart[n].DichtIkHy == S.Vrager)
                        {
                            i = S.Kaart[n].ActWaarde;
                            if (i <= m) { m = i; skaart = S.Kaart[n].Naam; skleur = S.Troef; S.Tactiek = 65; }
                        }
                }
            }
        }

        if (skaart == 0)
        {
            m = 99;
            for (n = 0; n < 32; n++)
                if (S.Kaart[n].DichtIkHy == S.Vrager && S.Kaart[n].Kleur != S.Troef)
                {
                    i = S.Kaart[n].ActWaarde;
                    if (i <= m) { m = i; skaart = S.Kaart[n].Naam; skleur = S.Kaart[n].Kleur; S.Tactiek = 53; }
                }
        }

        if (skaart == 0)   // gooi maar wat
        {
            m = 99;
            for (n = 0; n < 32; n++)
                if (S.Kaart[n].DichtIkHy == S.Vrager)
                {
                    i = S.Kaart[n].ActWaarde;
                    if (i <= m) { m = i; skaart = S.Kaart[n].Naam; skleur = S.Kaart[n].Kleur; S.Tactiek = 35; }
                }
        }

        S.Lkaart = skaart;
        S.Lkleur = skleur;
        S.Vrager = WieVrager(S.Lkaart, S.Lkleur);
    }
}
