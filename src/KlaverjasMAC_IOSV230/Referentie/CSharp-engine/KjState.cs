namespace Klaverjas.Engine;

/// <summary>Eén van de 32 kaarten in het spel (struct krts uit KJ.C).</summary>
public sealed class SpeelKaart
{
    public char Naam;          // 'A','H','V','B','T','9','8','7'
    public int PuntWaarde;     // waarde als niet-troef
    public int TroefWaarde;    // waarde als troef
    public int ActWaarde;      // actuele waarde, gezet zodra troef bekend is
    public int DichtIkHy;      // zie KaartPositie
    public int Troef;
    public int Kleur;          // 0=Klaver 1=Schoppen 2=Ruiten 3=Harten
}

/// <summary>
/// De waarden van kaart.DichtIkHy uit het origineel. Dit is de spilvariabele:
/// hij codeert waar een kaart zich bevindt.
/// </summary>
public static class Pos
{
    public const int Dicht = 0;       // nog niet uitgedeeld / onbekend
    public const int HandZuid = 1;    // in de hand van Zuid
    public const int HandNoord = 2;   // in de hand van Noord
    public const int TafelZuid = 3;   // open op tafel bij Zuid
    public const int TafelNoord = 4;  // open op tafel bij Noord
    public const int Gespeeld = 5;    // al gespeeld
    public const int DichtZuid = 33;  // dicht onder de tafelkaarten van Zuid
    public const int DichtNoord = 44; // dicht onder de tafelkaarten van Noord
    public const int NieuwZuid = 13;  // net omgedraaid, wordt volgende slag TafelZuid
    public const int NieuwNoord = 14; // net omgedraaid, wordt volgende slag TafelNoord
}

/// <summary>Kaart in hand/tafel-overzicht met bijbehorende slagkans (struct deck).</summary>
public struct Deck
{
    public int Slagkans;
    public int Slagkans0;    // slagkans aan het begin van de slag
    public char Naam;
    public int Kleur;
    public int Waarde;
    public int Troef;
    public int Gegarandeerd; // slagkans > 95
}

/// <summary>Eén gespeelde kaart binnen een slag (struct slach).</summary>
public struct SlagKaart
{
    public int Kleur;
    public char Naam;
    public int Troef;
    public int Speler;
    public int Kans;
    public int Waarde;
    public int Tactiek;
}

/// <summary>
/// Alle globale toestand van het originele programma bij elkaar. Het origineel
/// werkt volledig met globals; die structuur is hier bewust overgenomen zodat
/// de vertaling van de speel- en tactiekroutines één-op-één blijft.
/// </summary>
public sealed class KjState
{
    public const int SlagkansLevel = 15;

    // Volgorde van kaarten binnen een kleur, hoog -> laag.
    public const string RangTroef = "B9ATHV87";
    public const string RangNorm = "ATHVB987";
    public const string RangRoem = "AHVBT987";

    // Voor de naam van een kleur: Taal.KleurNaam(), die de gekozen taal volgt.

    public readonly SpeelKaart[] Kaart = new SpeelKaart[32];
    public readonly Deck[,] Hand = new Deck[2, 8];
    public readonly Deck[,] Tafel = new Deck[2, 8];

    /// <summary>
    /// slag[9][4] uit het origineel, maar plat opgeslagen. Het origineel indexeert
    /// op een paar plaatsen bewust of onbewust buiten de rij (slag[SLAG][4]); met
    /// een platte array valt dat net als in C door naar slag[SLAG+1][0], zodat het
    /// gedrag identiek blijft in plaats van een exception te geven.
    /// </summary>
    private readonly SlagKaart[] _slag = new SlagKaart[48];

    public ref SlagKaart Slag(int slag, int i) => ref _slag[slag * 4 + i];

    public readonly int[] Deeltabel = new int[32];
    public readonly int[,] Verzaakt = new int[2, 4];
    public readonly int[] TNoord = new int[4];   // ligt er nog een dichte kaart onder?
    public readonly int[] TZuid = new int[4];

