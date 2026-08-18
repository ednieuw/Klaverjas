using System.Diagnostics;
using System.Threading;
using Klaverjas.Engine;

namespace Klaverjas.Test;

/// <summary>
/// Laat de engine zonder scherm een groot aantal spellen tegen zichzelf spelen.
/// Controleert onderweg de dingen die bij een vertaling van C naar C# mis
/// kunnen gaan: uitzonderingen, kaarten die twee keer of nooit gespeeld worden,
/// en een puntentelling die niet op 152 uitkomt.
/// </summary>
internal sealed class StilleUi : IKjUi
{
    public int Verzaakt;
    public string LaatsteMelding = "";

    public void Toon(SpelView view) { }
    public void Verder(SpelView view, string tekst)
    {
        LaatsteMelding = tekst;
        if (tekst.StartsWith("Fout:")) Verzaakt++;
    }
    public (char Naam, int Kleur) KiesKaart(SpelView view)
        => throw new InvalidOperationException("In demomodus hoort de mens niet aan zet te komen.");
    public int KiesTroef(SpelView view)
        => throw new InvalidOperationException("In demomodus kiest de computer troef.");
}

/// <summary>
/// Speelt de menselijke kant automatisch: kiest telkens een andere kaart uit de
/// stapel die aan de beurt is, tot de regelcontrole er een goedkeurt. Hiermee
/// loopt de volledige speelloop inclusief MensKiest() en CheckValid().
/// </summary>
internal sealed class AutoMensUi : IKjUi
{
    private readonly Random _rnd;
    private int _poging;
    public int Spellen;
    public int Afwijzingen;
    public int MaxPogingen;
    public string LaatsteMelding = "";

    public AutoMensUi(int seed) => _rnd = new Random(seed);

    public int DekkingFout;
    public string DekkingVoorbeeld = "";

    /// <summary>
    /// Controleert dat het aantal plekken dat als "nog gedekt" getekend wordt
    /// gelijk is aan het aantal dichte kaarten dat er werkelijk nog ligt, en dat
    /// een gedekte plek ook echt een open kaart heeft.
    /// </summary>
    private void ControleerDekking(SpelView v)
    {
        int zuid = v.OnderZuid.Count(b => b);
        int noord = v.OnderNoord.Count(b => b);
        if (zuid != v.DichtZuid.Count || noord != v.DichtNoord.Count)
        {
            DekkingFout++;
            if (DekkingVoorbeeld == "")
                DekkingVoorbeeld = $"slag {v.SlagNr}: gedekte plekken Z/N = {zuid}/{noord}, " +
                                   $"dichte kaarten Z/N = {v.DichtZuid.Count}/{v.DichtNoord.Count}";
            return;
        }
        foreach (var (open, gedekt, kant) in new[]
                 { (v.TafelZuid, v.OnderZuid, "Zuid"), (v.TafelNoord, v.OnderNoord, "Noord") })
            for (int i = 0; i < 4; i++)
                if (gedekt[i] && !open.Any(k => k.Plek == i))
                {
                    DekkingFout++;
                    if (DekkingVoorbeeld == "")
                        DekkingVoorbeeld = $"slag {v.SlagNr}: {kant} plek {i} gedekt maar zonder open kaart";
                    return;
                }
    }

    public void Toon(SpelView view) => ControleerDekking(view);

    public readonly List<string> RoemMeldingen = new();

    public void Verder(SpelView view, string tekst)
    {
        LaatsteMelding = tekst;
        // Taalonafhankelijk herkennen: de meldingen bestaan in het Nederlands
        // en het Engels.
        if (tekst.Contains("roem") || tekst.Contains("meld") ||
            tekst.Contains("laatste slag") || tekst.Contains("last trick"))
            if (RoemMeldingen.Count < 12) RoemMeldingen.Add(tekst);
        if (tekst.Contains("wint dit spel") || tekst.Contains("wins this deal") ||
            tekst.StartsWith("Fout:") || tekst.StartsWith("Error:")) Spellen++;
        _poging = 0;
    }

    public int KiesTroef(SpelView view) => _rnd.Next(4);

