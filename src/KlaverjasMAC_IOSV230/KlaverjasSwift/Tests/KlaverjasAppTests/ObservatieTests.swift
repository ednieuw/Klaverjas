import Testing
import Foundation
import Combine
@testable import KlaverjasApp
@testable import KlaverjasKit

/// Het model is van `@Observable` (iOS 17) naar `ObservableObject` gegaan, zodat
/// de app vanaf iOS 16 draait. Bij `@Observable` volgt SwiftUI de eigenschappen
/// zelf; nu moet het model zeggen dat er iets verandert. Vergeet je één
/// `@Published`, dan bouwt alles nog steeds en blijft het scherm stilstaan —
/// vandaar deze proef.
@Suite(.serialized)
@MainActor
struct ObservatieTests {
    /// Telt hoe vaak het model zegt dat er iets gaat veranderen.
    private func teller(_ model: SpelModel) -> (get: () -> Int, houd: AnyCancellable) {
        let doos = Doos()
        let abo = model.objectWillChange.sink { _ in doos.n += 1 }
        return ({ doos.n }, abo)
    }

    private final class Doos { var n = 0 }

    /// De stap "engels" zet `Taal.engels` om (via `model.engels`'s `didSet`).
    /// Doet hij dat terwijl `FoutmeldingTests` middenin een spel zit, dan kan
    /// die daar een tekst in de verkeerde taal uit krijgen — zie de opmerking
    /// bij `Taalslot`.
    @Test("Elke schakelaar laat het scherm bijwerken")
    func schakelaarsMelden() async {
        await Taalslot.metSlot {
            let model = losModel()
            let (aantal, abo) = teller(model)
            defer { abo.cancel() }

            var verwacht = 0
            func stap(_ naam: String, _ doe: () -> Void) {
                doe()
                verwacht += 1
                #expect(aantal() >= verwacht, "\(naam) meldde geen wijziging")
            }

            stap("demo") { model.demo.toggle() }
            stap("openKaart") { model.openKaart.toggle() }
            stap("automatisch") { model.automatisch.toggle() }
            stap("zoektZuid") { model.zoektZuid.toggle() }
            stap("zoektNoord") { model.zoektNoord.toggle() }
            stap("engels") { model.engels = !model.engels }
            stap("snel") { model.snel.toggle() }
        }
    }

    @Test("Een nieuwe stand op tafel laat het scherm bijwerken")
    func toonMeldt() {
        let model = losModel()
        let (aantal, abo) = teller(model)
        defer { abo.cancel() }

        var v = SpelView()
        v.status = "slag 3"
        model.toon(v)
        #expect(aantal() > 0, "een nieuwe stand meldde geen wijziging")
        #expect(model.view.status == "slag 3")

        let voor = aantal()
        model.zetTekst("iets anders")
        #expect(aantal() > voor, "de balktekst meldde geen wijziging")
    }

    @Test("De taalknop schrijft door naar Taal")
    func taalDoorschrijven() async {
        await Taalslot.metSlot {
            let model = losModel()
            let oud = Taal.engels
            defer { Taal.engels = oud }

            model.engels = true
            #expect(Taal.engels, "de taal van de speellogica ging niet mee")
            model.engels = false
            #expect(!Taal.engels)
        }
    }
}

/// Het scherm mag een tik niet zelf tegenhouden.
///
/// Tikte je op de verkeerde stapel, dan liet het scherm de tik vallen en gebeurde
/// er niets: geen kaart, geen tekst, niets. De speelloop heeft juist een
/// antwoord klaar — "die kaart ligt op tafel" — maar dat kan alleen als de tik
/// hem bereikt.
@Suite(.serialized)
@MainActor
struct TikTests {
    @Test("Een tik gaat door, ook naar de stapel die niet aan de beurt is")
    func tikGaatDoor() {
        let model = losModel()
        var v = SpelView()
        // Midden in een slag: de tafel van Zuid is aan zet.
        v.slag = [SlagView(kleur: 0, naam: "A", speler: 2, tactiek: 0)]
        v.aanZet = Pos.tafelZuid
        model.toon(v)
        model.zetModus(.kiesKaart)

        #expect(model.neemtTik(), "het scherm nam de tik niet aan")
        // Het oplichten blijft wel beperkt tot de stapel die aan zet is.
        #expect(model.magKlikken(false), "de tafel hoort op te lichten")
        #expect(!model.magKlikken(true), "de hand hoort niet op te lichten")
    }

    @Test("Buiten je beurt neemt het scherm geen tik aan")
    func geenTikBuitenDeBeurt() {
        let model = losModel()
        model.zetModus(.wachten)
        #expect(!model.neemtTik())
        model.zetModus(.verder)
        #expect(!model.neemtTik())
    }
}

/// Een sleutelkast in het geheugen: een toets laat zo niets achter in de echte
/// instellingen van wie hem draait.
final class Kladkast: Sleutelkast {
    private var inhoud: [String: Any] = [:]
    func data(forKey sleutel: String) -> Data? { inhoud[sleutel] as? Data }
    func set(_ waarde: Any?, forKey sleutel: String) { inhoud[sleutel] = waarde }
    func removeObject(forKey sleutel: String) { inhoud[sleutel] = nil }
}

/// Een model met een eigen kladkast, los van alles.
@MainActor
func losModel() -> SpelModel {
    SpelModel(bewaarplaats: Bewaarplaats(opslag: Kladkast()))
}
