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
    public static var menuSamenSpelen: String { t("Samen spelen", "Play together") }
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

    /// Eén letter, voor waar geen ruimte is. Apart en niet de eerste letter van
    /// `noord`/`zuid`: in het Engels zijn South en North allebei niet wat je zou
    /// afsnijden, en bij een derde taal gaat afsnijden helemaal mis.
    public static func kantKort(_ kant: Int) -> String {
        switch kant {
        case 1: return t("Z", "S")
        case 2: return t("N", "N")
        default: return ""
        }
    }
    public static var punten: String { t("Punten", "Points") }
    public static var roem: String { t("Roem", "Meld") }
    public static var totaal: String { t("Totaal", "Total") }
    public static var partijen: String { t("Partijen", "Matches") }
    public static var vorigeSlag: String { t("Vorige slag", "Previous trick") }
    /// De aansporing om verder te gaan. Zonder de streepjes ervoor: die stonden
    /// er om hem van de melding te scheiden, maar hij staat nu apart en mag
    /// wegvallen als er geen ruimte is.
    public static var klikOfToets: String { t("klik of druk een toets", "click or press a key") }
    /// Op een aanraakscherm is er geen toets om te drukken, en is de ruimte
    /// krap. Kort houden.
    public static var tikVerder: String { t("tik om verder te gaan", "tap to continue") }
    public static var welkeTroef: String { t("Welke kleur is troef?", "Which suit is trumps?") }
    public static var kiesDeTroefkleur: String { t("Kies de troefkleur", "Choose the trump suit") }

    /// Onder de vier troefknoppen. Zonder deze regel vindt niemand de tweede
    /// manier om te kiezen: een kaart aantikken laat zich niet raden.
    public static var troefViaKaart: String {
        t("of tik een eigen kaart", "or tap one of your own cards")
    }
    public static var jouwBeurt: String { t("Jouw beurt - kies een kaart", "Your turn - pick a card") }
    /// Bij samenspel: de andere kant is aan zet, niet ik. Zonder dit bleef op
    /// het wachtende scherm "Jouw beurt" staan van de vorige eigen kaart.
    public static var zijnBeurt: String { t("Zijn beurt", "Their turn") }

    public static var dansTitel: String { t("Kaartendans  -  klik of druk een toets om te stoppen",
                                            "Card dance  -  click or press a key to stop") }

    private static let kleurenNl = ["Klaver", "Schoppen", "Ruiten", "Harten"]
    private static let kleurenEn = ["Clubs", "Spades", "Diamonds", "Hearts"]

    /// Naam van kleur 0..3 (klaver, schoppen, ruiten, harten).
    public static func kleurNaam(_ kleur: Int) -> String {
        if kleur < 0 || kleur > 3 { return "?" }
        return engels ? kleurenEn[kleur] : kleurenNl[kleur]
    }

    /// Het kleurteken zelf. Sneller te lezen dan de naam, en in beide talen
    /// hetzelfde — daarom niet door `t()` heen.
    public static func kleurTeken(_ kleur: Int) -> String {
        switch kleur {
        case 0: return "\u{2663}"    // klaver
        case 1: return "\u{2660}"    // schoppen
        case 2: return "\u{2666}"    // ruiten
        case 3: return "\u{2665}"    // harten
        default: return ""
        }
    }

    /// Is dit een rode kleur? Voor het scherm, dat ruiten en harten rood zet.
    public static func kleurIsRood(_ kleur: Int) -> Bool { kleur == 2 || kleur == 3 }

    /// Teken en naam achter elkaar, zoals boven in het scherm.
    public static func kleurMetTeken(_ kleur: Int) -> String {
        if kleur < 0 || kleur > 3 { return kleurNaam(kleur) }
        return kleurTeken(kleur) + " " + kleurNaam(kleur)
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

    /// Alle acht slagen, in dezelfde opsomming als de tien voor de laatste
    /// slag: "Slag 8 voor Zuid, 10 voor de laatste slag, 100 voor pit". Tussen
    /// haakjes achteraan las het als een voetnoot, terwijl het gewoon punten
    /// zijn die je erbij krijgt.
    ///
    /// In het Engels heet alle acht slagen halen een *march*. Dat woord staat
    /// hier omdat "for all eight tricks" de regel te lang maakt; de handleiding
    /// legt het uit.
    public static func voorPit(_ roem: Int) -> String {
        t(", \(roem) voor pit", ", \(roem) for march")
    }
    /// Alle acht slagen terwijl de tegenpartij troef maakte.
    public static func voorTegenpit(_ roem: Int) -> String {
        t(", \(roem) voor tegenpit", ", \(roem) for the opponent's march")
    }

    public static func standen(_ zuid: Int, _ noord: Int) -> String {
        t("  -  Zuid \(zuid), Noord \(noord)", "  -  South \(zuid), North \(noord)")
    }

    public static var partijUit: String { t("  -  partij uit!", "  -  match over!") }
    public static var spelUit: String { t("Spel uit", "Deal over") }

    // ------------------------------------------------- partijscherm (splash)
    public static var partijGewonnen: String { t("Partij gewonnen!", "Match won!") }
    public static var partijVerloren: String { t("Partij verloren", "Match lost") }
    public static var partijGelijk: String { t("Partij gelijk!", "Match tied!") }
    public static func partijStand(_ mijn: Int, _ zijn: Int) -> String {
        t("\(mijn) - \(zijn) in partijen", "\(mijn) - \(zijn) in matches")
    }

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
    public static var menuSpelregels: String { t("Spelregels", "Rules") }
    /// Boven `CFBundleShortVersionString` (Xcode's "Version"), in het
    /// optieblad. `\(versie)` komt van het aanroepende scherm — `Taal` zelf
    /// weet niets van `Bundle`.
    public static func menuVersie(_ versie: String) -> String {
        t("Versie \(versie)", "Version \(versie)")
    }

    // Samen spelen over bluetooth (fase 4 uit het bluetooth-plan).
    public static var duoTitel: String { t("Samen spelen", "Play together") }
    /// De knop "Samen spelen" zelf wordt dit zolang er een verbinding is —
    /// zodat er een nette, met opzet getikte manier is om af te sluiten,
    /// naast een verbinding die vanzelf wegvalt.
    public static var duoStopSamen: String { t("Stop samen", "Stop together") }
    public static var duoUitleg: String {
        t("Eén toestel stelt zich open, het andere zoekt.",
          "One device opens up, the other searches.")
    }
    /// Het veld in het verbindscherm: de naam waaronder de ander jou in zijn lijst "samen gespeeld" ziet.
    /// Nodig omdat iOS apps sinds versie 16 alleen nog "iPhone" als toestelnaam geeft.
    public static var duoMijnNaam: String { t("Mijn naam (voor de lijst van de ander)", "My name (shown to the other player)") }
    public static var duoNaamLeeg: String { t("naam van dit toestel", "name of this device") }
    public static var duoOpenstellen: String { t("Openstellen", "Open up") }
    public static var duoZoeken: String { t("Zoeken", "Search") }
    public static var duoOpnieuw: String { t("Opnieuw proberen", "Try again") }
    public static var duoAnnuleren: String { t("Annuleren", "Cancel") }
    public static var duoBegroeten: String { t("Verbonden, spel wordt klaargezet…", "Connected, setting up the game…") }
    public static func duoAndereVersie(_ versie: Int) -> String {
        t("De andere app praat een andere versie van het protocol (\(versie)) — installeer bij allebei de nieuwste versie.",
          "The other app speaks a different protocol version (\(versie)) — install the latest version on both.")
    }
    public static var duoOnverwacht: String {
        t("Er kwam iets onverwachts binnen tijdens het verbinden.",
          "Something unexpected arrived while connecting.")
    }
    /// De partij stopte omdat de verbinding tijdens het spel wegviel — niet
    /// tijdens het verbinden zelf (`duoOnverwacht`/`duoAndereVersie`), maar
    /// erna. Op beide schermen, gastheer en gast: geen van beide hoort
    /// zomaar te blijven doorspelen of stil te blijven staan zonder te
    /// zeggen waarom.
    public static var duoVerbindingVerbroken: String { t("Verbinding verbroken", "Connection lost") }
    public static var statTitel: String { t("Statistieken", "Statistics") }
    public static var statNogNiets: String { t("Nog geen spel gespeeld", "No deal played yet") }
    public static var statSluiten: String { t("Sluiten", "Close") }
    public static var statWissen: String { t("Wissen", "Reset") }
    /// Wissen raakt alleen de eigen tellingen; de samenspel-partners staan er los onder en hebben elk hun
    /// eigen prullenbak. Zo kost een foutje nooit alles tegelijk.
    public static var statWissenZeker: String {
        t("Huidige statistiek wissen?", "Reset the current statistics?")
    }
    /// Eén samenspel-partner uit de lijst halen (zonder de rest aan te raken).
    public static var statPartnerWissen: String { t("Verwijderen", "Remove") }
    public static func statPartnerWissenZeker(_ naam: String) -> String {
        t("\(naam) verwijderen?", "Remove \(naam)?")
    }
    public static var statWissenJa: String { t("Ja", "Yes") }
    public static var statWissenNee: String { t("Nee", "No") }
    public static var statPartijen: String { t("Partijen gewonnen", "Matches won") }
    public static var statSpellen: String { t("Spellen gewonnen", "Deals won") }
    public static var statKaartpunten: String { t("Kaartpunten", "Card points") }
    public static var statTroefpunten: String { t("Troefpunten", "Trump points") }
    public static var statTroefkaarten: String { t("Troefkaarten", "Trump cards") }
    public static var statRoempunten: String { t("Roempunten", "Meld points") }
    public static var statPit: String { t("Pit", "March") }
    public static var statTegenpit: String { t("Tegenpit", "Opponent's march") }
    public static var statNat: String { t("Nat", "Went wet") }
    public static var statSuperroem: String { t("Superroem (vier gelijke)", "Four of a kind") }
    public static var statStand: String { t("Stand huidige partij", "Current match score") }
    /// Kop boven de lijst met bewaarde samenspel-partners
    /// (`SpelModel.alleBewaardeDuoTellingen()`) — elk met zijn eigen,
    /// losstaande score, zie `Bewaarplaats.schrijfDuo`.
    public static var statSamenspel: String { t("Samen gespeeld", "Played together") }
    public static var statTactiek: String { t("Tactiek", "Tactic") }
    public static var statTactiekUitleg: String {
        t("De nummers zijn die uit de broncode van 1994; hoe vaak elke regel is toegepast.",
          "The numbers are those from the 1994 source; how often each rule was applied.")
    }
    /// Tactiek 70 heeft geen nummer uit 1994: de zoekende speler rekent de zet
    /// door in plaats van een regel toe te passen.
    public static var statTactiekZoeken: String {
        t("Doorgerekend (Ronlog)", "Searched ahead (Ronlog)")
    }
    /// Tactiek 71 is van Claude, die het hele spel een aantal keer doorspeelt.
    public static var statTactiekClaude: String {
        t("Brute force (Claude)", "Brute force (Claude)")
    }

    // ------------------------------------------------------- speelwijze
    public static var menuSpeelwijze: String { t("Speelwijze", "Playing style") }
    public static var menuNoordSpeelt: String { t("Noord speelt", "North plays") }
    public static var menuZuidSpeelt: String { t("Zuid speelt", "South plays") }
    public static var menuAiEd: String { t("Ednieuw \u{2014} vuistregels", "Ednieuw \u{2014} rules of thumb") }
    public static var menuAiLoggen: String {
        t("Ronlog \u{2014} rekent zetten door", "Ronlog \u{2014} searches ahead")
    }
    public static var menuAiClaude: String { t("Claude \u{2014} brute force", "Claude \u{2014} brute force") }

    /// De naam van de speelwijze van één kant, uit wat de motor werkelijk doet.
    public static func speelwijzeNaam(claude: Bool, zoekt: Bool) -> String {
        claude ? menuAiClaude : (zoekt ? menuAiLoggen : menuAiEd)
    }

    // ----------------------------------------------------- snel spelen
    public static var menuSnel: String { t("Snel spelen zonder kaarten", "Play fast without cards") }
    public static var snelBezig: String { t("Bezig met snel spelen\u{2026}", "Playing fast\u{2026}") }
    public static func snelSpellen(_ n: Int) -> String {
        t("\(n) spellen gespeeld", "\(n) deals played")
    }
    public static var snelUitzetten: String { t("Stoppen", "Stop") }
    public static func snelKlaar(_ n: Int) -> String {
        t("Gestopt na \(n) spellen", "Stopped after \(n) deals")
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
