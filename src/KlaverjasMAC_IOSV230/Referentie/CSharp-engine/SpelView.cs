namespace Klaverjas.Engine;

/// <summary>Eén kaart zoals de UI hem moet tekenen.</summary>
public sealed class KaartView
{
    public int Index;        // 0..31, index in Kaart[]
    public char Naam;
    public int Kleur;
    public bool Open;        // false = achterkant tonen
    public bool Klikbaar;
    public int Plek;         // 0..3 voor tafelkaarten, anders volgnummer
}

/// <summary>Een gespeelde kaart in de huidige of vorige slag.</summary>
public readonly record struct SlagView(int Kleur, char Naam, int Speler, int Tactiek);

/// <summary>Wat één slag opleverde voor de winnaar ervan.</summary>
/// <param name="Punten">Kaartpunten van de vier kaarten samen.</param>
/// <param name="Roem">Roem uit opeenvolgende kaarten, stuk of vier gelijke.</param>
/// <param name="LaatsteSlag">10 punten voor de achtste slag, anders 0.</param>
public readonly record struct SlagUitslag(int Punten, int Roem, int LaatsteSlag);

/// <summary>
/// Momentopname van de speltoestand. De speellogica draait op een eigen
/// thread; de UI tekent uitsluitend uit zo'n snapshot, zodat er geen
/// gedeelde-toestand-races kunnen ontstaan.
/// </summary>
public sealed class SpelView
{
    public List<KaartView> HandZuid = new();
    public List<KaartView> HandNoord = new();
    public List<KaartView> TafelZuid = new();
    public List<KaartView> TafelNoord = new();
    public List<KaartView> DichtZuid = new();
    public List<KaartView> DichtNoord = new();

    /// <summary>
    /// Per tafelplek 0..3: ligt daar nog een dichte kaart onder? Dit komt uit
    /// tzuid[]/tnoord[] van de engine. Het aantal dichte kaarten alleen is niet
    /// genoeg: welke plek nog gedekt is, staat er los van.
    /// </summary>
    public readonly bool[] OnderZuid = new bool[4];
    public readonly bool[] OnderNoord = new bool[4];
    public List<SlagView> Slag = new();
    public List<SlagView> VorigeSlag = new();

    public int Troef = 999;
    public int SlagNr;
    public int AanZet;              // 1..4, wie moet er spelen
    public bool WachtOpSpeler;      // true = de mens is aan zet
    public bool TroefVraag;         // true = de mens moet troef kiezen

    public int PuntenZuid, PuntenNoord;
    public int RoemZuid, RoemNoord;
    public long TotaalZuid, TotaalNoord;
    public int PartijenZuid, PartijenNoord;

    public string Status = "";
    public string Melding = "";

    /// <summary>De tellers over de hele sessie, voor het statistiekenscherm.</summary>
    public Statistiek Statistiek = new();
}
