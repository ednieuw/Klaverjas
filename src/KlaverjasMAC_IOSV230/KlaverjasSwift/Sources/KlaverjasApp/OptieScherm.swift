import SwiftUI
import KlaverjasKit

/// De schakelaars uit het menu Opties, als eigen blad.
///
/// Op een telefoon is er in de knoppenbalk geen ruimte voor vier schakelaars
/// naast elkaar. Bewust géén `Menu`: dat leunt op een stuk UIKit dat zichzelf
/// in de SwiftUI-hiërarchie hangt, wat een waarschuwing over
/// `_UIReparentingView` in de foutmeldingen oplevert. Een blad met gewone
/// knoppen doet hetzelfde en blijft van onszelf.
public struct OptieScherm: View {
    @ObservedObject var model: SpelModel
    let sluit: () -> Void

    /// Voor de kaartjes van de vorige slag. Op een telefoon is er geen paneel,
    /// dus staan die hier. Staat er wél een paneel naast het speelveld (iPad, Mac), dan toont dat de vorige
    /// slag al en geeft de aanroeper hier `nil` mee: de rij verdwijnt dan uit dit blad.
    let beelden: Kaartbeelden?
    let displayScale: CGFloat

    /// Sluit dit blad en opent daarna, ná het sluiten, de spelregels — niet
    /// terwijl dit blad nog open staat. Zie de aantekening bij de knop
    /// hieronder.
    let toonSpelregels: () -> Void

    /// Of het midden van het blad mag rollen als het niet past. In het programma altijd; de balk is dan
    /// verborgen, en het blad is hoog genoeg gemaakt zodat het op een gewoon venster nooit hoeft. Het
    /// schermafdruk-gereedschap zet het uit, omdat de inhoud van een ScrollView buiten een venster niet
    /// getekend wordt.
    let rolt: Bool

