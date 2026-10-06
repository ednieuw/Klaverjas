import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import KlaverjasKit
import KlaverjasKaarten

/// Het speelscherm: een balk met de melding, het speelveld met de vier rijen
/// kaarten, en rechts een paneel met de stand.
public struct SpelScherm: View {
    @StateObject private var model: SpelModel
    @State private var beelden = Kaartbeelden()
    @Environment(\.displayScale) private var displayScale

    /// Zelf een partij starten, of een meegegeven model tonen. Dat tweede is
    /// wat een preview en het schermafdruk-gereedschap nodig hebben: die willen
    /// een vaste toestand zien, geen lopend spel.
    private let zelfStarten: Bool

    /// Rekent dit scherm als aanraakscherm of als venster? Standaard wat het
    /// apparaat is. Het schermafdruk-gereedschap zet hem met de hand, zodat een
    /// Mac kan tekenen wat een iPad laat zien — anders klopt een
    /// iPad-schermafdruk voor de App Store niet met het echte scherm.
    private let aanraak: Bool

    public init(aanraak: Bool = SpelScherm.aanraakscherm) {
        _model = StateObject(wrappedValue: SpelModel())
        zelfStarten = true
        self.aanraak = aanraak
    }

    public init(model: SpelModel, aanraak: Bool = SpelScherm.aanraakscherm) {
        _model = StateObject(wrappedValue: model)
        zelfStarten = false
        self.aanraak = aanraak
    }

    /// Onder deze breedte past het paneel van 250 punten niet meer naast het
    /// speelveld. Breed genoeg is niet genoeg: op een telefoon in liggende
    /// stand is er breedte zat maar te weinig hoogte, en dan moet het smalle
    /// scherm het ook overnemen.
    static let smalOnder: CGFloat = 820
    static let paneelBreed: CGFloat = 250

    /// Past het paneel naast de smalle indeling? Op een tablet dwars wel.
    ///
    /// Daar wordt de smalle indeling toch al tot ongeveer de helft verkleind —
    /// de vier rijen onder elkaar zijn hoger dan het scherm — dus de 250 punten
    /// die het paneel afsnoept kosten de kaarten vrijwel niets. En omdat de
    /// standregel en de knoppenbalk dan kunnen vervallen, blijft er onder de
    /// streep zelfs iets meer hoogte over dan zonder paneel.
    ///
    /// De brede indeling is hier geen alternatief: die past op een iPad van tien
    /// inch alleen op ware grootte, en dan zijn de kaarten juist een stuk
    /// kleiner.
    static func paneelNaastSmal(_ maat: CGSize) -> Bool {
        maat.width >= 1000 && maat.height >= 700
    }

    /// Welke van de twee indelingen het wordt.
    ///
    /// Niet alleen "past het brede scherm?", maar ook "welke laat de grootste
    /// kaarten zien?". Op een iPad liggend past de brede indeling wel, maar
    /// alleen op ware grootte; de smalle haalt daar een dubbele vergroting, en
    /// dat leest een stuk prettiger.
    static func neemSmalScherm(_ maat: CGSize, aanraak: Bool = Self.aanraakscherm) -> Bool {
        if maat.width < smalOnder { return true }
        let speelBreed = maat.width - paneelBreed
        let speelHoog = maat.height - 34
        guard let breed = Indeling.schaalIndienPassend(speelBreed, speelHoog) else { return true }

        if !aanraak {
            // Op de Mac wint de brede indeling zodra hij past. Een venster is
            // daar geen vast formaat: wie hem kleiner trekt verwacht kleinere
            // kaarten, niet ineens de indeling van een telefoon zonder paneel.
            return false
        }
        // Op een tablet telt wél welke de grootste kaarten oplevert. Liggend
        // past de brede indeling daar wel, maar alleen op ware grootte, en dan
        // leest het smalle scherm met dubbele kaarten prettiger.
        if breed >= 2 { return false }
        return CompactIndeling.heleSchaal(maat.width) > breed
    }

    /// Een vast scherm dat je aanraakt, of een venster dat je kunt slepen. Als
    /// parameter en niet als `#if`, zodat de regel vanaf beide kanten na te
    /// rekenen is — een Mac kan anders niet toetsen wat een iPad zou doen.
    public static var aanraakscherm: Bool {
        #if os(macOS)
        false
        #else
        true
        #endif
    }

