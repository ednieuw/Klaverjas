namespace Klaverjas.Engine;

/// <summary>
/// De spelmechanica uit KJJ.C: delen, handen vullen, kansberekening, roem,
/// slagbepaling en de regelcontrole. Alle schermuitvoer is eruit gestript; wat
/// overblijft is pure rekenlogica.
/// </summary>
public partial class KjEngine
{
    public readonly KjState S;

    public KjEngine(int? seed = null) => S = new KjState(seed);

    // ---------------------------------------------------------------- Delen

    /// <summary>Deelt de 32 kaarten uit (Delen() uit KJJ.C).</summary>
    public void Delen()
    {
        int[] pntwaarde = { 11, 4, 3, 2, 10, 0, 0, 0 };
        int[] troevwaarde = { 11, 4, 3, 20, 10, 14, 0, 0 };
        int wie = Pos.HandZuid;
        int n;

        for (n = 0; n < 32; n++) S.Deeltabel[n] = n;

        n = 1;
        for (int m = 31; m >= 0; m--)
        {
            int card = S.Random(m);
            S.Kaart[S.Deeltabel[card]].DichtIkHy = wie;
            S.Deeltabel[card] = S.Deeltabel[m];
            if (n == 8) wie = Pos.HandNoord;
            if (n == 16) wie = Pos.TafelZuid;
            if (n == 20) wie = Pos.TafelNoord;
            if (n == 24) wie = Pos.DichtZuid;
            if (n == 28) wie = Pos.DichtNoord;
            n++;
        }

        for (n = 0; n < 32; n++)
        {
            var k = S.Kaart[n];
            k.Naam = KjState.RangRoem[n % 8];
            k.PuntWaarde = pntwaarde[n % 8];
            k.TroefWaarde = troevwaarde[n % 8];
            k.Kleur = n / 8;
        }

        for (n = 1; n < 9; n++)
            for (int m = 0; m < 4; m++)
            {
                ref var sk = ref S.Slag(n, m);
                sk.Kleur = 9;
                sk.Naam = (char)0;
                sk.Troef = 0;
                sk.Speler = 998;
                sk.Kans = -100;
                sk.Waarde = -100;
                sk.Tactiek = 255;
            }
    }

    // ----------------------------------------------------------- Vulhanden

    /// <summary>
    /// Bouwt hand[]/tafel[] opnieuw op vanuit het perspectief van de huidige
    /// VRAGER: index 0 is altijd "mijn" kant, index 1 de tegenpartij. Berekent
    /// meteen de slagkans van elke eigen kaart.
    /// </summary>
    public void Vulhanden()
    {
        int[] mm = new int[5];
        int n, wie;

        KaartenVrij();

        for (wie = 0; wie < 2; wie++)
            for (n = 0; n < 8; n++)
            {
                S.Hand[wie, n].Naam = (char)0;
                S.Hand[wie, n].Kleur = 5;
                S.Hand[wie, n].Waarde = 0;
                S.Hand[wie, n].Troef = 0;
                S.Hand[wie, n].Slagkans = -100;
                if (S.SlagKrtNo == 0) S.Hand[wie, n].Slagkans0 = -100;

                S.Tafel[wie, n].Naam = (char)0;
                S.Tafel[wie, n].Kleur = 5;
                S.Tafel[wie, n].Waarde = 5;
                S.Tafel[wie, n].Troef = 0;
                S.Tafel[wie, n].Slagkans = -100;
                if (S.SlagKrtNo == 0) S.Tafel[wie, n].Slagkans0 = -100;
            }

        int vraagkant = (S.Vrager == 1 || S.Vrager == 3) ? 1 : 2;

        for (n = 0; n < 32; n++)
        {
            var k = S.Kaart[n];
            int status = k.DichtIkHy;

            if (status == Pos.Gespeeld) continue;
            if (status == Pos.Dicht) continue;
            if (status > 30) continue;

            int troefstatus = (S.Troef == n / 8) ? 1 : 0;
            k.Troef = troefstatus;

            wie = (status == vraagkant) ? 1 : 2;
            if (status == vraagkant + 2 && status > 2) wie = 3;
            else if (status > 2) wie = 4;

            if (wie < 3)
            {
                S.Hand[wie - 1, mm[wie]].Naam = k.Naam;
                S.Hand[wie - 1, mm[wie]].Kleur = k.Kleur;
                S.Hand[wie - 1, mm[wie]].Waarde = k.ActWaarde;
                S.Hand[wie - 1, mm[wie]].Troef = troefstatus;
                mm[wie]++;
            }
            else
            {
                int twie = wie - 2;
                S.Tafel[twie - 1, mm[wie]].Naam = k.Naam;
                S.Tafel[twie - 1, mm[wie]].Kleur = k.Kleur;
                S.Tafel[twie - 1, mm[wie]].Waarde = k.ActWaarde;
                S.Tafel[twie - 1, mm[wie]].Troef = troefstatus;
                mm[wie]++;
            }
        }

        for (n = 0; n < 8; n++)
        {
            S.Hand[0, n].Slagkans = BepaalSlagkans(S.Hand[0, n].Naam, S.Hand[0, n].Kleur);
            if (S.SlagKrtNo == 0) S.Hand[0, n].Slagkans0 = S.Hand[0, n].Slagkans;
            S.Hand[0, n].Gegarandeerd = S.Hand[0, n].Slagkans > 95 ? 1 : 0;
        }

        for (n = 0; n < 4; n++)
        {
            S.Tafel[0, n].Slagkans = BepaalSlagkans(S.Tafel[0, n].Naam, S.Tafel[0, n].Kleur);
            if (S.SlagKrtNo == 0) S.Tafel[0, n].Slagkans0 = S.Tafel[0, n].Slagkans;
            S.Tafel[0, n].Gegarandeerd = S.Tafel[0, n].Slagkans > 95 ? 1 : 0;
        }
    }