    public init(model: SpelModel, beelden: Kaartbeelden? = nil,
                displayScale: CGFloat = 2, rolt: Bool = true,
                sluit: @escaping () -> Void,
                toonSpelregels: @escaping () -> Void) {
        self.rolt = rolt
        self.model = model
        self.beelden = beelden
        self.displayScale = displayScale
        self.sluit = sluit
        self.toonSpelregels = toonSpelregels
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Taal.menuOpties.replacingOccurrences(of: "&", with: ""))
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Kleuren.geel)

            // De titel en de knoppen onderaan blijven staan. Past het midden, dan staat het gewoon
            // op het blad, zonder scrollbalk; past het niet (een klein venster, of een telefoon
            // met veel opties open), dan rolt het zonder zichtbare balk.
            if rolt {
                ViewThatFits(in: .vertical) {
                    keuzes
                    ScrollView { keuzes }
                        .scrollIndicators(.hidden)
                }
                Spacer(minLength: 0)
            } else {
                keuzes
                Spacer(minLength: 8)
            }

            // Spelregels staat hier weer, op Ed's verzoek: die raadpleeg je
            // zelden, dus hij hoefde niet meer in de knoppenbalk ernaast te
            // staan — dat gaf daar meer ruimte voor een groter lettertype.
            //
            // Wél via `toonSpelregels()`, niet door hier zelf een sheet te
            // openen: dit blad is zelf al een blad, en een blad uit een blad
            // opentrekken laat AppKit op de Mac midden in zijn opmaak opnieuw
            // meten ("It's not legal to call -layoutSubtreeIfNeeded on a view
            // which is already being laid out"). `toonSpelregels()` sluit dit
            // blad eerst en opent de spelregels pas ná die animatie, bij de
            // aanroeper (`Knoppenbalk`/`Paneel`) — nooit twee bladen tegelijk.
            HStack {
                Button(Taal.menuSpelregels, action: toonSpelregels)
                Spacer()
                Button(Taal.statSluiten, action: sluit)
                    .keyboardShortcut(.cancelAction)
            }

            // Onderaan, klein: welke versie dit is. Dezelfde waarde die
            // `VerbindScherm` als appversie meestuurt in de BLE-begroeting —
            // handig om te zien of twee toestellen wel dezelfde draaien vóór
            // je gaat samenspelen.
            Text(Taal.menuVersie(AppVersie.huidig))
                .font(.system(size: 11))
                .foregroundStyle(Kleuren.geel.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .font(.system(size: 15))
        .padding(20)
        // Hoog genoeg voor alles tegelijk: de drie speelwijzen van Noord én van Zuid (die bij Demo
        // erbij komt) en de taal, plus de vorige slag als die hier staat. Op een breed scherm staat die
        // in het paneel en is het blad dus lager.
        .frame(minWidth: 320, idealWidth: 380, maxWidth: 480,
               minHeight: 380, idealHeight: beelden == nil ? 660 : 780, maxHeight: 780)
        .background(Kleuren.paneel)
#if os(iOS)
        // Een blad vult op een telefoon het hele scherm. Zonder deze laag
        // blijven er witte stroken boven en onder de inhoud staan, want de maat
        // hierboven is bedoeld voor het losse venster op de Mac.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Kleuren.paneel.ignoresSafeArea())
#endif
    }

    /// Het midden van het blad: de schakelaars, de speelwijze per kant, de taal en de vorige slag.
    private var keuzes: some View {
        VStack(alignment: .leading, spacing: 16) {
            Schakelaar(Taal.menuDemo, aan: model.demo) { model.demo.toggle() }
            Schakelaar(Taal.menuOpenKaart, aan: model.openKaart) { model.openKaart.toggle() }
            Schakelaar(Taal.menuAuto, aan: model.automatisch) { model.automatisch.toggle() }
            Schakelaar(Taal.menuSnel, aan: model.snel) { model.snel.toggle() }

            Divider().overlay(Kleuren.geel.opacity(0.3))

            // Welke speelwijze elke kant gebruikt. Zuid telt alleen mee als de
            // computer die kant speelt; anders speel je zelf.
            Text(Taal.menuSpeelwijze)
                .fontWeight(.semibold)
                .foregroundStyle(Kleuren.geel)
            SpeelwijzeKeuze(kop: Taal.menuNoordSpeelt, gekozen: model.stijlNoord) {
                model.stijlNoord = $0
            }
            // Zuid alleen als de computer die kant speelt; anders speel je zelf
            // en valt er niets te kiezen.
            if model.demo {
                SpeelwijzeKeuze(kop: Taal.menuZuidSpeelt, gekozen: model.stijlZuid) {
                    model.stijlZuid = $0
                }
            }

            Divider().overlay(Kleuren.geel.opacity(0.3))

            HStack {
                Text(Taal.menuTaal.replacingOccurrences(of: "&", with: ""))
                    .fontWeight(.semibold)
                    .foregroundStyle(Kleuren.geel)
                Spacer()
                HStack(spacing: 0) {
                    taalKnop("NL", engelsAan: false)
                    taalKnop("EN", engelsAan: true)
                }
                .overlay(Rectangle().stroke(Kleuren.geel.opacity(0.45), lineWidth: 1))
            }

            VorigeSlagRij(view: model.view, beelden: beelden, displayScale: displayScale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func taalKnop(_ naam: String, engelsAan: Bool) -> some View {
        let gekozen = model.engels == engelsAan
        return Button { model.engels = engelsAan } label: {
            Text(naam)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(gekozen ? Kleuren.paneel : Kleuren.geel)
                .frame(width: 46, height: 26)
                .background(gekozen ? Kleuren.geel.opacity(0.85) : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// De speelwijze van één kant: de vuistregels van Ednieuw, het doorrekenen van
/// Ronlog of het hele spel doorspelen van Claude. Zowel het optieblad als het
/// paneel naast het speelveld gebruikt hem, zodat de knoppen overal even breed
/// zijn en hetzelfde aanvoelen. `gekozen`: 0 = Ednieuw, 1 = Ronlog, 2 = Claude.
struct SpeelwijzeKeuze: View {
    let kop: String
    let gekozen: Int
    let kies: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(kop)
                .font(.system(size: 13))
                .foregroundStyle(Kleuren.geel.opacity(0.8))
            VStack(alignment: .leading, spacing: 0) {
                knop(Taal.menuAiEd, gekozen: gekozen == 0) { kies(0) }
                knop(Taal.menuAiLoggen, gekozen: gekozen == 1) { kies(1) }
                knop(Taal.menuAiClaude, gekozen: gekozen == 2) { kies(2) }
            }
            .overlay(Rectangle().stroke(Kleuren.geel.opacity(0.45), lineWidth: 1))
        }
    }

    private func knop(_ naam: String, gekozen: Bool,
                      doe: @escaping () -> Void) -> some View {
        Button(action: doe) {
            Text(naam)
                .font(.system(size: 13, weight: gekozen ? .bold : .regular))
                .foregroundStyle(gekozen ? Kleuren.paneel : Kleuren.geel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .frame(height: 25)
                .background(gekozen ? Kleuren.geel.opacity(0.85) : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
