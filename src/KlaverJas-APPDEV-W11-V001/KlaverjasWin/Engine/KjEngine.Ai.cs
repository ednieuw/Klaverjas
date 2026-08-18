namespace Klaverjas.Engine;

/// <summary>
/// De tactiek uit KJ.C: speler1 (uitkomen), tegenspeler1, speler2 en
/// tegenspeler2, plus bekijk_beste_slag() dat het bijspelen afhandelt.
/// Elke tak zet S.Tactiek op het nummer uit het origineel, zodat je in de UI
/// nog steeds kunt zien welke regel de computer toepaste.
/// </summary>
public partial class KjEngine
{
    /// <summary>true zolang de zet nog van de menselijke speler moet komen.</summary>
    public bool WachtOpMens { get; private set; }

    private bool Humaan()
    {
        WachtOpMens = true;
        return true;
    }

    public void ZetMensKlaar() => WachtOpMens = false;

    private ZoekAi _zoeker;

    /// <summary>De zoekende speler, pas aangemaakt als hij nodig is.</summary>
    internal ZoekAi Zoeker() => _zoeker ??= new ZoekAi(this);

    /// <summary>
    /// Speelt de kant die nu aan zet is volgens de zoekende speler van Loggen?
    /// Zo ja, dan kiest die de kaart en slaan we de tactiek van Ed over.
    /// </summary>
    private bool ZoekendeSpeler()
    {
        int kant = S.Vrager > 2 ? S.Vrager - 2 : S.Vrager;
        if (kant < 1 || kant > 2) return false;
        if (!S.Zoekt[kant - 1]) return false;

        (_zoeker ??= new ZoekAi(this)).Kies();
        return true;
    }

    // -------------------------------------------------------- speler1

