using System.IO.Compression;
using System.Text;
using System.Text.Json;

namespace Klaverjas.Ble;

/// <summary>
/// JSON &lt;-&gt; base64 voor de inhoud van <c>STAND</c>- en <c>ZET</c>-regels.
///
/// De cruciale valkuil (zie BLUETOOTH-VOOR-WINDOWS.md): de Mac-kant comprimeert
/// met Apple's <c>Compression</c>-framework onder de naam
/// <c>COMPRESSION_ZLIB</c>, maar dat is geen echte zlib-stream (RFC 1950) —
/// het is kale, rauwe DEFLATE (RFC 1951), zonder header en zonder staart.
/// Op .NET is dat exact <see cref="DeflateStream"/>, niet <c>ZLibStream</c> en
/// niet <c>GZipStream</c>.
/// </summary>
public static class DuoStand
{
    private static readonly JsonSerializerOptions SchrijfOpties = new()
    {
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull,
    };

    /// <summary>Comprimeert JSON-tekst tot de base64-vorm die over de lijn gaat.</summary>
    public static string Comprimeer(string json)
    {
        byte[] bytes = Encoding.UTF8.GetBytes(json);
        using var uit = new MemoryStream();
        using (var deflate = new DeflateStream(uit, CompressionLevel.Optimal, leaveOpen: true))
            deflate.Write(bytes, 0, bytes.Length);
        return Convert.ToBase64String(uit.ToArray());
    }

    /// <summary>Decomprimeert de base64-inhoud van een STAND/ZET-regel tot JSON-tekst.</summary>
    public static string Decomprimeer(string base64)
    {
        byte[] gecomprimeerd = Convert.FromBase64String(base64);
        using var bron = new MemoryStream(gecomprimeerd);
        using var deflate = new DeflateStream(bron, CompressionMode.Decompress);
        using var uit = new MemoryStream();
        deflate.CopyTo(uit);
        return Encoding.UTF8.GetString(uit.ToArray());
    }

    /// <summary>Leest de base64-inhoud van een STAND-regel als <see cref="SpelStandGast"/>.</summary>
    public static SpelStandGast DecodeerStand(string base64)
    {
        string json = Decomprimeer(base64);
        return JsonSerializer.Deserialize<SpelStandGast>(json)
               ?? throw new InvalidDataException("Lege of onleesbare STAND.");
    }

    /// <summary>Codeert een <see cref="GastZet"/> tot de base64-inhoud van een ZET-regel.</summary>
    public static string CodeerZet(GastZet zet)
    {
        string json = JsonSerializer.Serialize(zet, SchrijfOpties);
        return Comprimeer(json);
    }

    /// <summary>Codeert een <see cref="SpelStandGast"/> tot de base64-inhoud van een STAND-regel.</summary>
    public static string CodeerStand(SpelStandGast stand)
    {
        string json = JsonSerializer.Serialize(stand, SchrijfOpties);
        return Comprimeer(json);
    }

    /// <summary>Leest de base64-inhoud van een ZET-regel als <see cref="GastZet"/>.</summary>
    public static GastZet DecodeerZet(string base64)
    {
        string json = Decomprimeer(base64);
        return JsonSerializer.Deserialize<GastZet>(json)
               ?? throw new InvalidDataException("Lege of onleesbare ZET.");
    }
}
