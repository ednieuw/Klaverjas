namespace Klaverjas.Engine;

/// <summary>
/// Wat de computer doet bij elk tactieknummer, kort genoeg voor één regel.
///
/// De nummers komen uit de broncode van 1994 en zijn in alle drie de versies
/// dezelfde; TACTIEKEN.md beschrijft ze uitgebreider en vertelt waar in de code
/// ze staan. De nummers 44 en 61 zijn nooit toegekend.
///
/// Een eigen klasse en geen uitbreiding van Taal, zodat Taal.cs onaangeroerd
/// kan blijven. Automatisch overgezet uit
/// KlaverjasSwift/Sources/KlaverjasKit/Tactieknamen.swift, zodat de twee niet
/// uit elkaar kunnen lopen.
/// </summary>
public static class Tactieknamen
{
    private static string T(string nl, string en) => Taal.Engels ? en : nl;

    public static string Naam(int nr) => nr switch
    {
        0 => T("geen tactiek", "no tactic"),
        7 => T("Zekere slag met de meeste roemkans", "Sure trick with the best meld chance"),
        1 => T("Zekere tafelkaart, hij heeft een kale tien", "Sure table card, bare ten opposite"),
        2 => T("Zekere handkaart, hij heeft een kale tien", "Sure hand card, bare ten opposite"),
        50 => T("Mijn aas tegen zijn kale tien", "My ace against his bare ten"),
        41 => T("Kleur aanspelen om troef kwijt te raken", "Lead a suit to shed a trump"),
        10 => T("Bijna zekere slag van tafel, met roem", "Near-certain trick from table, with meld"),
        62 => T("Bijna zekere slag uit de hand, met roem", "Near-certain trick from hand, with meld"),
        9 => T("Zekere slag van tafel, geen troef", "Sure trick from table, no trump"),
        8 => T("Zekere slag uit de hand, geen troef", "Sure trick from hand, no trump"),
        57 => T("Zekere slag van tafel, troef trekken", "Sure trick from table, drawing trumps"),
        58 => T("Zekere slag uit de hand, troef trekken", "Sure trick from hand, drawing trumps"),
        47 => T("Kleur aanspelen die ik zelf niet heb", "Lead a suit I don't hold myself"),
        11 => T("Beste slagkans van tafel", "Best trick chance from the table"),
        63 => T("Beste slagkans uit de hand", "Best trick chance from the hand"),
        5 => T("Troef trekken met een lage kaart", "Draw trumps with a low card"),
        55 => T("Overige zekere slag van tafel", "Other sure trick from the table"),
        56 => T("Overige zekere slag uit de hand", "Other sure trick from the hand"),
        54 => T("Troef van tafel gebruiken", "Use the trump on the table"),
        13 => T("Lage kaart zonder roemkans", "Low card without meld chance"),
        14 => T("Lage kaart, geen troef", "Low card, no trump"),
        15 => T("De laagste kaart die er nog is", "The lowest card left"),
        40 => T("Enige kaart van die kleur op tafel", "Only table card of the suit led"),
        18 => T("De enige hogere troef", "The only higher trump"),
        19 => T("Hogere troef met de beste kans", "Higher trump with the best chance"),
        42 => T("Van de hogere kaarten de minste roem", "Least meld among the higher cards"),
        6 => T("De achtergehouden kaart alsnog spelen", "Play the card held back earlier"),
        45 => T("De troef die weg moest", "The trump that had to go"),
        12 => T("Troef van tafel kwijtraken", "Get rid of the table trump"),
        36 => T("Enige kaart van die kleur", "Only card of that suit"),
        66 => T("De enige hogere troef", "The only higher trump"),
        67 => T("Hogere troef met een goede kans", "Higher trump with a good chance"),
        37 => T("Hogere troef met de meeste roem", "Higher trump with the most meld"),
        38 => T("Enige kaart van die kleur", "Only card of that suit"),
        17 => T("Kan niet hoger: roem meepakken", "Cannot go higher: take the meld"),
        20 => T("Hogere troef met de meeste roem", "Higher trump with the most meld"),
        39 => T("Kan niet hoger: minste roem weggeven", "Cannot go higher: give away least meld"),
        30 => T("Enige hogere troef, of troef van tafel", "Only higher trump, or a table trump"),
        16 => T("Beste tafelkaart van de gevraagde kleur", "Best table card of the suit led"),
        21 => T("Tafelkaart die de uitkomst verslaat", "Table card that beats the lead"),
        22 => T("Partner heeft de slag: roem meepakken", "Partner has the trick: take the meld"),
        49 => T("Handkaart die de uitkomst verslaat", "Hand card that beats the lead"),
        4 => T("Slag is binnen: roem meepakken", "Trick is ours: take the meld"),
        23 => T("Minste roem weggeven, niet de tien", "Least meld away, but not the ten"),
        24 => T("Handkaart met de meeste roem", "Hand card with the most meld"),
        48 => T("Meeste roem zonder de slag over te nemen", "Most meld without taking the trick"),
        46 => T("Hogere kaart van die kleur", "Higher card of that suit"),
        3 => T("De minste roem weggeven", "Give away the least meld"),
        26 => T("Laagste troef van tafel erbij", "Add the lowest trump from the table"),
        27 => T("Laagste troef uit de hand erbij", "Add the lowest trump from the hand"),
        28 => T("Overtroeven met troef van tafel", "Overtrump with a table trump"),
        29 => T("Overtroeven met troef uit de hand", "Overtrump with a hand trump"),
        31 => T("Troef uit de hand met de beste kans", "Hand trump with the best chance"),
        59 => T("Keuze teruggedraaid: er is ingetroefd", "Choice withdrawn: someone trumped in"),
        43 => T("Slag is binnen: de hoogste roem", "Trick is ours: the highest meld"),
        32 => T("De kaart met de minste roem", "The card with the least meld"),
        51 => T("Kale tien afgooien nu het kan", "Discard the bare ten while it is safe"),
        68 => T("Duurste rommel uit de hand", "Priciest junk from the hand"),
        52 => T("Kale tien van tafel afgooien", "Discard the bare ten from the table"),
        69 => T("Duurste rommel van tafel", "Priciest junk from the table"),
        60 => T("Introeven uit de hand, om de roem", "Trump in from hand, for the meld"),
        25 => T("Introeven van tafel, om de roem", "Trump in from table, for the meld"),
        34 => T("Van die kleur de minste roem", "Least meld of that suit"),
        33 => T("Goedkoopste kaart van die kleur", "Cheapest card of that suit"),
        64 => T("Hogere troef bijgooien", "Add a higher trump"),
        65 => T("Laagste troef bijgooien", "Add the lowest trump"),
        53 => T("Goedkoopste kaart, geen troef", "Cheapest card, no trump"),
        35 => T("Gooi maar wat: de goedkoopste", "Anything goes: the cheapest"),
        _ => T("onbekend", "unknown"),
    };
}
