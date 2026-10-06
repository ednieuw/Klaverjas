# Wat de Swift-versie anders doet dan de Windows-versie

Bijgehouden zodat de C#-versie dezelfde kant op kan en beide programma's gelijk
blijven lopen. Per punt staat erbij of het moet of dat het smaak is.

Bijgewerkt: 24 augustus 2026, bij het overzetten van de zoekende speler.

---

## A. Moet, anders zien de twee versies er anders uit

### A1. De twee spelers heten Ednieuw en Ronlog

**Waar:** overal waar de speelwijzen bij naam genoemd worden — in de C#-versie
zijn dat `Taal.cs` (`MenuAiEd`, `MenuAiLoggen`, `StatTactiekZoeken`) en de
koppen van `Toernooi()` in `KlaverjasTest/Program.cs`.

| oud | nieuw |
|---|---|
| `Ed` | `Ednieuw` |
| `Loggen`, `Ronald Loggen` | `Ronlog` |

Alleen de zichtbare tekst verandert; er is geen enkele naam van een klasse,
bestand of variabele mee omgezet, dus er kan niets van breken. Aan de Swift-kant
staan de teksten in `Taal.swift` onder "speelwijze" en in `Toernooi.verslag()`.

De uitvoer van het toernooi wordt daarmee:

```
                         Ednieuw    Ronlog
------------------------------------------
Spellen gewonnen             484       516
```

De getallen blijven precies wat ze waren.

### A2. Een grens aan het aantal spellen achter elkaar

**Waar:** in de C#-versie in `SpelForm.cs`, bij het snel spelen (`_snel`).

Snel spelen houdt uit zichzelf nooit op. Bij duizenden spellen per minuut lopen
de tellers een keer over — in de C#-versie zijn `PuntenSpel`, `Roem` en de
tactiektellers 32-bits, en met ruim 150 kaartpunten per spel is dat na ongeveer
veertien miljoen spellen op.

De Swift-versie stopt de partij bij **1.000.000 spellen** en zet er
`Taal.snelKlaar(n)` bij: *Gestopt na … spellen*. Dat ligt ruim onder de grens en
is met de hand toch nooit te halen.

In C# komt dat neer op: in `Toon(SpelView)`, in de tak `if (_snel)`, kijken of
`v.Statistiek.Spellen[0] + v.Statistiek.Spellen[1] >= 1_000_000` en dan `_snel`
uitzetten en de motor stoppen.

Het toernooi in `KlaverjasTest` heeft dezelfde grens nodig: elk spel wordt daar
twee keer gespeeld, dus de helft — 500.000 — als bovengrens op het aantal.

### A3. De tellingen blijven bewaard

**Waar:** in de C#-versie nieuw; nu alleen in Swift.

Het origineel drukte de tellingen bij het afsluiten af en gooide ze weg. Op een
telefoon veeg je het spel tien keer per dag omhoog, en dan is een partij naar
1500 nooit af te maken. De Swift-versie zet `Statistiek` als JSON in de
gebruikersvoorkeuren: aan het eind van elk spel, bij snel spelen hoogstens één
keer per seconde, en nog een keer als de app naar de achtergrond gaat.

Bij het opstarten gaan ze de motor weer in vóórdat er ook maar één kaart valt
(`KjState.zetStatistiek`). In het statistiekenscherm staat links onderin een
knop **Wissen**, met een ja/nee-vraag erachter.

Twee dingen om op te letten als Windows dit overneemt:

* **De volgorde bij wissen.** Het stilzetten van de motor legt de stand nog één
  keer vast. Wis je eerst en herstart je daarna, dan schrijft dat de zojuist
  gewiste tellingen meteen terug — er verandert dan niets. Eerst stoppen, dan de
  momentopname leegmaken, dan pas wissen.
* **Een oud bestand.** De tactieklijst kan korter zijn dan de tachtig van nu;
  die vult zichzelf aan met nullen in plaats van te struikelen.

### A4. Snel spelen begint een nieuw spel

Zet je snel spelen aan terwijl het spel op een kaart van de speler wacht, dan
staat het stil: in het snelscherm zijn de kaarten weg en valt er niets meer aan
te tikken. De Swift-versie begint daarom een nieuw spel zodra snel spelen
aangaat. De tellingen gaan daar doorheen, want die worden eerst bewaard.

In C# komt dat neer op: in de handler van `_miSnel`, na `S.Comp = true`, de
motor opnieuw opzetten in plaats van alleen `Deblokkeer()` aan te roepen.

### A5. Kleinigheden in beeld

* **Het troefteken voor de naam**: "Troef ♥ Harten" in plaats van "Troef Harten".
  Ruiten en harten in rood. Staat zowel in de regel bovenin als in het paneel.
* **De dichte kaart steekt zeven pixels uit** in plaats van vier of vijf: één
  zwarte kaartrand, drie wit en drie blauw, zodat er net zoveel van het
  ruitpatroon te zien is als van het witte kader.
* **Bij snel spelen geen balk en geen standregel.** Die veranderen bij elke
  kaart, zijn op die snelheid toch niet te lezen, en het tekenen ervan gaat van
  de speeltijd af.

### A6. De speelwijze van Zuid alleen in demo

Buiten demo speelt Zuid zelf; dan valt er voor die kant niets te kiezen. De
schakelaar staat er dan ook niet meer. Standaard staat Zuid op **Ronlog** en
Noord op **Ednieuw**, zodat een demo meteen de twee speelwijzen tegen elkaar zet.

De schakelaar voor Zuid gaat wel gewoon de motor in, ook buiten demo. Dat mag:
`zoekendeSpeler()` wordt pas na `Humaan()` gevraagd, dus de zoeker neemt de
kaarten van een mens nooit over. Er is een proef die dat vastlegt.

### A7. Speelwijze en taal blijven bewaard

Naast de tellingen worden nu ook de twee speelwijzen en de gekozen taal
bewaard, onder een eigen sleutel. Bewust *niet*: demo, open kaart en snel
spelen — die horen bij één zitting, en in snel spelen opstarten omdat je dat
gisteren aan had staan is geen prettige verrassing. `Wissen` in het
statistiekenscherm raakt alleen de tellingen, niet de voorkeuren.

### A8. Wat er werkelijk speelt staat in de momentopname

