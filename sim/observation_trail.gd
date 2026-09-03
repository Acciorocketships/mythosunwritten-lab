extends RefCounted
## The last few things that changed about a character, in words it could say
## about itself.
##
## Section 10 puts "last N actions and state transitions, converted to readable
## deltas" in the observation, and gives two examples of the form: "moved 1m
## north", "picked up Iron Spear". This is where those sentences come from.
##
## ## It reads the world; it does not ask the world to tell it anything
##
## Nothing under `sim/` was changed to make this possible and nothing reports to
## it. It keeps a snapshot of each character -- where it stood, how hurt it was,
## what it carried, what it had on, what money it had, whether it was on a board
## -- and every time it is shown the scene again it *diffs* the two and writes
## the difference in words. So "picked up a lantern" is not an action anybody
## recorded; it is the plain fact that a lantern is in the pack now and was not
## before. A delta is a state transition, which is what section 10 asked for.
##
## That also means the wording never claims to know *how* something changed. An
## item that arrives says "gained"; it does not say "picked up", because a trade,
## a gift and a pick-up all look the same from outside and only one of them would
## have been true.
##
## ## It is first-person, and that is what keeps it local
##
## A character's trail holds only what changed about *that character*. An
## observation reports its own trail and nobody else's, so nothing in the recent
## changes is knowledge of somewhere the character has not been. What other
## people are doing is the observation's entity list, gated by line of sight,
## and it is a separate question with a separate answer.
##
## ## No clock
##
## A delta says what changed, never when. There is no tick in here, no timestamp
## and no duration -- section 10's examples have none either -- so the trail can
## be read by a character that cannot see a clock, which is every character.
class_name ObservationTrail

## How many changes are kept per character. Section 10's "last N", as one number.
## Six is a few: enough that a walk, a pick-up and a trade are all still in view,
## short enough that the packet does not turn into a diary.
const KEEP := 6

## How far a character has to have moved for the trail to call it moving, in
## world units. Below this it is the same place: a walk of a hundredth of a unit
## is arithmetic, not news.
const MOVED_AT_LEAST := 0.05

## The eight directions a move is reported in. North is -z and east is +x, the
## convention the whole project reads its top-down world by.
const COMPASS := [
	"north", "north-east", "east", "south-east",
	"south", "south-west", "west", "north-west",
]

# What each character looked like when it was last seen, and what has changed
# about it since, newest last. Both keyed by the scene's own id.
var _seen: Dictionary = {}
var _changes: Dictionary = {}


## Look at the world and write down what has changed since the last look.
##
## Called once per tick by whatever is stepping the scene. The first look at a
## character records it and writes nothing, because there is nothing yet to
## compare it against.
func note(scene: ActionScene) -> void:
	var present := {}
	for one in scene.actors:
		present[one.id] = true
		_note_one(one)
	# Anybody who has left the world is forgotten. Ids are never reused, so
	# nothing can come back wearing somebody else's history.
	for id in _seen.keys():
		if not present.has(id):
			_seen.erase(id)
			_changes.erase(id)


## Whether this trail has ever looked at a character. An observation of one it
## has not says so rather than reporting no changes, because the two are
## different facts.
func watches(id: int) -> bool:
	return _seen.has(id)


## The last few changes to a character, newest last.
##
## A copy, and that is not defensive tidiness -- it is what makes an observation
## a reading taken at a moment. The trail goes on growing after one is assembled,
## and this engine's packed arrays share their storage when they are handed out
## of a dictionary, so without the copy an observation taken on one tick would
## quietly fill in with everything that happened after it.
func recent_of(id: int) -> PackedStringArray:
	var kept: PackedStringArray = _changes.get(id, PackedStringArray())
	return kept.duplicate()


## How many characters this trail is watching.
func size() -> int:
	return _seen.size()


## What an entry of an inventory is called: the item's own name, which is also
## the name every action that reaches an item names it by, so what the trail says
## a character gained is exactly what that character can then name in a `pick_up`
## or an `attack`.
static func name_of_entry(entry: Variant) -> String:
	var carried := Inventory.item_of(entry)
	if carried != null:
		return carried.item_name
	return Inventory.entry_line(entry)


