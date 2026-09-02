extends RefCounted
## The one place a number is taken off a player-facing unit, and the rules that
## decide how big it is.
##
## Section 3.7 splits combat into two layers that scale independently. This file
## is the whole of the numeric one. The tactical one -- a minion taking another
## minion -- is not here at all, and that absence is the point: it is a binary
## capture that reads neither a level nor a hit point, so there is nothing for it
## to compute and no arithmetic it could share with this.
##
## ## The seam
##
## `resolve()` is the single named resolution point every player-facing pairing
## goes through. Nothing else in the project subtracts a defence from a power,
## which is why the roll-and-armour model section 13 left open could be settled
## here as an edit to one function.
##
## ## What was settled, and against what
##
## The design offered three: **(a)** a D&D to-hit roll against an armour class,
## **(b)** armour as damage reduction with attacks always landing, **(c)** both.
## What is implemented is **(b), with the die on how hard a blow lands rather
## than on whether it lands** -- armour reduces, every attack connects, and one
## more multiplier says how well it connected.
##
## The reason is a number, not a preference. A to-hit roll makes a planned
## sequence of $n$ blows succeed with probability $(1-p)^n$ for a single-blow
## miss chance $p$, so a deliberately planned *two*-move combination fails more
## often than it succeeds as soon as $p > 1 - 1/\sqrt{2} \approx 0.293$ -- which is
## inside the ordinary D&D range, and is exactly the stop condition this task was
## given. A die on the magnitude has no such cliff: the blow always lands, so a
## plan can only be off by how much, never by whether. `reports/dice.md` measures
## both.
##
## Section 4 is the other half of the reason, and it is why this could not be
## decided before the items phase. The ability-score gate already makes a
## too-powerful item under-perform for an under-qualified user, continuously:
## $v_{\text{eff}} = \lfloor v \cdot \min(A,L)/L \rfloor$. "A high-INT staff rarely
## succeeds for a low-INT user" is therefore already implemented, as a smaller
## number rather than as a miss chance. Option (a) would charge for it twice.
##
## ## The arithmetic
##
##     blow  = floor(power * multiplier / 100)
##     dealt = max(MINIMUM, round(blow * swing / 100) - defence)
##
## The multiplier is applied to the attack, not to the result, so terrain and
## facing make a blow *land harder* rather than make armour *work less*. It is
## carried in hundredths so that the whole layer is integer arithmetic: a half
## again is 150, doubled is 200, and a backstab from high ground is 300, which
## is one multiplication rather than two floating-point products whose order
## would matter.
##
## The `swing` is the die, in the same hundredths, and it is applied to the blow
## the board already decided rather than folded in beside the multiplier. That is
## two steps rather than one on purpose, and the second rounds to nearest rather
## than down. Folding it in and flooring once was tried, and measurably shaved
## about **0.45 points off every landed blow** -- the die would have been a quiet
## nerf on every attack in the game rather than a die. Rounding the second step
## to nearest makes the mean land on the deterministic number exactly, for every
## power, multiplier and defence in `reports/dice.md`'s table: ratio 1.0000, not
## 0.98.
##
## Switching the die off is passing `STEADY`, at which the second step is
## `round(blow * 100 / 100) = blow` and the whole thing collapses, digit for
## digit, to the function the combat phase shipped -- which is what every exact
## number in `reports/combat.md` still is, and what the suite still asserts.
##
## `MINIMUM` is why no configuration of levels makes a commander unkillable.
## Armour here is damage reduction, and reduction that could reach zero would
## mean a level gap past which an attack does literally nothing -- at which point
## the binary capture layer and the numeric layer would stop coexisting, which
## is the condition this task was told to stop and report on rather than patch.
## One point of damage is the floor that keeps every fight finite; the level gap
## then decides whether finite means four turns or ninety, and
## reports/combat.md tabulates both ends of that.
class_name Damage

## The smallest a landed blow can be. See the note above: this is what makes the
## two layers able to coexist rather than a softener bolted on afterwards.
const MINIMUM := 1

## No modifier: a hundred hundredths.
const NONE := 100

## Attacking from ground higher than the target's, by more than HIGH_GROUND_RISE
## world units. Half again.
const HIGH_GROUND := 150

## Attacking a target from its side. Half again.
const FLANK := 150

## Attacking a target from behind. Doubled.
const BACK := 200

## How much higher the attacker's cell must be for high ground, in world units.
## A third of a cell: enough that a facet of sloped ground is not high ground,
## small enough that one storey of anything is.
const HIGH_GROUND_RISE := 1.0

## Where an attacker stands relative to the way its target is looking.
const FRONT := 0
const FLANKING := 1
const BEHIND := 2

# --- The die --------------------------------------------------------------
#
# Section 13's first open decision, settled: see the note at the top of the file
# for which of the three options this is and why. What follows is the die's size
# and its shape, and neither is a matter of taste.

