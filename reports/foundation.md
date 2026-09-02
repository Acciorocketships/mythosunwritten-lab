# The foundation: what runs, and what it settles

The game did not exist yet — the repository held no source files. This first
stretch of work (a *slice*: one thin piece built through every layer rather than
one layer built widely) had to pick what to build the game with, get it running,
and check the two properties everything later leans on: that it runs with no
graphics at all (*headless*), and that the same *seed* — the single whole number
$s$ the world is grown from — always produces exactly the same world.

## Verified facts

**The stack is the Godot 4 engine (version 4.7.2), written in its own language,
GDScript.** This machine had no game engine on it at all — no Godot, Unity or
Unreal, and no Rust, Go or .NET either. So the choice was settled by doing it
rather than by argument: Godot 4.7.2 was installed inside the project at
`tools/godot/godot4` and run on this screenless machine, where it reported its
display driver as "headless", reproduced seeded noise bit-for-bit, and built 3D
geometry with no renderer present.

**Three commands, re-run while writing this:**

```
./run_headless.sh --seed 1234 --ticks 40   # no graphics at all; prints a trace; exits 0
./run_render.sh  --seed 1234               # the same simulation, in a window
./run_tests.sh                             # every suite, headless
```

`./run_tests.sh` reports **all 6 suites passed (6109 checks)**, exit code 0.

**Determinism, checked outside the tests.** Each headless line carries a
*digest* — a short fingerprint standing in for "is this the same world?".

| run | seed $s$ | ground loaded | final digest |
|---|---|---|---|
| A | 1234 | 39 chunks | `dc5e4f8aa127fa84` |
| B | 1234 | 39 chunks | `dc5e4f8aa127fa84` |
| C | 7 | 39 chunks | `9995e3218183e657` |

A *chunk* is a 16×16-unit square of ground; the world builds chunks near a
walker and drops the rest, so the map can be endless.

![The observer walking through a meadow, seed 1234 at tick 40: a rigged KayKit
ranger seen from behind, mid-stride, on the streamed ground with grass, trees
and floating islands around it](reports/assets/observer-character.png)

That used to be a ball. The observer was drawn as a 0.6-unit glowing sphere for
as long as there was nothing to look at but terrain; `W-character-visuals`
replaced it with a real animated character, which walks when the simulation says
it is moving and stands still when it is not. The simulation is unchanged and
does not know: it holds a position, a heading and how far it moved last tick, and
which animation that becomes is decided in the render layer. See
[`reports/characters.md`](characters.md).

## What the independent check found, and what was fixed

The review re-ran the claims instead of trusting the prose. **Headless is
genuine**: with the whole `render/` directory deleted, the headless run produced
byte-identical output. **Seed determinism is genuine**: three separate processes
at $s = 1234$ agreed exactly; a different seed diverged.

**The third claim — rendering can never affect the simulation — was not true
when checked.** The render shell was handed the live terrain object the
simulation holds, so writing through it would land in the world; and the chunk
fingerprint was computed once and cached, so the very test that compared
fingerprints could not have noticed. Separately, the determinism tests compared
two runs that took the same route through the world, so a bug making the world
fingerprint depend on the *order* things were visited passed all 6075 checks.

Both are fixed. The fingerprint is now recomputed from current contents (cost
measured, not assumed: the suite goes 3.0 s → 4.2 s, a 100-tick headless run
105 ms → 389 ms). The render layer gets a detached copy while the
simulation keeps the original — about 1 microsecond against the ~810
microseconds of building the chunk.

**What the tests do not prove.** They cover the ground layer and one placeholder
walker; there is no gameplay yet. Determinism is verified across processes on
this machine and engine build — not across machines or versions. The layer check
is textual: it scans the simulation folder for render paths and engine
presentation types, so it enforces the rule as written, not every conceivable
route between the layers.

## The method this phase settled on

A passing test is evidence only once it has been shown to *fail* against the bug
it targets — otherwise it may be passing for reasons unrelated to the claim. Both
review findings had been sitting under a green suite. So every fix here was
checked by putting the bug back: the cached fingerprint
failed 3 checks, the order-dependent one 1, and four separate render-isolation
bugs failed 6, 5, 1 and 3. Twice, a newly written test passed under its own
injected bug and had to be rewritten — found only because it was deliberately
tried.

## Decisions taken (reversible)

Godot 4 and GDScript, provisionally and pending your confirmation; the
simulation core never mentions the engine's presentation facilities, so the
choice stays cheap to reverse. Naming follows the task's own vocabulary.

## Open decisions that need you

1. **Confirm the engine.** Nothing on the machine settled it; Godot 4 fits the
   task's vocabulary and is now verified to work here.
2. **Where is the terrain base?** The task says layers 1–3 already exist and
   names the pieces. A case-sensitive search of the whole home directory found
   them only inside the task text itself. They have been built from scratch
   under those names — but if that code exists somewhere, it should be merged
   before more layers are stacked.
3. **The art packs and reference images are missing.** The KayKit and Daniel
   Mistage packs and the folder `~/Desktop/game visual inspiration` are absent
   from the Linux home and both mounted Windows drives. The look cannot be
   judged against your references until they arrive, so the next phase would be
   working from the written description alone.
