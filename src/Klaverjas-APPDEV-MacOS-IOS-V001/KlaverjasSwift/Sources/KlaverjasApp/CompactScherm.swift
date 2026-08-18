import SwiftUI
import KlaverjasKit
import KlaverjasKaarten

/// Het speelscherm voor een smal scherm: de telefoon rechtop.
///
/// Dezelfde vier rijen en hetzelfde speelveld als op de Mac, maar onder elkaar
/// en in een waaier. De stand staat in een regel bovenin in plaats van in een
/// paneel ernaast; voor een paneel van 250 punten is geen ruimte.
struct CompactScherm: View {
    let model: SpelModel
    let beelden: Kaartbeelden
    let displayScale: CGFloat
    /// Alleen om SwiftUI te laten merken dat de taal omging; de teksten komen
    /// uit Taal.
    let engels: Bool

    var body: some View {
        VStack(spacing: 0) {
            Balk(tekst: model.tekst, modus: model.modus)
            Standregel(view: model.view)

            GeometryReader { geo in
                // Op ware grootte neerzetten en daarna als geheel verkleinen
                // als het niet past. De klikvakken worden in dezelfde ruimte
                // berekend, dus die schuiven vanzelf mee.
                let nodig = CompactIndeling.natuurlijkeHoogte(geo.size.width)
                let hoog = max(geo.size.height, nodig)
                let krimp = min(1, geo.size.height / nodig)
                let speel = CGRect(x: 0, y: 0, width: geo.size.width, height: hoog)
                let ind = CompactIndeling(speel: speel)
                let vakken = klikVakken(ind)

                ZStack(alignment: .topLeading) {
                    Canvas { ctx, _ in teken(ctx, ind) }
                        .contentShape(Rectangle())
                        .onTapGesture(coordinateSpace: .local) { punt in
                            if model.modus == .verder { model.gaVerder(); return }
                            // Van achter naar voren: in een waaier ligt de
                            // rechter kaart bovenop, en die moet winnen.
                            for (vak, kaart, uitHand) in vakken.reversed()
                            where vak.contains(punt) && model.magKlikken(uitHand) {
                                model.klik(kaart)
                                return
                            }
                        }

                    if model.modus == .kiesTroef {
                        CompacteTroefKeuze(model: model)
                            .frame(width: geo.size.width)
                            .offset(y: ind.veld.minY - 10)
                    }
                }
                .frame(width: geo.size.width, height: hoog)
                .scaleEffect(krimp, anchor: .top)
            }

            Knoppenbalk(model: model)
        }
        .background(Kleuren.achtergrond)
    }

    private func klikVakken(_ ind: CompactIndeling) -> [(CGRect, KaartView, Bool)] {
        let v = model.view
        var uit: [(CGRect, KaartView, Bool)] = []
        for kaart in v.tafelZuid {
            let plek = min(max(kaart.plek, 0), 3)
            uit.append((ind.tafelVak(plek: plek, y: ind.yZuidTafel), kaart, false))
        }
        for (i, vak) in ind.rij(v.handZuid.count, y: ind.yZuidHand,
                                spatie: ind.handSpatie).enumerated() {
            uit.append((vak, v.handZuid[i], true))
        }
        return uit
    }

    // ------------------------------------------------------------ tekenen

