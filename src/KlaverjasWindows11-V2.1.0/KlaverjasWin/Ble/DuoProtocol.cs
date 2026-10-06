namespace Klaverjas.Ble;

/// <summary>
/// Vaste protocolwaarden die zowel de gast-kant (<see cref="GastRadio"/>,
/// "zoeken") als de gastheer-kant (<see cref="GastheerRadio"/>, "openstellen")
/// nodig hebben — hier één keer neergezet zodat ze nooit uit elkaar kunnen
/// lopen tussen de twee rollen.
/// </summary>
public static class DuoProtocol
{
    /// <summary>
    /// Moet gelijk zijn aan <c>DuoOpzet.protocolVersie</c> op de Mac. Van 2
    /// naar 3 ging hij toen <c>STAT</c> (score per partner) aan de begroeting
    /// werd toegevoegd.
    /// </summary>
    public const int Versie = 3;

    /// <summary>
    /// Kant-en-klare, gecomprimeerde vorm van een lege <c>Statistiek</c>
    /// (<c>{}</c>) — geverifieerd tegen de echte Mac-code, zie
    /// BLUETOOTH-VOOR-WINDOWS2.1.0.md, "STAT: score per partner". Dit is de
    /// "minimale, correcte deelname": deze app houdt zelf nog geen score per
    /// partner bij, dus deze vaste lege waarde volstaat om de begroeting niet
    /// te laten hangen. De inhoud van de STAT die terugkomt van de andere kant
    /// wordt genegeerd — alleen dat er één terugkomt is nodig.
    /// </summary>
    public const string LegeStatistiek =
        "q1YqLi1ILSrKT81Vsoo20DGI1VEqyS9JTMyBc0FyBaV5Jal5cKGCzBI4Oy8RwS5JTC7JTM2G8AczBLo1OzGxqATNXyVAv6ahiRUXpObkIKtJTU/NQw6AAqA5mVnopoCNhwvWAgA=";

    /// <summary>
    /// Conservatieve pakketgrootte tot de werkelijke MTU bekend is — dit is
    /// exact wat de Mac-kant ook als startpunt gebruikt.
    /// </summary>
    public const int PakketGrootte = 20;
}
