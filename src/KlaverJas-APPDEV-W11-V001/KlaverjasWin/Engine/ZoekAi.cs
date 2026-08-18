namespace Klaverjas.Engine;

/// <summary>
/// De speelwijze van R. Loggen (KJBeide/KJ2.C), overgezet op de gegevens van
/// deze engine.
///
/// Waar de tactiek van Ed uit een lange reeks vuistregels bestaat, probeert deze
/// speler het uit: hij speelt elke eigen kaart proef, laat de tegenstander er
/// zijn beste antwoord op geven, speelt zelf zijn beste vervolg, en middelt over
/// alle kaarten die de tegenstander nog in handen kán hebben. De waarde van een
/// slag is punten plus roem, met een minteken als de tegenstander hem pakt —
/// vandaar dat deze speler vanzelf op roem speelt.
///
/// Dat de eerste drie kaarten exact doorgerekend kunnen worden komt doordat de
/// tafelkaarten open liggen: alleen de handkaarten van de tegenstander zijn
/// onbekend, en dat is precies de vierde kaart van de slag.
///
/// Dit is Loggens methode op onze gegevens, geen regel-voor-regel omzetting van
/// zijn code: zijn programma heeft een eigen kaartadministratie (struct kaart
/// met wi/wa/s), die hier al in KjState zit. `LegaleZetten` is wél een directe
/// omzetting van zijn `kjlegaal`, zodat de zoektocht nooit een onreglementaire
/// kaart voorstelt.
/// </summary>
public sealed class ZoekAi
{
    private readonly KjEngine _e;
    private KjState S => _e.S;

    public ZoekAi(KjEngine engine) => _e = engine;

    /// <summary>Eén kaart op tafel tijdens het doorrekenen.</summary>
    private readonly record struct Zet(int Kleur, char Naam, bool Mijn);

    // ------------------------------------------------------------- basis

    /// <summary>Hoe sterk is deze kaart binnen zijn kleur? Hoger is sterker.</summary>
    private int Kracht(char naam, int kleur)
    {
        string rang = kleur == S.Troef ? KjState.RangTroef : KjState.RangNorm;
        int p = CStr.Pos(rang, naam);
        return p == 0 ? 0 : 9 - p;
    }

    /// <summary>Kaartpunten, troef telt anders.</summary>
    private int Waarde(char naam, int kleur)
    {
        int nr = KjState.KaartNr(kleur, naam);
        return (nr >= 0 && nr < 32) ? S.Kaart[nr].ActWaarde : 0;
    }

    /// <summary>Welke van de vier kaarten pakt de slag?</summary>
    private int Winnaar(Zet[] slag)
    {
        int leidend = slag[0].Kleur;
        bool troefErin = false;
        for (int i = 0; i < 4; i++) if (slag[i].Kleur == S.Troef) troefErin = true;
        int telt = troefErin ? S.Troef : leidend;

        int beste = -1, besteKracht = -1;
        for (int i = 0; i < 4; i++)
        {
            if (slag[i].Kleur != telt) continue;
            int k = Kracht(slag[i].Naam, slag[i].Kleur);
            if (k > besteKracht) { besteKracht = k; beste = i; }
        }
        return beste < 0 ? 0 : beste;
    }

    /// <summary>
    /// Punten plus roem van een volledige slag, gezien vanuit mijn kant:
    /// positief als ik hem pak, negatief als de tegenstander hem pakt. Dit is
    /// `kjmaakslagtest` uit KJ0.C.
    /// </summary>
    private int SlagWaarde(Zet[] slag)
    {
        int punten = 0;
        for (int i = 0; i < 4; i++) punten += Waarde(slag[i].Naam, slag[i].Kleur);

        int roem = 0;
        char[] sp = CStr.New(8);
        for (int kleur = 0; kleur < 4; kleur++)
        {
            int n = 0;
            for (int i = 0; i < 4; i++) if (slag[i].Kleur == kleur) sp[n++] = slag[i].Naam;
            sp[n] = CStr.Nul;
            if (n > 1) roem += _e.BepaalRoemPunten(sp, kleur);
        }
        // Vier gelijke kaarten, net als in Evalueer().
        if (slag[0].Naam == slag[1].Naam && slag[1].Naam == slag[2].Naam && slag[2].Naam == slag[3].Naam)
            roem += slag[0].Naam == 'B' ? 200 : 100;

        int totaal = punten + roem;
        return slag[Winnaar(slag)].Mijn ? totaal : -totaal;
    }

    // -------------------------------------------------- reglementaire zetten