    public var body: some View {
        // Toetsbediening bestaat alleen op iOS 17 en macOS 14 en hoger. Op de
        // Mac is dat altijd zo; een iPhone met iOS 16 krijgt hetzelfde scherm
        // zonder toetsen, en daar wordt toch met de vinger gespeeld.
        if #available(iOS 17.0, macOS 14.0, *) {
            basis.focusable()
                 .focusEffectDisabled()
                 .onKeyPress { druk in toets(druk) }
        } else {
            basis
        }
    }

    /// Het scherm zelf, zonder de toetsbediening eromheen.
    private var basis: some View {
        GeometryReader { geo in
            Group {
            if model.snel {
                // Snel spelen: geen kaarten, alleen de teller. Tekenen kost hier
                // meer tijd dan spelen, en de kaarten zouden toch voorbijflitsen.
                // Geen balk en geen standregel: die veranderen bij elke kaart
                // en zijn bij deze snelheid toch niet te lezen. Elk stuk tekst
                // dat meeloopt kost tekentijd die van het spelen afgaat.
                HStack(spacing: 0) {
                    SnelVeld(model: model, engels: model.engels)
                    if !Self.neemSmalScherm(geo.size, aanraak: aanraak) {
                        Paneel(view: model.view, model: model, engels: model.engels, aanraak: aanraak,
                               beelden: beelden, displayScale: displayScale)
                            .frame(width: Self.paneelBreed)
                    }
                }
            } else if Self.neemSmalScherm(geo.size, aanraak: aanraak) {
                // model.engels wordt hier gelezen zodat SwiftUI weet dat ook
                // dit scherm opnieuw getekend moet worden als de taal omgaat.
                if Self.paneelNaastSmal(geo.size) {
                    HStack(spacing: 0) {
                        CompactScherm(model: model, beelden: beelden,
                                      displayScale: displayScale, engels: model.engels,
                                      aanraak: aanraak, paneelErnaast: true)
                        Paneel(view: model.view, model: model, engels: model.engels, aanraak: aanraak,
                               beelden: beelden, displayScale: displayScale)
                            .frame(width: Self.paneelBreed)
                    }
                } else {
                    CompactScherm(model: model, beelden: beelden,
                                  displayScale: displayScale, engels: model.engels,
                                  aanraak: aanraak)
                }
            } else {
                VStack(spacing: 0) {
                    Balk(tekst: model.tekst, modus: model.modus, aanraak: aanraak,
                         toonAansporing: !(model.view.spelUit && model.modus == .verder))

                    HStack(spacing: 0) {
                        Speelveld(model: model, beelden: beelden, displayScale: displayScale)
                        // De taal gaat als waarde mee: zo merkt SwiftUI dat het
                        // paneel opnieuw getekend moet worden als hij omgaat. De
                        // teksten zelf komen uit Taal, niet uit deze vlag.
                        Paneel(view: model.view, model: model, engels: model.engels, aanraak: aanraak,
                               beelden: beelden, displayScale: displayScale)
                            .frame(width: Self.paneelBreed)
                    }
                }
            }
            }
            .overlay {
                if toonPartijSplash {
                    PartijSplash(view: model.view, engels: model.engels)
                        .onTapGesture { model.gaVerder() }
                }
            }
        }
        .background(Kleuren.achtergrond)
        .task { if zelfStarten { model.start() } }
        .onDisappear { model.stop() }
        // Omhoog vegen geeft geen onDisappear; dit is het laatste bericht dat
        // een app krijgt voordat hij weggelegd of afgesloten wordt.
        .onReceive(Self.appGaatWeg) { _ in model.naarDeAchtergrond() }
    }

    /// Alleen tijdens gewoon, mens-getikt spelen: bij `snel`/automatisch
    /// spelen tikt niemand toe (zie `SpelModel.wachtOpTikVoorVerder`) en kijkt
    /// er ook niemand mee, dus zou het scherm hier alleen maar op wachten.
    private var toonPartijSplash: Bool {
        model.view.partijUit && model.modus == .verder && !model.snel && !model.automatisch
    }

    /// Het laatste bericht dat een app krijgt voordat hij weggelegd wordt. Op
    /// iOS is dat het moment waarop de kaartenbak opengaat — ook als je hem
    /// daarna omhoog veegt en het spel dus nooit meer iets hoort.
    ///
    /// Bewust een melding en niet `onChange(of: scenePhase)`: die vorm is op
    /// macOS 14 afgekeurd, en de nieuwe bestaat pas vanaf iOS 17.
    private static var appGaatWeg: NotificationCenter.Publisher {
        #if canImport(UIKit)
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
        #else
        NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)
        #endif
    }

    /// Eén toetsaanslag: de eerste letter van de troefkleur, of welke toets dan
    /// ook om verder te gaan.
    @available(iOS 17.0, macOS 14.0, *)
    private func toets(_ druk: KeyPress) -> KeyPress.Result {
        switch model.modus {
        case .kiesTroef:
            switch druk.key.character.lowercased() {
            case "k": model.kiesTroef(0); return .handled
            case "s": model.kiesTroef(1); return .handled
            case "r": model.kiesTroef(2); return .handled
            case "h": model.kiesTroef(3); return .handled
            default: return .ignored
            }
        case .verder:
            model.gaVerder()
            return .handled
        default:
            return .ignored
        }
    }
}