    /// <summary>Uitkomen: kiest de kaart waarmee de slag geopend wordt.</summary>
    public void Speler1()
    {
        int m, n, i;
        int skleur, skl = 5, tss;
        char skaart, ska;
        int kansTroefkaarttp;

        if (S.StartVrager > 2) S.StartVrager -= 2;
        S.Vrager = S.StartVrager;
        tss = (S.Vrager == 1) ? 2 : 1;
        S.SlagKrtNo = 0;

        Vulhanden();

        skleur = 5;
        skaart = (char)0;

        if (S.IKrtTafel[S.Troef, 1] != 0) kansTroefkaarttp = 100;
        else kansTroefkaarttp = (int)(100 * KansKaart(S.Troef, 0, S.Vrager));
        if (S.Verzaakt[tss - 1, S.Troef] != 0 && S.IKrtTafel[S.Troef, 1] == 0) kansTroefkaarttp = 0;
        // Het origineel test hier "Krt_dicht[TROEF]==0" op een array in plaats
        // van op de inhoud; die test is altijd onwaar en is daarom weggelaten.

        if (!S.Comp && (S.Vrager == 1 || S.Vrager == 3)) { Humaan(); return; }
        if (ZoekendeSpeler()) return;

        // Roem van tafel halen: gegarandeerde slag met de hoogste roemkans.
        m = 0; ska = (char)0;
        for (n = 0; n < 4; n++)
            if (S.Tafel[0, n].Gegarandeerd == 1)
            {
                skaart = S.Tafel[0, n].Naam;
                skleur = S.Tafel[0, n].Kleur;
                i = BepaalHoogsteRoem(skleur, skaart);
                if (m < i) { ska = skaart; skl = skleur; m = i; }
            }
        for (n = 0; n < 8; n++)
            if (S.Hand[0, n].Gegarandeerd == 1)
            {
                skaart = S.Hand[0, n].Naam;
                skleur = S.Hand[0, n].Kleur;
                i = BepaalHoogsteRoem(skleur, skaart);
                if (m < i) { ska = skaart; skl = skleur; m = i; }
            }
        if (ska != 0) { skaart = ska; skleur = skl; S.Tactiek = 7; }
        else skaart = (char)0;

        // Kale tien, of kale troefnegen, bij de tegenstander op tafel.
        for (n = 0; n < 4; n++)
        {
            if (skaart != 0) break;
            if (S.Tafel[0, n].Gegarandeerd != 0)
            {
                skleur = S.Tafel[0, n].Kleur;
                if (skleur >= 0 && skleur < 4 && S.IKrtTafel[skleur, 1] == 1)
                {
                    if (S.KTafel[1][skleur][0] == 'T') skaart = S.Tafel[0, n].Naam;
                    if (S.KTafel[1][skleur][0] == '9' && skleur == S.Troef) skaart = S.Tafel[0, n].Naam;
                    S.Tactiek = 1;
                }
            }
        }

        if (skaart == 0)
            for (n = 0; n < 8; n++)
            {
                if (skaart != 0) break;
                if (S.Hand[0, n].Gegarandeerd != 0)
                {
                    skleur = S.Hand[0, n].Kleur;
                    if (skleur >= 0 && skleur < 4 && S.IKrtTafel[skleur, 1] == 1)
                    {
                        if (S.KTafel[1][skleur][0] == 'T') skaart = S.Hand[0, n].Naam;
                        if (S.KTafel[1][skleur][0] == '9' && skleur == S.Troef) skaart = S.Hand[0, n].Naam;
                        S.Tactiek = 2;
                    }
                }
            }

        // Ik heb de aas en hij een kale tien van die kleur op tafel.
        if (skaart == 0)
        {
            skleur = 5;
            // Het origineel indexeert hier tafel[1][] met de teller van de
            // vorige lus (altijd 8, dus buiten de rij) in plaats van met m;
            // daardoor liep deze tak in de praktijk nooit. Dat gedrag is hier
            // bewaard met een expliciete bereikcontrole.
            for (m = 0; m < 4; m++)
            {
                if (skaart != 0) { S.Tactiek = 50; break; }
                if (n >= 8) continue;
                if (S.Tafel[1, n].Naam == 'T' && S.IKrt[S.Tafel[1, n].Kleur, 1] == 1
                    && S.Tafel[1, n].Kleur != S.Troef)
                {
                    skleur = S.Tafel[1, n].Kleur;
                    for (n = 0; n < 8; n++)
                        if (S.Hand[0, n].Naam == 'A' && S.Hand[0, n].Kleur == skleur
                            && S.Hand[0, n].Slagkans > KjState.SlagkansLevel)
                        { skaart = S.Hand[0, n].Naam; break; }
                    if (skaart == 0)
                        for (n = 0; n < 4; n++)
                            if (S.Tafel[0, n].Naam == 'A' && S.Tafel[0, n].Kleur == skleur
                                && S.Tafel[0, n].Slagkans > KjState.SlagkansLevel)
                            { skaart = S.Tafel[0, n].Naam; break; }
                }
            }
            if (skaart != 0) S.Tactiek = 50;
        }

        // Ik heb troef op tafel en hij een kale A of T van een kleur die ik
        // niet heb: die troef mag weg zonder een zekere slag op te geven.
        if (skaart == 0 && S.IKrtTafel[S.Troef, 0] != 0)
        {
            skleur = 5;
            for (n = 0; n < 4; n++)
                if (S.Tafel[0, n].Troef != 0 && S.Tafel[0, n].Gegarandeerd == 0)
                { skleur = 6; S.Skrt41 = S.Tafel[0, n].Naam; }

            if (skleur == 6)
            {
                for (n = 0; n < 4; n++)
                    if ((S.Tafel[1, n].Naam == 'A' && S.Tafel[1, n].Kleur != S.Troef) ||
                        (S.Tafel[1, n].Naam == 'T' && S.Tafel[1, n].Kleur != S.Troef))
                    {
                        int kl = S.Tafel[1, n].Kleur;
                        if (kl >= 0 && kl < 4 && S.IKrtTafel[kl, 1] == 1 && S.IKrtTafel[kl, 0] == 0)
                            skleur = kl;
                    }

                if (skleur < 4)
                {
                    for (n = 0; n < 8; n++)
                        if (S.Hand[0, n].Kleur == skleur && S.Hand[0, n].Waarde < 5)
                            skaart = S.Hand[0, n].Naam;
                    if (skaart == 0)
                        for (n = 0; n < 8; n++)
                            if (S.Hand[0, n].Kleur == skleur) { skaart = S.Hand[0, n].Naam; break; }
                    if (skaart != 0) S.Tactiek = 41;
                }
            }
        }

        // Grootste roemkans bij een vrijwel zekere slag.
        if (skaart == 0)
        {
            skleur = 5;
            m = 0; int j = 0;
            for (n = 0; n < 4; n++)
                if (S.Tafel[0, n].Slagkans > 85 && m <= S.Tafel[0, n].Slagkans)
                {
                    i = BepaalHoogsteRoem(S.Tafel[0, n].Kleur, S.Tafel[0, n].Naam);
                    if (i > j)
                    {
                        j = i; m = S.Tafel[0, n].Slagkans;
                        skaart = S.Tafel[0, n].Naam; skleur = S.Tafel[0, n].Kleur;
                        S.Tactiek = 10;
                    }
                }
            for (n = 0; n < 8; n++)
                if (S.Hand[0, n].Slagkans > 85 && m <= S.Hand[0, n].Slagkans)
                {
                    i = BepaalHoogsteRoem(S.Hand[0, n].Kleur, S.Hand[0, n].Naam);
                    if (i > j)
                    {
                        j = i; m = S.Hand[0, n].Slagkans;
                        skaart = S.Hand[0, n].Naam; skleur = S.Hand[0, n].Kleur;
                        S.Tactiek = 62;
                    }
                }
        }

        // Laag uitkomen: als de partner de slag toch haalt, eerst de kaart met
        // de meeste roemkans van de andere stapel spelen.
        if (skaart != 0 && S.Tactiek != 41
            && !(skleur == S.Troef && skaart == 'V')
            && !(S.Tactiek == 7 && skleur != S.Troef))
        {
            S.Vrager = WieVrager(skaart, skleur);
            S.Lkaart = skaart;
            S.Lkleur = skleur;
            int j = 0;
            if (skleur >= 0 && skleur < 4)
            {
                if (S.Vrager < 3 && S.IKrtTafel[skleur, 0] != 0)
                    for (m = 0; m < S.IKrtTafel[skleur, 0]; m++)
                    {
                        if (skleur == S.Troef &&
                            CStr.Pos(KjState.RangTroef, S.KTafel[0][skleur][m]) < CStr.Pos(KjState.RangTroef, S.Lkaart))
                            continue;
                        i = BepaalHoogsteRoem(skleur, S.KTafel[0][skleur][m]);
                        if (i >= j)
                        {
                            j = i; skaart = S.KTafel[0][skleur][m];
                            S.TactiekLaag = true; S.Lkaart3 = S.Lkaart; S.Lkleur3 = S.Lkleur;
                        }
                    }
                if (S.Vrager > 2 && S.IKrt[skleur, 0] != 0)
                    for (m = 0; m < S.IKrt[skleur, 0]; m++)
                    {
                        if (skleur == S.Troef &&
                            CStr.Pos(KjState.RangTroef, S.KHand[0][skleur][m]) < CStr.Pos(KjState.RangTroef, S.Lkaart))
                            continue;
                        i = BepaalHoogsteRoem(skleur, S.KHand[0][skleur][m]);
                        if (i >= j)
                        {
                            j = i; skaart = S.KHand[0][skleur][m];
                            S.TactiekLaag = true; S.Lkaart3 = S.Lkaart; S.Lkleur3 = S.Lkleur;
                        }
                    }
            }
            S.Vrager = WieVrager(skaart, skleur);
            S.Lkaart = skaart;
            S.Lkleur = skleur;
            return;
        }

        // Gegarandeerde slagen die geen troef zijn eerst uitspelen.
        if (skaart == 0)
            for (n = 0; n < 4; n++)
                if (S.Tafel[0, n].Gegarandeerd == 1)
                {
                    if (S.Tafel[0, n].Kleur == S.Troef) continue;
                    skaart = S.Tafel[0, n].Naam; skleur = S.Tafel[0, n].Kleur;
                    S.Tactiek = 9; break;
                }
        if (skaart == 0)
            for (n = 0; n < 8; n++)
                if (S.Hand[0, n].Gegarandeerd == 1)
                {
                    if (S.Hand[0, n].Kleur == S.Troef) continue;
                    skaart = S.Hand[0, n].Naam; skleur = S.Hand[0, n].Kleur;
                    S.Tactiek = 8; break;
                }

        // Gegarandeerde slagen, troef trekken zolang de tegenpartij nog troef kan hebben.
        if (skaart == 0)
            for (n = 0; n < 4; n++)
                if (S.Tafel[0, n].Gegarandeerd == 1)
                {
                    if (S.Tafel[0, n].Kleur == S.Troef && kansTroefkaarttp < 30) continue;
                    skaart = S.Tafel[0, n].Naam; skleur = S.Tafel[0, n].Kleur;
                    S.Tactiek = 57; break;
                }
        if (skaart == 0)
            for (n = 0; n < 8; n++)
                if (S.Hand[0, n].Gegarandeerd == 1)
                {
                    if (S.Hand[0, n].Kleur == S.Troef && kansTroefkaarttp < 30) continue;
                    skaart = S.Hand[0, n].Naam; skleur = S.Hand[0, n].Kleur;
                    S.Tactiek = 58; break;
                }

        // Ik heb troef op tafel en hij A, T of H van een kleur die ik niet heb.
        if (skaart == 0 && S.IKrtTafel[S.Troef, 0] != 0)
        {
            skleur = 5;
            for (n = 0; n < 4; n++)
                if ((S.Tafel[1, n].Naam == 'A' || S.Tafel[1, n].Naam == 'T' || S.Tafel[1, n].Naam == 'H')
                    && S.Tafel[1, n].Kleur != S.Troef)
                {
                    int kl = S.Tafel[1, n].Kleur;
                    if (kl >= 0 && kl < 4 && S.IKrtTafel[kl, 1] == 1 && S.IKrtTafel[kl, 0] == 0)
                        skleur = kl;
                }
            if (skleur < 4)
            {
                for (n = 0; n < 8; n++)
                    if (S.Hand[0, n].Kleur == skleur && S.Hand[0, n].Waarde < 5)
                        skaart = S.Hand[0, n].Naam;
                if (skaart == 0)
                    for (n = 0; n < 8; n++)
                        if (S.Hand[0, n].Kleur == skleur) { skaart = S.Hand[0, n].Naam; break; }
                if (skaart != 0) S.Tactiek = 47;
            }
        }

        if (skaart != 0)
        {
            S.Vrager = WieVrager(skaart, skleur);
            S.Lkaart = skaart;
            S.Lkleur = skleur;
            return;
        }

        // Grootste slagkans boven 75.
        m = 0;
        for (n = 0; n < 4; n++)
        {
            if (S.Tafel[0, n].Kleur == S.Troef && kansTroefkaarttp < 20) continue;
            if (S.Tafel[0, n].Slagkans > 75 && m < S.Tafel[0, n].Slagkans)
            {
                m = S.Tafel[0, n].Slagkans;
                skaart = S.Tafel[0, n].Naam; skleur = S.Tafel[0, n].Kleur;
                S.Tactiek = 11;
            }
        }
        for (n = 0; n < 8; n++)
        {
            if (S.Hand[0, n].Kleur == S.Troef && kansTroefkaarttp < 20) continue;
            if (S.Hand[0, n].Slagkans > 75 && m < S.Hand[0, n].Slagkans)
            {
                m = S.Hand[0, n].Slagkans;
                skaart = S.Hand[0, n].Naam; skleur = S.Hand[0, n].Kleur;
                S.Tactiek = 63;
            }
        }

        // Troef van de tafel van de tegenstander trekken met een lage kaart.
        if (skaart == 0 && S.IKrtTafel[S.Troef, 1] != 0)
        {
            for (n = 0; n < 4; n++)
            {
                int kl = S.Tafel[0, n].Kleur;
                if (kl < 0 || kl > 3) continue;
                if (S.IKrtTafel[kl, 1] == 0 && S.Tafel[0, n].Waarde < 5)
                {
                    if (S.IKrt[kl, 0] == 1 &&
                        (S.KHand[0][kl][0] == 'A' || S.KHand[0][kl][0] == 'T'))
                        skaart = (char)0;
                    else { skaart = S.Tafel[0, n].Naam; skleur = kl; }
                }
            }
            if (skaart == 0)
                for (n = 0; n < 8; n++)
                {
                    int kl = S.Hand[0, n].Kleur;
                    if (kl < 0 || kl > 3) continue;
                    if (S.IKrt[kl, 1] == 0 && S.Hand[0, n].Waarde < 5)
                    {
                        if (S.IKrt[kl, 0] == 1 &&
                            (S.KTafel[0][kl][0] == 'A' || S.KTafel[0][kl][0] == 'T'))
                            skaart = (char)0;
                        else { skaart = S.Hand[0, n].Naam; skleur = kl; }
                    }
                }
            if (skaart != 0) S.Tactiek = 5;
        }

        // Overige gegarandeerde slagen, nu ook troef.
        if (skaart == 0)
            for (n = 0; n < 4; n++)
                if (S.Tafel[0, n].Gegarandeerd == 1)
                {
                    skaart = S.Tafel[0, n].Naam; skleur = S.Tafel[0, n].Kleur;
                    S.Tactiek = 55; break;
                }
        if (skaart == 0)
            for (n = 0; n < 8; n++)
                if (S.Hand[0, n].Gegarandeerd == 1)
                {
                    skaart = S.Hand[0, n].Naam; skleur = S.Hand[0, n].Kleur;
                    S.Tactiek = 56; break;
                }

        // Troef op tafel gebruiken om slagen te halen.
        if (skaart == 0 && S.IKrtTafel[S.Troef, 0] != 0)
        {
            skleur = 5;
            for (n = 0; n < 4; n++)
            {
                int kl = S.Tafel[1, n].Kleur;
                if (kl >= 0 && kl < 4 && S.IKrtTafel[kl, 0] == 0 && S.IKrtTafel[kl, 1] != 0)
                    skleur = kl;
            }
            if (skleur < 5)
            {
                for (n = 0; n < 8; n++)
                    if (S.Hand[0, n].Kleur == skleur && S.Hand[0, n].Waarde < 10)
                    { skaart = S.Hand[0, n].Naam; break; }
                if (skaart == 0)
                    for (n = 0; n < 8; n++)
                        if (S.Hand[0, n].Kleur == skleur) { skaart = S.Hand[0, n].Naam; break; }
            }
            if (skaart != 0) { S.Tactiek = 54; S.TactiekTT = true; }
        }

        // Kom uit met een lage kaart zonder roemkans, geen troef.
        if (skaart == 0)
        {
            m = 990;
            for (n = 0; n < 32; n++)
                if (S.Kaart[n].DichtIkHy == S.Vrager + 2 && m >= S.Kaart[n].ActWaarde
                    && S.Kaart[n].Kleur != S.Troef)
                {
                    // In het origineel staat achter de volgende test een losse
                    // puntkomma, waardoor het blok altijd wordt uitgevoerd.
                    BepaalHoogsteRoem(S.Kaart[n].Kleur, S.Kaart[n].Naam);
                    m = S.Kaart[n].ActWaarde;
                    skaart = S.Kaart[n].Naam;
                    skleur = S.Kaart[n].Kleur;
                    S.Tactiek = 13;
                }
        }

        // Kom uit met een lage kaart, geen troef.
        if (skaart == 0)
        {
            m = 990;
            for (n = 0; n < 32; n++)
                if (S.Kaart[n].DichtIkHy == S.Vrager && m >= S.Kaart[n].ActWaarde
                    && S.Kaart[n].Kleur != S.Troef)
                {
                    m = S.Kaart[n].ActWaarde;
                    skaart = S.Kaart[n].Naam;
                    skleur = S.Kaart[n].Kleur;
                    S.Tactiek = 14;
                }
        }

        // Kom uit met de laagste kaart die er is.
        if (skaart == 0)
        {
            m = 990;
            for (n = 0; n < 32; n++)
                if (S.Kaart[n].DichtIkHy == S.Vrager && m >= S.Kaart[n].ActWaarde)
                {
                    m = S.Kaart[n].ActWaarde;
                    skaart = S.Kaart[n].Naam;
                    skleur = S.Kaart[n].Kleur;
                    S.Tactiek = 15;
                }
        }

        S.Vrager = WieVrager(skaart, skleur);
        S.Lkaart = skaart;
        S.Lkleur = skleur;
    }

