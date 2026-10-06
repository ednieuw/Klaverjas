/// Wat de speellogica van de buitenwereld nodig heeft.
///
/// In de C#-versie blokkeerden deze drie vraag-methodes de speelthread tot de
/// speler iets deed. Hier zijn het `async`-functies: de speelloop wacht netjes
/// zonder een thread bezet te houden, en het scherm blijft ondertussen van de
/// hoofdactor.
public protocol KjUi: Sendable {
    /// Nieuwe toestand tonen.
    func toon(_ view: SpelView) async

    /// Wacht tot de speler een kaart kiest.
    func kiesKaart(_ view: SpelView) async -> (naam: Teken, kleur: Int)

    /// Wacht tot de speler een troefkleur kiest (0..3).
    func kiesTroef(_ view: SpelView) async -> Int

    /// Wacht tot de speler verder wil.
    func verder(_ view: SpelView, _ tekst: String) async

    /// Toont de uitslag van een slag zonder op een eigen tik te wachten — voor
    /// de kant die niet zelf beslist wanneer de partij verdergaat (B3-vervolg:
    /// bij samenspel is de gastheer de baas over het tempo, zie `DuoUi`).
    /// Standaard hetzelfde als `verder(_:_:)`, zodat elke bestaande `KjUi` die
    /// dit onderscheid niet kent — alles buiten `Brug` — ongewijzigd blijft.
    func toonUitslag(_ view: SpelView, _ tekst: String) async

    /// Wordt er snel gespeeld, zonder kaarten? Dan toont het scherm alleen tellers, en bouwt de
    /// speelloop geen kaartbeelden meer op: geen `toon` per kaart, en bij het eind van een slag en van
    /// het spel een lichte momentopname zonder kaarten (zie `KjSpel.snapshot(licht:)`).
    /// Moet snel en zonder wachten te lezen zijn: de speelloop vraagt het bij elke kaart.
    var snelSpelen: Bool { get }
}

public extension KjUi {
    var snelSpelen: Bool { false }

    func toonUitslag(_ view: SpelView, _ tekst: String) async {
        await verder(view, tekst)
    }
}

/// De schakelaars uit het menu Opties.
public struct Instellingen: Sendable {
    /// De computer speelt beide kanten.
    public var demo = false
    /// De kaarten van Noord open op tafel.
    public var openKaart = false
    /// Speelt Zuid volgens de zoekende speler in plaats van de vuistregels?
    /// Alleen van belang als de computer die kant speelt.
    public var zoektZuid = false
    /// Speelt Noord volgens de zoekende speler?
    public var zoektNoord = false
    /// Speelt deze kant volgens Claude? Gaat voor `zoektZuid`/`zoektNoord`.
    public var claudeZuid = false
    public var claudeNoord = false

    public init(demo: Bool = false, openKaart: Bool = false,
                zoektZuid: Bool = false, zoektNoord: Bool = false,
                claudeZuid: Bool = false, claudeNoord: Bool = false) {
        self.demo = demo
        self.openKaart = openKaart
        self.zoektZuid = zoektZuid
        self.zoektNoord = zoektNoord
        self.claudeZuid = claudeZuid
        self.claudeNoord = claudeNoord
    }
}

/// De speelloop uit main() van KJ.C: delen, troef bepalen, acht slagen spelen,
/// afrekenen, opnieuw.
///
/// `@unchecked Sendable`: `loop()` draait op zijn eigen taak en muteert `e`/
/// `s` alleen daar — met één bewuste uitzondering, `s.mens`, die `SpelModel`
/// live omzet zodra "Samen spelen" op een al lopende partij aansluit
/// (`startDuoAlsGastheer`). Twee `Bool`s in een klein array, buiten de
/// speelloop zelf nooit gelezen tijdens het omzetten: het risico is een
/// enkele verouderde lezing in dezelfde beurt, nooit een crash of een
/// kapotte toestand.
public final class KjSpel: @unchecked Sendable {
    public let e: KjEngine
    private let ui: KjUi
    private var s: KjState { e.s }

    /// De menuschakelaars worden niet van buitenaf in de engine geschreven —
    /// die draait op een eigen taak. In plaats daarvan leest de speelloop ze
    /// zelf uit, telkens op een moment dat het veilig is.
    private let leesInstellingen: @Sendable () -> Instellingen

    /// Welke kant "ik" ben op dit toestel: 1 = Zuid, 2 = Noord. Gaat rechtstreeks
    /// de momentopname in als `SpelView.mijnKant` (B5/B3 uit het bluetooth-plan).
    /// Standaard 1 — op één toestel is dat altijd zo geweest.
    private let mijnKant: Int

