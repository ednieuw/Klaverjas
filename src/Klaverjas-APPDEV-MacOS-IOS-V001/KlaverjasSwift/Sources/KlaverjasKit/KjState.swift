/// Eén van de 32 kaarten in het spel (struct krts uit KJ.C).
public final class SpeelKaart {
    public var naam: Teken = .nul   // 'A','H','V','B','T','9','8','7'
    public var puntWaarde = 0       // waarde als niet-troef
    public var troefWaarde = 0      // waarde als troef
    public var actWaarde = 0        // actuele waarde, gezet zodra troef bekend is
    public var dichtIkHy = 0        // zie Pos
    public var troef = 0
    public var kleur = 0            // 0=Klaver 1=Schoppen 2=Ruiten 3=Harten

    public init() {}
}

/// De waarden van kaart.dichtIkHy uit het origineel. Dit is de spilvariabele:
/// hij codeert waar een kaart zich bevindt.
public enum Pos {
    public static let dicht = 0       // nog niet uitgedeeld / onbekend
    public static let handZuid = 1    // in de hand van Zuid
    public static let handNoord = 2   // in de hand van Noord
    public static let tafelZuid = 3   // open op tafel bij Zuid
    public static let tafelNoord = 4  // open op tafel bij Noord
    public static let gespeeld = 5    // al gespeeld
    public static let dichtZuid = 33  // dicht onder de tafelkaarten van Zuid
    public static let dichtNoord = 44 // dicht onder de tafelkaarten van Noord
    public static let nieuwZuid = 13  // net omgedraaid, wordt volgende slag tafelZuid
    public static let nieuwNoord = 14 // net omgedraaid, wordt volgende slag tafelNoord
}

/// Kaart in hand/tafel-overzicht met bijbehorende slagkans (struct deck).
public struct Deck {
    public var slagkans = 0
    public var slagkans0 = 0    // slagkans aan het begin van de slag
    public var naam: Teken = .nul
    public var kleur = 0
    public var waarde = 0
    public var troef = 0
    public var gegarandeerd = 0 // slagkans > 95

    public init() {}
}

/// Eén gespeelde kaart binnen een slag (struct slach).
public struct SlagKaart {
    public var kleur = 0
    public var naam: Teken = .nul
    public var troef = 0
    public var speler = 0
    public var kans = 0
    public var waarde = 0
    public var tactiek = 0

    public init() {}
}

/// Alle globale toestand van het originele programma bij elkaar. Het origineel
/// werkt volledig met globals; die structuur is hier bewust overgenomen zodat
/// de vertaling van de speel- en tactiekroutines één-op-één blijft.
public final class KjState {
    public static let slagkansLevel = 15

    // Volgorde van kaarten binnen een kleur, hoog -> laag.
    public static let rangTroef = "B9ATHV87".tekens
    public static let rangNorm = "ATHVB987".tekens
    public static let rangRoem = "AHVBT987".tekens

    // Voor de naam van een kleur: Taal.kleurNaam(), die de gekozen taal volgt.

    public let kaart: [SpeelKaart] = (0..<32).map { _ in SpeelKaart() }
    public var hand = [[Deck]](repeating: [Deck](repeating: Deck(), count: 8), count: 2)
    public var tafel = [[Deck]](repeating: [Deck](repeating: Deck(), count: 8), count: 2)

    /// slag[9][4] uit het origineel, maar plat opgeslagen. Het origineel
    /// indexeert op een paar plaatsen bewust of onbewust buiten de rij
    /// (slag[SLAG][4]); met een platte rij valt dat net als in C door naar
    /// slag[SLAG+1][0], zodat het gedrag identiek blijft in plaats van een
    /// foutmelding te geven.
    private var _slag = [SlagKaart](repeating: SlagKaart(), count: 48)

    public subscript(slag slag: Int, i i: Int) -> SlagKaart {
        get { _slag[slag * 4 + i] }
        set { _slag[slag * 4 + i] = newValue }
    }

