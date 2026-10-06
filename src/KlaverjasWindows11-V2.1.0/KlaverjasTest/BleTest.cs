using System.Text;
using System.Text.Json;
using Klaverjas.Ble;
using Klaverjas.Engine;

namespace Klaverjas.Test;

/// <summary>
/// Toetst de Ble-laag zonder bluetooth en zonder de Mac nodig te hebben,
/// precies zoals BLUETOOTH-VOOR-WINDOWS.md voorschrijft in "Hoe te toetsen,
/// zonder en met hardware", stap 1 t/m 3:
///
/// 1. de drie kant-en-klare voorbeelden uit dat document teruglezen tot exact
///    de getoonde JSON (de coderingsproef);
/// 2. een regel in willekeurige stukken knippen en weer aan elkaar plakken
///    (de regelbuffer-proef);
/// 3. een eigen ZET coderen en meteen weer terugdecoderen (lus-proef zonder
///    radio).
///
/// Draaien met: dotnet run --project KlaverjasTest -- ble
/// </summary>
internal static class BleTest
{
    private static int _fouten;

    public static int Uitvoeren()
    {
        _fouten = 0;

        Console.WriteLine("Ble-laag toetsen (geen bluetooth, geen Mac nodig)");
        Console.WriteLine();

        ToetsVoorbeeldTroef();
        ToetsVoorbeeldKaart();
        ToetsVoorbeeldStand();
        ToetsVoorbeeldLegeStat();
        ToetsEigenZetRondje();
        ToetsRegelBuffer();
        ToetsDuoBericht();
        ToetsGastWeergave();
        ToetsGastheerStand();
        ToetsDecodeerZet();

        Console.WriteLine();
        Console.WriteLine(_fouten == 0
            ? "RESULTAAT: geen afwijkingen gevonden."
            : $"RESULTAAT: {_fouten} afwijking(en) gevonden, zie hierboven.");
        return _fouten == 0 ? 0 : 1;
    }

    private static void Controleer(bool ok, string omschrijving)
    {
        Console.WriteLine((ok ? "  OK   " : "  FOUT ") + omschrijving);
        if (!ok) _fouten++;
    }

    // ---------------------------------------------------- coderingsproef

    /// <summary>Troefkeuze (GastZet(troef: 3), harten) uit BLUETOOTH-VOOR-WINDOWS.md.</summary>
    private static void ToetsVoorbeeldTroef()
    {
        Console.WriteLine("Voorbeeld 1: troefkeuze");
        const string base64 = "q1YqKcpPTVOyMq4FAA==";
        string json = DuoStand.Decomprimeer(base64);
        Controleer(json == "{\"troef\":3}", $"json na decoderen is {{\"troef\":3}} (was: {json})");
    }

    /// <summary>Kaartkeuze (GastZet(kaart: Teken(raw: 84), kleur: 3), tien harten).</summary>
    private static void ToetsVoorbeeldKaart()
    {
        Console.WriteLine("Voorbeeld 2: kaartkeuze");
        const string base64 = "q1bKzkktLVKyMtZRyk5MLCpRsqpWKkosV7KyMKmtBQA=";
        string json = DuoStand.Decomprimeer(base64);
        Controleer(json == "{\"kleur\":3,\"kaart\":{\"raw\":84}}",
            $"json na decoderen is {{\"kleur\":3,\"kaart\":{{\"raw\":84}}}} (was: {json})");
    }

