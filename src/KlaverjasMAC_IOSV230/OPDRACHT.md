# Opdracht: Klaverjas voor iPad, iPhone en Mac — met beide speelwijzen

**Voor Claude Code op de MacBook.** Je leest dit op een machine waar dit werk
niet gemaakt is. Alles wat je nodig hebt staat in deze map; je hoeft niets van
de Windows-machine te halen.

Geschreven op 24 augustus 2026.

---

## Waar het om gaat

De Swift-app **bestaat al** en werkt: hij is op een Mac gebouwd en als DMG
uitgegeven. Wat hij nog niet heeft, is het nieuwste van de Windows-versie:

1. **De tweede speelwijze** — de zoekende speler van R. Loggen, die zetten
   doorrekent in plaats van vuistregels toe te passen. In Swift ontbreekt hij
   volledig; er is geen `ZoekAi.swift`.
2. **Ze tegen elkaar laten spelen** — per kant kiezen wie er speelt (Ed of
   Loggen), en een stand "snel spelen zonder kaarten" waarin de computer beide
   kanten speelt zonder te tekenen, duizenden spellen per seconde.

Daarnaast: er is nu alleen een SwiftPM-pakket. Er moet een **Xcode-project**
komen voor iPad, iPhone en Mac.

De motor van de Windows-versie en die van de Swift-versie lopen op dit moment
**precies gelijk**. Dat is op 24 augustus 2026 nagemeten met twee ijksporen
(zaad 1 en zaad 6): regel voor regel gelijk, inclusief de verbetering voor vier
gelijke kaarten. Die gelijkheid moet blijven — daar zijn de proeven voor.

## Wat er al ligt

| map | inhoud |
|---|---|
| `KlaverjasSwift/` | het complete SwiftPM-pakket: `KlaverjasKit` (de motor), `KlaverjasKaarten` (de 32 kaarten per pixel), `KlaverjasApp` (SwiftUI), zeven hulpprogramma's en 17 proeven |
| `Referentie/CSharp-engine/` | de C#-motor, waar de Swift-versie uit vertaald is. **`ZoekAi.cs` is het bestand dat je moet overzetten** |
| `Referentie/CSharp-scherm/` | `SpelForm.cs` (het menu), `StatistiekForm.cs`, `Program.cs` en `KlaverjasTest-Program.cs`, waarin het toernooi Ed-tegen-Loggen staat |
| `Referentie/spoor-csharp.txt` | ijkspoor, 200 spellen zaad 1, 6601 regels |
| `Referentie/spoor-zaad6-swift.txt` | ijkspoor zaad 6, waarin vier gelijke kaarten wél voorkomen |
| `Referentie/LEESMIJ-CSharp.md` | de volledige verantwoording van de omzetting, met alle afwijkingen |
| `Referentie/TACTIEKEN.md` | wat elk tactieknummer betekent |
| `Referentie/WIJZIGINGEN-Swift.md` | wat de Swift-versie anders doet dan Windows |
| `Referentie/Schermafdrukken/` | hoe de Windows-versie en de huidige Mac-versie eruitzien |

> Anders dan bij Akwaier: **deze Swift-code is wél gecompileerd en gedraaid.**
> Krijg je compilerfouten in bestaande bestanden, dan komt dat door jouw
> wijziging, niet door de erfenis.

---

## Stap 0 — eerst groen

```bash
cd KlaverjasSwift
swift test
```

17 proeven, waarvan `SpoorTests` de belangrijkste is: die speelt 200 spellen met
zaad 1 en legt elke gespeelde kaart naast `spoor-csharp.txt`. Blijft die groen,
dan speelt de Swift-motor aantoonbaar dezelfde partij als de Windows-versie.

**Ga pas verder als dit groen is**, en houd het groen na elke stap hieronder.

---

## Stap 1 — de zoekende speler overzetten

`Referentie/CSharp-engine/ZoekAi.cs` wordt
`KlaverjasSwift/Sources/KlaverjasKit/ZoekAi.swift`.

Wat die speler doet: hij speelt elke eigen kaart proef, laat de tegenstander er
zijn beste antwoord op geven, speelt zelf zijn beste vervolg, en middelt over
alle kaarten die de tegenstander nog in handen *kan* hebben. De waarde van een
slag is punten plus roem, met een minteken als de tegenstander hem pakt —
daardoor speelt hij vanzelf op roem. Dat de eerste drie kaarten exact
doorgerekend kunnen worden komt doordat de tafelkaarten open liggen: alleen de
handkaarten van de tegenstander zijn onbekend.

**Alles is geheeltallig.** Er komt geen enkel kommagetal in voor en geen toeval.
De omzetting is daardoor volledig voorspelbaar: bij dezelfde stand hoort er
exact dezelfde kaart uit te komen als in C#.

### De vijf plekken waar hij ingehaakt wordt

