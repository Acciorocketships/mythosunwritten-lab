# Every panel fits the window the game actually ships in

The interface is pixel art drawn over a 3D world and multiplied by a whole
number. Until this change the whole number came from one line —

```gdscript
art_scale = maxi(1, int(window.y) / DESIGN_HEIGHT)   # DESIGN_HEIGHT := 320
```

— and nothing afterwards asked whether what had been laid out at that number
still fitted inside the window. It did not. `project.godot` has no `[display]`
section, so the game ships in Godot's own default **1152x648**, and at that size
a 320-pixel design height picks 2, and two times the layout is taller than the
window.

Everything below is quoted from runs of the shipped shell. The shell prints
every panel's placed rectangle in screen pixels when it stops, which is what
makes this a measurement rather than a look.

## 1. Before: three panels off the bottom, one off the right

`xvfb-run -a ./run_render.sh --seed 1234 --scenario play --play --sheet --journal --input 10:f,14:1,22:2,28:f,32:3,40:f,44:x,52:tab,54:f,58:o --screenshot-ticks 62:…png`

```
render-shell sheet    scale=2 x=16  y=16  w=574 h=712
render-shell readout  scale=2 x=16  y=16  w=538 h=428
render-shell dialogue scale=2 x=676 y=922 w=596 h=110
render-shell trade    scale=2 x=676 y=750 w=596 h=164
```

`xvfb-run -a ./run_render.sh --seed 1234 --scenario battle --play --readout --board --journal --input 6:bracketleft,…,58:0 --screenshot-ticks 28:…png`

```
render-shell sheet    scale=2 x=16  y=16  w=574 h=676
render-shell readout  scale=2 x=734 y=16  w=538 h=642
render-shell dialogue scale=2 x=676 y=802 w=596 h=110
render-shell trade    scale=2 x=676 y=680 w=596 h=114
```

In a 1152x648 window, in the bag run: the open sheet ends 80 pixels past the
bottom, the trade panel starts 102 pixels *below* the bottom of the window and
the dialogue panel 274 below — they are not clipped, they are placed off screen
altogether, and both also end 120 pixels past the right edge. In the fight run:
the readout ends 120 pixels past the right edge and 10 past the bottom, taking
the end-turn button with it; the sheet ends 44 past the bottom; the trade panel
starts 32 pixels below the window and the dialogue panel 154 below.

![The fight before: the readout runs off the right edge and the button row is
cut in half at the bottom, so the end-turn control is not on
screen](assets/window-fit-before-fight-t28.png)

![The bag before: the sheet is open and every other panel has been pushed off
the window, so a person equipping something cannot see the engine's answer to
it](assets/window-fit-before-bag-t62.png)

## 2. The rule now answers to the panels

```gdscript
static func scale_that_fits(window: Vector2, needed: Vector2) -> int:
	if needed.x <= 0.0 or needed.y <= 0.0:
		return 1
	return maxi(1, mini(int(window.x / needed.x), int(window.y / needed.y)))
```

`needed` is how much room the panels this run built actually want, in art
pixels: the larger of the frame's own combined minimum — exact, and the whole
answer once every panel is showing — and the arrangement `build` made, added up
from the panels themselves so that a panel which is hidden this second because
the world has nothing to say through it still counts. It only ever grows within
a run, so the interface never rises and falls in size while somebody is talking.

A design height has an answer only for the sizes it was written for. This has an
answer for any window, which is the whole difference.

## 3. After: inside the window, at the shipped size and either side of it