`SpelView` heeft er `zoekt[2]` bij, gevuld uit `s.zoekt`. Het snelscherm laat
daarmee zien wat de motor *doet* in plaats van wat het scherm gevraagd heeft.
Dat is ook wat de proeven meten: de motor draait op een eigen taak en is van
buiten niet te lezen, dus alles wat je van hem weet komt uit de momentopname.

### A9. Een tablet dwars krijgt het paneel ernaast

Op een iPad in liggende stand staat de stand nu rechts in een paneel, net als op
de Mac. Niet met de brede indeling erbij: die past op een tien-inch iPad alleen
op ware grootte en levert dan juist veel kleinere kaarten op. De smalle indeling
blijft dus staan, met het paneel ernaast.

Dat kost de kaarten niets. Liggend wordt de smalle indeling toch al tot ongeveer
de helft verkleind — de vier rijen onder elkaar zijn hoger dan het scherm — dus
de 250 punten die het paneel afsnoept doen er nauwelijks toe. En omdat de
standregel en de knoppenbalk dan kunnen vervallen (het paneel toont diezelfde
stand en heeft dezelfde knoppen), blijft er onder de streep zelfs iets meer
hoogte over dan zonder paneel. Er is een proef die dat vastlegt.

### A10. De indelingsregel is vanaf beide kanten na te rekenen

`neemSmalScherm` had een `#if os(macOS)` in zich. Daardoor kon op een Mac niet
getoetst worden wat een iPad zou doen, en liet het schermafdruk-gereedschap bij
een iPad-formaat gewoon de Mac-indeling zien — een iPad-schermafdruk voor de App
Store klopte dus niet met het toestel.

Het is nu een parameter (`aanraak`) met het platform als standaardwaarde. Het
gereedschap neemt een extra argument: `tablet` of `mac`.

```bash
swift run -c release schermafdruk ipad.png 6 1080 810 spel nl 2 tablet
```

### A11. Noord koos zijn troef op een vlag die van niemand was

**Waar:** `KjEngine.cs`, in `TroefBepalen()`. In het origineel `KJJ.C` regel
729-733:

```c
L8 if (tafel[VRAGER-1][n].gegarandeerd) zekereslagen[tafel[VRAGER-1][n].kleur]++;
L8 if (hand [VRAGER-1][n].gegarandeerd) zekereslagen[hand [VRAGER-1][n].kleur]++;
```

`hand[]` en `tafel[]` zijn niet op Zuid/Noord geïndexeerd maar op **0 = mijn
kant, 1 = de tegenpartij** — zo zet `Vulhanden()` ze klaar. `VRAGER-1` klopt dus
alleen als VRAGER 1 is.

En het is erger dan alleen "in andermans kaarten kijken": `gegarandeerd` wordt in
`Vulhanden()` **uitsluitend voor index 0 berekend**, en de wislus aan het begin
zet het veld niet terug. Bij index 1 staat dus een vlag uit een eerdere stand.
Maakte Noord troef, dan telde hij zekere slagen mee die nergens op sloegen.

**De reparatie:** aan beide kanten `[0]` lezen.

```csharp
for (int n = 0; n < 8; n++)
    if (S.Tafel[0, n].Gegarandeerd != 0) zekereslagen[S.Tafel[0, n].Kleur]++;
for (int n = 0; n < 8; n++)
    if (S.Hand[0, n].Gegarandeerd != 0) zekereslagen[S.Hand[0, n].Kleur]++;
```

**Dit verandert het spelverloop**, en samen met punt A13 vervalt daarmee het
oude ijkspoor. Zie "Het nieuwe ijkspoor" hieronder.

### A12. De superroem wordt per kant geteld

`Superroem` was één getal, dus je kon niet zien of de vier gelijke kaarten bij
Zuid of bij Noord vielen. Het is nu een paar, net als alle andere tellers, en de
slag wordt toegekend aan wie hem pakt — dezelfde kant die de roem krijgt
(`s.roem[s.startVrager - 1]`).

In C# komt dat neer op: `Superroem` van `long` naar `long[2]`, in `Evalueer()`
`S.Superroem[S.StartVrager - 1]++`, en in het statistiekenscherm de regel in
dezelfde twee kolommen zetten als de rest.

**Let op bij het bewaren.** Een bestand van de vorige versie heeft `superroem`
als één getal. De Swift-versie leest dat nog steeds (en zet het bij Zuid); zonder
die voorziening was de speler bij het bijwerken zijn hele telling kwijt geweest,
want één onleesbaar veld maakt het hele bestand onleesbaar. Alle velden hebben
nu een standaardwaarde, zodat een bestand waarin later iets bij- of afkomt blijft
werken. Er zijn twee proeven voor.

### A13. Het schudden was scheef

**Waar:** `KjEngine.cs`, in `Delen()`. In het origineel `KJJ.C` regel 195-199:

```c
for (m = 31; m >= 0; m--) {
    card = random(m);
    kaart[deeltabel[card]].DichtIkHy = wie;
    deeltabel[card] = deeltabel[m];
    ...
}
```

Een eerlijke Fisher-Yates kiest uit álle nog niet gedeelde kaarten, dus uit
0..m. `random(m)` levert bij Borland 0..m-1, en dus kan de kaart die op dat
moment op plek `m` ligt bij die stap nooit gekozen worden.

**De reparatie:** één teken.

```csharp
int card = S.Random(m + 1);
```

Let op dat `Random(n)` aan beide kanten 0..n-1 oplevert; in Swift doet
`Toevalsreeks.volgende(grens)` dat ook. `m + 1` klopt dus voor allebei.

**Waarom het moet.** Gemeten over 200.000 keer delen kreeg Zuid 60,344
kaartpunten per spel en Noord 59,656 — een structureel voordeel van 0,687 punt.
Het zat volledig in de tafel- en de dichte stapels; de handen waren wel gelijk.
Afzonderlijke kaarten weken tot 10% af van hoe vaak ze in een stapel horen te
komen. Na de reparatie is het verschil 0,073, en dat is ruis.

Aan de Swift-kant bewaakt `DelenTests` dit blijvend, met een marge van 0,3 punt
over 40.000 spellen. Met de oude schudding valt die proef om op 0,73 — nagegaan.

### A15. De meldingsbalk knelde op een telefoon

**Waar:** in de C#-versie de regel bovenin `SpelForm.OnPaint`.

