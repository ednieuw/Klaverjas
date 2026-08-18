# Klaverjas

Klaverjas for two players, against the computer. Originally written in Turbo C for DOS,
now rebuilt as a Windows 11 desktop program in C# and as a Swift app for iPad, iPhone
and Mac. The hand-drawn cards from the 1990 original are still there, pixel for pixel.

## Where it came from

The program was born on a camping holiday in Guillermie, a village near Vichy in France,
where we played this game every evening after dinner. The hard part was the statistics:
working out the odds that the opponent holds a particular card, with no books at hand.
After buying a calculator that could do factorials the formula was found, and it is still
called *Guilermie* in the source. The cards were drawn on millimetre paper with coloured
pencils in the sun; the first version of the program followed at home in September 1990.

## The game

Klaverjas is normally played by four. In this two-player variant the third and fourth
player's cards lie on the table: eight per side, four face up with four face down beneath
them. You play for yourself and for your table.

Trumps are chosen first, and the computer decides at random who leads. The opening card
may come from your hand or from the table, but the reply must come from the table — so a
trick runs hand, table, table, hand or table, table, hand, hand.

**Ranking.** Trumps: J 9 A 10 K Q 8 7. Other suits: A 10 K Q J 9 8 7. You must follow
suit; if you cannot, you must trump; if trumps were led you must play higher when you can.

**Points.** A=11, 10=10, K=4, Q=3, J=2, and 9, 8, 7 score nothing. In trumps: J=10, 9=14,
A=11, 10=10, K=4, Q=3. Three cards in sequence (A K Q J 10 9 8 7) are worth 20 meld, four
in sequence 50, and four of a kind 100. King and queen of trumps together are worth 20.
The last trick adds 10. Take every point in the deal and you get 100 extra, or 200 if the
other side chose trumps. A match runs to 1500 points.

The cards keep their Dutch letters: **A**as, **H**eer, **V**rouw, **B**oer — ace, king,
queen, jack.

## Two computer players

You can pick who plays each side, and watch them play each other:

- **Ed** — the rules of thumb from the original program, with the Guilermie odds.
- **Loggen** — R. Loggen's version, which searches the trick through instead of judging it.

They are close. Loggen wins slightly more deals (about 51%) because he plays for meld;
Ed is ahead on raw card points. *Options → Fast play without cards* runs them against each
other with no drawing at all, a few thousand deals a second, and the statistics screen
shows how it adds up.

## Running it

The finished program is in `Klaverjas-app/` — a single self-contained `Klaverjas.exe` that
needs nothing installed. Start it with `/en` for English, `/snel` to go straight to fast
play.

To build from source:

```bash
dotnet publish Klaverjas/KlaverjasWin -c Release -r win-x64 --self-contained -o Klaverjas/Klaverjas-app
```

## What is in this folder

| | |
|---|---|
| `KJ/` | the original Turbo C sources from 1990–1994 |
| `KJBeide/` | both C versions side by side, including R. Loggen's |
| `KlaverjasWin/` | the C# program — `Engine/` is the game, `Ui/` is Windows |
| `KlaverjasTest/` | headless test harness; also proves the engine is portable |
| `KlaverjasSwift/` | the iPad, iPhone and Mac version |
| `spoor-*.txt` | reference traces used to check that nothing drifted |

`LEESMIJ-CSharp.md` documents the port in full, in Dutch: where every file came from and
every place the new version departs from the old one.

## One old bug, fixed

The DOS version awarded nothing for four of a kind — the page on ednieuw.nl warned about
it for years. It works now.

---

©2026 Ed Nieuwenhuys — [ednieuw.nl](https://ednieuw.nl)
