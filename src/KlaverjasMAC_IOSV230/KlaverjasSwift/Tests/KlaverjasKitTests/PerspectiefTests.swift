import Testing
@testable import KlaverjasKit

/// `SpelView.mijnKant` (B5 uit het bluetooth-plan): de kaarten en de
/// beurtdetectie vanuit het perspectief van de kant die op dit toestel speelt,
/// zonder dat de onderliggende velden (`handZuid`, `puntenNoord`, …) ooit
/// spiegelen — die blijven absoluut, want `Spoor`, het statistiekenscherm en
/// `SpelUitslag` lezen ze allemaal.
struct PerspectiefTests {
    /// Een kaart met een herkenbare naam, om te zien welke er precies
    /// doorkomt — niet alleen hoeveel.
    private func kaart(_ naam: Character) -> KaartView {
        var k = KaartView()
        k.naam = Teken(raw: naam.asciiValue!)
        return k
    }

    @Test("Standaard (mijnKant = 1) is Zuid nog steeds ik, precies als voorheen")
    func standaardIsZuid() {
        var v = SpelView()
        v.handZuid = [kaart("A")]
        v.handNoord = [kaart("H")]
        v.tafelZuid = [kaart("V")]
        v.tafelNoord = [kaart("B")]
        v.dichtZuid = [kaart("T")]
        v.dichtNoord = [kaart("9")]
        v.onderZuid = [true, false, false, false]
        v.onderNoord = [false, true, false, false]

        #expect(v.mijnKant == 1, "de standaardwaarde moet 1 blijven, anders verandert bestaand gedrag")
        #expect(v.mijnHand.map(\.naam) == v.handZuid.map(\.naam))
        #expect(v.zijnHand.map(\.naam) == v.handNoord.map(\.naam))
        #expect(v.mijnTafel.map(\.naam) == v.tafelZuid.map(\.naam))
        #expect(v.zijnTafel.map(\.naam) == v.tafelNoord.map(\.naam))
        #expect(v.mijnDicht.map(\.naam) == v.dichtZuid.map(\.naam))
        #expect(v.zijnDicht.map(\.naam) == v.dichtNoord.map(\.naam))
        #expect(v.mijnOnder == v.onderZuid)
        #expect(v.zijnOnder == v.onderNoord)
        #expect(v.mijnHandPos == Pos.handZuid)
        #expect(v.mijnTafelPos == Pos.tafelZuid)
    }

    @Test("Met mijnKant = 2 wisselen mijn en zijn kaarten om, de velden zelf niet")
    func noordAlsIk() {
        var v = SpelView()
        v.mijnKant = 2
        v.handZuid = [kaart("A")]
        v.handNoord = [kaart("H")]
        v.tafelZuid = [kaart("V")]
        v.tafelNoord = [kaart("B")]

        // De vertaling: mijn kaarten zijn nu Noords.
        #expect(v.mijnHand.map(\.naam) == v.handNoord.map(\.naam))
        #expect(v.zijnHand.map(\.naam) == v.handZuid.map(\.naam))
        #expect(v.mijnTafel.map(\.naam) == v.tafelNoord.map(\.naam))
        #expect(v.zijnTafel.map(\.naam) == v.tafelZuid.map(\.naam))
        #expect(v.mijnHandPos == Pos.handNoord)
        #expect(v.mijnTafelPos == Pos.tafelNoord)

        // De onderliggende velden zelf zijn onaangeroerd: dit moet nog
        // steeds "Zuids aas" en "Noords heer" zijn, niet omgewisseld.
        #expect(v.handZuid.map(\.naam) == [kaart("A")].map(\.naam))
        #expect(v.handNoord.map(\.naam) == [kaart("H")].map(\.naam))
    }

    @Test("benIkAanZet volgt mijn kant, niet Zuid")
    func benIkAanZet() {
        var v = SpelView()
        v.mijnKant = 2

        v.aanZet = Pos.handNoord
        #expect(v.benIkAanZet, "Noords hand is aan zet en ik ben Noord")

        v.aanZet = Pos.tafelNoord
        #expect(v.benIkAanZet, "Noords tafel is aan zet en ik ben Noord")

        v.aanZet = Pos.handZuid
        #expect(!v.benIkAanZet, "Zuid is aan zet, niet ik")

        v.aanZet = Pos.tafelZuid
        #expect(!v.benIkAanZet, "Zuid is aan zet, niet ik")
    }