    /// <summary>Volledige stand: troef harten, Zuid 20 punten en 20 roem, twee kaarten in handZuid.</summary>
    private static void ToetsVoorbeeldStand()
    {
        Console.WriteLine("Voorbeeld 3: volledige stand");
        const string base64 =
            "zVPLTsMwEPyVaM8+JIUilF9AKocKDq04LGRb3DhO5DiAqPrv7NqmDhXcUaWo3sfszD6O4HuPaFZ97xqoSwWNfnn16bl9UoBoN+ShXigYDe6jsdMHe4eWzZUCjzsys4zRo9ej19RCfQTvetq1iM6TZX+pSgkZyJjZm2O6YbLzEIv+/D9yzNnTQE5ScgC+xHry/s8/5hp6cSF2YJM+zA16pl46eJHgaU82B51iCzeT5hksypQD9ZWCV7RNtG+PoG1DH2HMFrGT8Th8h/pmyQCtocmFlH6QSt5NxESMtLUUt26fmTrUOzQjndQZrbpAu73OaNVvaNUcTRyntAJ5C2VBHkReKKbgs6dWxMZn+J73Iqqrlou0vEkt+996p/e0Pq/tO7L7flgzOLlvTj2rcClnBq9+lpI2znY89PfRoSAnirL20wg1bPg4imeW7yFPNksL55I5xsHmyQU535X+5iO3uHLhLDsyjbZMBERpURVvnF0IoioWZZE2J3HusKU4l2hPlaoyU039PH0B";

        SpelStandGast stand = DuoStand.DecodeerStand(base64);

        Controleer(stand.Troef == 3, $"troef is 3 (harten) (was: {stand.Troef})");
        Controleer(stand.PuntenZuid == 20, $"puntenZuid is 20 (was: {stand.PuntenZuid})");
        Controleer(stand.RoemZuid == 20, $"roemZuid is 20 (was: {stand.RoemZuid})");
        Controleer(stand.HandZuid.Count == 2, $"handZuid heeft 2 kaarten (was: {stand.HandZuid.Count})");
    }

    /// <summary>
    /// Kant-en-klare, gecomprimeerde lege Statistiek uit
    /// BLUETOOTH-VOOR-WINDOWS2.1.0.md, "STAT: score per partner" — dit is
    /// exact het blok dat <c>GastRadio</c> als minimale, correcte deelname
    /// verstuurt zolang Windows zelf nog geen score per partner bijhoudt.
    /// Swift's Codable schrijft bij het coderen alle velden altijd voluit
    /// (in tegenstelling tot het decoderen, waar een ontbrekende sleutel de
    /// standaardwaarde krijgt) — de JSON hieronder is dus geen kaal
    /// <c>{}</c>, maar wel overal nullen/lege lijsten.
    /// </summary>
    private static void ToetsVoorbeeldLegeStat()
    {
        Console.WriteLine("Voorbeeld 4: lege STAT (score per partner)");
        const string base64 =
            "q1YqLi1ILSrKT81Vsoo20DGI1VEqyS9JTMyBc0FyBaV5Jal5cKGCzBI4Oy8RwS5JTC7JTM2G8AczBLo1OzGxqATNXyVAv6ahiRUXpObkIKtJTU/NQw6AAqA5mVnopoCNhwvWAgA=";
        string json = DuoStand.Decomprimeer(base64);
        using var doc = JsonDocument.Parse(json);
        bool ok = doc.RootElement.GetProperty("spellen").EnumerateArray().All(v => v.GetInt32() == 0)
               && doc.RootElement.GetProperty("partijen").EnumerateArray().All(v => v.GetInt32() == 0);
        Controleer(ok, $"json na decoderen bevat alleen nullen (spellen/partijen op [0,0]) (was: {json})");
    }

    // -------------------------------------------------- eigen zet coderen

    /// <summary>
    /// Codeert zelf een GastZet en decodeert hem meteen weer terug: de
    /// lus-proef uit stap 3, zonder radio. Er is geen byte-voor-byte
    /// verwachting op de base64: DEFLATE is niet deterministisch tussen
    /// implementaties, dus de test controleert de inhoud, niet de bytes.
    /// </summary>
    private static void ToetsEigenZetRondje()
    {
        Console.WriteLine("Eigen ZET coderen en teruglezen");

        string base64Troef = DuoStand.CodeerZet(GastZet.VoorTroef(3));
        string jsonTroef = DuoStand.Decomprimeer(base64Troef);
        Controleer(jsonTroef == "{\"troef\":3}",
            $"eigen troefkeuze codeert tot {{\"troef\":3}} (was: {jsonTroef})");

        string base64Kaart = DuoStand.CodeerZet(GastZet.VoorKaart('T', 3));
        string jsonKaart = DuoStand.Decomprimeer(base64Kaart);
        using var doc = JsonDocument.Parse(jsonKaart);
        bool kaartOk = doc.RootElement.GetProperty("kaart").GetProperty("raw").GetByte() == 84
                    && doc.RootElement.GetProperty("kleur").GetInt32() == 3
                    && !doc.RootElement.TryGetProperty("troef", out _);
        Controleer(kaartOk, $"eigen kaartkeuze codeert tot kaart.raw=84, kleur=3, geen troef-sleutel (was: {jsonKaart})");

        string base64Verder = DuoStand.CodeerZet(GastZet.VoorVerder());
        string jsonVerder = DuoStand.Decomprimeer(base64Verder);
        Controleer(jsonVerder == "{\"verder\":true}",
            $"eigen \"verder\"-tik codeert tot {{\"verder\":true}} (was: {jsonVerder})");
    }