De balk zette de melding en "klik of druk een toets" naast elkaar. Die vaste
tekst nam op een telefoon ruim honderdvijftig punten breedte, waardoor er voor de
melding nog geen tweehonderd overbleef. De langste melding is er een van ruim
honderd tekens:

```
Slag 8 voor Noord, 100 roem + 10 voor de laatste slag  -  Noord wint dit spel  -  Zuid 32, Noord 230
```

Die werd verkleind, na twee regels afgekapt, en juist het eind viel weg — met de
roem erin. Vandaar de melding dat "de 100 punten roem niet gemeld wordt": de
motor rekende en meldde ze wel, maar ze pasten niet in beeld.

**Drie dingen aangepast:**

1. De melding krijgt voorrang op de breedte (`layoutPriority`), zodat de
   aansporing wijkt in plaats van de melding.
2. De aansporing valt helemaal weg als hij niet past (`ViewThatFits`). Je mist
   er niets door: op het hele scherm valt te tikken om verder te gaan.
3. Drie regels in plaats van twee, en op een aanraakscherm een kortere tekst:
   **"tik om verder te gaan"** in plaats van "klik of druk een toets" — daar is
   ook helemaal geen toets om te drukken. De streepjes die ervoor stonden zijn
   weg; die dienden om de twee teksten te scheiden en dat doet de ruimte nu.

Aan de Swift-kant bewaakt een proef dat de melding de roem bevat, door de hele
speelloop heen tot en met de zin die op het scherm komt.

### A16. De aansporing staat bij spel uit op de plek van "Spel uit"

Aan het eind van een spel is de melding het langst — daar komt de uitslag bij —
en juist dan stond de aansporing er nog naast. Nu staat "tik om verder te gaan"
op de plek waar anders "Spel uit" staat: in de standregel op een telefoon, in het
paneel op de Mac. De balk bovenin houdt daardoor de volle breedte voor de
uitslag.

Op een iPhone scheelt dat een regel (van drie naar twee), op de Mac past de hele
uitslag weer op één regel. "Spel uit" zelf is geen verlies: de melding zegt al
wie het spel won en met hoeveel.

De aansporing verschijnt alleen als er werkelijk gewacht wordt. Staat
"automatisch doorgaan" aan, dan valt er niets te tikken en blijft "Spel uit"
staan.

### A17. Een knop naar de statistiek tijdens snel spelen

Bij snel spelen is er geen paneel en dus geen weg naar de statistiek, terwijl
juist dan het verloop aardig is om te volgen. Er staat nu een knop
**Statistieken** naast **Stoppen**. Het blad werkt bij terwijl er doorgespeeld
wordt — nagelopen op een toestel: tussen twee opnames liep de teller van 1911
naar 2413 spellen.

### A18. Troef groot, en op de telefoon alleen het teken

De troef stond rechts tegen de rand van het paneel, los van zijn kop, en klein.
Nu staan kop, teken en naam naast elkaar links, en anderhalf tot twee keer zo
groot als de rest: het is het enige gegeven dat je tijdens het spelen
voortdurend nodig hebt.

Ruiten en harten in rood, klaver en schoppen in wit — op de kaarten zijn die
zwart, maar zwart op donkergroen leest niet.

Op een telefoon staat er alleen **Troef ♥**, zonder de kleurnaam. "Troef ♥
Harten" duwde "Slag 2 van 8" er half overheen; het teken zegt hetzelfde en neemt
een derde van de ruimte. Het staat er wel op de maat van de meldingsbalk
erboven; de rest van die regel blijft klein.

### A19. Hand en tafel uit elkaar te houden op de telefoon

**In de rijen.** Op het brede scherm zie je aan de dichte kaarten eronder welke
rij de tafel is. Op een telefoon staan de vier rijen los onder elkaar en zag je
dat niet. De handrijen staan nu een tiende kaartbreedte naar links ten opzichte
van de tafelrijen.

**In het speelveld.** Belangrijker, en pas na twee keer verkeerd lezen goed
begrepen: van een gespeelde kaart in het groene veld was op de telefoon niet te
zien waar hij vandaan kwam.

Op het brede scherm kan dat wel. Daar is het veld een trap — de vier plekken
liggen op y = 10, 50, 95 en 135 maal de vergroting — en die volgt de vier rijen
van boven naar beneden: hand Noord, tafel Noord, tafel Zuid, hand Zuid. Wat uit
een hand komt ligt dus naar buiten, wat van tafel komt naar binnen.

Op de telefoon was het veld een vlakke twee bij twee: de vier plekken lagen op
één hoogte per rij en er viel niets aan af te lezen.

**De reparatie:** dezelfde beweging, alleen kleiner. De linkerkolom schuift een
tiende kaarthoogte omlaag, de rechter een tiende omhoog. Omdat de plekken
diagonaal liggen — tafel Noord en hand Zuid links, hand Noord en tafel Zuid
rechts — komt daarmee elke handkaart naar buiten en elke tafelkaart naar binnen,
net als op het brede scherm. De veldhoogte is met die twee stappen meegegroeid.

De handleiding zegt het in één zin, die voor beide indelingen klopt: "Een kaart
uit de hand ligt iets naar buiten, een kaart van tafel iets naar binnen."

Het brede scherm is niet aangepast: daar werkt de trap al.

### A20. De vorige slag staat in het paneel

Zoals de Windows-versie hem laat staan: vier kaartjes onder de taalkeuze. Handig
om nog even na te kijken wat er lag, zeker als de computer doorspeelt.

`SpelView.vorigeSlag` en `Taal.vorigeSlag` bestonden allebei al maar werden
nergens getoond. De kaarten worden op de schermdichtheid opgebouwd en op ware
grootte neergezet — hele vergrotingen, anders wordt het pixelwerk vaag. Ze
overlappen zes punten, want vier hele kaarten passen net niet in een paneel van
250; de hoek linksboven met kleur en rang blijft vrij.

De drie knoppen onderin het paneel staan nu op twee regels. Naast elkaar werd
"Statistieken" afgekapt tot "Statistiek…".

**Op een telefoon is er geen paneel**, en daar stond hij dus nergens. Het
kaartrijtje is daarom een eigen view geworden (`VorigeSlagRij`) die zowel het
paneel als het **optieblad** gebruikt — op de telefoon staat hij onder de
taalkeuze in dat blad, op dezelfde plek in de volgorde als op de Mac.

