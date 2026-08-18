import CoreGraphics
import KlaverjasKit
import KlaverjasKaarten

/// De indeling voor een smal scherm: de telefoon rechtop.
///
/// De brede indeling zet vier rijen naast een speelveld van 130 bij 230 en
/// heeft daar zo'n duizend punten breedte voor nodig. Een iPhone heeft er
/// vierhonderd. Twee dingen gaan daarom anders:
///
/// * De handen liggen waaiervormig over elkaar. De overlap wordt uit de
///   beschikbare breedte berekend, met de eis dat er van elke kaart genoeg
///   overblijft om hem te herkennen — anders wordt de kaart een maatje kleiner.
/// * Het speelveld is geen liggend vlak van 130 bij 230 meer maar een blok van
///   twee bij twee. De plekken houden hun betekenis: Noord boven, Zuid onder,
///   hand links, tafel rechts, net als in `krtposx`/`krtposy`.
struct CompactIndeling {
    /// Hoeveel van een kaart in de waaier zichtbaar moet blijven. Bij 0,7 zie
    /// je van elke kaart de linker zeventig procent: het hoeksymbool, het
    /// cijfer en bij plaatkaarten een flink stuk van de tekening.
    static let minZichtbaar: CGFloat = 0.7

    let schaal: Int
    let cw: CGFloat
    let ch: CGFloat

    let marge: CGFloat = 10
    let tussen: CGFloat        // verticale ruimte tussen de rijen

    let handSpatie: CGFloat
    let noordHandSpatie: CGFloat
    let tafelSpatie: CGFloat

    let yNoordHand: CGFloat
    let yNoordTafel: CGFloat
    let yZuidTafel: CGFloat
    let yZuidHand: CGFloat
    let veld: CGRect

    let breedte: CGFloat

    /// De lucht tussen de rijen als alles op ware grootte wordt neergezet.
    static let ruimteNatuurlijk: CGFloat = 12

    /// Grootste hele vergroting waarbij de waaier van acht leesbaar blijft.
    ///
    /// Alleen de breedte telt hier mee. Past het in de hoogte niet — een
    /// telefoon in liggende stand, of een smal venster naast een ander — dan
    /// wordt het geheel straks als één blok verkleind. Dat is lelijker dan
    /// kleinere kaarten, maar het snijdt tenminste niets af.
    static func heleSchaal(_ b: CGFloat) -> Int {
        for k in stride(from: 3, through: 1, by: -1) {
            let cw = CGFloat(OrigineleKaarten.breedte * k)
            if cw + 7 * cw * minZichtbaar <= b - 20 { return k }
        }
        return 1
    }

    /// De hoogte die deze indeling op ware grootte nodig heeft.
    static func natuurlijkeHoogte(_ b: CGFloat) -> CGFloat {
        let k = heleSchaal(b)
        let ch = CGFloat(OrigineleKaarten.hoogte * k)
        return 4 * ch + (2 * ch + 8) + 4 * ruimteNatuurlijk
    }

    init(speel: CGRect) {
        let k = CompactIndeling.heleSchaal(speel.width)
        let kaartBreed = CGFloat(OrigineleKaarten.breedte * k)
        let kaartHoog = CGFloat(OrigineleKaarten.hoogte * k)
        let bruikbaar = speel.width - 2 * marge

        // De waaier vult de breedte, maar wordt nooit ijler dan de brede
        // indeling hem zou neerleggen, en nooit zo dicht dat er van een kaart
        // te weinig overblijft om hem te herkennen.
        let spatieVoor = { (aantal: Int, normaal: CGFloat) -> CGFloat in
            guard aantal > 1 else { return normaal }
            let passend = (bruikbaar - kaartBreed) / CGFloat(aantal - 1)
            return min(normaal, max(kaartBreed * CompactIndeling.minZichtbaar, passend))
        }

        // Wat er aan lucht over is, gaat tussen de rijen in — maar met mate.
        // Blijft er dan nog over, dan komt het blok in het midden te staan in
        // plaats van uitgerekt over de hele hoogte.
        let veldHoog = 2 * kaartHoog + 8
        let over = speel.height - (4 * kaartHoog + veldHoog)
        let ruimte = max(CompactIndeling.ruimteNatuurlijk, min(18, over / 5))
        let blokHoog = 4 * kaartHoog + veldHoog + 4 * ruimte
        let boven = max(0, (speel.height - blokHoog) / 2)

        let yNH = speel.minY + boven
        let yNT = yNH + kaartHoog + ruimte
        let yV = yNT + kaartHoog + ruimte
        let yZT = yV + veldHoog + ruimte
        let veldBreed = 2 * kaartBreed + 8

        schaal = k
        cw = kaartBreed
        ch = kaartHoog
        breedte = speel.width
        handSpatie = spatieVoor(8, CGFloat(Indeling.handSpatie(k)))
        noordHandSpatie = spatieVoor(8, CGFloat(Indeling.noordHandSpatie(k)))
        tafelSpatie = spatieVoor(4, CGFloat(Indeling.tafelSpatie(k)))
        tussen = ruimte
        yNoordHand = yNH
        yNoordTafel = yNT
        yZuidTafel = yZT
        yZuidHand = yZT + kaartHoog + ruimte
        veld = CGRect(x: speel.midX - veldBreed / 2, y: yV,
                      width: veldBreed, height: veldHoog)
    }

    /// Waar de kaarten van een rij komen; gecentreerd in plaats van rechts
    /// uitgelijnd, want op een smal scherm valt er niets uit te lijnen.
    func rij(_ aantal: Int, y: CGFloat, spatie: CGFloat) -> [CGRect] {
        guard aantal > 0 else { return [] }
        let breed = spatie * CGFloat(aantal - 1) + cw
        let x = (breedte - breed) / 2
        return (0..<aantal).map {
            CGRect(x: x + CGFloat($0) * spatie, y: y, width: cw, height: ch)
        }
    }

    /// De vier tafelplekken, altijd vier breed ook als er minder open liggen.
    func tafelVak(plek: Int, y: CGFloat) -> CGRect {
        let breed = tafelSpatie * 3 + cw
        let x = (breedte - breed) / 2
        return CGRect(x: x + CGFloat(plek) * tafelSpatie, y: y, width: cw, height: ch)
    }

    /// Plek van de kaart van speler 1..4 in het speelveld van twee bij twee.
    /// Noord boven, Zuid onder; hand links, tafel rechts — dezelfde verdeling
    /// als in het brede scherm.
    func veldPlek(_ speler: Int) -> CGRect {
        let x0 = veld.minX + 4, y0 = veld.minY + 4
        switch speler {
        case Pos.tafelNoord: return CGRect(x: x0, y: y0, width: cw, height: ch)
        case Pos.handNoord:  return CGRect(x: x0 + cw + 4, y: y0, width: cw, height: ch)
        case Pos.handZuid:   return CGRect(x: x0, y: y0 + ch + 4, width: cw, height: ch)
        default:             return CGRect(x: x0 + cw + 4, y: y0 + ch + 4, width: cw, height: ch)
        }
    }
}
