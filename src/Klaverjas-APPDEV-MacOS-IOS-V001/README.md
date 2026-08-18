# Klaverjas

Het Nederlandse kaartspel klaverjas voor twee: u tegen de computer. Voor
iPhone, iPad en Mac.

De speellogica komt uit een programma dat Ed Nieuwenhuys in 1994 in Borland C
schreef. Die is regel voor regel overgezet — eerst naar C#, daarna naar Swift —
en speelt aantoonbaar dezelfde tactiek als toen. De kaarten zijn de
oorspronkelijke pixeltekeningen uit `KJKRT.C`.

## Wat waar staat

| map | inhoud |
|---|---|
| `KJ.C`, `KJJ.C`, `KJKRT.C`, `KRTDANS.C`, `KEYBOARD.*` | het origineel uit 1994, ongewijzigd |
| `KlaverjasSwift/` | het Swift-pakket: engine, kaarten, scherm en gereedschap |
| `Klaverjas/` | het Xcode-project dat er een app van maakt |
| `appstore/` | schermafdrukken, voorvertoningsfilm en de teksten voor de App Store |
| `KlaverJasDMG/` | schijfkopie voor de Mac, plus het script dat hem maakt |
| `genkaarten.py` | haalt de kaarttekeningen uit `KJKRT.C` en schrijft ze als broncode |

## Bouwen en toetsen

```bash
cd KlaverjasSwift
swift test -c release
```

Zeventien toetsen in zeven suites, in een seconde of vijftien. Twee daarvan zijn
ijkproeven tegen de C#-versie:

* `spoor-csharp.txt` — 200 spellen met zaad 1, 6601 regels. De Swift-engine moet
  dat bestand regel voor regel opleveren; dan speelt hij aantoonbaar dezelfde
  tactiek als het origineel.
* `kaarten.png` — alle 32 kaarten plus de achterkant op drievoudige vergroting,
  pixel voor pixel vergeleken.

De app zelf komt uit `Klaverjas/Klaverjas.xcodeproj`.

## Gereedschap in het pakket

```bash
swift run -c release spoor 200 6 spoor-zaad6.txt   # speelverloop wegschrijven
swift run -c release kaartenblad kaarten.png 3     # contactafdruk van de kaarten
swift run -c release pictogram <map>               # programmapictogram
swift run -c release schermafdruk <pad> …          # schermafdruk zonder venster
swift run -c release film <pad.mp4> 1920 1080 nl   # voorvertoningsfilm
```

## Verder lezen

* `LEESMIJ-CSharp.md` — de omzetting van C naar C#, en de eigenaardigheden in de
  oude code die bewust zijn blijven staan
* `TACTIEKEN.md` — wat elk van de 67 tactieknummers betekent
* `WIJZIGINGEN-Swift.md` — waar de Swift-versie van de C#-versie afwijkt, en wat
  er aan de Windows-kant overgenomen moet worden
