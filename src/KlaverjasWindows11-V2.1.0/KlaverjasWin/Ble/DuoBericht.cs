namespace Klaverjas.Ble;

/// <summary>De vijf regelvormen van het lijnprotocol.</summary>
public enum DuoBerichtType
{
    /// <summary>"KJ &lt;versie&gt; &lt;appversie&gt; &lt;naam&gt;" — begroeting, door allebei gestuurd.</summary>
    Kj,
    /// <summary>"STAT &lt;base64&gt;" — bewaarde score voor deze partner, vlak na de begroeting, door allebei gestuurd.</summary>
    Stat,
    /// <summary>"JA &lt;versie&gt;" — akkoord van de gast.</summary>
    Ja,
    /// <summary>"STAND &lt;base64&gt;" — volledige momentopname, alleen van de gastheer.</summary>
    Stand,
    /// <summary>"ZET &lt;base64&gt;" — troef- of kaartkeuze, alleen van de gast.</summary>
    Zet,
    /// <summary>"P" — pols bij stilte. Mag genegeerd worden.</summary>
    Pols,
}

/// <summary>
/// Eén regel van het lijnprotocol: parsen (<see cref="Ontleed"/>) en
/// samenstellen (<see cref="NaarRegel"/>). Sinds protocolversie 3 zes vormen
/// in plaats van vijf (<c>STAT</c> erbij), zie <c>KlaverjasKit/DuoBericht.swift</c>.
/// </summary>
public sealed class DuoBericht
{
    public DuoBerichtType Type { get; private init; }
    public int Versie { get; private init; }
    public string AppVersie { get; private init; } = "";
    public string Naam { get; private init; } = "";
    public string Base64 { get; private init; } = "";

    public static DuoBericht Kj(int versie, string appVersie, string naam) => new()
    { Type = DuoBerichtType.Kj, Versie = versie, AppVersie = appVersie, Naam = naam };

    public static DuoBericht Stat(string base64) => new() { Type = DuoBerichtType.Stat, Base64 = base64 };

    public static DuoBericht Ja(int versie) => new() { Type = DuoBerichtType.Ja, Versie = versie };

    public static DuoBericht Stand(string base64) => new() { Type = DuoBerichtType.Stand, Base64 = base64 };

    public static DuoBericht Zet(string base64) => new() { Type = DuoBerichtType.Zet, Base64 = base64 };

    public static DuoBericht Pols() => new() { Type = DuoBerichtType.Pols };

    /// <summary>Zet dit bericht om in de regel die over de lijn gaat (zonder \n).</summary>
    public string NaarRegel() => Type switch
    {
        DuoBerichtType.Kj => $"KJ {Versie} {AppVersie} {Naam}",
        DuoBerichtType.Stat => $"STAT {Base64}",
        DuoBerichtType.Ja => $"JA {Versie}",
        DuoBerichtType.Stand => $"STAND {Base64}",
        DuoBerichtType.Zet => $"ZET {Base64}",
        DuoBerichtType.Pols => "P",
        _ => throw new InvalidOperationException($"Onbekend berichttype: {Type}"),
    };

    /// <summary>Ontleedt één regel (zonder \n). Geeft null bij een onherkende regel.</summary>
    public static DuoBericht Ontleed(string regel)
    {
        if (string.IsNullOrEmpty(regel)) return null;
        if (regel == "P") return Pols();

        int spatie = regel.IndexOf(' ');
        string woord = spatie < 0 ? regel : regel[..spatie];
        string rest = spatie < 0 ? "" : regel[(spatie + 1)..];

        switch (woord)
        {
            case "KJ":
                // "<versie> <appversie> <naam>" - naam mag zelf spaties bevatten.
                var delen = rest.Split(' ', 3);
                if (delen.Length < 3 || !int.TryParse(delen[0], out int versie)) return null;
                return Kj(versie, delen[1], delen[2]);

            case "STAT":
                return rest.Length > 0 ? Stat(rest) : null;

            case "JA":
                return int.TryParse(rest, out int jaVersie) ? Ja(jaVersie) : null;

            case "STAND":
                return rest.Length > 0 ? Stand(rest) : null;

            case "ZET":
                return rest.Length > 0 ? Zet(rest) : null;

            default:
                return null;
        }
    }
}
