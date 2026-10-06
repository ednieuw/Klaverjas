namespace Klaverjas.Ble;

/// <summary>
/// De drie UUID's van de bluetooth-dienst waarmee de Mac/iOS-app en de
/// Windows-app met elkaar praten. Vast, en nooit te wijzigen: een ander UUID
/// zou een al werkende Mac-versie niet meer herkennen.
///
/// Bron: <c>KlaverjasBLE/UartDienst.swift</c> op de Mac, overgenomen zoals
/// beschreven in BLUETOOTH-VOOR-WINDOWS.md.
/// </summary>
public static class UartDienst
{
    /// <summary>De GATT-dienst zelf. Windows scant hierop als gast.</summary>
    public static readonly Guid Dienst = Guid.Parse("263825A9-5883-47C6-ACF0-44C9DC3E0525");

    /// <summary>Windows schrijft hierin (richting de gastheer).</summary>
    public static readonly Guid NaarPerifeer = Guid.Parse("463B3B14-262E-4E91-8C1C-49C1B84065E2");

    /// <summary>Windows abonneert zich hierop (notificaties van de gastheer).</summary>
    public static readonly Guid NaarCentraal = Guid.Parse("AB6D4A13-5352-4A64-A87D-943378C397B2");
}
