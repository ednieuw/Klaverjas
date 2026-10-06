using System.Text.Json.Serialization;

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
    public long[] Superroem = { 0, 0 };
    public long[] Totaal = { 0, 0 };        // PuntenTotaalSpel[]: stand van de partij

    /// <summary>
    /// Hoe vaak elke tactiek is toegepast, 0..79. De nummers zijn die uit het
    /// origineel (TACTIEK=7, 41, 68, ...).
    /// </summary>
    public long[] Tactiek = new long[80];

    /// <summary>Is er al iets te zien?</summary>
    [JsonIgnore]
    public bool Leeg => Spellen[0] + Spellen[1] == 0;

    /// <summary>
    /// Lijsten die uit een bewaard bestand komen op de juiste lengte
    /// brengen. Een bestand van een andere versie kan een kortere of langere
    /// tactieklijst hebben, of een veld missen; dat vult zichzelf aan met
    /// nullen in plaats van te struikelen.
    /// </summary>
    public void Normaliseer()
    {
        static long[] Twee(long[] l)
        {
            if (l != null && l.Length == 2) return l;
            var uit = new long[2];
            if (l != null) Array.Copy(l, uit, Math.Min(l.Length, 2));
            return uit;
        }

        Partijen = Twee(Partijen);
        Spellen = Twee(Spellen);
        Kaartpunten = Twee(Kaartpunten);
        Troefpunten = Twee(Troefpunten);
        Troefkaarten = Twee(Troefkaarten);
        Roempunten = Twee(Roempunten);
        Pit = Twee(Pit);
        Tegenpit = Twee(Tegenpit);
        Nat = Twee(Nat);
        Superroem = Twee(Superroem);
        Totaal = Twee(Totaal);

        if (Tactiek == null || Tactiek.Length != 80)
        {
            var uit = new long[80];
            if (Tactiek != null) Array.Copy(Tactiek, uit, Math.Min(Tactiek.Length, 80));
            Tactiek = uit;
        }
    }

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
            Superroem = new[] { s.Superroem[0], s.Superroem[1] },
            Totaal = new[] { s.PuntenTotaalSpel[0], s.PuntenTotaalSpel[1] },
        };
        Array.Copy(s.Tac, st.Tactiek, Math.Min(s.Tac.Length, st.Tactiek.Length));
        return st;
    }

    /// <summary>
    /// De tellingen terugzetten in een verse KjState. Nodig als de motor
    /// opnieuw opgezet wordt zonder dat de sessie ophoudt - bij snel spelen,
    /// zie A4 - want anders zou dat de hele telling wegvegen.
    /// Element voor element, want de velden zijn readonly arrays.
    /// </summary>
    public static void ZetStatistiek(this KjState s, Statistiek st)
    {
        for (int i = 0; i < 2; i++)
        {
            s.Gewonnen[i] = (int)st.Partijen[i];
            s.GewonnenTot[i] = st.Spellen[i];
            s.Kaartpnt[i] = st.Kaartpunten[i];
            s.Troefpnt[i] = st.Troefpunten[i];
            s.Troefkrt[i] = st.Troefkaarten[i];
            s.Roempnt[i] = st.Roempunten[i];
            s.Pit[i] = st.Pit[i];
            s.Tpit[i] = st.Tegenpit[i];
            s.Nat[i] = st.Nat[i];
            s.Superroem[i] = st.Superroem[i];
            s.PuntenTotaalSpel[i] = st.Totaal[i];
        }
        Array.Clear(s.Tac);
        Array.Copy(st.Tactiek, s.Tac, Math.Min(st.Tactiek.Length, s.Tac.Length));
    }
}
