import Testing
@testable import KlaverjasKit

/// `DuoOpzet`: de begroeting zodra twee toestellen verbonden zijn. Met
/// `LusLijn` te toetsen, zonder één toestel nodig te hebben.
///
/// Geen zaad/kant meer om te vergelijken (die uitwisseling verviel toen de
/// gastheer de enige echte motor werd — zie `GastheerUi`, `SpelModel`): de
/// rollen liggen al vast in de keuze die de speler zelf maakte (openstellen
/// of zoeken), dus de begroeting hoeft alleen nog de protocolversie te
/// controleren.
@Suite(.timeLimit(.minutes(1)))
struct DuoOpzetTests {
    @Test("Een gelukte begroeting geeft aan beide kanten .klaar")
    func gewoneOpzet() async {
        let (lijnGastheer, lijnGast) = LusLijn.paar()

        async let gastheer = DuoOpzet.alsGastheer(lijn: lijnGastheer, appversie: "2.0.0", naam: "Mac")
        async let gast = DuoOpzet.alsGast(lijn: lijnGast, appversie: "2.0.0", naam: "iPhone")
        let (uitkomstGastheer, uitkomstGast) = await (gastheer, gast)

        // De naam die terugkomt is die van de ÁNDER: de gastheer hoort de
        // naam die de gast van zichzelf opgaf, en omgekeerd.
        #expect(uitkomstGastheer == .klaar(naam: "iPhone", statistiek: Statistiek()))
        #expect(uitkomstGast == .klaar(naam: "Mac", statistiek: Statistiek()))
    }

    @Test("Een ander protocolversienummer wordt geweigerd, niet stilzwijgend genegeerd")
    func versieverschilWordtGeweigerd() async {
        let (lijnGastheer, lijnGast) = LusLijn.paar()

        // De "gast" hier praat met de hand een oudere versie, in plaats van
        // via `DuoOpzet.alsGast` — zo simuleer je een oudere app zonder een
        // aparte protocolversie te hoeven onderhouden.
        async let oudeGast: DuoBericht = {
            await lijnGast.stuur(.begroeting(versie: 0, appversie: "1.2.0", naam: "oud toestel"))
            return await lijnGast.ontvang()
        }()

        // Race tegen een eigen `Task.sleep`: zonder de versiecontrole stuurt
        // de gastheer door en wacht daarna eeuwig op een `JA` die deze proef
        // nooit stuurt — een kale continuation, dus geen `.timeLimit` die dat
        // redt (zie de aantekening bij `MensTests.noordSpeeltMee`).
        let uitkomstGastheer = await withTaskGroup(of: DuoOpzet.Resultaat?.self) { groep in
            groep.addTask {
                await DuoOpzet.alsGastheer(lijn: lijnGastheer, appversie: "2.0.0", naam: "Mac")
            }
            groep.addTask {
                try? await Task.sleep(for: .seconds(10))
                return nil
            }
            let eerste = await groep.next() ?? nil
            groep.cancelAll()
            return eerste
        }
        _ = await oudeGast

        #expect(uitkomstGastheer == .versieverschil(andereVersie: 0),
                "kreeg \(String(describing: uitkomstGastheer))")
    }

    @Test("Bij het verbinden verzoenen beide kanten hun bewaarde score voor deze partner")
    func scoreWordtVerzoend() async {
        let (lijnGastheer, lijnGast) = LusLijn.paar()

        // De gastheer speelde deze partner ("iPhone") eerder al eens als
        // gastheer (dus in eigen orde: [0] = zichzelf) en staat voor.
        var voorGastheer = Statistiek()
        voorGastheer.spellen = [10, 4]
        // De gast heeft voor deze partner ("Mac") nog niets bewaard.
        let eigenTellingenGastheer = ["iPhone": voorGastheer]
        let eigenTellingenGast: [String: Statistiek] = [:]

        async let gastheer = DuoOpzet.alsGastheer(lijn: lijnGastheer, appversie: "2.0.0", naam: "Mac",
                                                  eigenTellingen: eigenTellingenGastheer)
        async let gast = DuoOpzet.alsGast(lijn: lijnGast, appversie: "2.0.0", naam: "iPhone",
                                          eigenTellingen: eigenTellingenGast)
        let (uitkomstGastheer, uitkomstGast) = await (gastheer, gast)

        // Allebei moeten met dezelfde, verzoende telling verder — de
        // gastheer stond voor, dus die telling wint bij allebei. Voor de
        // gastheer verandert de kant-orde niet (hij was al Zuid); voor de
        // gast is dat dezelfde telling maar dan van diens eigen kant bekeken
        // ([0]/[1] omgewisseld), want de gastheer is voor hém de partner.
        #expect(uitkomstGastheer == .klaar(naam: "iPhone", statistiek: voorGastheer))
        #expect(uitkomstGast == .klaar(naam: "Mac", statistiek: voorGastheer.kantenOmgewisseld))
    }

    @Test("Een onverwacht bericht op het moment van de begroeting geeft .onverwacht")
    func onverwachtBerichtWordtGemeld() async {
        let (lijnGastheer, lijnGast) = LusLijn.paar()

        async let gastheer = DuoOpzet.alsGastheer(lijn: lijnGastheer, appversie: "2.0.0", naam: "Mac")
        async let ietsAnders: Void = { await lijnGast.stuur(.pols) }()
        let (uitkomst, _) = await (gastheer, ietsAnders)

        guard case .onverwacht = uitkomst else {
            Issue.record("verwachtte .onverwacht, kreeg \(uitkomst)")
            return
        }
    }
}
