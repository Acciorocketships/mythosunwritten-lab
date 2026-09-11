# The bargain suite stops turning on what one model reply happened to do

`tests/test_bargain.gd` used to hard-assert an end-to-end purchase carried out by
a language model. Six of its checks were claims about one draw — the trader
accepted, the lantern arrived, the price was paid, he no longer carries it, the
sale closed his goal, the pack window shut — and when `BARGAIN_ROWS` was
re-recorded on 2026-09-09 the first draw failed all six. A second pass was run
and the draw that closed the sale is what ships. That is a recording chosen on
the outcome of a test, disclosed at the time in
[observation-position.md](observation-position.md) and
[dialogue-trade.md](dialogue-trade.md), and filed as a finding.

This is that finding answered. Nothing in the simulation changed; the suite did.

## 1. The cause, with a file and a line

The finding's own reading was a claim to confirm, not to adopt: *it is not the
packet, it is the test*. Confirmed, both halves.

**It is the test.** The six red checks were six lines, all of them assertions
about the trader's own choice, at `tests/test_bargain.gd` as it stood at
`182a191`:

| line | the assertion |
| --- | --- |
| 202 | `the trader should have accepted a bargain` |
| 204 | `the lantern should be in the person's pack` |
| 213 | `the person paid the price` |
| 216 | `and the trader no longer carries it` |
| 218 | `the sale closed what the trader was after` |
| 256 | `with no trade standing the pack is shut again` |

Lines 202–218 are one method, `_the_model_driven_trader_answered_and_the_item_arrived`,
whose subject is what the trader decided. Line 256 reads the closing examine,
which shows no pack only if no offer is standing at tick 115 — which is again the
trader's choice, since a trader still repeating his own offer still has one
standing. No other check in the suite named a decision of the trader's.

**It is not the packet.** `net/bargain_draws.gd` now keeps the failing draw
itself — `BARGAIN_ROWS` as shipped at `6c79f56`, copied out verbatim — and it is
replayed by the suite on every run. Against the code at HEAD it still closes no
sale, and every machinery claim in the suite holds on it anyway (§2). The trade
surface was never broken on that draw; it was simply not used.

## 2. The same run through every draw there is

`./tools/bargain_draws_probe.sh` plays the identical arc — the same seed, the
same cast, the same written-down key presses — once per recorded table, and
prints what that draw's trader did beside what held whatever he did. Full output:
[bargain-draws-evidence.txt](bargain-draws-evidence.txt).

**What each draw's trader happened to do** — three different stories:

| | shipped, 2026-09-09 (`c8c351f`) | first table, 2026-09-07 (`9871350`) | first draw of 2026-09-09 (`6c79f56`) |
| --- | --- | --- | --- |
| an acceptance of his was honoured | yes | yes | **no** |
| the lantern is in the person's pack | yes | yes | **no** |
| the person's purse (opens at 20) | 15 | 15 | **20** |
| the trader still carries the lantern | no | no | **yes** |
| the trader's purse (he is after 10) | 11 | 11 | **6** |
| the closing examine shows a pack | no | no | **yes** |

**What held on all three anyway** — the same six answers down every column:

| | shipped | 2026-09-07 | the failing draw |
| --- | --- | --- | --- |
| coins in the two purses, end vs start | 26 / 26 | 26 / 26 | 26 / 26 |
| the lantern has exactly one holder | yes | yes | yes |
| every purse moved by what the ledger says | yes (−5 / +5) | yes (−5 / +5) | yes (0 / 0) |
| the pack window matched the standing trade, per tick | yes, 0 of 130 disagreed | yes, 0 disagreed | yes, 0 disagreed |
| the keyboard's ask named the lantern and stood | yes | yes | yes |
| every refusal carried the engine's own reason | yes (2) | yes (1) | yes (2) |

The first table is the one that moves with the draw, and the second is the one
the suite now asserts. That is the whole change.

## 3. What the suite asserts now

* `_the_machinery_held()` runs over **every** draw in the repository — the
  shipped table and both past draws — and holds none of the trader's choices
  against him. A pack is shown exactly while a trade stands, in both directions,
  on every tick. Nothing is minted or destroyed: the two packs hold the same
  items and the same coins throughout, and the lantern has exactly one holder.
  Every coin that moved is on `ActionScene.trades`, the engine's own ledger, for
  the amount that trade named. Every refusal, to the person and to the model
  alike, carries the engine's reason.
* `_a_purchase_closes_when_the_other_side_says_yes()` asserts the whole arc
  end to end **with no model in the run at all**. The trader's mind is
  `_willing()`, a written-down counterparty that accepts a bargain and takes no
  gift — the exact mirror of `ScriptedPlay._haggling`, which denies every bargain
  and takes every gift. The lantern arrives, four coins leave the person's purse
  and nothing else does, the trader ends on the ten he was after, and the window
  shuts. Whether the trade surface carries a purchase is machinery; it is checked
  as machinery.
* `_what_the_shipped_recording_happened_to_do()` is the only check that turns on
  a recorded reply, and its name and its first sentence say so. It reads the
  transcript and asserts the consequences of whatever it finds, in either
  direction: on a draw that closed the sale, the lantern moved and at least the
  asking price was paid; on a draw that did not, the lantern is still the
  trader's and nothing was paid for it. A re-record changes what it reports. It
  does not change whether it passes.

Three of the machinery claims are written as biconditionals rather than as
assertions that something happened, because a draw is allowed to produce a world
in which it did not. If no trade ever stood, the person's opening offer must have
been refused in the engine's own words. If the pack window was shut when the key
that names an item was pressed, the key must have taken nothing. If the
acceptance after the denial succeeded, it must be on the trade ledger; if it
failed, it must carry one of the engine's two sentences for having nothing to
accept. None of these can be satisfied vacuously and none of them can be broken
by a trader who decides to walk away.

A pack-window claim of this shape is worth one caution, because the first cut of
it went red on two draws out of three for a reason that was not a bug: the
packet's `carries` **field** is the window, and its **contents** are the pack. A
trader who has just sold his only item is shown as carrying nothing, which is not
the same fact as a trader whose pack is not observable. The check reads the
field's presence, as `Observation.of` writes it.

## 4. Reproducing it

```
./tools/bargain_draws_probe.sh      # the three draws, side by side
./run_tests.sh test_bargain         # the suite over all of them
./tools/bargain_actions.sh          # the shipped run, printed end to end
```

## 5. The full suite, and what it does not certify

`reports/bargain-machinery-full-suite.log`, committed so it outlives the sandbox
that produced it. Its summary line, at line 2932:

```
3 of 73 suites failed (5 failed checks of 219422)
```

`PASS  bargain        2083 checks` is in it, at line 2887 — the suite this work
rewrote is green inside the full run, over all three draws, with no key, no
network and no model.

The three failures are **not** this work's, and that is measured rather than
asserted. A worktree at `182a191`, the commit this branched from, running those
three suites and nothing else:

```
FAIL  walk motion    93 checks, 2 failed
FAIL  scenario       160 checks, 1 failed
FAIL  agent          1238 checks, 2 failed
3 of 3 suites failed (5 failed checks of 1491)
```

The same three suites, the same five checks, before the change. They are a
stale checked-in scenario transcript, a shipped model recording whose prompts
have drifted (which needs a live pass to repair), and the one-mover scan
catching a text cursor in `tools/measure_ui.gd:500` — all three already reported
as finding `I-59d87f7cd259` by the work that preceded this. This change adds no
failure and removes none of theirs; what it changes in that log is one line,
from `PASS  bargain 46 checks` to `PASS  bargain 2083 checks`.