    // ------------------------------------------------------- kaarten_vrij

    /// <summary>
    /// Verdeelt alle 32 kaarten over "vrij" (nog in het spel), "weg" (gespeeld)
    /// en "dicht" (voor de vrager onzichtbaar), per kleur en totaal, en telt de
    /// kaarten per kleur in hand en op tafel.
    /// </summary>
    public void KaartenVrij()
    {
        char[] nop = CStr.New(40), vrij = CStr.New(40), weg = CStr.New(40), dicht = CStr.New(40);
        int[] q = new int[5];
        int n;

        for (n = 0; n < 4; n++)
        {
            S.IKrt[n, 0] = 0; S.IKrt[n, 1] = 0;
            S.IKrtTafel[n, 0] = 0; S.IKrtTafel[n, 1] = 0;
            CStr.Clear(S.KHand[0][n]); CStr.Clear(S.KHand[1][n]);
            CStr.Clear(S.KTafel[0][n]); CStr.Clear(S.KTafel[1][n]);
        }

        int vragert = S.Vrager;
        if (vragert > 2) vragert -= 2;

        CStr.Clear(S.KrtTotVrij);
        CStr.Clear(S.KrtTotDicht);
        CStr.Clear(S.KrtTotWeg);
        S.IKrtGespeeld = 0;

        n = -1;
        for (int x = 0; x < 4; x++)
        {
            int m = 0, o = 0, p = 0;
            q[1] = q[2] = q[3] = q[4] = 0;
            int i = x;

            for (int y = 0; y < 8; y++)
            {
                n++;
                int stat = S.Kaart[n].DichtIkHy;
                i = S.Kaart[n].Kleur;
                int wie = 1;
                if (stat == vragert) wie = 0;
                if (stat - 2 == vragert) wie = 0;

                if (stat == Pos.HandZuid)
                {
                    S.IKrt[i, wie]++;
                    S.KHand[wie][i][q[1]++] = S.Kaart[n].Naam;
                    S.KHand[wie][i][q[1]] = CStr.Nul;
                    if (stat != vragert) S.KrtDicht[i][p++] = S.Kaart[n].Naam;
                }
                if (stat == Pos.HandNoord)
                {
                    S.IKrt[i, wie]++;
                    S.KHand[wie][i][q[2]++] = S.Kaart[n].Naam;
                    S.KHand[wie][i][q[2]] = CStr.Nul;
                    if (stat != vragert) S.KrtDicht[i][p++] = S.Kaart[n].Naam;
                }
                if (stat == Pos.TafelZuid)
                {
                    S.IKrtTafel[i, wie]++;
                    S.KTafel[wie][i][q[3]++] = S.Kaart[n].Naam;
                    S.KTafel[wie][i][q[3]] = CStr.Nul;
                }
                if (stat == Pos.TafelNoord)
                {
                    S.IKrtTafel[i, wie]++;
                    S.KTafel[wie][i][q[4]++] = S.Kaart[n].Naam;
                    S.KTafel[wie][i][q[4]] = CStr.Nul;
                }

                if (stat != Pos.Gespeeld) S.KrtVrij[i][m++] = S.Kaart[n].Naam;
                if (stat == Pos.Gespeeld)
                {
                    S.KrtWeg[i][o++] = S.Kaart[n].Naam;
                    S.IKrtGespeeld++;
                }
                if (stat == Pos.Dicht) S.KrtDicht[i][p++] = S.Kaart[n].Naam;
                if (stat == Pos.DichtZuid) S.KrtDicht[i][p++] = S.Kaart[n].Naam;
                if (stat == Pos.DichtNoord) S.KrtDicht[i][p++] = S.Kaart[n].Naam;
                if (stat == Pos.NieuwZuid) S.KrtDicht[i][p++] = S.Kaart[n].Naam;
                if (stat == Pos.NieuwNoord) S.KrtDicht[i][p++] = S.Kaart[n].Naam;
            }

            S.KrtVrij[i][m] = CStr.Nul;
            S.KrtWeg[i][o] = CStr.Nul;
            S.KrtDicht[i][p] = CStr.Nul;
        }

        for (int kolor = 0; kolor < 4; kolor++)
        {
            CStr.Cpy(nop, kolor == S.Troef ? KjState.RangTroef : KjState.RangNorm);

            int m = 0, o = 0, p = 0;
            for (n = 0; n < 8; n++)
            {
                char x = nop[n];
                if (CStr.Pos(S.KrtVrij[kolor], x) != 0) vrij[m++] = nop[n];
                if (CStr.Pos(S.KrtWeg[kolor], x) != 0) weg[o++] = nop[n];
                if (CStr.Pos(S.KrtDicht[kolor], x) != 0) dicht[p++] = nop[n];
            }
            vrij[m] = CStr.Nul;
            weg[o] = CStr.Nul;
            dicht[p] = CStr.Nul;

            CStr.Cpy(S.KrtVrij[kolor], vrij);
            CStr.Cpy(S.KrtWeg[kolor], weg);
            CStr.Cpy(S.KrtDicht[kolor], dicht);
            CStr.Cat(S.KrtTotVrij, vrij);
            CStr.Cat(S.KrtTotWeg, weg);
            CStr.Cat(S.KrtTotDicht, dicht);
        }
    }

