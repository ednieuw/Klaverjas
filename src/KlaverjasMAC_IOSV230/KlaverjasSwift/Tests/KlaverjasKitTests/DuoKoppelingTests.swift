import Testing
@testable import KlaverjasKit

/// `DuoKoppeling`: de luistertaak en de wachtrij eromheen, los van de
/// speellogica die er bovenop komt (`GastheerUi`).
///
/// Geen "stuur nummer zoveel opnieuw" meer om te toetsen (`R`, uit de eerste
/// opzet van dit protocol) — met een volledige, zelfstandige momentopname per
/// bericht (`STAND`) hoeft een gemiste regel niet apart teruggevraagd te
/// worden, dus die hele laag (en deze proeven ervoor) is vervallen. Wat
/// overblijft is eenvoudiger: aankomt aankomt, in volgorde, ook als niemand
/// net op dat moment aan het wachten is.
@Suite(.timeLimit(.minutes(1)))
struct DuoKoppelingTests {
    @Test("Een bericht komt bij de andere kant binnen via volgende()")
    func gewoonBericht() async {
        let (kantA, kantB) = LusLijn.paar()
        let a = DuoKoppeling(lijn: kantA)
        let b = DuoKoppeling(lijn: kantB)
        await a.start()
        await b.start()

        let bericht = DuoBericht.stand(json: "abc")
        await a.stuur(bericht)

        #expect(await b.volgende() == bericht)
    }

    @Test("Berichten komen aan in de volgorde waarin ze gestuurd zijn, ook zonder wachtende volgende()")
    func volgordeZonderWachtende() async {
        let (kantA, kantB) = LusLijn.paar()
        let a = DuoKoppeling(lijn: kantA)
        let b = DuoKoppeling(lijn: kantB)
        await a.start()
        await b.start()

        // Niemand roept hier nog volgende() aan: deze berichten moeten in de
        // wachtrij van B blijven staan, in aankomstvolgorde.
        await a.stuur(.stand(json: "1"))
        await a.stuur(.stand(json: "2"))
        await a.stuur(.stand(json: "3"))

        #expect(await b.volgende() == .stand(json: "1"))
        #expect(await b.volgende() == .stand(json: "2"))
        #expect(await b.volgende() == .stand(json: "3"))
    }

    @Test("Een volgende() die al wacht, wordt losgemaakt zodra er iets komt")
    func wachtendeVolgendeWordtLosgemaakt() async {
        let (kantA, kantB) = LusLijn.paar()
        let a = DuoKoppeling(lijn: kantA)
        let b = DuoKoppeling(lijn: kantB)
        await a.start()
        await b.start()

        async let ontvangen = b.volgende()
        await a.stuur(.pols)

        #expect(await ontvangen == .pols)
    }
}