### A21. Een korte handleiding in het spel

Nieuw blad **Spelregels**, in het Nederlands en het Engels, te openen vanuit het
paneel (Mac en iPad) en vanuit het optieblad (telefoon). Acht stukken: waar het
om gaat, de kaarten, troef maken, bekennen en troeven, roem, pit en nat, spelen,
en de twee speelwijzen.

De tekst staat in `Handleiding.swift`, niet in `Taal` — dat bestand gaat over
losse woorden en zou er onleesbaar van worden.

**De uitleg beschrijft wat `check_valid()` werkelijk afdwingt**, niet wat er
mooi klinkt. Dat betekent onder meer dat de uitzondering erin staat: kun je niet
bekennen maar staat de slag al op je eigen naam, dan hoef je niet te troeven.
Dat is geen zuivere Rotterdamse regel, maar het is wel wat het programma doet —
en dat is wat de speler moet weten. Twee proeven bewaken het: dat beide talen
even veel stukken hebben en nergens dezelfde tekst staat, en dat de getallen uit
de motor (1500, 152, 20, 50, 100, 200, 10) en de uitzondering erin blijven staan.

### A22. De bonus voor pit stond nergens

Alle acht slagen levert 100 punten roem op, en 300 als de tegenpartij het doet
terwijl jij troef maakte. Die bonus telt `EvalueerSpel()` pas op — ná de laatste
slag, dus ná het moment waarop de melding van die slag gemaakt wordt. Hij viel
daardoor buiten de uitslagtekst én buiten het paneel: de stand sprong met 100
omhoog zonder dat er iets bij stond, en het paneel liet 50 roem zien waar het er
150 waren.

**Twee dingen aangepast:**

