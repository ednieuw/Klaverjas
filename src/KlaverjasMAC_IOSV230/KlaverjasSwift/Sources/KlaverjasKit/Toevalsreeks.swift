/// Een piepkleine, volledig vastgelegde toevalsgenerator. Bewust niet de
/// generator van het systeem: die geeft in elke taal en elke versie andere
/// getallen, en dan is een vergelijking met de C#-versie onmogelijk. Deze reeks
/// levert bij hetzelfde startgetal exact dezelfde spellen op.
///
/// Letterlijk overgenomen uit Engine/Toevalsreeks.cs, waar deze Swift-versie al
/// als commentaar klaarstond.
public struct Toevalsreeks: Sendable {
    private var stand: UInt32

    public init(_ zaad: UInt32) { stand = zaad == 0 ? 1 : zaad }

    /// Een getal 0 <= uitkomst < grens, en 0 als grens niet positief is —
    /// hetzelfde gedrag als random() van Borland, dat ook met een
    /// vermenigvuldiging schaalde in plaats van met een rest.
    public mutating func volgende(_ grens: Int) -> Int {
        stand = stand &* 1664525 &+ 1013904223
        if grens <= 0 { return 0 }
        return Int((UInt64(stand) &* UInt64(grens)) >> 32)
    }
}