    /// <summary>
    /// Welke kaarten mag deze stapel spelen? Directe omzetting van `kjlegaal`
    /// uit KJ0.C: troef bekennen en overtroeven waar het moet, kleur bekennen,
    /// en bij niet kunnen bekennen wel of niet moeten troeven al naar gelang de
    /// slag al aan de eigen kant is.
    /// </summary>
    private List<(int Kleur, char Naam)> LegaleZetten(
        List<(int Kleur, char Naam)> bezit, List<Zet> opTafel, bool slagIsVanMij)
    {
        var uit = new List<(int, char)>();
        if (opTafel.Count == 0) { uit.AddRange(bezit); return uit; }

        int leidend = opTafel[0].Kleur;

        // Hoogste kaart die de slag nu zou pakken, en in welke kleur.
        int besteKracht = -1;
        int besteKleur = leidend;
        bool troefErin = false;
        foreach (var z in opTafel) if (z.Kleur == S.Troef) troefErin = true;
        int telt = troefErin ? S.Troef : leidend;
        foreach (var z in opTafel)
        {
            if (z.Kleur != telt) continue;
            int k = Kracht(z.Naam, z.Kleur);
            if (k > besteKracht) { besteKracht = k; besteKleur = z.Kleur; }
        }

        if (leidend == S.Troef)
        {
            foreach (var b in bezit)
                if (b.Kleur == S.Troef && Kracht(b.Naam, b.Kleur) > besteKracht) uit.Add(b);
            if (uit.Count == 0)
                foreach (var b in bezit) if (b.Kleur == leidend) uit.Add(b);
            if (uit.Count == 0) uit.AddRange(bezit);
            return uit;
        }

        foreach (var b in bezit) if (b.Kleur == leidend) uit.Add(b);
        if (uit.Count > 0) return uit;

        if (slagIsVanMij)
        {
            // Slag staat al op eigen naam: alles mag, behalve ondertroeven als
            // er getroefd is.
            foreach (var b in bezit)
            {
                if (troefErin && b.Kleur == S.Troef && Kracht(b.Naam, b.Kleur) <= besteKracht) continue;
                uit.Add(b);
            }
            if (uit.Count == 0) uit.AddRange(bezit);
            return uit;
        }

        foreach (var b in bezit)
            if (b.Kleur == S.Troef && Kracht(b.Naam, b.Kleur) > besteKracht) uit.Add(b);
        if (uit.Count == 0) uit.AddRange(bezit);
        return uit;
    }

    // ------------------------------------------------------- kaarten tellen

    /// <summary>Kaarten van een eigen stapel: hand (0) of tafel (1) van mijn kant.</summary>
    private List<(int Kleur, char Naam)> EigenBezit(bool tafel)
    {
        var uit = new List<(int, char)>();
        int aantal = tafel ? 4 : 8;
        for (int n = 0; n < aantal; n++)
        {
            var d = tafel ? S.Tafel[0, n] : S.Hand[0, n];
            if (d.Naam != 0 && d.Kleur >= 0 && d.Kleur < 4) uit.Add((d.Kleur, d.Naam));
        }
        return uit;
    }

    /// <summary>De open tafelkaarten van de tegenstander; die zijn bekend.</summary>
    private List<(int Kleur, char Naam)> TegenstanderTafel()
    {
        var uit = new List<(int, char)>();
        for (int n = 0; n < 4; n++)
        {
            var d = S.Tafel[1, n];
            if (d.Naam != 0 && d.Kleur >= 0 && d.Kleur < 4) uit.Add((d.Kleur, d.Naam));
        }
        return uit;
    }

    /// <summary>
    /// Kaarten die de tegenstander nog in handen kán hebben. Dat is wat voor
    /// ons dicht is: zijn hand en de omgekeerde tafelkaarten. Kleuren waarin
    /// hij aantoonbaar verzaakt heeft vallen af.
    /// </summary>
    private List<(int Kleur, char Naam)> MogelijkeHand(int kleurVoorkeur)
    {
        int tegen = S.Vrager > 2 ? S.Vrager - 2 : S.Vrager;
        tegen = tegen == 1 ? 2 : 1;

        var uit = new List<(int, char)>();
        void Voeg(int kleur)
        {
            if (kleur < 0 || kleur > 3) return;
            if (S.Verzaakt[tegen - 1, kleur] != 0) return;
            int len = CStr.Len(S.KrtDicht[kleur]);
            for (int i = 0; i < len; i++) uit.Add((kleur, S.KrtDicht[kleur][i]));
        }
        Voeg(kleurVoorkeur);
        if (S.Troef != kleurVoorkeur) Voeg(S.Troef);
        return uit;
    }