    private func teken(_ ctx: GraphicsContext, _ ind: CompactIndeling) {
        let v = model.view
        let px = ind.schaal * max(1, Int(displayScale.rounded()))

        // Speelveld eerst, de kaarten liggen erop.
        let pad = Path(ind.veld)
        ctx.fill(pad, with: .color(Kleuren.veld))
        ctx.stroke(pad, with: .color(Kleuren.veldRand), lineWidth: 2)

        for speler in [Pos.handZuid, Pos.handNoord, Pos.tafelZuid, Pos.tafelNoord] {
            if v.slag.contains(where: { $0.speler == speler }) { continue }
            ctx.stroke(Path(ind.veldPlek(speler)), with: .color(Kleuren.veldRand.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        for s in v.slag {
            let vak = ind.veldPlek(s.speler)
            schaduw(ctx, vak)
            if let beeld = beelden.voor(s.naam, s.kleur, schaal: px) {
                ctx.draw(Image(decorative: beeld, scale: displayScale).interpolation(.none), in: vak)
            }
        }

        for (i, vak) in ind.rij(v.handNoord.count, y: ind.yNoordHand,
                                spatie: ind.noordHandSpatie).enumerated() {
            tekenKaart(ctx, v.handNoord[i], vak, px)
        }

        tekenTafelRij(ctx, ind, v.tafelNoord, v.onderNoord, y: ind.yNoordTafel,
                      peekOmlaag: true, px: px)
        tekenTafelRij(ctx, ind, v.tafelZuid, v.onderZuid, y: ind.yZuidTafel,
                      peekOmlaag: false, px: px)

        for (i, vak) in ind.rij(v.handZuid.count, y: ind.yZuidHand,
                                spatie: ind.handSpatie).enumerated() {
            let op = model.magKlikken(true)
                ? vak.offsetBy(dx: 0, dy: -CGFloat(2 * ind.schaal)) : vak
            tekenKaart(ctx, v.handZuid[i], op, px)
        }
    }

    private func tekenTafelRij(_ ctx: GraphicsContext, _ ind: CompactIndeling,
                               _ open: [KaartView], _ gedekt: [Bool],
                               y: CGFloat, peekOmlaag: Bool, px: Int) {
        let peek = CGFloat(peekOmlaag ? 4 * ind.schaal : -4 * ind.schaal)
        for i in 0..<min(4, gedekt.count) where gedekt[i] {
            let vak = ind.tafelVak(plek: i, y: y + peek)
            if let beeld = beelden.achterkant(schaal: px) {
                ctx.draw(Image(decorative: beeld, scale: displayScale).interpolation(.none), in: vak)
            }
        }
        for kaart in open {
            let plek = min(max(kaart.plek, 0), 3)
            tekenKaart(ctx, kaart, ind.tafelVak(plek: plek, y: y), px)
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
        ctx.fill(Path(r.offsetBy(dx: 2, dy: 3)), with: .color(.black.opacity(0.24)))
    }
}

/// De stand op één regel, in plaats van het paneel ernaast.
struct Standregel: View {
    let view: SpelView

    var body: some View {
        HStack(spacing: 14) {
            if view.spelUit {
                deel(Taal.spelUit, "")
            } else {
                deel(Taal.troef, view.troef >= 0 && view.troef < 4
                                 ? Taal.kleurNaam(view.troef) : "-")
                deel(Taal.slagVanAcht(max(1, view.slagNr)), "")
            }
            Spacer(minLength: 0)
            deel(Taal.zuid, "\(view.puntenZuid)+\(view.roemZuid)")
            deel(Taal.noord, "\(view.puntenNoord)+\(view.roemNoord)")
        }
        .font(.system(size: 12))
        .monospacedDigit()
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Kleuren.paneel.opacity(0.8))
    }

    private func deel(_ kop: String, _ waarde: String) -> some View {
        HStack(spacing: 4) {
            Text(kop)
                .foregroundStyle(Kleuren.geel.opacity(0.7))
            if !waarde.isEmpty {
                Text(waarde)
                    .fontWeight(.semibold)
                    .foregroundStyle(Kleuren.geel)
            }
        }
    }
}

/// Nieuw spel, statistieken en de opties, onderaan het scherm.
struct Knoppenbalk: View {
    let model: SpelModel

    /// Welk blad er open staat. Eén enkele sheet met een keuze erin, in plaats
    /// van twee sheet-modifiers op hetzelfde onderdeel: dat tweede geeft in
    /// SwiftUI onvoorspelbare uitkomsten.
    private enum Blad: String, Identifiable {
        case statistiek, opties
        var id: String { rawValue }
    }
    @State private var blad: Blad?

    var body: some View {
        HStack(spacing: 10) {
            knop(Taal.menuNieuw) { model.start() }
            knop(Taal.menuStatistieken) { blad = .statistiek }
            Spacer(minLength: 0)
            knop(Taal.menuOpties) { blad = .opties }
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(Kleuren.paneel)
        .sheet(item: $blad) { welke in
            switch welke {
            case .statistiek:
                StatistiekScherm(stat: model.view.statistiek) { blad = nil }
            case .opties:
                OptieScherm(model: model) { blad = nil }
            }
        }
    }

    private func knop(_ naam: String, aan: Bool = false, doe: @escaping () -> Void) -> some View {
        Button(action: doe) {
            Text(naam.replacingOccurrences(of: "&", with: ""))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(aan ? Kleuren.paneel : Kleuren.geel)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(aan ? Kleuren.geel.opacity(0.85) : Kleuren.geel.opacity(0.15))
        }
        .buttonStyle(.plain)
    }
}

/// De troefvraag op een smal scherm: vier knoppen op een rij over het veld.
struct CompacteTroefKeuze: View {
    let model: SpelModel

    private static let tekens = ["♣", "♠", "♦", "♥"]

    var body: some View {
        VStack(spacing: 6) {
            Text(Taal.welkeTroef)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Kleuren.geel)
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { k in
                    Button { model.kiesTroef(k) } label: {
                        VStack(spacing: 0) {
                            Text(Self.tekens[k]).font(.system(size: 26))
                            Text(Taal.kleurNaam(k)).font(.system(size: 10))
                        }
                        .foregroundStyle(k >= 2 ? Color.red : Color.black)
                        .frame(width: 76, height: 58)
                        .background(Color(white: 0.97))
                        .overlay(Rectangle().stroke(Color(white: 0.5), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .background(Color(red: 14 / 255, green: 28 / 255, blue: 20 / 255).opacity(0.9))
        .overlay(Rectangle().stroke(Kleuren.geel, lineWidth: 2))
    }
}
