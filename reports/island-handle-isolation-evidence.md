# An island handed to the render layer cannot be used to reshape the world

Evidence for `W-island-handle-isolation`, the follow-up to finding 1 of the
cycle-34 generation review (`reports/generation-review-evidence.md`, §5).

Terms, once. **Seed** — the single integer every random choice in the world
descends from. **Streamer** — the object that keeps the pieces of the world near
an observer built and drops the rest. **Handle** — an object the simulation hands
the render layer to draw; the isolation claim is that it is a detached copy, so
writing into it changes nothing the simulation reads. **Digest** (this project's
word) — a short SHA-256 fingerprint standing in for "is this the same world?".
**Heightfield** — here, a `ValueNoise`: six numbers and a hash function that
together answer "how high is the ground at this position". **Mutation testing** —
injecting a bug into a copy of the code to see whether the suite notices, since a
test that stays green under an injected bug is not testing what it claims to.

Nothing below was run inside the working tree except the final green suite and
the two headless runs. The pristine copy, the six injected copies and every probe
lived in a scratch directory; `sim/`, `render/` and `tests/` in the working tree
differ from the pristine copy in exactly the four files this task changed.

## What was wrong, and what changed

`FloatingIsland.detached_copy()` duplicated every packed array on the island but
handed its two heightfields — `_relief_noise` and `_detail_noise` — across by
reference, on the stated ground that a `ValueNoise` is immutable. It is not: its
`octaves`, `period`, `amplitude`, `lacunarity` and `gain` are plain `var`s, as is
its `field_seed`. Anyone holding the "copy" the render layer is given could
retune the island's relief and move the ground a character stands on.

Three changes, in three files plus tests:

* `ValueNoise.detached_copy()` — new, six lines. A field of its own with the same
  six numbers.
* `FloatingIsland.detached_copy()` — copies both fields rather than sharing them.
  The comment claiming a `ValueNoise` has nothing a holder could write into is
  replaced by one saying the opposite and why.
* `FloatingIsland.digest()` — folds in both fields' six parameters, via a new
  `ValueNoise.parameter_text()`. Two islands whose fields are tuned differently
  now fingerprint differently.

Nothing about how a heightfield is generated or sampled was touched.

## 1. The write no longer reaches the world

The probe (`.lab/memory/files/probe_island_handle.gd`) is the review's scenario:
build the world, stand the observer on the island so the streamer loads it, ask
`island_streamer.island(key)` — the documented accessor — and then write into
what the caller believes is its own copy:

```gdscript
var island := island_streamer.island(key)   # a "detached copy"
island._relief_noise.amplitude *= 4.0
island._relief_noise.period *= 0.25
```

Then read `TerrainQuery.surface_height_at` at $(c_x + 0.3r,\ c_z + 0.15r)$ — a
position on the island's top, off its middle.

| seed | island | before the write | after, unfixed | after, fixed | a second process |
|---|---|---|---|---|---|
| 1234 | band 0 cell $(-4,-4)$ | $9.5198$ | $9.3588$ | $9.5198$ | $9.5198$ |
| 7 | band 0 cell $(-4,-2)$ | $10.5047$ | $10.5047$ \* | $10.5047$ | $10.5047$ |
| 99991 | band 0 cell $(-4,-3)$ | $-1.3297$ | $-1.1536$ | $-1.3297$ | $-1.3297$ |

The three "before" numbers and two of the three "after, unfixed" numbers are the
review's own — $9.5198 \to 9.3588$ and $-1.3297 \to -1.1536$ — reproduced on
today's tree. The whole second-process column equals the fixed column, byte for
byte: the two probe runs on the fixed tree diff identically
(`island-handle-before.txt`, `island-handle-after.txt`).

\* Seed 7's write did not reach the world in this reconstruction, and the reason
is the review's own second caveat rather than anything about the fix. `IslandField`
memoises islands and clears the whole memo past `MEMO_LIMIT = 512`; on seed 7 the
clear happens during the streaming this probe does (memo at $118$ entries
afterwards), so the streamer is left holding an island the field no longer hands
out, and the write reaches that orphan instead of the world. On the other two
seeds the streamer's island is still the memoised one (memo $314$ and $304$) and
the write reaches everything. How far the old bug spread was decided by an
unrelated cache — which is part of why it was worth closing rather than living
with. The memo itself was not touched: it is out of scope for this task.

The review's label for the seed-1234 island, "lattice cell $(-1,0)$", does not
match this tree's coordinates — the island at $(-1,0)$ on seed 1234 has a rim at
$2.79$ and relief $4.35$, so it cannot answer $9.5198$ anywhere. Scanning band 0
found exactly one island per seed whose top answers the review's number at the
named position, and those are the cells in the table. Everything else about the
scenario reproduces exactly, so this reads as a mislabelled cell in the review's
write-up rather than a difference in the world.

Also confirmed in the same run, on all three seeds: the handle no longer shares
either field (`handle._relief_noise != live._relief_noise`), the loaded island's
own digest is unchanged by the write, the world's digest is unchanged by it, and
the write *did* land on the handle (its own amplitude went $1.0 \to 4.0$), so
"nothing moved" is not "nothing happened".

## 2. The island's fingerprint now covers its heightfields

Two islands whose fields differ now fingerprint differently. Checked directly in
`tests/test_islands.gd`, one parameter at a time — eight of them, six on the
relief field and two on the detail field — so a pass cannot come from folding in
only one number or only one of the two fields. An untouched copy still
fingerprints as the island it came from.