    private var vorigeSlag: [SlagView] = []
    private var melding = ""

    public init(ui: KjUi, zaad: Int? = nil,
                instellingen: @escaping @Sendable () -> Instellingen = { Instellingen() },
                beginStatistiek: Statistiek? = nil, mijnKant: Int = 1) {
        self.ui = ui
        self.e = KjEngine(zaad: zaad)
        self.leesInstellingen = instellingen
        self.mijnKant = mijnKant
        // De tellingen van de vorige keer, voordat er ook maar één kaart valt.
        if let st = beginStatistiek { e.s.zetStatistiek(st) }
    }

    private func pasInstellingenToe() {
        let i = leesInstellingen()
        s.comp = i.demo
        s.dicht = !i.openKaart
        s.zoekt[0] = i.zoektZuid
        s.zoekt[1] = i.zoektNoord
        s.claude[0] = i.claudeZuid
        s.claude[1] = i.claudeNoord
    }

    /// Speelt spel na spel tot de taak wordt afgebroken.
    public func loop() async {
        s.speler = s.random(2) + 1

        while !Task.isCancelled {
            await speelEenSpel()
        }
    }

    private func speelEenSpel() async {
        pasInstellingenToe()
        s.troef = 999
        s.slagNr = 0
        s.slagKrtNo = 0
        vorigeSlag = []
        melding = ""

        e.delen()

        s.speler = 1 - (s.speler - 1) + 1      // wisselt tussen 1 en 2
        s.vrager = s.speler
        s.startVrager = s.speler

        for n in 0..<4 { s.tNoord[n] = 1; s.tZuid[n] = 1 }

        e.kaartenVrij()
        e.zetTafelPosities()
        e.vulhanden()

        s.slagNr = 0

        // Was `s.startVrager == 2`: dan koos de computer altijd voor Noord,
        // want alleen Zuid was mens. Met `s.mensIsAanZet(_:)` krijgt Noord de
        // vraag ook, zodra die kant op dit toestel als mens speelt.
        if s.comp || !s.mensIsAanZet(s.startVrager) {
            e.troefBepalen()
        } else {
            var v = snapshot()
            v.troefVraag = true
            v.status = Taal.welkeTroef
            s.troef = await ui.kiesTroef(v)
            e.zetActWaarden()
        }

        // Statistiek over de verdeling van deze deal.
        for n in 0..<32 {
            let k = s.kaart[n]
            let kant: Int
            switch k.dichtIkHy {
            case Pos.handZuid, Pos.tafelZuid, Pos.dichtZuid: kant = 0
            case Pos.handNoord, Pos.tafelNoord, Pos.dichtNoord: kant = 1
            default: continue
            }
            s.kaartpnt[kant] += Int64(k.actWaarde)
            if k.kleur == s.troef {
                s.troefkrt[kant] += 1
                s.troefpnt[kant] += Int64(k.actWaarde)
            }
        }

        s.slagNr = 1
        while s.slagNr < 9 {
            if Task.isCancelled { return }

            pasInstellingenToe()
            s.tactiek = 0
            e.speler1()
            if !(await speelZet()) { await errorLegKaart(); break }
            s.startVrager = s.vrager
            if s.tactiek == 41 { s.tactiek41 = true }
            s.tac[KjSpel.begrens(s.tactiek)] += 1

            pasInstellingenToe()
            s.tactiek = 0
            e.tegenspeler1()
            if !(await speelZet()) { await errorLegKaart(); break }
            s.tac[KjSpel.begrens(s.tactiek)] += 1

            pasInstellingenToe()
            s.tactiek = 0
            e.speler2()
            if !(await speelZet()) { await errorLegKaart(); break }
            s.tac[KjSpel.begrens(s.tactiek)] += 1

            pasInstellingenToe()
            s.tactiek = 0
            e.tegenspeler2()
            if !(await speelZet()) { await errorLegKaart(); break }
            s.tac[KjSpel.begrens(s.tactiek)] += 1

            let uitslag = e.evalueer()

            var winnaar = e.wieSlag()
            if winnaar > 2 { winnaar -= 2 }
            if s.slagNr < 8 {
                melding = KjSpel.slagMelding(s.slagNr, winnaar == 1, uitslag)
            }

            if s.slagNr == 8 {
                // evalueerSpel() telt de punten bij het partijtotaal op en zet
                // de tellers van dit spel daarna op nul. De momentopname erna
                // liet dus overal nullen zien, en juist bij de laatste kaart
                // wil je zien wie het spel won en met hoeveel. Daarom geeft hij
                // de getallen terug — inclusief de bonus voor pit, die hij zelf
                // pas op dat moment optelt.
                let eind = e.evalueerSpel()
                melding = KjSpel.slagMelding(s.slagNr, winnaar == 1, uitslag,
                                             pitRoem: eind.pitRoem, tegenpit: eind.tegenpit)
                    + Taal.scheiding + eind.tekst

                var v = snapshot(licht: ui.snelSpelen)      // met de bijgewerkte partijtotalen
                v.puntenZuid = eind.puntenZuid
                v.puntenNoord = eind.puntenNoord
                v.roemZuid = eind.roemZuid
                v.roemNoord = eind.roemNoord
                v.spelUit = true
                v.partijUit = eind.partijUit
                v.partijGewonnenDoorZuid = eind.partijGewonnenDoorZuid
                v.partijGelijkspel = eind.partijGelijkspel
                await ui.verder(v, melding)
            } else {
                await ui.verder(snapshot(licht: ui.snelSpelen), melding)
                vorigeSlag = huidigeSlag()
                e.updateTafel()
                s.slagKrtNo = 0
            }

            s.slagNr += 1
        }

        s.slagKrtNo = 0
    }

