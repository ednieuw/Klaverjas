import Testing
@testable import KlaverjasKit

/// De speelloop met een menselijke speler erin. De C#-versie testte dit met
/// `KlaverjasTest mens 300`: een automaat speelt Zuid, en er wordt gekeken of
/// de lus niet vastloopt en of de punten blijven kloppen.
///
/// Dit is de enige test die de vraag-en-antwoordkant raakt: de speelloop stelt
/// een vraag, wacht, en gaat verder met wat er terugkomt.
struct MensTests {
    /// Speelt Zuid door telkens de eerstvolgende kaart aan te bieden. De
    /// speelloop wijst een ongeldige kaart af en vraagt gewoon opnieuw, dus na
    /// hooguit een paar pogingen ligt er een geldige.
    actor Automaat: KjUi {
        private(set) var zetten = 0
        private(set) var gevraagd = 0
        private(set) var spellen = 0
        private(set) var somFouten = 0
        private var beurt = 0

        private let maxSpellen: Int
        private var klaar: CheckedContinuation<Void, Never>?

        init(maxSpellen: Int) { self.maxSpellen = maxSpellen }

        func wachtTotKlaar() async {
            await withCheckedContinuation { c in
                if spellen >= maxSpellen { c.resume() } else { klaar = c }
            }
        }

        func toon(_ view: SpelView) async {
            zetten += 1
            beurt = 0
        }

        func kiesKaart(_ view: SpelView) async -> (naam: Teken, kleur: Int) {
            // Bij uitkomen mag het uit de hand of van tafel; anders alleen van
            // de stapel die aan de beurt is.
            var keuzes: [KaartView] = []
            if view.slag.isEmpty {
                keuzes = view.handZuid + view.tafelZuid
            } else if view.aanZet == Pos.tafelZuid {
                keuzes = view.tafelZuid
            } else {
                keuzes = view.handZuid
            }
            guard !keuzes.isEmpty else { return (naam: .nul, kleur: 0) }
            gevraagd += 1

            let kaart = keuzes[beurt % keuzes.count]
            beurt += 1
            return (naam: kaart.naam, kleur: kaart.kleur)
        }

        func kiesTroef(_ view: SpelView) async -> Int { view.slagNr % 4 }

        func verder(_ view: SpelView, _ tekst: String) async {
            guard view.spelUit else { return }
            // Aan het eind van een spel horen de kaartpunten op 152 uit te
            // komen. Deze test keek eerder of ze op nul stonden — dat was
            // precies de fout: evalueerSpel() zette de tellers leeg vóórdat de
            // momentopname werd gemaakt, zodat de speler de uitslag niet zag.
            if view.puntenZuid + view.puntenNoord != 152 { somFouten += 1 }
            spellen += 1
            if spellen >= maxSpellen, let c = klaar {
                klaar = nil
                c.resume()
            }
        }
    }

    @Test("De speelloop draait 60 spellen met een menselijke speler zonder vast te lopen")
    func mensSpeeltMee() async throws {
        let automaat = Automaat(maxSpellen: 60)
        let spel = KjSpel(ui: automaat, zaad: 99)

        let taak = Task.detached { await spel.loop() }
        await automaat.wachtTotKlaar()
        taak.cancel()

        let spellen = await automaat.spellen
        let zetten = await automaat.zetten
        let somFouten = await automaat.somFouten

        #expect(spellen >= 60)
        // 32 kaarten per spel, dus rond de 32 zetten per spel.
        #expect(zetten >= spellen * 32)
        #expect(somFouten == 0, "\(somFouten) spellen sloten af met een stand die niet klopt")

        // Zonder deze controle zou de test ook slagen als de computer stilletjes
        // beide kanten speelde en de mens nooit aan de beurt kwam.
        let gevraagd = await automaat.gevraagd
        #expect(gevraagd >= spellen * 8, "de mens werd maar \(gevraagd) keer om een kaart gevraagd")
    }
}