/// Het troefteken in de kleur die het op de kaart heeft, op een wit vlakje.
///
/// Zonder dat vlakje kan het niet: klaver is zwart en schoppen donkergrijs, en die
/// verdwijnen allebei in het donkergroen van het paneel. Op wit kloppen alle vier
/// de kleuren letterlijk, en blijft het verschil tussen klaver en schoppen — en
/// tussen ruiten en harten — zichtbaar. Het oogt bovendien als de hoek van een kaart.
struct Troefteken: View {
    let kleur: Int
    var grootte: CGFloat = 26

    var body: some View {
        Text(Taal.kleurTeken(kleur))
            .font(.system(size: grootte * 0.78))
            .foregroundStyle(Kleuren.kaartKleur(kleur))
            .frame(width: grootte, height: grootte * 1.2)
            .background(
                RoundedRectangle(cornerRadius: grootte * 0.16)
                    .fill(Kleuren.kaartWit)
            )
    }
}

enum Kleuren {
    static let achtergrond = Color(red: 18 / 255, green: 73 / 255, blue: 46 / 255)
    static let veld = Color(red: 0x66 / 255, green: 0xCE / 255, blue: 0x33 / 255)
    static let veldRand = Color(red: 58 / 255, green: 122 / 255, blue: 30 / 255)
    static let geel = Color(red: 250 / 255, green: 230 / 255, blue: 160 / 255)
    /// Voor ruiten en harten in de tekst; het rood van de kaarten zelf is op
    /// het donkere paneel te donker.
    static let roodTeken = Color(red: 255 / 255, green: 120 / 255, blue: 110 / 255)
    /// Klaver en schoppen. Op de kaarten zijn ze zwart, maar zwart op donker
    /// groen leest niet; wit houdt het onderscheid met rood wel overeind.
    static let zwartTeken = Color(red: 245 / 255, green: 245 / 255, blue: 240 / 255)

    /// Het wit van de kaart zelf, als ondergrond voor het troefteken.
    static let kaartWit = Color(red: 1, green: 1, blue: 1)

    /// De kleur waarin dit symbool op de kaart getekend is. Vier kleuren, geen
    /// twee: klaver zwart, schoppen donkergrijs, ruiten rood, harten lichtrood.
    static func kaartKleur(_ kleur: Int) -> Color {
        let w = OrigineleKaarten.symboolKleurVoor(kleur)
        return Color(red: Double((w >> 16) & 255) / 255,
                     green: Double((w >> 8) & 255) / 255,
                     blue: Double(w & 255) / 255)
    }
    static let paneel = Color(red: 12 / 255, green: 54 / 255, blue: 34 / 255)
}

/// De regel bovenin: na elke slag wie hem won en wat hij opleverde.
struct Balk: View {
    let tekst: String
    let modus: Modus
    /// Aanraakscherm of venster. Meegegeven en niet zelf opgezocht, zodat het
    /// schermafdruk-gereedschap op een Mac de tekst van een telefoon kan tonen.
    var aanraak = SpelScherm.aanraakscherm
    /// Staat de aansporing ergens anders al, dan hoeft hij hier niet en houdt de
    /// melding de volle breedte.
    var toonAansporing = true

