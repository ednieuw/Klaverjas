import SwiftUI
import KlaverjasKit
import KlaverjasKaarten

/// Het speelscherm voor een smal scherm: de telefoon rechtop.
///
/// Dezelfde vier rijen en hetzelfde speelveld als op de Mac, maar onder elkaar
/// en in een waaier. De stand staat in een regel bovenin in plaats van in een
/// paneel ernaast; voor een paneel van 250 punten is geen ruimte.
struct CompactScherm: View {
    @ObservedObject var model: SpelModel
    let beelden: Kaartbeelden
    let displayScale: CGFloat
    /// Alleen om SwiftUI te laten merken dat de taal omging; de teksten komen
    /// uit Taal.
    let engels: Bool

    /// Aanraakscherm of venster; zie `Balk`.
    var aanraak = SpelScherm.aanraakscherm

    /// De aansporing hoort alleen bij spel uit én als er echt gewacht wordt.
    /// Staat "automatisch doorgaan" aan, dan valt er niets te tikken.
    var aansporing: String? {
        guard model.view.spelUit, model.modus == .verder else { return nil }
        return aanraak ? Taal.tikVerder : Taal.klikOfToets
    }

    /// Staat het paneel ernaast? Dan hoeven de standregel en de knoppenbalk
    /// niet: het paneel toont diezelfde stand en heeft dezelfde knoppen, en de
    /// hoogte die dat scheelt komt de kaarten ten goede.
    var paneelErnaast = false

