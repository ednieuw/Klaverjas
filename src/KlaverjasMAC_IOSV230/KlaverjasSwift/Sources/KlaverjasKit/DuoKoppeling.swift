/// Zit tussen `GastheerUi`/de gast-ontvanglus en de rauwe `DuoLijn` in: een
/// eigen luistertaak leest de lijn continu leeg, ook terwijl niemand op een
/// bericht wacht — een `STAND` of `ZET` kan op elk moment binnenkomen, niet
/// alleen wanneer `volgende()` toevallig aan het wachten is. Berichten die
/// niemand meteen ophaalt gaan in een wachtrij, in aankomstvolgorde.
///
/// **Geen "stuur nummer zoveel opnieuw" meer** (`R`/`stuurZet`, uit de eerste
/// opzet van dit protocol): elke `STAND` is een complete, zelfstandige
/// momentopname, dus een gemist of beschadigd bericht hoeft niet apart
/// teruggevraagd te worden — het volgende bericht haalt alles vanzelf in.
/// Dat maakt deze laag een stuk kleiner dan hij was.
public actor DuoKoppeling {
    private let lijn: DuoLijn
    private var wachtrij: [DuoBericht] = []
    private var wachters: [CheckedContinuation<DuoBericht, Never>] = []
    private var luistertaak: Task<Void, Never>?

    public init(lijn: DuoLijn) {
        self.lijn = lijn
    }

    /// Begint met luisteren. Apart van `init`, want de taak vangt zichzelf
    /// (`self`) en dat kan pas nadat de actor volledig bestaat.
    public func start() {
        guard luistertaak == nil else { return }
        luistertaak = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let bericht = await lijn.ontvang()
                if Task.isCancelled { return }
                await self.verwerkBinnenkomend(bericht)
            }
        }
    }

    public func stop() {
        luistertaak?.cancel()
        luistertaak = nil
        for wachter in wachters { wachter.resume(returning: .pols) }
        wachters.removeAll()
    }

    private func verwerkBinnenkomend(_ bericht: DuoBericht) async {
        if !wachters.isEmpty {
            let wachter = wachters.removeFirst()
            wachter.resume(returning: bericht)
        } else {
            wachtrij.append(bericht)
        }
    }

    public func stuur(_ bericht: DuoBericht) async {
        await lijn.stuur(bericht)
    }

    /// Wacht op het eerstvolgende bericht dat nog niet opgehaald is.
    public func volgende() async -> DuoBericht {
        if !wachtrij.isEmpty { return wachtrij.removeFirst() }
        return await withCheckedContinuation { c in wachters.append(c) }
    }
}