    // --------------------------------------------------------- regelbuffer

    /// <summary>
    /// Eén regel in willekeurige stukken knippen — ook als een \n toevallig op
    /// een stukgrens valt — en controleren dat er precies de oorspronkelijke
    /// regel(s) uitkomen. Nooit de aanname dat één pakketje één regel is.
    /// </summary>
    private static void ToetsRegelBuffer()
    {
        Console.WriteLine("Regelbuffer: opknippen en weer aan elkaar plakken");

        string regel = "STAND " + new string('x', 700); // ongeveer zo lang als een echte STAND

        foreach (int pakketGrootte in new[] { 1, 3, 7, 20, 1000 })
        {
            var pakketten = RegelSplitser.SplitsVoorVerzending(regel, pakketGrootte);
            var buffer = new RegelBuffer();
            var ontvangen = new List<string>();
            foreach (var pakket in pakketten) ontvangen.AddRange(buffer.VoegToe(pakket));

            bool ok = ontvangen.Count == 1 && ontvangen[0] == regel;
            Controleer(ok, $"pakketgrootte {pakketGrootte}: regel van {regel.Length} tekens komt heel terug" +
                           (ok ? "" : $" (kreeg {ontvangen.Count} regel(s))"));
        }

        // Twee regels na elkaar, geknipt zonder rekening te houden met waar de
        // regelgrens ligt: de \n van de eerste regel kan midden in een pakketje
        // vallen.
        string regelA = "KJ 3 2.1.0 MacBook Pro";
        string regelB = "JA 3";
        byte[] samen = Encoding.UTF8.GetBytes(regelA + "\n" + regelB + "\n");
        var buf2 = new RegelBuffer();
        var uitkomst = new List<string>();
        const int stukGrootte = 5;
        for (int i = 0; i < samen.Length; i += stukGrootte)
        {
            int lengte = Math.Min(stukGrootte, samen.Length - i);
            var stuk = new byte[lengte];
            Array.Copy(samen, i, stuk, 0, lengte);
            uitkomst.AddRange(buf2.VoegToe(stuk));
        }
        bool tweeRegelsOk = uitkomst.Count == 2 && uitkomst[0] == regelA && uitkomst[1] == regelB;
        Controleer(tweeRegelsOk, "twee regels na elkaar, geknipt zonder op regelgrenzen te letten, komen apart en compleet terug" +
                                 (tweeRegelsOk ? "" : $" (kreeg: {string.Join(" | ", uitkomst)})"));
    }

    // ----------------------------------------------------------- DuoBericht

    private static void ToetsDuoBericht()
    {
        Console.WriteLine("DuoBericht: opbouwen en ontleden");

        RondjeBericht(DuoBericht.Kj(3, "2.1.0", "MacBook Pro"), "KJ 3 2.1.0 MacBook Pro");
        RondjeBericht(DuoBericht.Stat("q1Yq=="), "STAT q1Yq==");
        RondjeBericht(DuoBericht.Ja(3), "JA 3");
        RondjeBericht(DuoBericht.Stand("abcd=="), "STAND abcd==");
        RondjeBericht(DuoBericht.Zet("efgh=="), "ZET efgh==");
        RondjeBericht(DuoBericht.Pols(), "P");

        Controleer(DuoBericht.Ontleed("ONBEKEND iets") == null, "een onherkende regel geeft null terug");
    }

