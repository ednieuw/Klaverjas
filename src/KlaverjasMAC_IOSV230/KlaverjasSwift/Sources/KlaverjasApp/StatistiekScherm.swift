import SwiftUI
import KlaverjasKit

/// De tellingen die het origineel bij het afsluiten afdrukte, nu op te vragen
/// tijdens het spel. Dezelfde regels en dezelfde volgorde als in KJ.C, met
/// Zuid en Noord als kolommen.
public struct StatistiekScherm: View {
    let stat: Statistiek
    let sluit: () -> Void

    /// Per samenspel-partner een eigen, losstaande score — zie
    /// `SpelModel.alleBewaardeDuoTellingen()`/`Bewaarplaats.schrijfDuo`. Elke
    /// `Statistiek` staat al in eigen orde ([0] = ikzelf, [1] = die partner),
    /// dus hoeft hier niet meer omgewisseld te worden.
    let duoTellingen: [String: Statistiek]

    /// Eén samenspel-partner verwijderen. Ontbreekt hij, dan komt er geen knop bij de partners.
    let wisPartner: ((String) -> Void)?

    /// De partner met wie nu samen gespeeld wordt: die is niet te verwijderen, want de lopende partij
    /// schrijft zijn tellingen toch weer terug.
    let actievePartner: String?

    /// De partners zoals ze nu in beeld zijn: begint als `duoTellingen` en verliest er een bij elke
    /// verwijdering, want het blad leest de bewaarplaats niet opnieuw.
    @State private var duo: [String: Statistiek]
    @State private var vraagtOmWissenPartner: String?

    /// Of de lijst mag rollen. In het programma altijd; het
    /// schermafdruk-gereedschap zet hem uit, omdat de inhoud van een ScrollView
    /// buiten een venster niet getekend wordt en de afdruk dan leeg blijft.
    let rolt: Bool

    /// Hoeveel tactieken er hoogstens in de lijst komen. In het programma alle;
    /// een schermafdruk toont er een handvol, zodat de tellingen erboven in
    /// beeld blijven in plaats van weggedrukt te worden.
    let maxTactieken: Int?

    /// Alles op nul zetten. Ontbreekt hij, dan komt de knop er niet — dat is
    /// wat het schermafdruk-gereedschap en de previews willen.
    let wis: (() -> Void)?

    @State private var vraagtOmWissen = false