Meer is het niet. De tactiek van Ed blijft onaangeroerd.

| C# | Swift | wat er gebeurt |
|---|---|---|
| `KjState.cs`, `Zoekt` (`bool[2]`) | `KjState.swift`, bij `comp` | `public var zoekt = [false, false]` — index 0 = Zuid, 1 = Noord |
| `KjEngine.Ai.cs`, `ZoekendeSpeler()` | `KjEngine+Ai.swift` | de wissel: speelt deze kant zoekend, laat `ZoekAi` dan kiezen en sla Ed over |
| idem, boven in `Speler1`, `Tegenspeler1`, `Tegenspeler2`, `Speler2` | `speler1()`, `tegenspeler1()`, `tegenspeler2()`, `speler2()` | `if zoekendeSpeler() { return }` als eerste regel |
| `KjEngine.cs`, `TroefBepalen()` | `troefBepalen()` | speelt de kant die troef mag maken zoekend, dan kiest die ook zijn eigen troef |
| `ZoekAi.cs`, in `Kies()` | idem | `s.tactiek = 70` — het nummer waaronder de statistiek deze keuzes telt |

Nummer 70 bestaat niet in de code van 1994; het is er in C# bijgezet voor deze
speler. `Tactieknamen` kent het dus niet, en dat hoort zo.

### Waar je op moet letten

- **De regelcontrole van de motor is doorslaggevend.** `Kies()` filtert zijn
  kandidaten eerst door `Toegestaan` (dat is `checkValid` van de motor) en pas
  daarna door zijn eigen `LegaleZetten`. `checkValid` heeft eigenaardigheden uit
  1994 die in Loggens `kjlegaal` niet zitten, en een kaart die de motor afkeurt
  kost het hele spel. Draai die volgorde niet om.
- **`Uitkiezen` is geen gewone maximumzoeker.** Bij gelijke opbrengst wint eerst
  de voorkeur "geen zekere slag weggeven" en dan "liever geen troef"; pas
  daarna telt de hoogste score. Neem dat één op één over, anders lopen de
  toernooicijfers uiteen.
- **Geen SwiftUI in `KlaverjasKit`.** Dat de motor niets van het scherm weet is
  precies wat hem draagbaar maakte; de compiler bewaakt dat hier.

---

## Stap 2 — de teksten

In `KlaverjasKit/Taal.swift` ontbreken precies tien teksten. Dit zijn ze, uit
`Referentie/CSharp-engine/Taal.cs` (regel 29-33, 97-100 en 126):

| naam | Nederlands | English |
|---|---|---|
| `menuSpeelwijze` | Speelwijze | Playing style |
| `menuNoordSpeelt` | Noord speelt | North plays |
| `menuZuidSpeelt` | Zuid speelt (in demo) | South plays (in demo) |
| `menuAiEd` | Ed — vuistregels | Ed — rules of thumb |
| `menuAiLoggen` | Loggen — rekent zetten door | Loggen — searches ahead |
| `menuSnel` | Snel spelen zonder kaarten | Fast play without cards |
| `snelBezig` | Snel spelen zonder kaarten | Fast play without cards |
| `snelSpellen(n)` | *n* spellen gespeeld | *n* deals played |
| `snelUitzetten` | Zet dit uit via Opties om weer met kaarten te spelen. | Turn this off in Options to play with cards again. |
| `statTactiekZoeken` | Doorgerekend (Loggen) | Searched ahead (Loggen) |

De `&` uit de Windows-menuteksten (`S&peelwijze`) hoort er in Swift niet in; dat
is een sneltoetsmarkering van Windows. Het scherm mag **geen enkele losse
tekst** bevatten — alles komt uit `Taal`.

---

## Stap 3 — de statistiek

`StatistiekScherm` toont per tactieknummer hoe vaak die regel is toegepast.
Nummer 70 moet daar `Taal.statTactiekZoeken` als naam krijgen in plaats van een
naam uit `Tactieknamen`. Zie `Referentie/CSharp-scherm/StatistiekForm.cs`,
regel 60-62: daar staat het in één regel.

Zo zie je na een toernooi meteen hoe vaak er doorgerekend is, tegenover hoe vaak
elke vuistregel van Ed aan bod kwam.

---

## Stap 4 — het scherm

De schakelaars zitten in `KlaverjasApp/OptieScherm.swift`; zie
`Referentie/Schermafdrukken/mac-opties.png` voor hoe dat er nu uitziet. Erbij
komen:

- **Speelwijze, per kant.** Twee keuzes van twee: Noord speelt Ed of Loggen,
  Zuid speelt Ed of Loggen. Zuid speelt alleen als de computer die kant doet —
  vandaar de tekst "Zuid speelt (in demo)".