    var body: some View {
        HStack(spacing: 12) {
            Text(tekst.isEmpty ? Taal.titel : tekst)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Kleuren.geel)
                // De langste melding is er een van ruim honderd tekens: "Slag 8
                // voor Noord, 100 roem + 10 voor de laatste slag - Noord wint
                // dit spel - Zuid 32, Noord 230". Drie regels en krimpen tot 70%
                // om die op een telefoon heel te houden.
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                // De melding gaat voor. Zonder dit eist de aansporing rechts
                // eerst haar volle breedte op, houdt de melding op een telefoon
                // nog geen tweehonderd punten over, en valt het eind van de
                // regel — juist de roem — buiten beeld.
                .layoutPriority(1)

            if modus == .verder && toonAansporing {
                // Past hij niet, dan valt hij weg in plaats van de melding te
                // verdringen. Er valt overal op het scherm te tikken om verder
                // te gaan, dus je mist er niets door.
                ViewThatFits(in: .horizontal) {
                    aansporing
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(minHeight: 34)
        .background(Kleuren.paneel)
    }

    private var aansporing: some View {
        Text(aanraak ? Taal.tikVerder : Taal.klikOfToets)
            .font(.system(size: 13))
            .foregroundStyle(Kleuren.geel.opacity(0.75))
            .lineLimit(1)
            .fixedSize()
    }
}

/// Het speelveld met de vier rijen. Alles wordt in één Canvas getekend, net als
/// de C#-versie alles in één OnPaint deed; klikken worden op dezelfde vakken
/// teruggerekend.
struct Speelveld: View {
    @ObservedObject var model: SpelModel
    let beelden: Kaartbeelden
    let displayScale: CGFloat

    var body: some View {
        GeometryReader { geo in
            let speel = CGRect(origin: .zero, size: geo.size)
            let ind = Indeling(speel: speel)
            let vakken = klikVakken(ind)

            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in teken(ctx, ind) }
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { punt in
                        if model.modus == .verder { model.gaVerder(); return }
                        // Van achter naar voren zoeken: de bovenste kaart wint.
                        for (vak, kaart, _) in vakken.reversed()
                        where vak.contains(punt) && model.neemtTik() {
                            model.klik(kaart)
                            return
                        }
                    }

                if model.modus == .kiesTroef {
                    TroefKeuze(model: model)
                        .frame(width: ind.troefRij.width, height: ind.troefRij.height)
                        .offset(x: ind.troefRij.minX, y: ind.troefRij.minY)
                }
            }
        }
    }

    /// Alle aanklikbare kaartvakken, in tekenvolgorde. Altijd mijn eigen rijen
    /// — de onderste twee — ongeacht of ik Zuid of Noord ben; ze staan toch
    /// altijd onderaan, zie `teken(_:_:)`.
    private func klikVakken(_ ind: Indeling) -> [(CGRect, KaartView, Bool)] {
        let v = model.view
        var uit: [(CGRect, KaartView, Bool)] = []

        for (i, vak) in ind.rij(v.mijnTafel.count, y: ind.yZuidTafel,
                                spatie: ind.spatieTafel).enumerated() {
            _ = vak
            let plek = min(max(v.mijnTafel[i].plek, 0), 3)
            uit.append((ind.tafelVak(plek: plek, y: ind.yZuidTafel), v.mijnTafel[i], false))
        }
        for (i, vak) in ind.rij(v.mijnHand.count, y: ind.yZuidHand,
                                spatie: ind.spatieHand).enumerated() {
            uit.append((vak, v.mijnHand[i], true))
        }
        return uit
    }

    // ------------------------------------------------------------ tekenen

    private func teken(_ ctx: GraphicsContext, _ ind: Indeling) {
        let v = model.view
        let k = ind.schaal
        let px = k * max(1, Int(displayScale.rounded()))

        tekenVeld(ctx, ind, v, px)

        // Zijn hand, dicht of open, altijd bovenaan.
        for (i, vak) in ind.rij(v.zijnHand.count, y: ind.yNoordHand,
                                spatie: ind.spatieNoordHand).enumerated() {
            tekenKaart(ctx, v.zijnHand[i], vak, px)
        }

        tekenTafelRij(ctx, ind, v.zijnTafel, v.zijnOnder, y: ind.yNoordTafel,
                      peekOmlaag: true, px: px)
        tekenTafelRij(ctx, ind, v.mijnTafel, v.mijnOnder, y: ind.yZuidTafel,
                      peekOmlaag: false, px: px)

        for (i, vak) in ind.rij(v.mijnHand.count, y: ind.yZuidHand,
                                spatie: ind.spatieHand).enumerated() {
            let kaart = v.mijnHand[i]
            let op = model.magKlikken(true) ? vak.offsetBy(dx: 0, dy: -CGFloat(3 * k)) : vak
            tekenKaart(ctx, kaart, op, px)
        }
    }

