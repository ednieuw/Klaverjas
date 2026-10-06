/// Een korte uitleg van het spel, in beide talen.
///
/// Bewust hier en niet in `Taal`: dat bestand gaat over losse woorden en korte
/// regels, en deze lappen tekst zouden het onleesbaar maken.
///
/// De uitleg beschrijft wat de motor werkelijk afdwingt — `checkValid()` is de
/// baas, niet de folder. Vandaar ook de uitzondering bij het troeven: die staat
/// er niet voor de sier, hij zit echt in de regelcontrole.
public enum Handleiding {
    public struct Stuk: Sendable, Identifiable {
        public let id: Int
        public let kop: String
        public let tekst: String
    }

    /// De taal als parameter en niet uit `Taal.engels`: dan kan een proef beide
    /// talen naast elkaar leggen zonder aan die gedeelde waarde te zitten. Doet
    /// hij dat wel, dan valt een andere proef die er tegelijk op let zomaar om.
    public static func stukken(engels metEngels: Bool = Taal.engels) -> [Stuk] {
        let paren = metEngels ? engels : nederlands
        return paren.enumerated().map { Stuk(id: $0.offset, kop: $0.element.0, tekst: $0.element.1) }
    }

    private static let nederlands: [(String, String)] = [
        ("Waar het om gaat", """
        Klaverjassen met z'n tweeën: jij bent Zuid, de computer is Noord. \
        Wie het eerst bij 1500 punten voorstaat, wint de partij. Daarna \
        begint een nieuwe.
        """),

        ("De kaarten", """
        Tweeëndertig kaarten, van zeven tot aas. Ieder krijgt acht kaarten in \
        de hand, vier open op tafel en vier dicht daaronder. Speel je een \
        tafelkaart, dan draait de kaart eronder om en neemt haar plaats in.

        Je speelt dus uit twee stapels tegelijk: je hand, die de tegenstander \
        niet ziet, en je tafel, die open ligt voor allebei.
        """),

        ("Troef maken", """
        Wie het spel opent kiest de troefkleur. Beurten wisselen elk spel.

        Kiezen kan op twee manieren: met een van de vier knoppen, of door een \
        eigen kaart aan te tikken — de onderste twee rijen. De kleur van die \
        kaart wordt dan troef.

        In troef telt een andere volgorde: boer (20), negen (14), aas (11), \
        tien (10), heer (4), vrouw (3), acht en zeven (0).

        In de andere kleuren: aas (11), tien (10), heer (4), vrouw (3), \
        boer (2), negen, acht en zeven (0).

        Alle kaarten samen zijn 152 punten waard.
        """),

        ("Bekennen en troeven", """
        Je moet de gevraagde kleur bekennen als je die hebt.

        Kun je niet bekennen, dan moet je troeven. Ligt er al troef, dan moet \
        je overtroeven als je een hogere troef hebt.

        Eén uitzondering: staat de slag op dat moment al op jouw naam — je \
        andere stapel ligt hoog — dan hoef je niet te troeven en mag je alles \
        bijgooien.

        Wordt er troef gevraagd, dan moet je troef bekennen én overtroeven \
        zolang je een kaart hebt die boven de hoogste troef op tafel uitkomt.
        """),

        ("Roem", """
        Roem gaat naar wie de slag pakt, en telt bij de punten op.

        Drie opeenvolgende kaarten van één kleur: 20. Vier opeenvolgend: 50. \
        Voor roem is de volgorde aas, heer, vrouw, boer, tien, negen, acht, zeven.

        Heer en vrouw van troef in dezelfde slag — het stuk: 20. Dat komt bij \
        een reeks bovenop.

        Vier gelijke kaarten in één slag: 100, en bij vier boeren 200.

        De laatste slag levert 10 punten extra op.
        """),

        ("Pit en nat", """
        Haal je alle acht slagen, dan is dat pit: 100 punten extra. Lukt dat \
        de tegenpartij terwijl jij troef maakte, dan krijgt zij er nog eens \
        200 bij.

        Maak je troef en haal je niet meer punten dan de tegenpartij, dan ga \
        je nat: al je punten van dat spel gaan naar de tegenpartij.
        """),

        ("Spelen", """
        Kies een kaart uit je hand of van je tafel. Bij het uitkomen mag je \
        uit allebei kiezen; daarna licht de stapel op die aan de beurt is.

        In het groene veld ligt elke kaart op de plek van de stapel waar hij \
        vandaan komt: Noord boven, Zuid onder. Een kaart uit de hand ligt iets \
        naar buiten, een kaart van tafel iets naar binnen. Zo zie je van elke \
        gespeelde kaart waar hij vandaan kwam.

        Boven in beeld staat wat er zojuist gebeurde, met de troef en de stand \
        eronder. Voor de troef staat de kant die hem maakte: N of Z. Onderaan \
        staat de vorige slag nog na te kijken.

        Achter de knop Opties zitten de schakelaars, de speelwijze en de taal. \
        Daar kun je de computer beide kanten laten spelen, de kaarten van Noord \
        open leggen, en kiezen hoe de computer speelt.
        """),

        ("De drie speelwijzen", """
        Ednieuw volgt de vuistregels uit de oorspronkelijke versie van 1994: \
        zevenenzestig regels over wanneer je troef trekt, roem meepakt of juist \
        een lage kaart weggooit.

        Ronlog rekent in plaats daarvan de slag door. Hij speelt elke kaart die \
        hij mag spelen proef, laat de tegenstander er zijn beste antwoord op \
        geven, en middelt over de kaarten die hij niet kan zien.

        Claude speelt het hele spel door. Wat de tegenstander in handen heeft \
        kan hij niet zien, dus verdeelt hij die kaarten telkens opnieuw \
        willekeurig, binnen wat bekend is: wat er gespeeld en getoond is, en \
        in welke kleuren de tegenstander niet kon bekennen. Elke kaart die hij \
        mag spelen speelt hij zo tot het einde van het spel door, honderden \
        keren, met pit en nat erbij. De kaart met de beste uitkomst kiest hij. \
        Daarom heet het brute force.

        In het statistiekenscherm zie je hoe vaak elke regel is toegepast.
        """),
    ]

