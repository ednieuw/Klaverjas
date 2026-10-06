import Testing
@testable import KlaverjasKit

/// `LusLijn` zelf, los van alles wat er straks bovenop komt: wat de ene kant
/// stuurt moet bij de andere aankomen, in de goede volgorde, ook als de
/// ontvanger al aan het wachten was vóórdat er iets gestuurd werd.
@Suite(.timeLimit(.minutes(1)))
struct LusLijnTests {
    @Test("Wat A stuurt komt bij B aan, en omgekeerd")
    func heenEnTerug() async {
        let (a, b) = LusLijn.paar()

        await a.stuur(.pols)
        #expect(await b.ontvang() == .pols)

        await b.stuur(.stand(json: "s1"))
        #expect(await a.ontvang() == .stand(json: "s1"))
    }

    @Test("Berichten komen aan in de volgorde waarin ze gestuurd zijn")
    func volgorde() async {
        let (a, b) = LusLijn.paar()

        await a.stuur(.stand(json: "s1"))
        await a.stuur(.stand(json: "s2"))
        await a.stuur(.stand(json: "s3"))

        #expect(await b.ontvang() == .stand(json: "s1"))
        #expect(await b.ontvang() == .stand(json: "s2"))
        #expect(await b.ontvang() == .stand(json: "s3"))
    }

    @Test("Een ontvang() die al wacht, wordt losgemaakt zodra er iets komt")
    func wachtenVoordatErIetsIs() async {
        let (a, b) = LusLijn.paar()

        async let ontvangen = b.ontvang()
        // Geen vaste pauze: `ontvangen` staat al klaar te wachten voordat wij
        // hier iets sturen, en dat is precies wat deze proef moet aantonen.
        await a.stuur(.pols)

        #expect(await ontvangen == .pols)
    }

    @Test("Elke kant hoort alleen wat de andere kant stuurt, niet zijn eigen berichten")
    func geenEcho() async {
        let (a, b) = LusLijn.paar()

        await a.stuur(.pols)
        await b.stuur(.stand(json: "s9"))

        // a stuurde .pols, dus a moet nu .stand(json: "s9") van b binnenkrijgen —
        // niet zijn eigen .pols terug.
        #expect(await a.ontvang() == .stand(json: "s9"))
        #expect(await b.ontvang() == .pols)
    }
}
