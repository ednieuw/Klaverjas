package nl.edsoft.klaverjas.ble

import java.util.UUID

/**
 * De UUID's van de eigen, UART-achtige bluetooth-dienst waarmee twee toestellen klaverjas-berichten
 * uitwisselen. Gelijk aan die van de iPhone/iPad/Mac-app en nooit meer te wijzigen: een ander UUID
 * wordt door een oudere versie niet als dezelfde dienst herkend.
 */
object UartDienst {
    val dienst: UUID = UUID.fromString("263825A9-5883-47C6-ACF0-44C9DC3E0525")

    /** Van de centrale kant naar de kant die zich openstelt: de centrale schrijft hier zijn regels naartoe. */
    val naarPerifeer: UUID = UUID.fromString("463B3B14-262E-4E91-8C1C-49C1B84065E2")

    /** Van de kant die zich openstelt naar de centrale kant: die notificeert hier zijn regels op. */
    val naarCentraal: UUID = UUID.fromString("AB6D4A13-5352-4A64-A87D-943378C397B2")

    /** Client Characteristic Configuration Descriptor: hiermee zet de centrale notificaties aan. */
    val cccd: UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
}
