import Testing
@testable import KlaverjasKit

/// Alles wat met de taalschakelaar te maken heeft, in één suite en bewust
/// `.serialized`.
///
/// `Taal.engels` is één schakelaar voor het hele programma. Swift Testing
/// draait tests standaard naast elkaar, en dan zet de ene test de taal om
/// terwijl de andere hem uitleest. Door ze samen in één seriële suite te zetten
/// kan dat niet gebeuren.
@Suite(.serialized)
struct TaalTests {
    /// De nummers die de engine daadwerkelijk toekent; 44 en 61 bestaan niet.
    static let gebruikteTactieken: [Int] = Array(1...43) + [45] + Array(46...60) + Array(62...69)

    // ------------------------------------------------------ standaardtaal

    @Test("Nederlands bovenaan geeft Nederlands, al de rest geeft Engels",
          arguments: [
            (["nl"], false),
            (["nl-NL"], false),
            (["nl-BE"], false),
            (["NL-nl"], false),
            (["en-US"], true),
            (["de-DE", "nl-NL"], true),   // alleen de eerste voorkeur telt
            (["fr"], true),
            ([], true),
          ])
    func standaardtaal(voorkeur: [String], verwachtEngels: Bool) {
        // engelsVoor() raakt de schakelaar niet aan, dus dit kan altijd.
        #expect(Taal.engelsVoor(voorkeur) == verwachtEngels)
    }

    // ---------------------------------------------------------- teksten

    @Test("Omschakelen raakt zowel het scherm als de speellogica")
    func omschakelen() {
        let oud = Taal.engels
        defer { Taal.engels = oud }

        Taal.engels = false
        #expect(Taal.kleurNaam(0) == "Klaver")
        #expect(Taal.wintDitSpel(true).hasPrefix("Zuid"))

        Taal.engels = true
        #expect(Taal.kleurNaam(0) == "Clubs")
        #expect(Taal.wintDitSpel(true).hasPrefix("South"))
    }

    // ------------------------------------------------------ tactieknamen

    @Test("Elk gebruikt tactieknummer heeft een naam in beide talen")
    func alleTactiekenHebbenEenNaam() {
        let oud = Taal.engels
        defer { Taal.engels = oud }

        Taal.engels = false
        for nr in Self.gebruikteTactieken {
            #expect(Taal.tactiekNaam(nr) != "onbekend", "tactiek \(nr) heeft geen Nederlandse naam")
        }

        Taal.engels = true
        for nr in Self.gebruikteTactieken {
            #expect(Taal.tactiekNaam(nr) != "unknown", "tactiek \(nr) heeft geen Engelse naam")
        }
    }

    @Test("De nummers 44 en 61 bestaan niet en melden zich als onbekend")
    func gatenInDeReeks() {
        let oud = Taal.engels
        defer { Taal.engels = oud }

        Taal.engels = false
        #expect(Taal.tactiekNaam(44) == "onbekend")
        #expect(Taal.tactiekNaam(61) == "onbekend")
    }

    @Test("De tactieknamen passen op één regel in het statistiekenscherm")
    func namenZijnKort() {
        let oud = Taal.engels
        defer { Taal.engels = oud }

        for taal in [false, true] {
            Taal.engels = taal
            for nr in Self.gebruikteTactieken {
                let naam = Taal.tactiekNaam(nr)
                #expect(naam.count <= 44, "tactiek \(nr) is te lang: \(naam)")
            }
        }
    }
}
