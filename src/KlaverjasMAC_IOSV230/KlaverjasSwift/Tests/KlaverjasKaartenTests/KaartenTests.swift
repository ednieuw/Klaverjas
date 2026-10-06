import Foundation
import ImageIO
import CoreGraphics
import Testing
@testable import KlaverjasKaarten

/// `kaarten.png` is de contactafdruk die de C#-versie maakte met
/// `Klaverjas.exe kaartenblad kaarten.png 3`: 1511x1062, alle 32 kaarten plus
/// de achterkant op drievoudige vergroting. Tekent de Swift-versie exact
/// dezelfde pixels, dan is de kaartport net zo hard bewezen als de engine.
struct KaartenTests {
    static let marge = 8
    static let kb = OrigineleKaarten.breedte * 3    // 159
    static let kh = OrigineleKaarten.hoogte * 3     // 249

    /// De contactafdruk als 0xAARRGGBB, rij voor rij.
    static func ijkblad() throws -> Afbeelding {
        let url = try #require(Bundle.module.url(forResource: "kaarten", withExtension: "png"))
        let bron = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let plaatje = try #require(CGImageSourceCreateImageAtIndex(bron, 0, nil))

        let w = plaatje.width, h = plaatje.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        // Uitgeschreven bytevolgorde A,R,G,B: dan hoeft er niets geraden te
        // worden over hoe een UInt32 in het geheugen staat.
        let ctx = try #require(CGContext(
            data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                      | CGBitmapInfo.byteOrder32Big.rawValue))
        ctx.draw(plaatje, in: CGRect(x: 0, y: 0, width: w, height: h))

        var pixels = [UInt32](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            pixels[i] = UInt32(bytes[i * 4]) << 24 | UInt32(bytes[i * 4 + 1]) << 16
                      | UInt32(bytes[i * 4 + 2]) << 8 | UInt32(bytes[i * 4 + 3])
        }
        return Afbeelding(breedte: w, hoogte: h, pixels: pixels)
    }

    static func hex(_ c: UInt32) -> String {
        "#" + String(format: "%08X", c)
    }

    /// Vergelijkt één kaartvak met het ijkblad en geeft de eerste afwijking terug.
    static func vergelijk(_ kaart: Afbeelding, in blad: Afbeelding,
                          x0: Int, y0: Int) -> (x: Int, y: Int, verwacht: UInt32, gekregen: UInt32)? {
        for y in 0..<kaart.hoogte {
            for x in 0..<kaart.breedte {
                let verwacht = blad[x0 + x, y0 + y]
                let gekregen = kaart[x, y]
                if verwacht != gekregen { return (x, y, verwacht, gekregen) }
            }
        }
        return nil
    }

    @Test("Het ijkblad heeft de afmetingen die KaartenBlad.cs oplevert")
    func ijkbladIsHetVerwachteBlad() throws {
        let blad = try Self.ijkblad()
        #expect(blad.breedte == Self.marge + 9 * (Self.kb + Self.marge))   // 1511
        #expect(blad.hoogte == Self.marge + 4 * (Self.kh + Self.marge) + 26)  // 1062
    }

    @Test("De 32 kaarten zijn pixel voor pixel gelijk aan de C#-versie",
          arguments: 0..<4)
    func kaartenZijnGelijk(kleur: Int) throws {
        let blad = try Self.ijkblad()
        let set = Kaartenset(schaal: 3)

        for rang in 0..<8 {
            let naam = OrigineleKaarten.rangRoem[rang]
            let kaart = try #require(set.voor(naam, kleur))
            let x0 = Self.marge + rang * (Self.kb + Self.marge)
            let y0 = Self.marge + kleur * (Self.kh + Self.marge)

            if let af = Self.vergelijk(kaart, in: blad, x0: x0, y0: y0) {
                Issue.record("""
                    Kaart \(naam) van kleur \(kleur) wijkt af op pixel (\(af.x), \(af.y)):
                      C#   : \(Self.hex(af.verwacht))
                      Swift: \(Self.hex(af.gekregen))
                    """)
                return
            }
        }
    }

    @Test("De achterkant is pixel voor pixel gelijk aan de C#-versie")
    func achterkantIsGelijk() throws {
        let blad = try Self.ijkblad()
        let set = Kaartenset(schaal: 3)
        let x0 = Self.marge + 8 * (Self.kb + Self.marge)
        let y0 = Self.marge

        if let af = Self.vergelijk(set.achterkant, in: blad, x0: x0, y0: y0) {
            Issue.record("""
                De achterkant wijkt af op pixel (\(af.x), \(af.y)):
                  C#   : \(Self.hex(af.verwacht))
                  Swift: \(Self.hex(af.gekregen))
                """)
        }
    }

    @Test("Scale3x op een vlak verandert er niets aan")
    func scale3xLaatVlakkenMetRust() {
        var bron = Afbeelding(breedte: 4, hoogte: 4, vulling: 0xFF00FF00)
        bron[1, 1] = 0xFF00FF00
        let groot = OrigineleKaarten.scale3x(bron)
        #expect(groot.breedte == 12 && groot.hoogte == 12)
        #expect(groot.pixels.allSatisfy { $0 == 0xFF00FF00 })
    }
}
