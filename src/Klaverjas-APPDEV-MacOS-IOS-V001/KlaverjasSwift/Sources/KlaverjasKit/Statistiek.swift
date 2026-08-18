/// De tellingen die het origineel bij het afsluiten op het scherm zette
/// (KJ.C, aan het eind van main()): "Gewonnen / Kaartpnt / Troefpnt / Troefkrt /
/// Roempnt / Pit / Tegenpit / Nat" in twee kolommen, met de superroem eronder,
/// en bij COMP ook de teller per tactiek.
///
/// In het origineel zag je dit pas als je stopte met spelen. Hier kan het
/// tijdens het spel bekeken worden; de getallen zelf zijn dezelfde.
public struct Statistiek: Sendable {
    /// [0] = Zuid, [1] = Noord — dezelfde volgorde als in de engine.
    public var partijen: [Int64] = [0, 0]      // Gewonnen[]: partijen tot 1500
    public var spellen: [Int64] = [0, 0]       // GewonnenTot[]: losse spellen
    public var kaartpunten: [Int64] = [0, 0]   // Kaartpnt[]
    public var troefpunten: [Int64] = [0, 0]   // Troefpnt[]
    public var troefkaarten: [Int64] = [0, 0]  // Troefkrt[]
    public var roempunten: [Int64] = [0, 0]    // Roempnt[]
    public var pit: [Int64] = [0, 0]           // Pit[]
    public var tegenpit: [Int64] = [0, 0]      // Tpit[]
    public var nat: [Int64] = [0, 0]           // Nat[]
    public var superroem: Int64 = 0            // vier gelijke kaarten
    public var totaal: [Int64] = [0, 0]        // PuntenTotaalSpel[]: stand van de partij

    /// Hoe vaak elke tactiek is toegepast, 0..79. De nummers zijn die uit het
    /// origineel (TACTIEK=7, 41, 68, ...), zodat je in de code kunt terugzoeken
    /// welke regel de computer volgde.
    public var tactiek: [Int64] = Array(repeating: 0, count: 80)

    public init() {}

    /// De tactieken die daadwerkelijk gebruikt zijn, aflopend op aantal.
    public var gebruikteTactieken: [(nummer: Int, aantal: Int64)] {
        tactiek.enumerated()
            .filter { $0.offset > 0 && $0.element > 0 }
            .map { (nummer: $0.offset, aantal: $0.element) }
            .sorted { $0.aantal > $1.aantal }
    }

    /// Is er al iets te zien?
    public var leeg: Bool {
        spellen[0] + spellen[1] == 0
    }
}

extension KjState {
    /// Een momentopname van de tellers, veilig mee te geven aan het scherm.
    public var statistiek: Statistiek {
        var st = Statistiek()
        st.partijen = [Int64(gewonnen[0]), Int64(gewonnen[1])]
        st.spellen = gewonnenTot
        st.kaartpunten = kaartpnt
        st.troefpunten = troefpnt
        st.troefkaarten = troefkrt
        st.roempunten = roempnt
        st.pit = pit
        st.tegenpit = tpit
        st.nat = nat
        st.superroem = superroem
        st.totaal = puntenTotaalSpel
        st.tactiek = tac
        return st
    }
}
