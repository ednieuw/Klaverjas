import SwiftUI
import KlaverjasKit
import KlaverjasKaarten

/// Het speelscherm: een balk met de melding, het speelveld met de vier rijen
/// kaarten, en rechts een paneel met de stand.
public struct SpelScherm: View {
    @State private var model: SpelModel
    @State private var beelden = Kaartbeelden()
    @Environment(\.displayScale) private var displayScale

    /// Zelf een partij starten, of een meegegeven model tonen. Dat tweede is
    /// wat een preview en het schermafdruk-gereedschap nodig hebben: die willen
    /// een vaste toestand zien, geen lopend spel.
    private let zelfStarten: Bool

    public init() {
        _model = State(initialValue: SpelModel())
        zelfStarten = true
    }

    public init(model: SpelModel) {
        _model = State(initialValue: model)
        zelfStarten = false
    }

    /// Onder deze breedte past het paneel van 250 punten niet meer naast het
    /// speelveld. Breed genoeg is niet genoeg: op een telefoon in liggende
    /// stand is er breedte zat maar te weinig hoogte, en dan moet het smalle
    /// scherm het ook overnemen.
    static let smalOnder: CGFloat = 820
    static let paneelBreed: CGFloat = 250

    /// Welke van de twee indelingen het wordt.
    ///
    /// Niet alleen "past het brede scherm?", maar ook "welke laat de grootste
    /// kaarten zien?". Op een iPad liggend past de brede indeling wel, maar
    /// alleen op ware grootte; de smalle haalt daar een dubbele vergroting, en
    /// dat leest een stuk prettiger.
    static func neemSmalScherm(_ maat: CGSize) -> Bool {
        if maat.width < smalOnder { return true }
        let speelBreed = maat.width - paneelBreed
        let speelHoog = maat.height - 34
        guard let breed = Indeling.schaalIndienPassend(speelBreed, speelHoog) else { return true }

        #if os(macOS)
        // Op de Mac wint de brede indeling zodra hij past. Een venster is daar
        // geen vast formaat: wie hem kleiner trekt verwacht kleinere kaarten,
        // niet ineens de indeling van een telefoon zonder paneel.
        return false
        #else
        // Op een tablet telt wél welke de grootste kaarten oplevert. Liggend
        // past de brede indeling daar wel, maar alleen op ware grootte, en dan
        // leest het smalle scherm met dubbele kaarten prettiger.
        if breed >= 2 { return false }
        return CompactIndeling.heleSchaal(maat.width) > breed
        #endif
    }

