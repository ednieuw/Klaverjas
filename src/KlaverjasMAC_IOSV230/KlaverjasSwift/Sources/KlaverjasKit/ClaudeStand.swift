/// Een compacte, snelle simulatie van één spel klaverjas voor de speelwijze Claude.
///
/// Los van `KjEngine`, die met globale toestand en C-strings werkt en daardoor te traag is om
/// tienduizenden keren door te rekenen. De regels zijn dezelfde: de proeven leggen de
/// regelcontrole en de puntentelling naast die van de engine.
///
/// Kaarten zijn getallen 0..31: kleur * 8 + plek in "AHVBT987" (zoals `KjState.kaartNr`). Een
/// stapel is een bitmasker. Per slag speelt elke kant één kaart uit zijn hand en één van zijn tafel;
/// de uitkomer kiest welke stapel hij het eerst speelt. De volgorde ligt vast: uitkomer, tafel van de
/// tegenstander, andere stapel van de uitkomer, hand van de tegenstander.
///
/// Port van ClaudeStand.kt uit de Android-versie; de twee horen bij dezelfde invoer dezelfde
/// uitkomst te geven (zie `ClaudeTests`).
enum ClaudeTabel {
    /// Sterkte binnen de kleur: hoger is sterker. Index = plek in "AHVBT987".
    private static let krachtNorm = [7, 5, 4, 3, 6, 2, 1, 0]   // A H V B T 9 8 7 -> ATHVB987
    private static let krachtTroef = [5, 3, 2, 7, 4, 6, 1, 0]  // -> B9ATHV87
    private static let puntNorm = [11, 4, 3, 2, 10, 0, 0, 0]
    private static let puntTroef = [11, 4, 3, 20, 10, 14, 0, 0]

    @inline(__always) static func kleur(_ c: Int) -> Int { c >> 3 }
    @inline(__always) static func plek(_ c: Int) -> Int { c & 7 }
    @inline(__always) static func kracht(_ c: Int, _ troef: Int) -> Int {
        kleur(c) == troef ? krachtTroef[plek(c)] : krachtNorm[plek(c)]
    }
    @inline(__always) static func punten(_ c: Int, _ troef: Int) -> Int {
        kleur(c) == troef ? puntTroef[plek(c)] : puntNorm[plek(c)]
    }

    /// Alle kaarten van een kleur als masker.
    @inline(__always) static func kleurMasker(_ k: Int) -> Int { 0xFF << (8 * k) }

    /// Het kaartnummer van (kleur, naam), of -1.
    static func kaartNr(_ kleur: Int, _ naam: Teken) -> Int {
        guard let p = KjState.rangRoem.firstIndex(of: naam), kleur >= 0, kleur <= 3 else { return -1 }
        return kleur * 8 + p
    }

    static func naam(_ c: Int) -> Teken { KjState.rangRoem[plek(c)] }

    /// Roem van de kaarten van één kleur in één slag, als in `bepaalRoemPunten()`: drie opeenvolgend
    /// 20, vier opeenvolgend 50, en heer plus vrouw van troef (het stuk) 20 erbij.
    /// `gevonden`: bit p gezet als de kaart op plek p van deze kleur in de slag ligt.
    static func roemKleur(_ gevonden: Int, _ kleur: Int, _ troef: Int) -> Int {
        var i = 0, j = 0
        for p in 0..<8 {
            if gevonden & (1 << p) != 0 { i += 1; if i > j { j = i } } else { i = 0 }
        }
        var roem = 0
        if kleur == troef && gevonden & 0b110 == 0b110 { roem = 20 }   // plek 1 = heer, plek 2 = vrouw
        if j == 3 { roem += 20 }
        if j == 4 { roem += 50 }
        return roem
    }
}

final class ClaudeStand {
    var troef = 0
    /// Welke kant troef maakte: 0 = Zuid, 1 = Noord.
    var speler = 0
    var hand = [0, 0]
    /// Open tafelkaart per plek (of -1) en de kaart die er nog onder ligt (of -1).
    var open = [[Int]](repeating: [-1, -1, -1, -1], count: 2)
    var dicht = [[Int]](repeating: [-1, -1, -1, -1], count: 2)
    var punten = [0, 0]
    var roem = [0, 0]
    var slagNr = 1
    var leider = 0
    var gespeeld = 0