    private static func begrens(_ tactiek: Int) -> Int {
        (tactiek >= 0 && tactiek < 80) ? tactiek : 0
    }

    /// Regel bovenin: wie won de slag en wat leverde die op.
    private static func slagMelding(_ slagNr: Int, _ zuidWon: Bool, _ u: SlagUitslag,
                                    pitRoem: Int = 0, tegenpit: Bool = false) -> String {
        var tekst = Taal.slagVoor(slagNr, zuidWon)
        if u.roem > 0 { tekst += Taal.metRoem(u.roem) }
        if u.laatsteSlag > 0 { tekst += Taal.laatsteSlag(u.laatsteSlag, naRoem: u.roem > 0) }
        // De pit hoort in dezelfde opsomming: "10 voor de laatste slag, 100
        // voor pit". Hij komt pas uit `evalueerSpel()`, dus bij de achtste slag
        // wordt deze zin daarna gemaakt.
        if pitRoem > 0 {
            tekst += tegenpit ? Taal.voorTegenpit(pitRoem) : Taal.voorPit(pitRoem)
        }
        return tekst
    }

    /// Legt de zet die de AI koos, of vraagt de mens om er een. Geeft false als
    /// er een onspeelbare kaart uit de tactiek kwam (verzaken door de computer).
    private func speelZet() async -> Bool {
        if e.wachtOpMens {
            e.zetMensKlaar()
            await mensKiest()
        }

        if !e.legKaart(s.lkaart, s.lkleur, s.vrager) { return false }
        if e.checkValid() != nil { return false }

        // Bij snel spelen valt er niets te tonen en kost het opbouwen van alle kaartbeelden meer dan
        // het spelen zelf.
        if !ui.snelSpelen { await ui.toon(snapshot()) }
        return true
    }

