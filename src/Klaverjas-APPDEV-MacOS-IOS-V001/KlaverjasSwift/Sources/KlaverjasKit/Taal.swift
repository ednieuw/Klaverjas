import Foundation

/// Alle teksten die de speler te zien krijgt, in het Nederlands en het Engels.
/// Zowel de speellogica als het scherm halen hun teksten hier op, zodat er bij
/// het omschakelen niets in de verkeerde taal kan achterblijven.
public enum Taal {
    /// false = Nederlands, true = Engels.
    ///
    /// Eén schakelaar voor het hele programma, net als in de C#-versie. Het
    /// scherm schrijft hem en de speeltaak leest hem, en die twee draaien niet
    /// op dezelfde plek — vandaar het slot. Het gaat om één jaknikker, dus dat
    /// kost niets.
    nonisolated(unsafe) private static var _engels = false
    private static let slot = NSLock()

    public static var engels: Bool {
        get { slot.lock(); defer { slot.unlock() }; return _engels }
        set { slot.lock(); _engels = newValue; slot.unlock() }
    }

    // Niet private: Tactieknamen.swift breidt Taal uit en heeft hem ook nodig.
    static func t(_ nl: String, _ en: String) -> String { engels ? en : nl }

    /// Nederlands als het apparaat daarom vraagt, anders Engels.
    ///
    /// De C#-versie startte altijd in het Nederlands en had `Klaverjas.exe /en`
    /// nodig voor de Engelse. Op de Mac en de telefoon hoort een programma de
    /// taal van het apparaat te volgen; met de schakelaar in beeld kan het
    /// alsnog om.
    public static func engelsVoor(_ voorkeurstalen: [String]) -> Bool {
        guard let eerste = voorkeurstalen.first else { return true }
        // De code kan "nl", "nl-NL" of "nl_BE" zijn; alleen het eerste stuk telt.
        return !eerste.lowercased().hasPrefix("nl")
    }

    /// Zet de taal op grond van de voorkeurstalen van het apparaat. Aanroepen
    /// bij het starten, vóór het eerste scherm.
    public static func kiesStandaardtaal(_ voorkeurstalen: [String] = Locale.preferredLanguages) {
        engels = engelsVoor(voorkeurstalen)
    }

    // ------------------------------------------------------------- menu
    public static var menuSpel: String { t("&Spel", "&Game") }
    public static var menuNieuw: String { t("&Nieuw spel", "&New game") }
    public static var menuDans: String { t("&Kaartendans", "Card &dance") }
    public static var menuAfsluiten: String { t("&Afsluiten", "E&xit") }
    public static var menuOpties: String { t("&Opties", "&Options") }
    public static var menuOrigineel: String { t("Oorspronkelijke &kaarten", "&Original cards") }
    public static var menuGlad: String { t("Kaarten &gladstrijken", "&Smooth the cards") }
    public static var menuDemo: String { t("&Demo (computer speelt beide)", "&Demo (computer plays both)") }
    public static var menuOpenKaart: String { t("Kaarten van &Noord tonen", "Show &North's cards") }
    public static var menuAuto: String { t("&Automatisch doorgaan", "Continue a&utomatically") }
    public static var menuDansAuto: String { t("Kaartendans &bij de start en na drie minuten",
                                               "Card dance at start and after three &minutes") }
    public static var menuTaal: String { t("&Taal", "&Language") }
    public static var menuNederlands: String { "&Nederlands" }
    public static var menuEngels: String { "&English" }

    // ------------------------------------------------------------ scherm
    public static var titel: String { "Klaverjas" }
    public static var troef: String { t("Troef", "Trumps") }
    public static var nogNietBepaald: String { t("nog niet bepaald", "not chosen yet") }
    public static func slagVanAcht(_ n: Int) -> String { t("Slag \(n) van 8", "Trick \(n) of 8") }
    public static var noord: String { t("Noord", "North") }
    public static var zuid: String { t("Zuid", "South") }
    public static var punten: String { t("Punten", "Points") }
    public static var roem: String { t("Roem", "Meld") }
    public static var totaal: String { t("Totaal", "Total") }
    public static var partijen: String { t("Partijen", "Matches") }
    public static var vorigeSlag: String { t("Vorige slag", "Previous trick") }
    public static var klikOfToets: String { t("   -   klik of druk een toets", "   -   click or press a key") }
    public static var welkeTroef: String { t("Welke kleur is troef?", "Which suit is trumps?") }
    public static var kiesDeTroefkleur: String { t("Kies de troefkleur", "Choose the trump suit") }
    public static var jouwBeurt: String { t("Jouw beurt - kies een kaart", "Your turn - pick a card") }

    public static var dansTitel: String { t("Kaartendans  -  klik of druk een toets om te stoppen",
                                            "Card dance  -  click or press a key to stop") }

    private static let kleurenNl = ["Klaver", "Schoppen", "Ruiten", "Harten"]
    private static let kleurenEn = ["Clubs", "Spades", "Diamonds", "Hearts"]