    // ------------------------------------------------------- kansrekening

    /// <summary>
    /// Hypergeometrische kans (guillermie() uit KJJ.C).
    /// a = totaal dichte kaarten, h = kaarten in de betreffende hand,
    /// z = resterende kaarten van die kleur, x = gevraagd aantal van die kleur,
    /// s = gevraagd aantal specifieke kaarten.
    /// </summary>
    public static double Guillermie(int a, int h, int z, int x, int s)
    {
        var f = KjState.Fact;

        if (h - x < 0) return 1.0;
        if (a - h < 0) return 1.0;
        if (a - z <= 0) return 1.0;
        if (z - s < 0) s = z;
        if (x - s < 0) s = x;
        if (z - x < 0) return 0.0;
        if ((a - z) - (h - x) < 0) return 1.0;

        if (a >= f.Length || h >= f.Length || z >= f.Length) return 0.0;

        double aa = f[h] * f[a - h] / f[h - x] * f[a - z] * f[z - s];
        double bb = f[(a - z) - (h - x)] * f[x - s] * f[z - x];
        double cc = f[a];

        if (aa == 0) return 0.0;
        if (bb == 0) return 1.0;
        if (cc == 0) return 1.0;

        return (aa / bb) / cc;
    }

    /// <summary>Kans dat de tegenpartij een hogere kaart van die kleur heeft.</summary>
    public double KansHoger(int kaartenhoger, int kleur, int specifiek, int vrager)
    {
        if (vrager > 2) vrager -= 2;
        if (vrager < 1 || vrager > 2) return 0;
        if (S.Verzaakt[vrager - 1, kleur] != 0) return 0;
        if (CStr.Len(S.KrtVrij[kleur]) == 0) return 0;

        const int ts = 1;
        int a = CStr.Len(S.KrtTotDicht);
        int h = S.IKrt[0, ts] + S.IKrt[1, ts] + S.IKrt[2, ts] + S.IKrt[3, ts];
        int x = kaartenhoger;
        int s = specifiek;
        int z = CStr.Len(S.KrtDicht[kleur]);

        if (z == 0) return 0;
        if (x == 0) return 0;
        if (x >= KjState.Fact.Length) return 1.0;

        double res = Guillermie(a, h, z, x, s) * KjState.Fact[x];
        if (res > 1.0) res = 1.0;
        return res;
    }

