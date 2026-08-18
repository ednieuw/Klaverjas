"""Haalt de kaarttekeningen uit KJKRT.C en schrijft ze weg als bronbestand.

Schrijft zowel de C#-versie (KlaverjasWin) als de Swift-versie (KlaverjasSwift);
beide komen uit dezelfde tekeningen, zodat ze niet uit elkaar kunnen lopen.
De paden staan ten opzichte van dit script, zodat het op elke machine werkt.
"""
import os
import re

HIER = os.path.dirname(os.path.abspath(__file__))

SRC = os.path.join(HIER, 'KJKRT.C')
OUT = os.path.join(HIER, 'KlaverjasWin', 'Ui', 'KaartData.cs')
OUT_SWIFT = os.path.join(HIER, 'KlaverjasSwift', 'Sources', 'KlaverjasKaarten', 'KaartData.swift')

BGI = {
    'BLACK': 0, 'BLUE': 1, 'GREEN': 2, 'CYAN': 3, 'RED': 4, 'MAGENTA': 5,
    'BROWN': 6, 'LIGHTGRAY': 7, 'DARKGRAY': 8, 'LIGHTBLUE': 9, 'LIGHTGREEN': 10,
    'LIGHTCYAN': 11, 'LIGHTRED': 12, 'LIGHTMAGENTA': 13, 'YELLOW': 14, 'WHITE': 15,
}

src = open(SRC, encoding='latin-1').read()


def functie(naam):
    m = re.search(r'void\s+%s\s*\((?:void)?\)\s*\{(.*?)\n\}' % naam, src, re.S)
    if not m:
        raise SystemExit('functie %s niet gevonden' % naam)
    return m.group(1)


def plaat(naam):
    body = functie(naam)
    rijen = re.findall(r'strcpy\(inputline\[(\d+)\]\s*,\s*"([^"]*)"\)', body)
    rijen = [s for _, s in sorted(rijen, key=lambda kv: int(kv[0]))]

    # kleurtabel van deze functie; "GREEN+i" is kleurafhankelijk -> -1
    tabel = {}
    for teken, waarde in re.findall(r"case\s+'(.)'\s*:\s*color\s*=\s*([A-Z+ i0-9]+?)\s*;", body):
        waarde = waarde.replace(' ', '')
        tabel[teken] = -1 if waarde == 'GREEN+i' else BGI[waarde]

    onbekend = sorted({c.lower() for r in rijen for c in r} - set(tabel))
    if onbekend:
        print('  let op: %s heeft tekens zonder kleur: %s' % (naam, onbekend))
    print('  %-6s %d rijen x %d, %d kleuren' % (naam, len(rijen), max(map(len, rijen)), len(tabel)))
    return rijen, tabel


def pips():
    body = functie('kleuren')
    uit = {}
    for kleur in ['klaver', 'schoppen', 'ruiten', 'harten']:
        rijen = re.findall(r'strcpy\(%s\[(\d+)\]\s*,\s*"([^"]*)"\)' % kleur, body)
        uit[kleur] = [s for _, s in sorted(rijen, key=lambda kv: int(kv[0]))]
        print('  %-8s %d rijen x %d' % (kleur, len(uit[kleur]), max(map(len, uit[kleur]))))
    return uit


def cs_string_array(rijen, inspring):
    sp = ' ' * inspring
    return '\n'.join('%s"%s",' % (sp, r) for r in rijen)


print('Kaartdata uit KJKRT.C:')
platen = {n: plaat(n) for n in ['aas', 'heer', 'vrouw', 'boer']}
symbolen = pips()

