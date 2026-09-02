# Generation-layer review — evidence log

An independent check of the five layers added in this phase — biome, water,
floating islands (including the island rework and the way island cover is
hashed), settlements and paths, and the decoration scatter — against the four
guarantees the foundation established:

1. the same seed reproduces the same world **across separate processes**;
2. results do not depend on **the order chunks are built** or observers listed;
3. an **unloaded chunk reloads identically**;
4. nothing the render layer is handed lets it **write into simulation state**.

The method is deliberately not "the suite is green, therefore the guarantee
holds". Every claim below is either re-run from outside the project's own test
suite, or probed by injecting a violation into a **copy** of the code and asking
which suites noticed. A test that stays green under an injected bug is not
testing what it claims to; that is the whole point of the exercise.

Terms used here, defined once and re-defined wherever they recur.

* **Seed** $s$ — the single integer every random choice in the world descends
  from. Two runs of the same $s$ must produce the same world.
* **Chunk** — a fixed $16\times16$ world-unit square of ground, addressed by an
  integer coordinate $(c_x, c_z)$.
* **Streamer** — the object that keeps the pieces near an observer built and
  drops the rest. There is one for ground, one for islands, one for villages and
  roads, one for scatter.
* **Digest** (this project's word) — a short SHA-256 fingerprint of one piece's
  or the whole world's state, used as a stand-in for "is this the same world?".
* **Handle** — an object the simulation hands to the render layer to draw. The
  isolation claim is that a handle is a *detached copy*: writing into it must
  change nothing the simulation holds.
* **Mutation testing** — deliberately introducing a bug into a copy of the code
  to see whether the test suite notices.
* **Order-dependence** — a layer whose answer for a given key changes according
  to what was computed before it. This is the failure mode a streamed infinite
  world is most exposed to, because the order pieces are built is decided by
  where the player happened to walk.

Every mutation was applied to a copy of the project under a scratch directory.
**The working tree was never modified** and was re-verified green afterwards
(§6).

---

## 1. Seed determinism, re-run across separate processes

The project's own determinism test compares a streamed *walk*. That is the right
end-to-end check but it only exercises whatever the observer happened to pass. So
this asks the fields directly, over a fixed region that does not depend on
streaming: `bin/critic_layers.gd` prints one fingerprint per layer, folded from

| layer | what is folded in |
|---|---|
| biome | biome name and full blended profile at $81\times81$ positions, $7$ units apart |
| water | is-water, is-bank, depth and carved ground height at the same $6561$ positions |
| island | every island in $\pm400$ units of all three bands: placement, meshed geometry and pond |
| island cover | every walkable island's dressing, item by item — including `kind` and `context`, which the project's own `ScatterPatch.digest()` leaves out |
| settlement | every village in $\pm500$ units: pad, buildings, props, and each lit window with the building index it belongs to |
| path | road strength at $51\times51$ positions plus every road within $400$ units, with its bridges and lining props |
| scatter | every item in a $13\times13$ block of chunks, again including `kind` and `context` |
| world-walk | the whole streamed world's digest after a 60-tick walk |

The probe was run twice per seed, each run a **separate engine process**:

```
$ for seed in 1234 7 99991; do
    for run in A B; do
      godot4 --headless --path . --script res://bin/critic_layers.gd -- --seed $seed \
        > layers-$seed-$run.txt
    done
  done
```

Seed 1234, run A, verbatim:

```
probe seed=1234
biome 2ac20deb932c3847ae44c231 n=6561
water f6ed25fac59a7ea2c7d6eb59 n=6561
island 16f8a83eef7b2f9c54de73f6 n=78
island-cover a61de398c02863b91771cf9d n=58
settlement 6d0a5eae44ba220e3b4c00ba n=4
path 0b9d9db5488a55a3e385b00e n=2636
scatter 67868c8aed83bbd0e2d444a6 n=169
world-walk 04598b34fb18be9c
```

Seed 7, run A:

```
probe seed=7
biome d423d486421dbd0e049de399 n=6561
water 1b174dd65aa70d1f51fac5c8 n=6561
island 3297d1dd318ca0779c9bd4c3 n=69
island-cover 7b59462da550e2700d3e4a73 n=47
settlement e8a2bb364d359c0efdb610b4 n=3
path adf0667d38e60440b7deedac n=2624
scatter 72c6a6c33090fc36555d76c7 n=169
world-walk df19d828003a1f95
```

Seed 99991, run A:

```
probe seed=99991
biome 307ab444890d02d709625034 n=6561
water 3957d59b0a4488416d3b4cca n=6561
island 9eb98198912181bf552daf80 n=63
island-cover e7d64c1443b3a6b60cc03185 n=42
settlement 243e7c0037bf55c2d6bb50f4 n=10
path eb11e32034c0062cc5e97dc1 n=2631
scatter 11b9f648bb155015bef0d757 n=169
world-walk e410f39ad28b01ce
```

Process A against process B, per seed:

```
$ diff layers-1234-A.txt layers-1234-B.txt && echo IDENTICAL
IDENTICAL
$ diff layers-7-A.txt layers-7-B.txt && echo IDENTICAL
IDENTICAL
$ diff layers-99991-A.txt layers-99991-B.txt && echo IDENTICAL
IDENTICAL
```

And the comparison is not vacuous — a different seed does produce a different
world:

```
$ diff layers-1234-A.txt layers-7-A.txt >/dev/null \
    && echo "PROBLEM: identical across seeds" || echo "differ, as they must"
differ, as they must
```

**Verdict: holds.** Every new layer reproduces byte-identically in a fresh
process, on three seeds, over regions chosen independently of what streaming
happened to load.

---

## 2. Order-independence, probed by injection

*Order-independence* is the claim that a layer's answer for a given key does not
depend on what was computed before it. Two things were done for each layer.

**(a) Measured directly, on the unmodified code.** `bin/critic_order.gd` produces
the same set of answers twice inside one process — once walking the keys
forwards, once backwards — from two separate field objects, and compares them
key by key. Nothing is streamed; the fields themselves are asked, which is the
level the claim is made at.

```
$ godot4 --headless --path . --script res://bin/critic_order.gd -- --seed 1234
order probe seed=1234
biome            0 of 2401 differ between the two build orders  order-free
water            0 of 2401 differ between the two build orders  order-free
island           0 of 162 differ between the two build orders  order-free
island cover     0 of 42 differ between the two build orders  order-free
settlement       0 of 7 differ between the two build orders  order-free
scatter          0 of 121 differ between the two build orders  order-free
cover in laps    13 overlapping storey pairs, 4 things standing in a lap, 0 coincidences  distinct
order probe: 0 layer(s) order-dependent
```

Seed 7 gives the same result. The **observer list** was probed separately, since
the streamers all take an `Array[Vector2]` of observers: three observers streamed
as $[a,b,c]$, $[c,b,a]$ and $[b,a,c]$, compared piece by piece on the ground,
island, village, road and scatter fingerprints.

```
$ godot4 --headless --path . --script res://bin/critic_observers.gd -- --seed 1234
observer-order probe seed=1234: 0 of 216 pieces differ across the three orderings  order-free
$ godot4 --headless --path . --script res://bin/critic_observers.gd -- --seed 7
observer-order probe seed=7: 0 of 207 pieces differ across the three orderings  order-free
```

**(b) Probed by injection.** One violation was introduced into a copy of each
layer, one layer at a time, and the whole suite run against it. The order probe
above was run against each copy too, to confirm the injection is a real
order-dependence and not a dud.

| copy | layer | injected bug | order probe on the copy | suites that noticed |
|---|---|---|---|---|
| `inj-biome` | biome | `weights_at` eases the marsh share $2\%$ towards the previous position sampled | biome $550/2401$, island $7/162$, scatter $2/121$ | **5** — determinism, terrain, biomes, islands, island cover |
| `inj-water` | water | `sample_column` eases the bed $3\%$ towards the previous position sampled | water $2401/2401$, island $35/162$, scatter $4/121$ | **7** — determinism, terrain, water, islands, settlements, scatter, render shell |
| `inj-island` | islands | `_crowded` takes its neighbours from the memo's insertion order instead of a fixed cell scan | island $1/162$ | **1** — islands |
| `inj-settlement` | settlements | `_lay_out` turns each village a little further by a count of villages built so far | settlement $6/7$ | **1** — settlements |
| `inj-scatter` | scatter | `item_in_cell` thins the roll by $0.02$ when the cell just examined placed something | scatter $2/121$ | **0 — all 14 suites green** |
| `inj-scatter2` | scatter | the same, thinned by $0.15$ instead | scatter $4/121$ | see §5 finding 2 |
| `inj-cover` | island cover | `build` salts every roll by a count of islands dressed so far | island cover $34/42$ | **1** — island cover |
| `inj-coverhash` | island cover | the hash drops the island's identity and takes the world cell, positions left island-local | — (not an order bug) | **1** — island cover, on its sample-size guard |
| `inj-coverhash2` | island cover | the cell is read on the ground layer's world lattice for **both** the hash and the position — the exact mistake `sim/island_cover.gd` says it exists to avoid | — (not an order bug) | **1** — island cover, on the coincidence check itself |

The two rows that matter most:

**The island-cover hashing is genuinely guarded.** `inj-coverhash2` is the
faithful regression: an island's cover cell counted on the world lattice rather
than from the island's own middle. The check written for exactly this failed, and
failed loudly:

```
FAIL  island cover   6512 checks, 1 failed
        - 13 of 31 things on an upper storey stand exactly where the same thing
          stands on the plate below -- cover is being hashed from world position
      expected: 0
      actual:   13
```

That is the claim the whole `IslandCover` file is organised around, and it is
defended by a test that fails when it is broken. The earlier, half-way variant
(`inj-coverhash`, hash on the world cell but positions still island-local) does
*not* produce coincidences — the two plates' centres differ by a non-multiple of
the cell size, so the same tag lands at different positions — and it was caught
only by the sample-size guard (`only 24 things stand in the overlaps, which is
too few to conclude from`). That guard doing the catching is a small piece of
luck, but the real regression is caught by the real check.

**The island cover's build-order salt was caught by the reload test**, not by an
order test:

```
FAIL  island cover   6564 checks, 2 failed
        - only 24 things stand in the overlaps, which is too few to conclude from
        - an island came back from an unload dressed differently
      expected: 39bea6b0ddf1a107
      actual:   686b62244b9f01f9
```

That is the right outcome and worth noting as a design property: because a
streamer *does* rebuild, a reload-identity test catches build-order dependence
for free.

**And one layer's injection went entirely unnoticed** — see §5 finding 2.

**Verdict: the layers themselves are order-free**, measured directly on three
orderings of keys and three orderings of the observer list. **The suite's ability
to notice if that changed is uneven**, and one layer's coverage has a hole.

---

## 3. Reload identity: a settlement, an island and a scattered chunk

*Reload identity* is the claim that a piece dropped when nobody is near and
rebuilt when someone returns comes back exactly as it was. `bin/critic_reload.gd`
walks the observer to the piece, records it, walks $40{,}000$ units away
(confirming the piece actually unloaded — otherwise the test proves nothing),
walks back, and compares.

The comparison is made twice over: on the project's own digest, and on a
**deeper rendering than the digest covers** — every field of every building,
prop and lit window, and every scattered item's `kind` and `context`, which
`ScatterPatch.digest()` does not fold in (§5, finding 2).

```
$ godot4 --headless --path . --script res://bin/critic_reload.gd -- --seed 1234
settlement reload: cell=(-2, -3) unloaded=true reloaded=true builds=2->3 digest b8c76593bdfd408e -> b8c76593bdfd408e deep-equal=true  OK
island reload: key=(-5, 3, 2) band=2 unloaded=true reloaded=true builds=15->34
  before 40a7fa07b6006743|7247615418c543d8|1f8430dd3cb3a59a|9271bc299c6aa6ff
  after  40a7fa07b6006743|7247615418c543d8|1f8430dd3cb3a59a|9271bc299c6aa6ff
  cover deep-equal=true (18 items)  OK
scatter reload: chunk=(-2, -3) items=29 unloaded=true reloaded=true builds=32->96 digest 9a966c74922416f8 -> 9a966c74922416f8 deep-equal=true  OK
reload probe: 0 failure(s)
```

The four island fingerprints are, in order, its placement, its meshed geometry,
its cover and its pond. Band 2 is the *upper* aerial storey — chosen on purpose,
because that is the storey whose cover is hashed on the island's own lattice
rather than on the world's, and so the one where a reload could most plausibly
come back different.

Two further seeds:

```
$ godot4 --headless --path . --script res://bin/critic_reload.gd -- --seed 7
settlement reload: cell=(0, -3) unloaded=true reloaded=true builds=2->4 digest d581e828d49216dd -> d581e828d49216dd deep-equal=true  OK
island reload: key=(-5, 0, 2) band=2 unloaded=true reloaded=true builds=16->35
  before 9a9f71fb10732ff8|e4f67bfd75bf08ea|d391769fe0b523ec|892e248a222a101c
  after  9a9f71fb10732ff8|e4f67bfd75bf08ea|d391769fe0b523ec|892e248a222a101c
  cover deep-equal=true (14 items)  OK
scatter reload: chunk=(-2, -2) items=31 unloaded=true reloaded=true builds=32->96 digest ad15aa77c271d699 -> ad15aa77c271d699 deep-equal=true  OK
reload probe: 0 failure(s)

$ godot4 --headless --path . --script res://bin/critic_reload.gd -- --seed 99991
settlement reload: cell=(-3, -3) unloaded=true reloaded=true builds=2->3 digest 94d956b6bd6d9cd0 -> 94d956b6bd6d9cd0 deep-equal=true  OK
island reload: key=(-5, -2, 2) band=2 unloaded=true reloaded=true builds=15->31
  before 95fb7f4dd8d1a5ec|30c5046b118ffcf7|2fec2a76c51b6397|42bfca5476293651
  after  95fb7f4dd8d1a5ec|30c5046b118ffcf7|2fec2a76c51b6397|42bfca5476293651
  cover deep-equal=true (15 items)  OK
scatter reload: chunk=(0, -3) items=24 unloaded=true reloaded=true builds=32->96 digest 890f2d78b36821a1 -> 890f2d78b36821a1 deep-equal=true  OK
reload probe: 0 failure(s)
```

`builds=15->34` is the count of islands ever built including rebuilds, so the
rebuild demonstrably happened rather than the piece having quietly stayed
loaded.

**Verdict: holds**, for all three new streamed kinds, on three seeds.

---

## 4. What the render layer is handed, written through

The rule is one-directional: the render layer may read the simulation, never
write into it. The project's automated check (`tests/layer_check.gd`) enforces
this by **scanning imports** — no file under `sim/` may name a render path or a
presentation type. That is necessary but not sufficient: it says nothing about
whether an object handed *out* is a copy or a way back in.

So every place `render/main.gd` reaches into the simulation was enumerated
directly from the source, and each was probed by `bin/critic_handles.gd` in two
phases:

* **detect** — make the write into the object the simulation itself holds. The
  world's fingerprint *must* move. Without this, "the fingerprint did not move"
  in phase 2 would be indistinguishable from "the fingerprint never notices
  anything".
* **block** — make the same write through the handle a viewer is actually given.
  It must land on the copy (so the handle is not merely inert), and must reach
  neither the live object nor the world's fingerprint.

```
$ godot4 --headless --path . --script res://bin/critic_handles.gd -- --seed 1234
handles probe seed=1234  chunks=30 islands=11 villages=1 roads=3 scatter=30
-- phase 1: can the world's fingerprint notice a write into the live object?
ground geometry        live-write-lands=true fingerprint-notices=true  OK
island geometry        live-write-lands=true fingerprint-notices=true  OK
island object          live-write-lands=true fingerprint-notices=true  OK
island cover           live-write-lands=true fingerprint-notices=true  OK
island pond            live-write-lands=true fingerprint-notices=true  OK
settlement             live-write-lands=true fingerprint-notices=true  OK
road                   live-write-lands=true fingerprint-notices=true  OK
scatter patch          live-write-lands=true fingerprint-notices=true  OK
world water sheet      live-write-lands=true fingerprint-notices=true  OK
-- phase 2: does the same write through the handed-out copy reach anything?
ground geometry        not-same-object=true same-content=true write-lands-on-copy=true world-still=true live-untouched=true  OK
island geometry        not-same-object=true same-content=true write-lands-on-copy=true world-still=true live-untouched=true  OK
island object          not-same-object=true same-content=true write-lands-on-copy=true world-still=true live-untouched=true  OK
island cover           not-same-object=true same-content=true write-lands-on-copy=true world-still=true live-untouched=true  OK
island pond            not-same-object=true same-content=true write-lands-on-copy=true world-still=true live-untouched=true  OK
settlement             not-same-object=true same-content=true write-lands-on-copy=true world-still=true live-untouched=true  OK
road                   not-same-object=true same-content=true write-lands-on-copy=true world-still=true live-untouched=true  OK
scatter patch          not-same-object=true same-content=true write-lands-on-copy=true world-still=true live-untouched=true  OK
world water sheet      not-same-object=true same-content=true write-lands-on-copy=true world-still=true live-untouched=true  OK
observer profile       distinct=true same-values=true next-clean=true world-still=true catalog-clean=true  OK
terrain profile_at     distinct=true same-values=true next-clean=true world-still=true catalog-clean=true  OK
snapshot               world-still=true streamers-still=true (30 chunks)  OK
handles probe: 0 failure(s)
```

Seed 7 gives the same twelve `OK` lines.

What each row wrote, so the checks are not taken on trust:

| handle | accessor in `render/main.gd` | write made |
|---|---|---|
| ground geometry | `terrain_streamer.geometry(key)` | a vertex, a normal, a colour, an index, `lowest`, `highest`, `chunk_x` |
| island geometry | `island_streamer.geometry(key)` | the same seven |
| island object | `island_streamer.island(key)` | centre, rim height, radius, keel depth, biome, walkable flag |
| island cover | `island_streamer.cover_of(key)` | the patch's chunk key, and an item's position, tag and context |
| island pond | `island_streamer.water_of(key)` | a vertex, a normal, a colour, an index, `min_x`, `wet_cells` |
| settlement | `settlement_streamer.settlement(key)` | centre, pad height, biome, a building, a prop, a lit window |
| road | `settlement_streamer.road(name)` | `id`, `from_id`, a route point, a bridge, a lining prop |
| scatter patch | `scatter_streamer.patch(key)` | the chunk key, and an item's position, tag and context |
| world water sheet | `world.water_sheet()` | a vertex, a normal, a colour, an index, `min_x`, `wet_cells` |
| observer profile | `world.observer_profile()` | tints, fog density, id, prop tags |
| terrain profile | `world.terrain.profile_at(x, z)` | the same |
| snapshot | `world.snapshot()` | the four loaded-key lists cleared, `observer_x` overwritten |

The two profile rows are checked differently, because neither has a live object
behind it — each call builds a fresh profile out of the catalog. There the
questions are: are two calls distinct objects with equal values, does a write
into one leave the next one clean, and does it leave the **static catalog** every
profile in the process is blended from clean? All three hold; the catalog is
protected because `BiomeCatalog.profile()` returns `detached_copy()` and that
duplicates the `prop_tags` array rather than sharing it.

**Verdict: eleven of the twelve hold. One does not** — see finding 1 below.

---

## 5. Findings

### Finding 1 (major) — a viewer can reshape an island through the copy it is handed

`FloatingIsland.detached_copy()` duplicates every packed array on the island but
hands its two *heightfields* across **by reference**, on a stated ground:

> The heightfields are shared rather than copied, because they are immutable: a
> ValueNoise is its five constants and a hash function, with nothing a holder
> could write into.
>
> — `sim/floating_island.gd:619-621`

That premise is false. `ValueNoise`'s five parameters — `octaves`, `period`,
`amplitude`, `lacunarity`, `gain` — are plain `var`s
(`sim/value_noise.gd:20-36`), writable by anyone holding the object. So the copy
`island_streamer.island(key)` hands the render layer shares mutable state with
the island the simulation holds.

**Concrete failure scenario.** Seed 1234. The render layer draws the aerial
island in lattice cell $(-1, 0)$, band 0, which `IslandStreamer` has loaded. It
calls `island_streamer.island(key)` — the documented, isolation-preserving
accessor — and then adjusts what it believes is its own copy:

```gdscript
var island := island_streamer.island(key)   # a "detached copy"
island._relief_noise.amplitude *= 4.0
island._relief_noise.period *= 0.25
```

`bin/critic_noise2.gd` makes exactly that call:

```
$ godot4 --headless --path . --script res://bin/critic_noise2.gd -- --seed 1234
memo entries after streaming: 147 (limit 512)
streamer island is the field's memoised object: true

after a viewer writes into the heightfield of the copy it was handed:
  TerrainQuery.island_height_at:  9.5198 -> 9.3588  (moved: true)
  TerrainQuery.surface_height_at: 9.5198 -> 9.3588  (moved: true)
  is_over_island_at:              true -> true
  a fresh query of the same seed:  9.5198
  the two now agree:               false
  cover from the poisoned island:  45bbc0c660d345e1
  cover from a fresh one:          61bf7a9c375a9716
  identical:                       false
```

The wrong result: `TerrainQuery.surface_height_at` — the height a character
stands on — answers $9.3588$ where a second process running the same seed answers
$9.5198$. The island's dressing rebuilt from that island digests
`45bbc0c660d345e1` instead of `61bf7a9c375a9716`. Two seeds more, same shape of
result:

| seed | island | `surface_height_at` before | after | fresh process |
|---|---|---|---|---|
| 1234 | $(-1,0)$ band 0 | $9.5198$ | $9.3588$ | $9.5198$ |
| 7 | band 0 | $10.5047$ | $8.6612$ | $10.5047$ |
| 99991 | band 0 | $-1.3297$ | $-1.1536$ | $-1.3297$ |

Three things make this worse than a shared reference usually is.

* **The world's fingerprint cannot see it.** `FloatingIsland.digest()` folds in
  the blob outline, the crenellation, the spur amplitudes and the taper — but not
  the two heightfields' parameters (`sim/floating_island.gd:662-688`). So
  `world.digest()` is unchanged after the write, and every fingerprint comparison
  in the suite — including the cross-process determinism test and the
  shell-versus-headless test — would compare equal on a world that has been
  edited.
* **How far it spreads is decided by an unrelated cache.** `IslandField` memoises
  islands and clears the whole memo when it passes `MEMO_LIMIT = 512`
  (`sim/island_field.gd:419-427`). While the streamer's island is still the
  memoised one — which it is at $147$ entries in the run above — the write reaches
  `TerrainQuery` and therefore everyone. After an eviction the streamer holds an
  orphan and the write reaches less. Whether a render-layer bug corrupts the
  world or merely corrupts the picture depends on how many island cells have been
  asked about since.
* **Nothing tests it.** `tests/test_render_shell.gd` probes handle isolation for
  `TerrainChunkGeometry` only. No suite writes through an island handle at all.

**Smallest change:** duplicate the two heightfields in
`FloatingIsland.detached_copy()` — give `ValueNoise` a `detached_copy()` of its
own and call it — and fold the heightfield parameters into
`FloatingIsland.digest()` so a fingerprint comparison could notice if it ever
happened again. Both are a few lines. (A larger alternative — making `ValueNoise`
genuinely immutable — would make the existing comment true, but the copy is the
smaller change.)

**Not a claim about today's renderer.** `render/main.gd` does not touch
`_relief_noise`; it reads `centre_x`, the tints and the outline. This is a hole in
the barrier, not a bug being exercised. It is reported because the barrier is
what the isolation guarantee *is*, and because the file states the opposite in a
comment a future author would reasonably trust.

### Finding 2 (major) — the scatter layer's order-independence check samples one chunk, and misses a real order-dependence

`DecorationScatter` states its claim plainly: a patch is a pure function of its
chunk coordinate and the seed, because "no cell consults its neighbours, nothing
accumulates between chunks, and no stream of random numbers is drawn from"
(`sim/scatter_patch.gd:8-15`). The claim holds today (§2a). What does not hold is
the suite's ability to notice if it stopped holding.

**Concrete failure scenario.** `inj-scatter` adds one line to
`DecorationScatter.item_in_cell` — a plausible-looking anti-clumping rule: thin
the roll by $0.02$ when the cell just examined placed something. That makes a
chunk's contents depend on what was built before it, and the dependence is real:

```
$ godot4 --headless --path . --script res://bin/critic_which.gd   # on inj-scatter
of 289 chunks, 10 move when the build order is reversed: (4,2), (2,6), (2,-8), (0,8), (0,-8), (-2,6), (-2,-7), (-3,4), (-6,-6), (-7,1)
the scatter suite's order-check chunk is (2,-3); its reload-check chunk is (0,0)
either of those among the moved chunks: false
```

Ten chunks in $289$ — $3.5\%$ — now come out differently depending on the order the
world was walked. The wrong result in the game: a player who approaches a chunk
from the north sees different flora on it than one who approaches from the
south, and a chunk revisited after a detour is dressed differently from how it
was left.

The whole suite is green on it:

```
$ ./run_tests.sh                                                  # on inj-scatter
PASS  rng            1325 checks
PASS  determinism    15 checks
PASS  terrain        32 checks
PASS  streaming      4695 checks
PASS  biomes         212 checks
PASS  water          6358 checks
PASS  islands        93172 checks
PASS  island cover   6252 checks
PASS  settlements    8929 checks
PASS  scatter        127 checks
PASS  layering       12 checks
PASS  asset tags     995 checks
PASS  window glow    7019 checks
PASS  render shell   30 checks

all 14 suites passed (129173 checks)
```

Why each of the four checks that should have caught it did not:

| check in `tests/test_scatter.gd` | what it samples | why it missed |
|---|---|---|
| `_a_chunk_is_the_same_fresh_as_after_its_neighbours` | one chunk, $(2,-3)$ | $(2,-3)$ is not one of the ten that move |
| `_a_chunk_dropped_and_reloaded_comes_back_identical` | one chunk, $(0,0)$ | $(0,0)$ is not one of the ten either |
| `_a_cell_is_a_pure_function_of_its_cell_and_the_seed` | a $13\times13$ block of cells, from a field given 200 unrelated questions | the perturbation only changes a cell whose roll lands within $0.02$ of a decision boundary; none of these $338$ do |
| `_two_processes_dress_the_world_the_same_way` | two headless runs of the same seed | **structurally cannot catch this.** Both processes walk in the same order, so an order-dependence is reproduced identically in both. Cross-process determinism and order-independence are different claims, and this test only answers the first |

The contrast with the island layer is the point. `tests/test_islands.gd` compares
**every cell** of an $11\times11\times2$ block asked forwards against asked
backwards, and caught an injected bug that changed exactly **one island in 162**.
The scatter equivalent compares one chunk, and missed one that changed ten in
289.

A stronger version of the same bug does not change the answer. `inj-scatter2`
thins the roll by $0.15$ rather than $0.02$ — a perturbation seven times larger —
and the suite is green on that too:

```
$ ./run_tests.sh                                                  # on inj-scatter2
...
all 14 suites passed (129173 checks)
```

So this is not a matter of the injection being too quiet to see. It is the
sampling: a bug of this shape only fires where a roll happens to land near a
decision boundary, which is an unpredictable few percent of chunks whatever its
magnitude, and a check that looks at two named chunks will keep missing it.

**Smallest change:** make `_a_chunk_is_the_same_fresh_as_after_its_neighbours`
sweep a block — build a square of chunks forwards from one `DecorationScatter`
and backwards from another, and compare the two digest maps — instead of
comparing a single target chunk. That is the shape `tests/test_islands.gd`
already uses, and it turns the check from a spot sample into a sweep.

*This is a finding about the test suite, not about the shipped scatter layer,
which is order-free as measured in §2a. It is reported as major rather than minor
because order-independence is one of the four guarantees the whole streamed
world rests on, and for one of the five new layers there is currently no check
that would fail if it broke in a realistic way.*

### Finding 3 (minor) — the world fingerprint does not cover a placed thing's `kind` or `context`

`ScatterPatch.digest()` folds in `tag`, `x`, `z`, `y`, `yaw` and `size`, and stops
there (`sim/scatter_patch.gd:75-80`). The two remaining fields of a placed item —
`kind`, which says what sort of thing it is, and `context`, which says *why it was
allowed to stand there* — are not in it. For island cover, `context` is what
distinguishes a thing standing on the island's top from a root hanging off its
keel (`sim/island_cover.gd:CONTEXT_TOP` / `CONTEXT_KEEL`), which is the difference
between a shape standing up and the same shape hanging down.

**Concrete failure scenario.** In `inj-context`, `IslandCover.roots_of()` labels a
hanging root `CONTEXT_TOP` instead of `CONTEXT_KEEL` — nothing about its position
changes, only the label saying which way it hangs. Result: every fingerprint in
the project is unmoved. The world digest, the cross-process determinism
comparison and the shell-versus-headless comparison all compare equal on a world
where every island's roots have been relabelled.

It was still caught, by the island-cover suite, but incidentally rather than by
anything reading the label as a meaning:

```
FAIL  island cover   6252 checks, 239 failed
        - an island grew 'hanging_root', which the scatter catalog has no row for
        ( x239 )
```

The check that fired is "everything standing on an island's top names a catalog
row", and `hanging_root` is not one. A relabelling in the other direction, or
between two `kind` values that are both catalog-legal, would leave no trace at
all.

**Smallest change:** add `kind` and `context` to `ScatterPatch.digest()`. They are
short strings, appended to a string that already carries six numbers per item, so
the cost is negligible against the SHA-256 that follows.

*This is not part of the isolation or order guarantees; it is a gap in what the
fingerprint answers for, which is the instrument all three of the other
guarantees are measured with. Reported as minor for that reason.*

---

## 6. The working tree

Every mutation lived in a copy under a scratch directory. Ten copies were made
in all — one pristine, nine injected — and the engine binary was symlinked into
each rather than duplicated. The probes themselves (`bin/critic_*.gd`) also live
only in the scratch copies; the only file this review adds to the project is this
report.

The project's own source is byte-identical to the pristine copy taken before any
injection:

```
$ diff -r sim  scratch/game/sim  && echo "sim/ IDENTICAL"
sim/ IDENTICAL
$ diff -r render scratch/game/render && echo "render/ IDENTICAL"
render/ IDENTICAL
$ diff -r tests scratch/game/tests && echo "tests/ IDENTICAL"
tests/ IDENTICAL
```

And the suite is green on it:

```
$ ./run_tests.sh
PASS  rng            1325 checks
PASS  determinism    15 checks
PASS  terrain        32 checks
PASS  streaming      4695 checks
PASS  biomes         212 checks
PASS  water          6358 checks
PASS  islands        93172 checks
        island cover: 13 overlapping storey pairs, 29 things in the laps, 0 coincidences
        island cover: 5307 placements over 4 seeds -- 0 hovering, 0 past the lip, 0 in water, 0 on a face
        island cover: 194 islands over 4 seeds -- 61 with a basin, 49 overflowing, 61 dipping below their own rim, 0 boundary samples below it
PASS  island cover   6252 checks
PASS  settlements    8929 checks
PASS  scatter        127 checks
PASS  layering       12 checks
PASS  asset tags     995 checks
        window glow: 21 villages light ["house=184", "cottage=190", "tavern=42", "tower=6"]
        window glow: 228 distinct placements checked, worst gap 0.201 (cottage face +1 share +1.00)
PASS  window glow    7019 checks
PASS  render shell   30 checks

all 14 suites passed (129173 checks)
```

---

## 7. Verdict

| guarantee | verdict | how it was established |
|---|---|---|
| the same seed reproduces the same world across processes | **holds** | per-layer fingerprints, two separate processes, three seeds, byte-identical (§1) |
| results do not depend on build order or observer order | **holds in the code**; **one layer's check would not notice if it stopped** | measured on three orderings of keys and three of the observer list (§2a); probed by nine injections (§2b, finding 2) |
| an unloaded chunk reloads identically | **holds** | village, upper-storey island and scattered chunk, three seeds, compared on a deeper rendering than the digest covers (§3) |
| nothing the render layer is handed lets it write into simulation state | **eleven of twelve handles hold; one does not** | every accessor in `render/main.gd`, two-phase detect-then-block (§4, finding 1) |

On the island layer specifically, which the work item asked to be judged as it
stands after the rework: the way island cover is hashed — from the island's own
cell rather than from world position — is correct, is the reason two overlapping
aerial storeys carry different cover, and is defended by a test that fails loudly
when the hashing regresses (§2b, `inj-coverhash2`). Its reload identity holds for
the upper storey specifically. The one problem on the island layer is the shared
heightfield in `detached_copy()` (finding 1), which is a barrier hole rather than
a shape problem.

Three findings, none of them in the generated world itself: one hole in the
simulation/render barrier, one hole in the suite's coverage of the scatter
layer's order-independence, and one field the world fingerprint does not cover.

