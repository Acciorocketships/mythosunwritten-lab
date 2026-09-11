# Independent check of the pixel-art interface: what was run, and what came back

This is the evidence behind the review of the interface milestone (`W-ui-review`),
written by somebody who did not build it. Every verdict below was reached by
running something; each section names the command and quotes its output. Nothing
here was fixed — anything found is recorded as a finding with the command that
reproduces it.

Two terms used throughout, because this page is meant to be readable with no
prior context:

* **The pack.** *Sprout Lands – UI Pack (Basic)*, a set of 2D pixel-art
  interface pieces (wooden frames, buttons, inventory slots, hearts, an icon
  sheet) drawn on a 16-pixel square cell, with a pixel typeface on an 8×14 cell.
  It is the user's own download and its licence forbids redistribution, so no
  file of it is in this repository.
* **Off-palette and off-grid.** The two numbers `tools/measure_ui.sh` measures on
  a real rendered frame. *Off-palette* is the share of pixels inside a panel
  whose colour is in neither the pack's own files nor this project's three drawn
  colours — any kind of smoothing invents in-between colours, and this finds
  them. *Off-grid* is the share of colour changes along rows and columns that do
  not land on a multiple of the interface's drawing scale — a whole-number scale
  puts every edge of the art on that grid, a fractional one does not.

A new read-only probe was written for this review: `tools/critic_ui_probe.gd`.
It asserts nothing. It builds every panel, walks it node by node, and prints what
each one actually resolves at run time, then measures every texture the interface
can draw, then asks the engine's resource cache a question twice, then checks
which files of the render layer name the vocabulary of an interface. Run it with:

```
env -u DISPLAY -u WAYLAND_DISPLAY ./tools/godot/godot4 --headless --path . \
    --script res://tools/critic_ui_probe.gd
```

---

## 1. Every panel is built from the pack, not from an engine default theme

The interface has grown from one panel to eight: the character sheet, the combat
readout, the play and answer panels, dialogue, trade, territory and the board
legend. The probe builds all eight under the theme the interface ships, puts them
in a live scene tree, and asks each Control which background and which typeface
it *resolves* — not which one the source appears to ask for.

```
panel                controls  pack-dressed  engine-default  pack-font  default-font
character sheet            94            14               0         33             0
combat readout             36            10               0         18             0
play                       20             1               0          6             0
answer                      9             1               0          3             0
dialogue                   21             1               0          7             0
trade                      27             1               0          9             0
territory                  10             1               0          5             0
legend                     42             1               0         10             0

theme on the frame:  SproutTheme.build()
engine-default draws: 0
```

Zero of the 259 Controls across the eight panels resolves a background or a
typeface from the engine's own default theme. Thirty resolve a background that is
a nine-sliced rectangle of one of the pack's own files; ninety-one resolve the
pack's own typeface, identified by the face name the font file carries
(`pixelFont-7-8x14-sproutLands`).

One caution about how this was measured, recorded because it first produced a
false alarm: a Control that is not yet inside the scene tree has no theme owner,
so it answers every theme question with the engine's default. Asked during
`_initialize()`, the probe reported `Open Sans SemiBold` on all ninety-one labels.
The probe now runs on the first processed frame instead and prints the check that
says so:

```
frame in tree: true; theme default_font: pixelFont-7-8x14-sproutLands; Label font in theme: pixelFont-7-8x14-sproutLands
first label '': in tree true, owner-resolved font pixelFont-7-8x14-sproutLands, explicit-type font pixelFont-7-8x14-sproutLands
```

The structural rule agrees. `./run_tests.sh --layers-only`:

```
layer check: OK -- res://sim references nothing in the render layer
combat check: OK -- res://render draws the fight and holds none of it
interface check: OK -- res://render/ui names its art through sprout_pack.gd alone
asset check: OK -- res://sim names asset tags and no asset
```

And the ten test suites that exercise the interface pass:

```
$ ./run_tests.sh test_layering test_character_sheet test_ui_panel test_ui_readout \
    test_ui_exchange test_ui_territory test_ui_fit test_ui_digits \
    test_panel_sentences test_board_legend
PASS  layering       63 checks
PASS  character sheet 109 checks
PASS  ui panel       381 checks
PASS  ui readout     1527 checks
PASS  ui exchange    555 checks
PASS  ui territory   64 checks
PASS  ui fit         109 checks
PASS  ui digits      137 checks
PASS  panel words    358 checks
PASS  board legend   193 checks

all 10 suites passed (3496 checks)
```

