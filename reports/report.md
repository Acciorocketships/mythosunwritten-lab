# What a character is now, and what the action interface settles

A fantasy world simulator: an endless landscape grown from one number — the
**seed** — in which the player is one character among many and gets no
privileges. This step built what a character is made of, what it can *choose* to
do, how a choice is refused, and how the world decides whether it keeps going,
then ran five characters through it all **headless** (drawing turned off).

## One sheet, and nothing that asks who is a player

One character type holds six ability scores ($STR$, $CON$, $CHA$, $DEX$, $WIS$,
$INT$), level, standing, health, what is carried and worn, four identity fields,
and two still-empty handles, for memory and for feelings toward others. A
**commander** — a character on the tactical board, whose death removes the
chess-like units it commands — keeps no copy of it.

| | level | standing | assigned |
|---|---|---|---|
| Wren | $3$ | $3$ | — |
| Bramble | $3$ | $12$ | $12$ |

Read literally, "for the player, status = level" needs a field naming players.
It is a default instead: standing starts unassigned, then reads
the level. No file *can* ask who is a player: a scan for eleven such words across
the simulation returns nothing, and catches planted lines.

## Twelve actions, one call surface

The design names this set twice — what a character may do, and the calls a
program makes to do it — so both are now columns of **one** twelve-row table and
cannot drift apart. A checker reads it against the code resolving each row, and
bites on six broken copies. Each action occupies **ticks** (steps of the world):

| action | ticks | action | ticks |
|---|---|---|---|
| go to | $20$ | pick up | $3$ |
| jump | $4$ | drop | $2$ |
| attack | $6$ | examine | $4$ |
| say | $5$ | interact | $6$ |
| trade: propose / accept / deny | $4/3/2$ | wait | its own duration |

No thirteenth action; no choosing without a sheet; no attack that starts a fight
(it is refused); no giving except as a trade wanting nothing back; no model
call anywhere.

## How an action fails

Every path out returns a sentence, and **twelve refusals in a row move nothing**:
the scene's fingerprint — one string over every position, coin, item, offer and
word — is identical either side.

| the case | the sentence returned |
|---|---|
| a jump past $DEX$ | `8.00 is further than DEX 4 jumps (4.50)` |
| a trade already denied | `the offer from Rook was denied` |
| a target out of shape | `Vex is outside the pattern of a common bow from here` |
| a chest, bare-handed | `the chest needs a lockpick` |

Each is paired with a case that succeeds, so a refusal is the rule biting: a
$4.00$ jump at that $DEX$ lands.

## Deciding whether to keep going

While an action runs the character is asked again every $5$ ticks; wanting
something else, it stays with what it is doing anyway with probability $0.85$ —
the **continue bias**. A character built to want somewhere else *every* time ran
$1200$ ticks, then again with the bias deleted:

| continue bias | times asked | changed its mind |
|---|---|---|
| $0.85$ | $193$ | $16.1\%$ |
| $0.00$ (deliberately broken) | $239$ | $100\%$ |

The four interruptions the design names — struck, a fight starting, being spoken
to, an action finishing — are read off the world by comparing it with a tick ago.
A decider taking $40$ ticks to answer stalls nobody: neighbours served on all
$80$ ticks either way.

## Five characters, one seeded run

![Wren and Rook on the meadow just after the trade](reports/assets/scenario-market.png)

*Tick $66$: Wren (pointed hat) and Rook (blue, right) just after the cloak and
coins changed hands; the third figure is the camera.*

`./run_scenario.sh` plays five characters for $110$ ticks at seed $1234$; they
differ in one field, the function that chooses. Wren's is a person's ten turns
written down in advance; the rest are rules.

```
t=  6  Rook   interrupted (spoken to), abandoned wait(ticks=4) 1/4t
t= 54  Wren   began trade_propose(target=2 give_money=12 want=[silk cloak])
t= 62  Rook   finished trade_accept(target=1) -> ok took_money=12 gave=1
t= 77  --     Bram and somebody of another band have met
    snap-in board 15a5a4b9f14a7bfc cells=441 standable=440 holes=1 cliffs=6
t= 78  Bram   interrupted (combat began), abandoned wait(ticks=4) 1/4t
t= 85  --     the fight is over; real time again
```

| | before | after |
|---|---|---|
| Wren's money | $30$ | $18$ |
| Rook's money | $8$ | $20$ |
| the silk cloak | Rook carries it | Wren carries it |

Only the two who met were taken in: Wren, $50.8$ units off, traded on and shouted
at tick $104$. Bram fell in $4$ rounds; Sable left at $16/38$ health.

![Bram and Sable during the quarrel](reports/assets/scenario-quarrel.png)

*Tick $80$: Bram (helmeted) and Sable, right. The board they fight on is in the
scene — the run reports its $441$ cells — but is not visible: the review measured
its overlay lifting the ground by $1.449$ of $255$ brightness, under what anyone
can see.*

## Verified, found, decided, open

**Verified by an independent review run today**, which re-ran everything rather
than reading write-ups: $33$ suites pass, $191{,}854$ checks; `./run_scenario.sh`
reproduces the checked-in transcript byte for byte; the two **mutation
harnesses** — which plant a broken rule and require the suite to notice — caught
$19/19$ and $61/61$. Its probe attacked the no-privileges principle five ways:
$0$ of $12$ actions, $0$ of $16$ loop entries, $0$ of $289$ transcript lines and
$0$ of $10$ combat numbers moved when the person-driven character was replaced by
a program-driven one.

**Found, reported rather than patched.** The one asymmetry runs the other way:
the library's person-shaped decider is a queue drained by *being asked*, so $4$
of $10$ written-down turns were taken where a decider indexed by what has been
carried out takes $10$ of $10$. And an `attack` chosen here never finishes its
$6$-tick span in a fight striking every tick, because being struck interrupts it;
the turn layer resolved that fight instead. Missing is a rule joining ticks to
turns.

**Two things the review could not verify.** The repository has one commit and
every file this step touched is uncommitted, so "these numbers did not move" has
no before-state to check against; what was measured now is quoted instead. And an
earlier acceptance line quotes two world fingerprints `./run_headless.sh` does
not produce — moved by a road fix that predates this step, filed.

**Decided.** Unassigned standing reads the level; the two action lists are one
table, a cost is a column of it; the engine resolves, the caller only chooses.

**Left open for the language-model milestone.**

- the decision handle, which no model yet fills;
- the memory and sentiment handles, still empty;
- who owns the seam between real-time ticks and combat turns;
- whether a person's recorded turns belong in the shared library;
- what *using* a consumable does.

Working: `reports/scenario.md`, `reports/characters-review-evidence.md`.