    // ---------------------------------------------------- tegenspeler1

    /// <summary>Tweede kaart van de slag: de tafelkaart van de tegenpartij.</summary>
    public void Tegenspeler1()
    {
        char[] nop = CStr.New(16), nop1 = CStr.New(16);
        int m, n, i, j = 0, s;

        S.Vrager = (S.StartVrager == 1 || S.StartVrager == 3) ? 4 : 3;

        Vulhanden();
        S.Lkaart = (char)0;
        int skleur = S.Slag(S.SlagNr, 0).Kleur;
        char skaart = S.Slag(S.SlagNr, 0).Naam;
        S.Lkleur = skleur;

        string slagvolgorde = S.Slag(S.SlagNr, 0).Troef != 0 ? KjState.RangTroef : KjState.RangNorm;

        if (!S.Comp && S.Vrager == 3) { Humaan(); return; }
        if (ZoekendeSpeler()) return;
        if (skleur < 0 || skleur > 3) { BekijkBesteSlag(skleur); return; }

        if (S.IKrtTafel[skleur, 0] == 1)
        { S.Lkaart = S.KTafel[0][skleur][0]; S.Tactiek = 40; return; }

        if (S.IKrtTafel[skleur, 0] > 1 && skleur == S.Troef)
        {
            for (n = 0; n < 8; n++)
            {
                if (slagvolgorde[n] != skaart) nop1[n] = slagvolgorde[n];
                else { nop1[n] = CStr.Nul; break; }
            }
            if (n >= 8) n = 8;
            nop1[n] = CStr.Nul;

            i = 0;   // aantal hogere kaarten op mijn tafel
            for (m = 0; m < S.IKrtTafel[skleur, 0]; m++)
            {
                if (CStr.Pos(nop1, S.KTafel[0][skleur][m]) == 0) continue;
                nop[i++] = S.KTafel[0][skleur][m];
            }
            nop[i] = CStr.Nul;
            int aantalhoger = i;

            s = -110;
            i = 0;
            for (n = 0; n < aantalhoger; n++)
            {
                i = BepaalSlagkans(nop[n], skleur);
                if (i >= s) { s = i; j = n; }
            }

            if (aantalhoger == 1) { S.Lkaart = nop[j]; S.Tactiek = 18; return; }
            if (i > 40) { S.Lkaart = nop[j]; S.Tactiek = 19; }
            else
            {
                // Doe alsof alleen de hogere kaarten van mij zijn en vraag dan
                // welke daarvan de minste roem weggeeft.
                int[] ss = new int[8];
                i = 0;
                for (n = skleur * 8; n < (skleur + 1) * 8; n++) ss[i++] = S.Kaart[n].DichtIkHy;

                for (n = skleur * 8; n < (skleur + 1) * 8; n++)
                    if (S.Kaart[n].DichtIkHy == S.Vrager) S.Kaart[n].DichtIkHy = Pos.Gespeeld;

                int len = CStr.Len(nop);
                for (m = 0; m < len; m++)
                    for (n = skleur * 8; n < (skleur + 1) * 8; n++)
                        if (S.Kaart[n].Naam == nop[m]) S.Kaart[n].DichtIkHy = S.Vrager;

                S.Lkaart = LaagsteRoem(skleur);
                S.Tactiek = 42;

                i = 0;
                for (n = skleur * 8; n < (skleur + 1) * 8; n++) S.Kaart[n].DichtIkHy = ss[i++];
            }
        }

        if (S.Lkaart == 0) BekijkBesteSlag(S.Slag(S.SlagNr, 0).Kleur);
    }

