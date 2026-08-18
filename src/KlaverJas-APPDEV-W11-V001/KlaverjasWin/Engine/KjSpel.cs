using System.Threading;

namespace Klaverjas.Engine;

/// <summary>Wat de speellogica van de buitenwereld nodig heeft.</summary>
public interface IKjUi
{
    /// <summary>Nieuwe toestand tonen.</summary>
    void Toon(SpelView view);

    /// <summary>Blokkeert tot de speler een kaart kiest. Geeft (naam, kleur).</summary>
    (char Naam, int Kleur) KiesKaart(SpelView view);

    /// <summary>Blokkeert tot de speler een troefkleur kiest (0..3).</summary>
    int KiesTroef(SpelView view);

    /// <summary>Blokkeert tot de speler verder wil.</summary>
    void Verder(SpelView view, string tekst);
}

/// <summary>
/// De speelloop uit main() van KJ.C: delen, troef bepalen, acht slagen spelen,
/// afrekenen, opnieuw. Draait op een eigen thread en praat met de UI via IKjUi.
/// </summary>
public sealed class KjSpel
{
    public readonly KjEngine E;
    private readonly IKjUi _ui;
    private KjState S => E.S;

    private List<SlagView> _vorigeSlag = new();
    private string _melding = "";

    public KjSpel(IKjUi ui, int? seed = null)
    {
        _ui = ui;
        E = new KjEngine(seed);
    }

    /// <summary>Speelt spel na spel tot de token wordt afgebroken.</summary>
    public void Loop(CancellationToken ct)
    {
        S.Speler = S.Random(2) + 1;

        while (!ct.IsCancellationRequested)
        {
            SpeelEenSpel(ct);
        }
    }

    private void SpeelEenSpel(CancellationToken ct)
    {
        int n;

        S.Troef = 999;
        S.SlagNr = 0;
        S.SlagKrtNo = 0;
        _vorigeSlag = new List<SlagView>();
        _melding = "";

        E.Delen();

        S.Speler = 1 - (S.Speler - 1) + 1;      // wisselt tussen 1 en 2
        S.Vrager = S.StartVrager = S.Speler;

        for (n = 0; n < 4; n++) { S.TNoord[n] = 1; S.TZuid[n] = 1; }

        E.KaartenVrij();
        E.ZetTafelPosities();
        E.Vulhanden();

        S.SlagNr = 0;

        if (S.Comp || S.StartVrager == 2)
        {
            E.TroefBepalen();
        }
        else
        {
            var v = Snapshot();
            v.TroefVraag = true;
            v.Status = Taal.WelkeTroef;
            S.Troef = _ui.KiesTroef(v);
            E.ZetActWaarden();
        }

        // Statistiek over de verdeling van deze deal.
        for (n = 0; n < 32; n++)
        {
            var k = S.Kaart[n];
            int kant;
            switch (k.DichtIkHy)
            {
                case Pos.HandZuid:
                case Pos.TafelZuid:
                case Pos.DichtZuid: kant = 0; break;
                case Pos.HandNoord:
                case Pos.TafelNoord:
                case Pos.DichtNoord: kant = 1; break;
                default: continue;
            }
            S.Kaartpnt[kant] += k.ActWaarde;
            if (k.Kleur == S.Troef) { S.Troefkrt[kant]++; S.Troefpnt[kant] += k.ActWaarde; }
        }

        for (S.SlagNr = 1; S.SlagNr < 9; S.SlagNr++)
        {
            if (ct.IsCancellationRequested) return;

            S.Tactiek = 0;
            E.Speler1();
            if (!SpeelZet()) { ErrorLegKaart(); break; }
            S.StartVrager = S.Vrager;
            if (S.Tactiek == 41) S.Tactiek41 = true;
            S.Tac[Begrens(S.Tactiek)]++;

            S.Tactiek = 0;
            E.Tegenspeler1();
            if (!SpeelZet()) { ErrorLegKaart(); break; }
            S.Tac[Begrens(S.Tactiek)]++;

            S.Tactiek = 0;
            E.Speler2();
            if (!SpeelZet()) { ErrorLegKaart(); break; }
            S.Tac[Begrens(S.Tactiek)]++;

            S.Tactiek = 0;
            E.Tegenspeler2();
            if (!SpeelZet()) { ErrorLegKaart(); break; }
            S.Tac[Begrens(S.Tactiek)]++;

            var uitslag = E.Evalueer();

            int winnaar = E.WieSlag();
            if (winnaar > 2) winnaar -= 2;
            _melding = SlagMelding(S.SlagNr, winnaar == 1, uitslag);

            if (S.SlagNr == 8)
            {
                _melding += Taal.Scheiding + E.EvalueerSpel();
                _ui.Verder(Snapshot(), _melding);
            }
            else
            {
                _ui.Verder(Snapshot(), _melding);
                _vorigeSlag = HuidigeSlag();
                E.UpdateTafel();
                S.SlagKrtNo = 0;
            }
        }

        S.SlagKrtNo = 0;
    }

