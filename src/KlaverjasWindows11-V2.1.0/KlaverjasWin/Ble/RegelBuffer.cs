using System.Text;

namespace Klaverjas.Ble;

/// <summary>
/// Knipt een regel op voor verzending in bluetooth-pakketjes, en plakt
/// binnenkomende pakketjes weer aan elkaar tot volledige regels.
///
/// Eén regel kan groter zijn dan één pakketje; omgekeerd kan één pakketje ook
/// een stuk van een regel zijn, of het einde van de ene en het begin van de
/// volgende regel tegelijk. Een pakketje is dus nooit meer of minder dan "een
/// stuk van een regel" — dit is een bewuste correctie op een eerder,
/// bluetooth-project (BLESerialPro) dat aannam dat één notificatie altijd
/// precies één regel was.
/// </summary>
public static class RegelSplitser
{
    /// <summary>
    /// Splitst één regel (plus het afsluitende \n) in stukken van hooguit
    /// <paramref name="pakketGrootte"/> bytes.
    /// </summary>
    public static List<byte[]> SplitsVoorVerzending(string regel, int pakketGrootte)
    {
        if (pakketGrootte < 1) throw new ArgumentOutOfRangeException(nameof(pakketGrootte));

        byte[] bytes = Encoding.UTF8.GetBytes(regel + "\n");
        var pakketten = new List<byte[]>();
        for (int i = 0; i < bytes.Length; i += pakketGrootte)
        {
            int lengte = Math.Min(pakketGrootte, bytes.Length - i);
            var stuk = new byte[lengte];
            Array.Copy(bytes, i, stuk, 0, lengte);
            pakketten.Add(stuk);
        }
        // Een lege regel geeft door de toegevoegde \n toch minstens één pakketje.
        return pakketten;
    }
}

/// <summary>
/// Ontvangkant van <see cref="RegelSplitser"/>: één buffer per richting per
/// verbinding, nooit gedeeld tussen twee verbindingen.
/// </summary>
public sealed class RegelBuffer
{
    private readonly List<byte> _buffer = new();

    /// <summary>
    /// Voegt een binnengekomen pakketje toe en geeft alle regels terug die
    /// daardoor compleet zijn geworden (nul, één, of meer). Onvolledige rest
    /// blijft in de buffer staan voor het volgende pakketje.
    /// </summary>
    public List<string> VoegToe(byte[] pakket)
    {
        _buffer.AddRange(pakket);

        var regels = new List<string>();
        int start = 0;
        for (int i = 0; i < _buffer.Count; i++)
        {
            if (_buffer[i] != (byte)'\n') continue;
            regels.Add(Encoding.UTF8.GetString(Uitknippen(start, i - start)));
            start = i + 1;
        }
        if (start > 0) _buffer.RemoveRange(0, start);
        return regels;
    }

    private byte[] Uitknippen(int start, int count)
    {
        var stuk = new byte[count];
        _buffer.CopyTo(start, stuk, 0, count);
        return stuk;
    }
}
