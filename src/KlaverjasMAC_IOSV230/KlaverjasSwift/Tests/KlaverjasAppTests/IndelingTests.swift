import Testing
import SwiftUI
@testable import KlaverjasApp

/// Welke indeling krijgt welk apparaat? De regel heeft drie uitkomsten en het
/// is van buiten niet te zien welke je krijgt, dus staat hij hier per maat
/// vastgelegd. `aanraak` is een parameter en geen `#if`, zodat deze proeven op
/// een Mac ook kunnen nagaan wat een iPad zou doen.
@MainActor
struct IndelingTests {
    private static let telefoonStaand = CGSize(width: 393, height: 852)
    private static let telefoonDwars = CGSize(width: 852, height: 393)
    private static let grooteTelefoonDwars = CGSize(width: 956, height: 440)
    private static let iPadStaand = CGSize(width: 810, height: 1080)
    private static let iPad102Dwars = CGSize(width: 1080, height: 810)
    private static let iPad5Dwars = CGSize(width: 1024, height: 768)
    private static let iPad11Dwars = CGSize(width: 1194, height: 834)
    private static let iPadProDwars = CGSize(width: 1366, height: 1024)
    private static let macVenster = CGSize(width: 1300, height: 950)

    @Test("Een telefoon krijgt altijd de smalle indeling, zonder paneel")
    func telefoon() {
        for maat in [Self.telefoonStaand, Self.telefoonDwars, Self.grooteTelefoonDwars] {
            #expect(SpelScherm.neemSmalScherm(maat, aanraak: true),
                    "\(maat) kreeg de brede indeling")
            #expect(!SpelScherm.paneelNaastSmal(maat),
                    "\(maat) kreeg een paneel dat er niet past")
        }
    }

    @Test("Een tablet dwars krijgt het paneel ernaast")
    func tabletDwars() {
        for maat in [Self.iPad102Dwars, Self.iPad5Dwars, Self.iPad11Dwars] {
            // De brede indeling past hier alleen op ware grootte en levert
            // dan juist kleinere kaarten op.
            #expect(SpelScherm.neemSmalScherm(maat, aanraak: true),
                    "\(maat) koos de brede indeling")
            #expect(SpelScherm.paneelNaastSmal(maat), "\(maat) kreeg geen paneel")
        }
    }

    @Test("Een tablet staand heeft geen ruimte voor een paneel")
    func tabletStaand() {
        #expect(SpelScherm.neemSmalScherm(Self.iPadStaand, aanraak: true))
        #expect(!SpelScherm.paneelNaastSmal(Self.iPadStaand))
    }

    @Test("De grootste tablet haalt de brede indeling wel")
    func groteTablet() {
        #expect(!SpelScherm.neemSmalScherm(Self.iPadProDwars, aanraak: true),
                "hier past de brede indeling op dubbele grootte")
    }

    @Test("Een Mac-venster houdt de brede indeling zodra die past")
    func macVensterHoudtBreed() {
        #expect(!SpelScherm.neemSmalScherm(Self.macVenster, aanraak: false))
        // Ook als hij maar net past: een venster dat je kleiner sleept hoort
        // kleinere kaarten te geven, niet ineens de indeling van een telefoon.
        #expect(!SpelScherm.neemSmalScherm(Self.iPad102Dwars, aanraak: false))
        // Te smal blijft te smal.
        #expect(SpelScherm.neemSmalScherm(CGSize(width: 700, height: 900), aanraak: false))
    }

    @Test("Het paneel ernaast kost de kaarten niets")
    func paneelKostNiets() {
        // Op een tablet dwars wordt de smalle indeling toch al tot ongeveer de
        // helft verkleind. Het paneel snoept breedte af, maar de standregel en
        // de knoppenbalk vervallen — onder de streep blijven de kaarten even
        // groot of groter. Zonder dat zou dit een verslechtering zijn.
        for maat in [Self.iPad102Dwars, Self.iPad5Dwars, Self.iPad11Dwars] {
            let zonder = effectieveSchaal(maat, paneel: 0, extraRegels: 28 + 50)
            let met = effectieveSchaal(maat, paneel: SpelScherm.paneelBreed, extraRegels: 0)
            #expect(met >= zonder - 0.01,
                    "\(maat): met paneel \(met), zonder \(zonder)")
        }
    }

    /// Hoe groot een kaart uiteindelijk in beeld komt: de hele vergroting maal
    /// de krimp die nodig is om de vier rijen te laten passen.
    private func effectieveSchaal(_ maat: CGSize, paneel: CGFloat,
                                  extraRegels: CGFloat) -> Double {
        let breed = maat.width - paneel
        let beschikbaar = maat.height - 34 - extraRegels
        let k = Double(CompactIndeling.heleSchaal(breed))
        let nodig = CompactIndeling.natuurlijkeHoogte(breed)
        return k * min(1, Double(beschikbaar / nodig))
    }
}