    // ------------------------------------------------------- troef kiezen

    /// <summary>
    /// De troefkeuze van Loggen (`kj2troef` uit KJ2.C). Hij waardeert elke
    /// kleur alsof die troef is en kiest de hoogste.
    ///
    /// Anders dan `troef_bepalen()` van Ed op drie punten: troeflengte telt
    /// kwadratisch in plaats van lineair, hand en tafel worden apart geteld,
    /// en de zijkleuren worden gewaardeerd op hun drie hoogste kaarten in
    /// plaats van op zekere slagen.
    /// </summary>
    public int KiesTroef()
    {
        int mij = (S.StartVrager > 2) ? S.StartVrager - 2 : S.StartVrager;
        if (mij < 1 || mij > 2) mij = 1;
        int mijnHand = mij;
        int mijnTafel = mij + 2;
        int hijTafel = (mij == 1) ? Pos.TafelNoord : Pos.TafelZuid;

        var t = new int[4];
        for (int y = 0; y < 4; y++)
        {
            // De troefkleur zelf: mijn kaarten tellen mee, de open troeven van
            // de tegenstander gaan eraf.
            for (int idx = 0; idx < 8; idx++)
            {
                int nr = KjState.KaartNr(y, KjState.RangTroef[idx]);
                int w = S.Kaart[nr].DichtIkHy;
                int p = S.Kaart[nr].TroefWaarde;
                if (w == mijnHand || w == mijnTafel) t[y] += p;
                else if (w == hijTafel) t[y] -= p;
            }

            // Zijn zichtbare troeven die ik kan afdekken tellen dubbel: van
            // onderaf zijn kaarten, van bovenaf de mijne.
            for (int x = 7, z = 0; x > 0; x--)
            {
                int nrX = KjState.KaartNr(y, KjState.RangTroef[x]);
                if (S.Kaart[nrX].DichtIkHy != hijTafel) continue;
                int nrZ = KjState.KaartNr(y, KjState.RangTroef[z]);
                int wz = S.Kaart[nrZ].DichtIkHy;
                if (wz != mijnHand && wz != mijnTafel) break;
                t[y] += S.Kaart[nrX].TroefWaarde * 2;
                z++;
            }

            for (int x = 0; x < 4; x++)
            {
                int trh = 0, trt = 0, p1 = 0, p2 = 0;
                string rang = (x == y) ? KjState.RangTroef : KjState.RangNorm;
                for (int idx = 0; idx < 8; idx++)
                {
                    int nr = KjState.KaartNr(x, rang[idx]);
                    int w = S.Kaart[nr].DichtIkHy;
                    int hoog = idx == 0 ? 200 : idx == 1 ? 100 : idx == 2 ? 20 : 8 - idx;
                    if (w == mijnHand) { if (x == y) trh++; else p1 += hoog; }
                    else if (w == mijnTafel) { if (x == y) trt++; else p2 += hoog; }
                }
                // Lengte telt kwadratisch, hand en tafel apart: vier troeven in
                // één stapel zijn meer waard dan twee-en-twee verdeeld.
                if (x == y) t[y] += trh * trh + trt * trt;
                t[y] += Ladder(p1) + Ladder(p2);
            }
        }

        int beste = 0;
        for (int x = 1; x < 4; x++) if (t[x] > t[beste]) beste = x;
        return beste;
    }

    /// <summary>Drempels waarmee Loggen een zijkleur waardeert.</summary>
    private static int Ladder(int p)
        => p >= 320 ? 6 : p >= 300 ? 5 : p >= 220 ? 4 : p >= 200 ? 3 : p > 100 ? 1 : 0;

    // -------------------------------------------------------- de zoektocht

    /// <summary>
    /// Welke stapel speelt de zoveelste kaart van de slag? De volgorde ligt
    /// vast: uitkomer, tafel van de tegenstander, andere stapel van de
    /// uitkomer, hand van de tegenstander. Waarden 1..4 zoals VRAGER.
    /// </summary>
    private static int VragerOpPlek(int leider, int plek) => plek switch
    {
        0 => leider,
        1 => (leider == 1 || leider == 3) ? 4 : 3,
        2 => leider switch { 1 => 3, 2 => 4, 3 => 1, _ => 2 },
        _ => (leider == 1 || leider == 3) ? 2 : 1,
    };

    private static int KantVan(int vrager) => vrager > 2 ? vrager - 2 : vrager;