    var body: some View {
        VStack(spacing: 0) {
            Balk(tekst: model.tekst, modus: model.modus, aanraak: aanraak,
                 toonAansporing: aansporing == nil)
            if !paneelErnaast { Standregel(view: model.view, aansporing: aansporing) }

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
                            for (vak, kaart, _) in vakken.reversed()
                            where vak.contains(punt) && model.neemtTik() {
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

            if !paneelErnaast {
                Knoppenbalk(model: model, beelden: beelden, displayScale: displayScale)
            }
        }
        .background(Kleuren.achtergrond)
    }

    /// Altijd mijn eigen rijen — de onderste twee — ongeacht of ik Zuid of
    /// Noord ben; ze staan toch altijd onderaan, zie `teken(_:_:)`.
    private func klikVakken(_ ind: CompactIndeling) -> [(CGRect, KaartView, Bool)] {
        let v = model.view
        var uit: [(CGRect, KaartView, Bool)] = []
        for kaart in v.mijnTafel {
            let plek = min(max(kaart.plek, 0), 3)
            uit.append((ind.tafelVak(plek: plek, y: ind.yZuidTafel), kaart, false))
        }
        for (i, vak) in ind.rij(v.mijnHand.count, y: ind.yZuidHand,
                                spatie: ind.handSpatie, verschoven: true).enumerated() {
            uit.append((vak, v.mijnHand[i], true))
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
            ctx.stroke(Path(ind.veldPlek(v.relatieveSpeler(speler))), with: .color(Kleuren.veldRand.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        for s in v.slag {
            let vak = ind.veldPlek(v.relatieveSpeler(s.speler))
            schaduw(ctx, vak)
            if let beeld = beelden.voor(s.naam, s.kleur, schaal: px) {
                ctx.draw(Image(decorative: beeld, scale: displayScale).interpolation(.none), in: vak)
            }
        }

        for (i, vak) in ind.rij(v.zijnHand.count, y: ind.yNoordHand,
                                spatie: ind.noordHandSpatie, verschoven: true).enumerated() {
            tekenKaart(ctx, v.zijnHand[i], vak, px)
        }

        tekenTafelRij(ctx, ind, v.zijnTafel, v.zijnOnder, y: ind.yNoordTafel,
                      peekOmlaag: true, px: px)
        tekenTafelRij(ctx, ind, v.mijnTafel, v.mijnOnder, y: ind.yZuidTafel,
                      peekOmlaag: false, px: px)

        for (i, vak) in ind.rij(v.mijnHand.count, y: ind.yZuidHand,
                                spatie: ind.handSpatie, verschoven: true).enumerated() {
            let op = model.magKlikken(true)
                ? vak.offsetBy(dx: 0, dy: -CGFloat(2 * ind.schaal)) : vak
            tekenKaart(ctx, v.mijnHand[i], op, px)
        }
    }

    private func tekenTafelRij(_ ctx: GraphicsContext, _ ind: CompactIndeling,
                               _ open: [KaartView], _ gedekt: [Bool],
                               y: CGFloat, peekOmlaag: Bool, px: Int) {
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

    /// Wat er bij spel uit op de plek van "Spel uit" komt. Is het niets, dan
    /// staat er gewoon "Spel uit". De aansporing om verder te gaan staat hier
    /// en niet in de balk erboven, zodat die de volle breedte houdt voor de
    /// uitslag — en die is aan het eind van een spel het langst.
    var aansporing: String?

    var body: some View {
        HStack(spacing: 14) {
            if view.spelUit {
                deel(aansporing ?? Taal.spelUit, "")
            } else {
                troefDeel
                deel(Taal.slagVanAcht(max(1, view.slagNr)), "")
            }
            Spacer(minLength: 0)
            deel(Taal.zuid, "\(view.mijnPunten)+\(view.mijnRoem)")
            deel(Taal.noord, "\(view.zijnPunten)+\(view.zijnRoem)")
        }
        .font(.system(size: 12))
        .monospacedDigit()
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Kleuren.paneel.opacity(0.8))
    }

    /// Troef, en alleen het teken — niet ook de naam. Op een telefoon is de regel
    /// te smal voor allebei: "Troef ♥ Harten" duwde "Slag 2 van 8" er half
    /// overheen. Het teken zegt hetzelfde en neemt een derde van de ruimte.
    ///
    /// Wel groot: dezelfde maat als de melding erboven, want dit is het gegeven
    /// dat je tijdens het spelen voortdurend nodig hebt. De rest van de regel
    /// blijft klein.
    private var troefDeel: some View {
        let k = view.troef
        let bekend = k >= 0 && k < 4
        return HStack(alignment: .center, spacing: 5) {
            if view.troefmaker != 0 {
                Text(Taal.kantKort(view.troefmakerRelatief))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Kleuren.geel)
            }
            Text(Taal.troef)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Kleuren.geel)
            if bekend {
                Troefteken(kleur: k, grootte: 18)
            } else {
                Text("-")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Kleuren.geel)
            }
        }
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
    @ObservedObject var model: SpelModel
    /// Alleen om door te geven aan het optieblad, voor de vorige slag.
    var beelden: Kaartbeelden?
    var displayScale: CGFloat = 2

    /// Welk blad er open staat. Eén enkele sheet met een keuze erin, in plaats
    /// van twee sheet-modifiers op hetzelfde onderdeel: dat tweede geeft in
    /// SwiftUI onvoorspelbare uitkomsten.
    private enum Blad: String, Identifiable {
        case statistiek, opties, spelregels, samenSpelen
        var id: String { rawValue }
    }
    @State private var blad: Blad?

    /// Gezet door `OptieScherm.toonSpelregels` vlak vóórdat dat blad zichzelf
    /// sluit — zie de aantekening bij `.sheet(onDismiss:)` hieronder.
    @State private var openSpelregelsNaSluiten = false

    var body: some View {
        // Spelregels staat niet meer in deze rij (Ed: "die zul je niet vaak
        // raadplegen") — hij zit nu in het optieblad. Met vier in plaats van
        // vijf knoppen is er ruimte over voor een groter lettertype.
        HStack(spacing: 10) {
            // Tijdens samenspel verstopt: die knop begint gewoon een eigen,
            // nieuwe partij — en breekt daarmee de lopende, gedeelde partij
            // af. Zonder deze bewaking kon één per ongeluk getikte knop
            // precies dat laten lijken op "de gast blijft in zijn eigen spel".
            if !model.inSamenspel {
                knop(Taal.menuNieuw) { model.start() }
            }
            // Verandert in "Stop samen" zodra er een verbinding is — een
            // nette, met opzet getikte manier om de partij af te sluiten,
            // naast een verbinding die vanzelf wegvalt (zie `SpelModel.stop()`/
            // `bewaakVerbinding`). `model.start()` doet precies dat: hij roept
            // zelf eerst `stop()` aan (sluit de radio netjes af) en begint
            // meteen weer een gewone, eigen partij — dezelfde bewaarde
            // puntentelling als voor het samenspel, want dat is één en
            // dezelfde `Bewaarplaats`.
            if model.inSamenspel {
                knop(Taal.duoStopSamen) { model.start() }
            } else {
                knop(Taal.menuSamenSpelen) { blad = .samenSpelen }
            }
            knop(Taal.menuStatistieken) { blad = .statistiek }
            Spacer(minLength: 0)
            knop(Taal.menuOpties) { blad = .opties }
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(Kleuren.paneel)
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
                StatistiekScherm(stat: model.view.statistiek, duoTellingen: model.alleBewaardeDuoTellingen(),
                                 wis: { if !model.inSamenspel { model.wisStatistiek() } },
                                 wisPartner: { model.wisDuoPartner($0) },
                                 actievePartner: model.actievePartner) { blad = nil }
            case .opties:
                OptieScherm(model: model, beelden: beelden, displayScale: displayScale,
                            sluit: { blad = nil },
                            toonSpelregels: { openSpelregelsNaSluiten = true; blad = nil })
            case .spelregels:
                HandleidingScherm(engels: model.engels) { blad = nil }
            case .samenSpelen:
                VerbindScherm(model: model) { blad = nil }
            }
        }
    }

    private func knop(_ naam: String, aan: Bool = false, doe: @escaping () -> Void) -> some View {
        Button(action: doe) {
            Text(naam.replacingOccurrences(of: "&", with: ""))
                // Groter dan de oorspronkelijke 12pt (Ed: "nu te klein"), maar
                // "Samen spelen"/"Play together" bleek bij 15pt zelfs zonder
                // Spelregels ernaast nog af te kappen op een iPhone. 14pt past
                // wél, en de lage krimpvloer hieronder blijft als vangnet voor
                // smallere toestellen (iPhone SE) — nooit meer een afgekapte
                // "…", hoogstens iets kleiner.
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(aan ? Kleuren.paneel : Kleuren.geel)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(aan ? Kleuren.geel.opacity(0.85) : Kleuren.geel.opacity(0.15))
        }
        .buttonStyle(.plain)
    }
}

/// De troefvraag op een smal scherm: vier knoppen op een rij over het veld.
struct CompacteTroefKeuze: View {
    @ObservedObject var model: SpelModel

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
                        .foregroundStyle(Kleuren.kaartKleur(k))
                        .frame(width: 76, height: 58)
                        .background(Color(white: 0.97))
                        .overlay(Rectangle().stroke(Color(white: 0.5), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            // Een kaart aantikken laat zich niet raden; hier staat het.
            Text(Taal.troefViaKaart)
                .font(.system(size: 11))
                .foregroundStyle(Kleuren.geel.opacity(0.85))
        }
        .padding(8)
        .background(Color(red: 14 / 255, green: 28 / 255, blue: 20 / 255).opacity(0.9))
        .overlay(Rectangle().stroke(Kleuren.geel, lineWidth: 2))
    }
}
