@preconcurrency import CoreBluetooth

/// De UUID's van de eigen, UART-achtige bluetooth-dienst waarmee twee
/// toestellen klaverjas-berichten uitwisselen (B3/B7 uit het bluetooth-plan):
/// één kant schrijft, de andere leest — in beide richtingen tegelijk, via
/// twee aparte karakteristieken, precies zoals een seriële poort dat zou doen.
///
/// Vast gekozen en nooit meer te wijzigen zodra er toestellen mee spelen: een
/// nieuw UUID zou een oudere versie van de app niet meer herkennen als
/// dezelfde dienst.
public enum UartDienst {
    /// De dienst zelf. Hierop wordt geadverteerd en gescand.
    public static let dienst = CBUUID(string: "263825A9-5883-47C6-ACF0-44C9DC3E0525")

    /// Van de centrale kant náár de kant die zich openstelt: de centrale kant
    /// schrijft hier zijn regels naartoe.
    public static let naarPerifeer = CBUUID(string: "463B3B14-262E-4E91-8C1C-49C1B84065E2")

    /// Van de kant die zich openstelt náár de centrale kant: die notificeert
    /// hier zijn regels op.
    public static let naarCentraal = CBUUID(string: "AB6D4A13-5352-4A64-A87D-943378C397B2")
}
