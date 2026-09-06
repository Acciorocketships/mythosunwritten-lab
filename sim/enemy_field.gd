extends RefCounted
## Where the enemies of the world are, as a function of the ground and the seed.
##
## Everything else in the generation stack answers "what is at this position" --
## how high it is, which biome it belongs to, whether a village stands there.
## This answers the same shape of question about the one thing that had no answer
## yet: **who is standing out there waiting for you.** It is a sparse field on a
## lattice of cells, each holding at most one enemy, decided by a hash of the
## cell and the world seed -- the same rule `SettlementField` places villages by,
## for the same reason. Nothing is drawn off a stream and nothing depends on what
## has been asked before, so an enemy is the same enemy whichever process asks,
## in whatever order, however many times.
##
## That is the whole of what makes walking away and coming back honest. There is
## no roll to repeat and no state to lose: `enemy_in_cell` is a pure function, so
## the world you come back to is the world the seed always said was there.
##
## ## The placement rule
##
##   * **Density.** One candidate per `CELL` square, and `CHANCE` of those cells
##     want an enemy at all before the ground has its say. So the most a stretch
##     of world can hold is one per cell, which is what makes the count near a
##     player boundable (see `sim/enemy_streamer.gd`, which states the bound).
##   * **The cell is a ring wide.** `CELL` is `ItemFrontier.RING_SPAN`, the width
##     of one band of section 5's difficulty gradient, so an enemy's level is
##     near enough constant across the cell it was placed in and a ring of the
##     gradient is a ring of enemies rather than a smear.
##   * **The ground has to take it.** A site is refused unless it can be stood on
##     -- not water, not a cliff -- and unless it is out of every village. A
##     village is the design's warm-light social hub; putting a hostile in the
##     market square would spend that for nothing. A handful of spots inside the
##     cell are tried before the cell is given up on, exactly as a settlement's
##     are.
##
## ## What an enemy is before anybody has decided who it is
##
## A row out of this field is a *placement*: a cell, a spot, a role and a level.
## The sheet behind it is `SpawnRoll`'s, which is section 8's first half -- roll
## the scores from the role's bands lifted by the local region difficulty, then
## let a language model write the person who explains them. The second half has
## not been written yet, so the name this file gives is a designation and not a
## persona: the role and the cell it came out of, which is a fact rather than a
## story and is what a trace needs in order to say who attacked whom.
class_name EnemyField

## How wide one cell of the enemy lattice is, in world units. One ring of section
## 5's gradient, read from the file that owns the gradient rather than typed
## again.
const CELL := ItemFrontier.RING_SPAN

## How many cells want an enemy, before the ground has its say. Some are then
## refused, so the density that survives is lower; `Simulation.enemy_report()`
## measures what survives on the shipped seed.
const CHANCE := 0.62

## How far into its cell a candidate may be jittered, as a share of the cell.
## Kept off the cell edges, so a site always lies inside the cell that owns it --
## which is what lets `EnemyStreamer` bound how many cells can have a site near
## you, and through that how many enemies can exist near you at once.
const JITTER_LOW := 0.25
const JITTER_HIGH := 0.75

## How many spots inside a cell are tried before the cell is given up on.
const ATTEMPTS := 4

## What the placement rolls are hashed against, so that adding a consumer of this
## field cannot shift what any other field decides.
const FIELD_SEED := 0x454e4d59

## The four unit roles, read off `SpawnRoll` rather than listed again: which
## roles exist is that file's, and a second list here would be a second answer.
const ROLES := SpawnRoll.ROLES

## The ground and the villages, both through the one query.
var terrain: TerrainQuery = null

## The seed every placement descends from.
var world_seed: int = 0

# Vector2i cell -> the row that cell answers with, once it has been worked out.
#
# A memo and not state: `enemy_in_cell` is a pure function of the cell and the
# seed, so what is remembered here is only what would be computed again. It is
# worth remembering because working it out asks the ground and the settlement
# layer about up to `ATTEMPTS` positions, and the streamer asks about the same
# nine cells on every tick of a walk.
var _known := {}


func _init(query: TerrainQuery = null) -> void:
	terrain = query
	world_seed = 0 if query == null else query.world_seed


## Which cell of the enemy lattice a world position falls in.
##
## A cornered lattice: cell `(0, 0)` spans `[0, CELL)` on both axes. Cornered
## rather than centred because nothing here is placed relative to the world
## origin -- unlike the starting village, which is, and whose lattice is centred
## for exactly that reason.
static func cell_at(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / CELL)), int(floor(z / CELL)))


## The world-space corner a cell starts at.
static func cell_corner(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * CELL, float(cell.y) * CELL)


## The enemy in a cell, or an empty dictionary when that cell holds none.
##
## The row is everything about the enemy that is a fact about the *place*: which
## cell it came out of, where in it the enemy stands, which role it was rolled
## as, and what the section 5 gradient makes of the distance. Nothing about what
## has happened to it is in here, because nothing that has happened to it is a
## property of the cell.
func enemy_in_cell(cell: Vector2i) -> Dictionary:
	if terrain == null:
		return {}
	if not _known.has(cell):
		_known[cell] = _work_out(cell)
	# A copy, for the reason chunk geometry and the water sheet are handed over
	# as copies: what the caller gets is theirs, and writing into it cannot make
	# the field disagree with itself later.
	return (_known[cell] as Dictionary).duplicate()


