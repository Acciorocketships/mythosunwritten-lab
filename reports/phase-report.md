# The world so far: eight layers, dressed and lit

This is a fantasy role-playing game whose world is a running simulation, so first
there has to be a world. This phase built it: an endless landscape grown from one
whole number — the *seed* — assembled in 16-unit squares (*chunks*) around
whoever walks it, dressed in bought models and lit.

**Verified.** `./run_tests.sh` — 16 suites, 132,026 checks, exit 0.

## The eight layers, and the command behind each picture

Each still came from `xvfb-run -a ./run_render.sh ARGS --screenshot
"$PWD/reports/assets/NAME.png"`, `NAME` being the file under the picture. Only
`ARGS` differs.

**1. Ground** — one height per position, hashed from position and seed.

`--seed 1234 --screenshot-frame 150`

![Streamed ground at its ragged edge, a lit village](reports/assets/now-terrain.png)

**2. Biomes** — meadow, deep forest, highland, blossom grove and twilight marsh,
each with its own tints, fog, sky and light.

`--seed 13 --screenshot-tick 25`

![A blossom grove: pink trees, a dirt road](reports/assets/now-biomes.png)

**3. Water** — rivers, ponds and lakes on one sheet, 8.3% of the world.

`--seed 22 --screenshot-tick 50`

![A river through a blossom grove](reports/assets/now-water.png)

**4. Floating islands** — walkable land a stride above what it overhangs, and
unreachable plates in the far sky.

`--seed 1234 --start -329.8 -254.1 --paused --screenshot-frame 150`

![Two low plates on a ridge, ragged islands far above](reports/assets/now-islands.png)

**5. Villages and roads** — levelled ground, a road graph, bridges.

`--seed 1234 --start -473.8 -730.1 --paused --camera 8 10 18 --aim -1 --screenshot-frame 150`

![A stone bridge on a village road, a lit lantern](reports/assets/now-village-bridge.png)

**6. Flora and props** — one hashed decision per cell, by biome and context.

`--seed 1234 --start -88.8 4.7 --paused --camera 0 26 44 --aim 4 --screenshot-frame 150`

![Lit houses in deep forest, an island overhead](reports/assets/now-village.png)

**7. Grass** — instanced tufts, wind-blown, parting around whoever walks in.

`--seed 1234 --start 228 -60 --paused --camera 0 3.2 6.5 --aim 0.5 --screenshot-frame 120`

![Grass blades under firs, near and far blurred](reports/assets/grass-blades.png)
![Blades bending around a walker](reports/assets/grass-parting.gif)

**8. Light and air** (new) — key light and shadows, per-biome fog and sky, warm
fill, bloom, drifting motes, a warm lamp on everything that glows, and near/far
blur.

`--seed 1234 --start -216 -504 --paused --screenshot-frame 150`

![Twilight marsh: teal gloom, orbs pooling light](reports/assets/atmosphere-border-marsh.png)

## What of section 9 is realised, and what is not

**Built:** biomes, water, islands, settlements and paths, props, grass (absent
from headless runs by construction), and now the whole lighting stack.

**Not built.** No interiors — buildings are solid exteriors. Nothing links an
island to the ground; bridges are built only where a road crosses water. Water
reflects nothing, half the "amber windows mirrored in still water" beat. There is
no time of day, so a cool night gradient needs a dark biome. No village sits by
water, and none contains a workshop — a known layout defect, unfixed.

## The islands: no longer saucers, not yet unmistakable

You rejected the aerial layer — *"they currently look just like flying saucers"* —
and asked for irregular chunks of land closer to the ground, carrying trees and
water. They were rebuilt. Same seed and camera as picture 4; the lighting
changed too, so judge the shapes.

![Before: smooth discs on smooth cones](reports/assets/islands-saucers-before.png)

**Fact.** The old shape was three surfaces of revolution off one radius — round
outline, dome, cone — a saucer by construction. All three broke: the outline is
now offset blobs with inlets and peninsulas, the top a hill over three shelves,
the keel varying by direction. Relief rose from a flat 1.1–2.9 units to 35–50% of
the radius. **Verdict:** close up they read as torn land carrying trees and
ponds.

![A terraced island over water, rocks and a fir](reports/assets/island-dressed.png)
![A pond spilling through a notch](reports/assets/island-pond-waterfall.png)

**From the playing camera** — the one the game is actually played from, 52 units
back and 42 up, looking down 31.6° through a 75° lens — they now read as terraced
knolls rather than lids. That took a second pass, because a downward view
foreshortens height twice over (once by the cosine of the pitch, again because a
degree up the frame is worth 0.81 of a degree across it), so a world unit of
height draws 0.69 of what a world unit of width draws. Measured on the four
islands in one frame, the summit's rise over the island's own width went from
0.10–0.15 to **0.20–0.28**, and the deepest bay in the outline from about a third
of the widest reach to about half. Three levers did it: the relief share, raised
and then lifted off a floor so an island stands in most of it rather than half;
the mesher's fan, from 24 directions to 40, which is what turned shelves that
were already in the shape functions into terraces anyone can see; and the
outline's blobs, pushed apart so the plan is a lobed chunk instead of an oval.
Two levers were tried and rejected with frames — a rougher crenellation, which
moves which cells hold islands without moving any island's edge, and a thicker
rim cliff, which deletes islands outright because the keel and the cliff share
the same room. `reports/islands.md` has the numbers and all four frames.

## Asset packs: eight, all CC0

**Fact.** Eight free packs by Kay Lousberg, all **CC0** (Creative Commons Zero —
public domain, no attribution owed), 982 model files, 111 MB: forest
nature, medieval hexagon, medieval builder, dungeon remastered, adventurers,
halloween bits, city builder bits, resource bits. From `xvfb-run -a
./run_asset_sheet.sh --screenshot "$PWD/reports/assets/now-asset-sheet.png"`:

![Before: coloured boxes and cones](reports/assets/asset-tag-sheet-before.png)
![After: KayKit models](reports/assets/now-asset-sheet.png)

Generation names only *tags*; one table turns a tag into a model, and **34 of 44
tags** now name one. The **ten still drawn as placeholder primitives**
are `flower`, `mushroom`, `toadstool`, `petal_drift`, `blossom_tree`,
`hanging_root`, `signpost`, `campfire`, `glowing_orb` and `window_glow`. Seven
are real gaps; `blossom_tree` keeps its pink placeholder rather than turn green;
the last two are lights, where a shape suffices.

## The village: tint and lit windows are back

The packs cost the village two things; both are back. One seed, one camera, one
crop:

![Four village states](reports/assets/village-four-states.png)

**Lit windows are back** — 522 across the 27 villages the suite samples. **The
per-biome tint on pack models is back** — 17 of the 34 model rows take it, which
is why panel 3's trees sit deeper than panel 2's. Panel 4 adds the light stack,
which at that distance is mostly haze. Up close it sings:

![A village green: lit windows, raking shadows](reports/assets/atmosphere-beat-4-warmth.png)

## Decisions this phase closed

Every generation question section 13 listed is settled.

- **Biome resolution.** A biome's share of a position is $\exp(-d^2/0.085)$ of
  its distance from a prototype point, normalised, marsh laid over at
  $\mathrm{smoothstep}(0.72, 0.90)$. *Why:* no threshold anywhere, so borders
  blend and a pocket can sit anywhere.
- **Island altitude, density, traversal** — one decision, not three. A rim sits
  1.8–2.9 units above what it overhangs, under the 3.0-unit stride, applied
  twice; 0.48 of cells want one. *Why:* jump-only would hide the layer behind an
  ability check; bridges alone strand wild islands.
- **Settlement placement.** One village per 260-unit cell at most; 72% of cells
  want one, against a threshold scaled by biome (meadow 1.00 → marsh 0.00); wet,
  steep or overhung sites vetoed. *Why:* retuning a biome then adds villages
  rather than moving them.
- **Prop catalog and weights.** Two lattices (2 units flora, 8 props), one roll
  per cell against per-biome probabilities laid end to end. *Why:* weights read
  as densities, and a new row cannot disturb earlier rows.
- **Grass interaction and detail.** A push outward around each character, no
  trampled trails; full density within 38 units, thinned by drawing fewer tufts.
  *Why:* a trail is memory, and rebuilding to thin costs 2.3 ms to save nothing.
- **Where light lives.** In the renderer, behind one `--no-atmosphere` switch.
  *Why:* nothing in the world touches fog or a firefly, and a headless process
  loads no renderer file, so "headless skips it" holds by construction.

**Still open:** the combat roll and armour model, extra minion types, the
diplomacy formula, ownership thresholds, and how terrain is described to a
character's decision-maker — none of them generation questions.

## Determinism, order-independence and headless

**Verified today.** Seed 1234 over 100 ticks fingerprints `d43c66e5293d8e29`,
byte-identical in two processes. A headless run loads 0 of 1,401 visual files and
0 of 7 renderer scripts, but 29 of 29 simulation scripts — that last figure the
control proving the probe works.

**It moved this revision**, from `6d2f2a19a21f9381`. The glowing orb went from
the coarse prop lattice to the fine flora one, where it can actually meet the wet
ground it needs (0.03 orbs per marsh view before, 0.81 now). That changes what
the world *contains*, so the move was expected; earlier reported fingerprints no
longer reproduce.

**It moved again when the islands were reshaped for the playing camera**, and
each step of that move is attributed to the rule that caused it in
`reports/islands.md`. Measured with `./run_headless.sh --seed 1234 --ticks 100`,
which is a narrower reading than the figure above: `020507a9a1d52a1e` before, six
levers later `a6aa8e5776ebfe8c`, byte-identical across two processes at both
ends. Only one of the six moves where islands *are* — the wider outline crowds
more neighbours out, taking the walkable density from 41.7 to 41.0 per million
for the lower storey and 16.0 to 15.3 for the upper. The step up onto an island
is untouched at 1.81 / 2.50 / 2.90 against a hop of 3.00.

**What the independent review found**, by injecting bugs into copies of the code
to see whether the tests noticed: two major findings, **both fixed**. The
renderer could reshape a loaded island through the copy it was handed. And the
scatter layer's order and reload checks each sampled one named chunk, so an
injected build-order bug passed every suite — they now sweep a 169-chunk block
both ways. A third defect was fixed too: villages were refused wherever an island
*might* overhang, on a proxy wrong in both directions; the sample went from 21
villages to 27.

## Limits of this judgement

**The reference images section 9.1 names are not on this machine.**
`~/Desktop/game visual inspiration` was searched for across the Linux home and
both Windows drives; it does not exist. The target survives only as its four
written beats — cozy daytime village, misty twilight forest, night pond-house,
torch-lit warmth — so nothing above, the island verdict included, was judged
against a picture you chose.

**Still missing:** every Daniel Mistage *STYLIZED Fantasy* pack the task names
(Village, Market, Tavern & Kitchen, Interior, Workshops, Alchemy, Armory), plus
KayKit's paid tiers and character packs beyond Adventurers — all paid, so they
must come from you. **Hypothesis:** the seven real tag gaps are what such a pack
supplies.

What runs reads as a diorama close up and washes out at distance. Reflections, a
night, and lakeside villages stand between it and the beats.
