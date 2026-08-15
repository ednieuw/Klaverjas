# Wat de Swift-versie anders doet

Bijgehouden zodat de C#-versie op de Windows-machine dezelfde kant op kan, en
beide programma's weer gelijk lopen. Per punt staat erbij of het moet (anders
spelen de twee versies verschillend) of dat het smaak is.

Bijgewerkt: 15 augustus 2026.

---

## Begin hier (ook als je dit voor het eerst leest)

Dit bestand is geschreven om op de Windows-machine gelezen te worden, door
iemand — of iets — dat deze wijzigingen niet zelf heeft gemaakt.

De Swift-versie staat in `KlaverjasSwift/`, de C#-versie in `KlaverjasWin/`.
Alleen **punt A1** moet echt overgenomen worden; zonder dat spelen de twee
versies vanaf nu verschillend. De rest is smaak.

Werkwijze:

1. Lees punt A1 en pas `KlaverjasWin/Engine/KjEngine.cs` aan.
2. Bouw en toets:

   ```bash
   dotnet build KlaverjasWin/KlaverjasWin.csproj -c Release
   dotnet run --project KlaverjasTest -c Release -- 50000
   ```

   De uitkomst hoort te blijven zoals in `LEESMIJ-CSharp.md` onder
   "Testresultaat": geen uitzonderingen, geen verzaken, puntensom altijd 152.

3. Controleer dat het ijkspoor niet verschoven is:

   ```bash
   dotnet run --project KlaverjasTest -c Release -- spoor 200 1 spoor-nieuw.txt
   ```

   `spoor-nieuw.txt` hoort regel voor regel gelijk te zijn aan
   `spoor-csharp.txt`. Is dat zo, dan is de wijziging goed ingedaald: in die
   200 spellen komt het geval niet voor.

4. Maak daarna het spoor waar het geval wél in zit:

   ```bash
   dotnet run --project KlaverjasTest -c Release -- spoor 200 6 spoor-zaad6.txt
   ```

   Leg dat naast `spoor-zaad6-swift.txt`, dat in deze map staat en met de
   Swift-engine gemaakt is. **De twee horen regel voor regel gelijk te zijn.**
   Zijn ze dat, dan doen beide versies weer precies hetzelfde — nu ook in het
   geval dat het ijkbestand van zaad 1 niet dekt.

   Wat je in dat bestand moet zien, op regel 3961:

   ```
   120;=;0;102;50;120;10
   ```

   Zonder de wijziging staat daar `120;=;0;102;50;20;10`: honderd roem minder
   voor Zuid, de vier vrouwen in slag 6. Dat is in het hele bestand van 6601
   regels de **enige** regel die verschilt — alle gespeelde kaarten blijven
   gelijk, want de tactiek verandert niet.

Wat je verder niet hoeft aan te raken: `KaartData.cs` is ongewijzigd, en
`genkaarten.py` draait op Windows precies zoals hij deed.

---

## A. Moet, anders spelen de versies verschillend

### A1. Vier gelijke kaarten leveren roem op

**Waar:** `KlaverjasWin/Engine/KjEngine.cs`, in `Evalueer()`.

`bepaalroempunten()` heeft sinds 1994 een tak voor vier gelijke kaarten (100
punten, 200 bij vier boeren) die `Superroem` ophoogt, maar die tak is
onbereikbaar. `Evalueer()` groepeert de vier kaarten van een slag eerst op
kleur en roept de functie alleen aan bij een groepje van meer dan één kaart.
Vier gelijke kaarten hebben per definitie vier verschillende kleuren, dus elk
groepje bevat er precies één. `Superroem` bleef daardoor altijd op nul staan.

In de Swift-versie wordt de slag als geheel bekeken. In C# komt dat hierop neer,
vlak vóór de regel `S.Roem[S.StartVrager - 1] += roem;`:

```csharp
// Vier gelijke kaarten, over de hele slag in plaats van per kleur. De tak in
// BepaalRoemPunten wordt nooit bereikt omdat hierboven op kleur gegroepeerd
// wordt, en vier gelijke kaarten vier verschillende kleuren hebben.
char n0 = S.Slag(S.SlagNr, 0).Naam;
if (n0 != 0
    && S.Slag(S.SlagNr, 1).Naam == n0
    && S.Slag(S.SlagNr, 2).Naam == n0
    && S.Slag(S.SlagNr, 3).Naam == n0)
{
    roem += (n0 == 'B') ? 200 : 100;
    S.Superroem++;
}
```

**Hoe vaak:** ongeveer eens per 1700 spellen. In 20.000 spellen
computer-tegen-computer gebeurde het twaalf keer.

**Het ijkbestand hoeft niet opnieuw.** In de 200 spellen van zaad 1 komt geen
enkele slag met vier gelijke kaarten voor, dus `spoor-csharp.txt` blijft precies
zoals hij is — voor en na de wijziging.

**Wel te controleren.** Deze zaden bevatten het geval wél, met het spelnummer
waar het voor het eerst optreedt:

| zaad | spel | slag | kaart |
|---|---|---|---|
| 6 | 120 | 6 | vier vrouwen |
| 11 | 118 | 8 | vier tienen |
| 18 | 190 | 6 | vier vrouwen |
| 34 | 182 | 8 | vier azen |
| 46 | 59 | 7 | vier vrouwen |

Na het aanpassen van de C#-code:

```bash
dotnet run --project KlaverjasTest -c Release -- spoor 200 6 spoor-zaad6.txt
```

`spoor-zaad6-swift.txt` in deze map is met de Swift-engine gemaakt en is waar
de C#-uitvoer mee moet overeenkomen. Precies één regel van de 6601 verschilt
tussen vóór en na de reparatie: regel 3961, de afsluitregel van spel 120, waar
de roem van Zuid van 20 naar 120 gaat.

Aan de Swift-kant is er een gelijkwaardig gereedschap:

```bash
cd KlaverjasSwift
swift run -c release spoor 200 6 spoor-zaad6-swift.txt
```

Dat levert hetzelfde bestandsformaat op, met CRLF, zodat de twee zo naast
elkaar te leggen zijn. Ter controle: `swift run -c release spoor 200 1` geeft
`spoor-csharp.txt` regel voor regel terug.

**Niet meeveranderd:** de tactiek van de computer. Hij houdt bij zijn kaartkeuze
geen rekening met deze roem, net zomin als het origineel dat deed. Zou je dat
wél willen, dan is dat een echte verandering van het spelgedrag en loopt het
ijkspoor daarna niet meer gelijk.

---

## B. Gedeeld gereedschap, al doorgevoerd

### B1. `genkaarten.py` werkt op beide machines en schrijft beide talen

De paden stonden hard op `C:\Users\ednie\...`; die staan nu ten opzichte van het
script zelf. Het script schrijft in één doorgang zowel
`KlaverjasWin/Ui/KaartData.cs` als
`KlaverjasSwift/Sources/KlaverjasKaarten/KaartData.swift`, uit dezelfde
tekeningen in `KJKRT.C`, zodat de twee niet uit elkaar kunnen lopen.

Het C#-bestand houdt CRLF als regeleinde, ook als je het script op een Mac
draait; anders lijkt het bestand in zijn geheel gewijzigd. Het bestand dat er nu
staat is byte voor byte gelijk aan het bestand van vóór deze wijziging.

**Op Windows hoeft er niets te gebeuren** — het script draait daar zoals het
altijd deed, en levert hetzelfde `KaartData.cs`.

---

## C. Nieuw in Swift, over te nemen als je wilt

Dit verandert niets aan het spelverloop.

### C1. Statistiekenscherm

