# Klaverjas — omzetting van Borland C naar C# / Windows 11

De originele Borland C-broncode uit 1994 is omgezet naar een .NET 8 WinForms-applicatie.
De spellogica en de volledige tactiek van de computer zijn regel voor regel overgenomen;
alleen de schermafhandeling is opnieuw geschreven.

## Wat waar staat

| Map | Inhoud |
|---|---|
| `KJ.C`, `KJJ.C`, `KJKRT.C`, `KEYBOARD.*` | de originele broncode, ongewijzigd |
| `KlaverjasWin/` | de C#-applicatie |
| `KlaverjasTest/` | testharnas dat de engine tegen zichzelf laat spelen |
| `Klaverjas-app/` | kant-en-klare `Klaverjas.exe`, draait zonder installatie |

### Herkomst van de C#-bestanden

| C#-bestand | Komt uit |
|---|---|
| `Engine/KjState.cs` | de globals en structs uit `KJ.C` |
| `Engine/KjEngine.cs` | `Delen`, `Vulhanden`, `kaarten_vrij`, `guillermie`, `kans_hoger`, `kans_kaart`, `bepaal_slagkans`, `troef_bepalen`, `legkaart`, `evalueer`, `evalueerspel` |
| `Engine/KjEngine.Roem.cs` | `bepaalroempunten`, `hoogsteroem`, `laagsteroem`, `bepaal_hoogsteroem`, `bepaal_laagsteroem` |
| `Engine/KjEngine.Ai.cs` | `speler1`, `tegenspeler1`, `speler2`, `tegenspeler2` |
| `Engine/KjEngine.BesteSlag.cs` | `bekijk_beste_slag` |
| `Engine/KjEngine.Regels.cs` | `check_valid` |
| `Engine/KjSpel.cs` | de speelloop uit `main()` plus `humaan()` en `error_legkaart()` |
| `Engine/CStr.cs` | bootst `strlen`/`strcpy`/`strcat`/`strpos` op char-arrays na |
| `Ui/KaartData.cs` | de pixeltekeningen uit `KJKRT.C`, automatisch gegenereerd |
| `Ui/OrigineleKaarten.cs` | bouwt de kaarten van 53×83 na, zoals `kaartvorm`/`aas`/`heer`/`vrouw`/`boer`/`Zeven`…`Tien` |
| `Ui/KaartenDansForm.cs` | de kaartendans uit `KRTDANS.C` / `kaarten()` |
| `Ui/SpelForm.cs`, `Ui/KaartTekenaar.cs` | nieuw: het speelscherm |

## Kaartendans

Via *Spel → Kaartendans* draait het demootje uit `KRTDANS.C`: er vliegt telkens één kaart
over een groen veld, botst tegen de randen en laat zijn spoor achter omdat er niets gewist
wordt. De bewegingsvergelijkingen zijn letterlijk overgenomen, inclusief de gehele deling
`posx += (x--)/2` die de horizontale snelheid stap voor stap laat afnemen en de kaart
vanzelf laat terugkeren. Het speelvlak wordt op een hele vergroting gezet, waardoor het
in een venster van 1300 bij 950 vrijwel exact op de 640 bij 480 van het origineel uitkomt.

Klik of druk een toets om te stoppen — net als het `kbhit()` van toen.

In het origineel was dit het **openingsscherm**: `main()` begon met `intro_text()`, dat
meteen `kaarten()` aanriep, en die lus draaide tot je een toets indrukte. Daarna kwamen de
spelregels en pas dan het spel. Dat is hier zo gehouden — de dans verschijnt meteen bij het
starten — en daarbovenop begint hij vanzelf opnieuw na drie minuten zonder muis- of
toetsbeweging.

Het delen gebeurt ondertussen gewoon door: de speelthread draait al en blijft netjes
wachten tot je de dans wegklikt. De automatische start komt alleen als het Klaverjas-venster
de aandacht heeft en niet geminimaliseerd is, zodat hij niet voor ander werk springt.
Beide zijn uit te zetten via *Opties → Kaartendans bij de start en na drie minuten*.

## Taal

Alle teksten die de speler ziet staan in `Engine/Taal.cs`, in het Nederlands en het Engels
naast elkaar. Zowel het scherm als de speellogica halen ze daar op, zodat er bij het
omschakelen niets in de verkeerde taal kan achterblijven. Wisselen kan tijdens het spelen
via *Opties → Taal*.