    private func tekenVeld(_ ctx: GraphicsContext, _ ind: Indeling, _ v: SpelView, _ px: Int) {
        let pad = Path(ind.veld)
        ctx.fill(pad, with: .color(Kleuren.veld))
        ctx.stroke(pad, with: .color(Kleuren.veldRand), lineWidth: 2)

        // Lege plekken licht aangeven, zodat de indeling ook zichtbaar is
        // voordat er kaarten liggen.
        for speler in [Pos.handZuid, Pos.handNoord, Pos.tafelZuid, Pos.tafelNoord] {
            if v.slag.contains(where: { $0.speler == speler }) { continue }
            let p = Indeling.veldPlek(v.relatieveSpeler(speler), ind.schaal)
            let vak = CGRect(x: ind.veld.minX + p.x, y: ind.veld.minY + p.y,
                             width: ind.cw, height: ind.ch)
            ctx.stroke(Path(vak), with: .color(Kleuren.veldRand.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }

        // In speelvolgorde tekenen, zodat een latere kaart over een eerdere valt.
        for s in v.slag {
            let p = Indeling.veldPlek(v.relatieveSpeler(s.speler), ind.schaal)
            let vak = CGRect(x: ind.veld.minX + p.x, y: ind.veld.minY + p.y,
                             width: ind.cw, height: ind.ch)
            schaduw(ctx, vak)
            if let beeld = beelden.voor(s.naam, s.kleur, schaal: px) {
                ctx.draw(Image(decorative: beeld, scale: displayScale).interpolation(.none), in: vak)
            }
        }
    }

    private func tekenTafelRij(_ ctx: GraphicsContext, _ ind: Indeling,
                               _ open: [KaartView], _ gedekt: [Bool],
                               y: CGFloat, peekOmlaag: Bool, px: Int) {
        // De achterkant hoort onder de plek die hij werkelijk dekt, niet onder
        // de eerste zoveel plekken.
        // Zeven pixels: één zwarte kaartrand, drie wit en drie blauw, zodat er
        // net zoveel van het ruitpatroon te zien is als van het witte kader.
        let peek = CGFloat(peekOmlaag ? 7 * ind.schaal : -7 * ind.schaal)
        for i in 0..<min(4, gedekt.count) where gedekt[i] {
            let vak = ind.tafelVak(plek: i, y: y + peek)
            if let beeld = beelden.achterkant(schaal: px) {
                ctx.draw(Image(decorative: beeld, scale: displayScale).interpolation(.none), in: vak)
            }
        }

        for kaart in open {
            let plek = min(max(kaart.plek, 0), 3)
            let vak = ind.tafelVak(plek: plek, y: y)
            schaduw(ctx, vak)
            tekenKaart(ctx, kaart, vak, px)
        }
    }

    private func tekenKaart(_ ctx: GraphicsContext, _ kaart: KaartView,
                            _ vak: CGRect, _ px: Int) {
        schaduw(ctx, vak)
        let beeld = kaart.open ? beelden.voor(kaart.naam, kaart.kleur, schaal: px)
                               : beelden.achterkant(schaal: px)
        guard let beeld else { return }
        ctx.draw(Image(decorative: beeld, scale: displayScale).interpolation(.none), in: vak)
    }

    private func schaduw(_ ctx: GraphicsContext, _ r: CGRect) {
        ctx.fill(Path(r.offsetBy(dx: 3, dy: 4)), with: .color(.black.opacity(0.24)))
    }
}

/// De troefvraag, op de rij dichte kaarten van Noord.
struct TroefKeuze: View {
    @ObservedObject var model: SpelModel

    private static let tekens = ["♣", "♠", "♦", "♥"]

    var body: some View {
        VStack(spacing: 6) {
            Text(Taal.welkeTroef)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Kleuren.geel)
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { k in
                    Button {
                        model.kiesTroef(k)
                    } label: {
                        VStack(spacing: 2) {
                            Text(Self.tekens[k])
                                .font(.system(size: 26))
                            Text(Taal.kleurNaam(k))
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Kleuren.kaartKleur(k))
                        .frame(width: 76, height: 60)
                        .background(Color(white: 0.97))
                        .overlay(Rectangle().stroke(Color(white: 0.5), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            // Een kaart aantikken laat zich niet raden; hier staat het.
            Text(Taal.troefViaKaart)
                .font(.system(size: 12))
                .foregroundStyle(Kleuren.geel.opacity(0.85))
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 14 / 255, green: 28 / 255, blue: 20 / 255).opacity(0.84))
        .overlay(Rectangle().stroke(Kleuren.geel, lineWidth: 2))
    }
}

/// De stand, rechts naast het speelveld.
struct Paneel: View {
    let view: SpelView
    @ObservedObject var model: SpelModel
    let engels: Bool
    var aanraak = SpelScherm.aanraakscherm
    /// Voor de kaartjes van de vorige slag.
    var beelden: Kaartbeelden?
    var displayScale: CGFloat = 2

    /// Zie `CompactScherm.aansporing`.
    var aansporing: String? {
        guard view.spelUit, model.modus == .verder else { return nil }
        return aanraak ? Taal.tikVerder : Taal.klikOfToets
    }

    /// Welk blad er open staat. Eén enkele sheet met een keuze erin, zoals de
    /// knoppenbalk van de telefoon het al doet: sheet-modifiers op elkaar
    /// stapelen geeft in SwiftUI onvoorspelbare uitkomsten, en met de knop
    /// Opties erbij zouden het er drie zijn.
    private enum Blad: String, Identifiable {
        case statistiek, opties, spelregels, samenSpelen
        var id: String { rawValue }
    }
    @State private var blad: Blad?

    /// Gezet door `OptieScherm.toonSpelregels` vlak vóórdat dat blad zichzelf
    /// sluit — zie de aantekening bij `.sheet(onDismiss:)` hieronder.
    @State private var openSpelregelsNaSluiten = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            troefRegel
            // Bij spel uit de aansporing hier, zodat de balk bovenin de volle
            // breedte houdt voor de uitslag.
            if view.spelUit {
                regel(aansporing ?? Taal.spelUit, "")
            } else {
                regel(Taal.slagVanAcht(max(1, view.slagNr)), "")
            }

            Divider().overlay(Kleuren.geel.opacity(0.3))

            standTabel

            // De schakelaars, de speelwijze en de taal stonden hier uitgeklapt.
            // Ze staan nu achter de knop Opties, in hetzelfde blad dat de telefoon
            // al gebruikt — één plek om te onderhouden, en een paneel dat rustig
            // genoeg is om de troefregel en de vorige slag te laten spreken.

            Divider().overlay(Kleuren.geel.opacity(0.3))

            VorigeSlagRij(view: view, beelden: beelden, displayScale: displayScale)

            Spacer()

            // Spelregels staat niet meer hier — Ed: "die zul je niet vaak
            // raadplegen" — maar in het optieblad. Dat laat twee rijen van
            // twee over in plaats van twee rijen plus een losse regel.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(Taal.menuOpties.replacingOccurrences(of: "&", with: "")) {
                        blad = .opties
                    }
                    Spacer()
                    Button(Taal.menuStatistieken.replacingOccurrences(of: "&", with: "")) {
                        blad = .statistiek
                    }
                }
                HStack {
                    // Tijdens samenspel verstopt: die knop begint gewoon een
                    // eigen, nieuwe partij — en breekt daarmee de lopende,
                    // gedeelde partij af. Zonder deze bewaking kon één per
                    // ongeluk getikte knop precies dat laten lijken op "de
                    // gast blijft in zijn eigen spel".
                    if !model.inSamenspel {
                        Button(Taal.menuNieuw.replacingOccurrences(of: "&", with: "")) {
                            model.start()
                        }
                    }
                    Spacer()
                    // Verandert in "Stop samen" zodra er een verbinding is —
                    // een nette, met opzet getikte manier om af te sluiten,
                    // naast een verbinding die vanzelf wegvalt. `model.start()`
                    // roept zelf eerst `stop()` aan (radio netjes dicht) en
                    // begint meteen een gewone, eigen partij — dezelfde
                    // bewaarde puntentelling als voor het samenspel.
                    if model.inSamenspel {
                        Button(Taal.duoStopSamen) { model.start() }
                    } else {
                        Button(Taal.menuSamenSpelen) { blad = .samenSpelen }
                    }
                }
            }
        }
        // `onDismiss` in plaats van de spelregels rechtstreeks vanuit
        // `OptieScherm` te openen: dat zou een blad uit een blad optrekken
        // terwijl het optieblad nog in beeld is, en dat laat AppKit op de Mac
        // klagen ("It's not legal to call -layoutSubtreeIfNeeded..."). Nu
        // sluit het optieblad eerst helemaal, en gaat pas ná die animatie —
        // hier, ná het echte sluiten — het spelregelsblad open.
        .sheet(item: $blad, onDismiss: {
            guard openSpelregelsNaSluiten else { return }
            openSpelregelsNaSluiten = false
            blad = .spelregels
        }) { welke in
            switch welke {
            case .statistiek:
                StatistiekScherm(stat: view.statistiek, duoTellingen: model.alleBewaardeDuoTellingen(),
                                 wis: { if !model.inSamenspel { model.wisStatistiek() } },
                                 wisPartner: { model.wisDuoPartner($0) },
                                 actievePartner: model.actievePartner) { blad = nil }
            case .opties:
                // Geen `beelden` mee: dit paneel toont de vorige slag zelf al (`VorigeSlagRij` hierboven),
                // dus hoeft het optieblad hem niet nog eens te laten zien. Alleen op een telefoon, waar
                // geen paneel is, staat hij in het optieblad (`CompactScherm`).
                OptieScherm(model: model, beelden: nil, displayScale: displayScale,
                            sluit: { blad = nil },
                            toonSpelregels: { openSpelregelsNaSluiten = true; blad = nil })
            case .spelregels:
                HandleidingScherm(engels: engels) { blad = nil }
            case .samenSpelen:
                VerbindScherm(model: model) { blad = nil }
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Kleuren.geel)
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Kleuren.paneel)
    }

    /// Troef groot en bij elkaar. De waarde stond hier rechts tegen de rand,
    /// los van zijn kop; nu staan ze naast elkaar links, en anderhalf tot twee
    /// keer zo groot als de rest van het paneel — het is het enige gegeven dat
    /// je tijdens het spelen voortdurend nodig hebt.
    private var troefRegel: some View {
        let k = view.troef
        let bekend = k >= 0 && k < 4
        return HStack(alignment: .center, spacing: 8) {
            // Wie troef maakte. Dat bepaalt wie zijn punten moet halen en wie er
            // nat kan gaan, en stond nergens in beeld.
            if view.troefmaker != 0 {
                Text(Taal.kantKort(view.troefmakerRelatief))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Kleuren.geel)
            }
            Text(Taal.troef)
                .font(.system(size: 20, weight: .semibold))
            if bekend {
                Troefteken(kleur: k)
                // "Diamonds" (en "Schoppen") passen bij 20pt niet meer naast
                // "N Troef"/"N Trumps" op de breedte van het paneel — de "ds"
                // viel op een tweede regel. Eén regel gedwongen en laten
                // krimpen in plaats van vast kleiner: dat werkt voor élke
                // kleurnaam in beide talen, niet alleen de langste van nu.
                Text(Taal.kleurNaam(k))
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text(Taal.nogNietBepaald)
            }
            Spacer(minLength: 0)
        }
    }

    private func regel(_ kop: String, _ waarde: String) -> some View {
        HStack {
            Text(kop).fontWeight(.semibold)
            Spacer()
            Text(waarde)
        }
    }

    /// De stand als tabel: een kop met Zuid en Noord, en daaronder één regel
    /// per soort punten. Zo staan de getallen onder elkaar en is per rij in één
    /// oogopslag te zien wie voorstaat.
    private var standTabel: some View {
        Grid(alignment: .trailing, horizontalSpacing: 18, verticalSpacing: 7) {
            GridRow {
                Color.clear
                    .frame(width: 0, height: 0)
                    .gridColumnAlignment(.leading)
                Text(Taal.zuid)
                Text(Taal.noord)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Kleuren.geel.opacity(0.7))

            GridRow {
                Divider()
                    .overlay(Kleuren.geel.opacity(0.25))
                    .gridCellColumns(3)
            }

            standRegel(Taal.punten, view.mijnPunten, view.zijnPunten)
            standRegel(Taal.roem, view.mijnRoem, view.zijnRoem)
            standRegel(Taal.totaal, Int(view.mijnTotaal), Int(view.zijnTotaal))
            standRegel(Taal.partijen, view.mijnPartijen, view.zijnPartijen)
        }
        .monospacedDigit()
    }

    private func standRegel(_ kop: String, _ zuid: Int, _ noord: Int) -> some View {
        GridRow {
            Text(kop)
                .fontWeight(.semibold)
                .gridColumnAlignment(.leading)
            Text("\(zuid)")
            Text("\(noord)")
        }
    }
}

