namespace Klaverjas.Engine;

/// <summary>
/// De tellingen die het origineel bij het afsluiten op het scherm zette
/// (KJ.C, aan het eind van main()): Gewonnen / Kaartpnt / Troefpnt / Troefkrt /
/// Roempnt / Pit / Tegenpit / Nat in twee kolommen, met de superroem eronder,
/// en bij COMP ook de teller per tactiek.
///
/// In het origineel zag je dit pas als je stopte met spelen. Met het
/// statistiekenscherm kan het tijdens het spel bekeken worden; de getallen zelf
/// zijn dezelfde.
/// </summary>
public sealed class Statistiek
{
    // [0] = Zuid, [1] = Noord - dezelfde volgorde als in de engine.
    public long[] Partijen = { 0, 0 };      // Gewonnen[]: partijen tot 1500
    public long[] Spellen = { 0, 0 };       // GewonnenTot[]: losse spellen
    public long[] Kaartpunten = { 0, 0 };
    public long[] Troefpunten = { 0, 0 };
    public long[] Troefkaarten = { 0, 0 };
    public long[] Roempunten = { 0, 0 };
    public long[] Pit = { 0, 0 };
    public long[] Tegenpit = { 0, 0 };
    public long[] Nat = { 0, 0 };
    public long Superroem;
    public long[] Totaal = { 0, 0 };        // PuntenTotaalSpel[]: stand van de partij

    /// <summary>
    /// Hoe vaak elke tactiek is toegepast, 0..79. De nummers zijn die uit het
    /// origineel (TACTIEK=7, 41, 68, ...).
    /// </summary>
    public long[] Tactiek = new long[80];

    /// <summary>Is er al iets te zien?</summary>
    public bool Leeg => Spellen[0] + Spellen[1] == 0;

    /// <summary>
    /// De tactieken die daadwerkelijk gebruikt zijn, de meest gebruikte eerst.
    /// Nummer 0 valt af: dat betekent "geen tactiek", zoals bij elke kaart die
    /// de speler zelf legt.
    /// </summary>
    public List<(int Nummer, long Aantal)> GebruikteTactieken()
    {
        var uit = new List<(int, long)>();
        for (int n = 1; n < Tactiek.Length; n++)
            if (Tactiek[n] > 0) uit.Add((n, Tactiek[n]));
        uit.Sort((a, b) => b.Item2.CompareTo(a.Item2));
        return uit;
    }
}

/// <summary>
/// Een momentopname van de tellers maken, veilig mee te geven aan het scherm.
/// Een uitbreidingsmethode, zodat KjState.cs onaangeroerd kan blijven.
/// </summary>
public static class StatistiekBouwer
{
    public static Statistiek MaakStatistiek(this KjState s)
    {
        var st = new Statistiek
        {
            Partijen = new[] { (long)s.Gewonnen[0], (long)s.Gewonnen[1] },
            Spellen = new[] { s.GewonnenTot[0], s.GewonnenTot[1] },
            Kaartpunten = new[] { s.Kaartpnt[0], s.Kaartpnt[1] },
            Troefpunten = new[] { s.Troefpnt[0], s.Troefpnt[1] },
            Troefkaarten = new[] { s.Troefkrt[0], s.Troefkrt[1] },
            Roempunten = new[] { s.Roempnt[0], s.Roempnt[1] },
            Pit = new[] { s.Pit[0], s.Pit[1] },
            Tegenpit = new[] { s.Tpit[0], s.Tpit[1] },
            Nat = new[] { s.Nat[0], s.Nat[1] },
            Superroem = s.Superroem,
            Totaal = new[] { s.PuntenTotaalSpel[0], s.PuntenTotaalSpel[1] },
        };
        Array.Copy(s.Tac, st.Tactiek, Math.Min(s.Tac.Length, st.Tactiek.Length));
        return st;
    }
}