Before the fix, retuning the relief amplitude of an island left its digest at
`b41fc43fc3e01976` (seed 1234, unchanged across the write, see the probe output).
After it, the same island digests `5945deac232c1dca` and any retuning moves it.

## 3. Every other handle, swept

The class of sharing to look for is a copied container that hands some object
inside it across by reference. Rather than reading the nine `detached_copy()`
implementations and judging by eye, the sweep walks the live object and its
handle side by side and reports every place both reach the same thing. Three
kinds of sharing count: the same object, the same array or dictionary, and the
same packed-array storage — the last found by writing a value into the copy and
looking for it on the other side, because this engine's packed arrays share
storage on assignment and leave nothing to compare.

| handle | accessor | verdict |
|---|---|---|
| chunk geometry | `TerrainStreamer.geometry()` | already clean |
| floating island | `IslandStreamer.island()` | **was shared, now fixed** |
| island geometry | `IslandStreamer.geometry()` | already clean |
| island cover (scatter patch) | `IslandStreamer.cover_of()` | already clean |
| island pond (water sheet) | `IslandStreamer.water_of()` | already clean |
| world water sheet | `SimWorld.water_sheet()` | already clean |
| scatter patch | `ScatterStreamer.patch()` | already clean |
| settlement | `SettlementStreamer.settlement()` | already clean |
| biome profile | `BiomeCatalog.profile()` | already clean |

On the unfixed tree the sweep reports exactly two shared objects, both on the
island — `._relief_noise` and `._detail_noise` — and nothing anywhere else. On
the fixed tree it reports none. The eight clean handles are clean for the same
structural reason: they hold only value types (floats, ints, strings, `Color`,
`Vector2i`), packed arrays which are duplicated, and arrays of dictionaries whose
entries are duplicated and hold nothing but scalars.

The sweep is not a one-off: it now lives in `tests/test_render_shell.gd` as a
standing check over all nine handles, including a count so that a handle kind
silently dropping out of the sweep fails rather than passing.

## 4. Mutation testing

Six copies of the tree, one pristine and five with an injected bug, each run
against the two suites that make the claims.

| injected bug | islands suite | handle sweep |
|---|---|---|
| none (the shipped code) | pass | pass |
| both heightfields shared again (the original bug) | **28 failures** | **caught** |
| the detail field shared, the relief field copied | **14 failures** | **caught** |
| the heightfield parameters dropped from `digest()` | **9 failures** | not its business |
| chunk geometry's `vertices` assigned instead of duplicated | — | **caught** |
| a scatter patch's item dictionaries shared, container duplicated | — | **caught** |

The first injection reproduces the review's number in the failure text: *"a write
through `island_streamer.island((-4, -4, 0))` moved the surface at $(-317.6588,
-281.6923)$: the height a character stands on changed — expected $9.51977899$,
actual $9.35878264$."*

The fourth injection is the one that shows the two halves of this task are
independent: with the copy fixed but the digest not folding the fields, nothing
can reach the world any more, but a fingerprint still could not *notice* a
retuned field — which is what the digest half is for.

## 5. No island changed shape

The fix is meant to be invisible to what the world looks like. A probe over four
seeds (1234, 7, 99991, 11) built every island in a $9 \times 9$ block of cells in
all three bands with the real mesher, and read a $9 \times 9$ grid of
`surface_height_at` over each — $375$ islands, their triangle counts and geometry
digests, and $30\,375$ heights at six decimal places. The pristine and fixed trees
produce byte-identical output (`island-shapes-before.txt`,
`island-shapes-after.txt`, $750$ lines each).

## 6. The world fingerprint moved, and why

```
before:  ./run_headless.sh  ->  done ticks=100 ... final=358a22ccb020629a
after:   ./run_headless.sh  ->  done ticks=100 ... final=6d2f2a19a21f9381
```

Expected, and it is the digest half of the task doing exactly what it was asked
to. `SimWorld.digest()` folds in every loaded island's own digest, and every
island's digest now has twelve more numbers in it. The world itself is unchanged
— §5 is the evidence — so this is a change of what the fingerprint is computed
from, not of what it is computed about. Any recorded fingerprint from before this
cycle no longer compares equal, and comparisons within a run, across processes and
between the render shell and a headless run all still hold.

One incidental observation from the unfixed probe, worth recording because it
looks like a contradiction of the review and is not: on seeds 1234 and 99991
`world.digest()` *did* move after the write, from `c9a11071c7b3dbd1` to
`2c0031c49cebf624` and from `39d032788c6b95cc` to `6696d3a56c525ebc`. That is not
the fingerprint noticing the island's shape. The probe stands the observer on the
island's centre, and the digest carries a flag for whether the observer is
standing on an island; retuning the relief moved the island's top out from under
them and flipped it. The island's own digest is unchanged across the same write
(`b41fc43fc3e01976` before and after), which is the review's actual claim and it
holds.

## 7. Suites

```
all 14 suites passed (129253 checks)
layer check: OK -- res://sim references nothing in the render layer
asset check: OK -- res://sim names asset tags and no asset
```

Up from $129\,173$ checks before this task: $52$ new checks in the islands suite
(the fingerprint-covers-the-fields check, the detection check, and the isolation
check over three seeds) and $28$ in the render-shell suite (the nine-handle
sweep).