/// Een aanvinkregel. Bewust niet Toggle met .checkbox: die stijl bestaat alleen
/// op de Mac, en dit scherm moet straks ook op de iPhone draaien.
struct Schakelaar: View {
    let naam: String
    let aan: Bool
    let doe: () -> Void

    init(_ naam: String, aan: Bool, doe: @escaping () -> Void) {
        // De ampersand markeert in het Windows-menu de sneltoets; hier niet.
        self.naam = naam.replacingOccurrences(of: "&", with: "")
        self.aan = aan
        self.doe = doe
    }

    var body: some View {
        Button(action: doe) {
            HStack(spacing: 8) {
                Image(systemName: aan ? "checkmark.square.fill" : "square")
                    .foregroundStyle(aan ? Kleuren.geel : Kleuren.geel.opacity(0.55))
                Text(naam)
                    .foregroundStyle(Kleuren.geel)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Wat er te zien is terwijl er snel gespeeld wordt: hoe ver hij is, wie er aan
/// welke kant speelt, en hoe je hem weer uitzet. De tegenhanger van TekenSnel()
/// in de Windows-versie.
struct SnelVeld: View {
    @ObservedObject var model: SpelModel
    /// Alleen om SwiftUI te laten merken dat de taal omging.
    let engels: Bool

    @State private var statistiekOpen = false

    var body: some View {
        let spellen = model.view.statistiek.spellen[0] + model.view.statistiek.spellen[1]
        VStack(spacing: 14) {
            Spacer()
            Text(Taal.snelBezig)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Kleuren.geel)
            Text(Taal.snelSpellen(Int(spellen)))
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.9))
                .monospacedDigit()

            // Uit de momentopname en niet uit de schakelaars: dit is wat de
            // motor werkelijk doet, en daar gaat het hier om.
            VStack(spacing: 4) {
                Text("\(Taal.zuid): \(Taal.speelwijzeNaam(claude: model.view.claude[0], zoekt: model.view.zoekt[0]))")
                Text("\(Taal.noord): \(Taal.speelwijzeNaam(claude: model.view.claude[1], zoekt: model.view.zoekt[1]))")
            }
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.75))

            // Ook hier de statistiek: bij snel spelen is juist het verloop het
            // aardige om te zien, en het paneel met die knop staat er niet.
            // Het blad werkt bij terwijl er doorgespeeld wordt.
            HStack(spacing: 16) {
                Button(Taal.snelUitzetten) { model.snel = false }
                Button(Taal.menuStatistieken.replacingOccurrences(of: "&", with: "")) {
                    statistiekOpen = true
                }
            }
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Kleuren.achtergrond)
        .sheet(isPresented: $statistiekOpen) {
            StatistiekScherm(stat: model.view.statistiek, duoTellingen: model.alleBewaardeDuoTellingen(),
                             wis: { if !model.inSamenspel { model.wisStatistiek() } },
                                 wisPartner: { model.wisDuoPartner($0) },
                                 actievePartner: model.actievePartner) { statistiekOpen = false }
        }
    }
}

