/// Eén kaart zoals de UI hem moet tekenen.
public struct KaartView: Sendable, Codable {
    public var index = 0        // 0..31, index in kaart[]
    public var naam: Teken = .nul
    public var kleur = 0
    public var open = false     // false = achterkant tonen
    public var klikbaar = false
    public var plek = 0         // 0..3 voor tafelkaarten, anders volgnummer

    public init() {}
}

/// Wat een heel spel opleverde.
///
/// De zin is voor de balk bovenin; de getallen zijn voor het paneel. Ze staan
/// hier bij elkaar omdat `evalueerSpel()` ze allebei uitrekent en daarna zijn
/// tellers op nul zet — daarna is er niets meer te halen.
///
/// De punten en de roem zijn die van dit spel, inclusief de bonus voor pit en
/// tegenpit maar vóór de natregel. Die regel verschuift punten van de ene kant
/// naar de andere; wat elke kant zelf gehaald heeft blijft zo zichtbaar.
public struct SpelUitslag: Sendable, Equatable {
    public let tekst: String
    public let puntenZuid: Int
    public let puntenNoord: Int
    public let roemZuid: Int
    public let roemNoord: Int
    /// De bonus voor alle acht slagen: 100, of 300 bij tegenpit. Nul als er geen
    /// pit was. Hij hoort in dezelfde opsomming als de tien voor de laatste
    /// slag, en die wordt gemaakt vóór dit spel wordt afgesloten — vandaar dat
    /// hij hier mee terugkomt.
    public let pitRoem: Int
    public let tegenpit: Bool
    /// Zie `SpelView.partijUit`/`partijGewonnenDoorZuid`/`partijGelijkspel` —
    /// dezelfde drie velden, hier omdat `evalueerSpel()` ze uitrekent.
    public let partijUit: Bool
    public let partijGewonnenDoorZuid: Bool
    public let partijGelijkspel: Bool

    public init(tekst: String, puntenZuid: Int, puntenNoord: Int,
                roemZuid: Int, roemNoord: Int,
                pitRoem: Int = 0, tegenpit: Bool = false,
                partijUit: Bool = false, partijGewonnenDoorZuid: Bool = false,
                partijGelijkspel: Bool = false) {
        self.tekst = tekst
        self.puntenZuid = puntenZuid
        self.puntenNoord = puntenNoord
        self.roemZuid = roemZuid
        self.roemNoord = roemNoord
        self.pitRoem = pitRoem
        self.tegenpit = tegenpit
        self.partijUit = partijUit
        self.partijGewonnenDoorZuid = partijGewonnenDoorZuid
        self.partijGelijkspel = partijGelijkspel
    }
}

/// Een gespeelde kaart in de huidige of vorige slag.
public struct SlagView: Sendable, Equatable, Codable {
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
public struct SpelView: Sendable, Codable {
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

    /// Wie troef maakte: 1 = Zuid, 2 = Noord, 0 = nog niet bekend.
    ///
    /// In klaverjas is dat "de speler": de kant die troef koos, zijn punten moet
    /// halen en nat gaat als dat niet lukt. De motor houdt het al bij in
    /// `KjState.speler`; het scherm kon er alleen niet bij. Let op: `SlagView.speler`
    /// is iets anders — dat is wie een kaart legde.
    public var troefmaker = 0
    public var slagNr = 0
    public var aanZet = 0            // 1..4, wie moet er spelen
    public var wachtOpSpeler = false // true = de mens is aan zet
    public var troefVraag = false    // true = de mens moet troef kiezen
    /// true = een slag is net afgelopen en er wordt gewacht tot iemand
    /// verder tikt. Anders dan `wachtOpSpeler`/`troefVraag` mag dit áltijd
    /// getikt worden, van welke kant dan ook — bij samenspel dus niet
    /// alleen door wie toevallig de laatste kaart van de slag legde. Zie
    /// `GastheerUi.verder(_:_:)`.
    public var wachtOpVerder = false

