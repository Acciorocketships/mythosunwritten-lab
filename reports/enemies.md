# Enemies in the running game

Before this, an enemy existed only where a runner mustered one: `./run_skirmish.sh`
stood a stranger on the meadow and `./run_encounter.sh` set two bands down beside
each other. The ordinary world -- the one the render shell steps and
`./run_headless.sh` prints -- held three wanderers and nothing that would ever
fight them.

It now holds enemies. They are placed by a field, streamed in and out around
whoever is in the world, decided for through the same seam every other character
uses, and a fight can begin because one of them chose to swing.

Everything below is measured on the shipped seed, $1234$, unless a line says
otherwise. The transcripts are checked in at
[`reports/enemies-evidence.txt`](enemies-evidence.txt).

---

## 1. Where an enemy is is a fact about the place

`sim/enemy_field.gd` is a sparse field on a lattice of cells, in the same shape
as the field that places villages: one cell holds at most one enemy, decided by a
hash of the cell and the world seed, and refused unless the ground will take it.

| what | value | why |
| --- | --- | --- |
| cell | $64$ world units | `ItemFrontier.RING_SPAN` -- one band of the section 5 difficulty gradient, so a ring of the gradient is a ring of enemies rather than a smear |
| chance a cell wants one | $0.62$ | before the ground has its say |
| spots tried in a cell | $4$ | jittered into the middle half of the cell, so a site always lies inside the cell that owns it |
| refused where | water, cliffs, and any village | a village is the design's warm-light social hub; a hostile in the market square spends that for nothing |

Measured over the $441$ cells within $\pm 640$ units of the origin on seed
$1234$: $278$ placed, a surviving density of $0.630$.

Nothing is drawn off a stream. `enemy_in_cell` is a pure function of the cell and
the seed, so the same cell gives the same enemy whichever process asks, in
whatever order, however many times -- which is the whole of why walking away and
coming back is honest (§3).

## 2. Level rises with distance from spawn

An enemy's level is `ItemFrontier.level_at(distance)` and nothing this layer
invented: section 5's gradient, read from the file that owns it. Its six ability
scores come out of `SpawnRoll`, whose bands are lifted by the same gradient at a
slower rate, and its gear is forged by `ItemFrontier` at that level.

The table below is not a formula printed back at you: every row was **stood up**
through the call the running world stands an enemy up with, and the level is read
off the character sheet that came back.

    ./run_headless.sh --ticks 0 --enemies

| ring | distance | level | enemies placed |
| ---: | --- | ---: | ---: |
| 0 | $0-64$ | 1 | 1 |
| 1 | $64-128$ | 2 | 6 |
| 2 | $128-192$ | 3 | 10 |
| 3 | $192-256$ | 4 | 15 |
| 4 | $256-320$ | 5 | 17 |
| 5 | $320-384$ | 6 | 23 |
| 6 | $384-448$ | 7 | 25 |
| 7 | $448-512$ | 8 | 27 |
| 8 | $512-576$ | 9 | 40 |
| 9 | $576-640$ | 10 | 36 |
| 10 | $640-704$ | 11 | 37 |

The count rises with the ring because a ring further out is a larger annulus, not
because anything is denser there: the density is one per cell everywhere.

## 3. Walking away and coming back

`sim/enemy_streamer.gd` keeps the enemies near the people in the world standing in
it, on the same near/far rule the ground, the islands, the villages and the
dressing are streamed by.

An enemy that is dropped is **forgotten, not stored**. Coming back re-derives it
from the field, so what you find is the enemy the seed always said was there --
same role, same level, same rolled scores, same gear, standing at the same spot.
The suite checks exactly that: it reads a standing enemy's name, role, level,
position and whole inventory fingerprint, walks the view $5657$ units away, checks
the enemy is out of the scene, walks back, and compares all six again.

Two things about a cell are remembered, and both are things that happened rather
than rolls:

* a cell that has been spawned is held until its **site** is out of the keep
  radius of everybody, so an enemy that wandered off and was dropped is not stood
  up again at its site on the next tick -- that would be a teleport, not a world;
* **the dead stay dead**: a cell whose enemy fell is never spawned again.

## 4. How many, and what they cost

At most **nine**, and the number is enforced rather than hoped for.

