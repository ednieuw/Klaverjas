import Testing
import Foundation
import KlaverjasKit
@testable import KlaverjasBLE

/// `RegelPakketten`/`RegelBuffer`: het opdelen en weer aan elkaar plakken van
/// protocolregels voor bluetooth-pakketjes van beperkte grootte (B7/B9 uit
/// het bluetooth-plan). Puur, zonder CoreBluetooth — dus hier wél volledig te
/// bewijzen, in tegenstelling tot de rest van deze laag.
struct RegelBufferTests {
    @Test("Een regel die in één pakket past, komt er ook als één pakket uit")
    func éénPakket() {
        let pakketten = RegelPakketten.verdeel("P", maxPakket: 20)
        #expect(pakketten.count == 1)
        #expect(pakketten[0] == Data("P\n".utf8))
    }

    @Test("Een lange regel wordt over meerdere pakketten verdeeld")
    func meerderePakketten() {
        let regel = "K 1.1 Th *77c0"   // 14 tekens + regeleinde = 15 bytes
        let pakketten = RegelPakketten.verdeel(regel, maxPakket: 5)
        #expect(pakketten.count == 3, "15 bytes in stukken van 5 is 3 pakketten")
        let herenigd = pakketten.reduce(Data(), +)
        #expect(herenigd == Data((regel + "\n").utf8))
    }

    @Test("Elk pakket is hooguit maxPakket bytes")
    func nooitTeGroot() {
        let regel = "SPEL 123456789 N een-hele-lange-optiestring-hier"
        for maxPakket in [1, 5, 20, 64] {
            let pakketten = RegelPakketten.verdeel(regel, maxPakket: maxPakket)
            for pakket in pakketten {
                #expect(pakket.count <= maxPakket, "pakket van \(pakket.count) > \(maxPakket)")
            }
        }
    }

    @Test("Plakt pakketjes weer aan elkaar tot de oorspronkelijke regel")
    func heenEnWeer() {
        for regel in ["P", "T 1.0 h *a3f1", "K 1.1 Th *77c0", "E DESYNC 1.5",
                      String(repeating: "x", count: 500)] {
            for maxPakket in [1, 3, 20, 64, 512] {
                var buffer = RegelBuffer()
                var teruggekregen: [String] = []
                for pakket in RegelPakketten.verdeel(regel, maxPakket: maxPakket) {
                    teruggekregen.append(contentsOf: buffer.neem(pakket))
                }
                #expect(teruggekregen == [regel],
                        "regel \"\(regel)\" met pakketten van \(maxPakket) bytes")
            }
        }
    }

    @Test("Twee regels na elkaar in één pakket komen er als twee regels uit")
    func tweeRegelsInEenPakket() {
        var buffer = RegelBuffer()
        let pakket = Data("P\nV 1\n".utf8)
        #expect(buffer.neem(pakket) == ["P", "V 1"])
    }

    @Test("Een regel die pas halverwege een volgend pakket compleet wordt")
    func regelSpreidtOverPakketten() {
        var buffer = RegelBuffer()
        #expect(buffer.neem(Data("T 1.0".utf8)) == [])
        #expect(buffer.neem(Data(" h *a".utf8)) == [])
        #expect(buffer.neem(Data("3f1\n".utf8)) == ["T 1.0 h *a3f1"])
    }

    @Test("Een half pakket levert nog geen regel op")
    func nogGeenRegeleinde() {
        var buffer = RegelBuffer()
        #expect(buffer.neem(Data("zonder einde".utf8)) == [])
    }

    @Test("Een DuoBericht komt heen en weer precies hetzelfde terug")
    func metEchteBerichten() {
        let berichten: [DuoBericht] = [
            .begroeting(versie: 1, appversie: "2.0.0", naam: "iPhone"),
            .akkoord(versie: 1),
            .stand(json: "eW5pZXQtZWNodGUtaW5ob3Vk"),
            .zet(json: "b29rLW5pZXQtZWNodA"),
            .pols,
        ]
        var buffer = RegelBuffer()
        var teruggekregen: [DuoBericht] = []
        for bericht in berichten {
            for pakket in RegelPakketten.verdeel(bericht.regel, maxPakket: 12) {
                for regel in buffer.neem(pakket) {
                    guard let terug = DuoBericht(regel: regel) else {
                        Issue.record("kon regel niet terugdecoderen: \(regel)")
                        continue
                    }
                    teruggekregen.append(terug)
                }
            }
        }
        #expect(teruggekregen == berichten)
    }

    @Test("Een buffer die alsmaar bytes krijgt zonder regeleinde loopt niet vol")
    func geenOngebondenGroei() {
        var buffer = RegelBuffer()
        for _ in 0..<10 {
            _ = buffer.neem(Data(repeating: UInt8(ascii: "x"), count: 1000))
        }
        // Geen aparte lees-toegang tot de interne buffer; deze proef bewijst
        // vooral dat er geen crash of trage groei optreedt bij duizenden
        // bytes zonder regeleinde. Een regel erna moet nog steeds gewoon
        // doorkomen — dat bewijst dat de buffer zichzelf leegde.
        #expect(buffer.neem(Data("P\n".utf8)) == ["P"])
    }
}
