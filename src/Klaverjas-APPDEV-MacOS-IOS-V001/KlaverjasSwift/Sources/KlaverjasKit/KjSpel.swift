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
}

/// De schakelaars uit het menu Opties.
public struct Instellingen: Sendable {
    /// De computer speelt beide kanten.
    public var demo = false
    /// De kaarten van Noord open op tafel.
    public var openKaart = false

    public init(demo: Bool = false, openKaart: Bool = false) {
        self.demo = demo
        self.openKaart = openKaart
    }
}

/// De speelloop uit main() van KJ.C: delen, troef bepalen, acht slagen spelen,
/// afrekenen, opnieuw.
public final class KjSpel {
    public let e: KjEngine
    private let ui: KjUi
    private var s: KjState { e.s }

    /// De menuschakelaars worden niet van buitenaf in de engine geschreven —
    /// die draait op een eigen taak. In plaats daarvan leest de speelloop ze
    /// zelf uit, telkens op een moment dat het veilig is.
    private let leesInstellingen: @Sendable () -> Instellingen

    private var vorigeSlag: [SlagView] = []
    private var melding = ""

    public init(ui: KjUi, zaad: Int? = nil,
                instellingen: @escaping @Sendable () -> Instellingen = { Instellingen() }) {
        self.ui = ui
        self.e = KjEngine(zaad: zaad)
        self.leesInstellingen = instellingen
    }

    private func pasInstellingenToe() {
        let i = leesInstellingen()
        s.comp = i.demo
        s.dicht = !i.openKaart
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

        if s.comp || s.startVrager == 2 {
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
            melding = KjSpel.slagMelding(s.slagNr, winnaar == 1, uitslag)

            if s.slagNr == 8 {
                // evalueerSpel() telt de punten bij het partijtotaal op en zet
                // de tellers van dit spel daarna op nul. De momentopname erna
                // liet dus overal nullen zien, en juist bij de laatste kaart
                // wil je zien wie het spel won en met hoeveel. De behaalde
                // punten worden hier bewaard en teruggezet.
                let puntenZ = s.puntenSpel[0], puntenN = s.puntenSpel[1]
                let roemZ = s.roem[0], roemN = s.roem[1]

                melding += Taal.scheiding + e.evalueerSpel()

                var v = snapshot()      // met de bijgewerkte partijtotalen
                v.puntenZuid = puntenZ
                v.puntenNoord = puntenN
                v.roemZuid = roemZ
                v.roemNoord = roemN
                v.spelUit = true
                await ui.verder(v, melding)
            } else {
                await ui.verder(snapshot(), melding)
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
    private static func slagMelding(_ slagNr: Int, _ zuidWon: Bool, _ u: SlagUitslag) -> String {
        var tekst = Taal.slagVoor(slagNr, zuidWon)
        if u.roem > 0 { tekst += Taal.metRoem(u.roem) }
        if u.laatsteSlag > 0 { tekst += Taal.laatsteSlag(u.laatsteSlag, naRoem: u.roem > 0) }
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

        await ui.toon(snapshot())
        return true
    }

    /// humaan(): vraagt net zolang een kaart tot er een geldige komt.
    private func mensKiest() async {
        while true {
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
                if s.slagKrtNo == 0 && (s.vrager == 1 || s.vrager == 3) {
                    // Bij uitkomen mag je zelf kiezen: uit de hand of van tafel.
                    if i == Pos.handZuid || i == Pos.tafelZuid { found = true; s.vrager = i }
                } else if s.vrager == i {
                    found = true
                }
            }

            if found {
                let fout = e.checkValid()
                if fout == nil { return }
                melding = fout!
                continue
            }

            switch i {
            case Pos.tafelZuid: melding = Taal.kaartLigtOpTafel
            case Pos.handZuid: melding = Taal.kaartZitInHand
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

        await ui.verder(snapshot(), Taal.computerVerzaakte(s.tactiek, s.lkleur, s.lkaart))
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
    public func snapshot() -> SpelView {
        pasInstellingenToe()
        var v = SpelView()
        v.troef = s.troef
        v.slagNr = s.slagNr
        v.aanZet = s.vrager
        v.puntenZuid = s.puntenSpel[0]
        v.puntenNoord = s.puntenSpel[1]
        v.roemZuid = s.roem[0]
        v.roemNoord = s.roem[1]
        v.totaalZuid = s.puntenTotaalSpel[0]
        v.totaalNoord = s.puntenTotaalSpel[1]
        v.partijenZuid = s.gewonnen[0]
        v.partijenNoord = s.gewonnen[1]
        v.slag = huidigeSlag()
        v.vorigeSlag = vorigeSlag
        v.melding = melding
        v.statistiek = s.statistiek

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

            switch k.dichtIkHy {
            case Pos.handZuid: kv.plek = volg; volg += 1; v.handZuid.append(kv)
            case Pos.handNoord: kv.open = !s.dicht; v.handNoord.append(kv)
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