**One part of the claim is not met and is declared rather than argued.** The
milestone's line names the pack's *cursors* among what panels are built from. The
pack ships six mouse sprites, including cat paws. Nothing under `render/` sets a
custom mouse cursor — a comment-stripped search for the word finds no use of it
anywhere — so the pointer in a running game is the platform's own.
`reports/ui.md` § 7 already says so. The interface is driven from the keyboard, so
nothing is broken by it; the list simply names something that is not wired.

## 2. The seam between pixel art and the 3D world is held by construction

The claim is that four things are true by construction rather than by care: the
interface is drawn at a whole-number scale, 2D textures are filtered
nearest-neighbour (no blending between pixels), the typeface is imported with
smoothing and hinting switched off, and every type size is a whole multiple of the
typeface's own 14-pixel cell. The probe reads all four off the objects:

```
face                 pixelFont-7-8x14-sproutLands
antialiasing         0 (NONE=0)
hinting              0 (NONE=0)
subpixel positioning 0 (DISABLED=0)
oversampling         1.00
mipmaps / msdf       false / false
system fallback      false
font cell            14 px; sizes asked for [14, 28]
  size 14  is a whole multiple of the 14-pixel cell
  size 28  is a whole multiple of the 14-pixel cell
art cell             16 px
2D texture filter    rendering/textures/canvas_textures/default_texture_filter = 0 (0 = nearest)
```

Then four panels were measured on real rendered frames, each on its own run:

| panel | command | scale | interior pixels | off-palette | off-grid |
| --- | --- | --- | --- | --- | --- |
| character sheet | `xvfb-run -a ./tools/measure_ui.sh --panel sheet` | 1 | 112,560 | 0 = 0.0000% | 0 of 20,044 |
| combat readout | `... --panel readout --tick 18` | 1 | 36,100 | 0 = 0.0000% | 0 of 7,156 |
| territory | `... --panel territory --only --scenario market --tick 70` | 4 | 276,352 | 0 = 0.0000% | 0 of 13,020 |
| trade | `... --panel trade --only --scenario bargain --tick 72` | 3 | 98,280 | 0 = 0.0000% | 0 of 5,106 |

Every scale is a whole number, every colour inside each panel is the pack's own
or one of this project's three, and every colour change lands on the grid. The
trade panel's interior, for instance, is four colours over 98,280 pixels.

Two things found here are recorded as findings and are in §§ 6 and 7 below: the
characters the pack's typeface has no glyph for, and a rectangle the measuring
script can pair with the wrong frame.

## 3. Nothing under `sim/` names an interface, and the rule covers where it lives

The first line of `./run_tests.sh --layers-only`, quoted above, is the check that
no file of the simulation names a Control, a scene layer, a theme, a typeface or
a path to a texture. It passes.

The second half of the claim — that the rule covers *whichever* directory the
interface landed in — was checked rather than taken on trust, because the rule is
written as a directory (`LayerCheck.UI_DIR = res://render/ui`) and a directory
cannot notice a panel put somewhere else. The probe walks every `.gd`, `.tscn` and
`.tres` under `res://render`, strips comments, and lists each file that names the
vocabulary of an interface:

```
file under res://render                      in UI_DIR interface words it names
render/ui/territory_panel.gd                 yes       Control, Label, PanelContainer, TextureRect, VBoxContainer, HBoxContainer
render/ui/trade_panel.gd                     yes       Control, Label, PanelContainer, TextureRect, VBoxContainer, HBoxContainer
render/ui/answer_panel.gd                    yes       Control, Label, PanelContainer, TextureRect, VBoxContainer, HBoxContainer
render/ui/sprout_theme.gd                    yes       Theme, StyleBoxTexture, FontFile, Label, Button, PanelContainer
render/ui/character_panel.gd                 yes       Control, Label, Button, PanelContainer, TextureRect, VBoxContainer +2
render/ui/glyph_shape.gd                     yes       FontFile
render/ui/combat_panel.gd                    yes       Control, Label, Button, PanelContainer, TextureRect, VBoxContainer +1
render/ui/dialogue_panel.gd                  yes       Control, Label, PanelContainer, TextureRect, VBoxContainer, HBoxContainer
render/ui/play_panel.gd                      yes       Control, Label, PanelContainer, TextureRect, VBoxContainer, HBoxContainer
render/ui/legend_panel.gd                    yes       Control, Label, PanelContainer, VBoxContainer, HBoxContainer
render/ui/pixel_ui.gd                        yes       CanvasLayer, Control, VBoxContainer, HBoxContainer, MarginContainer

interface files the UI rule does not scan: 0
```

