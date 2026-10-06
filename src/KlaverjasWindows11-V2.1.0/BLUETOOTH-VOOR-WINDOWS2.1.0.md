# Klaverjas: samen spelen tussen Windows en Mac/iOS over bluetooth

Dit bestand is geschreven om op de Windows-machine gelezen te worden, door
iemand — of iets — dat het samenspel-protocol niet zelf heeft ontworpen. Het
beschrijft wat de C#-app (`KlaverjasWin/`) moet bouwen om via bluetooth een
partij te kunnen spelen tegen de Swift-app op een Mac of iPhone/iPad, met
exact hetzelfde protocol als die kant al gebruikt.

Bijgewerkt: 15 september 2026, tegen de stand van
`KlaverjasMAC_IOS/KlaverjasSwift/Sources/KlaverjasKit` en `.../KlaverjasBLE`
op de Mac. Alles hieronder is ofwel rechtstreeks uit die broncode overgenomen,
ofwel met een eigen proefje op deze Mac geverifieerd (staat er telkens bij) —
niets is geraden. Controleer bij twijfel die bronbestanden; dit document kan
achterlopen als de Mac-kant intussen is doorontwikkeld.

**Let op waar dat is.** Alle bestandsverwijzingen hieronder ("op de Mac",
`KlaverjasKit/...`, `KlaverjasBLE/...`) zijn ten opzichte van
`KlaverjasMAC_IOS/KlaverjasSwift/Sources/` — de actief ontwikkelde kopie,
naast deze map. **Niet** de map `KlaverjasSwift/` die hier vlak naast dit
bestand staat: die is een oudere momentopname van vóór het samenspel-werk en
heeft nog geen `KlaverjasBLE`-map en geen van de `Duo*`-bestanden. Kopieer
dus, als je code wil overnemen of naslaan, uit `KlaverjasMAC_IOS/`, niet uit
de map hiernaast.

---

## Begin hier

Doe dit in deze volgorde. Elke stap is zonder bluetooth en zonder de andere
machine te toetsen — pas als stap 1 en 2 werken, is er iets om via de radio
heen en weer te sturen.

1. **Lees "De cruciale valkuil" hieronder eerst.** Dat ene punt (welk
   compressieformaat) kost de meeste tijd om zelf te ontdekken en is hier al
   voor je uitgezocht en getoetst.
2. Bouw de coderingslaag (JSON → deflate → base64, `Teken` als `{"raw": N}`)
   en toets hem tegen de drie kant-en-klare voorbeelden verderop in dit
   document. Geen bluetooth nodig, geen Mac nodig — alleen of jouw C#-code
   dezelfde bytes teruggeeft.
3. Bouw de regelbuffer (opknippen/aan elkaar plakken op `\n`) en toets die met
   een paar losse byte-arrays, ook zonder radio.
4. Bouw **alleen de gast-kant** (scannen/verbinden, niet adverteren) — zie
   "Welke kant bouwt Windows eerst" hieronder voor waarom.
5. Pas dan: twee echte toestellen. Begin met de Mac in demo-stand (het
   spel speelt zichzelf), zodat je alleen hoeft te kijken of er `STAND`-regels
   binnenkomen en of ze goed tekenen — nog niet of een tik terugkomt.
6. Als dat staat: een mens laten spelen op de Windows-kant, en de teruggestuurde
   `ZET` op de Mac laten verschijnen.

---

## De architectuur in het kort

Twee toestellen spelen **niet** allebei hun eigen motor met hetzelfde zaad
(dat was de eerste opzet en is verlaten — zie de aantekening bovenaan
`KlaverjasKit/DuoBericht.swift` en `GastheerUi.swift` als je wil weten
waarom). In plaats daarvan:

* Wie zich **openstelt** ("gastheer") draait de enige echte motor
  (`KjSpel`/`KjEngine`), altijd als Zuid. Na elke wijziging stuurt hij de
  **hele momentopname** naar de gast — niet losse zetten.
* Wie **zoekt** ("gast") draait geen motor. Hij toont alleen wat binnenkomt,
  altijd als Noord, en stuurt zijn eigen keuze (troef of kaart) terug als de
  momentopname zegt dat hij aan zet is.
* Gaat er een bericht verloren of komt het beschadigd aan: het volgende
  bericht is een complete, zelfstandige momentopname en herstelt vanzelf
  alles. Geen nummering, geen "stuur nummer zoveel opnieuw", geen
  controlesom nodig.

