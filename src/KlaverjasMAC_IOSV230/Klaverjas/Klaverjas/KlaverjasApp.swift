//
//  KlaverjasApp.swift
//  Klaverjas
//
//  Created by Ed Nieuwenhuys on 15/08/2026.
//

import SwiftUI
import KlaverjasApp
import KlaverjasKit

/// Het programma zelf stelt niets voor: al het werk zit in het pakket
/// KlaverjasSwift. Dit doelwit bestaat alleen om er een app van te maken die
/// de App Store aankan — het scherm, de kaarten en de speellogica komen
/// ongewijzigd uit het pakket, en zijn daar ook getoetst.
@main
struct KlaverjasProgramma: App {
    init() {
        // De taal van het apparaat volgen; in het scherm zelf kan het om.
        Taal.kiesStandaardtaal()
    }

    var body: some Scene {
        WindowGroup {
            SpelScherm()
                #if os(macOS)
                // Onder deze maat wordt het speelveld krap: de vier rijen en
                // het paneel moeten er samen op passen.
                .frame(minWidth: 1000, minHeight: 780)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1300, height: 950)
        .windowResizability(.contentMinSize)
        #endif
    }
}