    private static let engels: [(String, String)] = [
        ("What it is about", """
        Klaverjas for two: you are South, the computer is North. Whoever is \
        ahead first at 1500 points wins the match. Then a new one starts.
        """),

        ("The cards", """
        Thirty-two cards, seven up to ace. Each side gets eight in hand, four \
        face up on the table and four face down beneath them. Play a table \
        card and the one beneath it turns over and takes its place.

        So you play from two piles at once: your hand, which your opponent \
        cannot see, and your table, which is open to both.
        """),

        ("Choosing trumps", """
        Whoever opens the deal picks the trump suit, and that alternates every \
        deal.

        There are two ways to choose: one of the four buttons, or a tap on one \
        of your own cards — the bottom two rows. That card's suit becomes the \
        trump suit.

        Trumps rank differently: jack (20), nine (14), ace (11), ten (10), \
        king (4), queen (3), eight and seven (0).

        In the other suits: ace (11), ten (10), king (4), queen (3), jack (2), \
        nine, eight and seven (0).

        All the cards together are worth 152 points.
        """),

        ("Following and trumping", """
        You must follow the suit led if you can.

        If you cannot follow, you must trump. If a trump is already on the \
        table, you must beat it when you hold a higher one.

        One exception: if the trick already stands in your name — your other \
        pile is holding it — you need not trump and may play anything.

        When trumps are led you must follow with a trump, and you must overtrump \
        for as long as you hold a card above the highest trump on the table.
        """),

        ("Meld", """
        Meld goes to whoever takes the trick and is added to the points.

        Three cards in sequence within one suit: 20. Four in sequence: 50. For \
        meld the order is ace, king, queen, jack, ten, nine, eight, seven.

        King and queen of trumps in the same trick — the marriage: 20, on top \
        of any sequence.

        Four of a kind in one trick: 100, or 200 for four jacks.

        The last trick is worth 10 extra points.
        """),

        ("A march, and going wet", """
        Taking all eight tricks is called a march — pit in Dutch. It is worth \
        100 points extra. If your opponent manages it while you chose trumps, \
        they get another 200 on top.

        Choose trumps and fail to score more than your opponent, and you go \
        wet: everything you scored that deal goes to them.
        """),

        ("Playing", """
        Pick a card from your hand or from your table. When leading you may \
        choose from either; after that only the pile whose turn it is lights up.

        In the green field each card sits where it came from: North at the top, \
        South below. A card from the hand lies a little further out, one from \
        the table a little further in. So for every card played you can see \
        where it came from.

        The line at the top says what just happened, with the trump suit and the \
        score below it. Before the trump suit stands the side that chose it: \
        N or S. At the bottom the previous trick stays in view.

        The Options button holds the switches, the playing style and the \
        language. There you can let the computer play both sides, show North's \
        cards, and choose how the computer plays.
        """),

        ("The three playing styles", """
        Ednieuw follows the rules of thumb from the original 1994 version: \
        sixty-seven rules about when to draw trumps, take the meld, or throw \
        away a low card.

        Ronlog works the trick out instead. He tries every card he is allowed \
        to play, lets the opponent answer it as well as they can, and averages \
        over the cards he cannot see.

        Claude plays the whole deal out. He cannot see what his opponent holds, \
        so he deals those cards out again and again at random, within what is \
        known: what has been played and shown, and the suits in which the \
        opponent could not follow. Every card he may play is played to the end \
        of the deal that way, hundreds of times, with march and wet included. \
        He picks the card with the best result. That is why it is called brute \
        force.

        The statistics screen shows how often each rule was applied.
        """),
    ]
}