- **Snel spelen zonder kaarten.** Zet demo automatisch aan (er valt niets te
  klikken), slaat het tekenen van de kaarten over en haalt `demoPauze` eruit.
  Toon in plaats van het speelveld alleen `snelBezig`, `snelSpellen(n)` en
  `snelUitzetten`. Zie `TekenSnel` in `Referentie/CSharp-scherm/SpelForm.cs`.

**Belangrijk voor de Swift-kant.** Het scherm schrijft *niet* rechtstreeks in
`KjState`: de speellus draait op een eigen taak en leest de schakelaars via
`Instellingen` (`KjSpel.swift`, `pasInstellingenToe()`). Voeg de nieuwe
schakelaars dus toe aan `struct Instellingen` en zet ze daar in `s.zoekt[0]` en
`s.zoekt[1]`. In C# schrijft `SpelForm` wél rechtstreeks in `S.Zoekt` — neem dat
niet over; dat is precies het stuk dat in Swift anders opgelost is, en met
reden.

Op iPhone is er weinig ruimte: twee keer twee knoppen onder elkaar in het
optieblad is genoeg. Geen `Menu` gebruiken — dat leunt op UIKit-gedrag dat hier
eerder een waarschuwing over `_UIReparentingView` opleverde; daarom is het
optieblad ooit met gewone knoppen gebouwd.

---

## Stap 5 — het Xcode-project

Maak een multiplatform App-project **Klaverjas** (iOS + macOS) en voeg
`KlaverjasSwift` toe als lokale package (File > Add Package Dependencies > Add
Local). Laat het pakket een eigen module blijven, zodat `swift test` los blijft
werken. Beide targets krijgen `KlaverjasApp` als dependency.

Er zit al een `klaverjas-mac`-executable in het pakket; die blijft handig om
snel iets te proberen zonder Xcode. Het pictogram wordt getekend door de
`pictogram`-executable.

---

## Hoe je weet dat het klopt

**1 · De bestaande proeven blijven groen.** `zoekt` staat standaard op `false`
voor beide kanten, dus alle 17 proeven — vooral `SpoorTests` — moeten precies
hetzelfde blijven doen. Verschuift het spoor, dan heb je per ongeluk aan de
tactiek van Ed gezeten.

**2 · Het toernooi geeft exact deze getallen.** Bouw in `KlaverjasKit` een
tegenhanger van `Toernooi` uit `Referentie/CSharp-scherm/KlaverjasTest-Program.cs`
(regel 212 en verder): 500 spellen met zaad 1, elk spel twee keer — één keer met
Ed als Zuid, één keer met Loggen als Zuid, dezelfde kaarten. Op de
Windows-machine kwam daar op 24 augustus 2026 dit uit:

```
                              Ed    Loggen
------------------------------------------
Spellen gewonnen             484       516
Punten totaal              93774     92216
Waarvan roem               17190     16800
Nat gegaan                   130       114
Pit gehaald                   44        23

Puntenaandeel      : Ed 50.4%   Loggen 49.6%
Spellen gewonnen   : Ed 48.4%   Loggen 51.6%
Afgebroken (verzaakt): 0
```

Er zit geen toeval en geen kommagetal in de zoekende speler, dus een goede
omzetting hoort deze getallen **exact** te reproduceren, niet ongeveer. Wijken
ze af, kijk dan eerst naar `Uitkiezen` en naar de volgorde waarin de kandidaten
gefilterd worden. Schrijf desnoods met de bestaande `Spoor.genereer` een spoor
weg waarin één kant zoekend speelt, en zoek de eerste afwijkende kaart.

**3 · Nul keer verzaakt.** Dat is de onderste regel van het toernooi en de
strengste eis: de zoekende speler mag nooit een kaart voorstellen die de motor
afkeurt.

Het beeld dat eruit hoort te komen: de twee zijn aan elkaar gewaagd. Loggen wint
iets meer spellen omdat hij op roem speelt, Ed staat voor op kale kaartpunten.

---

## Wat je bewust *niet* moet doen

- **De tactiek van Ed "verbeteren".** Dat is de code van 1994, inclusief zijn
  eigenaardigheden; die staan stuk voor stuk verantwoord in
  `Referentie/LEESMIJ-CSharp.md`. Wat daar als afwijking beschreven staat, is
  met opzet zo gelaten.
- **De motor aan het scherm knopen.** Geen SwiftUI-import in `KlaverjasKit`.
- **Het ijkspoor bijwerken omdat een proef rood staat.** Het spoor is de norm,
  niet de uitkomst.
- **Losse teksten in het scherm zetten.** Alles via `Taal`.

## Als je iets verandert dat ook op Windows moet

Schrijf het op in `Referentie/WIJZIGINGEN-Swift.md`, op dezelfde manier als de
punten die daar al staan: waar, wat, waarom, en of het moet of smaak is. Dan kan
de C#-kant later dezelfde kant op en blijven de twee dezelfde partij spelen.
