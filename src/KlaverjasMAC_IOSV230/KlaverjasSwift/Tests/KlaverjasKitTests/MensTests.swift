import Testing
@testable import KlaverjasKit

/// De speelloop met een menselijke speler erin. De C#-versie testte dit met
/// `KlaverjasTest mens 300`: een automaat speelt Zuid, en er wordt gekeken of
/// de lus niet vastloopt en of de punten blijven kloppen.
///
/// Dit is de enige test die de vraag-en-antwoordkant raakt: de speelloop stelt
/// een vraag, wacht, en gaat verder met wat er terugkomt.
struct MensTests {
    /// Speelt een kant door telkens de eerstvolgende kaart aan te bieden. De
    /// speelloop wijst een ongeldige kaart af en vraagt gewoon opnieuw, dus na
    /// hooguit een paar pogingen ligt er een geldige.
    ///
    /// `kant` is 1 (Zuid, de standaard — het origineel kende geen andere
    /// mens) of 2 (Noord, voor de kantneutraliteit uit A4/B4: met bluetooth
    /// speelt elke kant zijn eigen kant als mens).
    actor Automaat: KjUi {
        private(set) var zetten = 0
        private(set) var gevraagd = 0
        private(set) var spellen = 0
        private(set) var somFouten = 0
        private var beurt = 0

        private let maxSpellen: Int
        private let kant: Int
        private var klaar: CheckedContinuation<Void, Never>?

        init(maxSpellen: Int, kant: Int = 1) {
            self.maxSpellen = maxSpellen
            self.kant = kant
        }

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
            let eigenHand = kant == 2 ? view.handNoord : view.handZuid
            let eigenTafel = kant == 2 ? view.tafelNoord : view.tafelZuid
            let eigenTafelPos = kant == 2 ? Pos.tafelNoord : Pos.tafelZuid

            // Bij uitkomen mag het uit de hand of van tafel; anders alleen van
            // de stapel die aan de beurt is.
            var keuzes: [KaartView] = []
            if view.slag.isEmpty {
                keuzes = eigenHand + eigenTafel
            } else if view.aanZet == eigenTafelPos {
                keuzes = eigenTafel
            } else {
                keuzes = eigenHand
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

    /// Het origineel kende alleen Zuid als mens; `s.mens` (A4/B4) maakt dat
    /// kantneutraal. Zonder deze proef bewijst niets dat Noord er ook echt
    /// door komt — `SpoorTests` en `ZoekTests` draaien met `comp = true` en
    /// raken de vier `humaan()`-takken helemaal niet aan.
    ///
    /// Vraagt de speelloop per ongeluk toch Zuid, dan biedt deze automaat
    /// Noords kaarten aan op een Zuid-vraag. Dat is nooit geldig, dus wijst
    /// `checkValid()` het af en probeert `mensKiest()` het opnieuw, en
    /// `wachtTotKlaar()` — een kale `withCheckedContinuation` — komt zo nooit
    /// los. De race tegen een eigen `Task.sleep` hieronder ving dat bij het
    /// schrijven van deze proef niet op, ook niet nadat `mensKiest()` er een
    /// `Task.yield()` bij kreeg (zie daar): het proces bleef één kern
    /// muurvast draaien en de eigen `Task.sleep` kreeg domweg geen beurt meer.
    /// Dat is dus geen garantie tegen déze fout — maar in dat opzicht staat
    /// deze proef gelijk aan `mensSpeeltMee` hierboven, die op dezelfde
    /// `wachtTotKlaar()` leunt en diezelfde beperking altijd al had. De race
    /// is verbetering, geen garantie; ze vangt wel elke fout die af en toe een
    /// échte wachtstap teruggeeft.
    ///
    /// **Bewijs, niet giswerk:** met `mensIsAanZet(_:)` tijdelijk terug naar
    /// "alleen Zuid" liep het testproces vast op 100% CPU en kwam er na ruim
    /// een minuut nog niets terug — met de klok erbij gecontroleerd, niet aan
    /// de proef zelf overgelaten. Met de reparatie duurt dezelfde proef 0,65
    /// seconden.
    @Test("De speelloop draait ook met Noord als mens, niet alleen Zuid")
    func noordSpeeltMee() async throws {
        let automaat = Automaat(maxSpellen: 60, kant: 2)
        let spel = KjSpel(ui: automaat, zaad: 99)
        spel.e.s.mens = [false, true]

        let taak = Task.detached { await spel.loop() }
        defer { taak.cancel() }

        let klaarOpTijd = await withTaskGroup(of: Bool.self) { groep in
            groep.addTask { await automaat.wachtTotKlaar(); return true }
            groep.addTask {
                try? await Task.sleep(for: .seconds(20))
                return false
            }
            let eerste = await groep.next() ?? false
            groep.cancelAll()
            return eerste
        }
        guard klaarOpTijd else {
            Issue.record("de partij kwam niet op tijd klaar — Noord werd waarschijnlijk niet als mens gevraagd")
            return
        }

        let spellen = await automaat.spellen
        let zetten = await automaat.zetten
        let somFouten = await automaat.somFouten

        #expect(spellen >= 60)
        #expect(zetten >= spellen * 32)
        #expect(somFouten == 0, "\(somFouten) spellen sloten af met een stand die niet klopt")

        let gevraagd = await automaat.gevraagd
        #expect(gevraagd >= spellen * 8, "Noord werd maar \(gevraagd) keer om een kaart gevraagd")
    }
}
