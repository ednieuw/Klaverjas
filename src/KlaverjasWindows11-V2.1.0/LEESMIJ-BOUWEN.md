# Klaverjas voor Windows 11 — bouwen

Deze map bevat alles wat nodig is om `Klaverjas.exe` voor Windows 11 te maken,
en niets anders. De Swift-versie voor Mac, iPad en iPhone stond hier ook; die is
op 25 augustus 2026 weggehaald en woont verder op de MacBook.

Bijgewerkt op 25 augustus 2026, bij versie 1.1.

## Bouwen

Dubbelklik op `bouw-exe.cmd`, of typ in een venster:

```
dotnet publish KlaverjasWin -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o Klaverjas-app
```

Dat is precies het recept waarmee de bestaande `Klaverjas-app\Klaverjas.exe`
gemaakt is: het resultaat is één bestand van ruim 161 MB, zonder losse dll's
ernaast. Zonder `IncludeNativeLibrariesForSelfExtract` blijven
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
| `genkaarten.py` | maakt `KlaverjasWin/Ui/KaartData.cs` opnieuw uit `KJ/KJKRT.C` |
| `KJ/`, `KJBeide/` | de oorspronkelijke Turbo C-bronnen van 1990-1994 |
| `spoor-v11.txt` | het ijkspoor, zie hieronder |
| `LEESMIJ-CSharp.md` | de verantwoording van de hele omzetting |
| `TACTIEKEN.md` | wat elk tactieknummer betekent |

`bin/` en `obj/` zitten er bewust niet in; die maakt de compiler zelf.

## De kaarten

De 32 handgetekende kaarten uit 1990 zitten als code in
`KlaverjasWin/Ui/KaartData.cs`. Dat bestand is gemaakt door `genkaarten.py` uit
de oorspronkelijke Turbo C-bron `KJ/KJKRT.C`, en staat hier al klaar — je hoeft
het script alleen te draaien als je aan de tekeningen zelf iets verandert:

```
python genkaarten.py
```

## Nakijken of er niets verschoven is

`test-motor.cmd spoor 200 1 spoor-nieuw.txt` schrijft per gespeelde kaart een
regel weg. Vergelijk dat met `spoor-v11.txt` (zelfde aanroep, zaad 1): zijn ze
regel voor regel gelijk, dan speelt de motor nog precies hetzelfde als in versie
1.1. Zonder argumenten draait `test-motor.cmd` 2000 spellen en toont de
statistiek.

Er is een tweede toets die scherper is dan het spoor:

```
test-motor.cmd toernooi 500 1
```

500 spellen, elk twee keer gespeeld met de kanten omgewisseld. Dat hoort exact op
te leveren: Ednieuw 489 spellen tegen Ronlog 511, 92817 tegen 93403 punten, 16560
tegen 17660 roem, 117 tegen 106 nat, 48 tegen 28 pit, nul keer verzaakt. Er zit
geen toeval en geen kommagetal in die keten, dus "ongeveer" is niet goed genoeg.

## Bij een volgende versie

`KlaverjasWin.csproj` zet `DebugType` op `none`, zodat er geen bronpaden van deze
machine in foutmeldingen belanden. Wil je een fout natrekken met regelnummers,
zet hem dan tijdelijk op `embedded`.