    // De slag die nu ligt.
    var slag = [0, 0, 0, 0]
    var wie = [0, 0, 0, 0]
    var fase = 0
    private var leiderUitHand = true

    /// Winnende kaart (index in `slag`) van wat er nu ligt.
    private var beste = 0

    func kopieer() -> ClaudeStand {
        let s = ClaudeStand()
        s.zet(self)
        return s
    }

    /// Kopieert elk veld los, zodat er niets nieuw aangemaakt wordt: dit gebeurt tienduizenden keren.
    func zet(_ o: ClaudeStand) {
        troef = o.troef; speler = o.speler; slagNr = o.slagNr; leider = o.leider
        gespeeld = o.gespeeld; fase = o.fase; leiderUitHand = o.leiderUitHand; beste = o.beste
        for k in 0..<2 {
            hand[k] = o.hand[k]; punten[k] = o.punten[k]; roem[k] = o.roem[k]
            for i in 0..<4 { open[k][i] = o.open[k][i]; dicht[k][i] = o.dicht[k][i] }
        }
        for i in 0..<4 { slag[i] = o.slag[i]; wie[i] = o.wie[i] }
    }

    func tafelMasker(_ kant: Int) -> Int {
        var m = 0
        for i in 0..<4 { let c = open[kant][i]; if c >= 0 { m |= 1 << c } }
        return m
    }

    /// Wie is er nu aan zet (0 = Zuid, 1 = Noord)?
    var aanZet: Int { (fase == 0 || fase == 2) ? leider : 1 - leider }

    /// Uit welke stapel moet de volgende kaart komen? true = hand.
    var uitHand: Bool {
        switch fase {
        case 1: return false               // de tafel van de tegenstander
        case 2: return !leiderUitHand      // de andere stapel van de uitkomer
        default: return true               // fase 3: de hand van de tegenstander
        }
    }

    /// De kaarten waaruit de speler die aan zet is mag kiezen, regels meegerekend.
    func toegestaan() -> Int {
        let kant = aanZet
        let pile: Int
        switch fase {
        case 0: pile = hand[kant] | tafelMasker(kant)               // de uitkomer kiest vrij
        case 1: pile = tafelMasker(kant)
        case 2: pile = leiderUitHand ? tafelMasker(kant) : hand[kant]
        default: pile = hand[kant]
        }
        if fase == 0 || pile == 0 { return pile }
        return legaal(pile, kant)
    }

    private func legaal(_ pile: Int, _ kant: Int) -> Int {
        let led = ClaudeTabel.kleur(slag[0])
        let tr = ClaudeTabel.kleurMasker(troef)
        var troefOp = false
        var hoogsteTroef = -1
        for i in 0..<fase where ClaudeTabel.kleur(slag[i]) == troef {
            troefOp = true
            let k = ClaudeTabel.kracht(slag[i], troef)
            if k > hoogsteTroef { hoogsteTroef = k }
        }
        let troeven = pile & tr
        if led == troef {
            if troeven != 0 {
                let hoger = hogerDan(troeven, hoogsteTroef)
                return hoger != 0 ? hoger : troeven    // overtroeven als het kan
            }
            return pile
        }
        let volgen = pile & ClaudeTabel.kleurMasker(led)
        if volgen != 0 { return volgen }               // kleur bekennen
        if winnaarKant == kant { return pile }         // de slag staat al op eigen naam
        if troeven != 0 {
            if troefOp {
                let hoger = hogerDan(troeven, hoogsteTroef)
                return hoger != 0 ? hoger : pile
            }
            return troeven                             // moet troeven
        }
        return pile
    }

    private func hogerDan(_ masker: Int, _ kracht: Int) -> Int {
        var uit = 0
        var m = masker
        while m != 0 {
            let c = m.trailingZeroBitCount
            m &= m - 1
            if ClaudeTabel.kracht(c, troef) > kracht { uit |= 1 << c }
        }
        return uit
    }

    /// Welke kant heeft de slag op dit moment?
    var winnaarKant: Int { wie[beste] }