## A swing of exactly `NONE`: the die switched off.
##
## Passing this to `resolve()` gives back, to the digit, the number the
## deterministic combat phase gave -- so the two models are the same code with
## and without one argument, and every table in `reports/combat.md` is still the
## arithmetic this layer runs.
const STEADY := NONE

## The fight seed that means "no die at all": a fight played `STEADY`.
##
## A fight is given a real seed by whoever begins it. Zero is reserved for the
## exact-number checks and for a report that quotes a blow rather than a
## distribution, and `describe_strike()` writes the swing out either way so a
## transcript never hides which it was.
const NO_DIE := 0

## How far one of the two dice reaches, in hundredths.
##
## **Four, and it is derived rather than chosen.** The positional ladder this
## layer already had is $100 < 150 < 200 < 300$ -- front, flank or high ground,
## backstab, backstab from high ground. The die must not invert it: the worst
## roll of the better position has to beat the best roll of the worse one, or a
## player who *did* manoeuvre round the back would sometimes be punished for it
## and section 3.1's "out-position them" would stop being the reliable path.
##
## For two rungs $m_1 < m_2$ that is
##
##     m_2 (NONE - 2 SWING) > m_1 (NONE + 2 SWING)
##
## which says the die's spread must be narrower than the narrowest rung. The
## narrowest rung is $200/150$, so
##
##     4/3 (100 - 2S) > 100 + 2S   <=>   100 > 14 S   <=>   S < 7.14
##
## Seven is therefore the largest die that never inverts the ladder, and eight
## does invert it. Four is what is used, because "never inverts" is weaker than
## it sounds once the arithmetic is integers: at seven the inequality holds by
## six parts in a thousand, which rounding eats, so the ordering survives only as
## "never worse" and ties become the common case. Four is the largest die under
## which a better position is *strictly* better at every blow of two points or
## more -- one-point blows being the one case where no die of any width has room
## to say anything. Both bounds are swept, width by width and power by power, in
## `reports/dice.md`, and both are asserted in the suite.
const SWING := 4

## The two ends of the swing, for a report line and a bounds check.
const SWING_LOW := NONE - 2 * SWING
const SWING_HIGH := NONE + 2 * SWING

## How many faces one of the two dice has.
const SWING_FACES := 2 * SWING + 1


## The swing for one blow: the die, rolled.
##
## **Two dice and not one**, summed, so the distribution is triangular rather
## than flat: a blow lands near its plain number far more often than at either
## extreme, and a plan built on the plain number is wrong by a little far more
## often than by a lot. One die of the same width would make every outcome in
## the band equally likely, which is the same spread spent much worse.
##
## **Hashed from the blow, not drawn from a stream.** This is the discipline
## `sim/item_drop.gd` already follows and for the same reason: a stream's numbers
## depend on how many were drawn before them, so a blow's roll would depend on
## how many other blows had been struck first, and resolving the same blow in a
## different order would give a different answer. Here the roll is a function of
## the fight's seed and of the blow itself -- who threw it, at whom, from where,
## against how much health, with how much power -- and of nothing else. Two
## processes therefore agree without having to have executed the same history.
##
## `fight_seed` of `NO_DIE` returns `STEADY`: no die, and the deterministic
## arithmetic.
static func swing_for(
	fight_seed: int, attacker: Piece, target: Piece, power: int
) -> int:
	if fight_seed == NO_DIE:
		return STEADY
	var who := SimRng.hash_ints(fight_seed, attacker.id, target.id)
	var where := SimRng.hash_ints(
		attacker.cell.x, attacker.cell.y, target.cell.x
	)
	var what := SimRng.hash_ints(target.cell.y, target.health, power)
	var first := _die(SimRng.hash_ints(who, where, what))
	var second := _die(SimRng.hash_ints(what, who, where))
	return NONE - 2 * SWING + first + second


## A fight's own seed, from the world's and from where on the map it happens.
##
## Two fights in one world roll differently because they stand in different
## places, and the same fight in the same world rolls the same however many times
## it is replayed -- which is the whole of what "deterministic per seed" has meant
## everywhere else in this project. Never `NO_DIE`, because a real fight is never
## the one that has no die.
static func fight_seed_for(world_seed: int, at_x: float, at_z: float) -> int:
	var folded := SimRng.hash_ints(world_seed, int(floor(at_x)), int(floor(at_z)))
	return folded if folded != NO_DIE else 1


## One die: a well-mixed word folded onto `SWING_FACES` faces by multiplying
## rather than by taking a remainder, so no face is favoured by however the
## number of faces happens to divide $2^{32}$.
static func _die(word: int) -> int:
	return ((word & SimRng.MASK) * SWING_FACES) >> 32

