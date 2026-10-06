# De tactieknummers

Elke kaart die de computer legt krijgt het nummer mee van de regel die hem koos.
Die nummers komen uit de broncode van 1994 (`TACTIEK=7`, `41`, `68`, …) en zijn
bij de omzetting naar C# ongewijzigd gebleven, zodat je in de code kunt
blijven terugzoeken waarom de computer deed wat hij deed.

Ze staan in het statistiekenscherm, en in het spoorbestand als laatste veld van
elke regel.

De drie versies gebruiken exact dezelfde 67 nummers. Nagelopen door de
toekenningen (`TACTIEK=`, `Tactiek =`, `tactiek =`) uit `KJ.C`/`KJJ.C`,
`KlaverjasWin/Engine/` naast de oorspronkelijke C-bron te
leggen: geen enkel nummer zit in de ene versie wel en in de andere niet.

De volgorde hieronder volgt de routines, niet de nummers: de nummers zijn in de
loop der jaren toegekend in de volgorde waarin de regels erbij kwamen.

---

## Uitkomen — `speler1()`

De eerste kaart van de slag.

| nr | wat de computer doet |
|---|---|
| 7 | Zekere slag met de grootste kans op roem; van tafel of uit de hand, wat het meeste oplevert |
| 1 | Zekere tafelkaart, terwijl de tegenstander een kale tien (of kale troefnegen) op tafel heeft |
| 2 | Hetzelfde, maar de zekere kaart komt uit de hand |
| 50 | Ik heb de aas en hij een kale tien van die kleur op tafel — *deze tak loopt nooit, zie afwijking 3 in LEESMIJ-CSharp.md* |
| 41 | Ik heb troef op tafel en hij een kale aas of tien van een kleur die ik niet heb: die kleur aanspelen om van die troef af te komen |
| 10 | Bijna zekere slag (kans boven 85) met de grootste roemkans, van tafel |
| 62 | Hetzelfde, uit de hand |
| 9 | Zekere slag die geen troef is, van tafel |
| 8 | Hetzelfde, uit de hand |
| 57 | Zekere slag, nu ook troef, zolang de tegenpartij nog troef kan hebben — van tafel |
| 58 | Hetzelfde, uit de hand |
| 47 | Ik heb troef op tafel en hij een aas, tien of heer van een kleur die ik niet heb |
| 11 | Grootste slagkans boven 75, van tafel |
| 63 | Hetzelfde, uit de hand |
| 5 | Troef bij de tegenstander vandaan trekken met een lage kaart |
| 55 | Overige zekere slagen, nu zonder voorbehoud voor troef — van tafel |
| 56 | Hetzelfde, uit de hand |
| 54 | Troef van tafel gebruiken om slagen te halen; zet het vervolg voor tactiek 12 klaar |
| 13 | Lage kaart zonder roemkans, geen troef — *achter de test staat een losse puntkomma, waardoor het blok altijd uitgevoerd wordt; zie afwijking 6* |
| 14 | Lage kaart, geen troef |
| 15 | De laagste kaart die er nog is |

## Tweede kaart — `tegenspeler1()`

| nr | wat de computer doet |
|---|---|
| 40 | Maar één kaart van de gevraagde kleur op tafel: die dan |
| 18 | Meer troefkaarten, en precies één daarvan is hoger: die |
| 19 | Van de hogere troeven die met de beste slagkans (boven 40) |
| 42 | Doe alsof alleen de hogere kaarten van mij zijn, en speel daarvan de kaart die de minste roem weggeeft |

## Derde kaart — `speler2()`

| nr | wat de computer doet |
|---|---|
| 6 | Speler1 hield bij het uitkomen bewust een kaart achter; die komt nu |
| 45 | Vervolg op tactiek 41: de troef die weg moest |
| 12 | Vervolg op tactiek 54: de troef van tafel die weg moest |
| 36 | Maar één kaart van de gevraagde kleur: die dan |
| 66 | Precies één hogere troef |
| 67 | Hogere troef met een slagkans boven 50 |
| 37 | Van de hogere troeven die met de meeste roem |

## Vierde kaart — `tegenspeler2()`

| nr | wat de computer doet |
|---|---|
| 38 | Maar één kaart van de gevraagde kleur: die dan |
| 17 | De slag is al van mijn kant en ik kan niet hoger: de roem meepakken |
| 20 | Meerdere hogere troeven: die met de meeste roem |
| 39 | De slag is niet van mijn kant en ik kan niet hoger: zo min mogelijk roem weggeven |
| 30 | Precies één hogere troef — *dit nummer wordt ook in `bekijk_beste_slag` gebruikt, zie hieronder* |