    // ----------------------------------------------------------- GastWeergave

    /// <summary>
    /// De gast is altijd Noord: zijn eigen kant moet als "Zuid" getekend
    /// worden (onderin), en Pos-codes in aanZet/slag moeten mee omdraaien.
    /// </summary>
    private static void ToetsGastWeergave()
    {
        Console.WriteLine("GastWeergave: Zuid/Noord omdraaien voor de gast");

        var stand = new SpelStandGast
        {
            MijnKant = 2, // de gast is altijd Noord
            AanZet = Pos.HandNoord, // de gast zelf is aan zet
            HandZuid = new List<KaartViewGast> { new() { Naam = 'X', Kleur = 0 } }, // van de tegenstander
            HandNoord = new List<KaartViewGast> { new() { Naam = 'Y', Kleur = 1 } }, // van de gast zelf
            PuntenZuid = 5,
            PuntenNoord = 7,
            Slag = new List<SlagViewGast> { new() { Kleur = 0, Naam = 'A', Speler = Pos.TafelZuid } },
        };

        Controleer(GastWeergave.BenIkAanZet(stand),
            "de gast is aan zet als aanZet == handNoord en mijnKant == 2");

        var v = GastWeergave.NaarSpelView(stand);
        Controleer(v.AanZet == Pos.HandZuid, $"aanZet wordt na omdraaien HandZuid (was: {v.AanZet})");
        Controleer(v.HandZuid.Count == 1 && v.HandZuid[0].Naam == 'Y',
            "de eigen hand van de gast (was handNoord) komt in HandZuid te staan");
        Controleer(v.HandNoord.Count == 1 && v.HandNoord[0].Naam == 'X',
            "de hand van de tegenstander (was handZuid) komt in HandNoord te staan");
        Controleer(v.PuntenZuid == 7 && v.PuntenNoord == 5,
            $"punten draaien mee om (PuntenZuid={v.PuntenZuid}, PuntenNoord={v.PuntenNoord})");
        Controleer(v.Slag.Count == 1 && v.Slag[0].Speler == Pos.TafelNoord,
            $"een slagkaart van tafelZuid komt na omdraaien op TafelNoord terecht (was: {(v.Slag.Count == 1 ? v.Slag[0].Speler : -1)})");
    }

    // ------------------------------------------------- gastheer (openstellen)