# newline expliciet: het C#-bestand hoort bij de Windows-kant en houdt CRLF,
# zodat het draaien van dit script op een Mac het bestand niet in zijn geheel
# als gewijzigd laat zien.
with open(OUT, 'w', encoding='utf-8', newline='\r\n') as f:
    w = f.write
    w('// Automatisch gegenereerd uit klaverjas/KJKRT.C - niet met de hand aanpassen.\n')
    w('// Bron: de tekenroutines aas(), heer(), vrouw(), boer() en kleuren().\n')
    w('// Elk teken is een pixel; de kleurtabel per plaatkaart komt uit de switch\n')
    w('// in de bijbehorende C-functie. Kleur -1 betekent "GREEN + kleurnummer",\n')
    w('// waardoor die pixels per kaartkleur verschillen, precies als in het origineel.\n\n')
    w('namespace Klaverjas.Ui;\n\n')
    w('internal static class KaartData\n{\n')

    for naam in ['aas', 'heer', 'vrouw', 'boer']:
        rijen, tabel = platen[naam]
        w('    public static readonly string[] %s =\n    {\n' % naam.capitalize())
        w(cs_string_array(rijen, 8))
        w('\n    };\n\n')
        w('    public static readonly (char Teken, int Kleur)[] %sPalet =\n    {\n' % naam.capitalize())
        w('\n'.join("        ('%s', %d)," % (t, k) for t, k in sorted(tabel.items())))
        w('\n    };\n\n')

    for kleur in ['klaver', 'schoppen', 'ruiten', 'harten']:
        w('    public static readonly string[] %s =\n    {\n' % kleur.capitalize())
        w(cs_string_array(symbolen[kleur], 8))
        w('\n    };\n\n')

    w('    public static string[] Plaat(char rang) => rang switch\n    {\n')
    w("        'A' => Aas,\n        'H' => Heer,\n        'V' => Vrouw,\n        'B' => Boer,\n")
    w('        _ => null\n    };\n\n')
    w('    public static (char, int)[] Palet(char rang) => rang switch\n    {\n')
    w("        'A' => AasPalet,\n        'H' => HeerPalet,\n        'V' => VrouwPalet,\n        'B' => BoerPalet,\n")
    w('        _ => null\n    };\n\n')
    w('    public static string[] Symbool(int kleur) => kleur switch\n    {\n')
    w('        0 => Klaver,\n        1 => Schoppen,\n        2 => Ruiten,\n        _ => Harten\n    };\n')
    w('}\n')

print('geschreven: %s' % OUT)


# ------------------------------------------------------------------ Swift

def swift_string_array(rijen, inspring):
    sp = ' ' * inspring
    return '\n'.join('%s"%s",' % (sp, r) for r in rijen)


os.makedirs(os.path.dirname(OUT_SWIFT), exist_ok=True)
with open(OUT_SWIFT, 'w', encoding='utf-8', newline='\n') as f:
    w = f.write
    w('// Automatisch gegenereerd uit Klaverjas/KJKRT.C door genkaarten.py -\n')
    w('// niet met de hand aanpassen.\n')
    w('// Bron: de tekenroutines aas(), heer(), vrouw(), boer() en kleuren().\n')
    w('// Elk teken is een pixel; de kleurtabel per plaatkaart komt uit de switch\n')
    w('// in de bijbehorende C-functie. Kleur -1 betekent "GREEN + kleurnummer",\n')
    w('// waardoor die pixels per kaartkleur verschillen, precies als in het origineel.\n\n')
    w('enum KaartData {\n')

    for naam in ['aas', 'heer', 'vrouw', 'boer']:
        rijen, tabel = platen[naam]
        w('    static let %s: [String] = [\n' % naam)
        w(swift_string_array(rijen, 8))
        w('\n    ]\n\n')
        w('    static let %sPalet: [(teken: Character, kleur: Int)] = [\n' % naam)
        w('\n'.join('        ("%s", %d),' % (t, k) for t, k in sorted(tabel.items())))
        w('\n    ]\n\n')

    for kleur in ['klaver', 'schoppen', 'ruiten', 'harten']:
        w('    static let %s: [String] = [\n' % kleur)
        w(swift_string_array(symbolen[kleur], 8))
        w('\n    ]\n\n')

    w('    static func plaat(_ rang: Character) -> [String]? {\n')
    w('        switch rang {\n')
    w('        case "A": return aas\n        case "H": return heer\n')
    w('        case "V": return vrouw\n        case "B": return boer\n')
    w('        default: return nil\n        }\n    }\n\n')

    w('    static func palet(_ rang: Character) -> [(teken: Character, kleur: Int)]? {\n')
    w('        switch rang {\n')
    w('        case "A": return aasPalet\n        case "H": return heerPalet\n')
    w('        case "V": return vrouwPalet\n        case "B": return boerPalet\n')
    w('        default: return nil\n        }\n    }\n\n')

    w('    static func symbool(_ kleur: Int) -> [String] {\n')
    w('        switch kleur {\n')
    w('        case 0: return klaver\n        case 1: return schoppen\n')
    w('        case 2: return ruiten\n        default: return harten\n')
    w('        }\n    }\n')
    w('}\n')

print('geschreven: %s' % OUT_SWIFT)