## Which of the eight directions an offset points in. North is -z.
static func compass_of(dx: float, dz: float) -> String:
	var turn := atan2(dx, -dz)
	if turn < 0.0:
		turn += TAU
	return COMPASS[int(roundf(turn / (TAU / 8.0))) % 8]


# --- Looking at one character ---------------------------------------------


func _note_one(one: Combatant) -> void:
	var now := _snapshot(one)
	if not _seen.has(one.id):
		_seen[one.id] = now
		_changes[one.id] = PackedStringArray()
		return
	var written := _deltas(_seen[one.id], now)
	_seen[one.id] = now
	if written.is_empty():
		return
	var kept: PackedStringArray = _changes[one.id]
	kept.append_array(written)
	while kept.size() > KEEP:
		kept.remove_at(0)
	_changes[one.id] = kept


# Everything about a character that a change to it would be worth a sentence.
static func _snapshot(one: Combatant) -> Dictionary:
	var pack := ActionScene.inventory_of(one)
	var kept := {
		"x": one.x, "y": one.y, "z": one.z,
		"health": one.piece.health,
		"fighting": one.fighting,
		"money": 0,
		"carried": PackedStringArray(),
		"worn": PackedStringArray(),
	}
	if pack == null:
		return kept
	kept["money"] = pack.money
	var carried := PackedStringArray()
	for entry in pack.carried:
		carried.append(name_of_entry(entry))
	kept["carried"] = carried
	var worn := PackedStringArray()
	var equipped := pack.equipment()
	for slot in equipped:
		worn.append("%s=%s" % [slot, name_of_entry(equipped[slot])])
	kept["worn"] = worn
	return kept


# The difference between two snapshots, in words, in a fixed order: where it is,
# how it is, what it has, what it has on, what it is worth, and where it is
# standing. Fixed, because a run must print the same lines in the same order in
# every process.
static func _deltas(before: Dictionary, after: Dictionary) -> PackedStringArray:
	var written := PackedStringArray()

	var dx: float = after["x"] - before["x"]
	var dz: float = after["z"] - before["z"]
	var across := Vector2(dx, dz).length()
	if across >= MOVED_AT_LEAST:
		written.append("moved %.1fm %s" % [across, compass_of(dx, dz)])
	var rise: float = after["y"] - before["y"]
	if absf(rise) >= MOVED_AT_LEAST:
		written.append("%s %.1fm" % ["climbed" if rise > 0.0 else "dropped", absf(rise)])

	var hurt: int = int(before["health"]) - int(after["health"])
	if hurt > 0:
		written.append("lost %d hit points" % hurt)
	elif hurt < 0:
		written.append("recovered %d hit points" % -hurt)

	for gained in _added(before["carried"], after["carried"]):
		written.append("gained %s" % gained)
	for lost in _added(after["carried"], before["carried"]):
		written.append("gave up %s" % lost)

	for put_on in _added(before["worn"], after["worn"]):
		written.append("put on %s" % put_on)
	for taken_off in _added(after["worn"], before["worn"]):
		written.append("took off %s" % taken_off)

	var coins: int = int(after["money"]) - int(before["money"])
	if coins > 0:
		written.append("gained %d coins" % coins)
	elif coins < 0:
		written.append("spent %d coins" % -coins)

	if bool(after["fighting"]) != bool(before["fighting"]):
		written.append("stood onto the tactical board" if after["fighting"]
			else "left the tactical board")
	return written


# What is in the second list and not in the first, counting duplicates, sorted so
# that the order two things arrived in cannot change what is printed.
static func _added(before: PackedStringArray, after: PackedStringArray) -> PackedStringArray:
	var left := {}
	for name_of in before:
		left[name_of] = int(left.get(name_of, 0)) + 1
	var gained := PackedStringArray()
	for name_of in after:
		if int(left.get(name_of, 0)) > 0:
			left[name_of] = int(left[name_of]) - 1
			continue
		gained.append(name_of)
	var sorted := Array(gained)
	sorted.sort()
	return PackedStringArray(sorted)