/// De vorige slag in het klein, zoals de Windows-versie hem laat staan. Handig
/// om nog even na te kijken wat er lag — zeker als de computer doorspeelt.
///
/// Een eigen view en geen stukje paneel: op een telefoon is er geen paneel, en
/// daar hoort hij in het optieblad. Zonder dit stond hij er domweg niet.
///
/// De kaarten zijn per pixel getekend, dus alleen op een hele vergroting: het
/// beeld wordt op de schermdichtheid gemaakt en op ware grootte neergezet. Ze
/// overlappen een tikje, want vier hele kaarten passen net niet naast elkaar in
/// een paneel van 250; de hoek linksboven met kleur en rang blijft vrij.
struct VorigeSlagRij: View {
    let view: SpelView
    let beelden: Kaartbeelden?
    let displayScale: CGFloat

    var body: some View {
        if !view.vorigeSlag.isEmpty, let beelden {
            let k = max(1, Int(displayScale.rounded()))
            VStack(alignment: .leading, spacing: 6) {
                Divider().overlay(Kleuren.geel.opacity(0.3))
                Text(Taal.vorigeSlag)
                    .fontWeight(.semibold)
                    .foregroundStyle(Kleuren.geel.opacity(0.8))
                HStack(spacing: -6) {
                    ForEach(Array(view.vorigeSlag.enumerated()), id: \.offset) { _, kaart in
                        if let beeld = beelden.voor(kaart.naam, kaart.kleur, schaal: k) {
                            Image(decorative: beeld, scale: displayScale)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: CGFloat(OrigineleKaarten.breedte),
                                       height: CGFloat(OrigineleKaarten.hoogte))
                        }
                    }
                }
            }
        }
    }
}
