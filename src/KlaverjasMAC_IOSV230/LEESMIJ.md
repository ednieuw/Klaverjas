# Klaverjas — de Mac-, iPad- en iPhone-versie

## Klaverjas-42, een eigen naam voor samen spelen, en de Android-versie (6 oktober 2026, versie 2.3.0 build 9)

* **De weergavenaam is "Klaverjas-42".** 42 = *for two*: klaverjas is officieel een spel voor vieren, dit is de
  versie voor twee. In het Xcode-project staat `INFOPLIST_KEY_CFBundleDisplayName = "Klaverjas-42"`, en
  `KlaverjasV1.0/KlaverJasDMG/maak-uitgave.sh` controleert en forceert dezelfde naam (ook de volumenaam van de
  DMG). Het bestand blijft `Klaverjas.app`; de naam in App Store Connect is een aparte keuze.
* **"Mijn naam" in het verbindscherm** (`VerbindScherm`, `@AppStorage("klaverjas.spelernaam.v1")`, hooguit 24
  tekens, één regel). Sinds iOS 16 geeft `UIDevice.current.name` aan apps alleen nog "iPhone", dus twee iPhones
  deelden bij de partner één telling. Wat hier staat gaat als naam mee in de begroeting en is de sleutel van de
  per-partner-telling aan de andere kant. Leeg laten = de toestelnaam, zoals voorheen. Het protocol bleef
  versie 3.