    /// <summary>Kans dat de tegenpartij überhaupt nog een kaart van die kleur heeft.</summary>
    public double KansKaart(int kleur, int specifiek, int vrager)
    {
        if (specifiek != 0) specifiek = 1;
        if (vrager > 2) vrager -= 2;
        if (vrager < 1 || vrager > 2) return 0;
        if (S.Verzaakt[vrager - 1, kleur] != 0) return 0;
        if (CStr.Len(S.KrtVrij[kleur]) == 0) return 0;

        const int ts = 1;
        int a = CStr.Len(S.KrtTotDicht);
        int h = S.IKrt[0, ts] + S.IKrt[1, ts] + S.IKrt[2, ts] + S.IKrt[3, ts];
        const int x = 1;
        const int s = 0;
        int z = CStr.Len(S.KrtDicht[kleur]);

        if (z == 0) return 0;
        if (z >= KjState.Fact.Length) return 1.0;

        double res = Guillermie(a, h, z, x, s) * KjState.Fact[z];
        if (res > 1.0) res = 1.0;
        return res;
    }

    // ------------------------------------------------------------ hulpjes

    /// <summary>
    /// Aantal kaarten in ks dat volgens 'volgorde' hoger is dan kv.
    /// </summary>
    public static int Hogere(char kv, char[] ks, string volgorde)
    {
        char[] nop1 = CStr.New(20);
        if (CStr.Len(ks) == 0) return 0;

        int n;
        for (n = 0; n < 8; n++)
        {
            if (volgorde[n] != kv) nop1[n] = volgorde[n];
            else { nop1[n] = CStr.Nul; break; }
        }
        // Komt kv niet in de volgorde voor, dan sluiten we hier af. In het
        // origineel bleef nop1 dan ongetermineerd (undefined behaviour).
        if (n >= 8) nop1[8] = CStr.Nul;

        int i = 0;
        int len = CStr.Len(ks);
        for (int m = 0; m < len; m++)
            if (CStr.Pos(nop1, ks[m]) != 0) i++;
        return i;
    }

    public static int Hogere(char kv, string ks, string volgorde)
    {
        char[] buf = CStr.New(ks.Length + 2);
        CStr.Cpy(buf, ks);
        return Hogere(kv, buf, volgorde);
    }

    /// <summary>Waar bevindt kaart (kleur, karte) zich? Geeft DichtIkHy of -1.</summary>
    public int WieVrager(char karte, int kleur)
    {
        // Bewust met bereikcontrole: één aanroep in het origineel
        // (bepaal_laagsteroem) verwisselt de argumenten en leest daardoor
        // buiten kaart[] - daar leverde dat een willekeurige waarde op, hier
        // netjes -1, wat ook het pad is dat het origineel bedoelde.
        int van = 8 * kleur, tot = (1 + kleur) * 8;
        if (van < 0 || tot > 32) return -1;
        for (int n = van; n < tot; n++)
            if (S.Kaart[n].Naam == karte) return S.Kaart[n].DichtIkHy;
        return -1;
    }

    /// <summary>Wie heeft de slag op dit moment (1..4)?</summary>
    public int WieSlag()
    {
        char[] st = CStr.New(8);
        int[] sp = new int[8];
        bool troef = false;
        int m = 0, n;

        int kkleur = S.Slag(S.SlagNr, 0).Kleur;

        for (n = 0; n < S.SlagKrtNo; n++)
            if (S.Slag(S.SlagNr, n).Troef != 0) troef = true;

        string slagvolgorde = troef ? KjState.RangTroef : KjState.RangNorm;
        if (troef) kkleur = S.Troef;

        int i = 0;
        for (n = 0; n < S.SlagKrtNo; n++)
            if (S.Slag(S.SlagNr, n).Kleur == kkleur)
            {
                st[i] = S.Slag(S.SlagNr, n).Naam;
                sp[i++] = S.Slag(S.SlagNr, n).Speler;
            }
        st[i] = CStr.Nul;

        i = 10;
        int len = CStr.Len(st);
        for (n = 0; n < len; n++)
        {
            int j = CStr.Pos(slagvolgorde, st[n]);
            if (j != 0 && j < i) { i = j; m = sp[n]; }
        }
        return m;
    }

    // -------------------------------------------------------- slagkans