    public var puntenZuid = 0, puntenNoord = 0
    public var roemZuid = 0, roemNoord = 0
    public var totaalZuid: Int64 = 0, totaalNoord: Int64 = 0
    public var partijenZuid = 0, partijenNoord = 0

    /// Welke kant "ik" ben op dit toestel: 1 = Zuid, 2 = Noord. Standaard 1 —
    /// tot nu toe was dat altijd zo, dus met deze waarde verandert er niets
    /// aan wat er op het scherm staat. Bij twee toestellen over bluetooth zet
    /// elk toestel dit op zijn eigen kant.
    ///
    /// Alle velden hierboven blijven absoluut (Zuid/Noord) — bewust: `Spoor`,
    /// het statistiekenscherm, `SpelUitslag` en de bestaande proeven lezen ze
    /// allemaal, en ze spiegelen zou daar het foutrapport onleesbaar maken.
    /// De eigenschappen hieronder zijn de vertaling naar perspectief, alleen
    /// voor waar het scherm om vraagt: welke kaarten van mij zijn, en of ik
    /// aan zet ben. De stand (punten, roem, …) en de plek van een slagkaart
    /// op het groene veld blijven met opzet Zuid/Noord, niet "ik/hij" — die
    /// zijn prima leesbaar zonder perspectief en hoeven niet te wisselen.
    public var mijnKant = 1

    private var ikBenZuid: Bool { mijnKant != 2 }

    public var mijnHand: [KaartView] { ikBenZuid ? handZuid : handNoord }
    public var zijnHand: [KaartView] { ikBenZuid ? handNoord : handZuid }
    public var mijnTafel: [KaartView] { ikBenZuid ? tafelZuid : tafelNoord }
    public var zijnTafel: [KaartView] { ikBenZuid ? tafelNoord : tafelZuid }
    public var mijnDicht: [KaartView] { ikBenZuid ? dichtZuid : dichtNoord }
    public var zijnDicht: [KaartView] { ikBenZuid ? dichtNoord : dichtZuid }
    public var mijnOnder: [Bool] { ikBenZuid ? onderZuid : onderNoord }
    public var zijnOnder: [Bool] { ikBenZuid ? onderNoord : onderZuid }

    /// Wat `Pos.handZuid`/`Pos.tafelZuid` tot nu toe letterlijk waren, nu naar
    /// kant vertaald — voor het aantikken en voor `aanZet`-vergelijkingen.
    public var mijnHandPos: Int { ikBenZuid ? Pos.handZuid : Pos.handNoord }
    public var mijnTafelPos: Int { ikBenZuid ? Pos.tafelZuid : Pos.tafelNoord }

    /// Ben ik het die nu een kaart moet leggen? `aanZet` is de Pos-code die de
    /// motor doorgeeft; dat kan mijn hand óf mijn tafel zijn.
    public var benIkAanZet: Bool { aanZet == mijnHandPos || aanZet == mijnTafelPos }

    /// Vertaalt een absolute spelerpositie (`Pos.handZuid`/`handNoord`/
    /// `tafelZuid`/`tafelNoord`, zoals `SlagView.speler` die levert) naar mijn
    /// kant — dezelfde vertaling als hierboven voor hand/tafel/aanZet, maar
    /// dan voor de kaarten die nu middenin het veld liggen. Zonder dit kwam
    /// een net gelegde eigen kaart bij `mijnKant == 2` in het vak van de
    /// tegenstander terecht: `Indeling.veldPlek`/`CompactIndeling.veldPlek`
    /// tekenen `Pos.handZuid`/`tafelZuid` altijd onderaan, precies waar
    /// `mijnHand`/`mijnTafel` ook staan — die twee moeten dus dezelfde kant op
    /// wijzen.
    public func relatieveSpeler(_ absoluut: Int) -> Int {
        guard mijnKant == 2 else { return absoluut }
        switch absoluut {
        case Pos.handZuid: return Pos.handNoord
        case Pos.handNoord: return Pos.handZuid
        case Pos.tafelZuid: return Pos.tafelNoord
        case Pos.tafelNoord: return Pos.tafelZuid
        default: return absoluut
        }
    }

