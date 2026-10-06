import Testing
@testable import KlaverjasKit

/// Het samenspel-protocol: elke regel moet heen en terug precies hetzelfde
/// bericht opleveren, en een regel die niet aan de vorm voldoet moet `nil`
/// geven — nooit het dichtstbijzijnde geldige bericht raden.
struct DuoBerichtTests {
    @Test("Elke berichtsoort komt heen en terug hetzelfde uit")
    func alleBerichtsoorten() {
        let berichten: [DuoBericht] = [
            .begroeting(versie: 1, appversie: "2.0.0", naam: "Ednieuws iPhone"),
            .akkoord(versie: 1),
            .stand(json: "eW5pZXQtZWNodGUtaW5ob3Vk"),
            .zet(json: "b29rLW5pZXQtZWNodA"),
            .stat(json: "b29rLW5pZXQtZWNodA"),
            .pols,
        ]
        for bericht in berichten {
            #expect(DuoBericht(regel: bericht.regel) == bericht, "regel: \(bericht.regel)")
        }
    }

    @Test("De voorbeeldregels van het protocol worden herkend")
    func voorbeeldregels() {
        #expect(DuoBericht(regel: "KJ 1 2.0.0 iPhone")
                == .begroeting(versie: 1, appversie: "2.0.0", naam: "iPhone"))
        #expect(DuoBericht(regel: "JA 1") == .akkoord(versie: 1))
        #expect(DuoBericht(regel: "STAND abcd123") == .stand(json: "abcd123"))
        #expect(DuoBericht(regel: "ZET abcd123") == .zet(json: "abcd123"))
        #expect(DuoBericht(regel: "STAT abcd123") == .stat(json: "abcd123"))
        #expect(DuoBericht(regel: "P") == .pols)
    }

    /// Een `SpelView` gaat gecomprimeerd en base64 het net op (`DuoStand`);
    /// dat kan een `+`, `/` of `=` bevatten maar nooit een spatie — dus de
    /// regel blijft altijd in twee stukken te splitsen op het eerste spatie.
    @Test("Een STAND-regel met typische base64-tekens blijft heel")
    func standMetBase64Tekens() {
        let json = "QUJDKy8x/PT09"
        #expect(DuoBericht(regel: "STAND \(json)") == .stand(json: json))
    }

    @Test("Onherkenbare regels geven nil, niet het dichtstbijzijnde bericht",
          arguments: [
            "", "ONZIN", "KJ", "KJ 1", "STAND", "ZET", "STAT", "P 1",
          ])
    func onherkenbareRegels(_ regel: String) {
        #expect(DuoBericht(regel: regel) == nil, "\"\(regel)\" had geen bericht moeten opleveren")
    }
}

/// `GastZet` — de keuze van de gast, zoals hij in `DuoStand`-vorm over de
/// lijn gaat.
struct GastZetTests {
    @Test("Een troefkeuze codeert en decodeert naar dezelfde kleur")
    func troefKeuze() throws {
        let z = GastZet(troef: 2)
        let json = try DuoStand.codeer(z)
        let terug = try DuoStand.decodeer(json, als: GastZet.self)
        #expect(terug == z)
        #expect(terug.kaart == nil, "een troefkeuze draagt geen kaart mee")
    }

    @Test("Een kaartkeuze codeert en decodeert naar dezelfde kaart")
    func kaartKeuze() throws {
        let z = GastZet(kaart: Teken(raw: "T".utf8.first!), kleur: 3)
        let json = try DuoStand.codeer(z)
        let terug = try DuoStand.decodeer(json, als: GastZet.self)
        #expect(terug == z)
        #expect(terug.troef == nil, "een kaartkeuze draagt geen troef mee")
    }
}