    private static int Begrens(int tactiek) => (tactiek >= 0 && tactiek < 80) ? tactiek : 0;

    /// <summary>Regel bovenin: wie won de slag en wat leverde die op.</summary>
    private static string SlagMelding(int slagNr, bool zuidWon, SlagUitslag u)
    {
        string tekst = Taal.SlagVoor(slagNr, zuidWon);
        if (u.Roem > 0) tekst += Taal.MetRoem(u.Roem);
        if (u.LaatsteSlag > 0) tekst += Taal.LaatsteSlag(u.LaatsteSlag, u.Roem > 0);
        return tekst;
    }

    /// <summary>
    /// Legt de zet die de AI koos, of vraagt de mens om er een. Geeft false als
    /// er een onspeelbare kaart uit de tactiek kwam (verzaken door de computer).
    /// </summary>
    private bool SpeelZet()
    {
        if (E.WachtOpMens)
        {
            E.ZetMensKlaar();
            MensKiest();
        }

        if (!E.LegKaart(S.Lkaart, S.Lkleur, S.Vrager)) return false;
        if (E.CheckValid() != null) return false;

        _ui.Toon(Snapshot());
        return true;
    }

    /// <summary>humaan(): vraagt net zolang een kaart tot er een geldige komt.</summary>
    private void MensKiest()
    {
        while (true)
        {
            var v = Snapshot();
            v.WachtOpSpeler = true;
            v.Status = Taal.JouwBeurt;
            v.Melding = _melding;

            var (naam, kleur) = _ui.KiesKaart(v);
            S.Lkaart = naam;
            S.Lkleur = kleur;

            bool found = false;
            int i = 0;
            for (int n = kleur * 8; n < kleur * 8 + 8; n++)
            {
                if (S.Kaart[n].Naam == S.Lkaart) i = S.Kaart[n].DichtIkHy;
                if (S.SlagKrtNo == 0 && (S.Vrager == 1 || S.Vrager == 3))
                {
                    // Bij uitkomen mag je zelf kiezen: uit de hand of van tafel.
                    if (i == Pos.HandZuid || i == Pos.TafelZuid) { found = true; S.Vrager = i; }
                }
                else if (S.Vrager == i) found = true;
            }

            if (found)
            {
                string fout = E.CheckValid();
                if (fout == null) return;
                _melding = fout;
                continue;
            }

            _melding = i switch
            {
                Pos.TafelZuid => Taal.KaartLigtOpTafel,
                Pos.HandZuid => Taal.KaartZitInHand,
                _ => Taal.KaartNietSpeelbaar
            };
        }
    }

    /// <summary>
    /// error_legkaart(): de computer koos een onspeelbare kaart. Het spel stopt
    /// en alle punten gaan naar de tegenpartij.
    /// </summary>
    private void ErrorLegKaart()
    {
        int vrager = S.Vrager;
        if (vrager > 2) vrager -= 2;
        if (vrager < 1 || vrager > 2) vrager = 1;
        int m = (vrager == 1) ? 2 : 1;

        S.PuntenSpel[m - 1] += 152 + S.Roem[vrager - 1] + S.Roem[m - 1];
        S.PuntenSpel[vrager - 1] = 0;
        S.Roem[vrager - 1] = 0;

        S.PuntenTotaalSpel[0] += S.PuntenSpel[0] + S.Roem[0];
        S.PuntenTotaalSpel[1] += S.PuntenSpel[1] + S.Roem[1];
        S.PuntenSpel[0] = S.PuntenSpel[1] = 0;
        S.Roem[0] = S.Roem[1] = 0;
        for (int n = 0; n < 4; n++) { S.Verzaakt[0, n] = 0; S.Verzaakt[1, n] = 0; }

        _ui.Verder(Snapshot(), Taal.ComputerVerzaakte(S.Tactiek, S.Lkleur, S.Lkaart));
    }