    public init(stat: Statistiek, duoTellingen: [String: Statistiek] = [:],
                rolt: Bool = true, maxTactieken: Int? = nil,
                wis: (() -> Void)? = nil,
                wisPartner: ((String) -> Void)? = nil,
                actievePartner: String? = nil,
                sluit: @escaping () -> Void) {
        self.stat = stat
        self.duoTellingen = duoTellingen
        self.wisPartner = wisPartner
        self.actievePartner = actievePartner
        _duo = State(initialValue: duoTellingen)
        self.rolt = rolt
        self.maxTactieken = maxTactieken
        self.wis = wis
        self.sluit = sluit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Taal.statTitel)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Kleuren.geel)
                .padding(.bottom, 14)

            if stat.leeg && duo.isEmpty {
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
                // Wissen kan niet ongedaan gemaakt worden, dus er hoort een
                // vraag tussen. Links, ver van Sluiten vandaan.
                if let wis, !stat.leeg {
                    if vraagtOmWissen {
                        Text(Taal.statWissenZeker)
                            .font(.system(size: 13))
                            .foregroundStyle(Kleuren.geel.opacity(0.85))
                        Button(Taal.statWissenJa) {
                            vraagtOmWissen = false
                            wis()
                            sluit()
                        }
                        Button(Taal.statWissenNee) { vraagtOmWissen = false }
                    } else {
                        Button(Taal.statWissen) { vraagtOmWissen = true }
                    }
                }
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
#if os(iOS)
        // Een blad vult op een telefoon het hele scherm. Zonder deze laag
        // blijven er witte stroken boven en onder de inhoud staan, want de maat
        // hierboven is bedoeld voor het losse venster op de Mac.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Kleuren.paneel.ignoresSafeArea())
#endif
    }

    /// De tellingen, de samenspel-partners en de tactieklijst onder elkaar.
    /// `tellingen` alleen als er ook echt iets in `stat` staat — wie nog
    /// nooit alleen speelde, alleen samen, hoeft geen rij nullen boven zijn
    /// echte samenspel-cijfers te zien.
    private var inhoud: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !stat.leeg {
                tellingen
            }
            if !duo.isEmpty {
                if !stat.leeg {
                    Divider().overlay(Kleuren.geel.opacity(0.25)).padding(.vertical, 16)
                }
                samenspel
            }
            if !stat.gebruikteTactieken.isEmpty {
                Divider().overlay(Kleuren.geel.opacity(0.25)).padding(.vertical, 16)
                tactieken
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Eén regel per bewaarde samenspel-partner, de actiefste (de meeste
    /// spellen) eerst. `partijen` is de kortste, herkenbaarste samenvatting
    /// van "hoe staan we ervoor" — dezelfde regel als bovenaan `tellingen`
    /// leest hier net zo makkelijk terug als "3 – 1".
    private var samenspel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Taal.statSamenspel)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Kleuren.geel)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(gesorteerdeDuoPartners, id: \.naam) { p in
                    HStack(spacing: 8) {
                        Text(p.naam)
                            .font(.system(size: 12))
                            .foregroundStyle(Kleuren.geel.opacity(0.9))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(p.stat.partijen[0]) – \(p.stat.partijen[1])")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Kleuren.geel)
                            .monospacedDigit()
                        partnerKnop(p.naam)
                    }
                }
            }
        }
    }

    /// Rechts op de regel: een prullenbak, of — na een tik — de vraag met Ja en Nee. Weg voor de partner met
    /// wie nu gespeeld wordt, en weg als het scherm geen manier heeft om te verwijderen.
    @ViewBuilder
    private func partnerKnop(_ naam: String) -> some View {
        if wisPartner != nil && naam != actievePartner {
            if vraagtOmWissenPartner == naam {
                Text(Taal.statPartnerWissenZeker(naam))
                    .font(.system(size: 11))
                    .foregroundStyle(Kleuren.geel.opacity(0.85))
                    .lineLimit(1)
                Button(Taal.statWissenJa) {
                    vraagtOmWissenPartner = nil
                    wisPartner?(naam)
                    duo.removeValue(forKey: naam)
                }
                Button(Taal.statWissenNee) { vraagtOmWissenPartner = nil }
            } else {
                Button { vraagtOmWissenPartner = naam } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Kleuren.geel.opacity(0.8))
                        .frame(minWidth: 28, minHeight: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Taal.statPartnerWissen)
            }
        }
    }

    private var gesorteerdeDuoPartners: [(naam: String, stat: Statistiek)] {
        duo
            .map { (naam: $0.key, stat: $0.value) }
            .sorted { a, b in
                let spellenA = a.stat.spellen[0] + a.stat.spellen[1]
                let spellenB = b.stat.spellen[0] + b.stat.spellen[1]
                return spellenA != spellenB ? spellenA > spellenB : a.naam < b.naam
            }
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

            // De lopende partij bovenaan: dat is het enige getal dat nú telt.
            // Alles eronder gaat over alle partijen bij elkaar.
            regel(Taal.statStand, stat.totaal)
            regel(Taal.statPartijen, stat.partijen)
            regel(Taal.statSpellen, stat.spellen)
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

            // Ook de superroem per kant: hij gaat naar wie de slag pakt, dus
            // hoort hij in dezelfde twee kolommen als de rest.
            regel(Taal.statSuperroem, stat.superroem)
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
                        // 70 is niet van 1994 maar van de zoekende speler;
                        // de tactieknamen blijven daarom ongemoeid.
                        Text(t.nummer == 70 ? Taal.statTactiekZoeken
                                            : t.nummer == 71 ? Taal.statTactiekClaude
                                            : Taal.tactiekNaam(t.nummer))
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
