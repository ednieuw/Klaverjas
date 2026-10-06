/// Voorkomt dat een proef die `Taal.engels` omzet dat doet terwijl een andere
/// proef er middenin op vertrouwt dat hij niet verandert.
///
/// Niet `public`: alleen bereikbaar via `@testable import`, want dit is puur
/// testondersteuning. `Taal.engels` is één schakelaar voor het hele programma
/// (zie aldaar), en Swift Testing draait suites — ook uit verschillende
/// testdoelen die in hetzelfde proces belanden — standaard naast elkaar. Een
/// proef die de schakelaar tijdelijk omzet kan zo een proef raken die een
/// tekst leest die er op een ander moment al op gebaseerd was. Elke proef die
/// dat risico loopt neemt hier eerst dit slot.
actor Taalslot {
    static let gedeeld = Taalslot()

    private var bezet = false
    private var wachtenden: [CheckedContinuation<Void, Never>] = []

    private func wacht() async {
        if !bezet {
            bezet = true
            return
        }
        await withCheckedContinuation { wachtenden.append($0) }
    }

    private func laatLos() {
        if wachtenden.isEmpty {
            bezet = false
        } else {
            wachtenden.removeFirst().resume()
        }
    }

    /// Voert `lichaam` uit terwijl geen andere proef via dit slot bezig is.
    ///
    /// `isolatie` erft de actor van de aanroeper (SE-0420): zonder dat zou
    /// `lichaam` — vaak `@MainActor`-gebonden, zoals in `ObservatieTests` —
    /// naar deze niet-geïsoleerde functie "verstuurd" moeten worden, en dat
    /// wijst de compiler in strikte concurrency af.
    static func metSlot<R>(
        isolatie: isolated (any Actor)? = #isolation,
        _ lichaam: () async throws -> R
    ) async rethrows -> R {
        await gedeeld.wacht()
        do {
            let r = try await lichaam()
            await gedeeld.laatLos()
            return r
        } catch {
            await gedeeld.laatLos()
            throw error
        }
    }
}