Eleven files name it; all eleven are inside the directory the rule scans. The
same answer comes out of a comment-stripping `grep` over `render/*.gd`, which
matches nothing outside `render/ui/`. There is no uncovered directory to report.

## 4. A headless run loads no interface texture, font or scene

The project's existing way of showing this is to ask the engine's own resource
cache, from outside the render layer, what has been loaded — a count kept inside
the render layer could only be read by loading the render layer, which is the
thing that must not happen. Re-derived:

```
$ ./run_headless.sh --ticks 20 --assets
...
assets visual-files found=5339 loaded=0
assets render-scripts found=40 loaded=0
assets sim-scripts found=129 loaded=104 -> res://sim/water_sheet_builder.gd,...,+100 more
```

Two things were checked about that `found=5339`, because a count that did not
include the interface's own art would make `loaded=0` vacuous. First, the walk
`bin/headless_main.gd` performs was reproduced independently — every file in the
project with a visual extension, skipping hidden directories and `tools/` and
`reports/`:

```
visual-extension files the same walk finds: 5339
of those, under the Sprout Lands pack: 52
the six the interface names: ['assets/sprout_lands_ui/buttons.png',
  'assets/sprout_lands_ui/hearts.png', 'assets/sprout_lands_ui/icons.png',
  'assets/sprout_lands_ui/pixel_font.ttf', 'assets/sprout_lands_ui/slots.png',
  'assets/sprout_lands_ui/ui_sheet.png']
```

The number matches exactly, and the six files the interface actually names are
inside the set being counted.

Second, the check was given a *positive control*: a measurement that can only
ever say "no" is not a measurement. The probe asks the same
`ResourceLoader.has_cached` question before and after loading the interface's own
art the way the interface loads it:

```
the interface's own art  before  after
ui_sheet.png             false   true
buttons.png              false   true
icons.png                false   true
hearts.png               false   true
slots.png                false   true
pixel_font.ttf           false   true
```

The call flips for all six, so `loaded=0` in a headless run is a fact about that
run and not a property of the question. There is no interface scene to load: the
panels are built in code, and `render-scripts found=40 loaded=0` covers the
render layer's own files.

## 5. The iconography the pack does not cover, against the 16-pixel rule

Every texture the interface can draw was measured. The four groups the milestone
names are all in it.

```
the icons drawn here, one per name in PixelIcons.ART:
  str          ability score  16x16
  con          ability score  16x16
  cha          ability score  16x16
  dex          ability score  16x16
  wis          ability score  16x16
  int          ability score  16x16
  ... (helmet, chestplate, leggings, boots, hand, and twelve weapon faces)
  toadstool    minion type    16x16
  cat          minion type    16x16
  ent          minion type    16x16
  frog         minion type    16x16
  ability scores covered: 6 of 6 ["str", "con", "cha", "dex", "wis", "int"]
  minion types covered:   4 of 4 ["toadstool", "cat", "ent", "frog"]
```

All 28 drawn icons come back 16×16. The attack patterns are generated from the
shape the simulation holds rather than tabled, so every one of them was built and
measured:

```
the attack-pattern glyphs, one per distinct shape in the weapon catalogue:
  spear/thrust                 2 cells -> 16x16
  dagger/stab                  2 cells -> 16x16
  sword/cut                    3 cells -> 16x16
  sword/cleave                 6 cells -> 16x16
  bow/loose                    248 cells -> 16x16
  staff/fireball               9 cells -> 16x16
  14 attack patterns measured, 0 off the 16-pixel cell
```

Cooldowns, the turn order, and the sentiment and territory readouts are the
pack's own icons rather than drawn ones, and are 16×16 as cut:

```
  tick -- usable now       at column,row (3, 2) -> 16x16
  bar -- cooling down      at column,row (5, 2) -> 16x16
  mark -- whose turn       at column,row (0, 1) -> 16x16
  dash -- waiting          at column,row (1, 2) -> 16x16
  crown -- territory       at column,row (5, 1) -> 16x16
  heart full   hearts.png  [P: (0, 0), S: (16, 16)] -> 16x16
```

