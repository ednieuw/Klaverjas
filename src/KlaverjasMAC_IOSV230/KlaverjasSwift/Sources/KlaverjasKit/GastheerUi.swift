/// De `KjUi` die de gastheer (de opensteller) gebruikt zodra er samen
/// gespeeld wordt: de gastheer draait de enige echte `KjSpel`, deze schil zit
/// ertussen om na elke wijziging de hele momentopname naar de gast te sturen,
/// en — als de gast aan zet is — zijn keuze terug te lezen in plaats van het
/// lokale scherm te vragen.
///
/// **Waarom niet allebei een eigen motor (zoals de eerste opzet, "gelijkloop"
/// met een controlesom per zet):** dat werkte, maar liet elke kant zijn eigen
/// partij bijhouden en zelf beslissen wanneer een slag verder ging — daardoor
/// leek het net twee losse partijen naast elkaar, niet één samen gespeelde.
/// Met één motor bij de gastheer bestaat dat onderscheid niet meer: de gast
/// is puur scherm en invoer, en wat hij ziet is altíjd precies wat de
/// gastheer net heeft laten zien, van zijn kant bekeken.
///
/// **Wat er in elke `STAND` gaat:** niet de momentopname die de gastheer zelf
/// gebruikt (`view`, met zíjn hand open en de tegenpartij dicht) maar een
/// tweede, apart berekende momentopname vanaf de kant van de gast
/// (`spel.snapshot(voor: gastKant)`) — anders zou de gast de kaarten van de
/// gastheer op zijn scherm krijgen. Zie de aantekening bij `KjSpel.snapshot`.
public actor GastheerUi: KjUi {
    private let scherm: KjUi
    private let koppeling: DuoKoppeling
    private let mijnKant: Int
    private let gastKant: Int

    /// Pas gezet zodra `KjSpel` bestaat — de kip-en-ei van `SpelModel`
    /// `startDuoAlsGastheer`: `KjSpel.init(ui:)` heeft deze schil al nodig
    /// vóórdat `KjSpel` zelf bestaat.
    private weak var spel: KjSpel?

    /// Voor het bewaren van een onderbroken partij (zie `Bewaarplaats`): elke
    /// troefkeuze en gespeelde kaart, ongeacht van welke kant, in de volgorde
    /// waarin ze vielen. `SpelModel` schrijft dit weg; deze schil hoeft zelf
    /// niets van bewaren te weten.
    private let opNieuweDeal: (@Sendable () -> Void)?
    private let opNieuweZet: (@Sendable (GastZet) -> Void)?

    /// Vraagt de lokale kant (`SpelModel`) of hij nu écht op een eigen tik
    /// wacht om verder te gaan. Bij snel spelen of automatisch doorgaan doet
    /// hij dat niet (`SpelModel.vraagVerder` slaat de wachttijd dan over) —
    /// en dan moet de gast ook niet ineens een tikvraag krijgen: dat zou
    /// `demoLaatComputerBeideKantenSpelen` breken, waar geen van beide
    /// schermen ooit om een tik mag vragen zolang de computer beide kanten
    /// automatisch speelt.
    private let wachtLokaalOpTik: (@Sendable () async -> Bool)?

    /// Lost de lokale "verder"-wachttijd programmatisch op, alsof de
    /// gastheer zelf getikt had — aangeroepen zodra de gast zijn eigen tik
    /// stuurt. Roept in de praktijk `SpelModel.gaVerder()` aan, die zelf al
    /// bewaakt of er nog iets op te lossen valt (dus veilig meermaals of te
    /// laat aan te roepen).
    private let gaVerderExtern: (@Sendable () async -> Void)?

    /// `KlaverjasKit` mag niets van `KlaverjasBLE` weten (die hangt er juist
    /// van af, niet andersom) — dus geen `BleLog` hier rechtstreeks. Deze
    /// haak laat `SpelModel` (die `KlaverjasBLE` wél kent) meeluisteren, voor
    /// precies het stuk dat tot nu toe onzichtbaar was: of `stuurStand()`
    /// eigenlijk wel ooit iets probeert te versturen.
    private let log: (@Sendable (String) -> Void)?

    /// Eén vaste, actor-eigen "postbus" per soort antwoord dat van de gast
    /// kan komen — troef, kaart, of "ik ga verder". Precies één lezer
    /// (`startOntvangen()`) haalt alles van `koppeling` en zet het in de
    /// juiste postbus; `wachtOpGastTroef`/`wachtOpGastKaart`/
    /// `wachtOpGastVerder` wachten allemaal op hun eigen postbus, nooit
    /// rechtstreeks op `koppeling.volgende()`.
    ///
    /// **Waarom dit nodig is, en niet zomaar elk twee losse `koppeling.
    /// volgende()`-lussen naast elkaar** (zoals `kiesTroef`/`kiesKaart` dat
    /// tot de komst van de "verder"-tik wél deden): twee gelijktijdige
    /// lezers van dezelfde `koppeling` verdelen binnenkomende berichten op
    /// volgorde van aanmelding, niet op wat voor bericht het is. Een
    /// "verder"-lezer die per ongeluk blijft hangen (zie `stop()`) zou dan
    /// zomaar de eerstvolgende échte kaart- of troefkeuze van de gast kunnen
    /// inpikken, hem stilzwijgend weggooien (hij past niet bij `.verder`),
    /// en de gast lijkt dan simpelweg niets gedaan te hebben.
    private var troefAntwoord: CheckedContinuation<Int, Never>?
    private var kaartAntwoord: CheckedContinuation<(naam: Teken, kleur: Int), Never>?
    private var verderAntwoord: CheckedContinuation<Void, Never>?
    private var ontvangTaak: Task<Void, Never>?

    /// Vangt een antwoord op dat al binnenkwam vóórdat de bijbehorende
    /// `wachtOpGast*`-functie ook maar begon te wachten — precies zoals
    /// `DuoKoppeling.wachtrij` dat voor rauwe berichten al doet.
    ///
    /// **Waarom dit nodig bleek:** `stuurStand(zoals:)` stuurt de stand pas
    /// nadat de aanroepende functie besloten heeft er (eventueel) op te
    /// wachten — en `groep.addTask { await self.wachtOpGastVerder() }`
    /// garandeert niet dat die taak al draait vóórdat de daaropvolgende
    /// `await self.stuurStand(...)` de gast bereikt. Onder zware
    /// gelijktijdige belasting (de volledige testrun van 29 suites samen)
    /// bleek dat gat groot genoeg: een supersnel "verder"-tikje van de gast
    /// kwam soms al aan vóórdat `verderAntwoord` gezet was, werd dan
    /// stilzwijgend weggegooid (`verwerkGastBericht` vond geen wachtende
    /// postbus), en de partij liep muurvast — geen van beide kanten wist nog
    /// dat er iets te doen viel. Met deze buffer maakt de volgorde niet meer
    /// uit: te vroeg binnengekomen antwoorden liggen klaar voor de eerste
    /// `wachtOpGast*`-aanroep die er om vraagt.
    private var vroegTroef: Int?
    private var vroegKaart: (naam: Teken, kleur: Int)?
    private var vroegVerder = false

    public init(scherm: KjUi, koppeling: DuoKoppeling, mijnKant: Int = 1,
                opNieuweDeal: (@Sendable () -> Void)? = nil,
                opNieuweZet: (@Sendable (GastZet) -> Void)? = nil,
                wachtLokaalOpTik: (@Sendable () async -> Bool)? = nil,
                gaVerder: (@Sendable () async -> Void)? = nil,
                log: (@Sendable (String) -> Void)? = nil) {
        self.scherm = scherm
        self.koppeling = koppeling
        self.mijnKant = mijnKant
        self.gastKant = mijnKant == 2 ? 1 : 2
        self.opNieuweDeal = opNieuweDeal
        self.opNieuweZet = opNieuweZet
        self.wachtLokaalOpTik = wachtLokaalOpTik
        self.gaVerderExtern = gaVerder
        self.log = log
    }

    /// Moet vóór `spel.loop()` aangeroepen zijn — anders kan `stuurStand()`
    /// nog geen momentopname voor de gast berekenen. Start meteen ook de
    /// vaste ontvangtaak (`startOntvangen()`), die de rest van de partij
    /// blijft lopen.
    public func koppel(aan nieuwSpel: KjSpel) {
        spel = nieuwSpel
        startOntvangen()
    }

    /// Ruimt alles netjes op zodra de partij stopt: de ontvangtaak, en drie
    /// eventueel nog openstaande postbussen. Zonder dit blijft een ervan
    /// (troef, kaart, of verder) voor eeuwig hangen zodra de verbinding
    /// wegvalt terwijl de gastheer op de gast wachtte — precies wat
    /// `SpelModel.stop()` voor zijn eigen, lokale wachters ook al deed, hier
    /// hetzelfde maar dan voor de wachters die op de gást wachten.
    public func stop() {
        ontvangTaak?.cancel()
        ontvangTaak = nil
        troefAntwoord?.resume(returning: 0); troefAntwoord = nil
        kaartAntwoord?.resume(returning: (naam: .nul, kleur: 0)); kaartAntwoord = nil
        verderAntwoord?.resume(); verderAntwoord = nil
    }

    public func toon(_ view: SpelView) async {
        await scherm.toon(view)
        await stuurStand(zoals: view)
    }

    /// **De "verder"-tik kan van allebei de kanten komen** (Ed: "de
    /// volgende beurt kan alleen door degene die de laatste slag speelt
    /// worden gegeven — maak het zo dat beide kanten een nieuwe beurt
    /// kunnen starten"). Vóór deze wijziging kreeg de gast domweg nooit een
    /// tikbare stand na een slag: `wachtOpVerder` bestond niet, dus
    /// `SpelModel.pasGastStandToe` liet `modus` altijd op `.wachten` staan.
    ///
    /// Wie er als eerste tikt wint: de lokale tik (`scherm.verder`, via
    /// `SpelModel.vraagVerder`/`gaVerder`) en de tik van de gast
    /// (`wachtOpGastVerder`, gevoed door `verwerkGastBericht`) worden tegen
    /// elkaar afgezet. Wie wint, de ander wordt meteen zelf losgemaakt —
    /// nooit alleen `cancelAll()` en verder niets doen: een kale
    /// `withCheckedContinuation` laat zich niet door annuleren lostrekken
    /// (met een proefje bevestigd — zie de code-geschiedenis), dus zonder
    /// die expliciete losmaak zou deze functie na de "verkeerde" tik voor
    /// altijd blijven hangen.
    public func verder(_ view: SpelView, _ tekst: String) async {
        let magGastTikken = await wachtLokaalOpTik?() ?? false
        var origineel = view
        origineel.wachtOpVerder = magGastTikken
        await stuurStand(zoals: origineel)

        guard magGastTikken else {
            // Snel spelen of automatisch doorgaan: de gastheer wacht zelf
            // ook niet, dus is er niets om op de gast te laten wachten.
            await scherm.verder(view, tekst)
            return
        }

        await withTaskGroup(of: Void.self) { groep in
            groep.addTask { await self.scherm.verder(view, tekst) }
            groep.addTask { await self.wachtOpGastVerder() }
            await groep.next()
            await self.gaVerderExtern?()
            self.beeindigVerderWachten()
            groep.cancelAll()
        }
    }

    public func kiesTroef(_ view: SpelView) async -> Int {
        opNieuweDeal?()
        await stuurStand(zoals: view)
        let kleur: Int
        if view.benIkAanZet {
            kleur = await scherm.kiesTroef(view)
        } else {
            // Niet mijn kant die troef kiest — mijn eigen scherm moet dat ook
            // zeggen, niet stil blijven staan op de tekst van de vorige keer
            // dat ík aan zet was. Zie de aantekening bij `stuurStand`.
            var wachtView = view
            wachtView.status = Taal.zijnBeurt
            await scherm.toon(wachtView)
            kleur = await wachtOpGastTroef()
        }
        opNieuweZet?(GastZet(troef: kleur))
        return kleur
    }

    public func kiesKaart(_ view: SpelView) async -> (naam: Teken, kleur: Int) {
        await stuurStand(zoals: view)
        let antwoord: (naam: Teken, kleur: Int)
        if view.benIkAanZet {
            antwoord = await scherm.kiesKaart(view)
        } else {
            var wachtView = view
            wachtView.status = Taal.zijnBeurt
            await scherm.toon(wachtView)
            antwoord = await wachtOpGastKaart()
        }
        opNieuweZet?(GastZet(kaart: antwoord.naam, kleur: antwoord.kleur))
        return antwoord
    }

    // ------------------------------------------------------------------ hulp

    /// `zoals origineel`: `KjSpel.snapshot()` zet `troefVraag`/`wachtOpSpeler`/
    /// `status` zelf niet — dat doet alleen `speelEenSpel()`/`mensKiest()`, op
    /// de ene momentopname die ze aan `ui.kiesTroef`/`kiesKaart` meegeven. Een
    /// eigen, verse `spel.snapshot(voor: gastKant)` mist die velden dus
    /// domweg, tenzij ze hier alsnog overgenomen worden. Hetzelfde geldt voor
    /// de allerlaatste slag van een spel: `speelEenSpel()` zet daar `spelUit`
    /// en de eindstand van dít spel (`punten…`/`roem…`) op de momentopname die
    /// naar `ui.verder` gaat, vlak vóórdat `evalueerSpel()` die tellers alweer
    /// op nul zet voor het volgende spel — een verse `snapshot()` erna zou dus
    /// alweer nullen laten zien in plaats van de zojuist behaalde eindstand.
    /// Zonder deze stap leek de gast nooit ergens aan zet, en zag hij nooit
    /// dat een spel was afgelopen. `wachtOpVerder` (de "verder"-tik, zie
    /// daar) wordt op dezelfde manier overgenomen: `snapshot()` weet er ook
    /// niets van, en buiten `verder(_:_:)` staat hij altijd op `false` omdat
    /// `origineel` dat dan ook is.
    ///
    /// `status` wordt hier bewust niet overgenomen maar opnieuw bepaald: op
    /// `origineel` (altijd vanaf de vaste kant van de gastheer) betekent
    /// "Jouw beurt" domweg dat de kant die op dát moment iets moet kiezen aan
    /// zet is — dat kan de gastheer zelf zijn of de gast. Klakkeloos
    /// doorsturen liet de gast dus "Jouw beurt" lezen op momenten dat de
    /// gastheer zelf aan zet was. Met `gastStand.benIkAanZet` (al vanuit de
    /// gast berekend) klopt de tekst voor wie hem leest.
    private func stuurStand(zoals origineel: SpelView) async {
        guard let spel else {
            log?("stand overgeslagen: nog niet gekoppeld aan een partij (koppel(aan:) niet aangeroepen?)")
            return
        }
        var gastStand = spel.snapshot(voor: gastKant)
        gastStand.troefVraag = origineel.troefVraag
        gastStand.wachtOpSpeler = origineel.wachtOpSpeler
        gastStand.wachtOpVerder = origineel.wachtOpVerder
        if gastStand.troefVraag {
            gastStand.status = gastStand.benIkAanZet ? Taal.welkeTroef : Taal.zijnBeurt
        } else if gastStand.wachtOpSpeler {
            gastStand.status = gastStand.benIkAanZet ? Taal.jouwBeurt : Taal.zijnBeurt
        } else {
            gastStand.status = origineel.status
        }
        gastStand.spelUit = origineel.spelUit
        if origineel.spelUit {
            gastStand.puntenZuid = origineel.puntenZuid
            gastStand.puntenNoord = origineel.puntenNoord
            gastStand.roemZuid = origineel.roemZuid
            gastStand.roemNoord = origineel.roemNoord
            gastStand.partijUit = origineel.partijUit
            gastStand.partijGewonnenDoorZuid = origineel.partijGewonnenDoorZuid
            gastStand.partijGelijkspel = origineel.partijGelijkspel
        }
        // `melding` ("Slag N voor Zuid", en bij de laatste slag van een spel
        // ook nog "Zuid wint dit spel"/"Zuid 152, Noord 130") komt letterlijk
        // uit `KjSpel`/`KjEngine`, die alleen de vaste kant van de gastheer
        // kennen — dus altijd absoluut. Op mijn scherm ben ik altijd Zuid (zie
        // `mijnKant` in `SpelView.swift`), dus wissel de twee woorden om
        // zodra de vaste tekst niet bij mijn kant hoort.
        if gastStand.mijnKant == 2 {
            gastStand.melding = GastheerUi.zuidNoordOmgewisseld(gastStand.melding)
        }
        guard let json = try? DuoStand.codeer(gastStand) else {
            log?("stand kon niet gecodeerd worden")
            return
        }
        await koppeling.stuur(.stand(json: json))
    }

    /// Wisselt "Zuid" en "Noord" (of "South"/"North") om in een losse
    /// meldingstekst — voor de gast, voor wie die twee altijd omgekeerd
    /// gelden. Via een tussenwaarde die in gewone speltekst niet voorkomt,
    /// zodat een tweede vervanging niet de eerste weer ongedaan maakt.
    private static func zuidNoordOmgewisseld(_ tekst: String) -> String {
        guard !tekst.isEmpty else { return tekst }
        let (zuid, noord) = Taal.engels ? ("South", "North") : ("Zuid", "Noord")
        let tussenwaarde = "\u{0}"
        return tekst
            .replacingOccurrences(of: zuid, with: tussenwaarde)
            .replacingOccurrences(of: noord, with: zuid)
            .replacingOccurrences(of: tussenwaarde, with: noord)
    }

    /// De ene, vaste lezer van `koppeling` voor de hele duur van de partij —
    /// zie de aantekening bij de drie postbussen hierboven voor waarom er
    /// niet nog een tweede lezer bij mag komen.
    private func startOntvangen() {
        guard ontvangTaak == nil else { return }
        ontvangTaak = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let bericht = await self.koppeling.volgende()
                if Task.isCancelled { return }
                await self.verwerkGastBericht(bericht)
            }
        }
    }

    /// Legt een binnengekomen bericht in de postbus die erop wacht. Past het
    /// nergens bij — een dubbele of te late tik, of iets voor een fase die
    /// intussen al voorbij is — dan wordt het gewoon genegeerd, net zoals de
    /// oude `wachtOpGastTroef`/`wachtOpGastKaart`-lussen dat altijd al deden.
    private func verwerkGastBericht(_ bericht: DuoBericht) {
        guard case .zet(let json) = bericht,
              let z = try? DuoStand.decodeer(json, als: GastZet.self) else { return }
        if let troef = z.troef {
            if let c = troefAntwoord { troefAntwoord = nil; c.resume(returning: troef) }
            else { vroegTroef = troef }
        } else if let kaart = z.kaart, let kleur = z.kleur {
            if let c = kaartAntwoord { kaartAntwoord = nil; c.resume(returning: (naam: kaart, kleur: kleur)) }
            else { vroegKaart = (naam: kaart, kleur: kleur) }
        } else if z.verder == true {
            if let c = verderAntwoord { verderAntwoord = nil; c.resume() }
            else { vroegVerder = true }
        }
    }

    private func wachtOpGastTroef() async -> Int {
        if let v = vroegTroef { vroegTroef = nil; return v }
        return await withCheckedContinuation { c in troefAntwoord = c }
    }

    private func wachtOpGastKaart() async -> (naam: Teken, kleur: Int) {
        if let v = vroegKaart { vroegKaart = nil; return v }
        return await withCheckedContinuation { c in kaartAntwoord = c }
    }

    private func wachtOpGastVerder() async {
        if vroegVerder { vroegVerder = false; return }
        await withCheckedContinuation { c in verderAntwoord = c }
    }

    private func beeindigVerderWachten() {
        verderAntwoord?.resume()
        verderAntwoord = nil
    }
}
