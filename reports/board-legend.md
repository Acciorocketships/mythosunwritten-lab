# The board says what its colours mean, and aiming turns both ways

Two things a player met in every fight, and neither of them was about the
simulation.

The first: the board overlay paints the ground in nine colours and nothing on
screen said what any of them was. One of them is amber, amber is a cliff edge,
and a cliff edge is the one square a shove off can cost a character its whole
life. A fight can be fought across a field of them.

The second: the aim ring only turned forward, so overshooting the thing you
wanted cost you a lap of everything in sight — and a character your own had
never met was offered as a number with a gap where a name goes.

---

## 1. Every colour is explained, off the table the ground is painted from

The obvious fix is a hand-written list of colours beside a hand-written list of
meanings. That fix goes stale the first time a colour changes and says nothing
when it does. So there is one table, `render/board_legend.gd`, and it is read
twice: `render/main.gd` asks it what colour a cell is and paints that, and
`render/ui/legend_panel.gd` asks it for the same rows and draws a swatch and a
word for each. Neither knows how many colours there are.

| colour | what the ground is | how a cell is asked |
|---|---|---|
| dark plate | no ground | `CombatBoard.is_hole` |
| dull red | built on | `CombatBoard.blocks_move` |
| warm amber | a cliff edge | `CombatBoard.is_cliff_edge` |
| pale cool | one storey up | `CombatBoard.storey_at` above the ground storey |
| cool white | you may stand | everything that is none of the above |
| cool green | you may step | `BoardControls.marks`' `move` |
| warm rose | weapon covers | its `reach` |
| pale blue | minion may go | its `minion` |
| bright plate | picked now | its `picked` |

A cell can be more than one of these at once — a cliff edge one storey up is
both — so the table is in the order a cell is tested and the first row that fits
is the one it is painted in. That order is also the order the legend is read in.

Here it is on screen, at the window the game ships in, over a board with amber
squares all across it. It is built for a run with somebody playing and hides
itself while no lattice is drawn, so a play run with no fight in it looks exactly
as it did before, and a `--board` frame taken for a report has no panel over it:

![The play stage with the tactical lattice painted on the meadow, amber squares
scattered across it, and a legend panel in the top-right corner naming all nine
colours: no ground, built on, a cliff edge, one storey up, you may stand, you
may step, weapon covers, minion may go, picked
now](assets/board-legend-t20.png)

    xvfb-run -a ./run_render.sh --seed 1234 --scenario play --play --board --journal \
        --camera 0 16 20 --aim 2 \
        --input "6:tab,8:tab,10:tab,12:quoteleft,14:quoteleft,16:quoteleft" \
        --screenshot-ticks "9:reports/assets/board-legend-t9.png,20:reports/assets/board-legend-t20.png"

The run says from outside that the panel was on the screen and how much of it:

    render-shell legend scale=1 x=791 y=8 w=353 h=91 colours=9

Nine colours drawn, which is every row of the table.

## 2. Aiming turns both ways

`Tab` aims at the next thing in sight and **`** — the key directly above it —
at the one before. It is that key because every letter on the keyboard already
means something; the pair is under one finger.

The ring is the observation's own list, in the observation's own order, and the
same run above walks it forward three times and back three times. Its order for
this stage is `#2 Hob`, `#3` (Rill, unmet), `#4 pile`, `#5 chest` — the
characters nearest-first and then the objects nearest-first, exactly as
`Observation` assembles them:

    render-shell play t= 8 aims at #2 Hob (commander) 6.0 away
    render-shell play t= 8 aims at #3 this character has not met it (commander) 30.0 away
    render-shell play t=10 aims at #4 pile (pile) 4.0 away
    render-shell play t=13 aims at #3 this character has not met it (commander) 30.0 away
    render-shell play t=16 aims at #2 Hob (commander) 6.0 away
    render-shell play t=16 aims at #5 chest (object) 5.0 away

Three presses of `Tab` walk `#2 → #3 → #4`; three of **`** walk `#3 → #2 → #5`,
which is the same list read backwards and round the end of it. The whole log is
`reports/board-legend.log`.

## 3. Nothing is offered with a blank name

The stranger across the meadow used to read `#3 (character) 30.0 away` — a
number and a gap. What goes in the gap now is the packet's own reason there is
no name, quoted: `Observation` writes `this character has not met it`,
`not in line of sight` or `it has no name` beside every absence, and which of
those it is is not decided at the keyboard. `sim/surroundings.gd` carries that
sentence out on the row instead of dropping it, and carries the packet's own
word for what the thing is — `commander`, `pile`, `chest` — instead of the
three-way sort it files rows under.

Nothing was narrowed to get there. What may be aimed at is still every row the
observation holds, which `TestPlayerActions` asserts against
`Observation.of()` directly; a stranger is a thing you may aim at, and now it is
a thing you can read.

![The same stage with the play panel reading "no.3 this character has not met it
(commander) 30.0 away"](assets/board-legend-t9.png)

## 4. What is pinned

`tests/test_board_legend.gd`, 193 checks, four claims:

1. every colour on the table has a meaning, no two colours are the same, and no
   meaning is blank;
2. on a board holding all five kinds of cell, the colour a cell is painted is
   the colour filed under the row that cell reads as — and all five rows are
   reached;
3. the panel draws one swatch per row of the table, in the table's order and in
   the table's colour, and its lines are the table's own words;
4. no file under `render/` but the table itself writes one of those colours
   down — read out of the source as four numbers rather than as a spelling — so
   "the two cannot disagree" is a fact about the tree.

`tests/test_player_actions.gd` gained two more: the ring's order and contents
are the observation's, forward walks it, back walks it the other way, a press
back undoes a press forward, and from nothing aimed at each direction starts at
its own end of the ring; and no row is offered without something to call it,
with the reason for a missing name being one of `Observation`'s three and never
the interface's own words.

Fifteen suites were re-run over the change together and all of them pass, 3329
checks and no runtime error: `reports/board-legend-suites.log`, from

    ./run_tests.sh test_board_overlay test_board_legend test_render_shell \
        test_player_input test_player_actions test_player_combat \
        test_player_inventory test_bargain test_observation \
        test_character_sheet test_layering test_ui_fit test_ui_panel \
        test_ui_digits test_ui_readout

`tests/test_ui_fit.gd` now measures the legend with the rest, at all three
windows, with the sheet shut, the sheet open and a fight on. That is what said
the panel could not live in the bottom-right corner: at 1152x648 with the sheet
open, another panel down there is a panel off the edge. It sits under the combat
readout instead, which is the corner the board is already read from.