The natural bound is nine: a site always lies inside its own cell, so any site
within the spawn radius of somebody belongs to a cell whose nearest point is
within it, and with a spawn radius ($48$) smaller than one cell ($64$) that is the
observer's own cell and its eight neighbours. That bounds what can be *spawned*.
It does not by itself bound what can be *standing*, because an enemy that follows
you stays inside the keep radius while new cells come into range ahead of you --
so the count is also capped outright at nine.

The cost, measured headless by stepping the same world twice, once with the layer
and once with it switched off:

    ./tools/measure_enemies.sh --ticks 300 --seeds "1234 7 11 42"

| seed | with (µs/tick) | without (µs/tick) | the layer (µs/tick) | most standing | mean standing |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1234 | 127489 | 102015 | 25474 | 2 | 1.34 |
| 7 | 63041 | 51008 | 12032 | 2 | 1.21 |
| 11 | 71599 | 55972 | 15628 | 2 | 1.31 |
| 42 | 75217 | 59910 | 15307 | 3 | 1.11 |

So the layer costs $12$–$25$ ms a tick on this machine while one or two enemies
are standing, against a world step of $51$–$102$ ms without it. The difference is
not only the streaming: it includes stepping the characters the layer stood up
and playing the fights they start, which is most of it. The absolute numbers are
a sandboxed VM's and are worth nothing on their own; the ratio is the reading.

The mean standing count is far below the cap because the cap is a ceiling, not a
target: nine cells near you, most of which either hold nobody or hold somebody
you have already walked past.

## 5. An enemy is not a special kind of thing

`sim/enemy_mind.gd` is a decision function and nothing else. It is built by
`DecisionSource.scripted` like the ordinary cast's wander rule, it has the
signature every decision function in the project has --

    func(scene: ActionScene, actor: Combatant) -> Action

-- and everything it returns is one of `Action`'s own constructors, handed to
`ActionEngine.resolve` by whatever is driving. There is no enemy type, no enemy
list, and no branch anywhere else in the simulation that asks whether a character
is one. The suite drives an enemy through `DecisionSource.drive` -- the same call
that drives a member of the ordinary cast -- and gets back the same two fields.

The rule, in five lines:

1. **on a board** -- swing at the nearest character of another band;
2. **within $18$ units** -- attack them, which in real time is what *starts* the
   fight;
3. **within $21$** -- watch them: a two-tick `wait`, taken again and again;
4. **within $40$** -- walk to $20$ units of them;
5. **nobody in sight** -- wander, on the ordinary cast's own rule.

The bands sit where they do for one reason. A walk is a twenty-tick commitment
and section 2.2's control loop is biased towards continuing one, so a hunter
still walking when its mark came into range would keep walking until the two of
them were close enough for the engagement rule to start the fight underneath it.
Stopping at $21$ and watching in two-tick beats is what lets the blow be the
opener.

## 6. A fight starts because a character acted

A blow struck when no fight is on now begins one. Section 1's world model is a
real-time overworld where "the instant combat begins the local area snaps to
turn-based on a tactical grid"; this is that instant, and it is an *action*.
`ActionEngine._attack` refuses a blow at somebody further away than
`Encounter.JOIN_RADIUS` -- a fight begun without the person it was begun against
is not a fight -- and otherwise reaches `ActionScene.begin_fight`, the same call
the engagement rule reaches. The blow itself is spent on starting the fight; the
attacker strikes on its own turn, because turn order is the match's and a swing
outside it would be a swing outside the turn economy.

From `./run_headless.sh --seed 42 --ticks 40`, at tick $17$:

```
t= 17  Guard(-1,0) finished attack(target=2 item=rare staff) -> attack ok fight=begins against=2 anchor=4 joined=2
t= 17  Nettle interrupted (combat began), abandoned go_to(target=(-21.834, 14.196)) 16/20t
t= 17  Nettle began attack(target=4 item=legendary flail), 6 ticks
  t= 17  snap-in around #4 at (-26.032, 3.831, 22.427) radius=24.0 span=30.0 storey=0 joined=2
```

The tick, who attacked whom, and what the engine answered are all on the first
line. Nothing declared the fight: `Guard(-1,0)` is an enemy the field placed in
cell $(-1, 0)$, stood up by the streamer, decided for by its own rule.