    /// <summary>
    /// Schat de kans (0..100) dat kaart (kleur, karte) de slag haalt.
    /// Dit is het hart van de AI: bepaal_slagkans() uit KJ.C.
    /// </summary>
    public int BepaalSlagkans(char karte, int kleur)
    {
        char[] nop = CStr.New(40), nop1 = CStr.New(40);
        int d, i, j, n, ts, tss;
        double kansHogerr;

        if (karte == 0) return -100;
        if (kleur < 0 || kleur > 3) return -100;

        int vrager = WieVrager(karte, kleur);
        if (vrager > 10) vrager /= 10;
        if (vrager > 2) vrager -= 2;
        ts = 1;
        tss = (vrager == 1) ? 2 : 1;

        CStr.Cpy(nop, kleur == S.Troef ? KjState.RangTroef : KjState.RangNorm);

        int posKaartvrager = Hogere(karte, S.KrtVrij[kleur], CStr.Str(nop)) + 1;
        kansHogerr = (posKaartvrager == 1) ? 1 : 0;

        i = j = 0;
        if (S.SlagKrtNo != 0)
        {
            for (n = 0; n <= S.SlagKrtNo; n++)
                if (S.Slag(S.SlagNr, n).Troef != 0 && kleur != S.Troef) return 0;

            if (S.Slag(S.SlagNr, 0).Kleur != kleur && kleur != S.Troef) return 0;

            for (n = 0; n <= S.SlagKrtNo; n++)
                if (S.Slag(S.SlagNr, n).Kleur == kleur) nop1[j++] = S.Slag(S.SlagNr, n).Naam;
            nop1[j] = CStr.Nul;
            i = Hogere(karte, nop1, CStr.Str(nop));
            if (i > 0) return 0;
        }

        for (n = 0; n < 8; n++)
        {
            if (nop[n] != karte) nop1[n] = nop[n];
            else { nop1[n] = CStr.Nul; break; }
        }
        if (n >= 8) n = 8;
        nop1[n] = CStr.Nul;

        d = j = 1;
        if (S.SlagKrtNo != 0)
        {
            for (n = 0; n <= S.SlagKrtNo; n++)
                if (S.Slag(S.SlagNr, n).Speler == tss + 2) j = 0;
            // Let op: in het origineel staat de volgende test buiten de lus,
            // met n al voorbij het laatste element. Dat is hier bewust zo
            // gelaten (de platte slag-array vangt de overloop net als in C op).
            if (S.Slag(S.SlagNr, n).Speler == tss) d = 0;
        }

        if (j != 0 && posKaartvrager > 1 && CStr.Len(S.KTafel[ts][kleur]) > 0)
        {
            i = Hogere(karte, S.KTafel[ts][kleur], CStr.Str(nop));
            if (i > 0) return 0;
        }

        if (j != 0 && S.Troef != 999 && kleur != S.Troef)
        {
            if (S.IKrtTafel[kleur, ts] == 0 && S.IKrtTafel[S.Troef, ts] != 0) return 0;
        }

        if (i == 0 && d == 0 && S.SlagKrtNo != 0)
        {
            for (n = 0; n <= S.SlagKrtNo; n++)
                if (S.Slag(S.SlagNr, n).Speler == tss) return 100;
        }

        int aantalHoger = Hogere(karte, S.KrtDicht[kleur], CStr.Str(nop));
        if (S.SlagNr == 8 && Hogere(karte, S.KrtVrij[kleur], CStr.Str(nop)) != 0) return 0;

        if (aantalHoger > 0)
        {
            kansHogerr = 1 - KansHoger(aantalHoger, kleur, 0, vrager);
        }
        else
        {
            kansHogerr = 1;
            if (S.Troef < 0 || S.Troef > 3) return (int)(kansHogerr * 100);
            if (CStr.Len(S.KrtDicht[S.Troef]) == 0) return (int)(kansHogerr * 100);
            if (tss >= 1 && tss <= 2 && S.Verzaakt[tss - 1, S.Troef] != 0) return (int)(kansHogerr * 100);
        }

        if (kleur != S.Troef && S.Troef != 999)
        {
            if (S.SlagKrtNo == 8 && CStr.Len(S.KrtDicht[S.Troef]) != 0) return 0;

            double kansKaartt;
            if (CStr.Len(S.KrtDicht[kleur]) == 0) kansKaartt = 0;
            else kansKaartt = KansKaart(kleur, 0, vrager);

            if (kansKaartt < 0.6 && CStr.Len(S.KrtDicht[S.Troef]) != 0)
            {
                double kansTroefkaartt = KansKaart(S.Troef, 0, vrager);
                kansKaartt = 1 - kansTroefkaartt;
            }
            kansHogerr *= kansKaartt;
        }

        return (int)(kansHogerr * 100);
    }