    /// <summary>
    /// Kiest een kaart voor de stapel die aan zet is en zet die in S.Lkaart /
    /// S.Lkleur, net als de tactiekroutines van Ed doen.
    /// </summary>
    public void Kies()
    {
        int mijnKant = KantVan(S.Vrager);
        int plek = Math.Clamp(S.SlagKrtNo, 0, 3);
        int leider = plek == 0 ? S.Vrager : S.Slag(S.SlagNr, 0).Speler;
        if (leider < 1 || leider > 4) leider = S.Vrager;

        var opTafel = new List<Zet>();
        for (int n = 0; n < plek; n++)
        {
            ref var sk = ref S.Slag(S.SlagNr, n);
            opTafel.Add(new Zet(sk.Kleur, sk.Naam, KantVan(sk.Speler) == mijnKant));
        }

        var bezit = EigenBezit(S.Vrager > 2);
        if (bezit.Count == 0) return;

        // De regelcontrole van de engine is doorslaggevend, niet mijn omzetting
        // van kjlegaal: check_valid heeft eigenaardigheden uit 1994 die daar
        // niet in zitten, en een kaart die hij afkeurt kost het hele spel.
        var kandidaten = bezit.Where(Toegestaan).ToList();
        if (kandidaten.Count == 0) kandidaten = LegaleZetten(bezit, opTafel, SlagIsVanMij(opTafel));
        if (kandidaten.Count == 0) kandidaten = bezit;

        var score = new int[kandidaten.Count];
        for (int i = 0; i < kandidaten.Count; i++)
        {
            var proef = new List<Zet>(opTafel) { new Zet(kandidaten[i].Kleur, kandidaten[i].Naam, true) };
            var gebruikt = new List<(int, char)> { kandidaten[i] };
            score[i] = Verder(proef, gebruikt, leider, mijnKant);
        }

        int beste = Uitkiezen(kandidaten, score, opTafel);

        S.Lkleur = kandidaten[beste].Kleur;
        S.Lkaart = kandidaten[beste].Naam;
        S.Tactiek = 70;                       // 70 = gekozen door de zoekende speler
        S.Vrager = _e.WieVrager(S.Lkaart, S.Lkleur);
    }

    /// <summary>
    /// Kiest uit de doorgerekende kaarten, met de voorkeuren uit `kj2welke` en
    /// het slot van `kj2uitkom0`: bij gelijke opbrengst liever geen zekere slag
    /// weggeven en liever geen troef. De hoogste score wint pas als die
    /// voorkeuren niets opleveren, of als de opbrengst toch al nul of minder is.
    /// </summary>
    private int Uitkiezen(List<(int Kleur, char Naam)> kand, int[] score, List<Zet> opTafel)
    {
        bool leiden = opTafel.Count == 0;
        bool troefGeleid = !leiden && opTafel[0].Kleur == S.Troef;
        bool troefOp = S.Troef >= 0 && S.Troef < 4 && CStr.Len(S.KrtDicht[S.Troef]) == 0;

        int Beste(Func<int, bool> mag)
        {
            int k = -1;
            for (int i = 0; i < kand.Count; i++)
            {
                if (!mag(i)) continue;
                if (k < 0 || score[i] > score[k]) k = i;
            }
            return k;
        }
        bool Zeker(int i) => IsZekereSlag(kand[i]);
        bool IsTroef(int i) => kand[i].Kleur == S.Troef;

        int k;
        if (leiden)
        {
            // Zijn alle troeven op, dan liever een gewone kaart uitspelen.
            if (troefOp)
            {
                k = Beste(i => !IsTroef(i));
                if (k >= 0 && score[k] > 0) return k;
            }
            return Math.Max(0, Beste(_ => true));
        }

        if (!troefGeleid)
        {
            k = Beste(i => !Zeker(i) && !IsTroef(i));
            if (k >= 0 && score[k] > 0) return k;
        }
        k = Beste(i => !Zeker(i));
        if (k >= 0 && score[k] > 0) return k;
        return Math.Max(0, Beste(_ => true));
    }

    /// <summary>
    /// Is dit een kaart die de slag vrijwel zeker pakt? De engine rekent dat al
    /// uit in Vulhanden; dat is hetzelfde als de 'Z' die `kj2status` zet.
    /// </summary>
    private bool IsZekereSlag((int Kleur, char Naam) kaart)
    {
        for (int n = 0; n < 8; n++)
            if (S.Hand[0, n].Naam == kaart.Naam && S.Hand[0, n].Kleur == kaart.Kleur)
                return S.Hand[0, n].Gegarandeerd != 0;
        for (int n = 0; n < 4; n++)
            if (S.Tafel[0, n].Naam == kaart.Naam && S.Tafel[0, n].Kleur == kaart.Kleur)
                return S.Tafel[0, n].Gegarandeerd != 0;
        return false;
    }

