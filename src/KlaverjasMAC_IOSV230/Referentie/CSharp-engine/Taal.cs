namespace Klaverjas.Engine;

/// <summary>
/// Alle teksten die de speler te zien krijgt, in het Nederlands en het Engels.
/// Zowel de speellogica als het scherm halen hun teksten hier op, zodat er bij
/// het omschakelen niets in de verkeerde taal kan achterblijven.
/// </summary>
public static class Taal
{
    /// <summary>false = Nederlands, true = Engels.</summary>
    public static bool Engels { get; set; }

    private static string T(string nl, string en) => Engels ? en : nl;

    // ------------------------------------------------------------- menu
    public static string MenuSpel => T("&Spel", "&Game");
    public static string MenuNieuw => T("&Nieuw spel", "&New game");
    public static string MenuDans => T("&Kaartendans", "Card &dance");
    public static string MenuAfsluiten => T("&Afsluiten", "E&xit");
    public static string MenuOpties => T("&Opties", "&Options");
    public static string MenuOrigineel => T("Oorspronkelijke &kaarten", "&Original cards");
    // Gladstrijken is geen keuze meer: de kaarten worden altijd met
    // Scale2x/Scale3x vergroot.
    public static string MenuDemo => T("&Demo (computer speelt beide)", "&Demo (computer plays both)");
    public static string MenuOpenKaart => T("Kaarten van &Noord tonen", "Show &North's cards");
    public static string MenuAuto => T("&Automatisch doorgaan", "Continue a&utomatically");
    public static string MenuDansAuto => T("Kaartendans &bij de start en na drie minuten",
                                           "Card dance at start and after three &minutes");
    public static string MenuSpeelwijze => T("S&peelwijze", "&Playing style");
    public static string MenuNoordSpeelt => T("Noord speelt", "North plays");
    public static string MenuZuidSpeelt => T("Zuid speelt (in demo)", "South plays (in demo)");
    public static string MenuAiEd => T("Ed — vuistregels", "Ed — rules of thumb");
    public static string MenuAiLoggen => T("Loggen — rekent zetten door", "Loggen — searches ahead");
    public static string MenuTaal => T("&Taal", "&Language");
    public static string MenuNederlands => "&Nederlands";
    public static string MenuEngels => "&English";

    // ------------------------------------------------------------ scherm
    public static string Titel => "Klaverjas";
    public static string Troef => T("Troef", "Trumps");
    public static string NogNietBepaald => T("nog niet bepaald", "not chosen yet");
    public static string SlagVanAcht(int n) => T($"Slag {n} van 8", $"Trick {n} of 8");
    public static string Noord => T("Noord", "North");
    public static string Zuid => T("Zuid", "South");
    public static string Punten => T("Punten", "Points");
    public static string Roem => T("Roem", "Meld");
    public static string Totaal => T("Totaal", "Total");
    public static string Partijen => T("Partijen", "Matches");
    public static string VorigeSlag => T("Vorige slag", "Previous trick");
    public static string KlikOfToets => T("   -   klik of druk een toets", "   -   click or press a key");
    public static string WelkeTroef => T("Welke kleur is troef?", "Which suit is trumps?");
    public static string KiesDeTroefkleur => T("Kies de troefkleur", "Choose the trump suit");
    public static string JouwBeurt => T("Jouw beurt - kies een kaart", "Your turn - pick a card");

    public static string DansTitel => T("Kaartendans  -  klik of druk een toets om te stoppen",
                                        "Card dance  -  click or press a key to stop");

    private static readonly string[] KleurenNl = { "Klaver", "Schoppen", "Ruiten", "Harten" };
    private static readonly string[] KleurenEn = { "Clubs", "Spades", "Diamonds", "Hearts" };

    /// <summary>Naam van kleur 0..3 (klaver, schoppen, ruiten, harten).</summary>
    public static string KleurNaam(int kleur)
    {
        if (kleur < 0 || kleur > 3) return "?";
        return Engels ? KleurenEn[kleur] : KleurenNl[kleur];
    }

    // ------------------------------------------------------------ slagen
    public static string SlagVoor(int slagNr, bool zuidWon)
        => T($"Slag {slagNr} voor {(zuidWon ? "Zuid" : "Noord")}",
             $"Trick {slagNr} to {(zuidWon ? "South" : "North")}");

    public static string MetRoem(int roem) => T($", {roem} roem", $", {roem} meld");

    public static string LaatsteSlag(int punten, bool naRoem)
        => naRoem
            ? T($" + {punten} voor de laatste slag", $" + {punten} for the last trick")
            : T($", {punten} voor de laatste slag", $", {punten} for the last trick");

    public static string Scheiding => "   -   ";

    // ------------------------------------------------------- einde spel
    public static string WintDitSpel(bool zuidWon)
        => T($"{(zuidWon ? "Zuid" : "Noord")} wint dit spel",
             $"{(zuidWon ? "South" : "North")} wins this deal");

