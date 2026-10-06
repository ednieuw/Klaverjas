// swift-tools-version: 6.0
import PackageDescription

// De spellogica staat bewust in een eigen pakket. Het kan niets uit SwiftUI of
// UIKit importeren, en dat is precies de eigenschap die de C#-engine draagbaar
// maakte: Engine/ bevatte geen enkele verwijzing naar het scherm. De compiler
// bewaakt dat hier nu.
//
// KlaverjasKaarten staat er los van: dat bouwt de kaarten per pixel op, ook
// zonder tekenframework, zodat de plaatjes net zo goed te toetsen zijn als de
// engine. Alleen `kaartenblad` gebruikt ImageIO, om er een PNG van te maken.
let package = Package(
    name: "KlaverjasKit",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: [
        .library(name: "KlaverjasKit", targets: ["KlaverjasKit"]),
        .library(name: "KlaverjasKaarten", targets: ["KlaverjasKaarten"]),
        .library(name: "KlaverjasApp", targets: ["KlaverjasApp"]),
        .library(name: "KlaverjasBLE", targets: ["KlaverjasBLE"]),
        .executable(name: "kaartenblad", targets: ["kaartenblad"]),
        .executable(name: "klaverjas-mac", targets: ["klaverjas-mac"]),
        .executable(name: "schermafdruk", targets: ["schermafdruk"]),
        .executable(name: "pictogram", targets: ["pictogram"]),
        .executable(name: "spoor", targets: ["spoor"]),
        .executable(name: "toernooi", targets: ["toernooi"]),
        .executable(name: "film", targets: ["film"]),
    ],
    targets: [
        .target(name: "KlaverjasKit"),
        .target(name: "KlaverjasKaarten"),
        .target(name: "KlaverjasApp", dependencies: ["KlaverjasKit", "KlaverjasKaarten", "KlaverjasBLE"]),
        // CoreBluetooth, geen SwiftUI/UIKit — kan naast KlaverjasApp bestaan
        // zonder dat de engine ooit van bluetooth hoeft te weten. Depends
        // alleen op KlaverjasKit, voor DuoBericht/DuoLijn.
        .target(name: "KlaverjasBLE", dependencies: ["KlaverjasKit"]),
        .executableTarget(name: "kaartenblad", dependencies: ["KlaverjasKaarten"]),
        .executableTarget(name: "klaverjas-mac", dependencies: ["KlaverjasApp"]),
        .executableTarget(name: "schermafdruk", dependencies: ["KlaverjasApp"]),
        .executableTarget(name: "pictogram", dependencies: ["KlaverjasKaarten"]),
        .executableTarget(name: "spoor", dependencies: ["KlaverjasKit"]),
        .executableTarget(name: "toernooi", dependencies: ["KlaverjasKit"]),
        .executableTarget(name: "film", dependencies: ["KlaverjasApp", "KlaverjasKit"]),
        .testTarget(
            name: "KlaverjasKitTests",
            dependencies: ["KlaverjasKit"],
            resources: [
                .copy("Bronnen/spoor-csharp.txt"),
                .copy("Bronnen/spoor-v11.txt"),
            ]
        ),
        .testTarget(
            name: "KlaverjasAppTests",
            dependencies: ["KlaverjasApp", "KlaverjasKit"]
        ),
        .testTarget(
            name: "KlaverjasKaartenTests",
            dependencies: ["KlaverjasKaarten"],
            resources: [.copy("Bronnen/kaarten.png")]
        ),
        .testTarget(
            name: "KlaverjasBLETests",
            dependencies: ["KlaverjasBLE", "KlaverjasKit"]
        ),
    ]
)