    // ------------------------------------------------------------ snapshot

    private List<SlagView> HuidigeSlag()
    {
        var lijst = new List<SlagView>();
        for (int n = 0; n < S.SlagKrtNo && n < 4; n++)
        {
            ref var sk = ref S.Slag(S.SlagNr, n);
            lijst.Add(new SlagView(sk.Kleur, sk.Naam, sk.Speler, sk.Tactiek));
        }
        return lijst;
    }

    /// <summary>Bouwt de momentopname waarop de UI tekent.</summary>
    public SpelView Snapshot()
    {
        var v = new SpelView
        {
            Troef = S.Troef,
            SlagNr = S.SlagNr,
            AanZet = S.Vrager,
            PuntenZuid = S.PuntenSpel[0],
            PuntenNoord = S.PuntenSpel[1],
            RoemZuid = S.Roem[0],
            RoemNoord = S.Roem[1],
            TotaalZuid = S.PuntenTotaalSpel[0],
            TotaalNoord = S.PuntenTotaalSpel[1],
            PartijenZuid = S.Gewonnen[0],
            PartijenNoord = S.Gewonnen[1],
            Slag = HuidigeSlag(),
            VorigeSlag = _vorigeSlag,
            Melding = _melding,
            Statistiek = S.MaakStatistiek(),
        };

        for (int i = 0; i < 4; i++)
        {
            v.OnderZuid[i] = S.TZuid[i] != 0;
            v.OnderNoord[i] = S.TNoord[i] != 0;
        }

        int volg = 0;
        for (int n = 0; n < 32; n++)
        {
            var k = S.Kaart[n];
            var kv = new KaartView
            {
                Index = n,
                Naam = k.Naam,
                Kleur = k.Kleur,
                Open = true,
                Plek = E.TafelPos(n)
            };

            switch (k.DichtIkHy)
            {
                case Pos.HandZuid: kv.Plek = volg++; v.HandZuid.Add(kv); break;
                case Pos.HandNoord: kv.Open = !S.Dicht; v.HandNoord.Add(kv); break;
                case Pos.TafelZuid:
                case Pos.NieuwZuid: v.TafelZuid.Add(kv); break;
                case Pos.TafelNoord:
                case Pos.NieuwNoord: v.TafelNoord.Add(kv); break;
                case Pos.DichtZuid: kv.Open = !S.Dicht; v.DichtZuid.Add(kv); break;
                case Pos.DichtNoord: kv.Open = !S.Dicht; v.DichtNoord.Add(kv); break;
            }
        }

        // Hand van Zuid op kleur en rang sorteren, dat speelt prettiger.
        v.HandZuid.Sort(VergelijkKaart);
        v.TafelZuid.Sort((a, b) => a.Plek.CompareTo(b.Plek));
        v.TafelNoord.Sort((a, b) => a.Plek.CompareTo(b.Plek));

        for (int i = 0; i < v.HandNoord.Count; i++) v.HandNoord[i].Plek = i;
        for (int i = 0; i < v.DichtZuid.Count; i++) v.DichtZuid[i].Plek = i;
        for (int i = 0; i < v.DichtNoord.Count; i++) v.DichtNoord[i].Plek = i;
        for (int i = 0; i < v.HandZuid.Count; i++) v.HandZuid[i].Plek = i;

        return v;
    }

    private int VergelijkKaart(KaartView a, KaartView b)
    {
        if (a.Kleur != b.Kleur)
        {
            // Troef vooraan.
            bool at = a.Kleur == S.Troef, bt = b.Kleur == S.Troef;
            if (at != bt) return at ? -1 : 1;
            return a.Kleur.CompareTo(b.Kleur);
        }
        string rang = a.Kleur == S.Troef ? KjState.RangTroef : KjState.RangNorm;
        return CStr.Pos(rang, a.Naam).CompareTo(CStr.Pos(rang, b.Naam));
    }
}