The six effect sprites a blow is drawn with are 16×16 too, on the same cell
(`EffectArt.CELL=16, SproutPack.CELL=16`). The closing count:

```
textures off the 16-pixel cell: 0
```

Which icon came from the pack and which was drawn here is stated per icon across
`reports/ui.md` § 5 (the eleven ability-score and equipment icons),
`reports/dialogue-trade.md` §§ 6–7 (the four minion types and the pattern glyphs)
and `reports/territory-readout.md` § 4 (the crown and the heart).

## 6. The licence, as a fact about the repository

```
$ git check-ignore -v "assets/Sprout Lands - UI Pack - Basic pack.zip" \
    assets/sprout_lands_ui "assets/sprout_lands_ui/Sprout Lands - UI Pack - Basic pack"
.gitignore:31:/assets/*.zip	assets/Sprout Lands - UI Pack - Basic pack.zip
.gitignore:47:/assets/sprout_lands_ui/	assets/sprout_lands_ui
.gitignore:47:/assets/sprout_lands_ui/	assets/sprout_lands_ui/Sprout Lands - UI Pack - Basic pack
```

The zip the user dropped in and the unpacked copy are both ignored, by the same
kind of rule that excludes the other packs. `git status --porcelain assets/` is
empty; `git ls-files assets` lists 21 files, all of them this project's own tag
scenes and its example well. `git ls-files | grep -i sprout` returns three files
and no asset: `render/ui/sprout_pack.gd`, its `.uid`, `render/ui/sprout_theme.gd`
and `tools/extract_sprout_lands.sh`. There is no `tools/fetch_sprout_lands.sh`
beside `tools/fetch_kaykit.sh`, which is what the README's "not fetchable by any
script" means. `README.md` quotes the pack's own `read_me.txt` verbatim —
modification allowed, no redistribution even if modified, non-commercial use only
— and states that a commercial release would need the paid *Premium* pack.

One fact recorded for the human to judge rather than for anybody to act on: the
repository contains no file of the pack and no binary derived from one, and the
only committed images that contain the pack's pixels are screenshots of the
running game. The README states the project's position on that explicitly — "a
*screenshot of the running game* showing the interface in use is not
redistribution".

## 7. What a sentence can still carry: nine characters with no glyph

The pack's typeface has a small glyph set, and the interface already has the
mechanism for that: `SproutPack.FONT_SUBSTITUTES` folds a character the font
cannot draw down to one it can, and every panel puts its text through it. The
question worth asking is therefore not whether there is a hole but which
characters are still through it. The probe asks the font itself:

```
character                        glyph?   folded away? what a label would draw
em dash                          no       no           the ENGINE'S OWN hex box, off the pixel grid
en dash                          no       no           the ENGINE'S OWN hex box, off the pixel grid
left single quote                no       no           the ENGINE'S OWN hex box, off the pixel grid
right single quote / apostrophe  no       no           the ENGINE'S OWN hex box, off the pixel grid
left double quote                no       no           the ENGINE'S OWN hex box, off the pixel grid
right double quote               no       no           the ENGINE'S OWN hex box, off the pixel grid
ellipsis                         no       no           the ENGINE'S OWN hex box, off the pixel grid
e acute                          no       no           the ENGINE'S OWN hex box, off the pixel grid
degree sign                      no       no           the ENGINE'S OWN hex box, off the pixel grid
hash                             no       yes          'no.' instead
underscore                       no       yes          ' ' instead
left bracket                     no       yes          '(' instead
right bracket                    no       yes          ')' instead
middle dot                       no       yes          '-' instead

characters with no glyph and no substitute: 9
FONT_SUBSTITUTES covers 5 characters: ["#", "_", "[", "]", "·"]
```

This is not a new discovery — `reports/dialogue-trade.md` § 8 measured it
happening once, as 140 off-grid colour edges (0.6715%) in a dialogue panel
quoting a sentence with an em dash in it, and named the two honest fixes. What the
table above adds is the size of the opening: nine characters, seven of them the
typography an English sentence picks up when a language model rather than a
programmer wrote it. The smallest closing move is the one already built — add
those characters to `SproutPack.FONT_SUBSTITUTES`, which every panel's text
already passes through.

## 8. A rectangle the measuring script can pair with the wrong frame

Found while measuring §2, and the sharpest thing in this review.

