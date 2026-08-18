import SwiftUI
import KlaverjasKit

/// De tellingen die het origineel bij het afsluiten afdrukte, nu op te vragen
/// tijdens het spel. Dezelfde regels en dezelfde volgorde als in KJ.C, met
/// Zuid en Noord als kolommen.
public struct StatistiekScherm: View {
    let stat: Statistiek
    let sluit: () -> Void

    /// Of de lijst mag rollen. In het programma altijd; het
    /// schermafdruk-gereedschap zet hem uit, omdat de inhoud van een ScrollView
    /// buiten een venster niet getekend wordt en de afdruk dan leeg blijft.
    let rolt: Bool

    /// Hoeveel tactieken er hoogstens in de lijst komen. In het programma alle;
    /// een schermafdruk toont er een handvol, zodat de tellingen erboven in
    /// beeld blijven in plaats van weggedrukt te worden.
    let maxTactieken: Int?

    public init(stat: Statistiek, rolt: Bool = true, maxTactieken: Int? = nil,
                sluit: @escaping () -> Void) {
        self.stat = stat
        self.rolt = rolt
        self.maxTactieken = maxTactieken
        self.sluit = sluit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Taal.statTitel)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Kleuren.geel)
                .padding(.bottom, 14)

            if stat.leeg {
                Text(Taal.statNogNiets)
                    .foregroundStyle(Kleuren.geel.opacity(0.8))
                    .padding(.vertical, 20)
            } else {
                // Met alle tactieken erbij wordt de lijst al gauw langer dan
                // een laptopscherm hoog is, dus hij mag rollen.
                if rolt {
                    ScrollView { inhoud }
                } else {
                    inhoud
                }
            }

            Spacer(minLength: 16)

            HStack {
                Spacer()
                Button(Taal.statSluiten, action: sluit)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        // Geen vaste maat: op de Mac neemt het blad de gewenste maat aan, op
        // een telefoon vult het het scherm. Een vaste breedte van 520 punten
        // paste niet op een iPhone van 393.
        .frame(minWidth: 300, idealWidth: 520, maxWidth: 560,
               minHeight: 300, idealHeight: 620, maxHeight: 760)
        .background(Kleuren.paneel)
    }

    /// De tellingen en de tactieklijst onder elkaar.
    private var inhoud: some View {
        VStack(alignment: .leading, spacing: 0) {
            tellingen
            if !stat.gebruikteTactieken.isEmpty {
                Divider().overlay(Kleuren.geel.opacity(0.25)).padding(.vertical, 16)
                tactieken
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tellingen: some View {
        Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 7) {
            GridRow {
                Color.clear.frame(width: 0, height: 0).gridColumnAlignment(.leading)
                Text(Taal.zuid)
                Text(Taal.noord)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Kleuren.geel.opacity(0.7))

            GridRow {
                Divider().overlay(Kleuren.geel.opacity(0.25)).gridCellColumns(3)
            }

            regel(Taal.statPartijen, stat.partijen)
            regel(Taal.statSpellen, stat.spellen)
            regel(Taal.statStand, stat.totaal)
            regel(Taal.statKaartpunten, stat.kaartpunten)
            regel(Taal.statTroefpunten, stat.troefpunten)
            regel(Taal.statTroefkaarten, stat.troefkaarten)
            regel(Taal.statRoempunten, stat.roempunten)
            regel(Taal.statPit, stat.pit)
            regel(Taal.statTegenpit, stat.tegenpit)
            regel(Taal.statNat, stat.nat)

            GridRow {
                Divider().overlay(Kleuren.geel.opacity(0.25)).gridCellColumns(3)
            }

            GridRow {
                Text(Taal.statSuperroem)
                    .fontWeight(.semibold)
                    .gridColumnAlignment(.leading)
                Text("\(stat.superroem)")
                    .gridCellColumns(2)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Kleuren.geel)
        .monospacedDigit()
    }

    /// De tactieken die in beeld komen.
    private var getoondeTactieken: [(nummer: Int, aantal: Int64)] {
        let alle = stat.gebruikteTactieken
        guard let n = maxTactieken else { return alle }
        return Array(alle.prefix(n))
    }

    private func regel(_ kop: String, _ paar: [Int64]) -> some View {
        GridRow {
            Text(kop).fontWeight(.semibold).gridColumnAlignment(.leading)
            Text("\(paar[0])")
            Text("\(paar[1])")
        }
    }

    /// Hoe vaak elke tactiek is toegepast. Het origineel drukte dit alleen af
    /// als de computer beide kanten speelde; hier staat het er altijd bij zodra
    /// er iets te tellen valt.
    private var tactieken: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Taal.statTactiek)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Kleuren.geel)
            Text(Taal.statTactiekUitleg)
                .font(.system(size: 11))
                .foregroundStyle(Kleuren.geel.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            // Eén regel per tactiek: nummer, wat de computer erbij doet, en
            // hoe vaak. Het origineel drukte ze vijf naast elkaar af, maar dat
            // was zonder namen.
            VStack(alignment: .leading, spacing: 4) {
                ForEach(getoondeTactieken, id: \.nummer) { t in
                    HStack(spacing: 8) {
                        Text("\(t.nummer)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Kleuren.paneel)
                            .frame(width: 24, height: 16)
                            .background(Kleuren.geel.opacity(0.85))
                        Text(Taal.tactiekNaam(t.nummer))
                            .font(.system(size: 11))
                            .foregroundStyle(Kleuren.geel.opacity(0.9))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(t.aantal, format: .number)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Kleuren.geel)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}
