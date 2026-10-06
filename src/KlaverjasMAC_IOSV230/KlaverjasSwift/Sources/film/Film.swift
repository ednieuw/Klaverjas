import AVFoundation
import CoreGraphics
import Foundation
import SwiftUI
import KlaverjasApp
import KlaverjasKit

/// Maakt een filmpje van de app terwijl de computer beide kanten speelt: de
/// voorvertoning voor de App Store.
///
/// De beelden komen uit het spel zelf — dezelfde View als in het programma,
/// met dezelfde kaarten. Er wordt niets nagebouwd of nagespeeld.
///
///     swift run film <pad.mp4> <breedte> <hoogte> <taal> <seconden per zet>
@main
struct Film {
    static func main() async {
        let a = CommandLine.arguments
        let pad = a.count > 1 ? a[1] : "voorvertoning.mp4"
        let breed = a.count > 2 ? (Int(a[2]) ?? 1920) : 1920
        let hoog = a.count > 3 ? (Int(a[3]) ?? 1080) : 1080
        Taal.engels = (a.count > 4 && a[4].lowercased() == "en")
        let perZet = a.count > 5 ? (Double(a[5]) ?? 0.55) : 0.55

        // Zo veel momentopnamen dat het filmpje tussen de 15 en 30 seconden
        // duurt; dat is wat de App Store voor een voorvertoning vraagt.
        let aantal = max(28, min(48, Int(24.0 / perZet)))

        let vanger = Vanger(nodig: aantal)
        let spel = KjSpel(ui: vanger, zaad: 12,
                          instellingen: { Instellingen(demo: true, openKaart: false) })
        let taak = Task.detached { await spel.loop() }
        let beelden = await vanger.wacht()
        taak.cancel()

        print("\(beelden.count) momentopnamen; \(String(format: "%.1f", Double(beelden.count) * perZet)) seconden")

        await MainActor.run {
            do {
                try schrijf(beelden, naar: pad, breed: breed, hoog: hoog, perZet: perZet)
                print("geschreven: \(pad)")
            } catch {
                FileHandle.standardError.write(Data("mislukt: \(error)\n".utf8))
                exit(1)
            }
        }
    }

    struct Mislukt: Error, CustomStringConvertible { let description: String }

    @MainActor
    static func schrijf(_ beelden: [(SpelView, String)], naar pad: String,
                        breed: Int, hoog: Int, perZet: Double) throws {
        let url = URL(fileURLWithPath: pad)
        try? FileManager.default.removeItem(at: url)

        let schrijver = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let invoer = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: breed,
            AVVideoHeightKey: hoog,
        ])
        invoer.expectsMediaDataInRealTime = false
        let koppeling = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: invoer,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: breed,
                kCVPixelBufferHeightKey as String: hoog,
            ])
        guard schrijver.canAdd(invoer) else { throw Mislukt(description: "invoer geweigerd") }
        schrijver.add(invoer)
        guard schrijver.startWriting() else {
            throw Mislukt(description: "kon niet beginnen: \(schrijver.error as Any)")
        }
        schrijver.startSession(atSourceTime: .zero)

        let tempo: Int32 = 30
        let perBeeld = Int(perZet * Double(tempo))
        var nummer: Int64 = 0

        let model = SpelModel()
        model.demo = true
        model.engels = Taal.engels

        for (beeld, tekst) in beelden {
            model.toon(beeld)
            model.zetTekst(tekst)

            let renderer = ImageRenderer(content:
                SpelScherm(model: model)
                    .frame(width: CGFloat(breed), height: CGFloat(hoog)))
            renderer.scale = 1
            guard let plaatje = renderer.cgImage else {
                throw Mislukt(description: "kon beeld niet tekenen")
            }
            guard let buffer = maakBuffer(plaatje, breed: breed, hoog: hoog) else {
                throw Mislukt(description: "kon beeldbuffer niet maken")
            }

            for _ in 0..<perBeeld {
                while !invoer.isReadyForMoreMediaData { usleep(2000) }
                koppeling.append(buffer, withPresentationTime: CMTime(value: nummer, timescale: tempo))
                nummer += 1
            }
        }

        invoer.markAsFinished()
        let wacht = DispatchSemaphore(value: 0)
        schrijver.finishWriting { wacht.signal() }
        wacht.wait()
        if schrijver.status != .completed {
            throw Mislukt(description: "\(schrijver.error as Any)")
        }
    }

    static func maakBuffer(_ beeld: CGImage, breed: Int, hoog: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, breed, hoog, kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferCGImageCompatibilityKey: true,
                             kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
                            &buffer)
        guard let b = buffer else { return nil }
        CVPixelBufferLockBaseAddress(b, [])
        defer { CVPixelBufferUnlockBaseAddress(b, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(b),
                                  width: breed, height: hoog, bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(b),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                            | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        ctx.draw(beeld, in: CGRect(x: 0, y: 0, width: breed, height: hoog))
        return b
    }
}

/// Vangt een reeks momentopnamen op terwijl de computer speelt.
final actor Vanger: KjUi {
    private let nodig: Int
    private var beelden: [(SpelView, String)] = []
    private var wachter: CheckedContinuation<[(SpelView, String)], Never>?

    init(nodig: Int) { self.nodig = nodig }

    func wacht() async -> [(SpelView, String)] {
        await withCheckedContinuation { c in
            if beelden.count >= nodig { c.resume(returning: beelden) } else { wachter = c }
        }
    }

    private func bewaar(_ v: SpelView, _ t: String) {
        guard beelden.count < nodig else { return }
        beelden.append((v, t))
        if beelden.count >= nodig, let c = wachter {
            wachter = nil
            c.resume(returning: beelden)
        }
    }

    func toon(_ view: SpelView) async { bewaar(view, view.melding) }
    func verder(_ view: SpelView, _ tekst: String) async { bewaar(view, tekst) }
    func kiesKaart(_ view: SpelView) async -> (naam: Teken, kleur: Int) { (naam: .nul, kleur: 0) }
    func kiesTroef(_ view: SpelView) async -> Int { 0 }
}
