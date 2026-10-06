/// De tellingen die het origineel bij het afsluiten op het scherm zette
/// (KJ.C, aan het eind van main()): "Gewonnen / Kaartpnt / Troefpnt / Troefkrt /
/// Roempnt / Pit / Tegenpit / Nat" in twee kolommen, met de superroem eronder,
/// en bij COMP ook de teller per tactiek.
///
/// In het origineel zag je dit pas als je stopte met spelen. Hier kan het
/// tijdens het spel bekeken worden; de getallen zelf zijn dezelfde.
/// `Codable`, zodat de tellingen een herstart overleven: het origineel gooide ze
/// bij het afsluiten weg, maar op een telefoon sluit je het spel voortdurend.
public struct Statistiek: Sendable, Codable, Equatable {
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
    public var superroem: [Int64] = [0, 0]     // vier gelijke kaarten
    public var totaal: [Int64] = [0, 0]        // PuntenTotaalSpel[]: stand van de partij

    /// Hoe vaak elke tactiek is toegepast, 0..79. De nummers zijn die uit het
    /// origineel (TACTIEK=7, 41, 68, ...), zodat je in de code kunt terugzoeken
    /// welke regel de computer volgde.
    public var tactiek: [Int64] = Array(repeating: 0, count: 80)

    public init() {}

    /// Met de hand geschreven, om twee redenen. Een bewaard bestand van een
    /// oudere versie heeft `superroem` als één getal in plaats van als twee, en
    /// dat moet gewoon blijven werken. En elk veld heeft een standaardwaarde,
    /// zodat een bestand waarin later een veld bijkomt of wegvalt niet in zijn
    /// geheel onleesbaar wordt — dan zou de speler zijn hele telling kwijt zijn.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func paar(_ sleutel: CodingKeys) -> [Int64] {
            (try? c.decode([Int64].self, forKey: sleutel)) ?? [0, 0]
        }
        partijen = paar(.partijen)
        spellen = paar(.spellen)
        kaartpunten = paar(.kaartpunten)
        troefpunten = paar(.troefpunten)
        troefkaarten = paar(.troefkaarten)
        roempunten = paar(.roempunten)
        pit = paar(.pit)
        tegenpit = paar(.tegenpit)
        nat = paar(.nat)
        totaal = paar(.totaal)
        tactiek = (try? c.decode([Int64].self, forKey: .tactiek)) ?? []
        if tactiek.count < 80 { tactiek += Array(repeating: 0, count: 80 - tactiek.count) }

        if let lijst = try? c.decode([Int64].self, forKey: .superroem) {
            superroem = lijst.count >= 2 ? lijst : [lijst.first ?? 0, 0]
        } else if let enkel = try? c.decode(Int64.self, forKey: .superroem) {
            // Uit een versie die de superroem nog niet per kant bijhield.
            superroem = [enkel, 0]
        } else {
            superroem = [0, 0]
        }
    }

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

    /// Wisselt [0] en [1] om op elk per-kant veld — voor wanneer een eerder
    /// bewaarde meting in de tafelpositie (Zuid/Noord) van een andere sessie
    /// staat dan de huidige. Bij samenspel is de gastheer altijd Zuid en de
    /// gast altijd Noord, maar welk *fysiek* apparaat gastheer is wisselt per
    /// sessie — dus wat "Zuid" betekent voor een bewaarde meting hangt af van
    /// wie er tóén hostte, niet van wie dat nu doet.
    ///
    /// `tactiek` hoort hier bewust niet bij: dat is geen Zuid/Noord-paar maar
    /// één gedeelde teller van 80 AI-tactieken (zie `KjState.statistiek`/
    /// `zetStatistiek`, die `tac`/`tactiek` los van Zuid/Noord doorzet).
    public var kantenOmgewisseld: Statistiek {
        var st = self
        st.partijen.swapAt(0, 1)
        st.spellen.swapAt(0, 1)
        st.kaartpunten.swapAt(0, 1)
        st.troefpunten.swapAt(0, 1)
        st.troefkaarten.swapAt(0, 1)
        st.roempunten.swapAt(0, 1)
        st.pit.swapAt(0, 1)
        st.tegenpit.swapAt(0, 1)
        st.nat.swapAt(0, 1)
        st.superroem.swapAt(0, 1)
        st.totaal.swapAt(0, 1)
        return st
    }
}

/// Kiest, van twee tellingen die al in hetzelfde kant-stelsel staan (dus
/// allebei al `[0]` = ikzelf, `[1]` = de partner — zie `kantenOmgewisseld`),
/// de "verste" — Ed, over het samen-spelen-met-dezelfde-partner-probleem:
/// "onthoudt de hoogste score van de twee en ga daar mee verder."
public enum StatistiekVerzoening {
    /// Nooit in de eerste plaats `totaal`: dat veld valt terug naar `[0,0]`
    /// zodra een partij de 1500 haalt (`KjEngine`) — vlak ná een gewonnen
    /// partij zou de verder gevorderde kant anders juist "achter" lijken.
    /// `spellen` en `partijen` lopen nooit terug, dus die wegen het zwaarst;
    /// `totaal` breekt alleen nog een gelijkspel daarna verder open.
    private static func grootte(_ st: Statistiek) -> (Int64, Int64, Int64) {
        (st.spellen[0] + st.spellen[1],
         st.partijen[0] + st.partijen[1],
         st.totaal[0] + st.totaal[1])
    }

    public static func hoogste(_ a: Statistiek, _ b: Statistiek) -> Statistiek {
        grootte(a) >= grootte(b) ? a : b
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

    /// Zet bewaarde tellingen terug. Alleen aan te roepen voordat de speelloop
    /// begint; daarna is de motor van zijn eigen taak.
    public func zetStatistiek(_ st: Statistiek) {
        gewonnen = [Int(st.partijen[0]), Int(st.partijen[1])]
        gewonnenTot = st.spellen
        kaartpnt = st.kaartpunten
        troefpnt = st.troefpunten
        troefkrt = st.troefkaarten
        roempnt = st.roempunten
        pit = st.pit
        tpit = st.tegenpit
        nat = st.nat
        superroem = st.superroem.count >= 2 ? st.superroem : [0, 0]
        puntenTotaalSpel = st.totaal
        // Een bewaard bestand van een oudere versie kan een kortere lijst
        // hebben; die vult zichzelf dan aan met nullen.
        for i in 0..<min(tac.count, st.tactiek.count) { tac[i] = st.tactiek[i] }
    }
}