    public var body: some View {
        GeometryReader { geo in
            if Self.neemSmalScherm(geo.size) {
                // model.engels wordt hier gelezen zodat SwiftUI weet dat ook
                // dit scherm opnieuw getekend moet worden als de taal omgaat.
                CompactScherm(model: model, beelden: beelden,
                              displayScale: displayScale, engels: model.engels)
            } else {
                VStack(spacing: 0) {
                    Balk(tekst: model.tekst, modus: model.modus)

                    HStack(spacing: 0) {
                        Speelveld(model: model, beelden: beelden, displayScale: displayScale)
                        // De taal gaat als waarde mee: zo merkt SwiftUI dat het
                        // paneel opnieuw getekend moet worden als hij omgaat. De
                        // teksten zelf komen uit Taal, niet uit deze vlag.
                        Paneel(view: model.view, model: model, engels: model.engels)
                            .frame(width: Self.paneelBreed)
                    }
                }
            }
        }
        .background(Kleuren.achtergrond)
        .task { if zelfStarten { model.start() } }
        .onDisappear { model.stop() }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress { druk in
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
}

enum Kleuren {
    static let achtergrond = Color(red: 18 / 255, green: 73 / 255, blue: 46 / 255)
    static let veld = Color(red: 0x66 / 255, green: 0xCE / 255, blue: 0x33 / 255)
    static let veldRand = Color(red: 58 / 255, green: 122 / 255, blue: 30 / 255)
    static let geel = Color(red: 250 / 255, green: 230 / 255, blue: 160 / 255)
    static let paneel = Color(red: 12 / 255, green: 54 / 255, blue: 34 / 255)
}

/// De regel bovenin: na elke slag wie hem won en wat hij opleverde.
struct Balk: View {
    let tekst: String
    let modus: Modus

    var body: some View {
        HStack {
            Text(tekst.isEmpty ? Taal.titel : tekst)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Kleuren.geel)
                // Twee regels: "Slag 8 voor Zuid, 20 roem + 10 voor de laatste
                // slag - Zuid wint dit spel - Zuid 95, Noord 57" past niet op
                // één regel op een telefoon.
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if modus == .verder {
                Text(Taal.klikOfToets)
                    .font(.system(size: 13))
                    .foregroundStyle(Kleuren.geel.opacity(0.75))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(minHeight: 34)
        .background(Kleuren.paneel)
    }
}

/// Het speelveld met de vier rijen. Alles wordt in één Canvas getekend, net als
/// de C#-versie alles in één OnPaint deed; klikken worden op dezelfde vakken
/// teruggerekend.
struct Speelveld: View {
    let model: SpelModel
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
                        for (vak, kaart, uitHand) in vakken.reversed()
                        where vak.contains(punt) && model.magKlikken(uitHand) {
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

    /// Alle aanklikbare kaartvakken, in tekenvolgorde.
    private func klikVakken(_ ind: Indeling) -> [(CGRect, KaartView, Bool)] {
        let v = model.view
        var uit: [(CGRect, KaartView, Bool)] = []

        for (i, vak) in ind.rij(v.tafelZuid.count, y: ind.yZuidTafel,
                                spatie: ind.spatieTafel).enumerated() {
            _ = vak
            let plek = min(max(v.tafelZuid[i].plek, 0), 3)
            uit.append((ind.tafelVak(plek: plek, y: ind.yZuidTafel), v.tafelZuid[i], false))
        }
        for (i, vak) in ind.rij(v.handZuid.count, y: ind.yZuidHand,
                                spatie: ind.spatieHand).enumerated() {
            uit.append((vak, v.handZuid[i], true))
        }
        return uit
    }

    // ------------------------------------------------------------ tekenen

    private func teken(_ ctx: GraphicsContext, _ ind: Indeling) {
        let v = model.view
        let k = ind.schaal
        let px = k * max(1, Int(displayScale.rounded()))

        tekenVeld(ctx, ind, v, px)

        // Hand van Noord, dicht of open.
        for (i, vak) in ind.rij(v.handNoord.count, y: ind.yNoordHand,
                                spatie: ind.spatieNoordHand).enumerated() {
            tekenKaart(ctx, v.handNoord[i], vak, px)
        }

        tekenTafelRij(ctx, ind, v.tafelNoord, v.onderNoord, y: ind.yNoordTafel,
                      peekOmlaag: true, px: px)
        tekenTafelRij(ctx, ind, v.tafelZuid, v.onderZuid, y: ind.yZuidTafel,
                      peekOmlaag: false, px: px)

        for (i, vak) in ind.rij(v.handZuid.count, y: ind.yZuidHand,
                                spatie: ind.spatieHand).enumerated() {
            let kaart = v.handZuid[i]
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
            let p = Indeling.veldPlek(speler, ind.schaal)
            let vak = CGRect(x: ind.veld.minX + p.x, y: ind.veld.minY + p.y,
                             width: ind.cw, height: ind.ch)
            ctx.stroke(Path(vak), with: .color(Kleuren.veldRand.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }

        // In speelvolgorde tekenen, zodat een latere kaart over een eerdere valt.
        for s in v.slag {
            let p = Indeling.veldPlek(s.speler, ind.schaal)
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
        let peek = CGFloat(peekOmlaag ? 5 * ind.schaal : -5 * ind.schaal)
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
    let model: SpelModel

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
                        .foregroundStyle(k == 2 || k == 3 ? Color.red : Color.black)
                        .frame(width: 76, height: 60)
                        .background(Color(white: 0.97))
                        .overlay(Rectangle().stroke(Color(white: 0.5), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
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
    let model: SpelModel
    let engels: Bool

    @State private var statistiekOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            regel(Taal.troef, view.troef >= 0 && view.troef < 4
                              ? Taal.kleurNaam(view.troef) : Taal.nogNietBepaald)
            regel(view.spelUit ? Taal.spelUit : Taal.slagVanAcht(max(1, view.slagNr)), "")

            Divider().overlay(Kleuren.geel.opacity(0.3))

            standTabel

            Divider().overlay(Kleuren.geel.opacity(0.3))

            Schakelaar(Taal.menuDemo, aan: model.demo) { model.demo.toggle() }
            Schakelaar(Taal.menuOpenKaart, aan: model.openKaart) { model.openKaart.toggle() }
            Schakelaar(Taal.menuAuto, aan: model.automatisch) { model.automatisch.toggle() }

            Divider().overlay(Kleuren.geel.opacity(0.3))

            taalKeuze

            Spacer()

            HStack {
                Button(Taal.menuNieuw.replacingOccurrences(of: "&", with: "")) {
                    model.start()
                }
                Spacer()
                Button(Taal.menuStatistieken.replacingOccurrences(of: "&", with: "")) {
                    statistiekOpen = true
                }
            }
        }
        .sheet(isPresented: $statistiekOpen) {
            StatistiekScherm(stat: view.statistiek) { statistiekOpen = false }
        }
        .font(.system(size: 13))
        .foregroundStyle(Kleuren.geel)
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Kleuren.paneel)
    }

    /// Nederlands of Engels, tijdens het spelen om te zetten.
    private var taalKeuze: some View {
        HStack(spacing: 8) {
            Text(Taal.menuTaal.replacingOccurrences(of: "&", with: ""))
                .fontWeight(.semibold)
            Spacer()
            // Twee eigen knopjes in plaats van een Picker met .segmented:
            // die leunt op een besturingssysteemonderdeel dat er per platform
            // anders uitziet en zich buiten een venster niet laat tekenen.
            HStack(spacing: 0) {
                taalKnop("NL", engelsAan: false)
                taalKnop("EN", engelsAan: true)
            }
            .overlay(Rectangle().stroke(Kleuren.geel.opacity(0.45), lineWidth: 1))
        }
    }

    private func taalKnop(_ naam: String, engelsAan: Bool) -> some View {
        let gekozen = model.engels == engelsAan
        return Button {
            model.engels = engelsAan
        } label: {
            Text(naam)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(gekozen ? Kleuren.paneel : Kleuren.geel)
                .frame(width: 40, height: 22)
                .background(gekozen ? Kleuren.geel.opacity(0.85) : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

            standRegel(Taal.punten, view.puntenZuid, view.puntenNoord)
            standRegel(Taal.roem, view.roemZuid, view.roemNoord)
            standRegel(Taal.totaal, Int(view.totaalZuid), Int(view.totaalNoord))
            standRegel(Taal.partijen, view.partijenZuid, view.partijenNoord)
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