* **Er is nu ook een Android-versie, 2.3.0 (versionCode 9), die met deze app samen speelt** (`AndroidKlaverjasV2/`,
  Kotlin en Jetpack Compose). Zelfde protocol, zelfde dienst- en karakteristiek-UUID's, zelfde `STAND`/`ZET`/
  `STAT`-berichten; gastheer is Zuid en draait de enige motor, de gast is Noord. Bewezen met testregels aan
  beide kanten én op echte hardware (een Galaxy A27 met een iPhone, in beide rolrichtingen). Wat een andere
  implementatie van dit protocol moet weten, en waar het eerst misging:
  * De compressie is **ruwe deflate zonder zlib-kop** (zo schrijft Apple's `COMPRESSION_ZLIB`); in Java dus
    `Deflater(…, nowrap = true)`.
  * De JSON van een `Teken` is `{"raw":65}`, en Swift's gegenereerde `Codable` **eist alle sleutels** van
    `SpelView`: een ontbrekende sleutel (bijvoorbeeld `claude`) laat de hele stand mislukken.
  * Een notificatie mag op Android **hooguit 512 bytes** zijn, ook als de iPhone MTU 517 afspreekt: pakketgrootte
    is `min(MTU − 3, 512)`. Zonder die grens crasht `notifyCharacteristicChanged` bij de eerste stand.
  * De Android-gastheer wacht na elke notificatie op `onNotificationSent` voor de volgende.
* **Tegen een algemene naam ("iPhone", "iPad") vraagt de Android-app hoe de ander heet** en bewaart de score onder
  die naam. Is de nieuwe naam van dit veld ingevuld, dan komt die vraag niet.
* De proeven (`KlaverjasSwift`) zijn niet veranderd; de nieuwe code in `VerbindScherm` is alleen met bouwen en de
  bestaande samenspel-proeven (`StartDuoTests`) gecontroleerd, niet in een scherm bekeken.

## Optieblad past, en uit snel spelen gaat de demo uit (3 oktober 2026)

Met de derde speelwijze (Claude) werd het optieblad hoger dan het venster op de Mac, en bij Demo komt de
speelwijze van Zuid erbij: de bovenkant viel eraf. Nu:

* **Het optieblad past altijd.** Het is hoger gemaakt (ideaal 660, met de vorige slag 780; maximaal 780 punten
  in plaats van 560/660), zodat alles tegelijk past, ook met Demo aan: drie speelwijzen voor Noord én voor Zuid
  en de taal. Er is dan geen scrollbalk. Past het toch niet (een klein venster, een kleine telefoon), dan rolt
  het midden zonder zichtbare balk (`ViewThatFits` met `ScrollView` en `.scrollIndicators(.hidden)`); de titel
  en de knoppen Spelregels/Sluiten blijven staan. `OptieScherm.rolt` (standaard `true`); het
  schermafdruk-gereedschap geeft `rolt: false` mee, want de inhoud van een ScrollView wordt buiten een venster
  niet getekend.
* **De vorige slag staat niet meer in het optieblad als het paneel hem al toont** (iPad, Mac): het blad dat uit
  het paneel komt krijgt `beelden: nil`, en dan verdwijnt `VorigeSlagRij` uit het blad. Op een telefoon, zonder
  paneel, staat hij er nog. Dat past ook beter bij demo, waar die rij in het paneel meeloopt.
* **Uit snel spelen zet de demo weer uit** (`SpelModel.snel`, `didSet`), zodat je weer zelf speelt en de
  speelwijze van Zuid niet blijft staan. Hetzelfde als de Android-versie. Het lopende spel gaat verder; de
  eerstvolgende zet van Zuid vraagt dan jou. `SnelTests` toetst het.
* De versie en het bouwnummer zijn niet aangeraakt.

## Wissen en de samenspel-partners (3 oktober 2026)

De lijst "Samen gespeeld" in het statistiekenscherm was niet te wissen: `Bewaarplaats.wis()` wist alleen de
solo-sleutel, en de tellingen per samenspel-partner staan apart (`klaverjas.statistiek.duo.v1`). Nu:

* **Per partner verwijderen:** elke regel onder "Samen gespeeld" heeft een prullenbak. Een tik vraagt
  "*naam* verwijderen?" met Ja en Nee; Ja haalt alleen die partner weg (`Bewaarplaats.wisDuo(partner:)`,
  `SpelModel.wisDuoPartner(_:)`). De partner met wie nu samen gespeeld wordt heeft geen prullenbak: de
  lopende partij schrijft zijn tellingen toch weer terug (`SpelModel.actievePartner`).
* **Wissen blijft alleen de eigen tellingen wissen** — de partners niet. Ed: een foutje moet nooit alles
  tegelijk kosten. De vraag zegt wat er gebeurt: "Huidige statistiek wissen?" (Engels: "Reset the current
  statistics?"). De knop staat er alleen als er eigen tellingen zijn.
* Proeven in `BewaarTests`: één partner weg laat de rest en de solo-tellingen staan, alle partners weg laat
  de solo-tellingen staan, en `wisStatistiek()` laat niets achter. Het gereedschap `schermafdruk` is niet
  veranderd.

## Claude als derde speelwijze (3 oktober 2026)

Naast Ednieuw (vuistregels) en Ronlog (rekent één slag door) is er een derde speler, **Claude**, in het
scherm "Claude — brute force" genoemd. Hij verdeelt wat hij niet kan zien — de hand van de tegenstander
en de dichte kaarten onder beide tafels — telkens willekeurig, binnen wat bekend is (gespeeld, getoond,
kleuren waarin de tegenstander niet kon bekennen), en speelt voor elke toegestane kaart het hele spel tot
het eind door, met pit en nat. De kaart met de beste gemiddelde uitslag (eigen punten min die van de
tegenpartij) wint. Ook de troefkeuze gaat zo (vier kleuren, driemaal zoveel verdelingen).

* **Claude kijkt alleen naar wat de speler kan zien.** Bij de opening zijn dat 16 van de 32 kaarten: de eigen
  hand (8), de eigen open tafel (4) en de open tafel van de tegenstander (4). Van de andere 16 — de hand van
  de tegenstander en de dichte kaarten onder beide tafels — gebruikt hij alleen *welke* het zijn (een
  verzameling) en hoeveel er in de hand van de tegenstander zitten, nooit welke waar ligt. Tijdens het spel komt
  daar alleen openbare kennis bij: de gespeelde slagen, de omgedraaide kaarten en de kleuren waarin de
  tegenstander niet kon bekennen. Zie "De proef: kijkt Claude niet stiekem?" hieronder.
* `KlaverjasKit/ClaudeStand.swift` — de snelle, losse simulatie (kaarten als getallen, stapels als
  bitmaskers); `ClaudeAi.swift` — de speler zelf. Tactiek 71 in de statistiek.
* `KjState.claude[]`, `Instellingen.claudeZuid/claudeNoord`, `SpelModel.stijlZuid/stijlNoord`
  (0 Ednieuw, 1 Ronlog, 2 Claude). `Bewaarplaats.Voorkeuren` kreeg twee velden; een bestand van
  vóór Claude blijft leesbaar.
* Het toernooi kent nu stijlen: `swift run -c release toernooi 1000 1 claude ednieuw`.
* **Meting** (1000 spellen, zaad 1, elk twee keer gespeeld, 200 proeven per zet): Claude wint 60,7% van
  de spellen van Ednieuw (56,1% van de punten) en 60,4% van Ronlog. Hij gaat ruim drie keer minder vaak
  nat, en dat verklaart veel van het verschil. `ClaudeAi.standaardProeven` is de knop: bij 10 proeven
  ongeveer 56%, bij 40 ongeveer 58–60%. Een zet duurt in release ongeveer een milliseconde (Kotlin op de JVM ongeveer 0,4).
* **Bewijs.** `ClaudeTests`: de toegestane kaarten van de simulatie komen op 6400 beslismomenten overeen
  met `checkValid()`; punten en roem komen slag voor slag overeen met `spoor-v11.txt`; pit, tegenpit en
  nat met `evalueerSpel()`. Dit is een port van de Android-versie (Kotlin, `AndroidKlaverjasV1/`) met
  dezelfde toevalsreeks: bij hetzelfde zaad komen alle getallen exact overeen — ook dat is een proef.
* De handleiding spreekt nu van drie speelwijzen. Windows hoeft hier niets mee: dit is geen regelwijziging.
* **Snel spelen bouwt geen kaartbeelden meer op.** Bij snel spelen bouwde de speelloop na elke kaart en
  na elke slag nog een volledige momentopname met alle 32 kaartbeelden, terwijl `SnelVeld` alleen tellers
  toont — ook aan het eind van het spel, met de laatste stand erbij. `KjUi.snelSpelen` (standaard
  `false`; `Brug` leest het slot van `Tempo`, dus zonder sprong naar de hoofdtaak) zegt de speelloop dat
  het niet hoeft: dan geen `toon` per kaart, en `snapshot(licht: true)` bij het eind van een slag en van
  het spel. `SnelStandTests` bewijst dat dezelfde spellen dezelfde tellingen geven en dat er geen
  kaartbeeld meer getoond wordt. In release scheelt het ongeveer 11% speeltijd. Dezelfde wijziging zit
  in de Android-versie (`AndroidKlaverjasV1`).
* De zware Claude-proeven draaien op een eigen draad met lage prioriteit. Zonder dat faalde `SnelTests`
  ("hooguit een paar keer per seconde getekend": 500 aanroepen binnen 250 ms) in de volle run, terwijl
  hij los en met elke losse suite ernaast groen was; zonder de Claude-proeven was de volle run groen.
  Met lage prioriteit zijn alle 132 proeven groen. De versie en het bouwnummer zijn niet aangeraakt.

Bijgewerkt op 24 augustus 2026: de opdracht uit `OPDRACHT.md` is uitgevoerd. De
Swift-versie doet nu alles wat de Windows-versie doet.

## De drie speelwijzen — hoe ze werken en waarom Claude sterker is

Alle drie spelen met dezelfde regels (`checkValid()` beslist altijd) en dezelfde kaarten. Het verschil zit in
*hoe ver ze vooruitkijken* en *hoe ze met wat ze niet zien omgaan*.

### Ednieuw — vuistregels uit 1994

Het oorspronkelijke Borland C-programma, overgezet. Een lange reeks van 67 genummerde regels (de nummers staan
in het statistiekenscherm). Per beurt kijkt hij naar de plek in de slag — uitkomen, tweede, derde of vierde
kaart — en loopt zijn regels af tot er één past; wat die niet beslissen valt naar `bekijkBesteSlag`.

* **De basis is de slagkans.** `bepaalSlagkans()` schat voor elke kaart (0–100) hoe groot de kans is dat hij
  de slag haalt: een hypergeometrische kans dat de tegenstander nog een hogere kaart van die kleur (of troef)
  heeft, gegeven wat gespeeld en getoond is. Boven 95 heet de kaart "gegarandeerd".
* **Voorbeelden van regels:** zekere slagen die geen troef zijn eerst uitspelen; troef trekken zolang de
  tegenstander nog troef kan hebben; met de aas een kale tien van de tegenstander pakken; de goedkoopste kaart
  die de slag wint; roem meepakken als de slag al van de partner is; anders de goedkoopste afgooien.
* **Troef:** per kleur de troefpunten van de eigen kaarten (hand en tafel), min de open troeven van de
  tegenstander, extra als hij zelf de boer heeft en de tegenstander een troef van die kleur open heeft liggen,
  plus 3 per zekere slag en 2 per kaart in de kleur.
* **Sterk:** snel, voorspelbaar, speelt zoals een mens. **Zwak:** elke regel kijkt naar één plek in één slag.
  Er is geen plan over meerdere slagen, en het nat-risico van het hele spel komt nergens in voor.

### Ronlog — rekent één slag door (R. Loggen, `KJ2.C`; hier `ZoekAi`)

In plaats van regels toe te passen rekent hij de slag echt uit, tot en met de roem.

* Per beurt speelt hij elke toegestane eigen kaart proef. De tegenstander geeft daar zijn *beste* antwoord op,
  uit zijn open tafelkaarten (die zijn exact bekend); daarna speelt hij zelf zijn beste vervolg uit de andere
  stapel. Over de enige onbekende kaart, de hand van de tegenstander, wordt gemiddeld over wat daar nog kan zitten.
* **De waarde van een slag** is kaartpunten plus roem, positief als hij hem pakt en negatief als de
  tegenstander dat doet. Daarom zoekt hij vanzelf roem. Bij gelijke uitkomst geeft hij liever geen zekere slag
  weg en liever geen troef.
* **Troef:** hij waardeert elke kleur alsof het troef is: eigen troefpunten min de open troeven van de
  tegenstander, dubbel voor wat hij kan afdekken, de troeflengte kwadratisch (hand en tafel apart), en de
  zijkleuren op hun drie hoogste kaarten.
* **Sterk:** exact binnen de slag, met roem en met de onbekende kaart erbij. **Zwak:** precies één slag diep.
  Wat een kaart voor de *volgende* slagen betekent, en wat nat of pit kost, ziet hij niet.
* Alles is geheeltallig en zonder toeval; bij dezelfde stand komt dezelfde kaart uit.

### Claude — brute force: het hele spel uitspelen (`ClaudeAi`, `ClaudeStand`)

Hij vraagt niet "welke regel past?" en niet "wie wint deze slag?", maar "wat levert deze kaart op als het
spel uitgespeeld is?".

1. **Wat hij ziet.** Alleen wat een speler aan tafel zou zien, zoals hierboven beschreven.
2. **Verdelen.** De onbekende kaarten worden willekeurig verdeeld over de hand van de tegenstander en de dichte
   kaarten onder de tafels — consistent met wat bekend is, dus nooit een kleur in de hand van de tegenstander
   waarin hij al liet zien dat hij niet kon bekennen. Dat gebeurt 200 keer per zet.
3. **Doorspelen.** Voor elke toegestane kaart wordt in elke verdeling het héle spel gespeeld, tot en met de
   laatste slag, met een eenvoudige speelwijze voor beide kanten (onklopbare kaarten eerst uitspelen, de
   goedkoopste kaart die de slag wint, smeren als de slag van de partner blijft staan, anders zo weinig mogelijk
   weggeven).
4. **De uitslag is de echte uitslag.** Punten, roem, de tien voor de laatste slag, pit, tegenpit én nat worden
   geteld zoals `evalueerSpel()` dat doet. Wat telt is eigen totaal min dat van de tegenpartij.
5. **Kiezen.** De kaart met het beste gemiddelde wint. De troefkeuze gaat op dezelfde manier: elke van de vier
   kleuren, 600 verdelingen, het hele spel uitgespeeld.

De simulatie draait op bitmaskers (kaarten als getallen 0–31, stapels als een geheel getal) en is daardoor
snel genoeg om bij elke zet honderden spellen door te spelen. De regels in die simulatie zijn aan de engine
getoetst: `ClaudeTests` legt de toegestane kaarten op 6400 beslismomenten naast `checkValid()`, de telling van
punten en roem slag voor slag naast het ijkspoor, en pit, tegenpit en nat naast `evalueerSpel()`.

### Wat de metingen zeggen

Elk spel wordt twee keer gespeeld met dezelfde kaarten, één keer met elke speelwijze als Zuid, zodat een
gelukkige verdeling niet meetelt. 1000 spellen, zaad 1, Claude met 200 proeven per zet, 2000 spellen per duel:

| | Claude | Ednieuw |  | Claude | Ronlog |
|---|---:|---:|---|---:|---:|
| Spellen gewonnen | 1214 | 786 | | 1208 | 792 |
| Punten totaal | 210915 | 165325 | | 205866 | 168334 |
| Waarvan roem | 46650 | 25590 | | 43000 | 27200 |
| **Nat gegaan** | **106** | **320** | | **104** | **312** |
| Pit gehaald | 108 | 70 | | 111 | 54 |
| Aandeel spellen | **60,7%** | 39,3% | | **60,4%** | 39,6% |
| Aandeel punten | 56,1% | 43,9% | | 55,0% | 45,0% |

Ter vergelijking spelen Ednieuw en Ronlog onderling gelijk: 500 spellen geven 489 tegen 511 gewonnen (48,9%
tegen 51,1%) en 92817 tegen 93403 punten. Geen van beiden is dus een makkelijke tegenstander voor de ander;
het verschil dat Claude maakt is echt.

**Meer proeven is sterker, met afnemende winst** (aandeel gewonnen spellen, tegen Ednieuw / tegen Ronlog):
10 proeven 56,1% / 56,6%, 40 proeven 59,7% / 58,5%, 200 proeven 60,7% / 60,4%. Een zet duurt in release op een
Mac ongeveer een milliseconde (Swift; Kotlin op de JVM ongeveer 0,4 ms, op een Galaxy A27 ongeveer 5 ms).

### Waarom Claude beter is

* **Hij kijkt naar het hele spel, de anderen naar een slag.** Een kaart kan nu een slag winnen en toch het
  spel kosten: een troef te vroeg wegspelen, een zekere slag niet laten staan voor later, roem aan de
  tegenpartij geven. De vuistregels van Ednieuw en de ene slag van Ronlog zien dat niet; Claude speelt het uit.
* **Nat en pit zitten in zijn doel.** Wie troef maakt en niet meer punten haalt dan de tegenpartij, verliest alles
  van dat spel. Ednieuw en Ronlog gaan ruim drie keer zo vaak nat als Claude (320 en 312 tegen 106 en 104), en
  dat past bij een groot deel van het verschil in gewonnen spellen. Hij haalt ook vaker pit.
* **De troefkeuze wordt gemeten in plaats van geschat.** De anderen tellen punten en lengtes; Claude speelt
  met elke troefkleur het spel duizenden keer uit en kiest de kleur die het meest oplevert, nat meegerekend.
* **Hij gaat zorgvuldig met het onbekende om.** Ednieuw rekent met een kans per kaart, Ronlog middelt over één
  onbekende kaart. Claude verdeelt álle onbekende kaarten telkens opnieuw, binnen wat bekend is, en gebruikt
  daarbij elke kleur waarin de tegenstander niet kon bekennen.
* **Hij hoeft geen regels te onthouden.** Een nieuwe situatie kost hem geen nieuwe vuistregel: het uitspelen
  geeft vanzelf een antwoord.

**Wat het niet is.** Claude wint 60% van de spellen, geen 90%: vier van de tien spellen verliest hij nog. De
kaarten blijven bepalend. Hoeveel het scheelt over een hele partij naar 1500 punten is niet gemeten, en ook
niet tegen mensen. Ik heb ook niet los gemeten hoeveel van de winst uit de troefkeuze komt en hoeveel uit het
spelen; het verschil in nat wijst op allebei. De eenvoudige speelwijze waarmee het spel wordt doorgespeeld is
niet perfect: beide kanten spelen daarin vuistregels, dus Claude schat zijn eigen vervolg en dat van de
tegenstander iets onnauwkeurig in. Dat is de bekende zwakte van deze methode ("strategy fusion"), en meer
proeven halen haar maar deels weg.

### De proef: kijkt Claude niet stiekem?

`ClaudeZichtTests` (Swift) en `ClaudeZichtTest` (Kotlin) verwisselen de verborgen kaarten onderling, zodat de
zichtbare kaarten gelijk blijven en alleen de werkelijke verdeling anders is. Rekent Claude alleen met wat hij
ziet, dan zijn daarna alle scores — per troefkleur en per toegestane kaart, elk een som over alle proeven —
exact gelijk. Piept hij naar de verborgen kaarten, dan wijkt minstens één getal af.

| Wat | Aantal | Uitkomst |
|---|---:|---|
| Troefkeuze: openingen × verdelingen | 40 × 3 = 120 vergelijkingen | alle scores exact gelijk |
| Kaartkeuze tijdens het spel: beslismomenten × verdelingen | 480 × 2 = 960 vergelijkingen (bij 644 verschoof er echt iets) | alle scores en kandidaten exact gelijk |
| **Controle:** één *zichtbare* kaart ruilen met een verborgen | 40 openingen | de scores veranderden bij **40 van de 40** |

De controle bewijst dat de proef kan falen: zodra de verwisseling wél iets zichtbaars raakt, zie je het meteen
in de cijfers. De getallen komen uit de Kotlin-versie; de Swift-proef heeft dezelfde opzet en eist minstens
35 van de 40, meer dan 300 beslismomenten en meer dan 200 echte verschuivingen — en is groen. Om dit te kunnen
meten staat het rekenwerk apart in `ClaudeAi.troefScores()` en `kaartScores()`; `kies()` en `kiesTroef()`
gebruiken die en geven dezelfde zetten als daarvoor (de uitslag tegen de Kotlin-versie is exact gelijk gebleven).

## Wat er bij is gekomen

- **De zoekende speler.** `Referentie/CSharp-engine/ZoekAi.cs` is overgezet naar
  `KlaverjasSwift/Sources/KlaverjasKit/ZoekAi.swift`. Hij rekent zetten door in
  plaats van vuistregels toe te passen: elke eigen kaart wordt proefgespeeld, de
  tegenstander geeft zijn beste antwoord, en over zijn ene onbekende handkaart
  wordt gemiddeld.
- **Per kant kiezen wie er speelt** — Ednieuw met zijn vuistregels of Ronlog die
  doorrekent. Zowel in het paneel naast het speelveld als in het optieblad.
- **Snel spelen zonder kaarten**, om er duizenden spellen doorheen te jagen. De
  computer speelt dan beide kanten en er wordt nergens gewacht.
- **Een grens van een miljoen spellen**, zodat de tellers niet overlopen.
- **Een Xcode-project** in `Klaverjas/`, versie 1.1 (bouwnummer 1), dat voor
  zowel macOS als iOS bouwt.
- **iOS 16 als ondergrens** in plaats van iOS 17, zodat oudere toestellen mee
  kunnen. macOS blijft 14. Nagelopen op een iPad met iOS 16.7.
- **De tellingen blijven bewaard** over afsluiten en herstarten heen, met een
  knop **Wissen** in het statistiekenscherm.
- **Het troefteken voor de troefnaam**, in de vier kleuren die de kaarten zelf
  gebruiken: klaver zwart, schoppen donkergrijs, ruiten rood, harten lichtrood.
  Het teken staat op een wit vlakje, want zwart leest niet op donkergroen.
- **Wie troef maakte staat erbij**: `Z Troef ♥ Harten`. Die kant moet zijn punten
  halen en gaat nat als dat niet lukt — dat stond nergens in beeld.
- **Troef kiezen kan ook met een kaart**: tik een kaart uit je eigen hand of van
  je eigen tafel en die kleur wordt troef. De vier knoppen blijven staan.
- **De schakelaars, de speelwijze en de taal achter de knop Opties**, ook op de
  Mac en de iPad. Dat is hetzelfde blad als op de telefoon.
- **De spelregels naast de opties**, niet erachter: op de telefoon een eigen knop
  in de knoppenbalk. Een blad dat een blad opentrekt laat AppKit op de Mac
  klagen over opmaak die zichzelf aanroept.
- **De dichte kaart steekt verder uit**, zodat er net zoveel blauw te zien is
  als wit.
- **Bij snel spelen geen balk en geen standregel**: die remden alleen maar af,
  en de motor tekent daar nu hooguit vier keer per seconde.
- **De speelwijze van Zuid alleen in demo**, met Zuid standaard op Ronlog.
- **Speelwijze en taal blijven bewaard**; wissen raakt alleen de tellingen.
- **Een iPad dwars krijgt de stand rechts in een paneel**, net als de Mac.
- **De superroem wordt per kant geteld**, zodat je ziet waar hij viel.
- **Twee gebreken uit 1994 rechtgezet**: de troefkeuze van Noord las een vlag
  die niet van hem was, en het schudden gaf Zuid structureel betere kaarten.
  Daardoor had de kant Noord ruim drie punten per spel voordeel. Dat is weg.

De drie spelers heten in deze versie **Ednieuw**, **Ronlog** en **Claude**; zie "De drie speelwijzen" hierboven.

## Waaraan je ziet dat het klopt

Het bewijs is het toernooi: 500 spellen, zaad 1, elk twee keer gespeeld met de
kaarten omgedraaid. Alle acht getallen komen exact overeen met wat de C#-versie
op de Windows-machine oplevert:

```
                         Ednieuw    Ronlog
------------------------------------------
Spellen gewonnen             484       516
Punten totaal              93774     92216
Waarvan roem               17190     16800
Nat gegaan                   130       114
Pit gehaald                   44        23

Puntenaandeel      : Ednieuw 50.4%   Ronlog 49.6%
Spellen gewonnen   : Ednieuw 48.4%   Ronlog 51.6%
Afgebroken (verzaakt): 0
```

Dat zijn duizend spellen waarin elke zet van beide kanten gelijk viel. Eén
andere kaart zou alles daarna verschuiven, dus dit is een strengere toets dan
het kaartspoor.

Zelf na te rekenen:

```bash
cd KlaverjasSwift && swift run -c release toernooi 500 1
```

## De proeven

```bash
cd KlaverjasSwift && swift test
```

Zevenenvijftig proeven in achttien suites, alle groen (24 augustus 2026, ruim drie
minuten). Daaronder de twee die er het meest toe doen:

- **`SpoorTests`** — 200 spellen bij zaad 1, regel voor regel gelijk aan
  `spoor-csharp.txt`. Dat spoor is onaangetast: `zoekt[]` staat standaard uit,
  dus zonder dat je erom vraagt speelt de motor precies zoals hij deed.
- **`ZoekTests`** — het toernooi hierboven, plus 900 spellen met de zoeker aan
  één of aan beide kanten zonder één keer te verzaken.

## Bouwen

```bash
cd Klaverjas && open Klaverjas.xcodeproj
```

Het project verwijst naar `../KlaverjasSwift` als lokaal pakket. Beide
bestemmingen zijn nagelopen: **BUILD SUCCEEDED** voor macOS en voor iOS, en de
app is in de simulator gestart, een kaart gespeeld en het optieblad bediend.

## Wat iOS 16 kostte

`@Observable` en de toetsbediening bestaan pas vanaf iOS 17. Daarom:

- `SpelModel` is een gewone `ObservableObject` met `@Published` geworden, en de
  schermen houden hem vast als `@StateObject` of `@ObservedObject`. Vergeet je
  daar één `@Published`, dan bouwt alles nog steeds en blijft het scherm
  stilstaan — `ObservatieTests` bewaakt dat, en die proef is met een negatieve
  controle nagegaan.
- `.focusable()`, `.focusEffectDisabled()` en `.onKeyPress` zitten achter
  `if #available(iOS 17.0, macOS 14.0, *)`. Op de Mac werken de toetsen K, S, R
  en H voor de troefkleur dus gewoon; een iPhone met iOS 16 speelt met de vinger.

De schermen zijn daarna pixel voor pixel vergeleken met die van ervoor: geen
enkel verschil.

## Voor het kopiëren: gooi `.build` weg

Xcode en `swift test` maken in `KlaverjasSwift/` een map `.build` aan. Die is
goed voor ruim **vijfduizend bestandjes en vierhonderd megabyte** — meer dan
honderd keer de rest bij elkaar — en maakt kopiëren of uploaden tot een marteling.

Hij bevat niets wat je moet bewaren; hij wordt bij de eerstvolgende build
vanzelf opnieuw gemaakt.

```bash
rm -rf KlaverjasSwift/.build KlaverjasSwift/.swiftpm
```

Daarna is de hele map **3 MB in 108 bestanden**. Er staat een `.gitignore` die
`.build`, `.swiftpm`, `DerivedData` en `xcuserdata` buiten de deur houdt, dus
GitHub Desktop laat ze vanzelf al staan.

## Inhoud

```
LEESMIJ.md                        dit bestand
OPDRACHT.md                       de opdracht die hiermee is uitgevoerd

Klaverjas/                        het Xcode-project (macOS + iOS), versie 1.1
  Klaverjas.xcodeproj
  Klaverjas/KlaverjasApp.swift
  Klaverjas/Assets.xcassets       pictogram uit de kaarten zelf

KlaverjasSwift/                   het SwiftPM-pakket
  Sources/KlaverjasKit/           de motor, met ZoekAi.swift en Toernooi.swift
  Sources/KlaverjasKaarten/       de 32 kaarten van 1990, per pixel
  Sources/KlaverjasApp/           SwiftUI: spelscherm, opties, statistiek
  Sources/{kaartenblad,pictogram,schermafdruk,spoor,toernooi,film}/  gereedschap
  Tests/                          57 proeven, waaronder het ijkspoor

Referentie/
  CSharp-engine/*.cs              de C#-motor waar ZoekAi.cs uit komt
  CSharp-scherm/                  hoe het menu en het toernooi op Windows werken
  spoor-csharp.txt                ijkspoor zaad 1
  spoor-zaad6-swift.txt           ijkspoor zaad 6 (vier gelijke kaarten)
  WIJZIGINGEN-Swift.md            wat Windows nog moet overnemen
  LEESMIJ-CSharp.md               de verantwoording van de hele omzetting
  TACTIEKEN.md                    wat elk tactieknummer betekent
  Schermafdrukken/
```

## Wat Windows nog moet overnemen

Uitgeschreven in `Referentie/WIJZIGINGEN-Swift.md`, deel A. De speelwijze zelf
hoeft niet: die kwam van Windows en is daar al goed.

## In ontwikkeling: samen spelen over bluetooth

Het volledige plan staat in `~/.claude/plans/lively-cooking-yao.md`. Vier
fasen; de eerste twee zijn klaar en met eigen proeven bewezen, zonder dat er
al bluetooth aan te pas komt:

- **Fase 1 — de motor kantneutraal.** `KjState.mens` (wie op dit toestel mens
  is: Zuid, Noord, of geen van beide) en `SpelView.mijnKant`/`benIkAanZet`/
  `mijnHand`/`zijnHand` (je eigen kaarten altijd onderaan, ongeacht welke kant
  je bent). Zie A31/A32 in `Referentie/WIJZIGINGEN-Swift.md`.
- **Fase 2 — het protocol, met een lus-in-het-geheugen bewezen.** Nieuw in
  `KlaverjasSwift/Sources/KlaverjasKit/`: `DuoBericht` (de tekstregels),
  `DuoLijn`/`LusLijn`, `DuoKoppeling`. De eerste opzet (niet meer in gebruik,
  zie fase 5 hieronder) liet beide toestellen onafhankelijk hun eigen motor
  doorrekenen met hetzelfde zaad, met een controlesom per zet om afwijking te
  betrappen (`DuoControlesom`) — bewezen zonder één toestel: 20 spellen lang
  regel voor regel gelijk, een verloren regel terug via `R`, een afwijking
  binnen één zet gemeld.

- **Fase 3 — `KlaverjasBLE`, de radiolaag.** Nieuw pakketdoel met
  CoreBluetooth: `RegelBuffer`/`RegelPakketten` (deelt een protocolregel op in
  bluetooth-pakketjes en plakt ze weer aan elkaar — puur en uitputtend
  getoetst, negen proeven), `UartDienst` (de eigen dienst- en
  karakteristiek-UUID's), `BlePerifeer` (stelt zich open, adverteert) en
  `BleCentraal` (zoekt, verbindt) — allebei een `actor` die aan `DuoLijn`
  voldoet, met een dun `NSObject`-klasje ervoor dat CoreBluetooth's aanroepen
  doorgeeft. Rechten geregeld: `NSBluetoothAlwaysUsageDescription` op beide
  platforms, en op de Mac een nieuw rechtenbestand
  (`Klaverjas-macOS.entitlements`) met `com.apple.security.device.bluetooth`
  — zonder dat vond de Mac eerder niets, zonder foutmelding.

  **Bewezen op echte hardware.** Met het kale proefscherm (knop
  "Bluetooth-proef", alleen in debug-bouwen, in het optieblad — Mac/iPad —
  en de knoppenbalk — iPhone, als "BLE") werkt Mac↔iPhone end-to-end, in
  beide rolrichtingen: adverteren, vinden, verbinden, een getypte regel komt
  ongeschonden op het andere toestel aan. iPhone↔iPhone staat nog open.

  **Reparatie (bij fase 5 ontdekt): pakketten die stilzwijgend verdwenen bij
  een lange regel.** `BlePerifeer.stuur(_:)` (`updateValue`) en
  `BleCentraal.stuur(_:)` (`writeValue`) negeerden allebei het teken dat
  CoreBluetooth geeft zodra zijn eigen zendwachtrij vol zit
  (`updateValue`'s `Bool`-antwoord, `canSendWriteWithoutResponse`) — een
  pakket dat niet meteen paste werd dan gewoon niet verstuurd, zonder
  foutmelding. Bij het korte testregeltje van het kale proefscherm (hierboven)
  paste alles toch in één pakket, dus dit bleef onopgemerkt. Pas bij fase 5,
  met een hele gecomprimeerde stand over meerdere pakketten, werd dit een
  echt probleem: "de kaarten worden nog niet uitgewisseld", met een lege
  regel als gevolg bij de ontvanger. Beide kanten wachten nu op
  `peripheralManagerIsReady(toUpdateSubscribers:)` /
  `peripheralIsReady(toSendWriteWithoutResponse:)` voordat ze het volgende
  pakket proberen. Terzijde ook `peripheral(_:didModifyServices:)`
  toegevoegd — ontbrak, en CoreBluetooth klaagde daarover in de console
  ("does not implement..."); dat bleek zelf onschuldig (bevestigd: de
  verbinding zelf werkte prima ondanks die regel en een losstaande "XPC
  connection invalid"-regel, allebei gewone systeemruis), maar nu weg.

  Met die reparatie erin: kaarten en troefkeuze kloppen nu op beide
  toestellen, en de hele stand komt aantoonbaar compleet aan (bevestigd
  zonder Xcode ertussen, een losstaande bouw). **Nieuw gat:** een tik op een
  kaart door de gast kwam niet bij de gastheer aan (diens scherm veranderde
  niet) — maar er was geen enkele logregel die een verzonden bericht
  bevestigde, alleen "ontvangen: ...". `BleCentraal`/`BlePerifeer.stuur(_:)`
  loggen nu ook "verstuurd: ..." (en een duidelijke regel als de guard
  faalt, wat een compleet stille no-op was), en `SpelModel.stuurGastZet(_:)`
  logt zelf ook via `BleLog` (nu `public`) — zodat een volgende proef, met de
  console van beide toestellen erbij, precies laat zien waar de keten breekt.
  Puur diagnose deze keer, geen bevestigde functionele reparatie.

- **Fase 4 — de echte schermen.** Nieuw: `VerbindScherm.swift`
  (`KlaverjasApp`) — rol kiezen (openstellen/zoeken), status volgen via
  `DuoRadio.statusStroom()`, de begroeting (`DuoOpzet`) afhandelen, en bij
  succes doorstarten met `SpelModel.startDuo(lijn:mijnKant:zaad:)`; bij een
  mislukking (verbinding weg, andere appversie) een duidelijke melding met
  een "opnieuw"-knop. Toegankelijk via een knop "Samen spelen" naast Opties
  in zowel `Paneel` (Mac/iPad) als `Knoppenbalk` (iPhone). Pakket bouwt
  schoon, alle 103 proeven blijven groen, en beide Xcode-doelen (macOS en
  iOS) bouwen schoon met deze schermen erin.

  **Nog niet bewezen op hardware.** De onderliggende radiolaag
  (`BlePerifeer`/`BleCentraal`) is bewezen (fase 3, op echte hardware) — de
  bedrading erboven is intussen opnieuw opgezet (fase 5, hieronder) en dat is
  zelf nog niet met twee echte toestellen beproefd.

- **Fase 5 — de gastheer als enige motor.** Twee reparaties na de eerste
  proef met twee echte toestellen, allebei van Ed: eerst bleek de app na de
  eerste slag "vast te lopen" (allebei de kanten wachtten op hun eigen tik om
  verder te gaan, zonder dat één kant het tempo bepaalde), en toen dat
  verholpen was volgde de bredere aanwijzing: laat de gastheer (de
  opensteller) het hele spel beheersen — ook het delen, en ook een
  onderbroken partij — en stuur na elke kaart de volledige stand in plaats van
  losse zetten, met een check erin.

  Dat is meer dan een reparatie: de architectuur is omgezet. Niet langer twee
  onafhankelijke motoren die met hetzelfde zaad gelijk proberen te lopen
  (fase 2), maar **één echte motor, bij de gastheer**; de gast heeft
  helemaal geen `KjSpel` meer, alleen scherm en invoer.

  - De app start bij het opstarten altijd meteen een eigen partij — dat
    blijft zo. Kiest de speler daarna "Samen spelen" als opensteller, dan
    begint `startDuoAlsGastheer` altijd een **verse** partij (nieuwe deling)
    en stuurt die naar de gast, ook als er al een tijdje solo gespeeld werd.
    Een eerdere opzet liet die partij gewoon doorspelen (via een wisselbare
    `KjUi` ervoor, `KjUiRouter`) — dat werkte in proeven met een
    lus-in-het-geheugen, maar gaf op hardware precies het probleem dat dit
    zou moeten voorkomen: allebei de toestellen bleven hun eigen, intussen
    al uiteengelopen partij spelen (Ed: "Als er een BLE verbinding is moeten
    beide spelen eigenlijk stoppen en moet de master opnieuw gaan delen").
    `KjUiRouter` is er daarom weer uit; simpeler en robuuster om bij het
    verbinden altijd gewoon opnieuw te delen.
  - **`GastheerUi`** (vervangt `DuoUi`): stuurt na elke wijziging een
    volledige, voor de ontvanger geredigeerde momentopname (`STAND`) naar de
    gast — zijn hand open, de hand van de gastheer dicht, precies zoals
    `KjSpel.snapshot(voor kant:)` dat nu voor een willekeurige kant kan
    berekenen (voorheen alleen voor de eigen kant van dit toestel; dat liet
    voor kant 2 juist de kaarten van kant 1 ongefilterd zien — een echt lek,
    nu dichtgezet). Is de gast aan zet, dan wacht `GastheerUi` op zijn `ZET`
    in plaats van het lokale scherm te vragen.
  - **`DuoStand`** (nieuw): codeert zo'n momentopname (of de keuze van de
    gast, `GastZet`) als JSON, daarna zlib-gecomprimeerd, daarna base64 — één
    woord, altijd één regel. Ed's argument hiervoor: een volledige,
    zelfstandige stand per bericht herstelt zichzelf vanzelf als er onderweg
    iets misgaat, in tegenstelling tot een groeiende reeks losse zetjes waar
    één gemiste regel je voorgoed laat achterlopen. Vandaar ook: geen
    controlesom en geen "stuur nummer zoveel opnieuw" (`R`) meer nodig —
    `DuoControlesom` en die kant van `DuoKoppeling` zijn vervallen.
  - `DuoOpzet` is aanzienlijk kleiner geworden: geen zaad/kant-uitwisseling
    meer (de gast heeft geen motor die dat nodig heeft), alleen nog de
    versiecontrole.

  **Bewezen zonder hardware**, via `LusLijn`: een gast die zelf geen motor
  heeft speelt een heel spel van acht slagen puur op binnenkomende standen
  uit (`StartDuoTests`); de gast ziet zijn eigen hand open en die van de
  gastheer dicht (het lek hierboven, aangetoond en dichtgezet); aansluiten
  als gastheer op een partij die al een stuk gespeeld was begint aantoonbaar
  een nieuwe (een nieuwe troefvraag verschijnt, niet meteen kaarten spelen),
  met dezelfde troef en dezelfde partijstand bij de gast als bij de gastheer.

  **Bewust nog niet gebouwd:** een onderbroken partij hervatten met de
  kaarten zoals ze waren — bij het (opnieuw) verbinden begint de gastheer nu
  altijd gewoon een verse deling. Dat vergt ofwel `KjState` zelf bewaarbaar
  maken — niet aan te raden, het is een woordelijke vertaling van de
  C-globals met caches die alleen kloppen als ze
  via de echte spellogica zijn opgebouwd — ofwel zaad plus alle zetten van de
  hele zitting bewaren en bij het opnieuw opstarten eerst in stilte
  terugspelen. Dat laatste is behapbaar maar geen kleine klus, en de
  partijstand zelf (`Statistiek.totaal`) is al veilig — dat overleeft een
  herstart nu al. Alleen de kaarten van een spel dat nog bezig was zouden bij
  een volledige herstart verloren gaan; niet bij een weggevallen verbinding.

  **Reparatie: "de gast blijft na het verbinden in zijn eigen spel".** Ed's
  melding na de eerste hardwareproef van fase 5 zelf. Twee echte, los van
  elkaar staande oorzaken gevonden en verholpen:

  1. `startDuoAlsGast` roept `stop()` aan, en die trekt een openstaande
     lokale kaartvraag los met een lege, ongeldige kaart — maar dat maakt de
     oude speeltaak niet meteen dood, hij staat nog gewoon aan dezelfde
     `Brug`/`KjUiRouter` vast. `KjSpel.mensKiest()` vraagt bij een ongeldige
     kaart gewoon opnieuw, via diezelfde oude `Brug`, die dan over de
     gastmodus heen schrijft. Verholpen met een generatie op `SpelModel`
     (elke `stop()` telt hem op; een `Brug` van vóór die telling schrijft
     niet meer) en met een `Task.isCancelled`-uitgang in
     `KjSpel.mensKiest()`, zodat zo'n verweesde taak zichzelf ook echt
     opgeeft. **Een valkuil onderweg:** de generatiecontrole eerst als een
     aparte `await`-stap vóór elke aanroep gezet — dat voegde een onzichtbare
     extra actorwissel toe die de timing van `modus = .verder` net genoeg
     opschoof om een bestaande proef (`PauzeTests.gewoonPaneelWerktElkeSlagBij`,
     die maar één keer `Task.yield()` doet vóór ze kijkt) voorgoed te laten
     hangen. Opgelost door de controle in dezelfde MainActor-aanroep te doen
     als de eigenlijke actie (`SpelModel` kreeg generatiebewaakte overloads
     van `toon`/`vraagKaart`/`vraagTroef`/`vraagVerder`/`toonUitslag`), niet
     als losse stap ervoor — één actorwissel, niet twee.
  2. De gast zag na het verbinden pas iets zodra de motor uit zichzelf de
     eerstvolgende `toon`/`kiesKaart`/`kiesTroef`/`verder` aanriep — tot dat
     moment bleef gewoon het bevroren scherm van vóór het verbinden staan.
     Verholpen — zie reparatie hieronder, die dit gat vanzelf dichtte.
  3. Als extra vangnet: de knop "Nieuw spel" (en "wis statistiek") verstopt/
     genegeerd zolang `SpelModel.inSamenspel` waar is — die knop begon
     zonder die bewaking gewoon een eigen, nieuwe partij en brak daarmee een
     lopend samenspel af, wat er ook uitzag als "blijft in zijn eigen spel".

  **Tweede hardwareronde, tweede melding: "beide games gingen hun eigen spel
  spelen".** Met de reparatie hierboven verholpen, bleek bij een echte proef
  met twee toestellen dat de gastheer nog steeds de partij liet doorspelen
  die al liep vóór het verbinden (de bewuste keuze uit fase 5's eerste opzet,
  via `KjUiRouter`) — en dat gaf op hardware precies dit: de gastheer speelde
  zijn eigen, allang uiteengelopen partij door, los van wat de gast te zien
  kreeg. Ed's reparatie-aanwijzing: "Als er een BLE verbinding is moeten
  beide spelen eigenlijk stoppen en moet de master opnieuw gaan delen en dan
  het spel naar de slave sturen." Dat is nu de opzet: `startDuoAlsGastheer`
  stopt eerst altijd (`stop()`) en begint dan een volledig verse partij
  (nieuw zaad, nieuwe deling) rechtstreeks met `GastheerUi` als motor — geen
  `KjUiRouter`/wisselbare `KjUi` meer, die is er weer helemaal uit. Dat maakte
  ook punt 2 hierboven vanzelf overbodig: een verse partij stuurt zijn eerste
  stand toch al meteen (de troefvraag is de allereerste stap), dus er is geen
  apart "duw meteen bij het verbinden" mechanisme meer nodig
  (`GastheerUi.stuurHuidigeStand()`, ook weer verwijderd).

  **Op echte hardware bewezen, drie reparaties onderweg:**

  1. **Stille pakketverliezen bij grote berichten.** De kleine testregels uit
     fase 3 verborgen een echte bug: `CBPeripheralManager.updateValue(...)`
     geeft `false` terug, en `CBPeripheral.writeValue(..., .withoutResponse)`
     doet stilletjes niets, zodra CoreBluetooth's eigen zendbuffer vol zit —
     en beide retourwaarden werden genegeerd. Onzichtbaar bij een kort woord,
     fataal bij een volledige `STAND` (json, gezipt, base64, over meerdere
     pakketten). Verholpen: `BlePerifeer`/`BleCentraal.stuur(_:)` wachten nu
     echt op "er is weer zendruimte" (`peripheralManagerIsReady`/
     `peripheralIsReady(toSendWriteWithoutResponse:)`), met een grens van 5
     seconden zodat een nooit komend signaal niet de hele motor-taak
     (`KjSpel.loop()`, die op dezelfde taak als het versturen draait) voor
     eeuwig laat hangen.
  2. **Geen enkele zend-diagnostiek.** Alleen `"ontvangen: ..."` werd ooit
     gelogd; Ed kon dus niet zien of een tik zelfs maar ooit een verzendpoging
     werd. `BleLog` (in `KlaverjasBLE`) is nu `public`, en zowel
     `BlePerifeer`/`BleCentraal.stuur(_:)` als `SpelModel.stuurGastZet(_:)`
     loggen nu ook de verzendkant: tik herkend, gecodeerd, verstuurd, of
     precies waarom niet.
  3. **De echte boosdoener achter "beide schermen onbedienbaar na de eerste
     kaart/troef": `VerbindScherm`'s `.onDisappear { stop() }`.** Die riep
     altijd `radio.stop()` aan, ook in het geslaagde pad — waar
     `startDuoAlsGastheer`/`startDuoAlsGast` de radio net had overgenomen
     voor de rest van de partij, vlak vóórdat `sluit()` het blad dichtdeed en
     zo zijn eigen `.onDisappear` liet afgaan. De net overgedragen verbinding
     werd zo een fractie van een seconde later door het eigen
     verbindingsscherm weer afgesloten — de eerste stand ontsnapte nog net,
     alles daarna trof een dode verbinding ("kon niet versturen (geen
     verbinding)"). Gevonden dankzij een complete, dubbelzijdige loguitdraai
     van Ed. Reparatie: `VerbindScherm` kreeg `@State private var
     overgedragen = false`, gezet vlak vóór `sluit()` in het geslaagde pad;
     `stop()` slaat het afsluiten van `radio` over zodra die waar is.

  **Hierna: de eerste écht volledige, van begin tot eind gespeelde partij
  over bluetooth ("wij kunnen nu spelen").** Twee schermreparaties volgden
  meteen daarna, allebei zonder de motor zelf aan te raken:

  - **"Jouw beurt" op het verkeerde scherm.** `GastheerUi.stuurStand`
    kopieerde de statustekst van de gastheer letterlijk naar de gast, zonder
    te weten wie hem las — en het eigen scherm van de gastheer werd tijdens
    het wachten op de gast helemaal niet bijgewerkt. Nu bepaalt `stuurStand`
    de tekst per ontvanger (`Taal.jouwBeurt`/`Taal.welkeTroef` alleen als die
    kant zelf `benIkAanZet` is, anders het nieuwe `Taal.zijnBeurt`), en
    duwt `kiesKaart`/`kiesTroef` dat ook naar het eigen scherm via
    `scherm.toon(...)` zodra het niet de gastheer zelf is die aan zet is.
  - **Zuid/Noord door elkaar.** "De speler op een scherm is altijd zuid" —
    de live puntentelling en de troefmaker-letter lazen `puntenZuid`/
    `puntenNoord`/`troefmaker` absoluut, dus zag de gast zijn eigen stand
    onder "Noord" staan. `SpelView` kreeg, naast de al bestaande
    `mijnHand`/`benIkAanZet` (fase 1/B5), ook `mijnPunten`/`zijnPunten`/
    `mijnRoem`/`zijnRoem`/`mijnTotaal`/`zijnTotaal`/`mijnPartijen`/
    `zijnPartijen`/`troefmakerRelatief` — alleen de live standTabel in
    `SpelScherm`/`CompactScherm` gebruikt ze; `StatistiekScherm` (de
    levenslange tellingen) blijft bewust absoluut.

  Twee schermbugs uit dezelfde eerste volledige partij, allebei absolute
  Zuid/Noord-tekst die niet per scherm was omgezet:

  - **Eigen kaart in het vak van de tegenstander.** De kaarten die middenin
    het veld liggen tijdens een slag (`SlagView.speler`, uit de engine, dus
    absoluut) gingen rechtstreeks naar `Indeling.veldPlek`/
    `CompactIndeling.veldPlek`, die `Pos.handZuid`/`tafelZuid` altijd
    onderaan tekenen — precies waar `mijnHand`/`mijnTafel` ook staan. Bij
    `mijnKant == 2` (de gast) kwam een eigen kaart daardoor bovenaan (het vak
    van de tegenstander) terecht. Reparatie: `SpelView.relatieveSpeler(_:)`
    (dezelfde vertaling als `mijnHand`/`benIkAanZet`, voor een los
    Pos-getal) — beide schermen roepen `veldPlek` nu op met
    `v.relatieveSpeler(s.speler)`.
  - **"Slag N voor Zuid/Noord" verkeerd om.** Die tekst (en bij de laatste
    slag van een spel ook "Zuid wint dit spel"/"Zuid 152, Noord 130") komt
    letterlijk uit `KjSpel`/`KjEngine`, die alleen de vaste kant van de
    gastheer kennen. `GastheerUi.stuurStand` stuurde hem ongewijzigd door.
    Reparatie: `GastheerUi.zuidNoordOmgewisseld` wisselt de HELE meldingtekst
    om (niet alleen het eerste stukje) via een tussenwaarde, zodat ook de
    latere spelUitslag-tekst bij de laatste slag meegaat.

  **`demo` werkt nu ook in samenspel — alleen bij de gastheer.** Ed wilde dit
  vooral om de BLE-verbinding en de snelheid te kunnen beproeven zonder zelf
  te tikken: "with a demo mode ran by two computers the BLE communication
  and game performance can be tested easily." Bleek eenvoudiger dan gedacht:
  `s.comp` (waar `demo` op uitkomt) slaat `mens` voor BEIDE kanten over
  (`!s.comp && s.mensIsAanZet(...)`), dus `GastheerUi.kiesKaart`/`kiesTroef`
  worden dan nooit aangeroepen — geen enkel netwerktimingprobleem, in
  tegenstelling tot het eerst overwogen idee om de GAST een eigen "speel
  voor mij"-bericht te laten sturen. `startDuoAlsGastheer` leest nu
  `Instellingen(demo: doos.huidig.demo)` in plaats van een hardgecodeerde
  `Instellingen()`; `openKaart`/`zoektZuid`/`zoektNoord` blijven op hun
  standaardwaarde. Voor een écht handenvrije proef moet ook `automatisch`
  aan staan — `demo` alleen wacht nog steeds op een tik tussen elke slag,
  hetzelfde bestaande gedrag als bij één toestel.

  **Opruiming.** Het kale proefscherm van hierboven (`BleProefScherm`, de
  knop "Bluetooth-proef"/"BLE") is weer helemaal weg — het was altijd bedoeld
  als tijdelijke steiger voor fase 3, en samenspel zelf is nu bewezen. En op
  de iPhone stond de knoppenrij onderaan inmiddels zo vol ("Samen spelen"
  erbij, tijdelijk ook nog "BLE") dat geen enkele knoptekst meer volledig
  paste. `CompactScherm.Knoppenbalk` is nu twee rijen: de eerste zoals
  eerst, "Samen spelen" gecentreerd op een eigen rij eronder.

  **Een weggevallen verbinding liet zich niet opnieuw opzetten — alleen een
  app-herstart hielp.** Ed: "als de verbinding wegvalt kan je niet opnieuw
  verbinden... de knop Nieuw spel is nu verdwenen." Twee oorzaken:

  - `SpelModel.startDuoAlsGastheer`/`startDuoAlsGast` kregen alleen het
    smallere `DuoLijn` (stuur/ontvang) binnen, niet het bredere `DuoRadio`
    (`start`/`stop`/`statusStroom`, in `KlaverjasBLE`). `SpelModel.stop()`
    kon de echte `CBPeripheralManager`/`CBCentralManager` dus nooit afsluiten
    — die bleef gewoon adverteren/scannen en blokkeerde de volgende
    verbindingspoging. Reparatie: beide functies nemen nu `DuoRadio` aan;
    `SpelModel` bewaart hem apart (`duoRadio`) en sluit hem in `stop()` ook
    echt af.
  - Niemand hoorde een wegval tijdens het spel zelf: `VerbindScherm` stopt
    met luisteren op `statusStroom()` zodra het overdraagt (en is dan al
    gesloten), en `BlePerifeer` (de gastheerkant) implementeerde
    `didUnsubscribeFrom` niet eens — kon een wegval dus sowieso niet merken,
    in tegenstelling tot `BleCentraal`'s al bestaande
    `didDisconnectPeripheral`. Zonder enige melding bleef `duoKoppeling`
    gewoon staan, dus `inSamenspel` ook, dus "Nieuw spel" (met opzet
    verstopt tijdens samenspel) voor altijd verstopt. Reparatie:
    `BlePerifeer` kreeg `didUnsubscribeFrom`; `SpelModel` kreeg
    `bewaakVerbinding(_:)`, die ná de overdracht blijft luisteren en bij een
    wegval gewoon `stop()` aanroept — geen hervatpoging, zoals Ed vroeg.

  `LusLijn` (de lus-in-het-geheugen achter bijna alle proeven in deze hele
  reeks) kreeg er daarom een lege `DuoRadio`-conformiteit bij (in
  `KlaverjasBLE/DuoRadio.swift`); een aparte `WisselbareRadio`
  (`StartDuoTests.swift`) kan een verbinding juist wél laten "wegvallen" voor
  de nieuwe proef.

  **Een wegval bleef stil.** Met de reparatie hierboven stopte de partij wel
  degelijk zodra een wegval gedetecteerd werd, maar `SpelModel.stop()` raakt
  `tekst` niet aan — het scherm bleef dus gewoon op de laatst getoonde
  speeltekst staan, zonder enig teken waarom het spel ophield. Ed, bij het
  testen met `demo`: "hij zou dan ook moeten stoppen met een melding
  'Verbinding verbroken'. Op de slave moet de melding ook komen."
  Reparatie: nieuwe `Taal.duoVerbindingVerbroken`; `bewaakVerbinding(_:)`
  zet die nu in `tekst` ná `stop()` — geldt voor gastheer én gast tegelijk,
  want beide riepen `bewaakVerbinding` al aan.

  **Bevestigd op hardware: "Werkt nu goed."** Daarna drie kleine
  schermwensen:

  - **De knop "Samen spelen" wordt "Stop samen" zodra er een verbinding
    is**, en sluit dan netjes af in plaats van opnieuw het
    verbindingsscherm te openen — `model.start()` (roept zelf `stop()`
    aan, sluit de radio écht af, en begint meteen een gewone partij met
    dezelfde bewaarde puntentelling als vóór het samenspel). Op zowel de
    iPhone- als de Mac/iPad-knoppenbalk.
  - **De knoppenrij op de iPhone weer terug naar één regel**, in de
    volgorde Nieuw spel, Samen spelen, Statistieken, Spelregels, Opties.
    Daarbij bleek de bestaande `minimumScaleFactor(0.75)` voor de
    knoptekst niet genoeg voor "Play together"/"Samen spelen" naast vier
    andere knoppen — die kapte af tot "Play toge…" in plaats van te
    krimpen. Verlaagd naar 0,55: blijft leesbaar, alleen kleiner.
  - **Op de Mac paste "N Troef ♥ Diamonds" niet meer** — de kleurnaam kreeg
    `.lineLimit(1)` + `.minimumScaleFactor(0.6)` in plaats van een vast
    kleiner lettertype, zodat het voor élke kleurnaam in beide talen werkt.

  Ed vroeg ook (als vraag, geen bouwverzoek) of de punten van een partij met
  een specifiek ander toestel apart bewaard blijven tot een volgende
  verbinding met datzelfde toestel. Antwoord: nee, er is maar één lopende
  telling, gedeeld door alleen-spelen én elke samenspel-partner — dat is
  ook precies waarom de telling na "Stop samen" vanzelf weer klopt. Een
  per-toestel telling zou een stabiele manier vergen om een toestel te
  herkennen en een nieuwe opslagvorm — niet gebouwd, tenzij Ed dat wil.

  **Spelregels verhuisd naar het optieblad, met een echte valkuil
  vermeden.** Ed: "die zul je niet vaak raadplegen, zet 'm in het
  optiescherm — dan kan het lettertype van de knoppenrij ook wat groter."
  `OptieScherm` had zelf al een aantekening waarom Spelregels er eerder
  UIT was gehaald: een blad openen vanuit een blad dat al open staat, laat
  AppKit op de Mac klagen ("It's not legal to call
  -layoutSubtreeIfNeeded..."). Spelregels gewoon terugzetten met een eigen
  sheet binnen `OptieScherm` zou die bug terugbrengen. Opgelost met een
  `toonSpelregels: () -> Void` die het optieblad eerst laat sluiten, en pas
  ná die sluitanimatie (`.sheet(onDismiss:)`) het spelregelsblad opent —
  nooit twee bladen tegelijk. Bevestigd op de simulator: geen crash, geen
  waarschuwing.

  Dat liet op de iPhone een rij van vier over (Nieuw spel, Samen spelen,
  Statistieken, Opties), en op de Mac twee nette rijen van twee in plaats
  van twee rijen plus een losse regel. Het lettertype van de knoppenrij
  ging van 12pt naar 14pt (een eerste poging naar 15pt liet "Play together"
  zelfs met nog maar vier knoppen weer afkappen tot "Play toge…" — bleek
  toch echt te veel voor de breedte).

- **Score per samenspel-partner, niet meer per gastheer-rol.** Ed: "de
  score wordt niet per apparaat bijgehouden", en (over waarom een simpele
  "gastheer bewaart de score"-opzet niet volstaat): "als er gewisseld
  wordt van master gaat het fout. Onthoud de hoogste score van de twee en
  ga daar mee verder." Elk apparaat bewaart nu zijn score per specifieke
  partner (los van de solo-score, die met opzet ongemoeid blijft — "als je
  tegen jezelf speelt is dat een aparte score"), en bij het verbinden
  wisselen beide kanten hun bewaarde stand voor elkaar uit en gaan verder
  met de hoogste (`Statistiek.kantenOmgewisseld`/`StatistiekVerzoening`,
  nieuw bericht `STAT` tussen de begroeting en `JA`, protocolversie 2→3).
  Kernproef: apparaat A host sessie 1 en wint 3-1, apparaat B host sessie 2
  — de score blijft bij het juiste fysieke apparaat staan, niet omgedraaid
  door de tafelpositie-wissel. Meteen ook zichtbaar gemaakt: het
  statistiekenscherm toont nu een lijst "Samen gespeeld" met elke bewaarde
  partner en de stand, en het optieblad toont onderaan het versienummer
  uit Xcode (`CFBundleShortVersionString`) — beide bevestigd op de
  iOS-simulator. `Klaverjas/BLUETOOTH-VOOR-WINDOWS.md` (nieuw dit blok:
  instructies voor de W11/C#-kant om hetzelfde bluetooth-protocol te
  bouwen) is meteen bijgewerkt met de nieuwe `STAT`-stap en protocolversie.

- **De "verder"-tik na een slag mag nu van beide kanten komen.** Ed: "de
  volgende beurt kan alleen door degene die de laatste slag speelt worden
  gegeven, maak het zo dat beide kanten een nieuwe beurt kunnen starten."
  Nieuw veld `SpelView.wachtOpVerder` en `GastZet.verder`; wie het eerst
  tikt (gastheer lokaal, of de gast over de lijn) wint, de ander wordt dan
  losgemaakt. Onderweg bleek dit een echte race te hebben — pas zichtbaar
  onder de volle testrun van alle 29 suites, nooit in isolatie: een
  supersnel "verder"-tikje van de gast kon al binnenkomen vóórdat de
  gastheer klaarstond om het te ontvangen, ging dan stilzwijgend verloren,
  en de partij liep muurvast. Opgelost met een buffer op `GastheerUi` voor
  te vroeg binnengekomen antwoorden (troef, kaart én verder) — hetzelfde
  patroon dat `DuoKoppeling` voor rauwe berichten al gebruikte. Drie keer
  achter elkaar de volle testrun groen na de reparatie.
- Versienummer opgehoogd naar 2.1.0.