    /// <summary>
    /// Keurt de regelcontrole van de engine deze kaart goed? Zij bepaalt of de
    /// zet doorgaat, dus daar moet de keuze op aansluiten.
    /// </summary>
    private bool Toegestaan((int Kleur, char Naam) kaart)
    {
        char bewaardKaart = S.Lkaart;
        int bewaardKleur = S.Lkleur;
        S.Lkaart = kaart.Naam;
        S.Lkleur = kaart.Kleur;
        bool goed = _e.CheckValid() == null;
        S.Lkaart = bewaardKaart;
        S.Lkleur = bewaardKleur;
        return goed;
    }

    /// <summary>Staat de slag op dit moment op mijn naam?</summary>
    private bool SlagIsVanMij(List<Zet> opTafel)
    {
        if (opTafel.Count == 0) return false;
        int leidend = opTafel[0].Kleur;
        bool troefErin = false;
        foreach (var z in opTafel) if (z.Kleur == S.Troef) troefErin = true;
        int telt = troefErin ? S.Troef : leidend;
        int beste = 0, besteKracht = -1;
        for (int i = 0; i < opTafel.Count; i++)
        {
            if (opTafel[i].Kleur != telt) continue;
            int k = Kracht(opTafel[i].Naam, opTafel[i].Kleur);
            if (k > besteKracht) { besteKracht = k; beste = i; }
        }
        return opTafel[beste].Mijn;
    }

    /// <summary>
    /// Vult de slag verder aan tot er vier kaarten liggen. Mijn eigen stapels
    /// kiezen het beste, de open tafel van de tegenstander het slechtste voor
    /// mij, en over zijn onbekende handkaart wordt gemiddeld — dat is de enige
    /// kaart die niemand kan zien.
    /// </summary>
    private int Verder(List<Zet> opTafel, List<(int Kleur, char Naam)> gebruikt, int leider, int mijnKant)
    {
        if (opTafel.Count >= 4) return SlagWaarde(opTafel.ToArray());

        int plek = opTafel.Count;
        int vrager = VragerOpPlek(leider, plek);
        bool isMijn = KantVan(vrager) == mijnKant;
        bool slagVanMij = SlagIsVanMij(opTafel);

        List<(int Kleur, char Naam)> bezit;
        if (isMijn)
        {
            bezit = EigenBezit(vrager > 2);
            bezit.RemoveAll(b => gebruikt.Any(g => g.Kleur == b.Kleur && g.Naam == b.Naam));
        }
        else if (vrager > 2)
        {
            bezit = TegenstanderTafel();                 // open, dus precies bekend
        }
        else
        {
            bezit = MogelijkeHand(opTafel.Count > 0 ? opTafel[0].Kleur : S.Troef);
        }
        bezit.RemoveAll(b => opTafel.Any(z => z.Kleur == b.Kleur && z.Naam == b.Naam));

        var zetten = LegaleZetten(bezit, opTafel, isMijn ? slagVanMij : !slagVanMij);
        if (zetten.Count == 0) return SlagWaarde(Aanvullen(opTafel));

        if (isMijn)
        {
            int best = int.MinValue;
            foreach (var z in zetten)
            {
                var volgend = new List<Zet>(opTafel) { new Zet(z.Kleur, z.Naam, true) };
                var nu = new List<(int, char)>(gebruikt) { z };
                best = Math.Max(best, Verder(volgend, nu, leider, mijnKant));
            }
            return best;
        }

        if (vrager > 2)
        {
            int slechtst = int.MaxValue;
            foreach (var z in zetten)
            {
                var volgend = new List<Zet>(opTafel) { new Zet(z.Kleur, z.Naam, false) };
                slechtst = Math.Min(slechtst, Verder(volgend, gebruikt, leider, mijnKant));
            }
            return slechtst;
        }

        long som = 0;
        foreach (var z in zetten)
        {
            var volgend = new List<Zet>(opTafel) { new Zet(z.Kleur, z.Naam, false) };
            som += Verder(volgend, gebruikt, leider, mijnKant);
        }
        return (int)(som / zetten.Count);
    }

    /// <summary>
    /// Vult een onvolledige slag aan met de laatst gelegde kaart, zodat er altijd
    /// gewaardeerd kan worden. Komt alleen voor als er niets legaals meer over is.
    /// </summary>
    private static Zet[] Aanvullen(List<Zet> opTafel)
    {
        var vier = new Zet[4];
        for (int i = 0; i < 4; i++)
            vier[i] = i < opTafel.Count ? opTafel[i] : opTafel[opTafel.Count - 1];
        return vier;
    }
}
