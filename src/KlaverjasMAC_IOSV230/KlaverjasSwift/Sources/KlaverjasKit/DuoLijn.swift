/// Eén verbinding naar het andere toestel (B3 uit het bluetooth-plan).
///
/// Bewust een protocol: `DuoUi` (en alles daaromheen) praat alleen tegen
/// `DuoLijn`, nooit tegen bluetooth zelf. Dat maakt de hele samenspel-logica
/// te toetsen met `LusLijn`, een lus-in-het-geheugen, zonder één toestel nodig
/// te hebben — het belangrijkste ontwerpbesluit uit deze fase. Een latere
/// CoreBluetooth-implementatie (`KlaverjasBLE`) hoeft alleen dit protocol na
/// te komen.
public protocol DuoLijn: Sendable {
    /// Verstuurt één bericht. Komt pas terug als het bericht bij de andere
    /// kant in de wachtrij staat.
    func stuur(_ bericht: DuoBericht) async

    /// Wacht op het eerstvolgende bericht dat nog niet opgehaald is.
    func ontvang() async -> DuoBericht
}

/// Waar een verbinding op dit moment staat — voor het verbindingsscherm (B9:
/// "een duidelijke toestand als de lijn wegvalt"). `BlePerifeer`/`BleCentraal`
/// geven dit door via `statusStroom()`; `LusLijn` heeft dit niet nodig, want
/// een lus-in-het-geheugen valt nooit weg.
public enum DuoStatus: Sendable, Equatable {
    /// Onderweg, met een tekst voor op het scherm: "Adverteren…", "Zoeken…".
    case bezig(String)
    case verbonden
    /// De verbinding is er niet gekomen of weggevallen, met een reden voor op
    /// het scherm.
    case mislukt(String)
}

/// De gedeelde toestand achter één gekoppeld paar: twee postvakken, één voor
/// elke richting, en de ophalers die daarop wachten. Een actor, want
/// `stuur(_:)` (vanaf de ene kant) en `ontvang()` (vanaf de andere) raken
/// dezelfde toestand aan; actor-isolatie regelt dat zonder een eigen slot.
private actor LusHub {
    private var postvak: [[DuoBericht]] = [[], []]
    private var wachters: [[CheckedContinuation<DuoBericht, Never>]] = [[], []]

    func stuur(_ bericht: DuoBericht, naar kant: Int) {
        if !wachters[kant].isEmpty {
            let wachter = wachters[kant].removeFirst()
            wachter.resume(returning: bericht)
        } else {
            postvak[kant].append(bericht)
        }
    }

    func ontvang(bij kant: Int) async -> DuoBericht {
        if !postvak[kant].isEmpty { return postvak[kant].removeFirst() }
        return await withCheckedContinuation { c in wachters[kant].append(c) }
    }
}

/// Een lus-in-het-geheugen: wat de ene kant stuurt komt bij de andere binnen,
/// en omgekeerd. `paar()` maakt er twee die naar elkaar wijzen.
///
/// Een waarde-type dat naar een gedeelde `LusHub` wijst — niet zelf een actor
/// met een wederzijdse verwijzing naar zijn tegenhanger, want twee actors die
/// naar elkaar verwijzen moeten die koppeling na hun `init` leggen, en dat
/// geeft een kort gat waarin een vroege `stuur(_:)` in het niets verdwijnt.
/// Met één gedeelde hub bestaat dat gat niet: `paar()` levert twee al
/// volledig gekoppelde lussen op.
public struct LusLijn: DuoLijn {
    private let hub: LusHub
    private let eigenKant: Int
    private var andereKant: Int { 1 - eigenKant }

    private init(hub: LusHub, eigenKant: Int) {
        self.hub = hub
        self.eigenKant = eigenKant
    }

    /// Twee lussen die naar elkaar wijzen: wat de ene stuurt, ontvangt de
    /// andere, en omgekeerd.
    public static func paar() -> (LusLijn, LusLijn) {
        let hub = LusHub()
        return (LusLijn(hub: hub, eigenKant: 0), LusLijn(hub: hub, eigenKant: 1))
    }

    public func stuur(_ bericht: DuoBericht) async {
        await hub.stuur(bericht, naar: andereKant)
    }

    public func ontvang() async -> DuoBericht {
        await hub.ontvang(bij: eigenKant)
    }
}
