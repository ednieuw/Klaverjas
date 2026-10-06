import CoreGraphics
import KlaverjasKit
import KlaverjasKaarten

/// Waar alles op het speelscherm komt te staan.
///
/// De maten komen uit SpelForm.cs, dat ze op zijn beurt uit KJJ.C haalde: het
/// speelveld van 130 bij 230 met de vier kaartplekken uit legkaart(), en vier
/// rijen die alle tegen dezelfde rechterkant uitgelijnd staan, zoals het
/// origineel ze vanaf x=560 naar links neerlegde.
struct Indeling {
    static let veldBreedte = 130
    static let veldHoogte = 230
    static let veldMarge = 24   // lucht boven en onder het veld samen

    // Afstand tussen twee kaarten in een rij, steeds een veelvoud van de schaal
    // zodat elke kaart op een hele pixel valt. De hand van Noord ligt over
    // elkaar heen, net als in het origineel.
    static func handSpatie(_ k: Int) -> Int { 57 * k }
    static func noordHandSpatie(_ k: Int) -> Int { 46 * k }
    static func tafelSpatie(_ k: Int) -> Int { 70 * k }

    // Scheelt het net te weinig ruimte voor een maat groter, dan mogen de
    // kaarten wat verder over elkaar liggen. Grotere kaarten die elkaar een
    // stukje overlappen lezen beter dan kleine kaarten met lucht ertussen.
    // Van een handkaart blijft minstens driekwart zichtbaar, van een tafelkaart
    // vijfentachtig procent — genoeg om hem te herkennen.
    static let handKrap = 0.75
    static let tafelKrap = 0.85

    static func handRijBreed(_ k: Int, krap: Bool) -> Int {
        let cw = OrigineleKaarten.breedte * k
        let s = krap ? Int(Double(cw) * handKrap) : handSpatie(k)
        return s * 7 + cw
    }

    static func tafelRijBreed(_ k: Int, krap: Bool) -> Int {
        let cw = OrigineleKaarten.breedte * k
        let s = krap ? Int(Double(cw) * tafelKrap) : tafelSpatie(k)
        return s * 3 + cw
    }

    /// Plek van de kaart van speler 1..4 binnen het speelveld.
    static func veldPlek(_ speler: Int, _ k: Int) -> CGPoint {
        switch speler {
        case Pos.handZuid:   return CGPoint(x: 10 * k, y: 135 * k)   // Zuid onderaan
        case Pos.tafelZuid:  return CGPoint(x: 65 * k, y: 95 * k)
        case Pos.tafelNoord: return CGPoint(x: 10 * k, y: 50 * k)    // Noord bovenaan
        default:             return CGPoint(x: 65 * k, y: 10 * k)
        }
    }

    /// De vergroting waarop de brede indeling hier past, of nil als hij niet
    /// past. Past hij niet, dan hoort het smalle scherm het over te nemen;
    /// anders wordt de onderste rij afgesneden.
    static func schaalIndienPassend(_ breedte: CGFloat, _ hoogte: CGFloat) -> Int? {
        passendeSchaal(Int(breedte), Int(hoogte))
    }

    /// Grootste hele vergroting waarbij het speelveld links, vier rijen kaarten
    /// rechts en de breedste rij (acht kaarten in de hand) nog passen.
    static func heleSchaal(_ breedte: Int, _ hoogte: Int) -> Int {
        passendeSchaal(breedte, hoogte) ?? 1
    }

    private static func passendeSchaal(_ breedte: Int, _ hoogte: Int) -> Int? {
        // Ook 1 wordt getoetst. SpelForm.cs telde vanaf 6 tot boven 1 en viel
        // daarna terug op 1 zonder te kijken of dat wel paste — daar kon dat,
        // want er was geen alternatief. Hier is dat er wel: past 1 niet, dan
        // neemt het smalle scherm het over.
        for k in stride(from: 6, through: 1, by: -1) {
            let ch = OrigineleKaarten.hoogte * k
            let handRij = handRijBreed(k, krap: true)
            let tafelRij = tafelRijBreed(k, krap: true)
            let rijenHoog = 4 * ch + 12 * k + 20

            // Speelveld tussen de handen in, links van de tafelrijen.
            let nodigBinnen = (5 * veldHoogte * k + 5 * veldMarge + 2 * ch - 2 * 12 * k + 2) / 3
            let binnen = 40 + max(handRij, veldBreedte * k + 24 + tafelRij) <= breedte
                      && nodigBinnen <= hoogte

            // Of anders links naast alle rijen.
            let buiten = 40 + veldBreedte * k + 24 + handRij <= breedte
                      && rijenHoog <= hoogte

            if binnen || buiten { return k }
        }
        return nil
    }

    let schaal: Int
    let cw: CGFloat
    let ch: CGFloat
    let rijen: CGRect
    let yNoordHand: CGFloat
    let yNoordTafel: CGFloat
    let yZuidTafel: CGFloat
    let yZuidHand: CGFloat
    let veld: CGRect
    let troefRij: CGRect