De kaarten zelf blijven ongewijzigd: de rangletters A, H, V en B zitten in de tekeningen
uit `KJKRT.C` en horen bij het origineel.

Wil je een aparte snelkoppeling die meteen in het Engels start, dan kan dat zonder tweede
versie van het programma:

```bash
Klaverjas.exe /en
```

Maak een snelkoppeling met die parameter en noem hem bijvoorbeeld *Klaverjas UK*. Eén exe
om te onderhouden, twee snelkoppelingen.

## Statistieken

*Spel → Statistieken* toont de tellingen die het origineel pas bij het afsluiten afdrukte
(het `printf`-blok aan het eind van `main()` in `KJ.C`), nu op elk moment op te vragen.
Dezelfde regels in dezelfde volgorde, met daaronder hoe vaak elke tactiek is toegepast.

De schermen komen uit `voor-windows/`, geschreven bij de Swift-versie. `Tactieknamen.cs`
is daar automatisch uit de Swift-bron gegenereerd en blijft daarom ongemoeid; tactiek 70
bestaat niet in 1994 maar is de zoekende speler, en dat opschrift staat daarom in `Taal`.

Controle: kaartpunten van Zuid en Noord samen horen 152 maal het aantal gewonnen spellen
te zijn. Klopt dat niet, dan zijn er spellen afgebroken doordat de computer verzaakte.

## Snel spelen zonder kaarten

*Opties → Snel spelen zonder kaarten* is het `SDEMO` uit het origineel, waar `Sputimage()`
het tekenen oversloeg. Er wordt niets meer gewacht tussen de slagen en het scherm wordt
hooguit vier keer per seconde bijgewerkt; de rest van de tijd gaat naar het spelen. Dat
levert zo'n 2500 spellen per seconde op. Beide kanten worden dan door de computer
gespeeld, want er valt niets te klikken. Ook de vorige slag in het zijpaneel blijft weg —
die kaartjes flitsen anders voorbij, en juist dat tekenwerk willen we overslaan.

Met `Klaverjas.exe /snel` begint het programma er meteen mee, met Ed als Zuid en Loggen
als Noord. Let op: in dit scherm wisselen de twee niet van kant, dus een positievoordeel
telt mee. Voor een eerlijke vergelijking is `toernooi` in KlaverjasTest de juiste maat —
die speelt elk spel twee keer, één keer met elk als Zuid.

## Twee speelwijzen

Naast de tactiek uit `KJ.C` zit de speelwijze van R. Loggen erin, uit `KJBeide/KJ2.C`.
Waar Ed met een lange reeks vuistregels werkt, rekent Loggen zetten door: hij speelt elke
eigen kaart proef, laat de tegenstander zijn beste antwoord geven, kiest zelf het beste
vervolg en middelt over alle kaarten die de tegenstander nog in handen kán hebben. Dat de
eerste drie kaarten exact door te rekenen zijn komt doordat de tafelkaarten open liggen —
alleen de handkaart van de tegenstander is echt onbekend.

Zijn waardering telt punten **plus roem**, met een minteken als de tegenstander de slag
pakt (`kjmaakslagtest` in `KJBeide/KJ0.C`). Daardoor speelt hij vanzelf op roem, zonder
dat daar aparte regels voor nodig zijn.

Loggen heeft zelf twee spelers: `kj1` krijgt de hele stok mee en ziet dus ook de kaarten
van de tegenstander, `kj2` werkt alleen met wat hij mag weten. Overgenomen is `kj2`, want
alleen die geeft een eerlijke vergelijking.

Overgenomen in `Engine/ZoekAi.cs`: de zoekboom, de keuzevoorkeuren uit `kj2welke` (bij
gelijke opbrengst geen zekere slag of troef weggeven) en de troefkeuze `kj2troef`.
`LegaleZetten` is een directe omzetting van zijn `kjlegaal`; de rest werkt op `KjState`,
want zijn eigen kaartadministratie zit daar al in. Nog niet overgenomen is de
blokker-markering ('B') uit `kj2status`.

Instellen per kant via *Opties → Speelwijze*. Zet Demo aan en geef Noord en Zuid een
andere speelwijze, dan spelen ze zonder jou tegen elkaar. Zonder scherm:

```bash
dotnet run --project KlaverjasTest -c Release -- toernooi 1000 1
```

Elk spel wordt twee keer gespeeld met dezelfde kaarten, één keer met elk als Zuid, zodat
een gelukkige verdeling niet meetelt. Over vier zaden van elk 2000 spellen:

| zaad | spellen gewonnen | punten |
|---|---|---|
| 1 | Ed 48,6% — **Loggen 51,4%** | Ed 50,1% — Loggen 49,9% |
| 42 | Ed 49,8% — **Loggen 50,2%** | Ed 50,6% — Loggen 49,4% |
| 777 | Ed 48,9% — **Loggen 51,1%** | Ed 49,8% — Loggen 50,2% |
| 20260815 | Ed 49,4% — **Loggen 50,6%** | Ed 50,3% — Loggen 49,7% |

Loggen wint dus consequent iets meer spellen, terwijl Ed op ruwe punten net voorblijft en
duidelijk vaker pit haalt. De uitkomst hangt sterk aan de troefkeuze: met Eds
troefbepaling kwam Loggen op 47,8% uit, met zijn eigen op ruim 50%.

Een valkuil bij het meten: als een van de twee verzaakt wordt het spel afgebroken en gaan
alle punten naar de tegenpartij, wat de uitslag flink scheeftrekt. `toernooi` telt die
afgebroken spellen daarom apart; die regel hoort nul te zijn.

De troefkeuze bleek daarbij zwaarder te wegen dan het doorrekenen zelf: met Eds
troefbepaling kwam Loggen op 48,7% uit, met zijn eigen op 49,9%. De drie verschillen zijn
dat Loggen troeflengte kwadratisch telt in plaats van lineair, hand en tafel apart
waardeert, en zijkleuren op hun drie hoogste kaarten beoordeelt in plaats van op zekere
slagen.

De schakelaar staat standaard uit, dus de tactiek van Ed speelt precies zoals altijd en
de ijksporen verschuiven er niet door.

## Naar Swift (iPhone / iPad / Mac)

De engine is platformonafhankelijk: in `Engine/` staat geen enkele verwijzing naar
Windows of System.Drawing, en `KlaverjasTest` bouwt hem al als gewone `net8.0`. Alleen de
vijf bestanden in `Ui/` zijn Windows-gebonden.

Om een Swift-vertaling te kúnnen bewijzen in plaats van te hopen, gebruikt de engine sinds
kort `Engine/Toevalsreeks.cs`: een generator van vier regels die in elke taal dezelfde
reeks oplevert. De Swift-versie staat als commentaar in dat bestand.

Met `spoor` schrijft de test een volledig verloop weg:

```bash
dotnet run --project KlaverjasTest -c Release -- spoor 200 1 spoor-csharp.txt
```

Elke regel is één gespeelde kaart:

```
spel;slag;volgnr;speler;kleur;kaart;tactiek     bijvoorbeeld  1;1;0;2;2;A;8
spel;=;troef;puntenZuid;puntenNoord;roemZuid;roemNoord
```

`speler` is 1..4 (Zuid hand, Noord hand, Zuid tafel, Noord tafel), `kleur` 0..3
(klaver, schoppen, ruiten, harten). `spoor-csharp.txt` in deze map is het ijkbestand:
200 spellen met zaad 1, 6601 regels. Levert de Swift-engine bij hetzelfde zaad exact dit
bestand op, dan speelt hij aantoonbaar dezelfde tactiek als het origineel uit 1994.

Handig om te weten voor het tekenwerk: de kaarten zijn 53×83 punten. Op een scherm met
drievoudige resolutie is dat precies de uitvoer van Scale3x, op tweevoudige die van
Scale2x. De pixeltekeningen vallen daardoor exact op de schermpixels, zonder vervaging.

### Eén bewuste afwijking: de superroem

De Swift-versie rekent op één punt anders dan het origineel en dan de C#-versie: **vier
gelijke kaarten in één slag leveren nu 100 roempunten op, en 200 bij vier boeren.**

