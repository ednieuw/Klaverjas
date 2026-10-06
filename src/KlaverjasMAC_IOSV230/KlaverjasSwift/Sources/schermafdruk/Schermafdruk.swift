import AppKit
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import KlaverjasApp
import KlaverjasKit

/// Maakt een plaatje van het speelscherm zonder dat er een venster aan te pas
/// komt: laat de computer een paar zetten doen, vang een momentopname en teken
/// die met ImageRenderer weg.
///
/// Gebruik: swift run schermafdruk [pad] [aantal zetten] [breedte] [hoogte]
@main
struct Schermafdruk {
    static func main() async {
        let arg = CommandLine.arguments
        let pad = arg.count > 1 ? arg[1] : "scherm.png"
        let zetten = arg.count > 2 ? (Int(arg[2]) ?? 6) : 6
        let breed = arg.count > 3 ? (Double(arg[3]) ?? 1300) : 1300
        let hoog = arg.count > 4 ? (Double(arg[4]) ?? 950) : 950
        let wat = arg.count > 5 ? arg[5] : "spel"   // spel | stat | einde | opties | troef | snel | samen
        // Bewaard in een losse `let`, niet steeds opnieuw uit `Taal.engels`
        // gelezen: `SpelModel()` hieronder leest bij het opstarten de echt
        // opgeslagen taalvoorkeur van dít apparaat (`Bewaarplaats`) en zet
        // `Taal.engels` daarmee stilletjes terug — ongeacht wat hier is
        // meegegeven. Schermen die hun tekst pas live bij het tekenen ophalen
        // (`VerbindScherm`, `OptieScherm`, `StatistiekScherm`,
        // `HandleidingScherm`) lazen daardoor de verkeerde taal, ook al stond
        // `--en` erbij.
        let taalEngels = (arg.count > 6 && arg[6].lowercased() == "en")
        Taal.engels = taalEngels
        // De schermafdrukken voor de App Store moeten op de pixel kloppen: een
        // iPhone rekent op drie, een iPad en de Mac op twee.
        let schaal = arg.count > 7 ? (Double(arg[7]) ?? 2) : 2
        // "tablet" of "telefoon" tekent de indeling van een aanraakscherm, ook
        // als dit een Mac is. Zonder dat toont een iPad-schermafdruk de
        // Mac-indeling, en dat is niet wat er op het toestel staat.
        let aanraak = arg.count > 8 ? (arg[8] != "mac") : SpelScherm.aanraakscherm

        let vanger = Vanger(nodig: zetten)
        if wat == "einde" { await vanger.letOpEinde() }
        if wat == "troef" { await vanger.letOpTroef() }
        // Voor de troefvraag moet de mens aan zet zijn; anders kiest de
        // computer zelf en komt de vraag nooit in beeld.
        let demo = (wat != "troef")
        let spel = KjSpel(ui: vanger, zaad: wat == "troef" ? 3 : 4,
                          instellingen: {
                              // Voor de statistiek Noord laten doorrekenen, zodat
                              // tactiek 70 in de lijst komt te staan.
                              Instellingen(demo: demo, openKaart: false,
                                           zoektNoord: wat == "stat")
                          })

        // De speelloop draait tot de vanger genoeg gezien heeft.
        let taak = Task.detached { await spel.loop() }
        let beeld = await vanger.wacht()
        taak.cancel()

        await MainActor.run {
            let model = SpelModel()
            // Niet `Taal.engels` hier teruglezen: `SpelModel()` (net
            // hierboven) heeft die intussen al overschreven met de opgeslagen
            // voorkeur van dit apparaat. `model.engels`'s `didSet` zet
            // `Taal.engels` als bijvangst weer goed.
            model.engels = taalEngels
            model.toon(beeld)
            model.zetTekst(beeld.melding.isEmpty ? beeld.status : beeld.melding)
            if wat == "troef" { model.zetModus(.kiesTroef) }
            // Aan het eind van een spel staat het programma te wachten tot je
            // verder wilt. Zonder dit toont de afdruk "Spel uit" in plaats van
            // de aansporing, en dat is niet wat er op het toestel staat.
            if wat == "einde" { model.zetModus(.verder) }
            if wat == "snel" {
                model.zoektNoord = true
                model.snel = true
            }

            let renderer: ImageRenderer<AnyView>
            if wat == "opties" || wat == "stat" || wat == "regels" || wat == "samen" {
                // Zoals het in het programma staat: het blad over het
                // speelscherm heen, en het geheel op de maat van het apparaat.
                // Zo is elke schermafdruk precies even groot, wat de App Store
                // ook eist.
                let blad = AnyView(
                    Group {
                        if wat == "regels" {
                            HandleidingScherm(rolt: false) {}
                                .frame(maxWidth: min(breed - 24, 560), maxHeight: hoog - 120,
                                       alignment: .top)
                                .clipped()
                        } else if wat == "stat" {
                            StatistiekScherm(stat: beeld.statistiek, rolt: false, maxTactieken: 10, sluit: {})
                                .frame(maxWidth: min(breed - 24, 560), maxHeight: hoog - 120,
                                       alignment: .top)
                                .clipped()
                        } else if wat == "samen" {
                            // Geen lijst om af te snijden: dit is een klein,
                            // vast dialoogvenster — net als op het echte
                            // scherm gewoon in het midden, op eigen maat.
                            // `.fixedSize()` is nodig omdat de `Spacer` erin
                            // anders de volle canvashoogte opeist: in het
                            // echte programma begrenst het systeemvenster
                            // van `.sheet(...)` die hoogte, hier niet.
                            VerbindScherm(model: model, sluit: {})
                                .fixedSize()
                        } else {
                            OptieScherm(model: model, beelden: Kaartbeelden(),
                                        displayScale: schaal, rolt: false, sluit: {}, toonSpelregels: {})
                                .frame(maxWidth: min(breed - 24, 560), maxHeight: hoog - 120,
                                       alignment: .top)
                                .clipped()
                        }
                    }
                )
                renderer = ImageRenderer(content: AnyView(
                    ZStack {
                        SpelScherm(model: model, aanraak: aanraak).frame(width: breed, height: hoog)
                        Color.black.opacity(0.45)
                        blad
                    }
                    .frame(width: breed, height: hoog)
                ))
            } else {
                renderer = ImageRenderer(content: AnyView(
                    SpelScherm(model: model, aanraak: aanraak).frame(width: breed, height: hoog)))
            }
            renderer.scale = schaal

            guard let plaatje = renderer.cgImage else {
                FileHandle.standardError.write(Data("kon niet tekenen\n".utf8))
                exit(1)
            }
            guard let uit = CGImageDestinationCreateWithURL(
                    URL(fileURLWithPath: pad) as CFURL,
                    UTType.png.identifier as CFString, 1, nil) else {
                FileHandle.standardError.write(Data("kon \(pad) niet openen\n".utf8))
                exit(1)
            }
            CGImageDestinationAddImage(uit, plaatje, nil)
            guard CGImageDestinationFinalize(uit) else {
                FileHandle.standardError.write(Data("kon \(pad) niet wegschrijven\n".utf8))
                exit(1)
            }
            print("geschreven: \(pad)  \(Int(breed)) x \(Int(hoog))")
            exit(0)
        }
    }
}