    var winnendeKaart: Int { slag[beste] }

    /// Speelt kaart `c` voor degene die aan zet is.
    func speel(_ c: Int) {
        let kant = aanZet
        let bit = 1 << c
        if hand[kant] & bit != 0 {
            hand[kant] &= ~bit
            if fase == 0 { leiderUitHand = true }
        } else {
            for i in 0..<4 where open[kant][i] == c { open[kant][i] = -1; break }
            if fase == 0 { leiderUitHand = false }
        }
        slag[fase] = c
        wie[fase] = kant
        if fase > 0 && verslaat(c, slag[beste]) { beste = fase }
        fase += 1
        gespeeld |= bit
        if fase == 4 { slagKlaar() }
    }

    /// Zou `c` de kaart verslaan die nu de slag heeft?
    func verslaatBeste(_ c: Int) -> Bool { verslaat(c, slag[beste]) }

    /// Legt een kaart vast die al gespeeld is (en dus uit zijn stapel is), zoals de kaarten van de
    /// lopende slag bij het opbouwen van de stand uit de engine.
    func legVast(_ c: Int, _ kant: Int, uitHand: Bool) {
        if fase == 0 { leiderUitHand = uitHand }
        slag[fase] = c
        wie[fase] = kant
        if fase > 0 && verslaat(c, slag[beste]) { beste = fase }
        fase += 1
        gespeeld |= 1 << c
    }

    /// Verslaat kaart `a` kaart `b` (die al ligt)?
    private func verslaat(_ a: Int, _ b: Int) -> Bool {
        let ka = ClaudeTabel.kleur(a), kb = ClaudeTabel.kleur(b)
        if ka == kb { return ClaudeTabel.kracht(a, troef) > ClaudeTabel.kracht(b, troef) }
        return ka == troef
    }

    /// Waarde van de slag voor de winnaar: kaartpunten plus roem.
    private func slagKlaar() {
        let w = wie[beste]
        var p = 0
        for i in 0..<4 { p += ClaudeTabel.punten(slag[i], troef) }
        punten[w] += p

        var r = 0
        for k in 0..<4 {
            var gevonden = 0, n = 0
            for i in 0..<4 where ClaudeTabel.kleur(slag[i]) == k {
                gevonden |= 1 << ClaudeTabel.plek(slag[i]); n += 1
            }
            if n > 1 { r += ClaudeTabel.roemKleur(gevonden, k, troef) }
        }
        // Vier gelijke kaarten, over de hele slag.
        let p0 = ClaudeTabel.plek(slag[0])
        if ClaudeTabel.plek(slag[1]) == p0 && ClaudeTabel.plek(slag[2]) == p0 && ClaudeTabel.plek(slag[3]) == p0 {
            r += p0 == 3 ? 200 : 100                   // vier boeren: 200
        }
        roem[w] += r
        if slagNr == 8 { roem[w] += 10 }               // de laatste slag

        // De dichte kaarten onder een gespeelde tafelkaart draaien om.
        for k in 0..<2 {
            for i in 0..<4 where open[k][i] < 0 && dicht[k][i] >= 0 {
                open[k][i] = dicht[k][i]; dicht[k][i] = -1
            }
        }
        leider = w
        fase = 0
        beste = 0
        slagNr += 1
    }

    var klaar: Bool { slagNr > 8 }

    /// De uitslag van dit spel (Zuid, Noord) met pit, tegenpit en nat zoals `evalueerSpel()` ze telt.
    /// Alleen aan te roepen als `klaar`.
    func eindstand() -> (zuid: Int, noord: Int) {
        var r = roem
        for k in 0..<2 where punten[k] == 152 { r[k] += 100 }
        // Tegenpit: alle slagen voor de kant die niet troef maakte.
        if punten[0] == 152 && speler == 1 { r[0] += 200 }
        if punten[1] == 152 && speler == 0 { r[1] += 200 }
        var a = punten[0] + r[0]
        var b = punten[1] + r[1]
        if speler == 0 && a <= b { b += a; a = 0 }     // nat
        if speler == 1 && b <= a { a += b; b = 0 }
        return (a, b)
    }
}