    /// De puntentelling vanaf mijn kant: op elk scherm hoort de eigen speler
    /// onder "Zuid" te staan (zie `mijnKant` hierboven — "Noord is
    /// tegenstander en zuid ben ik"). `puntenZuid`/`puntenNoord` zelf blijven
    /// bewust absoluut; deze berekende ingangen lezen ze alleen in de juiste
    /// volgorde voor de tabel op het scherm.
    public var mijnPunten: Int { ikBenZuid ? puntenZuid : puntenNoord }
    public var zijnPunten: Int { ikBenZuid ? puntenNoord : puntenZuid }
    public var mijnRoem: Int { ikBenZuid ? roemZuid : roemNoord }
    public var zijnRoem: Int { ikBenZuid ? roemNoord : roemZuid }
    public var mijnTotaal: Int64 { ikBenZuid ? totaalZuid : totaalNoord }
    public var zijnTotaal: Int64 { ikBenZuid ? totaalNoord : totaalZuid }
    public var mijnPartijen: Int { ikBenZuid ? partijenZuid : partijenNoord }
    public var zijnPartijen: Int { ikBenZuid ? partijenNoord : partijenZuid }

    /// Wie troef maakte, vanaf mijn kant: 0 = nog niet bekend, 1 = ik, 2 = hij.
    /// `troefmaker` zelf blijft absoluut (1 = Zuid, 2 = Noord).
    public var troefmakerRelatief: Int {
        troefmaker == 0 ? 0 : (troefmaker == mijnKant ? 1 : 2)
    }

    public var status = ""
    public var melding = ""

    /// true zodra het spel is afgerekend: de punten en de roem hieronder zijn
    /// dan de eindstand van dit spel, niet een tussenstand.
    public var spelUit = false

    /// true zodra met dít spel ook de partij (1500 punten) klaar is — alleen
    /// geldig samen met `spelUit`, nooit los. Bepaalt of het scherm het grote
    /// partij-scherm toont in plaats van de gewone "Spel uit"-regel.
    public var partijUit = false
    /// Wie de partij won, absoluut (niet naar perspectief vertaald — zie
    /// `partijGewonnenDoorMij` hieronder). Alleen betekenisvol als `partijUit`.
    public var partijGewonnenDoorZuid = false
    /// Allebei de kanten kwamen in hetzelfde spel gelijk over de 1500: dan
    /// telt de partij voor beiden mee (zie `KjEngine.evalueerSpel()`), en is
    /// er geen verliezer om te tonen.
    public var partijGelijkspel = false

    /// `partijGewonnenDoorZuid`, vertaald naar perspectief — net als
    /// `mijnPunten` hieronder, maar dan voor de partij-uitslag.
    public var partijGewonnenDoorMij: Bool {
        ikBenZuid ? partijGewonnenDoorZuid : !partijGewonnenDoorZuid
    }

    /// De tellers over de hele sessie, voor het statistiekenscherm.
    public var statistiek = Statistiek()

    /// Welke kant er op dit moment doorrekent in plaats van vuistregels te
    /// volgen. [0] = Zuid, [1] = Noord.
    ///
    /// Wat de motor werkelijk doet, niet wat het scherm gevraagd heeft. Zo is in
    /// beeld te brengen — en te toetsen — dat de gekozen speelwijze echt gebruikt
    /// wordt.
    public var zoekt = [false, false]

    /// Welke kant er op dit moment volgens Claude speelt. Gaat voor `zoekt`.
    public var claude = [false, false]

    public init() {}
}