1. De uitslagtekst noemt hem:

   ```
   Slag 8 voor Zuid, 10 voor de laatste slag, 100 voor pit  -  Zuid wint dit spel  -  Zuid 302, Noord 0
   ```

   Bij tegenpit staat er `, 300 voor tegenpit`.

   In het Engels heet alle acht slagen halen een **march**:
   `, 100 for march`. Dat is een vakterm die niet vanzelf spreekt, dus de
   handleiding legt hem uit ("Taking all eight tricks is called a march — pit
   in Dutch"). Het statistiekenscherm gebruikt nu hetzelfde woord — daar stond
   "All eight tricks" en "Opponent's slam", en twee namen voor hetzelfde in één
   programma is verwarrend. Een proef bewaakt dat de uitleg blijft staan zolang
   de term in de meldingen gebruikt wordt.

   Eerst stond de pit achteraan tussen haakjes — `(pit, 100 roem)` — maar dat
   las als een voetnoot terwijl het gewoon punten zijn die je erbij krijgt. Hij
   staat nu in dezelfde opsomming als de tien voor de laatste slag. Daarvoor
   moest de zin van de achtste slag ná `EvalueerSpel()` gemaakt worden, want de
   pitbonus bestaat pas op dat moment; `SpelUitslag` draagt hem daarom mee terug.

2. `EvalueerSpel()` geeft de getallen terug in plaats van alleen een zin. `KjSpel`
   legde ze eerst zelf vast vóór de aanroep, en dat kón de pitbonus niet
   bevatten — die bestond op dat moment nog niet. Nu komen punten en roem uit de
   uitslag zelf, met de bonus erin.

In C# komt dat neer op: `EvalueerSpel()` een klein resultaat laten teruggeven
(tekst plus punten en roem per kant, ná de pitbonus en vóór de natregel) in
plaats van een `string`, en `KjSpel` die waarden laten gebruiken voor de
momentopname.

Er is een proef voor, met beide helften apart nagegaan: zonder de tekst valt hij
om op de melding, zonder de bonus in het paneel op de 50 tegen 100.

### A23. Een tik op de verkeerde stapel gaf geen kik

Tikte je op een kaart uit je hand terwijl je tafel aan zet was, dan gebeurde er
niets: geen kaart, geen tekst, niets. Het scherm hield de tik zelf tegen —
`magKlikken` diende zowel om te bepalen wélke stapel oplicht als om te bepalen
of een tik doorging.

De speelloop heeft juist een antwoord klaar. `mensKiest()` kijkt waar de gekozen
kaart ligt en zegt "Die kaart ligt op tafel" of "Die kaart zit in je hand" —
maar dat kan alleen als de tik hem bereikt.

**De reparatie:** het oplichten en het aannemen van een tik uit elkaar halen.
`magKlikken` blijft voor het tekenen, en er is een `neemtTik()` bij die alleen
kijkt of er op dit moment een kaart gevraagd wordt. Het scherm laat de tik door;
de speelloop beslist en zegt wat er mis is.

In C# is dat dezelfde splitsing in `SpelForm`: de muisklik niet meer op
"is deze stapel aan de beurt" filteren, maar op "wordt er een kaart gevraagd".

### A24. De foutmelding bleef de rest van het spel staan

`melding` werd bij een afgekeurde kaart gevuld en bij een goede kaart niet
leeggemaakt. Hij zit in de momentopname (`v.melding = melding`), en die gaat bij
elke kaartvraag opnieuw naar het scherm. De klacht kwam dus bij elke volgende
kaart terug — ook nadat er allang goed gespeeld werd, en bij de laatste slag
stond hij er nog.

**De reparatie:** in `mensKiest()`, in de tak waar de regelcontrole akkoord gaat,
`melding` leegmaken vóór de `return`.

De slaguitslag zette hem aan het eind van een slag wel over, en dat maskeerde het
half: grijp je mis op je laatste kaart van een slag, dan zie je er niets van.
Grijp je mis op je eerste kaart van een slag, dan blijft de klacht staan bij je
tweede kaart van diezelfde slag. Daar meet de proef dan ook op — de eerste opzet
mat het verkeerde moment en slaagde ook zonder de reparatie.

### A25. Wie troef maakte staat er nu bij

De motor wist het al — `KjState.speler`, 1 of 2, gezet bij de troefvraag en
gebruikt door de natregel — maar het scherm toonde het nergens. Terwijl juist
dat bepaalt hoe je moet spelen: die kant moet zijn punten halen en gaat nat als
dat niet lukt.

`SpelView` kreeg er `troefmaker` bij (0 = nog niet bekend), gevuld in
`snapshot()`. In het paneel en in de compacte standregel staat de letter vóór
"Troef": `Z Troef ♥ Harten`.

Niet de eerste letter van `Taal.zuid` afsnijden, maar `Taal.kantKort(_:)` — "Z"
en "N", en "S" en "N" in het Engels. Afsnijden breekt zodra er een taal bij komt
waarin de kant met een andere letter begint.

### A26. Vier troefkleuren, niet twee

De kaarten gebruiken vier kleuren, niet twee. `OrigineleKaarten.symboolKleur`
is `[0, 8, 4, 12]`:

| kleur | EGA | waarde |
|---|---|---|
| klaver | 0 zwart | 0, 0, 0 |
| schoppen | 8 donkergrijs | 85, 85, 85 |
| ruiten | 4 rood | 170, 0, 0 |
| harten | 12 lichtrood | 255, 85, 85 |

Twee licht/donkerparen dus. Het scherm gebruikte twee kleuren — rood voor ruiten
én harten, wit voor klaver én schoppen — en daarmee ging het onderscheid binnen
elk paar verloren.

Het probleem is dat zwart en donkergrijs onleesbaar zijn op het donkergroene
paneel (18, 73, 46). Daarom staat het teken nu op een wit vlakje met afgeronde
hoeken, als de hoek van een echte kaart: `Troefteken`. Op wit kloppen alle vier
de kleuren letterlijk.

Het scherm typt die kleuren niet over maar vraagt ze op met
`OrigineleKaarten.symboolKleurVoor(_:)`, zodat er één plaats is waar ze staan.
De vier knoppen van de troefvraag liggen al op wit en gebruiken ze nu ook.

### A27. Troef kiezen door een eigen kaart aan te tikken

Naast de vier knoppen: tik een kaart uit je eigen hand of van je eigen tafel —
de onderste twee rijen — en die kleur wordt troef. Dat is hoe het aan tafel
gaat, en het scheelt een blik naar de knoppen terwijl je juist naar je kaarten
kijkt.

Er was geen enkele wijziging in de schermen voor nodig. `klikVakken` bevatte al
precies de twee eigen rijen, in beide indelingen. Wat moest veranderen zit in
het model:

* `neemtTik()` liet alleen `.kiesKaart` door; nu ook `.kiesTroef`.
* `klik(_:)` doet bij `.kiesTroef` `kiesTroef(kaart.kleur)`.
* `magKlikken(_:)` geeft tijdens de troefvraag `true` voor beide eigen rijen, zodat
  te zien is dat het kan.

**Alleen een open kaart.** Een dichte kaart aan kunnen wijzen zou zijn kleur
verraden, en dat mag het spel niet. In de praktijk liggen Zuids hand en tafel
altijd open, dus de regel houdt vooral de deur dicht voor later.

Onder de vier knoppen staat "of tik een eigen kaart" / "or tap one of your own
cards": zonder die regel vindt niemand de tweede manier.

### A28. De opties achter één knop

Het paneel op Mac en tablet toonde de vier schakelaars, het speelwijzeblok en de
taalkeuze allemaal uitgeklapt. Die staan nu achter de knop **Opties**, die het
optieblad opent dat de telefoon al gebruikt — dezelfde view, dus één plek om te
onderhouden.

Wat in het paneel blijft: de troefregel, de slagregel, de stand en de vorige
slag. Er zijn nu vier knoppen (Opties, Spelregels, Nieuw spel, Statistieken) in
twee rijen van twee; drie naast elkaar paste al niet in 250 punten — dan werd
"Statistieken" afgekapt tot "Statistiek…".

Het paneel werd hier flink rustiger van, en dat komt de grotere troefregel uit
A25 en A26 goed uit.

### A29. De spelregels naast de opties, niet erachter

Het optieblad had zelf een knop Spelregels, die een tweede blad opentrok. Op de
Mac klaagt AppKit daarover:

```
It's not legal to call -layoutSubtreeIfNeeded on a view which is already
being laid out.
```

Een blad dat midden in zijn eigen opmaak een volgend blad laat opmeten. De
klacht is eenmalig en je ziet er verder niets van, maar hij hoort er niet te
staan.

**De reparatie:** het optieblad verliest zijn knop Spelregels. Op de Mac en de
tablet stond die knop al in het paneel, dus daar verandert er niets aan de
bereikbaarheid. Op de telefoon was het optieblad de enige ingang; daar staat nu
een vierde knop in de knoppenbalk — Nieuw spel, Statistieken, Spelregels,
Opties — met `minimumScaleFactor(0.75)`, zodat vier namen op een smal toestel
krimpen in plaats van halverwege af te breken.

**Meteen meegenomen:** het paneel had door de knop Opties uit A28 drie
`.sheet`-modifiers boven op elkaar staan. De knoppenbalk van de telefoon
vermijdt dat al bewust — sheets stapelen pakt in SwiftUI onvoorspelbaar uit.
Het paneel gebruikt nu dezelfde opzet: één `.sheet(item:)` met een keuze erin.

**Niet nagespeeld.** Met `swift run klaverjas-mac` komt de klacht niet, ook niet
met een blad dat een blad opentrekt: die opstelling opent de bladen op een vaste
tijd zonder klik en zonder maatverandering. De waarneming komt uit de
Xcode-console.

### A30. Het paneel afremmen bij snel spelen — geprobeerd, teruggedraaid

`Brug.toon` remde het tekenen bij snel spelen al af tot hooguit vier keer per
seconde. Maar het paneel — de stand en de vorige slag rechts in beeld — komt
niet via `toon` maar via `Brug.verder`, één keer per slag, en die had de rem
niet. Daardoor "liepen" de getallen door terwijl de kaarten zelf al afgeremd
waren.

**De poging:** `Brug.verder` dezelfde `tempo.magTekenen()` laten gebruiken als
`Brug.toon`, en de pauze van 250 naar 500 ms — bij snel spelen valt er toch
niets te volgen.

**Teruggedraaid.** Ed meldde dat de snelheid tegenviel. De extra sprong naar de
hoofdtaak om `model.snel` te lezen — nodig om te beslissen of er afgeremd moet
worden — gebeurde nu bij elke slag, en bij snel spelen zijn dat er miljoenen
per partij. Die sprong kostte meer dan het stilstaande paneel ooit opleverde.
`Brug.verder` roept `vraagVerder` weer rechtstreeks aan, zonder rem, en de
pauze staat weer op 250 ms. `PauzeTests.snelPaneelWerktElkeSlagBij` legt dit nu
vast als bewuste keuze, niet als toeval.

**Bijvangst, wel gebleven.** De proef die dit onderzocht gebruikte eerst — net
als de al bestaande `SnelTests.snelTekentZuinig` — voor elke herhaling
dezelfde vaste tekst `"x"`. Daarmee is een update die toevallig dezelfde
waarde zet niet te onderscheiden van geen update, en kan de proef nooit zakken.
Beide gebruiken nu een tekst die bij elke herhaling verschilt; dat blijft zo,
los van de rest van deze reparatie.

### A31. De motor kantneutraal, als voorbereiding op samen spelen

Startpunt van het bluetooth-plan (`~/.claude/plans/lively-cooking-yao.md`,
fase B4): met z'n tweeën over bluetooth speelt elke kant zijn eigen kant als
mens, op zijn eigen toestel. De motor kende tot nu toe maar één mens — Zuid,
hard gecodeerd op vier plekken in `KjEngine+Ai.swift` en twee in `KjSpel.swift`.

**`KjState.mens = [true, false]`**: wie op dit toestel met de hand speelt,
[0] = Zuid, [1] = Noord. Die standaardwaarde is precies het bestaande gedrag.
Erbij: `KjState.mensIsAanZet(_ vrager: Int) -> Bool`, die `vrager` (Pos.hand​Zuid
..Pos.tafelNoord, of een deel daarvan) naar een kant herleidt — hand- en
tafelvariant van dezelfde kant geven dezelfde uitkomst, net als
`zoekendeSpeler()` al deed voor de zoekende speler.

**De vier `humaan()`-poorten** in `speler1()`, `tegenspeler1()`,
`tegenspeler2()` en `speler2()` testten stuk voor stuk `s.vrager == 1`,
`== 3`, of een combinatie — vier keer hetzelfde idee, in vier iets andere
vormen omdat `vrager` in elke functie over een andere deelverzameling loopt.
Alle vier zijn nu `s.mensIsAanZet(s.vrager)`.

**De troefvraag in `KjSpel.swift`** testte `s.startVrager == 2` om de computer
juist NIET te vragen — daar zat impliciet in verstopt dat alleen Zuid ooit
mens was. Nu: `s.comp || !s.mensIsAanZet(s.startVrager)`.

**`mensKiest()`** rekende met de letterlijke constanten `Pos.handZuid` en
`Pos.tafelZuid`, voor de foutmeldingen én om te bepalen of een tik bij het
uitkomen als hand of als tafel geldt. Nu bepaalt de functie bij binnenkomst
welke kant er aan zet is en gebruikt de bijbehorende Pos-codes.

**Bijvangst: een stap opzij tegen een muurvaste kern.** Bij het testen van
Noord als mens bleek `mensKiest()`'s hertry-lus, als de aangesloten `KjUi`
structureel een ongeldige kaart blijft aanbieden, één kern muurvast te kunnen
houden: de `await` op `ui.kiesKaart(v)` wisselt niet per se van taak als de
aansluiting direct antwoordt zonder echt te wachten. Dat is precies het soort
fout dat een nog onvolgroeide Bluetooth-koppeling kan veroorzaken. Er staat nu
een expliciete `await Task.yield()` boven aan de lus. **Geen garantie** tegen
elke vorm hiervan — zie de aantekening bij `MensTests.noordSpeeltMee` voor
waarom niet — maar wel een verbetering voor elk geval waarin de aansluiting af
en toe een échte wachtstap teruggeeft.

**Toetsen.** `SpoorTests` (het ijkspoor van 200 spellen) en `ZoekTests` (het
toernooi van 500 spellen × 2) blijven exact kloppen: met `mens = [true, false]`
— de standaardwaarde — verandert er voor de bestaande speelwijze letterlijk
niets. Beide draaien met `comp = true` en raken de vier `humaan()`-takken
sowieso niet aan; het echte bewijs voor de kantneutraliteit is een nieuwe
proef, `MensTests.noordSpeeltMee`, die `s.mens = [false, true]` zet en
controleert dat Noord nu wél om kaarten gevraagd wordt. Met `mensIsAanZet(_:)`
tijdelijk teruggezet naar "alleen Zuid" liep die proef muurvast op 100% CPU in
plaats van te zakken — met de klok erbij gecontroleerd, niet aan de proef zelf
overgelaten, want een kale `withCheckedContinuation` luistert niet naar
annulering en een race tegen een eigen `Task.sleep` redt dat niet altijd (zie
de aantekening in de proef zelf).

**Nog niet gedaan: B5** (het perspectief in `SpelView` — je eigen kaarten
onderaan, ongeacht welke kant je bent) en de rest van deel B. Dit is alleen
de motor; er verandert voor de speler nog niets.

### A32. Perspectief: je eigen kaarten onderaan, ongeacht welke kant je bent

Vervolg op A31 (B5 uit het bluetooth-plan). Tot nu toe stond Zuid altijd
onderaan in beeld, want alleen Zuid kon mens zijn. Met bluetooth speelt straks
elke kant op zijn eigen toestel, en moet je eigen hand daar altijd onderaan
staan — ook als de motor jou "Noord" noemt.

**`SpelView.mijnKant = 1`** (1 = Zuid, 2 = Noord; standaard 1, dus verandert
er met deze waarde niets). Alle bestaande velden (`handZuid`, `puntenNoord`,
…) blijven absoluut — bewust niet spiegelen: `Spoor`, het statistiekenscherm,
`SpelUitslag` en de bestaande proeven lezen ze allemaal, en spiegelen zou daar
het foutrapport onleesbaar maken. Erbij, als berekende eigenschappen:
`mijnHand`, `zijnHand`, `mijnTafel`, `zijnTafel`, `mijnDicht`, `zijnDicht`,
`mijnOnder`, `zijnOnder`, `mijnHandPos`, `mijnTafelPos`, `benIkAanZet`.

**Drie bestanden mechanisch omgezet:**
* `SpelModel.magKlikken(_:)` vergelijkt nu met `view.mijnHandPos`/
  `view.mijnTafelPos` in plaats van met het letterlijke `Pos.handZuid`/
  `Pos.tafelZuid`.
* `SpelScherm.swift` en `CompactScherm.swift`: `klikVakken()` bouwt de
  aanklikbare vakken uit `v.mijnTafel`/`v.mijnHand`; `teken()` tekent
  `v.zijnHand`/`v.zijnTafel` bovenaan en `v.mijnHand`/`v.mijnTafel` onderaan —
  waar voorheen letterlijk Noord en Zuid stonden.

**Bewust buiten scope gelaten, en waarom dat oké is:**
* **De plek van een slagkaart op het groene speelveld** (`Indeling.veldPlek`/
  `CompactIndeling.veldPlek`) blijft absoluut: Zuids kaart landt onderaan het
  veld, Noords bovenaan, ook als Noord "ik" ben. Dat is een cosmetisch verschil
  met de rijen eromheen — je kaart landt zichtbaar boven in plaats van onder —
  geen functionele blokkade: er is nog steeds duidelijk te zien welke van de
  vier kaarten de jouwe is. Een volledige omdraai zou ook `Indeling.swift` en
  `CompactIndeling.swift` moeten aanpassen; dat is bewaard voor een latere
  ronde, niet stilzwijgend overgeslagen.
* **De standtabel** (punten, roem, totaal, partijen) blijft Zuid/Noord tonen,
  niet "ik/hij". Die cijfers zijn zonder perspectief prima leesbaar, en hoeven
  niet mee te wisselen om samen spelen mogelijk te maken.

**Toetsen.** Nieuw: `PerspectiefTests` (KlaverjasKit) toetst de berekende
eigenschappen zelf, met en zonder `mijnKant = 2`. `PerspectiefSchermTests`
(KlaverjasApp) toetst dat `magKlikken(_:)` bij `mijnKant = 2` Noords rij laat
oplichten en Zuids rij niet, zelfs als `aanZet` toevallig op een Zuid-positie
staat. Met `magKlikken(_:)` teruggezet naar de oude, hardgecodeerde vergelijking
zakken beide Noord-proeven en blijft de Zuid-proef slagen — zo bewezen, niet
aangenomen. De volledige set blijft ongewijzigd bij de standaardwaarde
`mijnKant = 1`.

### A14. Het nieuwe ijkspoor

A11 en A13 veranderen allebei het spelverloop. `spoor-csharp.txt` en de
toernooigetallen 484/516 horen bij versie 1.0 en zijn niet meer na te spelen.

**Zolang Windows die twee reparaties niet heeft, is er geen kruiscontrole tussen
de twee talen.** Dat is de prijs; hij is bewust betaald omdat een oneerlijk spel
erger is dan een tijdelijk ontbrekend bewijs.

Er staat een nieuw doel klaar:

* **`Tests/KlaverjasKitTests/Bronnen/spoor-v11.txt`** — 200 spellen, zaad 1,
  6601 regels, gemaakt met de Swift-motor mét beide reparaties. Levert de
  C#-versie na A11 en A13 hetzelfde bestand op, dan lopen de twee weer gelijk.

  ```bash
  dotnet run --project KlaverjasTest -c Release -- spoor 200 1 spoor-nieuw.txt
  ```

* **De toernooiuitslag** bij 500 spellen en zaad 1 wordt:

  ```
                           Ednieuw    Ronlog
  ------------------------------------------
  Spellen gewonnen             489       511
  Punten totaal              92817     93403
  Waarvan roem               16560     17660
  Nat gegaan                   117       106
  Pit gehaald                   48        28

  Puntenaandeel      : Ednieuw 49.8%   Ronlog 50.2%
  Spellen gewonnen   : Ednieuw 48.9%   Ronlog 51.1%
  ```

  Merk op dat de uitslag omdraait: met een eerlijk spel staat **Ronlog** voor,
  waar in versie 1.0 Ednieuw voorlag. Dat kwam dus niet door zijn speelwijze
  maar doordat hij op de verkeerde stoel zat.

`spoor-csharp.txt` blijft staan als het archief van versie 1.0.

---

---

## B. Gelijk aan Windows, ter controle overgezet

### B1. De zoekende speler

`ZoekAi.cs` is regel voor regel `ZoekAi.swift` geworden, met dezelfde volgorde
van beslissen. Bewezen door het toernooi: 500 spellen, zaad 1, elk twee keer
gespeeld, en alle acht getallen komen exact overeen met de C#-uitvoer. Dat zijn
duizend spellen waarin elke zet van beide kanten gelijk viel; één andere kaart
zou alles erna verschuiven.

De toets staat vast in `Tests/KlaverjasKitTests/ZoekTests.swift` en draait mee
met `swift test`. Aan de Swift-kant is er hetzelfde gereedschap als aan de
C#-kant:

```bash
cd KlaverjasSwift
swift run -c release toernooi 500 1
```

Twee dingen die bij het overzetten opvielen en die aan beide kanten zo moeten
blijven:

* `Kies()` filtert zijn kandidaten **eerst** door `Toegestaan` (de regelcontrole
  van de motor) en pas daarna door zijn eigen `LegaleZetten`. Die twee zijn het
  niet altijd eens — `check_valid` heeft eigenaardigheden uit 1994 — en de motor
  heeft het laatste woord.
* `Uitkiezen` is geen gewone maximumzoeker. Bij gelijke opbrengst wint eerst
  "geen zekere slag weggeven", dan "liever geen troef", en pas daarna de hoogste
  score.

### B2. Tactieknummer 70

70 is niet van 1994 maar van de zoekende speler. In het statistiekenscherm komt
daar `Taal.StatTactiekZoeken` te staan in plaats van een naam uit
`Tactieknamen`; die tabel blijft ongemoeid. Aan beide kanten hetzelfde.

---

## C. Niet aangepast

* **De tactiek van Ednieuw.** De vuistregels zijn niet "verbeterd" om het
  toernooi mooier te laten uitvallen; dan zou het ijkspoor van zaad 1 breken.
* **Het verschil tussen de twee speelwijzen.** Dat is kleiner dan het lijkt.
  Zie de aantekening hieronder.
* **Het ijkspoor.** `zoekt[]` staat standaard uit, dus `spoor-csharp.txt` klopt
  nog steeds regel voor regel — nagelopen, alle zeventien toetsen groen.
* **De zes eigenaardigheden** uit `LEESMIJ-CSharp.md`. Die horen zo.

---

## E. Aantekening: de kant Noord heeft een klein voordeel

Nagemeten op 24 augustus 2026, omdat het vreemd leek dat Ronlog partijen
verliest terwijl hij meer spellen wint.

**Zet twee keer dezelfde speelwijze tegenover elkaar en Noord wint nog steeds
vaker.** Vier startgetallen, 8000 spellen elk:

| opstelling | partijen Zuid | partijen Noord | Noord |
|---|---|---|---|
| beide Ednieuw | 1107 | 1218 | 52,4 % |
| beide Ronlog | 540 | 570 | 51,4 % |

Er zit dus ongeveer één tot twee procent voordeel aan de kant Noord, los van de
speelwijze. Bij Ednieuw is dat met 2325 partijen net aantoonbaar (z ≈ 2,3), bij
Ronlog met 1110 partijen nog niet (z ≈ 0,9).

Dat verklaart wat er in de app te zien is. Een lange sessie met Ronlog op Zuid
en Ednieuw op Noord gaf 2952 tegen 3246 partijen — Noord 52,4 %, **precies het
percentage dat twee identieke Ednieuws ook opleveren**. Ronlog verliest dus niet
van Ednieuw; Zuid verliest van Noord. Van de spellen won Ronlog er zelfs iets
meer dan een Ednieuw op diezelfde stoel: 50,2 % tegen 49,5 %.

Het voordeel zit in de motor en niet in de omzetting: beide versies draaien
dezelfde code, en het ijkspoor is regel voor regel gelijk. Het komt dus uit 1994.

### Wat de meting oplevert

Partijen zijn een luidruchtige maat. Op **punten per spel** gemeten, in beide
opstellingen, 18.000 spellen elk:

| | Zuid | Noord |
|---|---|---|
| Zuid Ednieuw, Noord Ronlog | 95,95 | 97,23 |
| Zuid Ronlog, Noord Ednieuw | 95,02 | 98,60 |

* **speelwijze**: Ednieuw 97,27 tegen Ronlog 96,12 — Ednieuw **+1,15** per spel
* **stoel**: Zuid 95,48 tegen Noord 97,91 — Noord **+2,43** per spel

Beide effecten bestaan dus, en de stoel weegt ruim twee keer zo zwaar als de
speelwijze.

### Twee gebreken in de motor van 1994

**1. `troef_bepalen()` kijkt bij Noord in de kaarten van de tegenstander.**

`KJJ.C` regel 729–733, en één op één zo overgezet:

```c
L8 if (tafel[VRAGER-1][n].gegarandeerd) zekereslagen[tafel[VRAGER-1][n].kleur]++;
L8 if (hand [VRAGER-1][n].gegarandeerd) zekereslagen[hand [VRAGER-1][n].kleur]++;
```

`hand[]` en `tafel[]` zijn níet op Zuid/Noord geïndexeerd maar op **0 = mijn
kant, 1 = de tegenpartij** — dat zet `Vulhanden()` zo klaar. `VRAGER-1` klopt
dus alleen als VRAGER 1 is. Maakt Noord troef (VRAGER 2), dan telt hij de zekere
slagen van *Zuid* mee in zijn troefkeuze.

Dat is te zien in de uitkomst: bij vrijwel gelijke kaartsterkte (75,97 tegen
76,03 troefpunten) kiezen de twee kanten verschillende kleuren — Noord kiest
harten 7176 keer tegen Zuid 6168, en ruiten 3225 tegen 3947.

**Dit is gerepareerd** — zie punt A11.

**2. Het schudden is scheef.**

`KJJ.C` regel 195–199:

```c
for(m=31;m>=0;m--) { card = random(m); ... deeltabel[card] = deeltabel[m]; }
```

`random(m)` levert 0..m-1, terwijl een eerlijke Fisher-Yates 0..m nodig heeft.
De kaart die op dat moment op plek `m` ligt kan bij die stap dus nooit gekozen
worden. De Swift-versie doet exact hetzelfde, want zo hoort het bij een getrouwe
omzetting.

Gemeten over 200.000 keer delen:

| stapel | kaartpunten per spel |
|---|---|
| hand Zuid | 29,98 |
| hand Noord | 29,99 |
| tafel Zuid | **15,19** |
| tafel Noord | **14,82** |
| dicht Zuid | **15,17** |
| dicht Noord | **14,85** |
| **totaal Zuid** | **60,34** |
| **totaal Noord** | **59,66** |

Zuid krijgt structureel 0,69 kaartpunt per spel meer. Eén afzonderlijke kaart
komt tot 10 % vaker of minder vaak in een bepaalde stapel dan hij hoort. Dit
gebrek werkt dus juist *tegen* het voordeel van Noord in, en maskeert het
gedeeltelijk.

### De twee gebreken verklaren het voordeel samen helemaal

Gemeten met beide kanten op de vuistregels van Ednieuw, 30.000 spellen per
opstelling, in punten per spel:

| motor | Zuid | Noord | voordeel Noord |
|---|---|---|---|
| 1994, beide gebreken | 96,45 | 99,69 | **+3,24** |
| troefkeuze gerepareerd | 96,91 | 99,04 | **+2,13** |
| ook het schudden gerepareerd | 97,49 | 97,78 | **+0,29** |

Die laatste 0,29 is bij dit aantal spellen niet van nul te onderscheiden. Ook de
troefkleuren komen dan gelijk: Zuid koos harten 5013 keer, Noord 5003 — waar dat
in de oude motor 4629 tegen 5350 was.

En het delen wordt eerlijk: het verschil van 0,687 kaartpunt per spel loopt terug
tot 0,073.

### Beide zijn gerepareerd

De troefkeuze in punt A11, het schudden in punt A13. Het voordeel van de kant
Noord is daarmee weg; wat overblijft is 0,29 punt per spel en dat is bij 30.000
spellen niet van nul te onderscheiden.

**Wat hier eerder fout stond.** Op grond van één toernooi van 1000 spellen was
geconcludeerd dat Ronlog structureel minder roem haalt. Over 10.000 spellen
klopt dat niet: daar haalt hij er juist meer (171.900 tegen 167.300). Dat
verschil van 1000 spellen was ruis. Wat wél standhoudt is dat Ednieuw vaker pit
haalt — ruwweg anderhalf tot twee keer zo vaak — en dat is honderd punten per
keer.
