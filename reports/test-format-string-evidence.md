# tests/test_characters.gd:499 -- format string and arguments now match

## What was wrong

In GDScript `%` binds tighter than `+`, so in

```gdscript
check(row.scene_path.contains("board_game"),
    "minion '%s' resolves to something other than the abstract board"
    + " piece the report names it as: %s" % [tag, row.scene_path])
```

the `%` applied to the second fragment alone -- one placeholder, two arguments --
and the concatenation happened afterwards. The fix is one pair of parentheses, so
the whole two-placeholder message is formatted:

```gdscript
check(row.scene_path.contains("board_game"),
    ("minion '%s' resolves to something other than the abstract board"
    + " piece the report names it as: %s") % [tag, row.scene_path])
```

Nothing else changed; the check asserts exactly what it did before.

## A full run prints no engine error

`./run_tests.sh` after the fix -- 25 suites, 188145 checks, exit 0, and
`grep -c "String formatting error"` over the captured output is 0. There is no
line matching `error`, `at:` or `backtrace` anywhere in the run.

```
PASS  characters     1295 checks

all 25 suites passed (188145 checks)
```

## The check made to fail deliberately

The condition was temporarily changed to `contains("board_game_DELIBERATE_MISMATCH")`
so all four minion rows fail, and the characters suite was run on its own through a
throwaway entry point (both reverted/removed afterwards).

**With the fix** -- the intended explanation, tag and path filled in, no engine error:

```
suite characters: 1295 checks, 4 failed
        - minion 'minion_toadstool' resolves to something other than the abstract board piece the report names it as: res://assets/kaykit_board_game_bits/KayKit_BoardGameBits_1.0_FREE/Assets/gltf/pawn_A_blue.gltf
        - minion 'minion_cat' resolves to something other than the abstract board piece the report names it as: res://assets/kaykit_board_game_bits/KayKit_BoardGameBits_1.0_FREE/Assets/gltf/pawn_B_blue.gltf
        - minion 'minion_ent' resolves to something other than the abstract board piece the report names it as: res://assets/kaykit_board_game_bits/KayKit_BoardGameBits_1.0_FREE/Assets/gltf/building_blue.gltf
        - minion 'minion_frog' resolves to something other than the abstract board piece the report names it as: res://assets/kaykit_board_game_bits/KayKit_BoardGameBits_1.0_FREE/Assets/gltf/meeple_blue.gltf
```

**Before the fix**, same deliberate failure -- the engine error (the message is
formatted whether the check passes or fails, which is why it showed up on green
runs too), and the message itself arrives with its placeholders unfilled:

```
ERROR: String formatting error: not all arguments converted during string formatting.
   at: validated_evaluate (core/variant/variant_op.h:770)
   GDScript backtrace (most recent call first):
       [0] _the_minions_are_named_as_uncovered (res://tests/test_characters.gd:499)
       [1] run (res://tests/test_characters.gd:60)
suite characters: 1295 checks, 4 failed
        - minion '%s' resolves to something other than the abstract board piece the report names it as: %s
        - minion '%s' resolves to something other than the abstract board piece the report names it as: %s
        - minion '%s' resolves to something other than the abstract board piece the report names it as: %s
        - minion '%s' resolves to something other than the abstract board piece the report names it as: %s
```