**Belangrijk gevolg:** de twee motoren (Swift-`KjEngine` en C#-`KjEngine`)
hoeven voor het samenspel **niet** perfect gelijk te lopen. Tijdens een
gedeelde partij draait maar één motor — die van de gastheer. De andere kant is
puur scherm en invoer. De ijkproeven tussen de twee engines
(`WIJZIGINGEN-Swift.md`) blijven belangrijk voor het *eigen* spel op elk
toestel, maar zijn geen voorwaarde om samen te kunnen spelen.

### Welke kant bouwt Windows eerst

Op de Mac/iPhone is "openstellen" een bluetooth **peripheral**
(`CBPeripheralManager`: adverteert, wacht op een abonnee) en "zoeken" een
**central** (`CBCentralManager`: scant, verbindt). Beide bestaan al en zijn
symmetrisch.

Op Windows is dat niet symmetrisch qua risico. De central-rol
(`Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisementWatcher`,
`BluetoothLEDevice`, `GattDeviceService`) is een oude, stabiele WinRT-API die
al sinds Windows 10 bestaat en op vrijwel elke adapter werkt. De
peripheral-rol (`GattServiceProvider`, zelf adverteren als GATT-server) hangt
af van of de adapter/driver dat ondersteunt, en is in de praktijk minder
betrouwbaar — precies het soort onbewezen aanname waar dit hele
BLE-onderdeel al eerder tegenaan liep (zie de aantekeningen "Onbewezen zonder
hardware" in `BlePerifeer.swift`/`BleCentraal.swift` op de Mac).

**Advies: bouw eerst alleen de gast-kant (central/zoeken) op Windows.** Dat
betekent:

* De Mac of iPhone stelt zich altijd open ("Samen spelen" → openstellen).
* Windows zoekt altijd.
* Windows hoeft nooit een volledige `SpelView` te **coderen** (dat doet
  alleen de gastheer) — alleen te **decoderen**, en zelf alleen het veel
  kleinere `GastZet`-bericht te coderen. Dat scheelt een hoop: geen
  volwaardige C#-kopie van `SpelView` met alle statistiekvelden nodig, zie
  verderop.
* Windows-als-gastheer (zelf adverteren, `GattServiceProvider`) is een
  goede **stap 2**, geen blokkade voor stap 1.

Dit is een bewuste, tijdelijke beperking, geen technische onmogelijkheid: er
is niets in het protocol dat een kant aan een rol bindt. Het is puur "wat is
het eerst betrouwbaar aan de praat te krijgen op Windows."

---

## De cruciale valkuil: het compressieformaat

`DuoStand.codeer` (Mac-kant, `KlaverjasKit/DuoStand.swift`) doet: JSON →
comprimeren met Apple's `Compression`-framework, `COMPRESSION_ZLIB` → base64.
**De naam is misleidend: dit is géén zlib-stream (RFC 1950, met 2-byte
header en Adler32-staart).** Het is kale, rauwe **DEFLATE** (RFC 1951),
zonder header en zonder staart.

Dit is geen aanname — het is zojuist op deze Mac getoetst: een tekst door
`compression_encode_buffer(..., COMPRESSION_ZLIB)` gehaald geeft als eerste
bytes `05 c1 8b 09 00 20` — geen `0x78`-header, dus geen echte zlib-stream
(die begint altijd met `0x78`).

En bevestigd door de output terug te lezen met Python's `zlib`:

```
zlib.decompress(data, wbits=-15)   → werkt   (−15 = rauwe deflate, RFC 1951)
zlib.decompress(data, wbits=15)    → FAALT   ("incorrect header check", = echte zlib)
zlib.decompress(data, wbits=47)    → FAALT   (= zlib- of gzip-header verwacht)
```

**Op .NET is dat exact `System.IO.Compression.DeflateStream` — niet
`ZLibStream` en niet `GZipStream`.** Microsoft's eigen documentatie
bevestigt hetzelfde: ".NET compression libraries support at the core only
[...] Deflate, specified by RFC 1951 [...] DeflateStream built in to .NET
does not work with zlib streams containing a header and trailer (RFC1950)."
Zie [DeflateStream Class](https://learn.microsoft.com/en-us/dotnet/api/system.io.compression.deflatestream)
en de toelichting in [Zlib compression in .NET Core](https://benfoster.io/blog/zlib-compression-net-core/).

```csharp
// Decoderen (een STAND van de gastheer lezen):
byte[] gecomprimeerd = Convert.FromBase64String(tekst);
using var bron = new MemoryStream(gecomprimeerd);
using var deflate = new DeflateStream(bron, CompressionMode.Decompress);
using var uit = new MemoryStream();
deflate.CopyTo(uit);
string json = Encoding.UTF8.GetString(uit.ToArray());

// Coderen (een ZET terugsturen):
using var uit2 = new MemoryStream();
using (var deflate2 = new DeflateStream(uit2, CompressionLevel.Optimal, leaveOpen: true))
    deflate2.Write(Encoding.UTF8.GetBytes(json));
string base64 = Convert.ToBase64String(uit2.ToArray());
```

**Toets dit met de drie voorbeelden verderop (sectie "Drie geverifieerde
voorbeelden") vóór je één regel bluetooth-code schrijft.** Lukt het
decoderen van de troefkeuze en de kaartkeuze daar niet met `DeflateStream`,
dan zit de fout in deze stap en nergens anders.

---

## `Teken`: een kaartnaam is een object, geen tekst

Dit is de tweede valkuil, en minstens zo makkelijk te missen. Een kaartrang
(`KaartView.naam`, `SlagView.naam`, `GastZet.kaart`) is op de Mac geen
Swift-`String` en geen los teken, maar een eigen type:

```swift
public struct Teken: Codable {
    public var raw: UInt8   // ASCII-waarde van het rangteken
}
```

Omdat dit een struct met één veld is, codeert Swift's standaard-`Codable`
hem als een **object met dat ene veld erin** — niet als kale tekst of een
kaal getal. Ook getoetst op deze Mac:

```
naam: Teken(raw: 65)  →  JSON: {"raw":65}
```

Dus een kaart in `handZuid` ziet er in de JSON zo uit (met willekeurige
sleutelvolgorde — Swift's encoder garandeert geen vaste volgorde):

```json
{"index":0,"naam":{"raw":65},"kleur":3,"open":true,"klikbaar":false,"plek":0}
```

De ASCII-waarden die voorkomen (uit `KJ.C`/`KjState.swift`):

| rang | teken | ASCII (`raw`) |
|---|---|---|
| aas | `A` | 65 |
| heer | `H` | 72 |
| vrouw | `V` | 86 |
| boer | `B` | 66 |
| tien | `T` | 84 |
| negen | `9` | 57 |
| acht | `8` | 56 |
| zeven | `7` | 55 |
| (leeg/geen kaart) | — | 0 |

En de kleur (een gewoon `Int`, geen object):

| kleur | waarde |
|---|---|
| klaver | 0 |
| schoppen | 1 |
| ruiten | 2 |
| harten | 3 |

Dit zijn dezelfde nummers als de bestaande C#-engine al gebruikt
(`Ui/OrigineleKaarten.cs`/`KaartData.cs`), dus daar hoeft niets nieuws
bedacht te worden — alleen de JSON-vorm eromheen is nieuw.

**In C#:** schrijf een eigen `JsonConverter<Teken>` (`System.Text.Json`) die
een object met sleutel `"raw"` leest en schrijft, geen kaal getal of tekst.

---

## Drie geverifieerde voorbeelden

Precies zo gegenereerd met de echte Mac-code (`DuoStand.codeer`, niet
nagebouwd) — dit zijn geen verzonnen bytes. Gebruik ze als toets voordat er
enige bluetooth bij komt.

**Troefkeuze** (`GastZet(troef: 3)`, harten):

```
base64: q1YqKcpPTVOyMq4FAA==
json na decoderen: {"troef":3}
```

**Kaartkeuze** (`GastZet(kaart: Teken(raw: 84), kleur: 3)`, tien harten):

```
base64: q1bKzkktLVKyMtZRyk5MLCpRsqpWKkosV7KyMKmtBQA=
json na decoderen: {"kleur":3,"kaart":{"raw":84}}
```

Let op: `troef`/`kaart`/`kleur` die niet gezet zijn, staan **helemaal niet**
in de JSON (geen `"troef":null`, gewoon afwezig). Bij het decoderen aan de
Swift-kant maakt dat niets uit — zowel een ontbrekende sleutel als een
expliciete `null` wordt gelezen als "niet aanwezig". C# mag dus zelf kiezen:
weglaten of `null` meesturen, allebei werkt.

**Een volledige stand** (een verzonnen, kleine `SpelView`: troef harten,
Zuid heeft 20 punten en 20 roem al binnen, twee kaarten in `handZuid`):

```
base64: zVPLTsMwEPyVaM8+JIUilF9AKocKDq04LGRb3DhO5DiAqPrv7NqmDhXcUaWo3sfszD6O4HuPaFZ97xqoSwWNfnn16bl9UoBoN+ShXigYDe6jsdMHe4eWzZUCjzsys4zRo9ej19RCfQTvetq1iM6TZX+pSgkZyJjZm2O6YbLzEIv+/D9yzNnTQE5ScgC+xHry/s8/5hp6cSF2YJM+zA16pl46eJHgaU82B51iCzeT5hksypQD9ZWCV7RNtG+PoG1DH2HMFrGT8Th8h/pmyQCtocmFlH6QSt5NxESMtLUUt26fmTrUOzQjndQZrbpAu73OaNVvaNUcTRyntAJ5C2VBHkReKKbgs6dWxMZn+J73Iqqrlou0vEkt+996p/e0Pq/tO7L7flgzOLlvTj2rcClnBq9+lpI2znY89PfRoSAnirL20wg1bPg4imeW7yFPNksL55I5xsHmyQU535X+5iO3uHLhLDsyjbZMBERpURVvnF0IoioWZZE2J3HusKU4l2hPlaoyU039PH0B
```

Dit decodeert tot een volledige `SpelView`-JSON met alle velden uit de
volgende sectie (inclusief het lege `statistiek`-blok — laat dat gewoon
staan als je alleen de velden hieronder gebruikt, `System.Text.Json`
negeert onbekende sleutels vanzelf).

Als je eigen C#-decodering hiervan niet exact `puntenZuid: 20` teruggeeft,
zit de fout in de coderingslaag, niet in wat er daarna mee gebeurt.

---

## Wat er precies in een `STAND` zit — en wat Windows ervan nodig heeft

`SpelView` (Mac-bron: `KlaverjasKit/SpelView.swift`) heeft veel velden, ook
voor het statistiekenscherm (`statistiek`, tientallen tactiektellers) en voor
of de computer aan het doorrekenen is (`zoekt`). **Die hoeft Windows niet te
kennen.** `System.Text.Json` negeert onbekende JSON-sleutels vanzelf als je
ze niet in je C#-klasse zet — precies hetzelfde patroon dat de Swift-gast
zelf ook volgt (`SpelModel.pasGastStandToe` gebruikt ook maar een handvol
van de velden die binnenkomen).

Velden die de gast-kant wél nodig heeft, met hun JSON-sleutel (exact zo
gespeld, hoofdlettergevoelig) en betekenis:

| sleutel | type | betekenis |
|---|---|---|
| `handZuid`, `handNoord` | `KaartView[]` | de hand van elke kant |
| `tafelZuid`, `tafelNoord` | `KaartView[]` | open tafelkaarten per kant (één per gewonnen slag, opgestapeld) |
| `dichtZuid`, `dichtNoord` | `KaartView[]` | nog dichte kaarten eronder |
| `onderZuid`, `onderNoord` | `bool[4]` | per tafelplek 0..3: ligt daar nog een dichte kaart onder? |
| `slag` | `SlagView[]` | de lopende slag (het groene speelveld) |
| `vorigeSlag` | `SlagView[]` | de vorige slag, voor "nog even nakijken" |
| `troef` | `int` | 0..3, of 999 = nog onbekend |
| `troefmaker` | `int` | 0 = nog onbekend, 1 = Zuid, 2 = Noord |
| `slagNr` | `int` | 0..7 |
| `aanZet` | `int` | Pos-code, zie tabel hieronder |
| `wachtOpSpeler` | `bool` | iemand moet een kaart leggen |
| `troefVraag` | `bool` | iemand moet troef kiezen |
| `wachtOpVerder` | `bool` | een slag is net afgelopen; wie dan ook mag "verder" tikken — niet gebonden aan `benIkAanZet`, zie `GastZet` hieronder |
| `puntenZuid`, `puntenNoord` | `int` | kaartpunten deze partij |
| `roemZuid`, `roemNoord` | `int` | roem deze partij |
| `totaalZuid`, `totaalNoord` | `long` | partijtotaal (Swift: `Int64`) |
| `partijenZuid`, `partijenNoord` | `int` | gewonnen spellen |
| `mijnKant` | `int` | voor de gast altijd `2` (Noord) — lees hem toch uit de data, niet hardcoden |
| `status` | `string` | korte statustekst, taalafhankelijk, puur voor tonen |
| `melding` | `string` | langere melding ("Slag 3 voor Zuid, 20 punten"), puur voor tonen |
| `spelUit` | `bool` | zodra waar: punten/roem hierboven zijn de eindstand van dit spel |

`KaartView`: `index`(`int`), `naam`(`Teken`, dus `{"raw": N}`), `kleur`(`int`
0..3), `open`(`bool`, `false` = achterkant tonen), `klikbaar`(`bool`, alleen
relevant voor eigen invoer-highlighting), `plek`(`int`).

`SlagView`: `kleur`(`int`), `naam`(`Teken`), `speler`(`int`, een Pos-code),
`tactiek`(`int`, alleen interessant voor de statistiek — mag genegeerd).

**`status`/`melding` zijn platte, taalafhankelijke tekst, geen machinecode.**
Niet proberen te parsen; gewoon tonen zoals hij binnenkomt. Windows heeft al
zijn eigen `Taal.cs` voor de eigen knoppen en menu's; deze twee velden komen
kant-en-klaar van de gastheer, in de taal die dáár ingesteld staat.

### Pos-codes (`aanZet`, `SlagView.speler`)

Uit `KjState.swift` (`enum Pos`), ongewijzigd sinds het C-origineel:

| naam | waarde | betekenis |
|---|---|---|
| `handZuid` | 1 | hand van Zuid |
| `handNoord` | 2 | hand van Noord |
| `tafelZuid` | 3 | tafel van Zuid |
| `tafelNoord` | 4 | tafel van Noord |
| `gespeeld` | 5 | al gespeeld |

### Wat Windows zelf moet uitrekenen (staat niet in de JSON)

`benIkAanZet`, `mijnHand`, `mijnPunten`, `troefmakerRelatief` en dergelijke
zijn op de Mac **berekende** eigenschappen van `SpelView`, geen opgeslagen
velden — die staan dus niet in de JSON en moeten aan de Windows-kant met
dezelfde formule opnieuw berekend worden. Voor de gast (`mijnKant` is altijd
`2`):

```csharp
bool ikBenZuid = mijnKant != 2;                    // altijd false voor de gast
int mijnHandPos  = ikBenZuid ? 1 : 2;               // Pos.handZuid : Pos.handNoord
int mijnTafelPos = ikBenZuid ? 3 : 4;               // Pos.tafelZuid : Pos.tafelNoord
bool benIkAanZet = aanZet == mijnHandPos || aanZet == mijnTafelPos;
```

En voor het tekenen van `slag`/`vorigeSlag` op de juiste plek (de bestaande
Windows-tekencode legt Zuid onderin, Noord bovenin — precies zoals de
gast op zijn eigen scherm ook "ik onderin" wil zien, en de gast is altijd
Noord):

```csharp
// Swift: relatieveSpeler(_:) — wissel Zuid/Noord om als mijnKant == 2.
int RelatieveSpeler(int absoluut) => absoluut switch {
    1 => 2,   // handZuid  -> handNoord
    2 => 1,   // handNoord -> handZuid
    3 => 4,   // tafelZuid -> tafelNoord
    4 => 3,   // tafelNoord -> tafelZuid
    _ => absoluut,
};
```

Pas dit toe op `SlagView.speler` vóór je een slagkaart positioneert, anders
komt een kaart van de gast zelf in het vak van de tegenstander terecht (dit
exacte probleem is op de Mac-kant al eerder gevonden en opgelost, zie de
aantekening bij `relatieveSpeler` in `SpelView.swift`).

---

## Wat Windows terugstuurt: `GastZet`

Klein en simpel — het spiegelbeeld van hierboven. Drie vormen, nooit meer dan
één tegelijk:

```json
{"troef": 3}
```
```json
{"kaart": {"raw": 84}, "kleur": 3}
```
```json
{"verder": true}
```

Stuur `troef`/`kaart`+`kleur` alleen als de laatst ontvangen `STAND`
`troefVraag == true` respectievelijk `wachtOpSpeler == true` had **én**
`benIkAanZet` (zelf berekend, zie boven) waar was — net zoals de knoppen op
elk scherm nu al alleen actief zijn als de mens iets te kiezen heeft.

**`{"verder": true}`: de "volgende slag"-tik mag van de gast komen, niet
alleen van de gastheer.** Dit is niet gebonden aan `benIkAanZet` — na een
afgelopen slag mag ÁLTIJD getikt worden, van welke kant dan ook, wie het
eerst is. Stuur hem alleen als de laatst ontvangen `STAND`
`wachtOpVerder == true` had (zie de tabel bij `STAND` hierboven). Als
Windows dit niet implementeert — de minimale, correcte deelname hierboven
vereist het niet — kan de partij nog steeds gewoon gespeeld worden: dan
tikt op de Mac/iPhone-kant altijd de gastheer verder, precies zoals vóór
deze uitbreiding. Het is puur een gemak voor de menselijke speler achter
Windows, geen eis om te kunnen verbinden.

**Troef kiezen kan op twee manieren, en dat mag Windows overnemen.** Op de
Mac/iPhone/iPad is er niet alleen de vier kleurknoppen: tijdens de
troefvraag mag je ook op een eigen kaart tikken — hand óf tafel, dat zijn
allebei je eigen rijen, altijd onderin getekend (`SpelModel.klik(_:)` op de
Mac: `if modus == .kiesTroef { if kaart.open { kiesTroef(kaart.kleur) } }`).
De kleur van die kaart wordt dan troef. Alleen kaarten die je ook echt ziet
tellen mee — een nog dichte eigen tafelkaart doet niets, want die zou zijn
kleur verklappen vóór hij open mag. Dit verandert niets aan het protocol:
of de speler nu een knop indrukt of een kaart aantikt, er gaat exact
dezelfde `GastZet(troef: kleur)` over de lijn. Puur een suggestie voor het
Windows-scherm om dezelfde twee manieren aan te bieden, geen eis.

---

## Het lijnprotocol

Regels in ASCII, elk afgesloten met `\n` (`0x0A`), kort genoeg voor een
bluetooth-pakketje. Dit is ongewijzigd sinds het eerste ontwerp (zie
`KlaverjasKit/DuoBericht.swift`):

| regel | wie stuurt hem | betekenis |
|---|---|---|
| `KJ <versie> <appversie> <naam>` | allebei, bij het verbinden | begroeting |
| `STAT <base64>` | allebei, vlak na de begroeting | eigen bewaarde score voor déze partner (zie hieronder) |
| `JA <versie>` | de gast | akkoord; hierna stuurt de gastheer de eerste `STAND` |
| `STAND <base64>` | alleen de gastheer | volledige, voor de ontvanger berekende momentopname |
| `ZET <base64>` | alleen de gast | zijn keuze (troef of kaart), na een `STAND` waar hij aan zet was |
| `P` | beide | pols bij stilte (in de huidige Mac-code nog niet actief gebruikt — mag genegeerd worden als hij binnenkomt) |

`<versie>` is een geheel getal, op dit moment **3**
(`DuoOpzet.protocolVersie` in `KlaverjasKit/DuoOpzet.swift` op de Mac —
controleer die waarde, dit getal verandert bij een niet-compatibele
protocolwijziging: van 2 naar 3 ging hij toen `STAT` erbij kwam). Twee
kanten met een verschillend versienummer moeten weigeren te beginnen:
liever niet verbinden dan een subtiel andere motor tegen elkaar zetten.

### De begroeting, stap voor stap

Beide kanten sturen hun eigen begroeting **meteen** zodra de verbinding en
de karakteristieken klaarstaan, zonder op elkaar te wachten:

**Gastheer** (Mac/iPhone, "openstellen"):
1. stuur `KJ <versie> <appversie> <naam>`
2. ontvang de begroeting van de gast, vergelijk `<versie>`
3. stuur `STAT <base64>`
4. ontvang de `STAT <base64>` van de gast
5. ontvang `JA <versie>`
6. klaar — stuur de eerste `STAND`

**Gast** (Windows, "zoeken"):
1. stuur `KJ <versie> <appversie> <naam>`
2. ontvang de begroeting van de gastheer, vergelijk `<versie>`
3. stuur `STAT <base64>`
4. ontvang de `STAT <base64>` van de gastheer
5. stuur `JA <versie>`
6. klaar — wacht op de eerste `STAND`

`<appversie>` is puur informatief. **`<naam>` niet meer** sinds `STAT`
erbij kwam: de ontvangen naam is voortaan de sleutel waaronder elke kant
zijn bewaarde score voor déze partner opzoekt (zie hieronder) — dus niet
zomaar een willekeurige string, al blijft een herkenbare computernaam
(`Environment.MachineName`) een prima keuze.

### `STAT`: score per partner, ongeacht wie er opensteld

Ed, over waarom dit erbij kwam: "de idee was dat de master, de opensteller,
de score opslaat. Maar als er gewisseld wordt van master dan gaat het fout."
Op de Mac/iPhone-kant lost dat zo op: elk apparaat bewaart zijn score apart
per partnernaam (niet één gedeelde teller), en bij het verbinden wisselen
beide kanten die bewaarde score uit en gaan verder met de hoogste van de
twee — zodat het niet uitmaakt wie er dit keer opensteld.

**Voor Windows is dit geen blokkade.** `STAT` is gewoon een `Statistiek`
(dezelfde `DuoStand`-codering als `STAND`/`ZET`: JSON → rauwe DEFLATE →
base64, zie boven), maar `Statistiek`'s decoder aan de Mac-kant vult elk
ontbrekend veld stil aan met zijn standaardwaarde — dus een **leeg
JSON-object volstaat volledig**, zonder dat Windows de struct hoeft na te
bouwen. Geverifieerd op deze Mac: `{}` decodeert probleemloos tot een lege
`Statistiek`, en de kant-en-klare, gecomprimeerde vorm daarvan is:

```
q1YqLi1ILSrKT81Vsoo20DGI1VEqyS9JTMyBc0FyBaV5Jal5cKGCzBI4Oy8RwS5JTC7JTM2G8AczBLo1OzGxqATNXyVAv6ahiRUXpObkIKtJTU/NQw6AAqA5mVnopoCNhwvWAgA=
```

**Minimale, correcte deelname** (genoeg om te verbinden en te spelen): stuur
dit exacte blok als `STAT <dat-blok>`, en negeer de inhoud van de `STAT` die
terugkomt — lezen hoeft niet, alleen zorgen dat de regel er komt en dat er
één teruggelezen wordt, anders blijft de begroeting hangen op stap 4.

**Volledige gelijkwaardigheid** (optioneel, latere stap): Windows zelf ook
een score per partnernaam laten bijhouden en die als `STAT` versturen in
plaats van steeds de lege versie, plus de ontvangen `STAT` decoderen en de
hoogste van de twee aanhouden. Daarvoor gelden dezelfde twee valkuilen als
voor een `STAND` — het compressieformaat en het feit dat een kaartnaam een
`{"raw": N}`-object is, hier niet van toepassing omdat `Statistiek` geen
kaarten bevat — plus één extra: **Zuid/Noord in `Statistiek` is een
tafelpositie, geen apparaat.** Wie gastheer is, is altijd Zuid (`[0]`), wie
gast is altijd Noord (`[1]`) — maar dat wisselt per sessie. Bewaar dus nooit
rechtstreeks in Zuid/Noord-volgorde, maar in eigen-orde (`[0]` = ikzelf,
`[1]` = die partner), en wissel bij het versturen/ontvangen om waar nodig.
Zie `Statistiek.kantenOmgewisseld` en `StatistiekVerzoening.hoogste` in
`KlaverjasKit/Statistiek.swift` op de Mac voor de exacte, al geteste logica
— rechttoe-rechtaan over te zetten, geen reden om dit zelf opnieuw uit te
vinden.

**Waar dit inmiddels ook voor dient: een echt scherm.** Op de Mac/iPhone
staat de bewaarde score per partner sinds vandaag ook zichtbaar in het
statistiekenscherm, onder de kop "Samen gespeeld" — één regel per partner
(bijvoorbeeld "Ed's iPhone   3 – 1"), de actiefste partner (de meeste
gespeelde spellen) bovenaan (`StatistiekScherm.swift`, sectie `samenspel`,
data uit `SpelModel.alleBewaardeDuoTellingen()`). Dat is niet iets om over
te nemen voor de minimale, correcte deelname hierboven — puur ter
illustratie van waar "volledige gelijkwaardigheid" toe leidt als Windows dat
ooit bouwt: zonder een eigen bewaarde score blijft zo'n lijst aan de
Windows-kant voor altijd leeg.

**Ook nieuw, maar geen protocolwijziging:** het optieblad toont onderaan nu
het versienummer (`Bundle.main.infoDictionary?["CFBundleShortVersionString"]`
— dezelfde waarde die al als `<appversie>` in de begroeting meeging, nu ook
gewoon op het scherm). Puur cosmetisch, raakt de lijn niet.

Leuk om op de Windows-kant hetzelfde te doen, geen eis: onderaan het
optiescherm ook het eigen versienummer tonen — dezelfde waarde die je toch al
als `<appversie>` in de begroeting verstuurt (zie "Het lijnprotocol"
hierboven), dus geen nieuwe bron nodig, alleen ergens op het scherm zetten.
Handig bij het testen: dan zie je op beide schermen meteen of Mac en Windows
wel dezelfde protocolversie praten, zonder eerst te hoeven verbinden.

---

## De bluetooth-dienst: exacte UUID's

**Vast, en nooit te wijzigen** — een ander UUID zou een al werkende
Mac-versie niet meer herkennen. Overgenomen, niet zelf verzinnen:

```
dienst (UartDienst.dienst):        263825A9-5883-47C6-ACF0-44C9DC3E0525
schrijven naar gastheer (naarPerifeer): 463B3B14-262E-4E91-8C1C-49C1B84065E2
notificatie van gastheer (naarCentraal): AB6D4A13-5352-4A64-A87D-943378C397B2
```

(Bron: `KlaverjasBLE/UartDienst.swift` op de Mac.)

Als **gast** (central, wat Windows als eerste bouwt):

* Scan naar de dienst-UUID, verbind met het eerste toestel dat hem
  adverteert.
* Zoek de dienst op, daarbinnen de twee karakteristieken.
* Schrijven doet Windows naar `naarPerifeer`
  (`GattCommunicationStatus`/`WriteValueAsync`, zonder respons —
  `GattWriteOption.WriteWithoutResponse`, net als de Mac-kant doet).
* Lezen doet Windows via een abonnement op `naarCentraal` (notify) — meld je
  aan met `WriteClientCharacteristicConfigurationDescriptorAsync(...Notify)`
  en luister op het `ValueChanged`-event.

Startpunten in `Windows.Devices.Bluetooth`
(`BluetoothLEAdvertisementWatcher`, `BluetoothLEDevice.FromBluetoothAddressAsync`,
`GattDeviceService`, `GattCharacteristic`) zijn stabiele WinRT-API's die al
sinds Windows 10 bestaan — zie
[GattDeviceService](https://learn.microsoft.com/en-us/uwp/api/windows.devices.bluetooth.genericattributeprofile.gattdeviceservice)
en
[BluetoothLEAdvertisementWatcher](https://learn.microsoft.com/en-us/uwp/api/windows.devices.bluetooth.advertisement.bluetoothleadvertisementwatcher).
**Dit is op deze Mac niet te compileren of te toetsen** — controleer de
precieze methodenamen/overloads tegen de actuele Microsoft Learn-documentatie
tijdens het bouwen, net zoals de Mac-kant zijn eigen CoreBluetooth-code pas
op echte hardware kon bewijzen (zie de aantekeningen "Onbewezen zonder
hardware" in `BleCentraal.swift`/`BlePerifeer.swift`).

### Pakketjes: opknippen en aan elkaar plakken

Eén regel kan groter zijn dan één bluetooth-pakketje (een gecomprimeerde
`STAND` in het derde voorbeeld hierboven is al 700+ tekens base64). Dit is
op de Mac een klein, apart, uitputtend getoetst onderdeel
(`KlaverjasBLE/RegelBuffer.swift`) — bouw het net zo klein en apart na:

* **Versturen:** de UTF-8 bytes van de regel, plus één `0x0A` erachter,
  opgeknipt in stukken van hooguit de onderhandelde pakketgrootte (begin met
  een behoudende 20 bytes tot je de werkelijke MTU kent — dat is exact wat
  de Mac-kant ook doet).
* **Ontvangen:** bytes van binnenkomende pakketjes op een stapel leggen tot
  er een `0x0A` in zit; alles daarvóór is één complete regel, de rest blijft
  liggen voor de volgende. Eén zo'n buffer per richting/verbinding, nooit
  delen tussen twee verbindingen.
* Een pakketje is nooit meer of minder dan "een stuk van een regel" — nooit
  de aanname maken dat één notificatie exact één regel is. Dat was een
  bewuste correctie op een eerder, ander bluetooth-project van dezelfde
  auteur (BLESerialPro) dat die aanname wél maakte.

---

## Wat Windows concreet moet bouwen

### Er is al een C#-`SpelView` — bijna bruikbaar, twee dingen om op te letten

In `Referentie/CSharp-engine/SpelView.cs` (naast dit document, in
`KlaverjasMAC_IOS/`) staat al een C#-spiegel van `SpelView`/`KaartView`/
`SlagView`, kennelijk bijgehouden voor het statistiekenscherm (zie
`WIJZIGINGEN-Swift.md`/C1). Die is bijna wat een `STAND` nodig heeft, met
twee dingen om vóór te zijn:

1. **Hij mist drie velden** die er inmiddels wél bij horen:
   `Troefmaker`(`int`), `MijnKant`(`int`) en `SpelUit`(`bool`) — zie de
   velden-tabel hierboven. Die moeten aan `SpelView`/de klasse erbij, anders
   decodeert een binnenkomende `STAND` zonder foutmelding gewoon zonder die
   drie waarden (`System.Text.Json` vult ontbrekende sleutels stil met de
   standaardwaarde van het type).
2. **De veldnamen zijn PascalCase** (`HandZuid`, `PuntenZuid`), de JSON van
   de Mac is **camelCase** (`handZuid`, `puntenZuid`) — dat is verder
   letterlijk hetzelfde woord, alleen de eerste letter verschilt. Zet
   `JsonSerializerOptions.PropertyNameCaseInsensitive = true` bij het
   decoderen en dat verschil lost zichzelf overal in één keer op, zonder een
   `[JsonPropertyName(...)]` op elk veld te hoeven zetten.
3. **`KaartView.Naam` is hier een kaal `char`**, geen `Teken`-object. Een
   binnenkomende `{"raw":65}` past daar niet zomaar in. Makkelijkste
   oplossing: niet rechtstreeks in deze `SpelView`/`KaartView` decoderen,
   maar eerst in een klein, apart "draad"-DTO met `Teken` als `{"raw": N}`
   (zie hieronder, `SpelStandGast.cs`), en dat daarna veld voor veld
   overzetten naar een echte `SpelView`/`KaartView`
   (`kaartView.Naam = (char)wire.Naam.Raw;`). Zo kan de bestaande
   tekencode in `SpelForm.cs` gewoon een `SpelView` blijven aannemen, zoals
   hij nu al doet voor de lokale `KjEngine`.

Een voorstel voor de indeling van de nieuwe bestanden, in lijn met hoe
`KlaverjasWin/Engine/` en `Ui/` nu al gesplitst zijn (zie
`LEESMIJ-CSharp.md`) — pas gerust aan naar wat in de bestaande
projectstructuur past:

| nieuw bestand | inhoud |
|---|---|
| `Ble/UartDienst.cs` | de drie UUID's hierboven, als constanten |
| `Ble/RegelBuffer.cs` | opknippen/plakken op `\n`, zie boven |
| `Ble/DuoBericht.cs` | de zes regelvormen (`KJ`/`STAT`/`JA`/`STAND`/`ZET`/`P`), parsen en samenstellen |
| `Ble/DuoStand.cs` | `DeflateStream` + base64 + de `Teken`-`JsonConverter` |
| `Ble/GastRadio.cs` | de central-rol: scannen, verbinden, karakteristieken, versturen/ontvangen |
| `Ble/SpelStandGast.cs` | het "draad"-DTO voor een inkomende `STAND` (met `Teken` als `{"raw": N}`) — alleen de velden uit de tabel hierboven, daarna overgezet naar de bestaande `SpelView`/`KaartView` uit `Engine/SpelView.cs` |
| `Ble/GastZet.cs` | de uitgaande klasse, drie vormen (`troef`/`kaart`+`kleur`/`verder`) |

En in de bestaande UI: een nieuwe menu-ingang ("Samen spelen (zoeken)") die,
in plaats van de lokale `KjSpel`-lus te starten, `GastRadio` opzet en de
binnenkomende `SpelStandGast` doorgeeft aan **dezelfde tekencode** die
`SpelForm.cs`/`KaartTekenaar.cs` al gebruiken voor het eigen speelveld. De
indeling (groen speelveld, vier rijen rechts, troefvraag op de dichte rij
van Noord — zie `LEESMIJ-CSharp.md` onder "Indeling van het scherm") hoeft
niet opnieuw bedacht te worden: een `SpelStandGast` heeft dezelfde soort
gegevens als waar die tekencode nu al uit put, alleen komt het niet van de
eigen `KjEngine` maar van de lijn. Het enige nieuwe stuk UI is: bij
`troefVraag`/`wachtOpSpeler` + `benIkAanZet` de bestaande klik-afhandeling
niet naar de lokale engine laten gaan maar naar `GastZet` + versturen.

---

## Hoe te toetsen, zonder en met hardware

Dezelfde volgorde als de rest van dit project altijd aanhoudt: eerst
bewijzen zonder radio, dan pas er één bij pakken.

1. **Coderingsproef.** De drie voorbeelden hierboven, plus de lege-`STAT`
   ("`STAT`: score per partner") teruglezen tot exact de getoonde JSON. Geen
   bluetooth, geen Mac nodig.
2. **Regelbuffer-proef.** Een regel in willekeurige stukken knippen, door de
   buffer halen, en controleren dat er precies de oorspronkelijke regel
   uitkomt — ook als een `\n` toevallig op een stukgrens valt.
3. **Lus-proef (optioneel maar aan te raden).** Net als `LusLijnTests` aan de
   Swift-kant: een in-memory "kabeltje" dat twee kanten van je eigen
   C#-implementatie aan elkaar knoopt, om de begroeting en een paar
   `ZET`/`STAND`-regels te testen zonder dat er een radio bij hoeft.
4. **Twee echte toestellen, demo-stand.** Op de Mac/iPhone "Samen spelen" →
   openstellen, met de optie "demo" aan (de computer speelt dan beide
   kanten). Windows zoekt en verbindt. Er hoeft nu alleen gekeken te worden
   of er `STAND`-berichten binnenkomen en of het scherm meebeweegt — nog
   niet of een tik ergens aankomt.
5. **Een mens op de Windows-kant.** Troef kiezen en een kaart spelen, en op
   de Mac/iPhone controleren dat precies die keuze verschijnt.

---

## Windows-als-gastheer (openstellen)

Inmiddels gebouwd, bovenop de bewezen gast-kant: `Ble/GastheerRadio.cs`
(peripheral, `GattServiceProvider`) en het menu-item "Openstellen (host)" in
`SpelForm.cs`. Zo kunnen ook twee Windows-laptops samen spelen, zonder Mac of
iPhone: de een opent zich, de ander zoekt.

De lokale motor (`KjSpel`/`KjEngine`) blijft bij het openstellen gewoon
doorlopen — Zuid is en blijft de mens achter dat scherm — maar Noord wordt
niet meer door de computer gespeeld: `KjState.NoordIsGast` laat de motor ook
voor Noord op `_ui.KiesKaart`/`KiesTroef` wachten (`KjEngine.Ai.cs`:
`WachtOpGast`/`HumaanGast`, los gehouden van `WachtOpMens`/`WachtOpSpeler` zodat
het bestaande "is dit Zuids beurt"-scherm niets van deze nieuwe kant hoeft te
weten). Elke momentopname gaat als STAND naar de gast
(`SpelStandGast.VanSpelView`, het spiegelbeeld van `GastWeergave.NaarSpelView`).

**Onbewezen zonder hardware, net als de gast-kant dat aanvankelijk was.** De
begroeting/serialisatie/engine-kant is getoetst zonder radio (zie
`BleTest.ToetsGastheerStand`/`ToetsDecodeerZet`, en de 200-partijen-proef
blijft byte-voor-byte gelijk met `NoordIsGast` uit) en met de app zelf tegen
zichzelf (openstellen aanzetten, Zuid speelt, Noord wacht netjes op "een zet
van de tegenstander" in plaats van door de computer gespeeld te worden). De
`GattServiceProvider`-kant zelf — echt adverteren en een echte tweede laptop
laten verbinden — is nog niet met twee toestellen getoetst; zie de aantekening
"Welke kant bouwt Windows eerst" hierboven over waarom deze rol minder
betrouwbaar kan zijn dan de central-rol, afhankelijk van de adapter/driver.

## Buiten scope (voorlopig)

Net als bij het oorspronkelijke bluetooth-ontwerp op de Mac
(`WIJZIGINGEN-Swift.md`/het bluetooth-plan): geen hervatten van een
onderbroken partij na een weggevallen verbinding (gewoon opnieuw beginnen is
het gekozen gedrag, ook op de Mac), geen spelen over internet, geen
achtergrondspel.