De C#-versie heeft dit niet; het origineel drukte de tellingen pas af bij het
afsluiten. Nu op te vragen tijdens het spelen, met dezelfde regels en in
dezelfde volgorde als het `printf`-blok aan het eind van `main()` in `KJ.C`:
partijen, spellen, stand, kaartpunten, troefpunten, troefkaarten, roempunten,
pit, tegenpit, nat, superroem — Zuid en Noord in kolommen.

Daaronder de tactiektellers, vijf naast elkaar, precies zoals het origineel ze
afdrukte (`if((n/5)*5==n) printf("\n")`). Alleen de tactieken die gebruikt zijn,
de meest gebruikte eerst.

Alle tellers waren er al in `KjState`; er hoefde niets aan de engine bij.

### C2. De stand als tabel

Rechts in beeld staan punten, roem, totaal en partijen nu onder een kop
**Zuid | Noord**, met de getallen in kolommen in plaats van achter het label
aan.

### C3. De taal volgt het apparaat

De C#-versie start altijd in het Nederlands en heeft `Klaverjas.exe /en` nodig
voor de Engelse. De Swift-versie kijkt naar de voorkeurstaal van het apparaat:
staat Nederlands bovenaan, dan Nederlands, anders Engels. `/nl` en `/en` op de
opdrachtregel gaan daar nog steeds voor, en de schakelaar rechts in beeld blijft
gewoon werken.

Voor Windows zou hetzelfde kunnen met `CultureInfo.CurrentUICulture`, maar het
is de vraag of je dat daar wilt: de snelkoppeling met `/en` doet het werk al.

### C4. De uitslag van een spel blijft in beeld

`EvalueerSpel()` telt de punten bij het partijtotaal op en zet `puntenspel[]` en
`roem[]` daarna op nul. In `KjSpel` werd de momentopname voor het scherm daarná
gemaakt, zodat het paneel op het beslissende moment overal nullen liet zien: je
zag niet wie het spel won en met hoeveel.

In de Swift-versie worden de behaalde punten en roem vlak vóór `EvalueerSpel()`
bewaard en daarna in de momentopname teruggezet, samen met een vlag `spelUit`.
Het paneel toont de eindstand van het spel naast het bijgewerkte partijtotaal,
en zet "Slag 8 van 8" om in "Spel uit".

In C# zou dat neerkomen op: in `KjSpel.SpeelEenSpel()`, in de tak `if (S.SlagNr
== 8)`, eerst `S.PuntenSpel[0..1]` en `S.Roem[0..1]` in lokale variabelen zetten,
dan `EvalueerSpel()` aanroepen, dan `Snapshot()` maken en die vier waarden er
weer in schrijven.

Aan de engine verandert er niets; alleen het scherm krijgt te zien wat er al was.

### C5. `TACTIEKEN.md`: wat elk tactieknummer betekent

Nieuw document met alle 67 nummers en wat de computer bij elk nummer doet,
gegroepeerd per routine (uitkomen, tweede, derde en vierde kaart, bijspelen).
Geldt net zo goed voor de C#-versie en voor het origineel: de drie gebruiken
exact dezelfde nummers, nagelopen door de toekenningen naast elkaar te leggen.

---

## D. Bewust níet aangepast

* **De zes eigenaardigheden** uit `LEESMIJ-CSharp.md` onder "Afwijkingen ten
  opzichte van het origineel" — die horen zo, en repareren breekt het ijkspoor.
* **De rangletters A, H, V en B op de kaarten** blijven in beide talen staan.
  Ze zitten in de pixeltekeningen uit `KJKRT.C`; ze wijzigen zou de
  pixelvergelijking met `kaarten.png` breken.
* **Het onderschrift op het kaartenblad.** De C#-versie zet daar een regel in
  Segoe UI; dat lettertype staat niet op een Mac, dus de Swift-versie laat de
  strook leeg. Buiten de kaartvakken, dus de vergelijking merkt er niets van.