## Bijspelen — `bekijk_beste_slag()`

Wat er gebeurt als geen van de vaste regels hierboven uitkomst gaf. Loopt van
"ik kan de slag halen" via "ik kan roem pakken" naar "gooi maar wat".

### Als tweede of derde kaart

| nr | wat de computer doet |
|---|---|
| 16 | Tweede kaart: de tafelkaart van de gevraagde kleur met de beste slagkans |
| 21 | Derde kaart, van tafel: kaart die beter scoort dan de uitkomstkaart |
| 22 | Derde kaart, van tafel: de slag staat al bij de partner, dus de hoogste roem meepakken |
| 49 | Derde kaart, uit de hand: kaart die beter scoort dan de uitkomstkaart |
| 4 | Derde kaart, uit de hand: slag al aan mijn kant, hoogste roem meepakken |
| 23 | Derde kaart: anders de kaart die de minste roem weggeeft (de tien uitgezonderd) |

### Als laatste kaart

| nr | wat de computer doet |
|---|---|
| 24 | Slag al aan mijn kant: de handkaart die de meeste roem oplevert |
| 48 | Hetzelfde, maar alleen kaarten die de slag niet alsnog overnemen |
| 46 | Een hogere kaart van de gevraagde kleur, geen troef |
| 3 | Anders de kaart die de minste roem weggeeft |

### Kleur niet kunnen bekennen

| nr | wat de computer doet |
|---|---|
| 26 | Slag staat al op eigen naam en er is ingetroefd: laagste troef van tafel erbij |
| 27 | Hetzelfde, uit de hand |
| 28 | Slag bij de tegenpartij: overtroeven met de goedkoopste troef van tafel |
| 29 | Hetzelfde, uit de hand |
| 30 | Eerste of tweede kaart zonder de gevraagde kleur: troef van tafel met de beste kans |
| 31 | Hetzelfde, uit de hand |
| 59 | De keuze vervalt: er is ingetroefd en mijn kaart is niet hoog genoeg — *zie de opmerking over dubbel tellen hieronder* |
| 43 | Slag al aan mijn kant met een goede kans: hoogste roem meepakken |
| 32 | Anders de kaart met de minste roem |
| 51 | Slag ruim aan mijn kant: kale tien uit de hand afgooien nu het nog kan |
| 68 | Slag ruim aan mijn kant: de duurste rommel uit de hand bijgooien (geen troef, geen aas) |
| 52 | Zoals 51, maar van tafel |
| 69 | Zoals 68, maar van tafel |
| 60 | Introeven uit de hand, maar alleen als daar roem mee te halen valt |
| 25 | Hetzelfde, van tafel |

### Restcategorie

| nr | wat de computer doet |
|---|---|
| 34 | De kaart van de gevraagde kleur die de minste roem weggeeft |
| 33 | De goedkoopste kaart van de gevraagde kleur, geen troef |
| 64 | Er is ingetroefd en ik kan niet bekennen: een hogere troef erbij |
| 65 | Niet ingetroefd en geen kleur: de laagste troef erbij |
| 53 | De goedkoopste kaart die geen troef is |
| 35 | Gooi maar wat: de goedkoopste kaart die er nog is |

---

## Bij het lezen van de tellingen

**0 betekent "geen tactiek".** De teller wordt op nul gezet voor elke zet;
blijft hij nul, dan is de kaart niet door een tactiekregel gekozen. Dat is
onder meer zo bij elke kaart die de menselijke speler zelf legt. Het
statistiekenscherm laat nummer 0 daarom weg.

**59 telt dubbel.** Die tak hoogt de teller zelf al op (`Tac[59]++`) én laat het
nummer achter in `TACTIEK`, dat aan het eind van de beurt nóg een keer geteld
wordt — tenzij een latere regel er een ander nummer voor in de plaats zet. Lees
59 dus als "hoe vaak een keuze is teruggedraaid", niet als "hoe vaak deze regel
de kaart koos".

**30 staat op twee plekken.** Zowel de vierde kaart in `tegenspeler2()` als het
bijspelen in `bekijk_beste_slag()` gebruikt nummer 30; de teller telt die twee
bij elkaar op.

**44 en 61 bestaan niet.** Die nummers zijn nooit toegekend.

**Vaak gezien.** In een lange reeks computer-tegen-computer staat 53 bovenaan
("de goedkoopste kaart die geen troef is") en daarna 40, 38 en 3 — de regels die
uitkomen als er weinig te kiezen valt. De lage nummers 1 en 2 komen zelden voor:
daar moet net een kale tien bij de tegenstander op tafel liggen.