    // ------------------------------------------------------------- troef

    /// <summary>
    /// Laat de computer troef kiezen (troef_bepalen() uit KJJ.C).
    /// </summary>
    public void TroefBepalen()
    {
        // Speelt de kant die troef mag maken volgens Loggen, dan kiest die ook
        // zijn eigen troef.
        int kant = (S.StartVrager > 2) ? S.StartVrager - 2 : S.StartVrager;
        if (kant >= 1 && kant <= 2 && S.Zoekt[kant - 1])
        {
            S.Troef = Zoeker().KiesTroef();
            ZetActWaarden();
            return;
        }

        int[] sompunten = new int[4];
        int[] aantalkrt = new int[4];
        int[] zekereslagen = new int[4];
        int[] somtroefpunten = new int[4];
        int[] hijtroef = new int[4];
        int[] hijtroefpunten = new int[4];
        int m, n;

        S.Troef = 999;

        // In het origineel wordt Hijtafel alleen gezet als startvrager==1 en
        // blijft hij anders ongeinitialiseerd - juist het geval dat in een
        // menselijk spel altijd optreedt. Hier expliciet op de bedoelde waarde
        // gezet: de tafelkaarten van de tegenstander.
        int hijtafel = (S.StartVrager == 1) ? Pos.TafelNoord : Pos.TafelZuid;

        for (n = 0; n < 32; n++)
        {
            int status = S.Kaart[n].DichtIkHy;
            if (status == S.StartVrager || status == S.StartVrager + 2)
            {
                sompunten[S.Kaart[n].Kleur] += S.Kaart[n].TroefWaarde;
                somtroefpunten[S.Kaart[n].Kleur] += S.Kaart[n].TroefWaarde;
                aantalkrt[S.Kaart[n].Kleur]++;
            }
            if (status == hijtafel) somtroefpunten[S.Kaart[n].Kleur] -= S.Kaart[n].TroefWaarde;
        }

        for (n = 0; n < 32; n++)
        {
            if (S.Kaart[n].DichtIkHy == hijtafel)
            {
                hijtroef[S.Kaart[n].Kleur]++;
                hijtroefpunten[S.Kaart[n].Kleur] += S.Kaart[n].TroefWaarde;
            }
        }

        // Heb ik de boer van een kleur, tel dan de laagste troef van de
        // tegenstander mee.
        for (n = 0; n < 4; n++)
        {
            int status = S.Kaart[n * 8 + 3].DichtIkHy;
            if (status == S.StartVrager || status == S.StartVrager + 2)
            {
                for (m = 8 * (n + 1); m >= n * 8; m--)
                {
                    if (m > 31) continue;   // het origineel liep hier buiten kaart[]
                    if (S.Kaart[m].DichtIkHy == hijtafel)
                    {
                        somtroefpunten[n] += 2 * S.Kaart[n].TroefWaarde;
                        break;
                    }
                }
            }
        }

        for (n = 0; n < 8; n++)
            if (S.Tafel[S.Vrager - 1, n].Gegarandeerd != 0)
                zekereslagen[S.Tafel[S.Vrager - 1, n].Kleur]++;

        for (n = 0; n < 8; n++)
            if (S.Hand[S.Vrager - 1, n].Gegarandeerd != 0)
                zekereslagen[S.Hand[S.Vrager - 1, n].Kleur]++;

        for (n = 0; n < 4; n++)
            somtroefpunten[n] += 3 * zekereslagen[n] + 2 * aantalkrt[n];

        m = 0;
        for (n = 0; n < 4; n++)
            if (somtroefpunten[n] > m) { m = somtroefpunten[n]; S.Troef = n; }

        if (S.Troef == 999) S.Troef = 0;
        ZetActWaarden();
    }

    /// <summary>Zet de actuele kaartwaarden zodra troef bekend is.</summary>
    public void ZetActWaarden()
    {
        for (int n = 0; n < 32; n++)
            S.Kaart[n].ActWaarde = (S.Kaart[n].Kleur == S.Troef)
                ? S.Kaart[n].TroefWaarde
                : S.Kaart[n].PuntWaarde;
    }

    // ----------------------------------------------------------- legkaart

