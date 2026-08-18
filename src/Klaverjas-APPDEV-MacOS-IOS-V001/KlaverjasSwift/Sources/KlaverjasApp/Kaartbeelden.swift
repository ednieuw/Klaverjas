import CoreGraphics
import Foundation
import KlaverjasKaarten
import KlaverjasKit

/// De kaarten als CGImage, per vergroting eenmaal opgebouwd.
///
/// De kaarten zijn per pixel getekend, dus ze worden alleen op hele veelvouden
/// vergroot en met Scale2x/Scale3x gladgestreken. Wat hier uitkomt gaat 1 op 1
/// naar het scherm; er wordt nergens geïnterpoleerd.
@MainActor
final class Kaartbeelden {
    private var perSchaal: [Int: [CGImage]] = [:]

    /// Alle 33 beelden op deze vergroting: 0..31 de kaarten, 32 de achterkant.
    private func beelden(_ schaal: Int) -> [CGImage] {
        if let bestaand = perSchaal[schaal] { return bestaand }
        let set = Kaartenset(schaal: schaal)
        let reeks = set.alle.compactMap(Kaartbeelden.cgImage)
        perSchaal[schaal] = reeks
        return reeks
    }

    func voor(_ naam: Teken, _ kleur: Int, schaal: Int) -> CGImage? {
        guard let scalar = Unicode.Scalar(UInt32(naam.raw)),
              let rang = OrigineleKaarten.rangRoem.firstIndex(of: Character(scalar)),
              kleur >= 0, kleur < 4 else { return nil }
        let reeks = beelden(schaal)
        let i = kleur * 8 + rang
        return i < reeks.count ? reeks[i] : nil
    }

    func achterkant(schaal: Int) -> CGImage? {
        let reeks = beelden(schaal)
        return reeks.count > 32 ? reeks[32] : nil
    }

    /// Zet een Afbeelding (0xAARRGGBB) om in een CGImage.
    nonisolated static func cgImage(_ beeld: Afbeelding) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: beeld.breedte * beeld.hoogte * 4)
        for i in 0..<(beeld.breedte * beeld.hoogte) {
            let p = beeld.pixels[i]
            bytes[i * 4] = UInt8((p >> 24) & 0xFF)
            bytes[i * 4 + 1] = UInt8((p >> 16) & 0xFF)
            bytes[i * 4 + 2] = UInt8((p >> 8) & 0xFF)
            bytes[i * 4 + 3] = UInt8(p & 0xFF)
        }
        guard let data = CFDataCreate(nil, bytes, bytes.count),
              let bron = CGDataProvider(data: data) else { return nil }

        return CGImage(width: beeld.breedte, height: beeld.hoogte,
                       bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: beeld.breedte * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue:
                            CGImageAlphaInfo.premultipliedFirst.rawValue
                          | CGBitmapInfo.byteOrder32Big.rawValue),
                       provider: bron, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)
    }
}
