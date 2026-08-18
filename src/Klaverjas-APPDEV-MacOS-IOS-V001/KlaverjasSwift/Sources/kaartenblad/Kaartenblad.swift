import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import KlaverjasKaarten

/// Zet alle kaarten naast elkaar op één afbeelding, in dezelfde indeling als
/// KaartenBlad.cs: acht rangen naast elkaar, vier kleuren onder elkaar, met de
/// achterkant erachter. De tegenhanger van
///
///     Klaverjas-app/Klaverjas.exe kaartenblad kaarten.png 3
///
/// Gebruik: swift run kaartenblad [pad] [schaal]
@main
struct Kaartenblad {
    static func main() {
        let argumenten = CommandLine.arguments
        let pad = argumenten.count > 1 ? argumenten[1] : "kaarten-swift.png"
        let schaal = argumenten.count > 2 ? (Int(argumenten[2]) ?? 3) : 3

        let marge = 8
        let kb = OrigineleKaarten.breedte * schaal
        let kh = OrigineleKaarten.hoogte * schaal
        let breed = marge + 9 * (kb + marge)
        let hoog = marge + 4 * (kh + marge) + 26

        var blad = Afbeelding(breedte: breed, hoogte: hoog,
                              vulling: OrigineleKaarten.rgb(0, 100, 60))

        let set = Kaartenset(schaal: schaal)
        for kleur in 0..<4 {
            for rang in 0..<8 {
                guard let kaart = set.voor(OrigineleKaarten.rangRoem[rang], kleur) else { continue }
                plak(&blad, kaart, marge + rang * (kb + marge), marge + kleur * (kh + marge))
            }
        }
        plak(&blad, set.achterkant, marge + 8 * (kb + marge), marge)

        // Het onderschrift van de C#-versie stond in Segoe UI; dat lettertype
        // staat niet op een Mac, dus die regel blijft hier weg. De kaarten zelf
        // zijn pixelwerk en blijven ongemoeid.
        do {
            try schrijfPng(blad, naar: pad)
            print("geschreven: \(pad)  \(breed) x \(hoog), schaal \(schaal)")
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(1)
        }
    }

    static func plak(_ blad: inout Afbeelding, _ kaart: Afbeelding, _ x0: Int, _ y0: Int) {
        for y in 0..<kaart.hoogte {
            for x in 0..<kaart.breedte {
                blad.zet(x0 + x, y0 + y, kaart[x, y])
            }
        }
    }

    struct Mislukt: Error, CustomStringConvertible {
        let description: String
    }

    static func schrijfPng(_ beeld: Afbeelding, naar pad: String) throws {
        let n = beeld.breedte * beeld.hoogte
        var bytes = [UInt8](repeating: 0, count: n * 4)
        for i in 0..<n {
            let p = beeld.pixels[i]
            bytes[i * 4] = UInt8((p >> 24) & 0xFF)
            bytes[i * 4 + 1] = UInt8((p >> 16) & 0xFF)
            bytes[i * 4 + 2] = UInt8((p >> 8) & 0xFF)
            bytes[i * 4 + 3] = UInt8(p & 0xFF)
        }

        guard let ctx = CGContext(data: &bytes, width: beeld.breedte, height: beeld.hoogte,
                                  bitsPerComponent: 8, bytesPerRow: beeld.breedte * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                            | CGBitmapInfo.byteOrder32Big.rawValue),
              let plaatje = ctx.makeImage() else {
            throw Mislukt(description: "kon de afbeelding niet opbouwen")
        }

        let url = URL(fileURLWithPath: pad)
        guard let uit = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw Mislukt(description: "kon \(pad) niet openen om te schrijven")
        }
        CGImageDestinationAddImage(uit, plaatje, nil)
        guard CGImageDestinationFinalize(uit) else {
            throw Mislukt(description: "kon \(pad) niet wegschrijven")
        }
    }
}
