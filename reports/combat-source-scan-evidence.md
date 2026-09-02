# The two structural guarantees, checked over a scan instead of a list

Evidence for the change that replaced `_combat_sources()` — a fourteen-path array
typed into `tests/test_combat_resolution.gd` — with a scan of the `sim/`
directory. Every command below was run headless from the project root.

Two terms, both this project's own. An **injection** is one deliberate edit to a
single line of `sim/`, chosen to be a bug a person could plausibly write, after
which the suites are run to see whether any of them notices. A **detection gap**
is a rule that survives one: the code was broken on purpose and every suite
stayed green, so nothing was checking that rule.

---

## What was wrong

Both of the combat layer's structural claims — *exactly one file calls the damage
seam `Damage.resolve(`*, and *no combat file names a random source* — were
checked by reading a list of fourteen paths written into the test. Ten combat
files had joined `sim/` since that list was written:

```
sim/board_sketch.gd          sim/combatant.gd            sim/encounter.gd
sim/combat_board.gd          sim/combatant_roster.gd     sim/scripted_encounter.gd
sim/combat_board_builder.gd  sim/combat_policy.gd        sim/simulation.gd
sim/combat_snap.gd
```

Meanwhile `reports/combat.md` stated the seam property over `sim/` as a whole.
The test was checking a subset of the sentence the report printed.

## The detection gap, reproduced

The injection: a second call to the damage seam in `sim/combat_policy.gd`, in
`_swing()`, on the line that takes the swing. The added local is discarded, so
the fight plays exactly as before and no transcript changes — only a source scan
can see it.

```gdscript
	if best_index >= 0:
		var _roll := Damage.resolve(1, Damage.NONE, 0)     # <-- injected
		played.attack(best_index)
```

With the fourteen-path list still in place, every suite passed:

```
$ ./run_resolution.sh
PASS  combat resolution  294 checks

$ ./run_tests.sh
all 23 suites passed (172929 checks)
```

That is the gap: the seam property is the whole reason a future attack roll would
be one edit, and it could be broken without a single check going red.

## The same injection against the scan

With the scan in place and nothing else changed:

```
$ ./run_resolution.sh
FAIL  combat resolution  314 checks, 1 failed
        - exactly one file under sim/ calls the resolution seam
      expected: ["res://sim/combat_resolution.gd"]
      actual:   ["res://sim/combat_policy.gd", "res://sim/combat_resolution.gd"]
```

The other half of the guarantee bites on the same file. An unused `randi()` in
the same place — again changing no behaviour, so the determinism tests that
backstop this claim cannot see it either:

```
$ ./run_resolution.sh
FAIL  combat resolution  314 checks, 1 failed
        - no file of the combat layer touches a random number
      expected: []
      actual:   ["res://sim/combat_policy.gd -> randi"]
```

Both injections are now permanent entries in `tools/resolution_mutations.sh`
(`a second file calls the damage seam`, `a random source reaches the file that
plays a turn`), so they are re-run on every sweep rather than recorded once here.

## What the two checks now read, and why the scopes differ

| check | scope | how the scope is found |
|---|---|---|
| `Damage.resolve(` appears in exactly one file, exactly once | all **52** files under `sim/` | `DirAccess` over `sim/` |
| no `randi`, `randf`, `randomize`, `RandomNumberGenerator` or `Rng.` | the **24** of those that name the combat layer | the same scan, filtered by whether the file names a combat class |

The seam check has no exceptions: it is every file the directory holds, which is
the sentence `reports/combat.md` prints.

The random-source check is narrower **because generation is seeded-random by
design**. Terrain, biomes, islands, settlements, paths and scatter all draw on
the project's own deterministic hash `SimRng`; forbidding it across the whole of
`sim/` would forbid the world rather than the fight. So a file is in scope when
it names a class of the combat layer — `LayerCheck.FORBIDDEN_IN_RENDER`, the
list of names the render layer is not allowed to use, plus `CombatBoard`, which
that check deliberately leaves out because the shell is allowed to draw a board.
There is one list of what the combat layer is called and both checks read it.

Filtering that way is what makes the set self-maintaining: every combat file
written so far names another combat class, so a file added tomorrow lands in the
scan without anyone remembering to add it.

**One file is excused, by name: `sim/world.gd`.** It names `CombatantRoster`,
`CombatBoardBuilder` and `CombatBoard` while also seeding the terrain generator,
because it is the world a fight stands on rather than part of the fight — it
holds the roster and hands out a board and nothing more. The excuse is not taken
on trust: the suite requires that `sim/world.gd` contains none of `Damage.`,
`CombatResolution.`, `CombatMatch.`, `CombatPolicy.`, `LegalMoves.`, `MoveGrant.`
or `PieceGeometry.`, so it cannot become a place to park a rule of a turn outside
the scan. Writing a turn rule there fails the suite.

The scan is also checked for not being vacuous, in this suite's usual way: the
same read over a string that *is* in all 24 files (`func `) is required to find
it in all 24, so the empty random-source result means "not there" and not "the
scan read nothing".

## Everything green afterwards

Both mutation harnesses, run sequentially with nothing else running:

```
$ ./tools/resolution_mutations.sh
a second file calls the damage seam                  sim/combat_policy.gd  failed, as it must
a random source reaches the file that plays a turn   sim/combat_policy.gd  failed, as it must

all 41 broken rules were caught

$ ./tools/piece_mutations.sh
all 17 broken rules were caught
```

Then the suites, the structure checks, and the world:

```
$ ./run_tests.sh
all 23 suites passed (172949 checks)

$ ./run_tests.sh --layers-only
layer check: OK -- res://sim references nothing in the render layer
combat check: OK -- res://render draws the fight and holds none of it
asset check: OK -- res://sim names asset tags and no asset

$ ./run_headless.sh
done ticks=100 chunks=41 built=69 final=a6aa8e5776ebfe8c
```

The seed-1234 fingerprint `a6aa8e5776ebfe8c` is byte-identical to the run taken
before the change, and the whole 100-tick transcript diffs clean. Nothing under
`sim/` was renamed, moved or edited: this was a change to what the tests read,
not to what the combat layer does.