    @Test("Met mijnKant = 1 blijft benIkAanZet exact het oude Zuid-gedrag")
    func benIkAanZetStandaard() {
        var v = SpelView()

        v.aanZet = Pos.handZuid
        #expect(v.benIkAanZet)

        v.aanZet = Pos.handNoord
        #expect(!v.benIkAanZet)
    }

    /// De puntentelling die het scherm toont: Ed na de eerste hardwarepartij,
    /// "de speler op een scherm is altijd zuid". Zelfde principe als hierboven
    /// voor de kaarten, nu voor de standTabel/troefregel.
    @Test("Met mijnKant = 1 zijn mijn/zijn stand nog gewoon Zuid/Noord")
    func standRelatiefStandaard() {
        var v = SpelView()
        v.puntenZuid = 40; v.puntenNoord = 60
        v.roemZuid = 20; v.roemNoord = 0
        v.totaalZuid = 700; v.totaalNoord = 300
        v.partijenZuid = 2; v.partijenNoord = 1
        v.troefmaker = 1

        #expect(v.mijnPunten == 40 && v.zijnPunten == 60)
        #expect(v.mijnRoem == 20 && v.zijnRoem == 0)
        #expect(v.mijnTotaal == 700 && v.zijnTotaal == 300)
        #expect(v.mijnPartijen == 2 && v.zijnPartijen == 1)
        #expect(v.troefmakerRelatief == 1, "ik maakte troef")
    }

    @Test("Met mijnKant = 2 wisselen mijn/zijn stand om, de absolute velden niet")
    func standRelatiefAlsNoord() {
        var v = SpelView()
        v.mijnKant = 2
        v.puntenZuid = 40; v.puntenNoord = 60
        v.roemZuid = 20; v.roemNoord = 0
        v.totaalZuid = 700; v.totaalNoord = 300
        v.partijenZuid = 2; v.partijenNoord = 1
        v.troefmaker = 1

        #expect(v.mijnPunten == 60 && v.zijnPunten == 40)
        #expect(v.mijnRoem == 0 && v.zijnRoem == 20)
        #expect(v.mijnTotaal == 300 && v.zijnTotaal == 700)
        #expect(v.mijnPartijen == 1 && v.zijnPartijen == 2)
        #expect(v.troefmakerRelatief == 2, "Zuid maakte troef, en dat is niet ik")

        // De absolute velden zelf onaangeroerd — Spoor/StatistiekScherm lezen
        // die nog steeds letterlijk.
        #expect(v.puntenZuid == 40 && v.puntenNoord == 60)
    }

    @Test("troefmakerRelatief is 0 zolang er nog geen troef gekozen is")
    func troefmakerNogOnbekend() {
        var v = SpelView()
        v.mijnKant = 2
        v.troefmaker = 0
        #expect(v.troefmakerRelatief == 0)
    }

    /// De kaarten die middenin het veld liggen tijdens een slag
    /// (`SlagView.speler`, absoluut) moeten in hetzelfde vak vallen als
    /// `mijnHand`/`mijnTafel` — anders komt een eigen kaart in het vak van de
    /// tegenstander terecht. Ed's melding: "when south play his cards they
    /// placed on the north side in the opponent window."
    @Test("relatieveSpeler is de identiteit met mijnKant = 1")
    func relatieveSpelerStandaard() {
        let v = SpelView()
        #expect(v.relatieveSpeler(Pos.handZuid) == Pos.handZuid)
        #expect(v.relatieveSpeler(Pos.handNoord) == Pos.handNoord)
        #expect(v.relatieveSpeler(Pos.tafelZuid) == Pos.tafelZuid)
        #expect(v.relatieveSpeler(Pos.tafelNoord) == Pos.tafelNoord)
    }

    @Test("relatieveSpeler wisselt Zuid en Noord om met mijnKant = 2")
    func relatieveSpelerAlsNoord() {
        var v = SpelView()
        v.mijnKant = 2
        #expect(v.relatieveSpeler(Pos.handNoord) == Pos.handZuid,
                "mijn eigen (Noords) hand moet in mijn eigen vak vallen")
        #expect(v.relatieveSpeler(Pos.handZuid) == Pos.handNoord,
                "de hand van de tegenstander moet in zijn vak vallen")
        #expect(v.relatieveSpeler(Pos.tafelNoord) == Pos.tafelZuid)
        #expect(v.relatieveSpeler(Pos.tafelZuid) == Pos.tafelNoord)
    }
}