    // Kaartverzamelingen als C-strings, per kleur en totaal.
    public readonly char[][] KrtWeg = CStr.New2(4, 16);
    public readonly char[][] KrtVrij = CStr.New2(4, 16);
    public readonly char[][] KrtDicht = CStr.New2(4, 16);
    public readonly char[] KrtTotWeg = CStr.New(40);
    public readonly char[] KrtTotVrij = CStr.New(40);
    public readonly char[] KrtTotDicht = CStr.New(40);

    // [0] = kant van de huidige vrager, [1] = tegenpartij
    public readonly int[,] IKrt = new int[4, 2];
    public readonly int[,] IKrtTafel = new int[4, 2];
    public readonly char[][][] KHand = CStr.New3(2, 4, 16);
    public readonly char[][][] KTafel = CStr.New3(2, 4, 16);
    public int IKrtGespeeld;

    public int Vrager, StartVrager;
    public int Troef = 999;
    public int Speler;
    public int SlagNr, SlagKrtNo;

    public readonly int[] Roem = new int[2];
    public readonly int[] Gewonnen = new int[2];
    public readonly int[] PuntenSpel = new int[2];
    public readonly long[] PuntenTotaalSpel = new long[2]; // [0]=Zuid, [1]=Noord

    public char Lkaart;
    public int Lkleur;
    public char Lkaart3;
    public int Lkleur3;
    public char Skrt41;

    public int Hoogste;
    public int Tactiek;
    public bool Tactiek41, TactiekLaag, TactiekTT;

    /// <summary>true = beide handen door de computer gespeeld (demo).</summary>
    public bool Comp;

    /// <summary>
    /// Welke speelwijze gebruikt de computer per kant? false = de tactiek van
    /// Ed uit KJ.C, true = de zoekende speler van R. Loggen. Index 0 = Zuid,
    /// 1 = Noord.
    /// </summary>
    public readonly bool[] Zoekt = new bool[2];
    /// <summary>true = kaarten van de tegenstander verborgen.</summary>
    public bool Dicht = true;

    // Statistiek over de hele sessie.
    public readonly long[] Kaartpnt = new long[2];
    public readonly long[] Troefpnt = new long[2];
    public readonly long[] GewonnenTot = new long[2];
    public readonly long[] Roempnt = new long[2];
    public readonly long[] Troefkrt = new long[2];
    public readonly long[] Pit = new long[2];
    public readonly long[] Tpit = new long[2];
    public readonly long[] Nat = new long[2];
    public long Superroem;
    public readonly long[] Tac = new long[80];

    // Faculteiten 0..18, gebruikt door guillermie().
    public static readonly double[] Fact =
    {
        1.0, 1.0, 2.0, 6.0, 24.0, 120.0, 720.0, 5040.0, 40320.0, 362880.0,
        3628800.0, 39916800.0, 479001600.0, 6227020800.0, 87178291200.0,
        1307674368000.0, 20922789888000.0, 355687428096000.0, 6402373705728000.0
    };

    public readonly Toevalsreeks Rnd;

    public KjState(int? zaad = null)
    {
        // Geen zaad opgegeven: dan varieert het per keer. Wel een zaad: dan
        // speelt de engine exact dezelfde spellen, en dat is wat de vergelijking
        // met de Swift-versie mogelijk maakt.
        Rnd = new Toevalsreeks(zaad.HasValue
            ? (uint)zaad.Value
            : (uint)Environment.TickCount ^ 0x9E3779B9u);
        for (int i = 0; i < 32; i++) Kaart[i] = new SpeelKaart();
    }

    /// <summary>Borland random(num): 0 &lt;= resultaat &lt; num, en 0 bij num &lt;= 0.</summary>
    public int Random(int num) => Rnd.Volgende(num);

    /// <summary>Index in Kaart[] van kaart (kleur, naam).</summary>
    public static int KaartNr(int kleur, char naam) => CStr.Pos(RangRoem, naam) + kleur * 8 - 1;
}