    /// <summary>
    /// Legt een kaart op tafel. Geeft false als de kaart niet van de vrager is
    /// (dan heeft de AI verzaakt of klikte de speler op een verkeerde kaart).
    /// Draait daarbij zonodig een dichte tafelkaart om.
    /// </summary>
    public bool LegKaart(char skaart, int skleur, int vrager)
    {
        if (skleur < 0 || skleur > 3 || skaart == 0) return false;

        int vragert = WieVrager(skaart, skleur);
        int speler = vragert;
        if (vragert != vrager) return false;      // verkeerde kaart
        if (vragert == Pos.Gespeeld) return false; // al gespeeld
        if (vragert > 4) return false;             // dichte kaart
        if (vragert > 2) vragert -= 2;

        int krtno = KjState.KaartNr(skleur, skaart);

        ref var sk = ref S.Slag(S.SlagNr, S.SlagKrtNo);
        sk.Kleur = skleur;
        sk.Naam = skaart;
        sk.Speler = S.Vrager;
        sk.Waarde = S.Kaart[krtno].ActWaarde;
        sk.Kans = BepaalSlagkans(skaart, skleur);
        sk.Tactiek = S.Tactiek;
        sk.Troef = (skleur == S.Troef) ? 1 : 0;

        S.Kaart[krtno].DichtIkHy = Pos.Gespeeld;
        S.SlagKrtNo++;

        if (speler > 2)
        {
            int postafel = Math.Clamp(TafelPositie(krtno, speler), 0, 3);
            if (speler == Pos.TafelZuid && S.TZuid[postafel] == 0) return true;
            if (speler == Pos.TafelNoord && S.TNoord[postafel] == 0) return true;

            int bijlegger = (speler == Pos.TafelZuid) ? Pos.DichtZuid : Pos.DichtNoord;

            // Kies willekeurig een van de resterende dichte kaarten om om te draaien.
            int j = S.Random(8) + 1;
            int n = 0, i = 0;
            while (true)
            {
                if (S.Kaart[n].DichtIkHy == bijlegger) i++;
                if (i == j) break;
                if (++n > 31) { n = 0; if (i == 0) return true; }
            }

            _tafelPositie[n] = postafel;
            if (speler == Pos.TafelZuid) S.TZuid[postafel] = 0;
            else S.TNoord[postafel] = 0;

            // De omgedraaide kaart wordt pas de volgende slag een echte
            // tafelkaart; tot die tijd 33->13 resp. 44->14.
            if (S.Kaart[n].DichtIkHy > 30) S.Kaart[n].DichtIkHy = S.Kaart[n].DichtIkHy / 10 + 10;
        }
        return true;
    }

    // Positie van elke kaart in de rij tafelkaarten (0..3); vervangt kaart[].postafel.
    private readonly int[] _tafelPositie = new int[32];

    public int TafelPositie(int krtno, int speler) => _tafelPositie[krtno];

    /// <summary>Plek 0..3 van een tafelkaart in de rij.</summary>
    public int TafelPos(int krtno) => _tafelPositie[krtno];

    /// <summary>Kent de tafelkaarten hun plek 0..3 toe (wat leg_tafel() in KJJ.C deed).</summary>
    public void ZetTafelPosities()
    {
        int i = 0;
        for (int n = 0; n < 32; n++)
            if (S.Kaart[n].DichtIkHy == Pos.TafelZuid) _tafelPositie[n] = i++;
        i = 0;
        for (int n = 0; n < 32; n++)
            if (S.Kaart[n].DichtIkHy == Pos.TafelNoord) _tafelPositie[n] = i++;
    }

    /// <summary>Maakt net omgedraaide tafelkaarten (13/14) tot echte tafelkaarten.</summary>
    public void UpdateTafel()
    {
        for (int n = 0; n < 32; n++)
        {
            if (S.Kaart[n].DichtIkHy == Pos.NieuwZuid) S.Kaart[n].DichtIkHy = Pos.TafelZuid;
            if (S.Kaart[n].DichtIkHy == Pos.NieuwNoord) S.Kaart[n].DichtIkHy = Pos.TafelNoord;
        }
    }

    // ---------------------------------------------------------- evalueren

