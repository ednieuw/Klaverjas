import Foundation

/// De versie zoals die in Xcode staat ("Marketing Version",
/// `CFBundleShortVersionString`) — dezelfde waarde die `VerbindScherm` als
/// appversie in de BLE-begroeting meestuurt, hier ook voor het optieblad.
public enum AppVersie {
    public static var huidig: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }
}