    public (char Naam, int Kleur) KiesKaart(SpelView view)
    {
        var kandidaten = new List<KaartView>();
        if (view.Slag.Count == 0) { kandidaten.AddRange(view.HandZuid); kandidaten.AddRange(view.TafelZuid); }
        else if (view.AanZet == Pos.HandZuid) kandidaten.AddRange(view.HandZuid);
        else if (view.AanZet == Pos.TafelZuid) kandidaten.AddRange(view.TafelZuid);
        else { kandidaten.AddRange(view.HandZuid); kandidaten.AddRange(view.TafelZuid); }

        if (kandidaten.Count == 0)
            throw new InvalidOperationException($"Geen kaart om te spelen (aan zet: {view.AanZet}, slag {view.SlagNr}).");

        if (_poging > 0) Afwijzingen++;
        if (_poging > MaxPogingen) MaxPogingen = _poging;
        if (_poging > 200)
            throw new InvalidOperationException(
                $"Geen enkele kaart werd goedgekeurd (slag {view.SlagNr}, aan zet {view.AanZet}, laatste reden: {view.Melding}).");

        var k = kandidaten[_poging % kandidaten.Count];
        _poging++;
        return (k.Naam, k.Kleur);
    }
}

internal static class Program
{
    private static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "mens") return MensTest(args);
        if (args.Length > 0 && args[0] == "spoor") return Spoor(args);
        if (args.Length > 0 && args[0] == "toernooi") return Toernooi(args);

        int spellen = args.Length > 0 && int.TryParse(args[0], out var a) ? a : 2000;
        int seed = args.Length > 1 && int.TryParse(args[1], out var b) ? b : 12345;

        Console.WriteLine($"Klaverjas engine-test: {spellen} spellen, seed {seed}");

        var ui = new StilleUi();
        var spel = new KjSpel(ui, seed);
        spel.E.S.Comp = true;      // computer speelt beide kanten
        spel.E.S.Dicht = false;

        var s = spel.E.S;
        int gespeeld = 0, fouten = 0;
        int puntenFout = 0, kaartFout = 0;
        long totaalPunten = 0;
        var tactieken = new int[80];
        var klok = Stopwatch.StartNew();

        // De speelloop van KjSpel draait oneindig door; hier per spel aangestuurd
        // via reflectie op de publieke onderdelen zou omslachtig zijn, dus we
        // gebruiken een eigen loop met dezelfde stappen.
        var driver = new Driver(spel, ui);

        for (int i = 0; i < spellen; i++)
        {
            try
            {
                driver.SpeelEenSpel();
                gespeeld++;

                int punten = driver.PuntenZuid + driver.PuntenNoord;
                if (punten != 152) { puntenFout++; if (puntenFout <= 5) Console.WriteLine($"  spel {i}: kaartpunten {punten} in plaats van 152"); }
                totaalPunten += punten;

                // Elke kant speelt per slag een handkaart en een tafelkaart, dus
                // na acht slagen horen alle 32 kaarten gespeeld te zijn.
                int nietGespeeld = 0;
                for (int n = 0; n < 32; n++)
                    if (s.Kaart[n].DichtIkHy != Pos.Gespeeld) nietGespeeld++;
                if (nietGespeeld != 0) { kaartFout++; if (kaartFout <= 5) Console.WriteLine($"  spel {i}: {nietGespeeld} kaarten niet gespeeld"); }

                for (int t = 0; t < 80; t++) tactieken[t] = (int)s.Tac[t];
            }
            catch (Exception ex)
            {
                fouten++;
                if (fouten <= 3) Console.WriteLine($"  spel {i}: {ex.GetType().Name}: {ex.Message}\n{ex.StackTrace?.Split('\n')[0]}");
            }
        }
        klok.Stop();

        Console.WriteLine();
        Console.WriteLine($"Gespeeld            : {gespeeld}/{spellen}");
        Console.WriteLine($"Uitzonderingen      : {fouten}");
        Console.WriteLine($"Computer verzaakte  : {ui.Verzaakt}");
        Console.WriteLine($"Puntensom != 152    : {puntenFout}");
        Console.WriteLine($"Kaartentelling fout : {kaartFout}");
        Console.WriteLine($"Gem. kaartpunten    : {(gespeeld > 0 ? totaalPunten / (double)gespeeld : 0):F1}");
        Console.WriteLine($"Partijen Zuid/Noord : {s.Gewonnen[0]} / {s.Gewonnen[1]}");
        Console.WriteLine($"Spellen  Zuid/Noord : {s.GewonnenTot[0]} / {s.GewonnenTot[1]}");
        Console.WriteLine($"Roem     Zuid/Noord : {s.Roempnt[0]} / {s.Roempnt[1]}");
        Console.WriteLine($"Pit      Zuid/Noord : {s.Pit[0]} / {s.Pit[1]}");
        Console.WriteLine($"Nat      Zuid/Noord : {s.Nat[0]} / {s.Nat[1]}");
        Console.WriteLine($"Superroem           : {s.Superroem}");
        Console.WriteLine($"Tijd                : {klok.ElapsedMilliseconds} ms " +
                          $"({(gespeeld > 0 ? klok.Elapsed.TotalMilliseconds / gespeeld : 0):F2} ms/spel)");

        Console.WriteLine();
        Console.WriteLine("Meest gebruikte tactieken:");
        var top = Enumerable.Range(0, 80).Where(t => tactieken[t] > 0)
                            .OrderByDescending(t => tactieken[t]).Take(12);
        foreach (var t in top) Console.WriteLine($"  tactiek {t,2} : {tactieken[t]}");

        bool ok = fouten == 0 && puntenFout == 0 && kaartFout == 0;
        Console.WriteLine();
        Console.WriteLine(ok ? "RESULTAAT: geen afwijkingen gevonden." : "RESULTAAT: er zijn afwijkingen, zie hierboven.");
        return ok ? 0 : 1;
    }

    /// <summary>
    /// Laat de tactiek van Ed en de zoekende speler van Loggen zonder scherm
    /// tegen elkaar spelen. Elk spel wordt twee keer gespeeld met dezelfde
    /// kaarten, één keer met elk van beiden als Zuid, zodat een gelukkige
    /// verdeling niet meetelt en het verschil echt aan de speelwijze ligt.
    /// </summary>
    private static int Toernooi(string[] args)
    {
        int spellen = args.Length > 1 && int.TryParse(args[1], out var a) ? a : 500;
        int zaad = args.Length > 2 && int.TryParse(args[2], out var b) ? b : 1;

        Console.WriteLine($"Ed (vuistregels) tegen Loggen (zoekend): {spellen} spellen, elk twee keer gespeeld");
        Console.WriteLine();

        long[] punten = new long[2];      // 0 = Ed, 1 = Loggen
        long[] gewonnen = new long[2];
        long[] roem = new long[2];
        long[] nat = new long[2];
        long[] pit = new long[2];
        var klok = Stopwatch.StartNew();
        int gespeeld = 0, fouten = 0, verzaakt = 0;

        for (int ronde = 0; ronde < 2; ronde++)
        {
            // ronde 0: Ed is Zuid. ronde 1: Loggen is Zuid, zelfde kaarten.
            bool edIsZuid = ronde == 0;
            var spel = new KjSpel(new StilleUi(), zaad);
            var S = spel.E.S;
            var E = spel.E;
            S.Comp = true;
            S.Zoekt[0] = !edIsZuid;       // Zuid
            S.Zoekt[1] = edIsZuid;        // Noord

            var wacht = new StilleUi();
            var driver = new Driver(spel, wacht);
            for (int i = 0; i < spellen; i++)
            {
                long gwZ = S.GewonnenTot[0], gwN = S.GewonnenTot[1];
                long ntZ = S.Nat[0], ntN = S.Nat[1];
                long ptZ = S.Pit[0], ptN = S.Pit[1];
                driver.RoemZuid = driver.RoemNoord = 0;
                try
                {
                    driver.SpeelEenSpel();
                    gespeeld++;
                }
                catch (Exception ex)
                {
                    fouten++;
                    if (fouten <= 2)
                    {
                        Console.WriteLine($"  spel {i}: {ex.GetType().Name}: {ex.Message}");
                        foreach (var r in (ex.StackTrace ?? "").Split('\n').Take(5)) Console.WriteLine("     " + r.Trim());
                    }
                    continue;
                }
                // Zuid is index 0 als Ed Zuid speelt, anders is Loggen dat.
                verzaakt = wacht.Verzaakt;
                int ed = edIsZuid ? 0 : 1;
                int lo = edIsZuid ? 1 : 0;
                int[] kaartpnt = { driver.PuntenZuid, driver.PuntenNoord };
                int[] roempnt = { driver.RoemZuid, driver.RoemNoord };
                punten[0] += kaartpnt[ed] + roempnt[ed];
                punten[1] += kaartpnt[lo] + roempnt[lo];
                roem[0] += roempnt[ed];
                roem[1] += roempnt[lo];
                gewonnen[0] += (ed == 0 ? S.GewonnenTot[0] - gwZ : S.GewonnenTot[1] - gwN);
                gewonnen[1] += (lo == 0 ? S.GewonnenTot[0] - gwZ : S.GewonnenTot[1] - gwN);
                nat[0] += (ed == 0 ? S.Nat[0] - ntZ : S.Nat[1] - ntN);
                nat[1] += (lo == 0 ? S.Nat[0] - ntZ : S.Nat[1] - ntN);
                pit[0] += (ed == 0 ? S.Pit[0] - ptZ : S.Pit[1] - ptN);
                pit[1] += (lo == 0 ? S.Pit[0] - ptZ : S.Pit[1] - ptN);
            }
        }
        klok.Stop();

        string Rij(string kop, long e, long l)
            => $"{kop,-22}{e,10}{l,10}";

        Console.WriteLine($"{"",-22}{"Ed",10}{"Loggen",10}");
        Console.WriteLine(new string('-', 42));
        Console.WriteLine(Rij("Spellen gewonnen", gewonnen[0], gewonnen[1]));
        Console.WriteLine(Rij("Punten totaal", punten[0], punten[1]));
        Console.WriteLine(Rij("Waarvan roem", roem[0], roem[1]));
        Console.WriteLine(Rij("Nat gegaan", nat[0], nat[1]));
        Console.WriteLine(Rij("Pit gehaald", pit[0], pit[1]));
        Console.WriteLine();

        long tot = punten[0] + punten[1];
        if (tot > 0)
            Console.WriteLine($"Puntenaandeel      : Ed {100.0 * punten[0] / tot:F1}%   Loggen {100.0 * punten[1] / tot:F1}%");
        long totG = gewonnen[0] + gewonnen[1];
        if (totG > 0)
            Console.WriteLine($"Spellen gewonnen   : Ed {100.0 * gewonnen[0] / totG:F1}%   Loggen {100.0 * gewonnen[1] / totG:F1}%");
        Console.WriteLine($"Gespeeld           : {gespeeld} spellen ({fouten} fout), {klok.ElapsedMilliseconds} ms");
        Console.WriteLine($"Afgebroken (verzaakt): {verzaakt}");
        return fouten == 0 && verzaakt == 0 ? 0 : 1;
    }

    /// <summary>
    /// Schrijft een spoor van een vast aantal spellen weg: per gespeelde kaart
    /// één regel, per spel een afsluitregel met de stand. De Swift-versie moet
    /// bij hetzelfde startgetal exact hetzelfde bestand opleveren; verschilt er
    /// iets, dan wijst de eerste afwijkende regel de slag en de kaart aan.
    ///
    /// Regelvorm:  spel;slag;volgnr;speler;kleur;kaart;tactiek
    /// Afsluiting: spel;=;troef;puntenZuid;puntenNoord;roemZuid;roemNoord
    /// </summary>
    private static int Spoor(string[] args)
    {
        int spellen = args.Length > 1 && int.TryParse(args[1], out var a) ? a : 200;
        int zaad = args.Length > 2 && int.TryParse(args[2], out var b) ? b : 1;
        string pad = args.Length > 3 ? args[3] : "spoor-csharp.txt";

        var spel = new KjSpel(new StilleUi(), zaad);
        spel.E.S.Comp = true;          // computer speelt beide kanten: geen invoer nodig
        var S = spel.E.S;
        var E = spel.E;

        using (var uit = new StreamWriter(pad))
        {
        uit.WriteLine($"# klaverjas spoor; spellen={spellen}; zaad={zaad}");

        S.Speler = S.Random(2) + 1;

        for (int nr = 1; nr <= spellen; nr++)
        {
            S.Troef = 999;
            S.SlagNr = 0;
            S.SlagKrtNo = 0;
            E.Delen();
            S.Speler = 1 - (S.Speler - 1) + 1;
            S.Vrager = S.StartVrager = S.Speler;
            for (int n = 0; n < 4; n++) { S.TNoord[n] = 1; S.TZuid[n] = 1; }
            E.KaartenVrij();
            E.ZetTafelPosities();
            E.Vulhanden();
            S.SlagNr = 0;
            E.TroefBepalen();

            for (S.SlagNr = 1; S.SlagNr < 9; S.SlagNr++)
            {
                foreach (var beurt in new Action[] { E.Speler1, E.Tegenspeler1, E.Speler2, E.Tegenspeler2 })
                {
                    S.Tactiek = 0;
                    beurt();
                    int volgnr = S.SlagKrtNo;
                    int speler = S.Vrager;
                    int kleur = S.Lkleur;
                    char kaart = S.Lkaart;
                    int tactiek = S.Tactiek;

                    if (!E.LegKaart(kaart, kleur, S.Vrager) || E.CheckValid() != null)
                    {
                        uit.WriteLine($"{nr};{S.SlagNr};{volgnr};{speler};{kleur};{kaart};!verzaakt");
                        goto volgendSpel;
                    }
                    uit.WriteLine($"{nr};{S.SlagNr};{volgnr};{speler};{kleur};{kaart};{tactiek}");
                    if (volgnr == 0) S.StartVrager = S.Vrager;
                    if (volgnr == 0 && S.Tactiek == 41) S.Tactiek41 = true;
                }

                E.Evalueer();
                if (S.SlagNr == 8) { }
                else { E.UpdateTafel(); S.SlagKrtNo = 0; }
            }

            uit.WriteLine($"{nr};=;{S.Troef};{S.PuntenSpel[0]};{S.PuntenSpel[1]};{S.Roem[0]};{S.Roem[1]}");
            E.EvalueerSpel();

        volgendSpel:
            S.SlagKrtNo = 0;
        }
        }

        var regels = File.ReadAllLines(pad);
        Console.WriteLine($"Spoor geschreven: {pad}");
        Console.WriteLine($"  {regels.Length} regels, {spellen} spellen, zaad {zaad}");
        Console.WriteLine();
        Console.WriteLine("Eerste regels ter controle:");
        foreach (var r in regels.Take(6)) Console.WriteLine("  " + r);
        return 0;
    }

    /// <summary>
    /// Laat KjSpel.Loop draaien zoals de echte applicatie dat doet, met een
    /// automatische speler aan de Zuid-kant.
    /// </summary>
    private static int MensTest(string[] args)
    {
        int spellen = args.Length > 1 && int.TryParse(args[1], out var a) ? a : 200;
        int seed = args.Length > 2 && int.TryParse(args[2], out var b) ? b : 4242;
        Taal.Engels = args.Any(x => x.Equals("en", StringComparison.OrdinalIgnoreCase));

        Console.WriteLine($"Klaverjas mens-test: {spellen} spellen met een automatische speler, seed {seed}");

        var ui = new AutoMensUi(seed);
        var spel = new KjSpel(ui, seed);
        spel.E.S.Comp = false;      // Zuid wordt door de UI gespeeld
        spel.E.S.Dicht = true;

        using var cts = new CancellationTokenSource();
        Exception fout = null;

        var draad = new Thread(() =>
        {
            try { spel.Loop(cts.Token); }
            catch (OperationCanceledException) { }
            catch (Exception ex) { fout = ex; }
        })
        { IsBackground = true };

        var klok = Stopwatch.StartNew();
        draad.Start();

        while (ui.Spellen < spellen && fout == null && klok.Elapsed < TimeSpan.FromMinutes(3))
            Thread.Sleep(20);

        cts.Cancel();
        draad.Join(2000);
        klok.Stop();

        var s = spel.E.S;
        Console.WriteLine();
        Console.WriteLine($"Gespeeld            : {ui.Spellen}");
        Console.WriteLine($"Afgewezen zetten    : {ui.Afwijzingen} (max {ui.MaxPogingen} pogingen voor 1 kaart)");
        Console.WriteLine($"Dekking tafelkaarten: {(ui.DekkingFout == 0 ? "klopt" : $"{ui.DekkingFout} afwijkingen - {ui.DekkingVoorbeeld}")}");
        Console.WriteLine($"Spellen  Zuid/Noord : {s.GewonnenTot[0]} / {s.GewonnenTot[1]}");
        Console.WriteLine($"Roem     Zuid/Noord : {s.Roempnt[0]} / {s.Roempnt[1]}");
        Console.WriteLine($"Laatste melding     : {ui.LaatsteMelding}");
        Console.WriteLine();
        Console.WriteLine("Voorbeelden van meldingen met roem:");
        foreach (var m in ui.RoemMeldingen) Console.WriteLine("  " + m);
        Console.WriteLine($"Tijd                : {klok.ElapsedMilliseconds} ms");

        if (fout != null)
        {
            Console.WriteLine();
            Console.WriteLine("FOUT in de speelloop:");
            Console.WriteLine(fout);
            return 1;
        }

        bool ok = ui.Spellen >= spellen;
        Console.WriteLine();
        Console.WriteLine(ok ? "RESULTAAT: speelloop met menselijke speler is stabiel."
                             : "RESULTAAT: de speelloop liep vast voordat alle spellen gespeeld waren.");
        return ok ? 0 : 1;
    }
}

