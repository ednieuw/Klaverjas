package nl.edsoft.klaverjas

/**
 * De teksten die de engine zelf teruggeeft (regelmeldingen en de uitslagregel).
 * De rest van de schermteksten komt bij M3, als de UI er is.
 */
object Taal {
    /** false = Nederlands, true = Engels. */
    @Volatile
    var engels = false

    internal fun t(nl: String, en: String) = if (engels) en else nl

    private val kleurenNl = arrayOf("Klaver", "Schoppen", "Ruiten", "Harten")
    private val kleurenEn = arrayOf("Clubs", "Spades", "Diamonds", "Hearts")

    /** Naam van kleur 0..3 (klaver, schoppen, ruiten, harten). */
    fun kleurNaam(kleur: Int): String {
        if (kleur < 0 || kleur > 3) return "?"
        return if (engels) kleurenEn[kleur] else kleurenNl[kleur]
    }

    val verkeerdeKaart get() = t("Verkeerde kaart", "Wrong card")
    val moetTroefBekennen get() = t("Je moet troef bekennen", "You must follow trumps")
    val moetOvertroeven get() = t("Je moet overtroeven", "You must overtrump")
    val moetKleurBekennen get() = t("Je moet kleur bekennen", "You must follow suit")
    val moetTroeven get() = t("Je moet troeven", "You must trump")

    fun wintDitSpel(zuidWon: Boolean) =
        t("${if (zuidWon) "Zuid" else "Noord"} wint dit spel",
            "${if (zuidWon) "South" else "North"} wins this deal")

    val tegenpartijNat get() = t(" (tegenpartij is nat)", " (the other side went wet)")

    fun standen(zuid: Int, noord: Int) =
        t("  -  Zuid $zuid, Noord $noord", "  -  South $zuid, North $noord")

    val partijUit get() = t("  -  partij uit!", "  -  match over!")

    // ------------------------------------------------------------ slagen
    fun slagVoor(slagNr: Int, zuidWon: Boolean) =
        t("Slag $slagNr voor ${if (zuidWon) "Zuid" else "Noord"}",
            "Trick $slagNr to ${if (zuidWon) "South" else "North"}")

    fun metRoem(roem: Int) = t(", $roem roem", ", $roem meld")

    fun laatsteSlag(punten: Int, naRoem: Boolean) =
        if (naRoem) t(" + $punten voor de laatste slag", " + $punten for the last trick")
        else t(", $punten voor de laatste slag", ", $punten for the last trick")

    val scheiding get() = "   -   "

    fun voorPit(roem: Int) = t(", $roem voor pit", ", $roem for march")
    fun voorTegenpit(roem: Int) = t(", $roem voor tegenpit", ", $roem for the opponent's march")

    // --------------------------------------------------------- meldingen
    val welkeTroef get() = t("Welke kleur is troef?", "Which suit is trumps?")
    val jouwBeurt get() = t("Jouw beurt - kies een kaart", "Your turn - pick a card")
    /** De wachttekst voor wie niet aan zet is (bij samenspel). */
    val zijnBeurt get() = t("Zijn beurt", "Their turn")
    val kaartLigtOpTafel get() = t("Die kaart ligt op tafel - uit de hand spelen",
        "That card is on the table - play from your hand")
    val kaartZitInHand get() = t("Die kaart zit in je hand - van tafel spelen",
        "That card is in your hand - play from the table")
    val kaartNietSpeelbaar get() = t("Die kaart kun je niet spelen", "You cannot play that card")

    fun computerVerzaakte(tactiek: Int, kleur: Int, kaart: Teken) =
        t("Fout: de computer verzaakte (tactiek $tactiek, kaart ${kleurNaam(kleur)} $kaart). " +
            "Alle punten gaan naar de tegenpartij.",
            "Error: the computer revoked (tactic $tactiek, card ${kleurNaam(kleur)} $kaart). " +
            "All points go to the other side.")