    /// humaan(): vraagt net zolang een kaart tot er een geldige komt.
    private func mensKiest() async {
        // Welke kant hier aan zet is, in Pos-codes: was altijd Zuid, want
        // alleen Zuid kon mens zijn. `s.vrager` draagt de kant al — in de
        // hand- of tafelvorm — dus dat is de kortste weg naar de bijbehorende
        // codes. Eén keer bepaald bij binnenkomst: verderop in de lus wijzigt
        // `s.vrager` wel (bij uitkomen, zie onder), maar niet van kant.
        let kant = s.vrager > 2 ? s.vrager - 2 : s.vrager
        let eigenHand = kant == 2 ? Pos.handNoord : Pos.handZuid
        let eigenTafel = kant == 2 ? Pos.tafelNoord : Pos.tafelZuid

        while true {
            // Deze taak is stopgezet (`stop()`/`startDuoAlsGast` op het
            // scherm, ná deze partij) en de aangesloten `KjUi` heeft dat aan
            // ons doorgegeven door onmiddellijk, zonder navraag, een ongeldige
            // kaart terug te geven — dan is er niets meer om op te wachten.
            // Zonder deze uitgang bleef zo'n verweesde taak voor eeuwig
            // dezelfde ongeldige kaart aangeboden krijgen en aanvragen, met
            // niets ertussen dan `Task.yield()`: een kern die voorgoed bezet
            // blijft. Ontdekt toen samenspel de motor een "generatie" gaf
            // (`SpelModel.generatie`) om precies dit soort verweesde
            // aanroepen zonder gevolg te maken — die maakte deze lus daardoor
            // wél degelijk oneindig snel, waar hij dat eerder niet was.
            guard !Task.isCancelled else { return }

            // Een expliciete stap opzij, niet alleen de `await` van kiesKaart
            // hieronder: reageert een aangesloten `KjUi` direct, zonder ooit
            // écht te wachten, dan geeft die `await` de planner weinig reden
            // om te wisselen. Onschuldig bij een normale terugvraag ("geen
            // troef bekend, probeer opnieuw"); een gezonde gewoonte zodra er
            // straks een Bluetooth-koppeling tussen zit die uit de pas kan
            // lopen. Geen garantie tegen een `KjUi` die structureel dezelfde
            // ongeldige kaart blijft aanbieden — dat bleek bij het testen van
            // A4/B4 (zie `MensTests.noordSpeeltMee`): dan blijft deze lus wél
            // één kern bezet houden, `Task.yield()` of niet. De uitgang
            // hierboven redt het specifieke geval van een stopgezette taak;
            // een structureel foute `KjUi` die wél antwoordt maar altijd fout
            // blijft dit nog steeds niet redden.
            await Task.yield()

            var v = snapshot()
            v.wachtOpSpeler = true
            v.status = Taal.jouwBeurt
            v.melding = melding

            let (naam, kleur) = await ui.kiesKaart(v)
            s.lkaart = naam
            s.lkleur = kleur

            var found = false
            var i = 0
            for n in (kleur * 8)..<(kleur * 8 + 8) {
                if s.kaart[n].naam == s.lkaart { i = s.kaart[n].dichtIkHy }
                if s.slagKrtNo == 0 && (s.vrager == eigenHand || s.vrager == eigenTafel) {
                    // Bij uitkomen mag je zelf kiezen: uit de hand of van tafel.
                    if i == eigenHand || i == eigenTafel { found = true; s.vrager = i }
                } else if s.vrager == i {
                    found = true
                }
            }

            if found {
                let fout = e.checkValid()
                if fout == nil {
                    // De klacht over de vorige poging is afgehandeld. Bleef hij
                    // staan, dan kwam hij bij elke volgende kaart weer in beeld
                    // — tot en met de laatste slag, terwijl er allang goed
                    // gespeeld werd.
                    melding = ""
                    return
                }
                melding = fout!
                continue
            }

            switch i {
            case eigenTafel: melding = Taal.kaartLigtOpTafel
            case eigenHand: melding = Taal.kaartZitInHand
            default: melding = Taal.kaartNietSpeelbaar
            }
        }
    }

    /// error_legkaart(): de computer koos een onspeelbare kaart. Het spel stopt
    /// en alle punten gaan naar de tegenpartij.
    private func errorLegKaart() async {
        var vrager = s.vrager
        if vrager > 2 { vrager -= 2 }
        if vrager < 1 || vrager > 2 { vrager = 1 }
        let m = (vrager == 1) ? 2 : 1

        s.puntenSpel[m - 1] += 152 + s.roem[vrager - 1] + s.roem[m - 1]
        s.puntenSpel[vrager - 1] = 0
        s.roem[vrager - 1] = 0

        s.puntenTotaalSpel[0] += Int64(s.puntenSpel[0] + s.roem[0])
        s.puntenTotaalSpel[1] += Int64(s.puntenSpel[1] + s.roem[1])
        s.puntenSpel[0] = 0; s.puntenSpel[1] = 0
        s.roem[0] = 0; s.roem[1] = 0
        for n in 0..<4 { s.verzaakt[0][n] = 0; s.verzaakt[1][n] = 0 }

        await ui.verder(snapshot(licht: ui.snelSpelen), Taal.computerVerzaakte(s.tactiek, s.lkleur, s.lkaart))
    }

    // ------------------------------------------------------------ snapshot

    private func huidigeSlag() -> [SlagView] {
        var lijst: [SlagView] = []
        for n in 0..<min(s.slagKrtNo, 4) {
            let sk = s[slag: s.slagNr, i: n]
            lijst.append(SlagView(kleur: sk.kleur, naam: sk.naam,
                                  speler: sk.speler, tactiek: sk.tactiek))
        }
        return lijst
    }