In het origineel werd die roem nooit uitgekeerd. `bepaalroempunten()` heeft er wel een tak
voor — inclusief een pieptoon — maar `evalueer()` groepeert de vier kaarten van een slag
eerst op kleur en roept de functie alleen aan bij een groepje van meer dan één kaart. Vier
gelijke kaarten hebben per definitie vier verschillende kleuren, dus elk groepje bevat er
precies één en de tak wordt nooit bereikt. De teller `Superroem` bleef daardoor altijd op
nul staan.

Het komt ongeveer eens per 1700 spellen voor: in 20.000 spellen computer-tegen-computer
gebeurde het twaalf keer. In de 200 spellen van het ijkbestand komt het niet voor, dus
`spoor-csharp.txt` klopt nog steeds regel voor regel — maar dat bestand bewijst hiermee
niet langer dat beide engines in *alle* gevallen hetzelfde doen.

De tactiek van de computer is niet aangepast: hij houdt bij zijn kaartkeuze geen rekening
met deze roem, net zomin als het origineel dat deed.

## Foutmeldingen

`klaverjas-fout.txt` wordt alleen aangemaakt als er werkelijk iets misgaat, naast de exe.
Omdat het programma openbaar verspreid wordt staat `DebugType` op `none`: er komt geen los
`.pdb` mee en er staan geen bronpaden van de bouwmachine in de meldingen. Je ziet daardoor
wel welke methode het betrof, maar geen regelnummer. Wil je een fout natrekken, zet
`DebugType` in `KlaverjasWin.csproj` tijdelijk op `embedded` en bouw opnieuw; dan staan de
bestandsnaam en het regelnummer er weer bij, zonder los bestand.

## Je eigen kaarten

De kaarten zijn je originele tekeningen uit `KJKRT.C`. Die stonden daar als ASCII-art,
één teken per pixel, met per plaatkaart een eigen kleurtabel in de `switch` van de
bijbehorende functie (`aas` gebruikt `'c'` voor lichtblauw, `heer` gebruikt `'x'` voor
lichtmagenta, enzovoort). De kleurcode `'r'` staat voor `GREEN+i` en verschilt dus per
kaartkleur — dat effect is behouden, je ziet het aan het kasteel op de aas.

De data wordt uit de C-broncode gehaald door `genkaarten.py`; dat script schrijft
`KlaverjasWin/Ui/KaartData.cs`. Pas je de tekeningen in `KJKRT.C` aan, draai dan:

```bash
python genkaarten.py
```

`kaarten.png` in deze map is een contactafdruk van alle 32 kaarten plus de achterkant.
Die kun je zelf opnieuw maken met:

```bash
Klaverjas-app/Klaverjas.exe kaartenblad kaarten.png 3
```

Via *Opties → Oorspronkelijke kaarten* kun je omschakelen naar een moderne, gladde
kaartset; je eigen kaarten staan standaard aan.

### Indeling van het scherm

De indeling volgt die van het origineel:

* Een lichtgroen speelveld (`#66CE33`) van 130×230 waarop de lopende slag ligt. De vier
  kaarten krijgen daar de plek van hun speler, uit `krtposx`/`krtposy` in `legkaart()`:
  Noord legt bovenin (y 10 en 50), Zuid onderin (y 95 en 135). Aan de hoogte zie je dus
  meteen wie welke kaart legde. Het veld staat bij voorkeur tussen de handen van Noord en
  Zuid in, links van de tafelrijen; is het venster daar te laag voor, dan schuift het naar
  links naast alle rijen.
* Rechts vier rijen, alle tegen dezelfde rechterkant uitgelijnd zoals het origineel ze
  vanaf x=560 naar links neerlegde: hand Noord, tafel Noord, tafel Zuid, hand Zuid.
* Onder elke tafelkaart die nog een dichte kaart onder zich heeft steekt die er vijf
  pixels uit, richting het midden van de tafel — bij Noord naar beneden, bij Zuid naar
  boven. Daaraan zie je per plek of daar nog een kaart onder ligt; het aparte stapeltje
  dat het origineel daarnaast op `320-i*20` tekende voegt daar niets aan toe en is
  weggelaten. Welke plek nog gedekt is komt uit `tzuid[]`/`tnoord[]` van de engine, niet
  uit het aantal resterende kaarten: zodra een plek leegraakt zijn dat verschillende
  dingen.
