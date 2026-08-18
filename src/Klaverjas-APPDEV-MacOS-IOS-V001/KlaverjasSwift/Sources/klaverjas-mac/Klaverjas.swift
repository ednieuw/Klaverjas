import AppKit
import SwiftUI
import KlaverjasApp
import KlaverjasKit

/// Een minimale gastheer om het speelscherm op de Mac te kunnen draaien met
/// `swift run klaverjas-mac`. Voor de App Store komt hier een echt
/// app-doelwit voor in de plaats; de vensterinhoud blijft dezelfde View, want
/// die staat in KlaverjasApp.
@main
struct KlaverjasMac {
    static func main() {
        // De taal van het apparaat volgen; met de schakelaar rechts kan het om.
        // Met /nl of /en op de opdrachtregel kies je hem alsnog zelf, zoals
        // Klaverjas.exe /en op Windows deed.
        let vlaggen = CommandLine.arguments.dropFirst().map { $0.lowercased() }
        if vlaggen.contains("/en") || vlaggen.contains("--en") { Taal.engels = true }
        else if vlaggen.contains("/nl") || vlaggen.contains("--nl") { Taal.engels = false }
        else { Taal.kiesStandaardtaal() }

        let app = NSApplication.shared
        // Een programma dat vanaf de opdrachtregel start heeft geen bundel, en
        // komt zonder dit niet naar voren.
        app.setActivationPolicy(.regular)

        let venster = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1300, height: 950),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        venster.title = "Klaverjas"
        venster.contentView = NSHostingView(rootView: SpelScherm())
        venster.center()
        venster.makeKeyAndOrderFront(nil)

        let afsluiter = Afsluiter()
        app.delegate = afsluiter

        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

final class Afsluiter: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
