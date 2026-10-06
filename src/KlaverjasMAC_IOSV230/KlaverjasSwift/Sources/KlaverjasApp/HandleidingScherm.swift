import SwiftUI
import KlaverjasKit

/// De spelregels, als blad over het speelscherm heen.
///
/// Dezelfde vorm als het statistiekenscherm: dezelfde kleuren, een rollende
/// inhoud en een knop Sluiten. De tekst zelf staat in `Handleiding`.
public struct HandleidingScherm: View {
    let sluit: () -> Void

    /// Of de inhoud mag rollen. Uit voor het schermafdruk-gereedschap: wat in
    /// een ScrollView zit wordt buiten een venster niet getekend.
    let rolt: Bool

    /// Alleen om SwiftUI te laten merken dat de taal omging; de tekst komt uit
    /// Handleiding.
    let engels: Bool

    public init(rolt: Bool = true, engels: Bool = Taal.engels,
                sluit: @escaping () -> Void) {
        self.rolt = rolt
        self.engels = engels
        self.sluit = sluit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Taal.menuSpelregels)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Kleuren.geel)
                .padding(.bottom, 14)

            if rolt {
                ScrollView { inhoud }
            } else {
                inhoud
            }

            Spacer(minLength: 16)

            HStack {
                Spacer()
                Button(Taal.statSluiten, action: sluit)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(minWidth: 300, idealWidth: 520, maxWidth: 560,
               minHeight: 300, idealHeight: 620, maxHeight: 760)
        .background(Kleuren.paneel)
#if os(iOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Kleuren.paneel.ignoresSafeArea())
#endif
    }

    private var inhoud: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Handleiding.stukken(engels: engels)) { stuk in
                VStack(alignment: .leading, spacing: 5) {
                    Text(stuk.kop)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Kleuren.geel)
                    Text(stuk.tekst)
                        .font(.system(size: 13))
                        .foregroundStyle(Kleuren.geel.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
