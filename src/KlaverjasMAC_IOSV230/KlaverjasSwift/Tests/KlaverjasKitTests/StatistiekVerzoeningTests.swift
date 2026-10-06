import Testing
@testable import KlaverjasKit

/// `Statistiek.kantenOmgewisseld` en `StatistiekVerzoening.hoogste` — de twee
/// bouwstenen waarmee twee apparaten hun bewaarde score voor elkaar
/// verzoenen bij het verbinden, ongeacht wie er dit keer gastheer is.
struct StatistiekVerzoeningTests {
    private func gevuld() -> Statistiek {
        var st = Statistiek()
        st.partijen = [2, 1]
        st.spellen = [37, 41]
        st.kaartpunten = [3120, 2980]
        st.troefpunten = [800, 760]
        st.troefkaarten = [150, 148]
        st.roempunten = [420, 380]
        st.pit = [3, 1]
        st.tegenpit = [1, 0]
        st.nat = [5, 7]
        st.superroem = [2, 1]
        st.totaal = [1240, 990]
        st.tactiek[7] = 61
        st.tactiek[70] = 204
        return st
    }

    @Test("kantenOmgewisseld wisselt alle tien per-kant velden om")
    func wisseltPerKantVeldenOm() {
        let st = gevuld()
        let w = st.kantenOmgewisseld

        #expect(w.partijen == [1, 2])
        #expect(w.spellen == [41, 37])
        #expect(w.kaartpunten == [2980, 3120])
        #expect(w.troefpunten == [760, 800])
        #expect(w.troefkaarten == [148, 150])
        #expect(w.roempunten == [380, 420])
        #expect(w.pit == [1, 3])
        #expect(w.tegenpit == [0, 1])
        #expect(w.nat == [7, 5])
        #expect(w.superroem == [1, 2])
        #expect(w.totaal == [990, 1240])
    }

    @Test("kantenOmgewisseld laat de tactieklijst met rust")
    func laatTactiekMetRust() {
        let st = gevuld()
        #expect(st.kantenOmgewisseld.tactiek == st.tactiek,
                "tactiek is geen Zuid/Noord-paar en hoort niet om te wisselen")
    }

    @Test("Wisselen twee keer geeft de oorspronkelijke telling terug")
    func dubbelWisselenIsIdentiteit() {
        let st = gevuld()
        #expect(st.kantenOmgewisseld.kantenOmgewisseld == st)
    }

    @Test("hoogste kiest de kant met meer gespeelde spellen")
    func kiestMeerSpellen() {
        var a = Statistiek(); a.spellen = [10, 4]
        var b = Statistiek(); b.spellen = [3, 3]
        #expect(StatistiekVerzoening.hoogste(a, b) == a)
        #expect(StatistiekVerzoening.hoogste(b, a) == a)
    }

    @Test("Bij gelijke spellen beslist het aantal gewonnen partijen")
    func kiestMeerPartijenBijGelijkeSpellen() {
        var a = Statistiek(); a.spellen = [10, 4]; a.partijen = [1, 0]
        var b = Statistiek(); b.spellen = [8, 6]; b.partijen = [2, 0]
        #expect(StatistiekVerzoening.hoogste(a, b) == b)
    }

    @Test("Een net-op-nul-gevallen totaal na een gewonnen partij verliest niet van minder spellen")
    func totaalWordtNooitAlsEersteGebruikt() {
        // a won net een partij: totaal terug naar nul, maar heeft duidelijk
        // meer gespeeld en meer partijen binnen dan b.
        var a = Statistiek(); a.spellen = [20, 15]; a.partijen = [3, 1]; a.totaal = [0, 0]
        var b = Statistiek(); b.spellen = [5, 4]; b.partijen = [0, 0]; b.totaal = [900, 700]
        #expect(StatistiekVerzoening.hoogste(a, b) == a,
                "een lager totaal mag niet laten lijken dat a achterloopt vlak na een gewonnen partij")
    }
}