/// Vangt de zoveelste momentopname op en laat de wachter dan door.
final actor Vanger: KjUi {
    private let nodig: Int
    private var gezien = 0
    private var laatste = SpelView()
    private var wachter: CheckedContinuation<SpelView, Never>?

    init(nodig: Int) { self.nodig = nodig }

    func wacht() async -> SpelView {
        await withCheckedContinuation { c in
            if gezien >= nodig { c.resume(returning: laatste) } else { wachter = c }
        }
    }

    /// true = wachten op het einde van een spel in plaats van op een aantal zetten.
    private var wachtOpEinde = false
    func letOpEinde() { wachtOpEinde = true }
    private var wachtOpTroef = false
    func letOpTroef() { wachtOpTroef = true }

    func toon(_ view: SpelView) async {
        laatste = view
        gezien += 1
        if !wachtOpEinde, gezien >= nodig, let c = wachter {
            wachter = nil
            c.resume(returning: view)
        }
    }

    func kiesKaart(_ view: SpelView) async -> (naam: Teken, kleur: Int) { (naam: .nul, kleur: 0) }
    func kiesTroef(_ view: SpelView) async -> Int {
        if wachtOpTroef, let c = wachter {
            laatste = view
            wachter = nil
            c.resume(returning: view)
        }
        return 0
    }
    func verder(_ view: SpelView, _ tekst: String) async {
        laatste = view
        laatste.melding = tekst
        if wachtOpEinde, view.spelUit, let c = wachter {
            wachter = nil
            c.resume(returning: laatste)
        }
    }
}