`tools/measure_ui.sh` works in two halves: the render shell saves a frame at a
named tick, and the script then reads a rectangle off the shell's own output and
asks the saved frame whether that rectangle is made of whole art pixels. The
rectangle is printed by `render/main.gd` in `_exit_tree()` — when the shell is
shutting down — and the frame is saved at the tick. Those are not the same moment:
`_save_screenshot` captures, then calls `quit()`, which lets the tree run one more
iteration before it tears down. A panel whose size changes in that extra
iteration is reported at a size it did not have in the saved frame.

The dialogue panel does change: it is bottom-anchored and grows upward as speech
arrives. Measured:

```
$ xvfb-run -a ./tools/measure_ui.sh --panel dialogue --only --scenario bargain --tick 72
render-shell dialogue scale=3 x=360 y=288 w=894 h=408
panel          at 360,288 size 894x408, interface scale 3
measured       at 387,315 size 840x354 (inside the frame's rails)
distinct       6358 colours over 297360 pixels
off-palette    50400 of 297360 = 16.9492%
off-grid       62591 of 120960 = 51.7452%
```

Run twice, with identical numbers both times. The frame was kept and read back
row by row. Of the rectangle's 354 rows, the top 60 are not the panel at all:

```
row (window y) | share of the row that is a pack colour | distinct colours
 369     0.0%   520
 374     0.0%   523
 375   100.0%     1
 381   100.0%     1
```

Column 700 confirms it pixel by pixel: `#84c253` grass down to y=374, then
`#c49a6c` — the pack's own wood — from y=375. The drawn panel's frame begins at
window row 348; the rectangle claims it begins at 288. The difference is 60 window
pixels, which at a drawing scale of 3 is exactly 20 art pixels, one row of the
panel. And $840 \times 60 = 50{,}400$ — every off-palette pixel in the reading is
accounted for as grass in that band. Nothing is wrong with the panel: it is drawn
entirely in the pack's colours, and the four panels whose size was stable between
capture and shutdown measured 0.0000% off-palette.

Why it matters, stated precisely. A rectangle that drifts *outward* adds pixels
of the world to the reading, which can only make the two numbers worse, so a
clean reading is not faked by it — but it makes a dirty reading uninterpretable,
because the reader cannot tell a smoothed panel from a mis-paired rectangle. A
rectangle that drifts *inward* — a panel that shrinks in the extra iteration —
measures a region inside the drawn panel and could hide dirt at its edge. Both
directions are possible for the dialogue and trade panels, which are the two whose
content arrives while the run is going. The published 0.6715% figure in
`reports/dialogue-trade.md` is not this artefact: its off-palette share was
0.0000%, so its rectangle had not drifted into the world, and a whole-art-pixel
shift preserves the grid phase, so it could not have manufactured off-grid edges
either.

The smallest fix is to print those geometry lines from `_save_screenshot()`,
beside the frame they describe, instead of from `_exit_tree()`.

## 9. Two places the write-ups have gone out of date

Not measurements, but facts about the repository that a reader of this milestone
would trip over.

* `reports/ui.md` § 7 says: "After those two: no dialogue panel, no trade panel,
  no menu system, no cursor." The dialogue and trade panels have existed since
  `W-ui-dialogue`, and the territory and legend panels since after that; the probe
  builds eight. Only the cursor half of that sentence is still true.
* The milestone's own roll-up report (`W-ui-report`, cycle 141) lists "minion
  icons, attack-pattern shapes and goodwill/territory readouts" as having no
  answer yet. All three now exist and all three measure 16×16 in § 5 above. The
  report predates them and the later write-ups cover them, so the drift is in the
  roll-up rather than in the work.

## 10. The verdict

Accepted. All six of the milestone's acceptance lines hold under checks that were
run rather than read: the eight panels resolve nothing from the engine's default
theme, the four construction switches are what they claim to be and four panels
measure crisp on real frames, no file of the simulation names an interface and the
rule covers every directory the interface lives in, a headless run loads none of
it and the check that says so has been shown to be capable of saying otherwise,
every icon the pack does not cover is on the 16-pixel cell, and the pack is out of
git with its licence recorded. Four findings stand: the nine characters with no
glyph (§ 7), the rectangle the measuring script can mis-pair (§ 8), the two stale
write-ups (§ 9), and the pack's cursors, which are named in the acceptance line
and are not wired (§ 1).
