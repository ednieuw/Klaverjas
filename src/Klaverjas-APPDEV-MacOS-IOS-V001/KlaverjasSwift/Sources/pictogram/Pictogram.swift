import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import KlaverjasKaarten

/// Maakt het programmapictogram uit de kaarten zelf: drie kaarten uit KJKRT.C
/// naast elkaar op het groen van de speeltafel.
///
/// De kaarten worden op een hele vergroting opgebouwd en met Scale2x/Scale3x
/// gladgestreken, net als in het spel. Alleen het verkleinen naar de kleine
/// Mac-maten gebeurt wél met interpolatie: bij zestien bij zestien punten is
/// een scherpe blokjesrand juist lelijk.
///
/// Gebruik: swift run pictogram <map-van-AppIcon.appiconset>
@main
struct Pictogram {
    // Het groen van de achtergrond in het spel.
    static let achtergrond = (r: 18.0 / 255, g: 73.0 / 255, b: 46.0 / 255)

    /// De drie kaarten op het pictogram: aas, heer en boer, elk in een andere
    /// kleur, zodat er rood, zwart en grijs in zit.
    static let kaarten: [(naam: Character, kleur: Int)] = [
        ("A", 3),   // harten aas: het kasteel
        ("B", 2),   // ruiten boer: de hoogste troef
    ]

    static func main() {
        let arg = CommandLine.arguments
        guard arg.count > 1 else {
            FileHandle.standardError.write(Data("gebruik: pictogram <map>\n".utf8))
            exit(1)
        }
        let map = URL(fileURLWithPath: arg[1])

        guard let ios = teken(1024, macStijl: false),
              let mac = teken(1024, macStijl: true) else {
            FileHandle.standardError.write(Data("kon het pictogram niet tekenen\n".utf8))
            exit(1)
        }

        // iOS wil één plaatje van 1024; het systeem maakt de ronde hoeken zelf.
        schrijf(ios, 1024, map.appendingPathComponent("ios-1024.png"))
        schrijf(ios, 1024, map.appendingPathComponent("ios-1024-donker.png"))

        // De Mac wil een hele reeks, en het pictogram heeft daar zijn eigen
        // afgeronde vorm met lucht eromheen.
        for (naam, maat) in [("mac-16", 16), ("mac-16@2x", 32),
                             ("mac-32", 32), ("mac-32@2x", 64),
                             ("mac-128", 128), ("mac-128@2x", 256),
                             ("mac-256", 256), ("mac-256@2x", 512),
                             ("mac-512", 512), ("mac-512@2x", 1024)] {
            schrijf(mac, maat, map.appendingPathComponent("\(naam).png"))
        }

        print("pictogram geschreven in \(map.path)")
    }

    /// Het pictogram op ware grootte.
    static func teken(_ maat: Int, macStijl: Bool) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: maat, height: maat,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        let vlak: CGRect
        if macStijl {
            // De maatvoering die Apple voor Mac-pictogrammen aanhoudt: de vorm
            // vult ongeveer vier vijfde van het vierkant, met ronde hoeken.
            let rand = CGFloat(maat) * 0.098
            vlak = CGRect(x: rand, y: rand,
                          width: CGFloat(maat) - 2 * rand, height: CGFloat(maat) - 2 * rand)
            let vorm = CGPath(roundedRect: vlak,
                              cornerWidth: vlak.width * 0.2237,
                              cornerHeight: vlak.height * 0.2237, transform: nil)
            ctx.addPath(vorm)
            ctx.clip()
        } else {
            vlak = CGRect(x: 0, y: 0, width: CGFloat(maat), height: CGFloat(maat))
        }

        ctx.setFillColor(red: achtergrond.r, green: achtergrond.g, blue: achtergrond.b, alpha: 1)
        ctx.fill(vlak)

        // Drie kaarten naast elkaar, samen gecentreerd in het vlak.
        let schaal = 8
        let set = Kaartenset(schaal: schaal)
        let cw = CGFloat(OrigineleKaarten.breedte * schaal)
        let ch = CGFloat(OrigineleKaarten.hoogte * schaal)
        let stap = cw * 0.62
        let totaal = cw + stap * CGFloat(kaarten.count - 1)

        // Passend maken binnen het vlak, met wat lucht eromheen.
        let past = min(vlak.width * 0.80 / totaal, vlak.height * 0.68 / ch)
        let bx = vlak.midX - totaal * past / 2
        let by = vlak.midY - ch * past / 2

        // De middelste kaart een tikje hoger: dat leest als een waaier in de
        // hand in plaats van als drie kaarten op een rij.
        let hoger: [CGFloat] = [ch * past * 0.04, 0]

        ctx.interpolationQuality = .none
        for (i, k) in kaarten.enumerated() {
            guard let beeld = set.voor(k.naam, k.kleur), let cg = cgImage(beeld) else { continue }
            let vak = CGRect(x: bx + stap * CGFloat(i) * past, y: by + hoger[i],
                             width: cw * past, height: ch * past)

            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -vak.height * 0.02),
                          blur: vak.width * 0.06,
                          color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
            ctx.draw(cg, in: vak)
            ctx.restoreGState()
        }

        return ctx.makeImage()
    }

    /// Wegschrijven op de gevraagde maat; verkleinen mag hier wel vloeien.
    static func schrijf(_ beeld: CGImage, _ maat: Int, _ pad: URL) {
        var uitBeeld = beeld
        if maat != beeld.width {
            if let ctx = CGContext(data: nil, width: maat, height: maat,
                                   bitsPerComponent: 8, bytesPerRow: 0,
                                   space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                ctx.interpolationQuality = .high
                ctx.draw(beeld, in: CGRect(x: 0, y: 0, width: maat, height: maat))
                if let k = ctx.makeImage() { uitBeeld = k }
            }
        }
        guard let uit = CGImageDestinationCreateWithURL(
                pad as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(uit, uitBeeld, nil)
        CGImageDestinationFinalize(uit)
    }

    static func cgImage(_ beeld: Afbeelding) -> CGImage? {
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