    /// De rechterkant waar alle rijen tegenaan staan. Niet zomaar de rand van
    /// het speelvlak: blijft er ruimte over, dan komt het geheel in het midden
    /// te staan in plaats van alle leegte aan de linkerkant.
    let rechts: CGFloat
    let spatieHand: CGFloat
    let spatieNoordHand: CGFloat
    let spatieTafel: CGFloat

    init(speel: CGRect) {
        let k = Indeling.heleSchaal(Int(speel.width), Int(speel.height))
        schaal = k
        cw = CGFloat(OrigineleKaarten.breedte * k)
        ch = CGFloat(OrigineleKaarten.hoogte * k)

        let vak = CGRect(x: speel.minX + 20, y: speel.minY,
                         width: speel.width - 40, height: speel.height)
        rijen = vak

        // De rijen krijgen de gewone afstand, tenzij het dan niet past; dan
        // schuiven de kaarten wat verder over elkaar.
        let kaartBreed = CGFloat(OrigineleKaarten.breedte * k)
        let veldBreed = CGFloat(Indeling.veldBreedte * k)

        let spatie = { (aantal: Int, normaal: Int, krap: Double, ruimte: CGFloat) -> CGFloat in
            let passend = (ruimte - kaartBreed) / CGFloat(aantal - 1)
            return min(CGFloat(normaal), max(kaartBreed * krap, passend))
        }
        let sHand = spatie(8, Indeling.handSpatie(k), Indeling.handKrap, vak.width)
        let sNoord = spatie(8, Indeling.noordHandSpatie(k), Indeling.handKrap, vak.width)
        // De tafelrij krijgt niet de volle breedte: links ervan moet het
        // speelveld nog passen. Zonder die aftrek rekt de rij zich uit tot over
        // het veld heen en liggen de kaarten er half overheen.
        let sTafel = spatie(4, Indeling.tafelSpatie(k), Indeling.tafelKrap,
                            vak.width - veldBreed - 24)
        spatieHand = sHand
        spatieNoordHand = sNoord
        spatieTafel = sTafel

        // Wat het geheel breed is, en hoeveel daarvan overblijft.
        let handRij = sHand * 7 + kaartBreed
        let tafelRij = sTafel * 3 + kaartBreed
        let nodigBreed = max(handRij, veldBreed + 24 + tafelRij)
        let rechterkant = vak.maxX - max(0, vak.width - nodigBreed) / 2
        rechts = rechterkant

        // Tussen de twee tafelrijen extra ruimte: daar steken de dichte kaarten
        // naar elkaar toe uit en die mogen elkaar niet raken.
        let extra = CGFloat(12 * k)
        let gap = max(4, (vak.height - 4 * ch - extra) / 5)
        let yNH = vak.minY + gap
        let yNT = yNH + ch + gap
        let yZT = yNT + ch + gap + extra
        yNoordHand = yNH
        yNoordTafel = yNT
        yZuidTafel = yZT
        yZuidHand = yZT + ch + gap

        // Het speelveld bij voorkeur rechts, in de vrije ruimte links van de
        // tafelrijen en tussen de handen van Noord en Zuid in. Past het daar
        // niet, dan valt hij terug naar links naast de rijen.
        let vb = veldBreed, vh = CGFloat(Indeling.veldHoogte * k)
        let tafelLinks = rechterkant - tafelRij
        let x = tafelLinks - 24 - vb
        let bandTop = yNH + ch, bandBot = yZT + ch + gap

        if x >= speel.minX + 8 && bandBot - bandTop >= vh + CGFloat(Indeling.veldMarge) {
            veld = CGRect(x: x, y: bandTop + (bandBot - bandTop - vh) / 2, width: vb, height: vh)
        } else {
            veld = CGRect(x: speel.minX + 20, y: speel.minY + (speel.height - vh) / 2,
                          width: vb, height: vh)
        }

        // De troefvraag komt op de rij dichte kaarten van Noord te staan: daar
        // zit toch geen informatie, en zo blijft je eigen hand zichtbaar
        // terwijl je kiest.
        let handBreed = sNoord * 7 + kaartBreed
        troefRij = CGRect(x: rechterkant - handBreed, y: yNH, width: handBreed, height: ch)
    }

    /// Waar de kaarten van een gewone rij komen, alle tegen dezelfde rechterkant.
    func rij(_ aantal: Int, y: CGFloat, spatie: CGFloat) -> [CGRect] {
        guard aantal > 0 else { return [] }
        let breed = spatie * CGFloat(aantal - 1) + cw
        let x = rechts - breed
        return (0..<aantal).map {
            CGRect(x: x + CGFloat($0) * spatie, y: y, width: cw, height: ch)
        }
    }

    /// Een tafelrij heeft altijd vier plekken, ook als er minder open liggen.
    func tafelVak(plek: Int, y: CGFloat) -> CGRect {
        let breed = spatieTafel * 3 + cw
        let x = rechts - breed
        return CGRect(x: x + CGFloat(plek) * spatieTafel, y: y, width: cw, height: ch)
    }
}
