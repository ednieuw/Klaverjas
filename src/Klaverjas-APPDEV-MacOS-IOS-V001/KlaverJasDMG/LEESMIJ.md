# Klaverjas voor de Mac weggeven

`Klaverjas-1.0.dmg` is een schijfkopie met het spel erin. Sleep hem naar
iemand toe en die sleept de app naar Programma's.

* **1,3 MB**, werkt op Apple Silicon én Intel (universeel gebouwd)
* **macOS 14 of nieuwer**
* Geen installatieprogramma, geen bijgeleverde bibliotheken, geen internet

Opnieuw maken na een wijziging:

```bash
./maak-uitgave.sh 1.1
```

Dat bouwt, ondertekent, maakt de schijfkopie en biedt hem zo mogelijk ter
waarmerking aan.

---

## Nu nog: de ontvanger krijgt een waarschuwing

Op deze Mac staat alleen een **Apple Development**-certificaat. Daarmee is de
app op andere machines niet geldig ondertekend, dus is hij ad-hoc ondertekend.
Het spel wérkt, maar bij de eerste start zegt macOS dat de ontwikkelaar niet te
verifiëren is. In `Lees mij.txt` staat hoe de ontvanger daar omheen komt:
rechtsklikken en Openen kiezen.

Voor vrienden is dat te doen. Voor onbekenden is het een drempel, en het ziet
er onbetrouwbaar uit.

## Zo wordt het een gewone dubbelklik

Je hebt het Developer Program al (team U533G62Q3B), dus dit kost alleen wat
handelingen — geen extra geld.

### 1. Certificaat maken

In Xcode: **Settings ▸ Accounts ▸** je Apple ID ▸ **Manage Certificates…** ▸
knop **+** linksonder ▸ **Developer ID Application**.

Controleer daarna:

```bash
security find-identity -v -p codesigning
```

Er hoort nu een regel met `Developer ID Application: Ed Nieuwenhuys (U533G62Q3B)`
bij te staan.

### 2. Wachtwoord voor waarmerken klaarzetten

Maak op https://appleid.apple.com een app-specifiek wachtwoord aan en bewaar het
onder de profielnaam die het script verwacht:

```bash
xcrun notarytool store-credentials "notary" \
  --apple-id "jouw@appleid.nl" \
  --team-id U533G62Q3B \
  --password "xxxx-xxxx-xxxx-xxxx"
```

Dat slaat het op in je sleutelhanger; je hoeft het daarna nooit meer in te
typen. **Doe dit zelf** — een app-specifiek wachtwoord hoort niet in een
gespreksvenster of in een script te belanden.

### 3. Opnieuw uitgeven

```bash
./maak-uitgave.sh 1.0
```

Het script ziet nu het certificaat én het profiel, ondertekent met de Developer
ID, biedt de schijfkopie aan bij Apple, wacht op het oordeel (meestal een paar
minuten) en niet het waarmerk aan het bestand vast. Daarna opent de app bij
iedereen met een gewone dubbelklik, ook zonder internet.

Ter controle hoort de laatste regel dan `accepted` te zeggen in plaats van
`rejected`.

---

## Waarom dit geen App Store-versie is

De App Store-versie wordt anders ondertekend (Apple Distribution) en gaat via
App Store Connect. Deze schijfkopie staat daar los van: je kunt hem rustig
weggeven terwijl de App Store-versie in beoordeling is. Beide komen uit dezelfde
broncode.
