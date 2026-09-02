# Detection gaps — evidence log

The foundation review found two places where a rule the project claims to
follow could be broken without any test noticing. This log records closing both
of them: what changed, what the new checks are, that each one really fails when
the bug it targets is present, and what the change costs.

Terms used here, defined once. *Chunk* — a fixed $16 \times 16$ world-unit
square of ground, addressed by an integer coordinate $(c_x, c_z)$. *Streamer* —
the object that keeps the chunks near an observer built and drops the rest;
what it holds is a dictionary keyed by chunk coordinate. *Digest* (this
project's word) — a short SHA-256 fingerprint standing in for "is this the same
thing?", computed for one chunk's geometry (`TerrainChunkGeometry.digest()`) and
for the whole world (`SimWorld.digest()`), the latter folding in the former for
every loaded chunk. *Memo* — a value computed once on first call and returned
unchanged thereafter. *Mutation testing* — deliberately introducing a bug to see
whether the suite notices; a test that stays green under the bug it is supposed
to catch is not testing what it claims to.

Unlike the review's evidence log, the injections below were applied to the
working tree itself, then removed, because the change being demonstrated is in
that tree. Each injection is quoted, its failing output is quoted verbatim, and
the tree is shown green again after removal.

---

## 1. What changed

**`sim/terrain_chunk_geometry.gd`** — the memo is gone. `digest()` now walks the
chunk's vertices and normals on every call:

```gdscript
func digest() -> String:
	var parts := PackedStringArray()
	parts.append("chunk=%d,%d" % [chunk_x, chunk_z])
	parts.append("tris=%d" % triangle_count())
	for i in vertices.size():
		var vertex := vertices[i]
		var normal := normals[i]
		parts.append("%.4f,%.4f,%.4f/%.4f,%.4f,%.4f" % [
			vertex.x, vertex.y, vertex.z, normal.x, normal.y, normal.z,
		])
	return "|".join(parts).sha256_text().substr(0, 16)
```

No cache is kept, so there is no cache to invalidate. Section 4 measures what
that costs and what a cache would have saved.

**`sim/world.gd`** — unchanged. `SimWorld.digest()` already iterated
`terrain_streamer.loaded_keys()`, which is sorted. The gap the review found there
was not a live bug but an *untested* property: nothing failed if that sorting
were dropped. Section 3 is what now fails.

**Three checks added**, one per file:

| file | check | what it would catch |
|---|---|---|
| `tests/test_terrain.gd` | `_a_chunk_fingerprint_follows_its_contents` | a chunk's fingerprint not tracking its own contents |
| `tests/test_render_shell.gd` | `_a_write_into_loaded_ground_is_visible_to_the_world_digest` | a write through `terrain_streamer.geometry(key)` the world digest cannot see |
| `tests/test_determinism.gd` | `_two_routes_to_the_same_ground_agree` | a world fingerprint that depends on the order chunks were loaded |

---

## 2. Injection A — the memo, restored

The bug the review named, put back exactly as it was:

```gdscript
var _digest := ""  # INJECTED BUG: fingerprint memoised at first call

func digest() -> String:
	if not _digest.is_empty():  # INJECTED BUG
		return _digest
	...
	_digest = "|".join(parts).sha256_text().substr(0, 16)  # INJECTED BUG
	return _digest
```

```
$ ./run_tests.sh
PASS  rng            1325 checks
PASS  determinism    15 checks
FAIL  terrain        32 checks, 2 failed
        - writing into a built chunk did not change its fingerprint
      both values were: 6c1bbae97c99c042
        - changing a chunk's normals did not change its fingerprint
      both values were: 6c1bbae97c99c042
PASS  streaming      4695 checks
PASS  layering       12 checks
FAIL  render shell   9 checks, 1 failed
        - a write through terrain_streamer.geometry(0, -3) left the world digest unchanged: the simulation cannot detect being edited
      both values were: 85243e93e3e0f177

2 of 6 suites failed (3 failed checks of 6088)
```

Both new checks fail, at both levels: the chunk's own fingerprint and the whole
world's. The world-level failure is the review's finding stated exactly — a
write into loaded ground, made through the handle the render shell is given,
that the simulation cannot detect. With the injection removed, the suite is
green again (section 5).

---

## 3. Injection B — the world digest over the raw dictionary

`SimWorld.digest()` iterating the streamer's dictionary directly instead of its
sorted key list. That dictionary is in insertion order, so this makes the
fingerprint depend on the order the chunks were loaded in:

```gdscript
	for key in terrain_streamer._loaded:  # INJECTED BUG: raw dictionary, not sorted keys
		parts.append("%d,%d:%s" % [key.x, key.y, terrain_streamer.geometry(key).digest()])
```

```
$ ./run_tests.sh
PASS  rng            1325 checks
FAIL  determinism    15 checks, 1 failed
        - the same loaded ground fingerprinted differently depending on the order the observers were given in
      expected: cd1c370589644495
      actual:   def961cae361af29
PASS  terrain        32 checks
PASS  streaming      4695 checks
PASS  layering       12 checks
PASS  render shell   9 checks

1 of 6 suites failed (1 failed checks of 6088)
```

The check loads one set of 71 chunks two ways — `update([p, q])` against
`update([q, p])` for the same pair of observer positions — and compares the two
world digests. Both orderings reach an identical loaded set (the check asserts
that first, so the digest comparison cannot pass vacuously); only the dictionary
order differs.

### A false start worth recording

The first version of this check used $p = (0, 0)$ and $q = (70, -45)$, and it
**passed under injection B** — that is, it did not work. A fresh world has
already loaded the ground around the origin before either ordering is applied,
so an observer standing there adds no chunks, and both orderings fill the
dictionary identically. Probing three position pairs directly:

| observers | chunks | same sorted key list | same raw dictionary order | same digest under injection B |
|---|---|---|---|---|
| $(0,0)$, $(70,-45)$ | 59 | yes | **yes** | yes — check useless |
| $(70,-45)$, $(-60,50)$ | 71 | yes | no | **no** — check bites |
| $(120,0)$, $(-120,30)$ | 64 | yes | no | **no** — check bites |

The check now stands both observers away from the origin, and the reason is
written into the test so it is not silently undone later. This is the general
hazard with order-independence checks: they pass either when the property holds
or when the two routes were never actually different, and only mutation testing
tells those apart.

---

## 4. What it costs

Removing the memo means every chunk fingerprint is recomputed on every call, and
the world fingerprint folds in ~40 of them. Measured with `Time.get_ticks_usec()`
on this machine, averaged over repeated calls (200 for a chunk, 20 for a world,
seed 1234, 41 chunks loaded):

| measurement | with memo | without memo (shipped) | factor |
|---|---|---|---|
| one chunk's `digest()` | 3.9 µs | 749.5 µs | ×192 |
| one `SimWorld.digest()` | 1.51 ms | 29.3 ms | ×19 |
| `Simulation.run(100)` — a 100-tick headless run, 13 report lines | 105 ms | 389 ms | ×3.7 |
| `./run_headless.sh --seed 1234 --ticks 100`, wall clock incl. engine start | — | 0.50 s | — |
| `./run_tests.sh`, wall clock, best of 3 | 3.01 s | 4.22 s | ×1.40 |

So the honest number is: **the whole test suite got 1.2 s slower, and a 100-tick
headless run got 0.28 s slower.** The per-call factors look alarming and the
wall-clock cost does not, because the memo was turning a 750 µs computation into
a dictionary-free string return.

This cost grows with two things: how many chunks are loaded, and how often the
digest is asked for (once per traced tick, so every 10 ticks). Later generation
layers — decoration, settlements, grass — will add vertices per chunk, and the
cost is linear in those.

A cache is possible if that becomes a problem, and would have to be keyed on the
geometry's contents rather than merely computed once. Godot's built-in
`hash(PackedVector3Array)` over one chunk's vertices, normals and indices costs
**2.78 µs**, against 749.5 µs to recompute the fingerprint — so a content-keyed
cache would recover roughly 270× of the recompute cost. It is deliberately not
shipped: it reintroduces a way for the fingerprint to be stale (a hash
collision), for a saving the wall-clock numbers above do not yet justify. The
measurement is recorded here so the option can be taken later without
re-deriving it.

---

## 5. The suite, green, after both injections were removed

```
$ ./run_tests.sh
PASS  rng            1325 checks
PASS  determinism    15 checks
PASS  terrain        32 checks
PASS  streaming      4695 checks
PASS  layering       12 checks
PASS  render shell   9 checks

all 6 suites passed (6088 checks)
```

```
$ ./run_tests.sh --layers-only
layer check: OK -- res://sim references nothing in the render layer
```

Check counts rose from 6075 to 6088: thirteen new expectations across the three
suites (determinism 12 → 15, terrain 26 → 32, render shell 5 → 9), measured by
running the suite with the three new checks switched off and again with them on. The render-shell suite's own comparison — the shell's world against a
headless run of the same seed — still passes with the fingerprint recomputed
rather than cached, so the two guarantees the task worried might be in tension
are not.

---

## 6. What this does not do

The write in section 2's check is still *possible*: the render shell is handed
the live geometry object, and nothing stops a viewer editing it. What changed is
that the edit is now detectable. Handing the viewer something it cannot write
through is the next task's subject; this one is the precondition for showing
that that task worked.