    /// Naam van kleur 0..3 (klaver, schoppen, ruiten, harten).
    public static func kleurNaam(_ kleur: Int) -> String {
        if kleur < 0 || kleur > 3 { return "?" }
        return engels ? kleurenEn[kleur] : kleurenNl[kleur]
    }

    // ------------------------------------------------------------ slagen
    public static func slagVoor(_ slagNr: Int, _ zuidWon: Bool) -> String {
        t("Slag \(slagNr) voor \(zuidWon ? "Zuid" : "Noord")",
          "Trick \(slagNr) to \(zuidWon ? "South" : "North")")
    }

    public static func metRoem(_ roem: Int) -> String { t(", \(roem) roem", ", \(roem) meld") }

    public static func laatsteSlag(_ punten: Int, naRoem: Bool) -> String {
        naRoem
            ? t(" + \(punten) voor de laatste slag", " + \(punten) for the last trick")
            : t(", \(punten) voor de laatste slag", ", \(punten) for the last trick")
    }

    public static var scheiding: String { "   -   " }

    // ------------------------------------------------------- einde spel
    public static func wintDitSpel(_ zuidWon: Bool) -> String {
        t("\(zuidWon ? "Zuid" : "Noord") wint dit spel",
          "\(zuidWon ? "South" : "North") wins this deal")
    }

    public static var tegenpartijNat: String { t(" (tegenpartij is nat)", " (the other side went wet)") }

    public static func standen(_ zuid: Int, _ noord: Int) -> String {
        t("  -  Zuid \(zuid), Noord \(noord)", "  -  South \(zuid), North \(noord)")
    }

    public static var partijUit: String { t("  -  partij uit!", "  -  match over!") }
    public static var spelUit: String { t("Spel uit", "Deal over") }

    // --------------------------------------------------------- meldingen
    public static var kaartLigtOpTafel: String { t("Die kaart ligt op tafel - uit de hand spelen",
                                                   "That card is on the table - play from your hand") }
    public static var kaartZitInHand: String { t("Die kaart zit in je hand - van tafel spelen",
                                                 "That card is in your hand - play from the table") }
    public static var kaartNietSpeelbaar: String { t("Die kaart kun je niet spelen",
                                                     "You cannot play that card") }

    public static func computerVerzaakte(_ tactiek: Int, _ kleur: Int, _ kaart: Teken) -> String {
        t("Fout: de computer verzaakte (tactiek \(tactiek), kaart \(kleurNaam(kleur)) \(kaart)). "
          + "Alle punten gaan naar de tegenpartij.",
          "Error: the computer revoked (tactic \(tactiek), card \(kleurNaam(kleur)) \(kaart)). "
          + "All points go to the other side.")
    }

    // ------------------------------------------------------------ regels
    public static var verkeerdeKaart: String { t("Verkeerde kaart", "Wrong card") }
    public static var moetTroefBekennen: String { t("Je moet troef bekennen", "You must follow trumps") }
    public static var moetOvertroeven: String { t("Je moet overtroeven", "You must overtrump") }
    public static var moetKleurBekennen: String { t("Je moet kleur bekennen", "You must follow suit") }
    public static var moetTroeven: String { t("Je moet troeven", "You must trump") }

    // ------------------------------------------------------ statistieken
    public static var menuStatistieken: String { t("&Statistieken", "&Statistics") }
    public static var statTitel: String { t("Statistieken", "Statistics") }
    public static var statNogNiets: String { t("Nog geen spel gespeeld", "No deal played yet") }
    public static var statSluiten: String { t("Sluiten", "Close") }
    public static var statPartijen: String { t("Partijen gewonnen", "Matches won") }
    public static var statSpellen: String { t("Spellen gewonnen", "Deals won") }
    public static var statKaartpunten: String { t("Kaartpunten", "Card points") }
    public static var statTroefpunten: String { t("Troefpunten", "Trump points") }
    public static var statTroefkaarten: String { t("Troefkaarten", "Trump cards") }
    public static var statRoempunten: String { t("Roempunten", "Meld points") }
    public static var statPit: String { t("Pit", "All eight tricks") }
    public static var statTegenpit: String { t("Tegenpit", "Opponent's slam") }
    public static var statNat: String { t("Nat", "Went wet") }
    public static var statSuperroem: String { t("Superroem (vier gelijke)", "Four of a kind") }
    public static var statStand: String { t("Stand van de partij", "Match score") }
    public static var statTactiek: String { t("Tactiek", "Tactic") }
    public static var statTactiekUitleg: String {
        t("De nummers zijn die uit de broncode van 1994; hoe vaak elke regel is toegepast.",
          "The numbers are those from the 1994 source; how often each rule was applied.")
    }

    // ------------------------------------------------------------ fouten
    public static var foutInSpellogica: String { t("Fout in de speellogica:", "Error in the game logic:") }
    public static var volledigeMeldingIn: String { t("Volledige melding in:", "Full message in:") }
    public static var ietsMisMaarLooptDoor: String { t("Er ging iets mis, maar het spel loopt door.",
                                                       "Something went wrong, but the game continues.") }
    public static var vorigePartijReageertNiet: String {
        t("De vorige partij reageert niet; probeer het zo nog eens.",
          "The previous game is not responding; please try again shortly.")
    }
}
