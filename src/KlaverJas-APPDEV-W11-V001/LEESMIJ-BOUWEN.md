# Klaverjas voor Windows 11 — bouwmap V001

Deze map bevat alles wat nodig is om `Klaverjas.exe` voor Windows 11 te maken,
en niets anders. Hij is bedoeld als vertrekpunt: kopieer hem naar
`KlaverJas-APPDEV-W11-V002` zodra je aan de volgende versie begint, dan blijft
V001 staan als de versie die het deed.

Vastgelegd op 18 augustus 2026, vanuit `Klaverjas/KlaverjasWin`.

## Bouwen

Dubbelklik op `bouw-exe.cmd`, of typ in een venster:

```
dotnet publish KlaverjasWin -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o Klaverjas-app
```

Dat is precies het recept waarmee de bestaande `Klaverjas-app\Klaverjas.exe`
gemaakt is: het resultaat is één bestand van 161.775.099 bytes (ca. 162 MB),
zonder losse dll's ernaast. Zonder `IncludeNativeLibrariesForSelfExtract` blijven
er vijf native dll's naast de exe liggen; zonder `PublishSingleFile` worden het
255 losse bestanden. Beide werken, maar dan is het geen enkel bestand meer dat je
zomaar kunt doorgeven.

De exe draait op elke Windows 11-machine; .NET hoeft er niet op geïnstalleerd te
staan, want de hele runtime zit erin. Vandaar de omvang.

Startopties: `/en` voor Engels, `/snel` om meteen naar snelspel te gaan.

## Wat je nodig hebt

.NET SDK 8.0 (hier gebruikt: 8.0.424). Die staat op deze machine niet in het
systeempad maar in het profiel: `%USERPROFILE%\.dotnet\dotnet.exe`. De
`.cmd`-bestanden zoeken hem daar en vallen anders terug op `dotnet` uit het pad.
Verder niets — geen NuGet-pakketten, geen Visual Studio.

## Wat er in deze map staat

| | |
|---|---|
| `KlaverjasWin/` | het programma. `Engine/` is het spel, `Ui/` is Windows Forms |
| `KlaverjasTest/` | motortest zonder scherm; compileert `Engine/` rechtstreeks mee |
| `bouw-exe.cmd` | maakt `Klaverjas-app\Klaverjas.exe` |
| `test-motor.cmd` | draait de motortest, zie hieronder |
| `genkaarten.py` + `KJKRT.C` | maken `KlaverjasWin/Ui/KaartData.cs` opnieuw |
| `Documentatie/` | LEESMIJ-CSharp.md, README.md, TACTIEKEN.md, spoor-csharp.txt |

`bin/` en `obj/` zitten er bewust niet in; die maakt de compiler zelf.

## De kaarten

De 32 handgetekende kaarten uit 1990 zitten als code in
`KlaverjasWin/Ui/KaartData.cs`. Dat bestand is gemaakt door `genkaarten.py` uit
de oorspronkelijke Turbo C-bron `KJKRT.C`, en staat hier al klaar — je hoeft het
script alleen te draaien als je aan de tekeningen zelf iets verandert:

```
python genkaarten.py
```

Het script schrijft ook een Swift-versie weg in een map `KlaverjasSwift/`; die
map is in deze bouwmap niet aanwezig en wordt dan aangemaakt. Voor Windows kun je
hem negeren.

## Nakijken of er niets verschoven is

`test-motor.cmd spoor 200 1 spoor-nieuw.txt` schrijft per gespeelde kaart een
regel weg. Vergelijk dat met `Documentatie\spoor-csharp.txt` (zelfde aanroep,
zaad 1): zijn ze gelijk, dan speelt de motor nog precies hetzelfde als in V001.
Zonder argumenten draait `test-motor.cmd` 2000 spellen en toont de statistiek.

## Bij een volgende versie

`KlaverjasWin.csproj` zet `DebugType` op `none`, zodat er geen bronpaden van deze
machine in foutmeldingen belanden. Wil je een fout natrekken met regelnummers,
zet hem dan tijdelijk op `embedded`.
