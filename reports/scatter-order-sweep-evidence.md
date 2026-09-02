# The scatter layer's order and reload checks sweep a block

Every command and its verbatim output. Nothing was run inside the working tree
except the final green suite; the pristine snapshot and all four injected copies
lived in a scratch directory outside it, and `sim/` and `render/` are shown to
diff byte-identical against the pristine snapshot afterwards.

Terms, once. *Chunk* — a fixed $16 \times 16$ world-unit square of ground, named
by an integer coordinate $(c_x, c_z)$. *Digest* (this project's word) — a short
SHA-256 fingerprint standing in for "is this the same thing?". *Order-dependence*
— a layer whose answer for a given key changes according to what was computed
before it. *Mutation testing* — injecting a bug into a copy of the code to see
whether the suite notices, since a test that stays green under an injected bug is
not testing what it claims to.

## What changed

`tests/test_scatter.gd` only. Two checks were widened; nothing else in the tree
was touched.

| Was | Is |
| --- | --- |
| `_a_chunk_is_the_same_fresh_as_after_its_neighbours` — one named chunk, $(2,-3)$, built fresh and built after its 48 neighbours | `_a_block_of_chunks_is_the_same_dressed_in_either_order` — a $13 \times 13$ block of 169 chunks built front to back by one `DecorationScatter` and back to front by a second, the two digest maps compared chunk by chunk, plus a third pass from the field the suite has been using all along |
| `_a_chunk_dropped_and_reloaded_comes_back_identical` — one named chunk, the one under the observer at spawn | `_every_chunk_dropped_and_reloaded_comes_back_identical` — every chunk the streamer had loaded at spawn (32 of them), all dropped by a 400-unit walk, and the observer returning from the *far* side of the world, every chunk compared against its own before-digest and against a fresh field |

The block reach is `ORDER_REACH = 6`. Why a block at all is written into the
constant's doc comment: an order-dependence in this layer does not change every
chunk it touches, only the ones where a roll happened to be sitting near the edge
of a decision, so how much of it a check notices is simply how much of the layer
the check sweeps.

## The injection

The finding's own bug, a plausible anti-clumping rule: thin a cell's roll by a
constant when the cell just examined placed something. A chunk's contents then
depend on what was built before it.

```diff
--- pristine/sim/decoration_scatter.gd
+++ inj-old-02/sim/decoration_scatter.gd
@@ -150,6 +150,11 @@
 ## Everything this layer asks about the ground. It asks; it never recomputes.
 var terrain: TerrainQuery = null

+## INJECTED BUG: anti-clumping. How much a cell's roll is thinned when the
+## cell just examined placed something, and whether it did.
+const CROWD_THINNING := 0.02
+var _crowded := false
+

 func _init(query: TerrainQuery = null) -> void:
 	terrain = query
@@ -195,7 +200,15 @@
 ## on nothing else -- not on which chunk asked, not on what has been asked
 ## before, and not on which process is asking.
 func item_in_cell(lattice: String, cell: Vector2i) -> Dictionary:
-	var pick := _roll(lattice, cell, SALT_PICK)
+	# INJECTED BUG: remember whether this cell placed anything, for the next one.
+	var placed := _item_in_cell(lattice, cell)
+	_crowded = not placed.is_empty()
+	return placed
+
+
+func _item_in_cell(lattice: String, cell: Vector2i) -> Dictionary:
+	# INJECTED BUG: a cell next to something that was placed grows less readily.
+	var pick := _roll(lattice, cell, SALT_PICK) + (CROWD_THINNING if _crowded else 0.0)
 	# The cheap way out, taken by about three cells in eight: no weight anywhere
 	# can reach this far along the line, so nothing here can be placed and
 	# nothing about the ground here needs to be asked.
```

Four copies were made from the same pristine snapshot: the injection at $0.02$ and
at the seven-times-stronger $0.15$, each paired once with the **old** suite and
once with the **new** one. All four ran `./run_tests.sh` in their own copy.

## Result

| Copy | Scatter suite | Whole run |
| --- | --- | --- |
| pristine sim, old tests | `PASS  scatter        127 checks` | `all 14 suites passed (129253 checks)` |
| pristine sim, new tests | `PASS  scatter        295 checks` | `all 14 suites passed (129421 checks)` |
| **injected 0.02**, old tests | `PASS  scatter        127 checks` | `all 14 suites passed (129253 checks)` |
| **injected 0.02**, new tests | `FAIL  scatter        295 checks, 5 failed` | `1 of 14 suites failed (5 failed checks of 129421)` |
| **injected 0.15**, old tests | `PASS  scatter        127 checks` | `all 14 suites passed (129253 checks)` |
| **injected 0.15**, new tests | `FAIL  scatter        295 checks, 7 failed` | `1 of 14 suites failed (7 failed checks of 129421)` |

So the finding reproduces exactly — both strengths sail through all 14 suites as
they stood — and the widened check catches both.

The chunks it names, verbatim:

```
=== inj-new-02 ===
FAIL  scatter        295 checks, 5 failed
        - chunk (-6,-6) came out different dressed back to front
        - chunk (-3,4) came out different dressed back to front
        - chunk (-2,6) came out different dressed back to front
        - chunk (2,6) came out different dressed back to front
        - chunk (4,2) came out different dressed back to front
=== inj-new-15 ===
FAIL  scatter        295 checks, 7 failed
        - chunk (-6,-6) came out different dressed back to front
        - chunk (-3,4) came out different dressed back to front
        - chunk (-2,-5) came out different dressed back to front
        - chunk (-2,6) came out different dressed back to front
        - chunk (2,6) came out different dressed back to front
        - chunk (4,2) came out different dressed back to front
        - chunk (5,4) came out different dressed back to front
```

Those five are exactly the five of the finding's ten that lie inside a $13 \times
13$ block. The finding listed $(4,2)$, $(2,6)$, $(2,-8)$, $(0,8)$, $(0,-8)$,
$(-2,6)$, $(-2,-7)$, $(-3,4)$, $(-6,-6)$, $(-7,1)$ from a $17 \times 17$ block of
289 chunks; the other five sit outside reach 6 and would be caught by a wider
block at proportionally more cost.

Which check fires is worth stating plainly: it is the **order sweep**, not the
reload sweep. The reload sweep rebuilds the block with a different amount of
history behind it, but the streamer visits chunks in the same order both times,
so with this particular injection only the first chunk of the rebuild sees a
different predecessor. The reload sweep now covers the block, which is what makes
it able to notice a bug of that shape at all, but the order sweep is the detector
here.

## The unmodified scatter passes the wider sweep

`PASS  scatter        295 checks` on the working tree, and the 169-chunk order
sweep reports no differing chunks in any of its three routes. There is no order
dependence in `DecorationScatter` as it stands, so nothing in `sim/` needed
fixing.

## Cost

| | Before | After | Added |
| --- | --- | --- | --- |
| Scatter suite alone | 62.597 s | 74.636 s | **+12.0 s** (+19%) |
| Whole suite, `./run_tests.sh` | 6 m 41.9 s | 6 m 52.9 s | **+11.0 s** (+2.7%) |
| Checks | 129 253 | 129 421 | +168 |

The scatter suite alone was measured with a scratch harness that runs only that
suite; the whole-suite numbers are `time ./run_tests.sh` on the pristine snapshot
and on the working tree, on the same machine with nothing else running.

## The tree afterwards

```
$ diff -r scratch/pristine/sim sim && echo "sim/: identical"
sim/: identical
$ diff -r scratch/pristine/render render && echo "render/: identical"
render/: identical
$ diff -rq scratch/pristine/tests tests
Files scratch/pristine/tests/test_scatter.gd and tests/test_scatter.gd differ
$ grep -c "CROWD_THINNING\|_crowded" sim/decoration_scatter.gd
0
```

`tests/test_scatter.gd` is the one file this work item changed. `sim/` and
`render/` are byte-identical to the snapshot taken before any of this ran.

## Final suite, headless

```
$ ./run_tests.sh
PASS  rng            1325 checks
PASS  determinism    15 checks
PASS  terrain        32 checks
PASS  streaming      4695 checks
PASS  biomes         212 checks
PASS  water          6358 checks
PASS  islands        93224 checks
PASS  island cover   6252 checks
PASS  settlements    8929 checks
PASS  scatter        295 checks
PASS  layering       12 checks
PASS  asset tags     995 checks
PASS  window glow    7019 checks
PASS  render shell   58 checks

all 14 suites passed (129421 checks)

real	6m52.898s
```