    // ------------------------------------------------------------ scherm
    val titel get() = "Klaverjas"
    val troef get() = t("Troef", "Trumps")
    fun slagVanAcht(n: Int) = t("Slag $n van 8", "Trick $n of 8")
    val noord get() = t("Noord", "North")
    val zuid get() = t("Zuid", "South")
    val spelUit get() = t("Spel uit", "Deal over")
    val tikVerder get() = t("tik om verder te gaan", "tap to continue")
    val kiesDeTroefkleur get() = t("Kies de troefkleur", "Choose the trump suit")
    val troefViaKaart get() = t("of tik een eigen kaart", "or tap one of your own cards")
    val nieuwSpel get() = t("Nieuw spel", "New game")
    val demo get() = t("Demo", "Demo")
    val openKaart get() = t("Open kaart", "Open cards")
    val ronlog get() = t("Ronlog", "Ronlog")

    /** Eén letter, voor waar geen ruimte is: 1 = ik (Zuid), 2 = hij (Noord). */
    fun kantKort(kant: Int) = when (kant) { 1 -> t("Z", "S"); 2 -> "N"; else -> "" }

    /** Het kleurteken zelf; in beide talen hetzelfde. */
    fun kleurTeken(kleur: Int) = when (kleur) {
        0 -> "\u2663"; 1 -> "\u2660"; 2 -> "\u2666"; 3 -> "\u2665"; else -> ""
    }

    /** Nederlands als het apparaat daarom vraagt, anders Engels. */
    fun engelsVoor(voorkeurstalen: List<String>): Boolean {
        val eerste = voorkeurstalen.firstOrNull() ?: return true
        return !eerste.lowercase().startsWith("nl")
    }

    // ------------------------------------------------------- samen spelen
    val menuSamenSpelen get() = t("Samen spelen", "Play together")
    val duoRechtenGeweigerd get() = t("Zonder toestemming voor Bluetooth kan er niet samen gespeeld worden. Geef die toestemming in de instellingen van de telefoon.",
        "Playing together needs permission to use Bluetooth. Grant it in the phone's settings.")
    /** Kop boven de lijst met bewaarde samenspel-partners in het statistiekenblad. */
    val statSamenspel get() = t("Samen gespeeld", "Played together")
    val statPartnerWissen get() = t("Verwijderen", "Remove")
    fun statPartnerWissenZeker(naam: String) = t("$naam verwijderen?", "Remove $naam?")
    val duoMijnNaam get() = t("Mijn naam (voor de lijst van de ander)", "My name (shown to the other player)")
    val duoNaamLeeg get() = t("naam van deze telefoon", "name of this phone")
    val duoMetWie get() = t("Met wie speel je?", "Who are you playing with?")
    val duoMetWieUitleg get() = t("Onder deze naam wordt jullie onderlinge score bewaard. Een iPhone geeft zijn eigen naam niet door; kies er zelf een.",
        "Your shared score is kept under this name. An iPhone does not share its own name, so pick one.")
    val duoOk get() = t("OK", "OK")
    val duoTitel get() = t("Samen spelen", "Play together")
    val duoStopSamen get() = t("Stop samen", "Stop together")
    val duoUitleg get() = t("Eén toestel stelt zich open, het andere zoekt.", "One device opens up, the other searches.")
    val duoOpenstellen get() = t("Openstellen", "Open up")
    val duoZoeken get() = t("Zoeken", "Search")
    val duoOpnieuw get() = t("Opnieuw proberen", "Try again")
    val duoAnnuleren get() = t("Annuleren", "Cancel")
    val duoBegroeten get() = t("Verbonden, spel wordt klaargezet…", "Connected, setting up the game…")
    fun duoAndereVersie(versie: Int) =
        t("De andere app praat een andere versie van het protocol ($versie) - installeer bij allebei de nieuwste versie.",
            "The other app speaks a different protocol version ($versie) - install the latest version on both.")
    val duoOnverwacht get() = t("Er kwam iets onverwachts binnen tijdens het verbinden.", "Something unexpected arrived while connecting.")
    val duoVerbindingVerbroken get() = t("Verbinding verbroken", "Connection lost")