* Boven in beeld staat na elke slag wie hem won en wat hij opleverde, bijvoorbeeld
  "Slag 3 voor Noord, 20 roem". Na de achtste slag komt daar de uitslag van het spel
  achter; past die regel niet, dan wordt hij in kleinere letters gezet.
* De troefvraag staat op de rij dichte kaarten van Noord. Daar zit toch geen informatie,
  en zo blijft je eigen hand zichtbaar terwijl je kiest — het origineel legde er een
  sluier over het hele veld.

De achterkant van de kaarten is een ruitennet van elkaar kruisende diagonalen in blauw,
lichtblauw en lichtcyaan, met een witte bies. Het origineel gebruikte `INTERLEAVE_FILL`
in geel, wat op een egaal raster neerkwam.

### Schaling

De kaarten zijn per pixel getekend, dus ze worden **alleen op hele veelvouden** vergroot:
53×83, 106×166, 159×249. Het speelscherm zoekt de grootste factor die past en legt de
kaarten op hele pixelposities neer. Zo wordt er nergens geïnterpoleerd. Op een scherm van
2048×1104 komt dat uit op 2×; op een groter scherm gaat hij vanzelf naar 3×.

Het vergroten gebeurt met **Scale2x** (voor 3× met Scale3x), een algoritme voor pixelkunst:
per pixel wordt gekeken of twee buren aan weerszijden gelijk zijn, en zo ja dan wordt de
hoek van het nieuwe blokje met die buurkleur gevuld. Schuine lijnen — de speer van de boer,
de schouders van de schoppen, de bogen van de cijfers — verliezen daardoor hun trapjes,
terwijl vlakken en rechte randen scherp blijven. Er wordt niets vervaagd; het resultaat
gaat 1 op 1 naar het scherm, zonder verdere herschaling.

Dit gebeurt altijd; er is geen schakelaar meer voor.

### Uitlijning

De letters komen uit een nagebouwd 8×8 blokletterfont, omdat het BGI-standaardfont niet
in de broncode zit. De inkt van zo'n teken vult maar 6 à 7 van de 8 kolommen en zit
linksboven in het vak, dus centreren gebeurt op de gezette pixels en niet op het vak —
anders staat alles net naar linksboven.

De posities zijn daarbij rechtgetrokken:

* De rangletter stond op `x+19`, links van het midden en half over het linker hoeksymbool.
  Nu op `x+26`, precies tussen de symbolen op `x 2..15` en `x 37..50`.
* Verticaal stond hij op `y+2` met verticale centrering, waardoor de bovenste letter half
  boven de kaartrand viel. Nu op `y+9` en `y+74`, gelijk met de hoeksymbolen.
* De hoekcijfers stonden op `x+4`/`x+40` en `y+4`/`y+72`, wat links en boven tegen de rand
  aan liep en rechts en onder negen pixels ruimte overliet. Nu symmetrisch op `x 8`/`x 44`
  en `y 7`/`y 75`, met vier pixels marge rondom.

De tactieknummers uit het origineel (`TACTIEK=7`, `41`, `68`, …) zijn ongewijzigd
overgenomen, zodat je in de code kunt blijven terugzoeken welke regel de computer toepast.
Wat elk nummer betekent staat in `TACTIEKEN.md`.

## Bouwen en draaien

De kant-en-klare versie draaien (geen installatie nodig):

```bash
Klaverjas-app/Klaverjas.exe
```

Zelf opnieuw bouwen — de .NET 8 SDK staat in `%USERPROFILE%\.dotnet`:

```bash
"$env:USERPROFILE\.dotnet\dotnet.exe" build KlaverjasWin/KlaverjasWin.csproj -c Release
```

Engine testen: de computer speelt beide kanten en er wordt gecontroleerd op
uitzonderingen, op de puntensom van 152 per spel en op het aantal gespeelde kaarten.

```bash
"$env:USERPROFILE\.dotnet\dotnet.exe" run --project KlaverjasTest -c Release -- 50000
```

De speelloop met een menselijke speler testen (een automaat speelt Zuid):

```bash
"$env:USERPROFILE\.dotnet\dotnet.exe" run --project KlaverjasTest -c Release -- mens 300
```

## Bediening

* Klikken op een kaart speelt hem. Bij uitkomen mag je kiezen tussen je hand en je tafel;
  daarna licht alleen de stapel op die aan de beurt is.