    public static string TegenpartijNat => T(" (tegenpartij is nat)", " (the other side went wet)");

    public static string Standen(int zuid, int noord)
        => T($"  -  Zuid {zuid}, Noord {noord}", $"  -  South {zuid}, North {noord}");

    public static string PartijUit => T("  -  partij uit!", "  -  match over!");

    // -------------------------------------------------- snel spelen (SDEMO)
    // Let op de sneltoetsletters: die moeten binnen het menu uniek zijn.
    // De N is al van "Kaarten van &Noord tonen".
    public static string MenuSnel => T("&Snel spelen zonder kaarten", "&Fast play without cards");
    public static string SnelBezig => T("Snel spelen zonder kaarten", "Fast play without cards");
    public static string SnelSpellen(long n) => T($"{n:N0} spellen gespeeld", $"{n:N0} deals played");
    public static string SnelUitzetten =>
        T("Zet dit uit via Opties om weer met kaarten te spelen.",
          "Turn this off in Options to play with cards again.");

    // ------------------------------------------------------ statistieken
    public static string MenuStatistieken => T("&Statistieken", "&Statistics");
    public static string StatTitel => T("Statistieken", "Statistics");
    public static string StatNogNiets => T("Nog geen spel gespeeld", "No deal played yet");
    public static string StatSluiten => T("Sluiten", "Close");
    public static string StatPartijen => T("Partijen gewonnen", "Matches won");
    public static string StatSpellen => T("Spellen gewonnen", "Deals won");
    public static string StatStand => T("Stand van de partij", "Match score");
    public static string StatKaartpunten => T("Kaartpunten", "Card points");
    public static string StatTroefpunten => T("Troefpunten", "Trump points");
    public static string StatTroefkaarten => T("Troefkaarten", "Trump cards");
    public static string StatRoempunten => T("Roempunten", "Meld points");
    public static string StatPit => T("Pit", "All eight tricks");
    public static string StatTegenpit => T("Tegenpit", "Opponent's slam");
    public static string StatNat => T("Nat", "Went wet");
    public static string StatSuperroem => T("Superroem (vier gelijke)", "Four of a kind");
    public static string StatTactiek => T("Tactiek", "Tactic");
    /// <summary>
    /// Nummer 70 bestaat niet in het origineel; het is de zoekende speler van
    /// Loggen. Daarom staat het hier en niet in Tactieknamen, dat uit de
    /// Swift-bron gegenereerd wordt.
    /// </summary>
    public static string StatTactiekZoeken =>
        T("Doorgerekend (Loggen)", "Searched ahead (Loggen)");
    public static string StatTactiekUitleg =>
        T("De nummers zijn die uit de broncode van 1994; hoe vaak elke regel is toegepast.",
          "The numbers are those from the 1994 source; how often each rule was applied.");

    // --------------------------------------------------------- meldingen
    public static string KaartLigtOpTafel => T("Die kaart ligt op tafel - uit de hand spelen",
                                               "That card is on the table - play from your hand");
    public static string KaartZitInHand => T("Die kaart zit in je hand - van tafel spelen",
                                             "That card is in your hand - play from the table");
    public static string KaartNietSpeelbaar => T("Die kaart kun je niet spelen",
                                                 "You cannot play that card");

    public static string ComputerVerzaakte(int tactiek, int kleur, char kaart)
        => T($"Fout: de computer verzaakte (tactiek {tactiek}, kaart {KleurNaam(kleur)} {kaart}). " +
             "Alle punten gaan naar de tegenpartij.",
             $"Error: the computer revoked (tactic {tactiek}, card {KleurNaam(kleur)} {kaart}). " +
             "All points go to the other side.");

    // ------------------------------------------------------------ regels
    public static string VerkeerdeKaart => T("Verkeerde kaart", "Wrong card");
    public static string MoetTroefBekennen => T("Je moet troef bekennen", "You must follow trumps");
    public static string MoetOvertroeven => T("Je moet overtroeven", "You must overtrump");
    public static string MoetKleurBekennen => T("Je moet kleur bekennen", "You must follow suit");
    public static string MoetTroeven => T("Je moet troeven", "You must trump");

    // ------------------------------------------------------------ fouten
    public static string FoutInSpellogica => T("Fout in de speellogica:", "Error in the game logic:");
    public static string VolledigeMeldingIn => T("Volledige melding in:", "Full message in:");
    public static string IetsMisMaarLooptDoor => T("Er ging iets mis, maar het spel loopt door.",
                                                   "Something went wrong, but the game continues.");
    public static string VorigePartijReageertNiet
        => T("De vorige partij reageert niet; probeer het zo nog eens.",
             "The previous game is not responding; please try again shortly.");
}
