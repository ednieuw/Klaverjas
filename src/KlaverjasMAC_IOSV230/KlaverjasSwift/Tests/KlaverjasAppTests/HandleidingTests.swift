import Testing
@testable import KlaverjasApp
@testable import KlaverjasKit

/// De handleiding staat los van `Taal`, dus de gebruikelijke bewaking dat elke
/// tekst in beide talen bestaat pakt hem niet. Vandaar hier.
struct HandleidingTests {
    @Test("De handleiding bestaat in beide talen, met dezelfde onderdelen")
    func beideTalen() {
        let nl = Handleiding.stukken(engels: false)
        let en = Handleiding.stukken(engels: true)

        #expect(nl.count == en.count, "\(nl.count) stukken in het Nederlands, \(en.count) in het Engels")
        #expect(nl.count >= 6, "een handleiding van \(nl.count) stukken is wel erg mager")

        for (n, e) in zip(nl, en) {
            #expect(!n.kop.isEmpty && !e.kop.isEmpty)
            #expect(!n.tekst.isEmpty && !e.tekst.isEmpty)
            // Een vergeten vertaling levert twee keer dezelfde tekst op.
            #expect(n.tekst != e.tekst, "\"\(n.kop)\" is in beide talen gelijk")
            #expect(n.kop != e.kop, "de kop \"\(n.kop)\" is niet vertaald")
        }
    }

    @Test("De Engelse handleiding legt uit wat een march is")
    func legtMarchUit() {
        // "march" staat in de uitslagmelding en in het statistiekenscherm. Het
        // is geen woord dat vanzelf spreekt, dus het moet uitgelegd blijven.
        let alles = Handleiding.stukken(engels: true).map { $0.kop + " " + $0.tekst }
            .joined(separator: " ").lowercased()
        #expect(alles.contains("march"), "de term march wordt nergens genoemd")
        #expect(alles.contains("all eight tricks"),
                "er staat nergens wát een march is")
    }

    @Test("De handleiding noemt de regels die de motor werkelijk afdwingt")
    func noemtDeEchteRegels() {
        let alles = Handleiding.stukken(engels: false).map(\.tekst).joined(separator: " ")

        // Deze getallen komen uit de motor; staat er iets anders in de uitleg,
        // dan klopt de handleiding niet meer met het spel.
        for getal in ["1500", "152", "20", "50", "100", "200", "10"] {
            #expect(alles.contains(getal), "het getal \(getal) ontbreekt in de uitleg")
        }
        // De uitzondering op het moeten troeven zit echt in checkValid; die mag
        // niet uit de uitleg verdwijnen, want dan klopt hij niet.
        #expect(alles.lowercased().contains("uitzondering"),
                "de uitzondering op het troeven wordt niet genoemd")
    }
}
