import SwiftUI
import KlaverjasKit
import KlaverjasBLE
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Het verbindingsscherm: kies openstellen of zoeken, wacht op de verbinding,
/// begroet de andere kant (`DuoOpzet`), en sluit dan aan op het spel —
/// `SpelModel.startDuoAlsGastheer(lijn:)` voor de opensteller (die draait de
/// motor en speelt gewoon door met wat er al liep) of
/// `SpelModel.startDuoAlsGast(lijn:)` voor de zoeker (die heeft geen eigen
/// motor, en krijgt alles van de gastheer).
///
/// **Wat hier nog niet bewezen is:** de radiolaag eronder (`BlePerifeer`/
/// `BleCentraal`) werkt aantoonbaar op echte hardware (Mac↔iPhone, met het
/// kale proefscherm). Dit scherm zelf — de nieuwe bedrading tussen
/// `statusStroom()` en de knoppen hier — is dat nog niet; dat kan pas met
/// twee toestellen.
public struct VerbindScherm: View {
    @ObservedObject var model: SpelModel
    let sluit: () -> Void

    private enum Stap: Equatable {
        case rolKiezen
        case bezig(String)
        case mislukt(String)
    }

    @State private var stap: Stap = .rolKiezen
    @State private var radio: (any DuoRadio)?
    @State private var taak: Task<Void, Never>?

    /// Gezet vlak vóór een geslaagde verbinding aan `SpelModel` wordt
    /// doorgegeven (`startDuoAlsGastheer`/`startDuoAlsGast`) — vanaf dat
    /// moment gebruikt de partij `radio` zelf verder, dus mag `stop()` hem
    /// niet meer afsluiten wanneer dit scherm dichtgaat.
    @State private var overgedragen = false

    /// De eigen naam voor de lijst van de ander; leeg = de naam van het toestel (die op iOS sinds versie 16
    /// altijd "iPhone" is, dus twee iPhones zouden één telling delen).
    @AppStorage("klaverjas.spelernaam.v1") private var mijnNaam = ""

    public init(model: SpelModel, sluit: @escaping () -> Void) {
        self.model = model
        self.sluit = sluit
    }

    public var body: some View {
        VStack(spacing: 20) {
            Text(Taal.duoTitel)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Kleuren.geel)

            switch stap {
            case .rolKiezen:
                Text(Taal.duoUitleg)
                    .font(.system(size: 13))
                    .foregroundStyle(Kleuren.geel.opacity(0.85))
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Taal.duoMijnNaam)
                        .font(.system(size: 12))
                        .foregroundStyle(Kleuren.geel.opacity(0.7))
                    TextField(Taal.duoNaamLeeg, text: $mijnNaam)
                        .textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 12) {
                    Button(Taal.duoOpenstellen) { begin(alsGastheer: true) }
                    Button(Taal.duoZoeken) { begin(alsGastheer: false) }
                }
            case .bezig(let tekst):
                ProgressView()
                Text(tekst)
                    .font(.system(size: 14))
                    .foregroundStyle(Kleuren.geel.opacity(0.85))
            case .mislukt(let tekst):
                Text(tekst)
                    .font(.system(size: 14))
                    .foregroundStyle(Kleuren.geel)
                    .multilineTextAlignment(.center)
                Button(Taal.duoOpnieuw) { stop(); stap = .rolKiezen }
            }

            Spacer(minLength: 4)

            Button(Taal.duoAnnuleren) { stop(); sluit() }
                .keyboardShortcut(.cancelAction)
        }
        .font(.system(size: 15))
        .padding(24)
        .frame(minWidth: 320, idealWidth: 380, minHeight: 220, idealHeight: 260)
        .background(Kleuren.paneel)
#if os(iOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Kleuren.paneel.ignoresSafeArea())
#endif
        .onDisappear { stop() }
    }

    private func begin(alsGastheer: Bool) {
        let gekozenRadio: any DuoRadio = alsGastheer ? BlePerifeer() : BleCentraal()
        radio = gekozenRadio
        stap = .bezig(alsGastheer ? Taal.duoOpenstellen : Taal.duoZoeken)

        taak = Task {
            await gekozenRadio.start()
            for await status in await gekozenRadio.statusStroom() {
                if Task.isCancelled { return }
                switch status {
                case .bezig(let tekst):
                    stap = .bezig(tekst)
                case .verbonden:
                    stap = .bezig(Taal.duoBegroeten)
                    await begroet(alsGastheer: alsGastheer, lijn: gekozenRadio)
                    return
                case .mislukt(let tekst):
                    stap = .mislukt(tekst)
                    return
                }
            }
        }
    }

    private func begroet(alsGastheer: Bool, lijn: any DuoLijn) async {
        let appversie = AppVersie.huidig
        let naam = eigenNaam()
        let eigenTellingen = model.alleBewaardeDuoTellingen()

        let resultaat = alsGastheer
            ? await DuoOpzet.alsGastheer(lijn: lijn, appversie: appversie, naam: naam,
                                         eigenTellingen: eigenTellingen)
            : await DuoOpzet.alsGast(lijn: lijn, appversie: appversie, naam: naam,
                                    eigenTellingen: eigenTellingen)
        BleLog.zeg("begroeting klaar: \(resultaat)")

        guard !Task.isCancelled else {
            BleLog.zeg("begroeting: taak was al afgebroken, niets meer gedaan")
            return
        }
        switch resultaat {
        case .klaar(let partnerNaam, let statistiek):
            guard let radio else {
                BleLog.zeg("begroeting geslaagd maar radio was al weg — niets gestart")
                return
            }
            if alsGastheer {
                model.startDuoAlsGastheer(lijn: radio, partnerNaam: partnerNaam, beginStatistiek: statistiek)
            } else {
                model.startDuoAlsGast(lijn: radio, partnerNaam: partnerNaam, beginStatistiek: statistiek)
            }
            // Vanaf hier is `radio` van de partij, niet meer van dit scherm —
            // `stop()` (via `.onDisappear`, zodra `sluit()` hieronder het blad
            // dichtdoet) mag hem niet meer afsluiten. Zonder dit werd de
            // net gestarte verbinding een fractie van een seconde later alweer
            // afgebroken: de eerste stand kwam nog aan, en alles daarna niet
            // meer ("kon niet versturen (geen verbinding)") — precies wat op
            // hardware "geen update meer, beide schermen onbedienbaar" leek.
            overgedragen = true
            sluit()
        case .versieverschil(let andereVersie):
            stap = .mislukt(Taal.duoAndereVersie(andereVersie))
        case .onverwacht:
            stap = .mislukt(Taal.duoOnverwacht)
        }
    }

    private func stop() {
        taak?.cancel()
        taak = nil
        // Na een geslaagde verbinding is `radio` overgedragen aan de partij
        // (`overgedragen`, zie `begroet(alsGastheer:lijn:)`) — dan mag deze
        // opruimfunctie, die ook via `.onDisappear` afgaat zodra `sluit()` het
        // blad dichtdoet, de verbinding niet alsnog afsluiten.
        if !overgedragen, let radio {
            Task { await radio.stop() }
        }
        radio = nil
    }

    /// De gekozen naam, anders die van het toestel. Eén regel en geen kale spaties: de naam gaat in een
    /// regel van het protocol.
    private func eigenNaam() -> String {
        let gekozen = mijnNaam
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return gekozen.isEmpty ? Self.toestelnaam() : String(gekozen.prefix(24))
    }

    private static func toestelnaam() -> String {
#if os(iOS)
        UIDevice.current.name
#else
        Host.current().localizedName ?? "Mac"
#endif
    }
}
