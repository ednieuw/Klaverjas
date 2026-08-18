/// Eén kaart zoals de UI hem moet tekenen.
public struct KaartView: Sendable {
    public var index = 0        // 0..31, index in kaart[]
    public var naam: Teken = .nul
    public var kleur = 0
    public var open = false     // false = achterkant tonen
    public var klikbaar = false
    public var plek = 0         // 0..3 voor tafelkaarten, anders volgnummer

    public init() {}
}

/// Een gespeelde kaart in de huidige of vorige slag.
public struct SlagView: Sendable, Equatable {
    public let kleur: Int
    public let naam: Teken
    public let speler: Int
    public let tactiek: Int

    public init(kleur: Int, naam: Teken, speler: Int, tactiek: Int) {
        self.kleur = kleur
        self.naam = naam
        self.speler = speler
        self.tactiek = tactiek
    }
}

/// Wat één slag opleverde voor de winnaar ervan.
/// - punten: kaartpunten van de vier kaarten samen.
/// - roem: roem uit opeenvolgende kaarten, stuk of vier gelijke.
/// - laatsteSlag: 10 punten voor de achtste slag, anders 0.
public struct SlagUitslag: Sendable, Equatable {
    public let punten: Int
    public let roem: Int
    public let laatsteSlag: Int

    public init(punten: Int, roem: Int, laatsteSlag: Int) {
        self.punten = punten
        self.roem = roem
        self.laatsteSlag = laatsteSlag
    }
}

/// Momentopname van de speltoestand. De speellogica draait op een eigen
/// uitvoeringscontext; de UI tekent uitsluitend uit zo'n momentopname, zodat er
/// geen races op gedeelde toestand kunnen ontstaan.
public struct SpelView: Sendable {
    public var handZuid: [KaartView] = []
    public var handNoord: [KaartView] = []
    public var tafelZuid: [KaartView] = []
    public var tafelNoord: [KaartView] = []
    public var dichtZuid: [KaartView] = []
    public var dichtNoord: [KaartView] = []

    /// Per tafelplek 0..3: ligt daar nog een dichte kaart onder? Dit komt uit
    /// tZuid[]/tNoord[] van de engine. Het aantal dichte kaarten alleen is niet
    /// genoeg: welke plek nog gedekt is, staat er los van.
    public var onderZuid = [Bool](repeating: false, count: 4)
    public var onderNoord = [Bool](repeating: false, count: 4)
    public var slag: [SlagView] = []
    public var vorigeSlag: [SlagView] = []

    public var troef = 999
    public var slagNr = 0
    public var aanZet = 0            // 1..4, wie moet er spelen
    public var wachtOpSpeler = false // true = de mens is aan zet
    public var troefVraag = false    // true = de mens moet troef kiezen

    public var puntenZuid = 0, puntenNoord = 0
    public var roemZuid = 0, roemNoord = 0
    public var totaalZuid: Int64 = 0, totaalNoord: Int64 = 0
    public var partijenZuid = 0, partijenNoord = 0

    public var status = ""
    public var melding = ""

    /// true zodra het spel is afgerekend: de punten en de roem hieronder zijn
    /// dan de eindstand van dit spel, niet een tussenstand.
    public var spelUit = false

    /// De tellers over de hele sessie, voor het statistiekenscherm.
    public var statistiek = Statistiek()

    public init() {}
}