    // ---------------------------------------------------- tegenspeler2

    /// <summary>Vierde en laatste kaart van de slag.</summary>
    public void Tegenspeler2()
    {
        char[] nop = CStr.New(16), nop1 = CStr.New(16), khoger = CStr.New(16);
        char[] kname = CStr.New(24);
        int m, n, i, j, s, t;

        S.Vrager = (S.StartVrager == 1 || S.StartVrager == 3) ? 2 : 1;

        Vulhanden();
        S.Lkaart = (char)0;
        int skleur = S.Slag(S.SlagNr, 0).Kleur;
        char skaart = S.Slag(S.SlagNr, 0).Naam;
        int skleur1 = S.Slag(S.SlagNr, 1).Kleur;
        char skaart1 = S.Slag(S.SlagNr, 1).Naam;
        int skleur2 = S.Slag(S.SlagNr, 2).Kleur;
        char skaart2 = S.Slag(S.SlagNr, 2).Naam;
        S.Lkleur = skleur;

        if (skleur < 0 || skleur > 3) { BekijkBesteSlag(skleur); return; }

        CStr.Cpy(kname, S.KHand[0][skleur]);
        int ikarte = S.IKrt[skleur, 0];

        string slagvolgorde = S.Slag(S.SlagNr, 0).Troef != 0 ? KjState.RangTroef : KjState.RangNorm;

        if (!S.Comp && S.Vrager == 1) { Humaan(); return; }
        if (ZoekendeSpeler()) return;

        if (ikarte == 1) { S.Lkaart = kname[0]; S.Tactiek = 38; return; }

        if (ikarte > 1 && skleur == S.Troef)
        {
            i = 0;
            for (n = 0; n < S.SlagKrtNo; n++)
                if (S.Slag(S.SlagNr, n).Troef != 0) nop[i++] = S.Slag(S.SlagNr, n).Naam;
            nop[i] = CStr.Nul;

            if (CStr.Pos(KjState.RangTroef, skaart) > CStr.Pos(KjState.RangTroef, skaart1) && skleur1 == S.Troef)
                skaart = skaart1;
            if (CStr.Pos(KjState.RangTroef, skaart) > CStr.Pos(KjState.RangTroef, skaart2) && skleur2 == S.Troef)
                skaart = skaart2;

            for (n = 0; n < 8; n++)
            {
                if (slagvolgorde[n] != skaart) nop1[n] = slagvolgorde[n];
                else { nop1[n] = CStr.Nul; break; }
            }
            if (n >= 8) nop1[8] = CStr.Nul;

            i = 0;
            for (m = 0; m < ikarte; m++)
            {
                if (CStr.Pos(nop1, kname[m]) == 0) continue;
                khoger[i++] = kname[m];
            }
            khoger[i] = CStr.Nul;
            int aantalhoger = i;

            s = -110;
            j = WieSlag();
            t = CStr.Len(nop);
            nop[t + 1] = CStr.Nul;

            // Slag is al aan mijn kant en ik kan niet hoger: pak de roem mee.
            if (j == S.Vrager + 2 && aantalhoger == 0)
            { S.Lkaart = HoogsteRoem(S.Troef); S.Tactiek = 17; }

            if (aantalhoger > 1)
            {
                for (n = 0; n < aantalhoger; n++)
                {
                    nop[t] = khoger[n];
                    i = BepaalRoemPunten(nop, S.Troef);
                    if (i >= s) { s = i; j = n; }
                }
                S.Lkaart = khoger[j];
                S.Tactiek = 20;
            }
            if (j != S.Vrager + 2 && aantalhoger == 0)
            { S.Lkaart = LaagsteRoem(S.Troef); S.Tactiek = 39; }

            S.Lkleur = S.Troef;
            if (aantalhoger == 1) { S.Lkaart = khoger[0]; S.Tactiek = 30; }

            // Valt er geen roem, gooi dan geen troef weg.
            if (aantalhoger == 0 && S.Lkaart != 0)
            {
                nop[t] = S.Lkaart;
                if (BepaalRoemPunten(nop, S.Troef) == 0) S.Lkaart = (char)0;
            }
        }

        if (S.Lkaart == 0) BekijkBesteSlag(S.Slag(S.SlagNr, 0).Kleur);
    }