/// <summary>
/// Speelt precies één spel, met dezelfde stappen als KjSpel.Loop maar zonder
/// oneindige lus, zodat de test er per spel tussen kan kijken.
/// </summary>
internal sealed class Driver
{
    private readonly KjSpel _spel;
    private readonly StilleUi _ui;
    private KjEngine E => _spel.E;
    private KjState S => _spel.E.S;

    public int PuntenZuid, PuntenNoord;
    public int RoemZuid, RoemNoord;

    public Driver(KjSpel spel, StilleUi ui)
    {
        _spel = spel;
        _ui = ui;
        S.Speler = S.Random(2) + 1;
    }

    public void SpeelEenSpel()
    {
        S.Troef = 999;
        S.SlagNr = 0;
        S.SlagKrtNo = 0;

        E.Delen();
        S.Speler = 1 - (S.Speler - 1) + 1;
        S.Vrager = S.StartVrager = S.Speler;
        for (int n = 0; n < 4; n++) { S.TNoord[n] = 1; S.TZuid[n] = 1; }

        E.KaartenVrij();
        E.ZetTafelPosities();
        E.Vulhanden();
        S.SlagNr = 0;
        E.TroefBepalen();

        PuntenZuid = PuntenNoord = 0;

        for (S.SlagNr = 1; S.SlagNr < 9; S.SlagNr++)
        {
            S.Tactiek = 0; E.Speler1();
            if (!Leg()) { Verzaak(); return; }
            S.StartVrager = S.Vrager;
            if (S.Tactiek == 41) S.Tactiek41 = true;
            S.Tac[Grens(S.Tactiek)]++;

            S.Tactiek = 0; E.Tegenspeler1();
            if (!Leg()) { Verzaak(); return; }
            S.Tac[Grens(S.Tactiek)]++;

            S.Tactiek = 0; E.Speler2();
            if (!Leg()) { Verzaak(); return; }
            S.Tac[Grens(S.Tactiek)]++;

            S.Tactiek = 0; E.Tegenspeler2();
            if (!Leg()) { Verzaak(); return; }
            S.Tac[Grens(S.Tactiek)]++;

            for (int n = 0; n < 4; n++)
            {
                ref var sk = ref S.Slag(S.SlagNr, n);
                if (WinnaarKant() == 1) PuntenZuid += sk.Waarde; else PuntenNoord += sk.Waarde;
            }

            E.Evalueer();

            if (S.SlagNr == 8)
            {
                // Vastleggen vóór EvalueerSpel(), want die zet de tellers op nul.
                RoemZuid = S.Roem[0];
                RoemNoord = S.Roem[1];
                E.EvalueerSpel();
            }
            else { E.UpdateTafel(); S.SlagKrtNo = 0; }
        }
    }

    private int WinnaarKant()
    {
        int w = E.WieSlag();
        return w > 2 ? w - 2 : w;
    }

    private static int Grens(int t) => (t >= 0 && t < 80) ? t : 0;

    private bool Leg()
    {
        if (E.WachtOpMens) throw new InvalidOperationException("Engine vroeg om een menselijke zet in demomodus.");
        if (!E.LegKaart(S.Lkaart, S.Lkleur, S.Vrager)) return false;
        return E.CheckValid() == null;
    }

    private void Verzaak() => _ui.Verder(_spel.Snapshot(), "Fout: verzaakt");
}
