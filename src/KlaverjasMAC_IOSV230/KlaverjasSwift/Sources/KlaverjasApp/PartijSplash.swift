import SwiftUI
import KlaverjasKit

/// Het grote scherm bij het einde van een partij (1500 punten), in plaats
/// van de gewone kleine regel bovenin die tot nu toe ook voor een gewoon
/// "Spel uit" gebruikt werd — een partij winnen mag gezien worden. Dekt het
/// hele speelveld af; een tik gaat verder, net als de regel die hij vervangt
/// (zie `SpelScherm.toonPartijSplash` voor de tik-afhandeling en de gating:
/// niet tijdens `snel`/automatisch spelen, daar kijkt niemand mee).
struct PartijSplash: View {
    let view: SpelView
    let engels: Bool

    var body: some View {
        ZStack {
            Kleuren.achtergrond.opacity(0.98).ignoresSafeArea()
            VStack(spacing: 16) {
                if !view.partijGelijkspel {
                    Image(systemName: view.partijGewonnenDoorMij ? "trophy.fill" : "flag.checkered")
                        .font(.system(size: 60))
                        .foregroundStyle(view.partijGewonnenDoorMij
                                         ? Kleuren.geel : Kleuren.zwartTeken.opacity(0.7))
                }
                Text(kop)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Kleuren.geel)
                    .multilineTextAlignment(.center)
                Text(Taal.partijStand(view.mijnPartijen, view.zijnPartijen))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Kleuren.zwartTeken)
                Text(view.melding)
                    .font(.system(size: 13))
                    .foregroundStyle(Kleuren.zwartTeken.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Text(Taal.tikVerder)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Kleuren.geel.opacity(0.85))
                    .padding(.top, 10)
            }
            .padding(32)
        }
        .contentShape(Rectangle())
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    private var kop: String {
        if view.partijGelijkspel { return Taal.partijGelijk }
        return view.partijGewonnenDoorMij ? Taal.partijGewonnen : Taal.partijVerloren
    }
}
