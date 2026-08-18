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
    let model: SpelModel
    let sluit: () -> Void

    public init(model: SpelModel, sluit: @escaping () -> Void) {
        self.model = model
        self.sluit = sluit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Taal.menuOpties.replacingOccurrences(of: "&", with: ""))
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Kleuren.geel)

            Schakelaar(Taal.menuDemo, aan: model.demo) { model.demo.toggle() }
            Schakelaar(Taal.menuOpenKaart, aan: model.openKaart) { model.openKaart.toggle() }
            Schakelaar(Taal.menuAuto, aan: model.automatisch) { model.automatisch.toggle() }

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

            Spacer(minLength: 8)

            HStack {
                Spacer()
                Button(Taal.statSluiten, action: sluit)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .font(.system(size: 15))
        .padding(20)
        .frame(minWidth: 300, idealWidth: 360, maxWidth: 460,
               minHeight: 260, idealHeight: 320, maxHeight: 420)
        .background(Kleuren.paneel)
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