The same two commands, and then the bag run again at two more window sizes
(`--resolution` on the engine, ahead of the shell's own arguments).

| window | run | panel | placed rectangle | inside? |
|---|---|---|---|---|
| 1152x648 | bag, sheet open | sheet | x=8 y=8 w=287 h=356 | yes |
| 1152x648 | bag, sheet open | trade | x=846 y=499 w=298 h=82 | yes |
| 1152x648 | bag, sheet open | dialogue | x=846 y=585 w=298 h=55 | yes |
| 1152x648 | fight | readout | x=875 y=8 w=269 h=321 | yes |
| 1152x648 | fight | sheet | x=8 y=8 w=287 h=338 | yes |
| 1152x648 | fight | trade | x=846 y=524 w=298 h=57 | yes |
| 1152x648 | fight | dialogue | x=846 y=585 w=298 h=55 | yes |
| 1280x960 | bag, sheet open | sheet | x=8 y=8 w=287 h=356 | yes |
| 1280x960 | bag, sheet open | trade | x=974 y=811 w=298 h=82 | yes |
| 1280x960 | bag, sheet open | dialogue | x=974 y=897 w=298 h=55 | yes |
| 1280x720 | bag, sheet open | sheet | x=8 y=8 w=287 h=356 | yes |
| 1280x720 | bag, sheet open | trade | x=974 y=571 w=298 h=82 | yes |
| 1280x720 | bag, sheet open | dialogue | x=974 y=657 w=298 h=55 | yes |
| 2560x1440 | bag, sheet open | sheet | x=16 y=16 w=574 h=712 | yes |
| 2560x1440 | bag, sheet open | trade | x=1948 y=1142 w=596 h=164 | yes |
| 2560x1440 | bag, sheet open | dialogue | x=1948 y=1314 w=596 h=110 | yes |

1152x648 and 1280x960 are both inside the band the old rule overflowed in
(`350 * floor(h / 320) > h`); 1280x720 is outside it and the old rule happened to
come out right there for the readout alone — though not for an open sheet, which
it drew 748 pixels tall in a 720-pixel window.

The last row is the one that shows the rule is not simply pinned at 1x: given a
window with room for it — 2560x1440 has room for two of the 644x685 art pixels
this run's panels want — it picks **2**, and everything still lands inside.

![The fight after: the whole readout is on screen, and the second row of
buttons — UNIT, GOES, SEND, END, LEAVE — is complete, so the end-turn control
can be pressed during a fight](assets/window-fit-fight-t28.png)

![The bag after: the sheet is open top-left and the four panels it used to
displace are all on screen and readable — what was aimed at and what the world
answered bottom-left, the trades standing and the dialogue heard
bottom-right](assets/window-fit-bag-t62.png)

## 4. The pixel idiom survives

A whole-number scale and a nearest-neighbour filter, measured on a real frame by
`tools/measure_ui.gd` — the share of pixels whose colour is in neither the pack's
files nor this project's three, and the share of colour changes that do not fall
on a multiple of the interface scale:

| frame | scale | off-palette | off-grid |
|---|---|---|---|
| `window-fit-sheet.png` (1280x720) | 1 | 0 of 86080 = 0.0000% | 0 of 17062 = 0.0000% |
| `window-fit-bag-2560x1440.png` | 2 | 0 of 363688 = 0.0000% | 0 of 37828 = 0.0000% |

The second row is the one that means something: at 2x an edge landing between
two art pixels would show up, and 37,828 colour changes are all on the grid.

## 5. The test that would have caught it

`tests/test_ui_fit.gd` builds the panels a play run builds, hands them a real
world, and measures where each showing panel landed at all three windows — with
the sheet shut, with the sheet open and with a fight on — through the shell's own
`geometry_of`. Laying out a container is normally the engine's next idle frame
and a suite is one call inside one frame, so the suite hands each container its
own sort notification from the top down, which is the work that frame would have
done.

Run against the old rule, it fails 34 checks, naming each panel and where it
went:

```
- in a play run with the sheet open at (1152.0, 648.0) the trade panel is laid
  out at [P: (676, 954), S: (596, 114)], which is not inside the window it is
  drawn in
```

Against the rule as it now stands: `PASS  ui fit  100 checks`.

## 6. A render-only change, and it shows

| | before | after |
|---|---|---|
| seed-1234 headless fingerprint, 100 ticks | `32656f55cc5eeb1c` | `32656f55cc5eeb1c` |
| render digest, bag run | `f5e1218587f11c3c` | `f5e1218587f11c3c` |
| render digest, fight run | `ccaebd6d0e1a85dc` | `ccaebd6d0e1a85dc` |

`./run_tests.sh --layers-only`:

```
layer check: OK -- res://sim references nothing in the render layer
combat check: OK -- res://render draws the fight and holds none of it
interface check: OK -- res://render/ui names its art through sprout_pack.gd alone
asset check: OK -- res://sim names asset tags and no asset
```

No panel gained or lost a control, and nothing under `render/` decides anything
or holds any simulation state: the change is the rule that picks one number.

## 7. What this does not fix

The panels a play run builds want about 644x685 art pixels between them at their
fullest, and no window this game is played in has room for two of that, so the
shipped window is drawn at 1x. That is the honest answer at this panel size —
the alternative is a fraction, which blurs the art the user chose — but it does
mean the interface is only ever magnified on a much larger screen. Making the
panels themselves smaller, rather than the multiplier larger, is the next thing
to try if 1x reads as too small in play.

There is also a size below which nothing fits: a scale is never less than one,
so a window smaller than what the panels need at 1x would still overflow. No
window in the band this item is about is anywhere near that.