* Troef kiezen kan met de muis of met de toetsen **K**, **S**, **R**, **H**.
* Na elke slag: klik of druk een toets om verder te gaan.
* Menu *Opties*: demo (computer speelt beide kanten), de kaarten van Noord tonen,
  en automatisch doorgaan zonder te klikken.

## Afwijkingen ten opzichte van het origineel

Bij de omzetting kwamen een paar plekken naar boven waar de C-code buiten arrays las of
ongeïnitialiseerde variabelen gebruikte. In C leverde dat een willekeurige waarde op; in C#
moest daar een keuze gemaakt worden. Alles staat met commentaar in de code gemarkeerd.

1. **`troef_bepalen`, variabele `Hijtafel`** — werd alleen gezet als `startvrager==1` en bleef
   anders ongeïnitialiseerd. Juist dat tweede geval treedt op zodra de computer troef kiest in
   een menselijk spel. Nu expliciet op de bedoelde waarde gezet (de tafelkaarten van de
   tegenstander). *Dit verandert het troefkeuzegedrag van de computer ten opzichte van het
   origineel, maar naar wat de code duidelijk bedoelde.*

2. **`check_valid`** — de test `iKrt==0` vergelijkt de array `iKrt[][]` met NUL in plaats van de
   lokale teller `IKrt`, en is dus altijd onwaar. Het gedrag is één-op-één overgenomen, niet
   "gerepareerd", omdat een reparatie de regelcontrole strenger zou maken dan het spel altijd
   geweest is.

3. **`speler1`, blok "als ik A en hij kale tien"** — indexeert `tafel[1][]` met de teller van de
   vorige lus (altijd 8, dus buiten de rij) in plaats van met `m`. Deze tak liep in de praktijk
   nooit; dat is zo gelaten.

4. **`bepaal_laagsteroem`** — roept `wie_vrager()` met verwisselde argumenten aan, waardoor de
   uitkomst altijd "niet gevonden" is. Dat pad is behouden zodat de kaartkeuze gelijk blijft.

5. **`bekijk_beste_slag`** — `Skleur` kan onderweg de waarde 5 krijgen (van een lege hand- of
   tafelpositie), waarna `kaart[40..47]` werd aangesproken. Nu wordt de kleur op elk gebruikspunt
   gecontroleerd, wat neerkomt op wat het origineel feitelijk deed: niets vinden.

6. **`speler1`, tactiek 13** — achter `if(bepaal_hoogsteroem(...)==0)` staat een losse puntkomma,
   waardoor het blok altijd wordt uitgevoerd. Zo gelaten.

7. **Vier gelijke kaarten leveren nu wél roem op.** *Dit is de enige plek waar het spelgedrag
   bewust afwijkt van 1994.* `bepaalroempunten()` heeft een tak voor vier gelijke kaarten
   (100 punten, 200 bij vier boeren) die `Superroem` ophoogt, maar die tak was onbereikbaar:
   `evalueer()` groepeert de vier kaarten van een slag eerst op kleur en roept de functie
   alleen aan bij een groepje van meer dan één kaart. Vier gelijke kaarten hebben per
   definitie vier verschillende kleuren, dus elk groepje bevat er precies één. `Superroem`
   bleef daardoor altijd op nul staan. `Evalueer()` bekijkt de slag nu ook als geheel.
   Komt ongeveer eens per 1700 spellen voor. De tactiek van de computer houdt er geen
   rekening mee, net zomin als het origineel dat deed. Zie `WIJZIGINGEN-Swift.md`, punt A1.

Verder vervangen: het tekenen van de kaarten (BGI-lijnen voor een 640×350 EGA-scherm →
schaalbaar GDI+), toetsenbord- en muisafhandeling (`KEYBOARD.LIB`, waarvan alleen de
binaire library bestond, geen broncode), en de blokkerende `getch()`-lus, die vervangen is
door een speelthread die op de UI wacht.

## Testresultaat

50.000 spellen computer-tegen-computer:

```
Uitzonderingen      : 0
Computer verzaakte  : 0
Puntensom != 152    : 0
Kaartentelling fout : 0
Spellen  Zuid/Noord : 24664 / 25336
```

Plus 318 spellen via de volledige speelloop met een automatische menselijke speler,
zonder vastlopers.