    /// <summary>
    /// Telt punten en roem van de zojuist gespeelde slag, en geeft terug wat
    /// die slag opleverde zodat de UI het kan melden.
    /// </summary>
    public SlagUitslag Evalueer()
    {
        char[] sp = CStr.New(8);
        int punten = 0, n;

        for (n = 0; n < 4; n++) punten += S.Slag(S.SlagNr, n).Waarde;

        S.StartVrager = WieSlag();
        if (S.StartVrager > 2) S.StartVrager -= 2;
        if (S.StartVrager < 1 || S.StartVrager > 2) S.StartVrager = 1;
        S.PuntenSpel[S.StartVrager - 1] += punten;

        int roem = 0;
        for (int rkleur = 0; rkleur < 4; rkleur++)
        {
            int i = 0;
            for (n = 0; n < 4; n++)
                if (S.Slag(S.SlagNr, n).Kleur == rkleur) sp[i++] = S.Slag(S.SlagNr, n).Naam;
            sp[i] = CStr.Nul;
            if (CStr.Len(sp) > 1)
                roem += BepaalRoemPunten(sp, rkleur);
        }

        // Vier gelijke kaarten, over de hele slag in plaats van per kleur. De tak in
        // BepaalRoemPunten wordt nooit bereikt omdat hierboven op kleur gegroepeerd
        // wordt, en vier gelijke kaarten vier verschillende kleuren hebben.
        char n0 = S.Slag(S.SlagNr, 0).Naam;
        if (n0 != 0
            && S.Slag(S.SlagNr, 1).Naam == n0
            && S.Slag(S.SlagNr, 2).Naam == n0
            && S.Slag(S.SlagNr, 3).Naam == n0)
        {
            roem += (n0 == 'B') ? 200 : 100;
            S.Superroem++;
        }

        S.Roem[S.StartVrager - 1] += roem;

        int laatsteSlag = 0;
        if (S.SlagNr == 8)
        {
            laatsteSlag = 10;
            S.Roem[S.StartVrager - 1] += laatsteSlag;
        }

        if (S.Slag(S.SlagNr, 0).Kleur != S.Slag(S.SlagNr, 3).Kleur)
        {
            int sp3 = S.Slag(S.SlagNr, 3).Speler;
            if (sp3 >= 1 && sp3 <= 2)
                S.Verzaakt[sp3 - 1, S.Slag(S.SlagNr, 0).Kleur] = 1;
        }

        return new SlagUitslag(punten, roem, laatsteSlag);
    }

    /// <summary>Sluit een heel spel (8 slagen) af en verwerkt pit, nat en de stand.</summary>
    public string EvalueerSpel()
    {
        int n;
        if (S.Speler > 2) S.Speler -= 2;
        S.SlagNr--;
        n = WieSlag();
        if (n > 2) n -= 2;

        if (S.PuntenSpel[0] == 152) { S.Roem[0] += 100; S.Pit[0]++; }
        if (S.PuntenSpel[1] == 152) { S.Roem[1] += 100; S.Pit[1]++; }
        if (S.PuntenSpel[0] == 152 && S.Speler == 2) { S.Roem[0] += 200; S.Tpit[0]++; }
        if (S.PuntenSpel[1] == 152 && S.Speler == 1) { S.Roem[1] += 200; S.Tpit[1]++; }

        int a = S.PuntenSpel[0] + S.Roem[0];
        int b = S.PuntenSpel[1] + S.Roem[1];

        bool nat = false;
        if (S.Speler == 1 && a <= b) { b += a; a = 0; S.Nat[0]++; nat = true; }
        if (S.Speler == 2 && b <= a) { a += b; b = 0; S.Nat[1]++; nat = true; }

        S.PuntenTotaalSpel[0] += a;
        S.PuntenTotaalSpel[1] += b;
        if (a < b) S.GewonnenTot[1]++; else S.GewonnenTot[0]++;
        S.Roempnt[0] += S.Roem[0];
        S.Roempnt[1] += S.Roem[1];
        S.PuntenSpel[0] = S.PuntenSpel[1] = 0;
        S.Roem[0] = S.Roem[1] = 0;
        S.SlagNr++;

        string uitslag = Taal.WintDitSpel(a > b)
                       + (nat ? Taal.TegenpartijNat : "")
                       + Taal.Standen(a, b);

        for (n = 0; n < 4; n++) { S.Verzaakt[0, n] = 0; S.Verzaakt[1, n] = 0; }

        if (S.PuntenTotaalSpel[0] >= 1500 || S.PuntenTotaalSpel[1] >= 1500)
        {
            if (S.PuntenTotaalSpel[0] > S.PuntenTotaalSpel[1]) S.Gewonnen[0]++;
            else S.Gewonnen[1]++;
            if (S.PuntenTotaalSpel[0] == S.PuntenTotaalSpel[1]) S.Gewonnen[0]++;
            S.PuntenTotaalSpel[0] = 0;
            S.PuntenTotaalSpel[1] = 0;
            uitslag += Taal.PartijUit;
        }
        return uitslag;
    }
}
