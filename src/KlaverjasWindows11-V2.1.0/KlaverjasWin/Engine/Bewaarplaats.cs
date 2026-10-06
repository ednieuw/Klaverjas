using System.Text.Json;
using System.Text.Json.Serialization;

namespace Klaverjas.Engine;

/// <summary>
/// Wat er tussen twee zittingen bewaard blijft. Het origineel drukte de
/// tellingen bij het afsluiten af en gooide ze weg; een partij naar 1500 was
/// daarmee nooit af te maken als je tussendoor stopte.
///
/// Bewust wel bewaard: de tellingen, de twee speelwijzen en de taal. Bewust
/// níet: demo, open kaart en snel spelen. Die horen bij één zitting, en in snel
/// spelen opstarten omdat dat gisteren aanstond is geen prettige verrassing.
/// </summary>
public sealed class BewaardeStand
{
    /// <summary>Zodat een later formaat te herkennen is.</summary>
    public int Versie = 1;

    public Statistiek Statistiek = new();

    /// <summary>false = Nederlands, true = Engels.</summary>
    public bool Engels;

    /// <summary>
    /// Wie er aan welke kant speelt: false = de vuistregels van Ednieuw, true =
    /// de zoekende speler van Ronlog. Index 0 = Zuid, 1 = Noord. Standaard staat
    /// Zuid op Ronlog en Noord op Ednieuw, zodat demo en snel spelen meteen de
    /// twee speelwijzen tegen elkaar zetten.
    /// </summary>
    public bool[] Zoekt = { true, false };

    /// <summary>
    /// Ontbrekende of te korte lijsten aanvullen. Een bestand van een oudere of
    /// nieuwere versie mag nooit het hele programma laten struikelen: één veld
    /// dat niet klopt zou anders de hele telling wegvagen.
    /// </summary>
    public void Normaliseer()
    {
        Statistiek ??= new Statistiek();
        Statistiek.Normaliseer();
        if (Zoekt == null || Zoekt.Length < 2) Zoekt = new[] { true, false };
    }
}

/// <summary>
/// Leest en schrijft <see cref="BewaardeStand"/> als JSON. Alles wat misgaat -
/// geen schrijfrechten, een half bestand, een schijf die vol is - levert de
/// standaardwaarden op in plaats van een foutmelding: er staat niets in dat
/// belangrijk genoeg is om het spelen voor op te houden.
/// </summary>
public static class Bewaarplaats
{
    private static readonly JsonSerializerOptions Opties = new()
    {
        // Statistiek en BewaardeStand houden hun waarden in velden, niet in
        // eigenschappen; zonder dit blijft het bestand leeg.
        IncludeFields = true,
        WriteIndented = true,
    };

    /// <summary>
    /// %AppData%\Klaverjas\klaverjas.json. Niet naast het programma: dat staat
    /// vaak in een map waar niet in geschreven mag worden.
    /// </summary>
    public static string Pad
    {
        get
        {
            string map = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "Klaverjas");
            return Path.Combine(map, "klaverjas.json");
        }
    }

    public static BewaardeStand Lees()
    {
        try
        {
            if (!File.Exists(Pad)) return new BewaardeStand();
            var stand = JsonSerializer.Deserialize<BewaardeStand>(File.ReadAllText(Pad), Opties)
                        ?? new BewaardeStand();
            stand.Normaliseer();
            return stand;
        }
        catch (Exception ex)
        {
            // Wel vastleggen: als het bestand stuk is wil je dat kunnen nazien.
            try { File.AppendAllText(Pad + ".fout.txt", $"{DateTime.Now:s} lezen: {ex.Message}\n"); }
            catch { }
            return new BewaardeStand();
        }
    }

    public static void Schrijf(BewaardeStand stand)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(Pad)!);
            // Eerst ernaast schrijven en dan pas op zijn plaats zetten: gaat er
            // halverwege iets mis, dan blijft het oude bestand heel in plaats van
            // dat er een half bestand achterblijft.
            // Op naam van dit proces: draaien er twee vensters tegelijk, dan
            // zouden ze anders hetzelfde tijdelijke bestand gebruiken en
            // elkaars schrijfbeurt omvergooien.
            string tijdelijk = $"{Pad}.{Environment.ProcessId}.tmp";
            File.WriteAllText(tijdelijk, JsonSerializer.Serialize(stand, Opties));
            File.Move(tijdelijk, Pad, overwrite: true);
        }
        catch (Exception ex)
        {
            // Niet laten struikelen, maar wel vastleggen wat er misging: anders
            // is "er wordt niets bewaard" niet te achterhalen.
            try { File.AppendAllText(Pad + ".fout.txt", $"{DateTime.Now:s} schrijven: {ex.Message}" + Environment.NewLine); }
            catch { }
        }
    }

    /// <summary>
    /// Alleen de tellingen op nul. De speelwijzen en de taal blijven staan: die
    /// heeft de speler zelf gekozen en hebben met de telling niets te maken.
    /// </summary>
    public static void WisTellingen()
    {
        var stand = Lees();
        stand.Statistiek = new Statistiek();
        Schrijf(stand);
    }
}
