import Foundation
import Observation
import KlaverjasKit

/// Waar het scherm op dit moment op wacht.
public enum Modus: Sendable, Equatable {
    case wachten      // de computer is aan zet
    case kiesKaart    // de speler moet een kaart aanklikken
    case kiesTroef    // de speler moet een troefkleur kiezen
    case verder       // klik of toets om door te gaan
}

/// Een doosje voor de menuschakelaars dat vanaf twee kanten benaderd wordt: het
/// scherm schrijft erin, de speeltaak leest eruit. Een slot is hier genoeg —
/// het gaat om twee jaknikkers.
final class Schakelaars: @unchecked Sendable {
    private let slot = NSLock()
    private var waarde = Instellingen()

    var huidig: Instellingen {
        get { slot.lock(); defer { slot.unlock() }; return waarde }
        set { slot.lock(); waarde = newValue; slot.unlock() }
    }
}

/// Het scherm praat met de speellogica via dit model. De speelloop draait op een
/// eigen taak en vraagt hier om invoer; het model zet die vraag om in iets wat
/// het scherm kan tonen, en wacht met een continuation tot er geklikt wordt.
@MainActor
@Observable
public final class SpelModel {
    public private(set) var view = SpelView()
    public private(set) var modus: Modus = .wachten
    public private(set) var tekst = ""

    /// Automatisch doorgaan na elke slag, zonder klikken.
    public var automatisch = false

    /// Hoe lang een gelegde kaart blijft staan voordat de volgende volgt, als
    /// de computer beide kanten speelt. Zonder die pauze verschijnen alle vier
    /// de kaarten van een slag tegelijk en valt er niets te volgen.
    public static let demoPauze = Duration.milliseconds(450)

    /// Nederlands of Engels. Schrijft door naar Taal, waar zowel het scherm als
    /// de speellogica hun teksten vandaan halen.
    public var engels: Bool = Taal.engels {
        didSet { Taal.engels = engels }
    }

    public var demo = false { didSet { schrijfSchakelaars() } }
    public var openKaart = false { didSet { schrijfSchakelaars() } }

    @ObservationIgnored private let schakelaars = Schakelaars()
    @ObservationIgnored private var taak: Task<Void, Never>?

    @ObservationIgnored private var kaartAntwoord: CheckedContinuation<(naam: Teken, kleur: Int), Never>?
    @ObservationIgnored private var troefAntwoord: CheckedContinuation<Int, Never>?
    @ObservationIgnored private var verderAntwoord: CheckedContinuation<Void, Never>?

    public init() {}

    private func schrijfSchakelaars() {
        schakelaars.huidig = Instellingen(demo: demo, openKaart: openKaart)
    }

    // ------------------------------------------------------------ starten

    /// Start een nieuwe partij; een lopende partij wordt eerst afgebroken.
    public func start(zaad: Int? = nil) {
        stop()
        schrijfSchakelaars()

        let brug = Brug(model: self)
        let doos = schakelaars
        taak = Task.detached(priority: .userInitiated) {
            let spel = KjSpel(ui: brug, zaad: zaad, instellingen: { doos.huidig })
            await spel.loop()
        }
    }

    public func stop() {
        taak?.cancel()
        taak = nil
        // Een wachtende vraag moet losgelaten worden, anders blijft de taak
        // voor eeuwig in de continuation hangen.
        kaartAntwoord?.resume(returning: (naam: Teken.nul, kleur: 0)); kaartAntwoord = nil
        troefAntwoord?.resume(returning: 0); troefAntwoord = nil
        verderAntwoord?.resume(); verderAntwoord = nil
        modus = .wachten
    }

    // ------------------------------------------- vragen van de speelloop

    /// De regel bovenin zetten. Voor previews en schermafdrukken.
    public func zetTekst(_ t: String) { tekst = t }

    /// Het scherm in een vaste stand zetten zonder dat er een spel loopt.
    /// Alleen voor previews en schermafdrukken.
    public func zetModus(_ m: Modus) { modus = m }

    /// Een vaste toestand tonen. De speelloop gebruikt dit na elke zet; een
    /// preview of schermafdruk zet er een opgeslagen momentopname mee neer.
    public func toon(_ v: SpelView) {
        view = v
        modus = .wachten
    }

    func vraagKaart(_ v: SpelView) async -> (naam: Teken, kleur: Int) {
        view = v
        tekst = v.melding.isEmpty ? v.status : v.melding
        modus = .kiesKaart
        return await withCheckedContinuation { c in kaartAntwoord = c }
    }

    func vraagTroef(_ v: SpelView) async -> Int {
        view = v
        tekst = v.status
        modus = .kiesTroef
        return await withCheckedContinuation { c in troefAntwoord = c }
    }

    func vraagVerder(_ v: SpelView, _ melding: String) async {
        view = v
        tekst = melding
        if automatisch {
            modus = .wachten
            try? await Task.sleep(for: .milliseconds(900))
            return
        }
        modus = .verder
        await withCheckedContinuation { c in verderAntwoord = c }
    }

    // --------------------------------------------------- antwoord geven

    /// De speler klikte op een kaart.
    public func klik(_ kaart: KaartView) {
        guard modus == .kiesKaart, let c = kaartAntwoord else { return }
        kaartAntwoord = nil
        modus = .wachten
        c.resume(returning: (naam: kaart.naam, kleur: kaart.kleur))
    }

    /// De speler koos een troefkleur (0..3).
    public func kiesTroef(_ kleur: Int) {
        guard modus == .kiesTroef, let c = troefAntwoord else { return }
        troefAntwoord = nil
        modus = .wachten
        c.resume(returning: kleur)
    }

    /// Klik of toets om verder te gaan.
    public func gaVerder() {
        guard modus == .verder, let c = verderAntwoord else { return }
        verderAntwoord = nil
        modus = .wachten
        c.resume()
    }

    /// Mag deze kaart op dit moment aangeklikt worden? Bij uitkomen mag je
    /// kiezen tussen je hand en je tafel; daarna licht alleen de stapel op die
    /// aan de beurt is.
    public func magKlikken(_ uitHand: Bool) -> Bool {
        guard modus == .kiesKaart else { return false }
        if view.slag.isEmpty { return true }
        return uitHand ? view.aanZet == Pos.handZuid : view.aanZet == Pos.tafelZuid
    }
}

/// De vertaling van de vier vragen van de speelloop naar het model. Een aparte
/// struct omdat de speelloop op een andere taak draait: dit is het enige stukje
/// dat de grens over gaat.
struct Brug: KjUi {
    let model: SpelModel

    func toon(_ view: SpelView) async {
        await model.toon(view)
        // De pauze hoort hier en niet in de speelloop: het is een kwestie van
        // kijken, niet van spelen. De engine zelf blijft er vrij van, en de
        // toetsen die hem nalopen draaien dus op volle snelheid.
        if await model.demo {
            try? await Task.sleep(for: SpelModel.demoPauze)
        }
    }

    func kiesKaart(_ view: SpelView) async -> (naam: Teken, kleur: Int) {
        await model.vraagKaart(view)
    }

    func kiesTroef(_ view: SpelView) async -> Int {
        await model.vraagTroef(view)
    }

    func verder(_ view: SpelView, _ tekst: String) async {
        await model.vraagVerder(view, tekst)
    }
}
