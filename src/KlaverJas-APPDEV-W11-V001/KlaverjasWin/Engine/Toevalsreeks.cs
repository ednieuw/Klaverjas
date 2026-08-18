namespace Klaverjas.Engine;

/// <summary>
/// Een piepkleine, volledig vastgelegde toevalsgenerator. Bewust niet
/// System.Random: die geeft in elke taal en elke versie andere getallen, en dan
/// is een vergelijking tussen de C#- en de Swift-versie onmogelijk. Deze reeks
/// is met een handvol regels in elke taal na te bouwen en levert bij hetzelfde
/// startgetal exact dezelfde spellen op.
///
/// Swift:
///     struct Toevalsreeks {
///         private var stand: UInt32
///         init(_ zaad: UInt32) { stand = zaad == 0 ? 1 : zaad }
///         mutating func volgende(_ grens: Int) -> Int {
///             stand = stand &amp;* 1664525 &amp;+ 1013904223
///             if grens &lt;= 0 { return 0 }
///             return Int((UInt64(stand) &amp;* UInt64(grens)) >> 32)
///         }
///     }
/// </summary>
public sealed class Toevalsreeks
{
    private uint _stand;

    public Toevalsreeks(uint zaad) => _stand = zaad == 0 ? 1 : zaad;

    /// <summary>
    /// Een getal 0 &lt;= uitkomst &lt; grens, en 0 als grens niet positief is —
    /// hetzelfde gedrag als random() van Borland, dat ook met een vermenigvuldiging
    /// schaalde in plaats van met een rest.
    /// </summary>
    public int Volgende(int grens)
    {
        _stand = unchecked(_stand * 1664525u + 1013904223u);
        if (grens <= 0) return 0;
        return (int)(((ulong)_stand * (ulong)grens) >> 32);
    }
}