    // -------------------------------------------------------- speler2

    /// <summary>Derde kaart van de slag.</summary>
    public void Speler2()
    {
        char[] nop = CStr.New(16), nop1 = CStr.New(16), khoger = CStr.New(16);
        char[] kname = CStr.New(24);
        int m, n, i, j = 0, s, t;

        if (S.StartVrager == 1) S.Vrager = 3;
        if (S.StartVrager == 2) S.Vrager = 4;
        if (S.StartVrager == 3) S.Vrager = 1;
        if (S.StartVrager == 4) S.Vrager = 2;

        Vulhanden();
        S.Lkaart = (char)0;
        int skleur = S.Slag(S.SlagNr, 0).Kleur;
        char skaart = S.Slag(S.SlagNr, 0).Naam;
        int skleur1 = S.Slag(S.SlagNr, 1).Kleur;
        char skaart1 = S.Slag(S.SlagNr, 1).Naam;
        S.Lkleur = skleur;

        if (skleur < 0 || skleur > 3) { BekijkBesteSlag(skleur); return; }

        int ikarte;
        if (S.StartVrager > 2)
        {
            CStr.Cpy(kname, S.KHand[0][skleur]);
            ikarte = S.IKrt[skleur, 0];
        }
        else
        {
            CStr.Cpy(kname, S.KTafel[0][skleur]);
            ikarte = S.IKrtTafel[skleur, 0];
        }

        string slagvolgorde = S.Slag(S.SlagNr, 0).Troef != 0 ? KjState.RangTroef : KjState.RangNorm;

        if (!S.Comp && (S.Vrager == 1 || S.Vrager == 3)) { Humaan(); return; }
        if (ZoekendeSpeler()) return;

        // Speler1 hield bewust een kaart achter om nu laag mee te komen.
        if (S.TactiekLaag)
        {
            S.Lkaart = S.Lkaart3;
            S.Lkleur = S.Lkleur3;
            S.Tactiek = 6;
            S.TactiekLaag = false;
            return;
        }

        if (S.Tactiek41)   // troef kwijtraken, A of T van de tegenstander trekken
        {
            S.Tactiek41 = false;
            S.Lkaart = S.Skrt41;
            S.Lkleur = S.Troef;
            S.Tactiek = 45;
            if (S.Lkaart != 0) return;
        }

        if (S.TactiekTT)   // troef van tafel kwijtraken
        {
            S.TactiekTT = false;
            i = 0;
            for (n = 0; n < 4; n++)
                if (S.Tafel[0, n].Kleur == S.Troef && i <= S.Tafel[0, n].Waarde)
                { i = S.Tafel[0, n].Waarde; S.Lkaart = S.Tafel[0, n].Naam; S.Lkleur = S.Troef; }
            S.Tactiek = 12;
            if (S.Lkaart != 0) return;
        }

        if (ikarte == 1) { S.Lkaart = kname[0]; S.Tactiek = 36; return; }

        if (ikarte > 1 && skleur == S.Troef)
        {
            if (skleur == skleur1 &&
                CStr.Pos(KjState.RangTroef, skaart) > CStr.Pos(KjState.RangTroef, skaart1))
                skaart = skaart1;

            for (n = 0; n < 8; n++)
            {
                if (slagvolgorde[n] != skaart) nop1[n] = slagvolgorde[n];
                else { nop1[n] = CStr.Nul; break; }
            }
            if (n >= 8) nop1[8] = CStr.Nul;

            i = 0;
            for (m = 0; m < ikarte; m++)
            {
                if (CStr.Pos(nop1, kname[m]) == 0) continue;
                nop[i++] = kname[m];
            }
            nop[i] = CStr.Nul;
            CStr.Cpy(khoger, nop);
            int aantalhoger = i;

            s = -110;
            i = 0;
            for (n = 0; n < aantalhoger; n++)
            {
                i = BepaalSlagkans(nop[n], S.Troef);
                if (i >= s) { s = i; j = n; }
            }

            if (aantalhoger == 1) { S.Lkaart = nop[j]; S.Tactiek = 66; return; }
            if (i > 50) { S.Lkaart = nop[j]; S.Tactiek = 67; return; }

            s = -100;
            if (aantalhoger != 0)
            {
                i = 0;
                for (n = 0; n < S.SlagKrtNo; n++)
                    if (S.Slag(S.SlagNr, n).Troef != 0) nop[i++] = S.Slag(S.SlagNr, n).Naam;
                nop[i] = CStr.Nul;
                t = CStr.Len(nop);
                nop[t + 1] = CStr.Nul;
                for (n = 0; n < aantalhoger; n++)
                {
                    nop[t] = khoger[n];
                    i = BepaalRoemPunten(nop, S.Troef);
                    if (i >= s) { s = i; j = n; }
                }
                S.Lkaart = khoger[j];
                S.Tactiek = 37;
            }
        }

        if (S.Lkaart == 0) BekijkBesteSlag(S.Slag(S.SlagNr, 0).Kleur);
    }
}