The older way in is untouched: two commanders of different bands who drift within
`ActionScene.ENGAGE_RADIUS` of each other still meet, because two people walking
into one another is a meeting and the world is entitled to say so. Both paths go
through one call.

Its turns in that fight are played by the battle AI in the running game --
`CombatPolicy` closes, faces and sends minions inside `SimWorld.step`, and the
blow it chose lands on its own turn through the one damage seam. No runner is
involved: the suite reads it off a world it only stepped.

## 7. What had to change outside the enemy layer, and why

Making enemies real broke three things that had never been exercised, and each
fix is a rule that was already written down being made true.

**A forged weapon had no attacks.** `Weapon.around` said so in as many words: an
item taken up bare "has a budget and nothing to spend it swinging", because the
forge and the weapon catalogue had never met. An enemy that cannot swing is not
an enemy, so the meeting exists now: `Item.shape` records the word the forge drew
(`blade`, `spear`, `bow`, ...) beside the tag it already recorded for what the
thing looks like, and `Weapon.for_item` holds an item as that shape. What it
swings is the pattern the shape has; every number is still the item's own budget,
gated by the wielder's ability score.

**A commander that could not reach stood still for the whole fight.**
`CombatPolicy` measured how near it was getting in Chebyshev distance -- king
steps -- and stopped as soon as it was adjacent. Both halves were wrong for half
the board: a commander only moves like a king once armour has granted it a
diagonal (§3.4), and no single cardinal step reduces a king distance to somebody
standing diagonally away; and being adjacent is not the same as being able to
strike, since a spear reaches one cell in front of it and no diagonal. On three
seeds in ten the ordinary world's first fight ran to the round limit with neither
commander ever swinging. The chooser now reads how near it is as a pair -- king
steps, then city blocks -- and stops when it can actually strike from where it
stands rather than when it is merely next to somebody. On the ten seeds measured,
every fight is now decided.

**The world stopped when the character the camera was on was killed.** The view
is a view *on a character*, and a character can now lose. It moves to the
lowest-id living commander instead, which is a member of the cast for as long as
one is left; nobody followed stays nobody followed, so `place_observer` still
means what it meant.

Two smaller ones. The ordinary cast is now armed -- forged gear at its own level,
put on by `Inventory.dress`, the one call that dresses anybody stood up out of a
roll -- and a member of it caught in a fight strikes back rather than choosing a
walk the board refuses. And the headless run now prints what the fights in the
world wrote down, at the tick they happened on, which is why the trace above has
snap-in lines in it at all.

## 8. Determinism, and the fingerprint

Two processes running `./run_headless.sh --ticks 100` print identical bytes; a
different seed prints different bytes. The seed-$1234$ world fingerprint moved:

    5014980a58150055  ->  32656f55cc5eeb1c

Four things moved it, all of them things that are now true of the world:

* the roster is four rather than three, because the enemy layer stands one up
  near the origin on this seed, and the roster is folded into the world digest;
* the cast carries and wears forged gear;
* the fight that follows moves everybody's positions and hit points;
* the closing rule moves pieces to different cells.

Nothing about the terrain, the water, the islands, the villages or the scatter
moved: the ground under seed $1234$ is the ground it always was.

## 9. What is not claimed

* **Fights are not always started by a blow.** Somebody who walks head-on into an
  enemy over a whole approach still meets it, and the engagement rule says so.
  Across ten seeds, roughly half of first fights open with a blow and half with a
  meeting.
* **The board AI is still the dullest possible chooser.** It is four greedy steps
  in a fixed order and it is not the minion AI of section 3.9. In particular it
  reasons in `owner_id`, which makes every commander everyone else's enemy, while
  the minds reason in bands -- so in a fight with three commanders of two bands, a
  commander can close on a band-mate and stand there. That is a real stall and it
  is left for the board-AI work rather than patched here.
* **An enemy has no persona.** `SpawnRoll` rolls the sheet and stops, which is the
  first half of section 8's sentence; the second half -- a language model writing
  the person who explains the rolls -- is not written yet. Until it is, an enemy's
  name is a designation: its role and the cell it came out of, `Guard(-1,0)`.
