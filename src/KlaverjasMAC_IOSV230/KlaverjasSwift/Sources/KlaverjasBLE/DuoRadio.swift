import KlaverjasKit

/// Wat het verbindingsscherm (fase 4) nodig heeft van `BlePerifeer` en
/// `BleCentraal`, boven op `DuoLijn` zelf: beginnen, stoppen, en de status
/// volgen. Eén protocol zodat het scherm niet apart met de twee rollen hoeft
/// om te gaan — het kiest er één en behandelt hem daarna hetzelfde.
public protocol DuoRadio: DuoLijn {
    func start() async
    func stop() async
    func statusStroom() async -> AsyncStream<DuoStatus>
}

extension BlePerifeer: DuoRadio {}
extension BleCentraal: DuoRadio {}

/// Zodat `LusLijn` (`KlaverjasKit`, de lus-in-het-geheugen waarmee de hele
/// samenspel-logica zonder hardware te toetsen is) ook overal kan waar een
/// echte radio wordt gevraagd — met name `SpelModel.startDuoAlsGastheer`/
/// `startDuoAlsGast`, die een `DuoRadio` binnenkrijgen in plaats van het
/// kalere `DuoLijn`, juist om hem bij `stop()` ook echt te kunnen afsluiten
/// (zie de aantekening bij `SpelModel.duoRadio`). Een lus-in-het-geheugen
/// heeft niets om te beginnen/stoppen en valt nooit vanzelf weg, dus alle
/// drie zijn hier lege invullingen — `statusStroom()` levert een stroom die
/// nooit iets uitzendt, wat voor `SpelModel.bewaakVerbinding` betekent: deze
/// verbinding valt nooit weg, precies zoals een `LusLijn` zich hoort te
/// gedragen.
extension LusLijn: DuoRadio {
    public func start() async {}
    public func stop() async {}
    public func statusStroom() async -> AsyncStream<DuoStatus> {
        AsyncStream { _ in }
    }
}
