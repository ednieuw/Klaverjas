# Klaverjas

Klaverjas for two players, against the computer. Originally written in Turbo C for DOS,
now rebuilt as a Windows 11 desktop program in C#. The hand-drawn cards from the 1990
original are still there, pixel for pixel.

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

- **Ednieuw** — the rules of thumb from the original program, with the Guilermie odds.
- **Ronlog** — R. Loggen's version, which searches the trick through instead of judging it.

They are close. Over 500 deals played twice with the sides swapped, Ronlog takes 511 deals
to Ednieuw's 489 and is a little ahead on points and meld; Ednieuw goes for the whole deal
more often and takes pit roughly twice as often. *Options → Fast play without cards* runs
them against each other with no drawing at all, a few thousand deals a second. The
statistics window opens with it and keeps up while they play.

The counts survive closing the program: they are kept in
`%AppData%\Klaverjas\klaverjas.json`, along with your choice of players and language.
**Clear** in the statistics window resets the counts and leaves those choices alone.

## Running it

The finished program is in `Klaverjas-app/` — a single self-contained `Klaverjas.exe` of
about 162 MB that needs nothing installed, not even .NET. Start it with `/en` for English,
`/nl` for Dutch, `/snel` to go straight to fast play.

To build it, run `bouw-exe.cmd`, or:

```bash
dotnet publish KlaverjasWin -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o Klaverjas-app
```

`LEESMIJ-BOUWEN.md` has the details, including how to check that nothing has drifted.

## What is in this folder

| | |
|---|---|
| `KJ/` | the original Turbo C sources from 1990–1994 |
| `KJBeide/` | both C versions side by side, including R. Loggen's |
| `KlaverjasWin/` | the C# program — `Engine/` is the game, `Ui/` is Windows |
| `KlaverjasTest/` | headless test harness; also proves the engine is portable |
| `bouw-exe.cmd` | builds `Klaverjas-app\Klaverjas.exe` |
| `test-motor.cmd` | runs the engine without a screen |
| `spoor-v11.txt` | reference trace used to check that nothing drifted |
| `genkaarten.py` | rebuilds `KlaverjasWin/Ui/KaartData.cs` from `KJ/KJKRT.C` |

`LEESMIJ-CSharp.md` documents the port in full, in Dutch: where every file came from and
every place the new version departs from the old one.

## Three old bugs, fixed

The DOS version awarded nothing for four of a kind — the page on ednieuw.nl warned about
it for years. It works now, and the count is kept per side.

Two more came to light in August 2026, both from 1994 and both in North's favour. When
North chose trumps he read a flag that was not his, counting South's certain tricks as his
own; and the shuffle was not a fair Fisher-Yates, so the card lying in the last slot could
never be picked at that step. Together they gave the North side over three points a deal.
Both are repaired, and the sides now come out even.

---

©2026 Ed Nieuwenhuys — [ednieuw.nl](https://ednieuw.nl)