func _work_out(cell: Vector2i) -> Dictionary:
	if _roll(cell, 0) >= CHANCE:
		return {}
	for attempt in ATTEMPTS:
		var at := _candidate_at(cell, attempt)
		if not _ground_takes_it(at):
			continue
		var role := _role_of(cell)
		return {
			"cell": cell,
			"x": at.x,
			"z": at.y,
			"role": role,
			"level": SpawnRoll.difficulty_at(at.x, at.y),
			"ring": SpawnRoll.ring_at(at.x, at.y),
			# What the roll is addressed by, in place of "which spawn of this run
			# is this". A spawn count would make an enemy depend on how many were
			# stood up before it; the cell does not depend on anything.
			"key": key_of(cell),
			"name": name_for(role, cell),
		}
	return {}


## Every enemy the field places within a distance of a position, in cell order so
## that two processes read them in the same order.
##
## Only the cells whose *nearest point* is within the distance are looked at,
## which is every cell that could hold a site within it, because a site always
## lies inside its own cell.
func enemies_near(x: float, z: float, within: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var here := cell_at(x, z)
	var reach := int(ceil(maxf(0.0, within) / CELL))
	for offset_x in range(-reach, reach + 1):
		for offset_z in range(-reach, reach + 1):
			var row := enemy_in_cell(Vector2i(here.x + offset_x, here.y + offset_z))
			if row.is_empty():
				continue
			if Vector2(float(row["x"]) - x, float(row["z"]) - z).length() > within:
				continue
			found.append(row)
	return found


## Every enemy the field places inside a square of world, in cell order. What the
## report walks, so that a table of distance against level answers for the field
## rather than for whatever a particular walk happened to meet.
func enemies_in_square(span: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var reach := int(ceil(maxf(0.0, span) / CELL))
	for cell_x in range(-reach, reach + 1):
		for cell_z in range(-reach, reach + 1):
			var row := enemy_in_cell(Vector2i(cell_x, cell_z))
			if not row.is_empty():
				found.append(row)
	return found


## What a placement is addressed by: one whole number per cell, folded so that
## neighbouring cells do not roll neighbouring sheets.
static func key_of(cell: Vector2i) -> int:
	return SimRng.hash_ints(FIELD_SEED, cell.x, cell.y)


## What an enemy is called.
##
## A designation, not a persona. Section 8 has a language model write the person
## who explains a rolled sheet, and that call is not written yet; until it is,
## the honest name is the two facts the world actually knows -- what it is and
## where it came from. `ActionScene.name_of` prints this in every trace, which is
## how a fight line can say who attacked whom.
static func name_for(role: String, cell: Vector2i) -> String:
	return "%s(%d,%d)" % [role.capitalize(), cell.x, cell.y]


## The character sheet behind a placement: `SpawnRoll`'s, addressed by the cell.
##
## Section 8's order is kept exactly -- the scores come out of the role's bands
## lifted by the local region difficulty, and nothing here has seen a persona,
## because none has been written. The name is put on afterwards for the same
## reason a designation is not a story.
func sheet_for(row: Dictionary) -> Character:
	if row.is_empty():
		return null
	var sheet := SpawnRoll.sheet_at(
		world_seed, int(row["key"]), String(row["role"]),
		float(row["x"]), float(row["z"]))
	sheet.character_name = String(row["name"])
	return sheet


# --- The rule ------------------------------------------------------------


## Which role a cell's enemy is, drawn evenly from the four.
func _role_of(cell: Vector2i) -> String:
	var drawn := _roll(cell, 1)
	var at := clampi(int(drawn * float(ROLES.size())), 0, ROLES.size() - 1)
	return String(ROLES[at]["role"])


## One spot inside a cell, kept off the cell's edges.
func _candidate_at(cell: Vector2i, attempt: int) -> Vector2:
	var corner := cell_corner(cell)
	var across := _roll_range(cell, 2 + attempt * 2, JITTER_LOW, JITTER_HIGH)
	var along := _roll_range(cell, 3 + attempt * 2, JITTER_LOW, JITTER_HIGH)
	return corner + Vector2(across, along) * CELL


## Whether the ground at a spot will take an enemy: somewhere it can be stood on,
## and out of every village.
func _ground_takes_it(at: Vector2) -> bool:
	if not terrain.is_passable_at(at.x, at.y):
		return false
	return terrain.settlement_at(at.x, at.y) == null


func _roll(cell: Vector2i, salt: int) -> float:
	return SimRng.hash_unit(
		world_seed ^ FIELD_SEED, cell.x * 73856093 ^ cell.y * 19349663, salt)


func _roll_range(cell: Vector2i, salt: int, low: float, high: float) -> float:
	return low + (high - low) * _roll(cell, salt)
