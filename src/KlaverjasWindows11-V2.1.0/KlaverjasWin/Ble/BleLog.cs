namespace Klaverjas.Ble;

/// <summary>
/// Een simpel logbestand naast de exe, alleen voor de gast-verbinding
/// (bluetooth). Bedoeld om precies te zien waar de begroeting vastloopt op
/// een echt toestel, iets wat van buitenaf niet te zien is. Nooit een
/// uitzondering laten ontsnappen: loggen mag het spel nooit breken.
/// </summary>
public static class BleLog
{
    private static readonly string Pad =
        Path.Combine(Path.GetDirectoryName(Environment.ProcessPath) ?? ".", "klaverjas-ble-log.txt");

    public static void Zeg(string tekst)
    {
        try { File.AppendAllText(Pad, $"{DateTime.Now:HH:mm:ss.fff} {tekst}\n"); } catch { }
    }
}
