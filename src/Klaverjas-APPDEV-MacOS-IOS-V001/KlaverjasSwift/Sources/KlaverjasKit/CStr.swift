/// Eén teken uit de originele C-code: ASCII, precies één byte, net als `char`.
///
/// Een eigen type in plaats van `Character`, om twee redenen. Het is één byte,
/// zodat de kaartverzamelingen even compact blijven als in C. En het laat zich
/// als letterlijke waarde schrijven — `if naam == "A"` — waardoor de vertaling
/// van de tactiekroutines regel voor regel naast het origineel te leggen is.
public struct Teken: Equatable, Hashable, Sendable,
                     ExpressibleByUnicodeScalarLiteral, CustomStringConvertible {
    public var raw: UInt8

    public init(raw: UInt8) { self.raw = raw }
    public init(unicodeScalarLiteral value: Unicode.Scalar) { self.raw = UInt8(value.value) }

    public static let nul = Teken(raw: 0)

    public var description: String { raw == 0 ? "" : String(UnicodeScalar(raw)) }
}

extension String {
    /// De tekens van een letterlijke reeks als `[Teken]`, voor de rangvolgordes.
    var tekens: [Teken] { unicodeScalars.map { Teken(raw: UInt8($0.value)) } }
}

/// Bootst een C-string na: een tekenrij van vaste omvang met een afsluitende
/// NUL. Het origineel (KJ.C / KJJ.C) leunt zwaar op strlen/strcpy/strcat/strchr
/// over char-arrays, en op het feit dat een array langer is dan de string die
/// erin staat.
///
/// Bewust een class en geen struct. In C# is `char[]` een verwijzing: de code
/// geeft `krtvrij[kleur]` door aan een hulproutine die hem ter plekke aanpast,
/// en verwacht dat de wijziging in de toestand terechtkomt. Een Swift-struct
/// zou daar een kopie van maken en het spel stilletjes anders laten verlopen.
public final class CStr {
    private var buf: [Teken]

    /// Nieuwe lege C-string van gegeven omvang.
    public init(_ size: Int) {
        buf = [Teken](repeating: .nul, count: size)
    }

    public static func new2(_ dim1: Int, _ size: Int) -> [CStr] {
        (0..<dim1).map { _ in CStr(size) }
    }

    public static func new3(_ dim1: Int, _ dim2: Int, _ size: Int) -> [[CStr]] {
        (0..<dim1).map { _ in new2(dim2, size) }
    }

    /// strlen()
    public var len: Int {
        for i in 0..<buf.count where buf[i] == .nul { return i }
        return buf.count
    }

    /// Inhoud tot aan de NUL.
    public var string: String {
        String(decoding: buf.prefix(len).map(\.raw), as: UTF8.self)
    }

    public subscript(i: Int) -> Teken {
        get { buf[i] }
        set { buf[i] = newValue }
    }

    /// strcpy(dst, src)
    public func cpy(_ src: [Teken]) {
        let n = min(src.count, buf.count - 1)
        for i in 0..<n { buf[i] = src[i] }
        buf[n] = .nul
    }

    public func cpy(_ src: CStr) { cpy(src.tekens) }
    public func cpy(_ src: String) { cpy(src.tekens) }

    /// strcat(dst, src)
    public func cat(_ src: [Teken]) {
        let l = len
        let n = min(src.count, buf.count - 1 - l)
        for i in 0..<n { buf[l + i] = src[i] }
        buf[l + n] = .nul
    }

    public func cat(_ src: CStr) { cat(src.tekens) }
    public func cat(_ src: String) { cat(src.tekens) }

    /// Zet 1 teken achteraan (dst[strlen(dst)] = c).
    public func append(_ c: Teken) {
        let l = len
        if l + 1 >= buf.count { return }
        buf[l] = c
        buf[l + 1] = .nul
    }

    public func clear() { buf[0] = .nul }

    /// De gevulde tekens, zonder de afsluitende NUL.
    public var tekens: [Teken] { Array(buf.prefix(len)) }

    /// strpos() uit het origineel: 1-gebaseerde positie van x, of 0 als x er
    /// niet in staat. Let op: de uitkomst wordt in het origineel ook als
    /// jaknikker gebruikt ("staat die kaart erin?").
    public func pos(_ x: Teken) -> Int {
        let n = len
        for i in 0..<n where buf[i] == x { return i + 1 }
        return 0
    }

    /// Dezelfde strpos() op een vaste rangvolgorde.
    public static func pos(_ s: [Teken], _ x: Teken) -> Int {
        for i in 0..<s.count where s[i] == x { return i + 1 }
        return 0
    }
}