    public var deeltabel = [Int](repeating: 0, count: 32)
    public var verzaakt = [[Int]](repeating: [Int](repeating: 0, count: 4), count: 2)
    public var tNoord = [Int](repeating: 0, count: 4)   // ligt er nog een dichte kaart onder?
    public var tZuid = [Int](repeating: 0, count: 4)

    // Kaartverzamelingen als C-strings, per kleur en totaal.
    public let krtWeg = CStr.new2(4, 16)
    public let krtVrij = CStr.new2(4, 16)
    public let krtDicht = CStr.new2(4, 16)
    public let krtTotWeg = CStr(40)
    public let krtTotVrij = CStr(40)
    public let krtTotDicht = CStr(40)

    // [0] = kant van de huidige vrager, [1] = tegenpartij
    public var iKrt = [[Int]](repeating: [Int](repeating: 0, count: 2), count: 4)
    public var iKrtTafel = [[Int]](repeating: [Int](repeating: 0, count: 2), count: 4)
    public let kHand = CStr.new3(2, 4, 16)
    public let kTafel = CStr.new3(2, 4, 16)
    public var iKrtGespeeld = 0

    public var vrager = 0, startVrager = 0
    public var troef = 999
    public var speler = 0
    public var slagNr = 0, slagKrtNo = 0

    public var roem = [Int](repeating: 0, count: 2)
    public var gewonnen = [Int](repeating: 0, count: 2)
    public var puntenSpel = [Int](repeating: 0, count: 2)
    public var puntenTotaalSpel = [Int64](repeating: 0, count: 2) // [0]=Zuid, [1]=Noord

    public var lkaart: Teken = .nul
    public var lkleur = 0
    public var lkaart3: Teken = .nul
    public var lkleur3 = 0
    public var skrt41: Teken = .nul

    public var hoogste = 0
    public var tactiek = 0
    public var tactiek41 = false, tactiekLaag = false, tactiekTT = false

    /// true = beide handen door de computer gespeeld (demo).
    public var comp = false
    /// true = kaarten van de tegenstander verborgen.
    public var dicht = true

    // Statistiek over de hele sessie.
    public var kaartpnt = [Int64](repeating: 0, count: 2)
    public var troefpnt = [Int64](repeating: 0, count: 2)
    public var gewonnenTot = [Int64](repeating: 0, count: 2)
    public var roempnt = [Int64](repeating: 0, count: 2)
    public var troefkrt = [Int64](repeating: 0, count: 2)
    public var pit = [Int64](repeating: 0, count: 2)
    public var tpit = [Int64](repeating: 0, count: 2)
    public var nat = [Int64](repeating: 0, count: 2)
    public var superroem: Int64 = 0
    public var tac = [Int64](repeating: 0, count: 80)

    /// Faculteiten 0..18, gebruikt door guillermie().
    public static let fact: [Double] = [
        1.0, 1.0, 2.0, 6.0, 24.0, 120.0, 720.0, 5040.0, 40320.0, 362880.0,
        3628800.0, 39916800.0, 479001600.0, 6227020800.0, 87178291200.0,
        1307674368000.0, 20922789888000.0, 355687428096000.0, 6402373705728000.0
    ]

    public var rnd: Toevalsreeks

    /// Geen zaad opgegeven: dan varieert het per keer. Wel een zaad: dan speelt
    /// de engine exact dezelfde spellen, en dat is wat de vergelijking met de
    /// C#-versie mogelijk maakt.
    public init(zaad: Int? = nil) {
        if let zaad {
            rnd = Toevalsreeks(UInt32(truncatingIfNeeded: zaad))
        } else {
            rnd = Toevalsreeks(UInt32.random(in: 1...UInt32.max))
        }
    }

    /// Borland random(num): 0 <= resultaat < num, en 0 bij num <= 0.
    public func random(_ num: Int) -> Int { rnd.volgende(num) }

    /// Index in kaart[] van kaart (kleur, naam).
    public static func kaartNr(_ kleur: Int, _ naam: Teken) -> Int {
        CStr.pos(rangRoem, naam) + kleur * 8 - 1
    }
}