# --- Level scaling --------------------------------------------------------
#
# Section 5: raw numbers are the infinite axis. Only the minion tier scales with
# level here, because that is what the design's damage matrix asks for -- a
# player's damage comes off a weapon and a player's defence off armour, and both
# of those become level-scaled in the items phase through the power budget
# rather than here.

## A minion's hit points at a level.
const MINION_HEALTH_BASE := 6
const MINION_HEALTH_PER_LEVEL := 4

## A minion's defence at a level.
const MINION_DEFENCE_BASE := 1
const MINION_DEFENCE_PER_LEVEL := 1

## What a minion's blow is worth against a player, at a level. Section 3.7's
## unbounded scaling axis, and the only pairing whose power is a function of a
## level rather than of an item.
const MINION_POWER_BASE := 2
const MINION_POWER_PER_LEVEL := 2

## A commander's hit points at a level. Its defence is not here: that is the sum
## of what it is wearing.
const COMMANDER_HEALTH_BASE := 20
const COMMANDER_HEALTH_PER_LEVEL := 6


static func minion_health(level: int) -> int:
	return MINION_HEALTH_BASE + MINION_HEALTH_PER_LEVEL * maxi(0, level)


static func minion_defence(level: int) -> int:
	return MINION_DEFENCE_BASE + MINION_DEFENCE_PER_LEVEL * maxi(0, level)


static func minion_power(level: int) -> int:
	return MINION_POWER_BASE + MINION_POWER_PER_LEVEL * maxi(0, level)


static func commander_health(level: int) -> int:
	return COMMANDER_HEALTH_BASE + COMMANDER_HEALTH_PER_LEVEL * maxi(0, level)


# --- The seam -------------------------------------------------------------


## The one resolution point. Every point of damage in the game is returned from
## here, and no other function subtracts a defence from a power.
##
## The blow always lands: there is no branch here that returns nothing, which is
## option (b) in one sentence and is what keeps a two-move combination a question
## of how much rather than of whether. `swing` is the die, already rolled by
## `swing_for()`; passing `STEADY` is the deterministic model, digit for digit.
##
## Two steps, because they are two different things. `blow` is what the board
## decided: the attack's power, made harder by terrain and facing, floored the
## way every other number in this layer is. `landed` is what the die then made of
## it, rounded to *nearest* so that the die is worth nothing on average rather
## than half a point against the attacker -- see the note at the top of the file
## for the measurement that forced this.
@warning_ignore("integer_division")
static func resolve(
	power: int, multiplier: int, defence: int, swing: int = STEADY
) -> int:
	var blow := (maxi(0, power) * multiplier) / NONE
	var landed := (blow * maxi(0, swing) + NONE / 2) / NONE
	return maxi(MINIMUM, landed - maxi(0, defence))


# --- The modifiers --------------------------------------------------------


## Where an attacker stands relative to the way its target is looking.
##
## The vector from the target to the attacker is rotated into the target's own
## frame, and then read off in one comparison: mostly ahead is the front, mostly
## behind is the back, and anything shallower than the diagonal is a flank. A
## target with no facing -- every minion -- has no back to stab, so it is always
## a front.
static func relation(target: Piece, attacker_cell: Vector2i) -> int:
	if not target.has_facing():
		return FRONT
	var facing := PieceGeometry.NORTH
	if target is Commander:
		facing = (target as Commander).facing
	# Rotating by -facing puts the attacker where it would stand if the target
	# were looking north, which is the frame every pattern in the layer is
	# written in.
	var local := PieceGeometry.rotate(attacker_cell - target.cell, -facing)
	if absi(local.x) > absi(local.y):
		return FLANKING
	return FRONT if local.y < 0 else BEHIND


## What the facing relation is worth.
static func facing_multiplier(of_relation: int) -> int:
	match of_relation:
		FLANKING:
			return FLANK
		BEHIND:
			return BACK
	return NONE


## Whether the attacker's cell stands high enough over the target's to count.
static func is_high_ground(board: CombatBoard, from: Vector2i, onto: Vector2i) -> bool:
	var rise := board.height_at(from) - board.height_at(onto)
	if not is_finite(rise):
		return false
	return rise >= HIGH_GROUND_RISE


## The whole multiplier for one blow: the terrain's and the facing's, multiplied
## rather than added, so a backstab from high ground is 300 and not 250.
@warning_ignore("integer_division")
static func multiplier_for(board: CombatBoard, attacker: Piece, target: Piece) -> int:
	var ground := HIGH_GROUND if is_high_ground(board, attacker.cell, target.cell) else NONE
	return ground * facing_multiplier(relation(target, attacker.cell)) / NONE


## The relation in one word, for a transcript line and a failure message.
static func relation_name(of_relation: int) -> String:
	match of_relation:
		FLANKING:
			return "flank"
		BEHIND:
			return "back"
	return "front"