    // ----------------------------------------------------------- opties
    val menuOpties get() = t("Opties", "Options")
    val menuStatistieken get() = t("Statistieken", "Statistics")
    val menuSpelregels get() = t("Spelregels", "Rules")
    fun menuVersie(versie: String) = t("Versie $versie", "Version $versie")
    val menuDemo get() = t("Demo (computer speelt beide)", "Demo (computer plays both)")
    val menuOpenKaart get() = t("Kaarten van Noord tonen", "Show North's cards")
    val menuAuto get() = t("Automatisch doorgaan", "Continue automatically")
    val menuTaal get() = t("Taal", "Language")
    val menuSpeelwijze get() = t("Speelwijze", "Playing style")
    val menuNoordSpeelt get() = t("Noord speelt", "North plays")
    val menuZuidSpeelt get() = t("Zuid speelt", "South plays")
    val menuAiEd get() = t("Ednieuw \u2014 vuistregels", "Ednieuw \u2014 rules of thumb")
    val menuAiClaude get() = t("Claude \u2014 brute force", "Claude \u2014 brute force")
    val menuAiLoggen get() = t("Ronlog \u2014 rekent zetten door", "Ronlog \u2014 searches ahead")

    // ------------------------------------------------------ statistieken
    val statTitel get() = t("Statistieken", "Statistics")
    val statNogNiets get() = t("Nog geen spel gespeeld", "No deal played yet")
    val statSluiten get() = t("Sluiten", "Close")
    val statWissen get() = t("Wissen", "Reset")
    val statWissenZeker get() = t("Alles wissen?", "Reset everything?")
    val statWissenJa get() = t("Ja", "Yes")
    val statWissenNee get() = t("Nee", "No")
    val statPartijen get() = t("Partijen gewonnen", "Matches won")
    val statSpellen get() = t("Spellen gewonnen", "Deals won")
    val statKaartpunten get() = t("Kaartpunten", "Card points")
    val statTroefpunten get() = t("Troefpunten", "Trump points")
    val statTroefkaarten get() = t("Troefkaarten", "Trump cards")
    val statRoempunten get() = t("Roempunten", "Meld points")
    val statPit get() = t("Pit", "March")
    val statTegenpit get() = t("Tegenpit", "Opponent's march")
    val statNat get() = t("Nat", "Went wet")
    val statSuperroem get() = t("Superroem (vier gelijke)", "Four of a kind")
    val statStand get() = t("Stand huidige partij", "Current match score")
    val statTactiek get() = t("Tactiek", "Tactic")
    val statTactiekUitleg get() = t("De nummers zijn die uit de broncode van 1994; hoe vaak elke regel is toegepast.",
        "The numbers are those from the 1994 source; how often each rule was applied.")
    /** Tactiek 70 heeft geen nummer uit 1994: de zoekende speler rekent de zet door. */
    /** Tactiek 71 is van Claude. */
    val statTactiekClaude get() = t("Brute force (Claude)", "Brute force (Claude)")
    val statTactiekZoeken get() = t("Doorgerekend (Ronlog)", "Searched ahead (Ronlog)")

    // -------------------------------------------------- vorige slag / partij
    val vorigeSlag get() = t("Vorige slag", "Previous trick")
    val partijGewonnen get() = t("Partij gewonnen!", "Match won!")
    val partijVerloren get() = t("Partij verloren", "Match lost")
    val partijGelijk get() = t("Partij gelijk!", "Match tied!")
    fun partijStand(mijn: Int, zijn: Int) = t("$mijn - $zijn in partijen", "$mijn - $zijn in matches")

    // ----------------------------------------------------- snel spelen
    val menuSnel get() = t("Snel spelen zonder kaarten", "Play fast without cards")
    val snelBezig get() = t("Bezig met snel spelen\u2026", "Playing fast\u2026")
    fun snelSpellen(n: Long) = t("$n spellen gespeeld", "$n deals played")
    val snelUitzetten get() = t("Stoppen", "Stop")
}