    /// Bouwt de momentopname waarop de UI tekent.
    ///
    /// `voor kant` is er voor samenspel (fase 5 van het bluetooth-plan): de
    /// gastheer draait de enige echte motor en moet zelf kunnen uitrekenen wat
    /// de gast — de andere kant — op zíjn scherm te zien mag krijgen, los van
    /// wat er op het eigen scherm staat. Standaard `mijnKant` (dit toestel),
    /// dus bestaande aanroepen veranderen niet.
    ///
    /// `licht`: alleen de getallen en de tellingen, zonder de 32 kaartbeelden en hun sortering.
    /// Voor snel spelen, waar het scherm geen kaarten tekent.
    public func snapshot(voor kant: Int? = nil, licht: Bool = false) -> SpelView {
        let kant = kant ?? mijnKant
        pasInstellingenToe()
        var v = SpelView()
        v.mijnKant = kant
        v.troef = s.troef
        v.slagNr = s.slagNr
        v.aanZet = s.vrager
        v.puntenZuid = s.puntenSpel[0]
        v.puntenNoord = s.puntenSpel[1]
        v.roemZuid = s.roem[0]
        v.roemNoord = s.roem[1]
        v.totaalZuid = s.puntenTotaalSpel[0]
        v.totaalNoord = s.puntenTotaalSpel[1]
        v.zoekt = s.zoekt
        v.claude = s.claude
        v.troefmaker = (s.speler == 1 || s.speler == 2) ? s.speler : 0
        v.partijenZuid = s.gewonnen[0]
        v.partijenNoord = s.gewonnen[1]
        // Bij `licht` ook geen kaarten van de lopende en de vorige slag: het paneel naast het
        // snelle-spelenscherm tekent die als "Vorige slag", en dat is bij duizenden spellen per minuut
        // tekenwerk op de hoofdtaak, waar de speelloop bij elke slag op moet wachten.
        v.slag = licht ? [] : huidigeSlag()
        v.vorigeSlag = licht ? [] : vorigeSlag
        v.melding = melding
        v.statistiek = s.statistiek
        if licht { return v }

        for i in 0..<4 {
            v.onderZuid[i] = s.tZuid[i] != 0
            v.onderNoord[i] = s.tNoord[i] != 0
        }

        var volg = 0
        for n in 0..<32 {
            let k = s.kaart[n]
            var kv = KaartView()
            kv.index = n
            kv.naam = k.naam
            kv.kleur = k.kleur
            kv.open = true
            kv.plek = e.tafelPos(n)

            // Mijn eigen hand is altijd open; de andere hand alleen met de
            // "open kaart"-instelling (een spiekknop voor tegen de computer,
            // hier ook bruikbaar om de eigen hand van de ándere kant te
            // bekijken). Vóór `voor kant` was dit hardgecodeerd op Zuid =
            // altijd open, Noord = alleen met spieken — bij samenspel met
            // Noord als eigen kant liet dat de kaarten van de tegenpartij
            // (Zuid) gewoon zien: geen spiekinstelling nodig. Vandaar hier
            // expliciet relatief aan `kant` in plaats van aan Zuid.
            switch k.dichtIkHy {
            case Pos.handZuid:
                kv.plek = volg; volg += 1; kv.open = (kant == 1) || !s.dicht
                v.handZuid.append(kv)
            case Pos.handNoord:
                kv.open = (kant == 2) || !s.dicht
                v.handNoord.append(kv)
            case Pos.tafelZuid, Pos.nieuwZuid: v.tafelZuid.append(kv)
            case Pos.tafelNoord, Pos.nieuwNoord: v.tafelNoord.append(kv)
            case Pos.dichtZuid: kv.open = !s.dicht; v.dichtZuid.append(kv)
            case Pos.dichtNoord: kv.open = !s.dicht; v.dichtNoord.append(kv)
            default: break
            }
        }

        // Hand van Zuid op kleur en rang sorteren, dat speelt prettiger.
        v.handZuid.sort(by: vergelijkKaart)
        v.tafelZuid.sort { $0.plek < $1.plek }
        v.tafelNoord.sort { $0.plek < $1.plek }

        for i in 0..<v.handNoord.count { v.handNoord[i].plek = i }
        for i in 0..<v.dichtZuid.count { v.dichtZuid[i].plek = i }
        for i in 0..<v.dichtNoord.count { v.dichtNoord[i].plek = i }
        for i in 0..<v.handZuid.count { v.handZuid[i].plek = i }

        return v
    }

    private func vergelijkKaart(_ a: KaartView, _ b: KaartView) -> Bool {
        if a.kleur != b.kleur {
            // Troef vooraan.
            let at = a.kleur == s.troef, bt = b.kleur == s.troef
            if at != bt { return at }
            return a.kleur < b.kleur
        }
        let rang = a.kleur == s.troef ? KjState.rangTroef : KjState.rangNorm
        return CStr.pos(rang, a.naam) < CStr.pos(rang, b.naam)
    }
}