    /// <summary>
    /// Het spiegelbeeld van <see cref="ToetsGastWeergave"/>: dit toetst
    /// <c>SpelStandGast.VanSpelView</c> (de kant die <c>GastheerRadio</c>
    /// gebruikt om een STAND te bouwen), zonder radio of Windows-specifieke
    /// bluetooth-code nodig te hebben — precies zoals de gast-kant destijds
    /// eerst zonder radio bewezen is. Rondje: eigen SpelView -> SpelStandGast
    /// -> CodeerStand -> DecodeerStand (dezelfde functie die al tegen echte
    /// Mac-data getoetst is in Voorbeeld 3) -> terug.
    /// </summary>
    private static void ToetsGastheerStand()
    {
        Console.WriteLine("SpelStandGast.VanSpelView + CodeerStand: gastheer bouwt een STAND");

        var v = new SpelView
        {
            Troef = 2,
            Troefmaker = 1,
            SlagNr = 3,
            AanZet = Pos.HandNoord,
            KaartVoorGast = true, // Noord (de gast) is aan zet om een kaart te kiezen
            PuntenZuid = 12,
            PuntenNoord = 8,
            Status = "Status-tekst",
            Melding = "Melding-tekst",
        };
        v.HandZuid.Add(new KaartView { Index = 0, Naam = 'A', Kleur = 3, Open = true, Plek = 0 });
        v.HandNoord.Add(new KaartView { Index = 1, Naam = 'T', Kleur = 1, Open = false, Plek = 0 });

        var wire = SpelStandGast.VanSpelView(v, wachtOpVerder: false);

        Controleer(wire.MijnKant == 2, $"de gastheer wijst de gast altijd Noord toe, mijnKant == 2 (was: {wire.MijnKant})");
        Controleer(wire.WachtOpSpeler, "KaartVoorGast op de lokale SpelView komt als wachtOpSpeler == true op de lijn");
        Controleer(wire.AanZet == Pos.HandNoord, $"aanZet blijft HandNoord (was: {wire.AanZet})");
        Controleer(wire.HandNoord.Count == 1 && wire.HandNoord[0].Naam == 'T' && !wire.HandNoord[0].Open,
            "handNoord (de gast zelf) staat gewoon op zijn eigen plek, niet omgewisseld — dat doet de gast zelf al met GastWeergave");
        Controleer(wire.Troefmaker == 1, $"troefmaker komt mee (was: {wire.Troefmaker})");

        string base64 = DuoStand.CodeerStand(wire);
        SpelStandGast terug = DuoStand.DecodeerStand(base64);
        Controleer(terug.MijnKant == 2 && terug.PuntenZuid == 12 && terug.PuntenNoord == 8
                   && terug.HandZuid.Count == 1 && terug.HandZuid[0].Naam == 'A' && terug.HandZuid[0].Kleur == 3,
            "een zelfgecodeerde STAND komt met dezelfde DecodeerStand() weer heel terug (dezelfde functie als Voorbeeld 3)");

        // wachtOpVerder: alleen waar als de aanroeper dat expliciet meegeeft
        // (dat moment komt niet uit SpelView zelf, zie SpelForm.Verder).
        var verderWire = SpelStandGast.VanSpelView(new SpelView(), wachtOpVerder: true);
        Controleer(verderWire.WachtOpVerder, "wachtOpVerder: true wordt doorgegeven op de lijn");
    }

    /// <summary>
    /// De gastheer moet, in tegenstelling tot de gast, een ZET ook kunnen
    /// lézen (DuoStand.DecodeerZet bestond nog niet toen alleen de gast-rol
    /// er was). Rondje met dezelfde drie GastZet-vormen als ToetsEigenZetRondje.
    /// </summary>
    private static void ToetsDecodeerZet()
    {
        Console.WriteLine("DuoStand.DecodeerZet: de gastheer leest een ZET van de gast");

        GastZet troef = DuoStand.DecodeerZet(DuoStand.CodeerZet(GastZet.VoorTroef(1)));
        Controleer(troef.Troef == 1 && troef.Kaart == null && troef.Verder == null,
            $"troefkeuze komt terug als Troef=1 (was: Troef={troef.Troef}, Kaart={troef.Kaart}, Verder={troef.Verder})");

        GastZet kaart = DuoStand.DecodeerZet(DuoStand.CodeerZet(GastZet.VoorKaart('H', 2)));
        Controleer(kaart.Kaart == 'H' && kaart.Kleur == 2 && kaart.Troef == null,
            $"kaartkeuze komt terug als Kaart='H', Kleur=2 (was: Kaart={kaart.Kaart}, Kleur={kaart.Kleur})");

        GastZet verder = DuoStand.DecodeerZet(DuoStand.CodeerZet(GastZet.VoorVerder()));
        Controleer(verder.Verder == true && verder.Troef == null && verder.Kaart == null,
            $"\"verder\"-tik komt terug als Verder=true (was: Verder={verder.Verder})");
    }

    private static void RondjeBericht(DuoBericht bericht, string verwachteRegel)
    {
        string regel = bericht.NaarRegel();
        Controleer(regel == verwachteRegel, $"NaarRegel() geeft \"{verwachteRegel}\" (was: \"{regel}\")");

        DuoBericht terug = DuoBericht.Ontleed(regel);
        bool ok = terug != null && terug.Type == bericht.Type
                  && terug.Versie == bericht.Versie
                  && terug.AppVersie == bericht.AppVersie
                  && terug.Naam == bericht.Naam
                  && terug.Base64 == bericht.Base64;
        Controleer(ok, $"Ontleed(\"{regel}\") geeft hetzelfde bericht terug");
    }
}
