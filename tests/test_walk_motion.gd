extends TestSuite
## A walk happens while it happens.
##
## Six claims:
##
##   1. **The walk is spread over its span.** A character under a `go_to` is
##      somewhere new on every tick of the span, one stride of
##      `ActionEngine.STEP` at a time, rather than in one place for the whole
##      span and somewhere else on the last tick.
##   2. **Spreading it moved nobody.** The same walk resolved in one call --
##      the engine reached directly, with no loop and no span -- lands on
##      exactly the same coordinates, having covered exactly the same distance
##      in exactly the same number of strides.
##   3. **The motion reaches the render layer.** `CombatantRoster.snapshot`
##      reports the walker moving on every tick of the span and standing still
##      when it is not walking, and `CharacterView` picks its walk clip from
##      that snapshot and nothing else.
##   4. **An interrupted walk leaves the character where it reached.** The walker
##      spoken to part-way through a walk is exactly as far along as the strides
##      it took, the walk never reaches the engine, and the next walk sets off
##      from there.
##   5. **There is one implementation of walking, and it is found by scanning.**
##      Every `.gd` file in the project is read, and every line that *adds to* a
##      combatant's ground coordinates -- which is what advancing a position is,
##      as against setting them, which is putting somebody down -- is collected.
##      The scan is then run over a line that would break the claim, and must
##      catch it.
##   6. **It is still a function of the seed and the tick.** Two worlds on one
##      seed walk their casts to the same coordinates, tick for tick, and
##      fingerprint the same at every tick.
class_name TestWalkMotion

## How far a stride carries a character with no speed of its own, and what a
## `go_to` costs. Both read off the code so that changing either changes what
## this suite expects rather than breaking it.
const STRIDE := ActionEngine.STEP

## Where the walker starts and how far away it is sent: far enough that the span
## cannot finish the walk, so the span is entirely motion.
const START := Vector2(0.0, 0.0)
const FAR := Vector2(60.0, 0.0)

## A walk that fits comfortably inside one span, for the cases that want the
## whole journey.
const NEAR := Vector2(9.0, 0.0)

## The seed the loop's draws come from here, and the seed the two worlds in
## claim 6 are both built on.
const SEED := 7
const WORLD_SEED := 1234

## How many ticks of a world are enough for its cast to walk a leg and choose
## another. One `go_to` span and a little either side.
const WORLD_TICKS := 30

## Where the scan looks: every directory in the project that holds code.
const CODE_DIRS := ["res://sim", "res://render", "res://bin", "res://net",
	"res://tools", "res://tests"]

## The two things in the project that advance a character across the ground, and
## the only two the scan may find. Every other write to those fields sets them,
## because standing somebody somewhere is not walking them there.
const MOVERS := ["res://sim/combatant.gd", "res://sim/walk.gd"]

## Where a case is set up rather than lived: a suite that shifts a fixture along
## to put it out of earshot is not a second implementation of walking, and the
## scan reports those separately rather than pretending they are not there.
const FIXTURES := "res://tests/"

## A line that would break claim 5 if it were in the tree, and which the scan
## must catch to be worth anything.
const A_SECOND_MOVER := "	actor.x += gap.x * 0.5"


func _init() -> void:
	suite_name = "walk motion"


func run() -> void:
	_the_walk_is_spread_over_its_span()
	_spreading_it_moved_nobody()
	_the_motion_reaches_the_render_layer()
	_an_interrupted_walk_stands_where_it_reached()
	_one_thing_advances_a_position()
	_the_mover_scan_would_notice()
	_two_worlds_on_one_seed_walk_the_same_walk()


# --- 1. The walk is spread over its span ----------------------------------


## Somewhere new on every tick, a stride at a time.
##
## The walk is aimed further than the span can cover, so every tick of the span
## is motion and none of it is a character standing about having arrived.
func _the_walk_is_spread_over_its_span() -> void:
	var scene := _bare_scene()
	var one: Combatant = scene.actors[0]
	_sheet(one).decide = DecisionSource.scripted(
		func(_scene: ActionScene, _actor: Combatant) -> Action:
			return Action.go_to(FAR))

	var loop := ControlLoop.on(scene, SEED)
	var span := ActionCatalog.occupies_of(ActionCatalog.GO_TO)
	var seen := PackedVector2Array()
	# The first tick is the one the walk is chosen on; the span is the ticks
	# after it, and the last of those is also the tick the walk is resolved on.
	loop.step()
	var was := Vector2(one.x, one.z)
	for _tick in span - 1:
		loop.step()
		var now := Vector2(one.x, one.z)
		seen.append(now)
		check(now != was, "the walker moved on tick %d of its span" % seen.size())
		equal(snappedf(was.distance_to(now), 0.0001), snappedf(STRIDE, 0.0001),
			"and moved exactly one stride on tick %d" % seen.size())
		was = now
	equal(seen.size(), span - 1, "one position per tick of the span")
	equal(snappedf(one.x, 0.001), snappedf(START.x + STRIDE * float(span - 1), 0.001),
		"and the span carried it a stride for each of the ticks it had spent")
	equal(loop.actions_of(one.id), 0, "with the walk still unresolved")

	# And the last tick of the span is the one the engine answers on: the walk is
	# aimed further than the span reaches, so the rest of it is walked there.
	loop.step()
	equal(loop.actions_of(one.id), 1, "the span ran out and the engine answered")
	equal(snappedf(one.x, 0.001), snappedf(FAR.x, 0.001),
		"and the walk finished where it was aimed")


# --- 2. Spreading it moved nobody -----------------------------------------


## The same walk, one call, no span: the same coordinates and the same tally.
##
## This is the claim the whole change stands on. The walk that was spread over
## twenty ticks and the walk resolved in one go are the same strides in the same
## order, so comparing the two is comparing floating-point arithmetic against
## itself rather than against a tolerance.
func _spreading_it_moved_nobody() -> void:
	var spread := _bare_scene()
	var walker: Combatant = spread.actors[0]
	_sheet(walker).decide = DecisionSource.scripted(
		func(_scene: ActionScene, _actor: Combatant) -> Action:
			return Action.go_to(NEAR))
	var loop := ControlLoop.on(spread, SEED)
	loop.run(ActionCatalog.occupies_of(ActionCatalog.GO_TO) + 1)
	var answer := loop.answer_of(walker.id)

	var at_once := _bare_scene()
	var jumper: Combatant = at_once.actors[0]
	var outcome := ActionEngine.resolve(at_once, jumper, Action.go_to(NEAR))

	equal(walker.x, jumper.x, "the spread walk ended at the very same x")
	equal(walker.z, jumper.z, "and the very same z")
	check(outcome.ok, "the walk resolved in one call arrived")
	equal(String(answer.get("line", "")), outcome.line(),
		"and the two outcomes read word for word the same")


# --- 3. The motion reaches the render layer -------------------------------


## What the snapshot says, and what the view makes of it.
##
## Read off `CombatantRoster.snapshot()` -- the dictionary the render shell is
## handed -- rather than off the character, because a field the shell never sees
## proves nothing about what is drawn.
func _the_motion_reaches_the_render_layer() -> void:
	var world := SimWorld.new(WORLD_SEED)
	var followed := world.follow_id
	check(followed != 0, "the world is looking through somebody")

	var walking := 0
	var clips := {}
	for _tick in WORLD_TICKS:
		world.step()
		var row := _row_of(world, followed)
		var speed := float(row.get("speed", 0.0))
		if speed > 0.0:
			walking += 1
			equal(snappedf(speed, 0.0001), snappedf(STRIDE, 0.0001),
				"the snapshot reports a stride a tick while the walk is under way")
		var clip := CharacterView.clip_for(CharacterView.observer_state(world.snapshot()))
		clips[clip] = int(clips.get(clip, 0)) + 1
	check(walking >= WORLD_TICKS - 2,
		"the snapshot reported motion on %d of %d ticks" % [walking, WORLD_TICKS])
	equal(int(clips.get(CharacterView.CLIP_WALK, 0)), walking,
		"and the view picked its walk clip on exactly the ticks it moved")

	# And nothing at all for a character with nothing to do: the world holds a
	# scene with no decision functions in it, so nobody walks.
	var still := _bare_scene()
	var standing: Combatant = still.actors[0]
	_sheet(standing).decide = Callable()
	ControlLoop.on(still, SEED).run(WORLD_TICKS)
	equal(standing.moved, 0.0, "a character choosing nothing reports no motion")


# --- 4. An interrupted walk stands where it reached -----------------------


## Spoken to part-way through a walk, and standing exactly that far along.
##
## The interruption is section 2.2's own: a word addressed by name. What is
## checked is not that the walker stopped but *where* it stopped -- the strides
## it had actually taken, to the last decimal -- and that the walk it gave up on
## never reached the engine all the same.
func _an_interrupted_walk_stands_where_it_reached() -> void:
	var scene := _bare_scene()
	var walker: Combatant = scene.actors[0]
	var caller: Combatant = scene.actors[1]
	_sheet(walker).decide = DecisionSource.scripted(
		func(_scene: ActionScene, _actor: Combatant) -> Action:
			return Action.go_to(FAR))
	_sheet(caller).decide = DecisionSource.recorded([
		Action.say("a word with you", walker.id)])

	var loop := ControlLoop.on(scene, SEED)
	var say_span := ActionCatalog.occupies_of(ActionCatalog.SAY)
	loop.run(say_span + 1)

	equal(loop.counts()[ControlLoop.SPOKEN_TO], 1, "the walker was interrupted")
	equal(loop.actions_of(walker.id), 0,
		"and the walk it abandoned never reached the engine")
	# It was committed on tick 1 and struck at the end of tick `say_span + 1`,
	# so it strode on every tick in between and on the tick of the blow.
	var strides := say_span
	equal(snappedf(walker.x, 0.001), snappedf(START.x + STRIDE * float(strides), 0.001),
		"and it is standing exactly the %d strides it took along the way" % strides)
	equal(scene.walk_of(walker.id), null,
		"and the walk it gave up on was forgotten with the commitment")

	# The walk it chooses next sets off from there rather than from where it
	# started: one more tick, one more stride, measured from the interruption.
	check(loop.is_busy(walker.id), "the walker chose again at once")
	var stopped := walker.x
	loop.step()
	equal(snappedf(walker.x - stopped, 0.001), snappedf(STRIDE, 0.001),
		"and the next walk set off from where it had actually reached")


# --- 5. One thing advances a position -------------------------------------


## Every file in the project, scanned for anything that moves a character.
##
## The rule the scan reads is one the code keeps on purpose: advancing a
## combatant across the ground *adds* to its `x` and `z`, and every other place
## in the project that touches those two fields *sets* them, because putting
## somebody down at a place is not walking them to it. So "is there a second
## implementation of walking?" is a search for `+=` on those fields rather than a
## list somebody wrote down and has to remember to update.
func _one_thing_advances_a_position() -> void:
	var found := PackedStringArray()
	var files := PackedStringArray()
	var in_fixtures := PackedStringArray()
	for path in _every_code_file():
		var hits := _advances_in(path, _code_lines(path))
		if hits.is_empty():
			continue
		# A suite nudging a fixture along to set a case up is not the world
		# running; the claim is about the code the world runs on.
		if path.begins_with(FIXTURES):
			in_fixtures.append_array(hits)
			continue
		found.append_array(hits)
		if not files.has(path):
			files.append(path)
	files.sort()
	equal(files, PackedStringArray(MOVERS),
		"exactly two files in the project advance a character across the ground:\n"
		+ "      %s" % "\n      ".join(found))
	equal(found.size(), 4,
		"and each of the two does it once, in x and in z:\n      %s"
		% "\n      ".join(found))
	check(not in_fixtures.is_empty(),
		"and the scan reaches the suites too, where it finds only fixtures"
		+ " being stood somewhere:\n      %s" % "\n      ".join(in_fixtures))


## The scan run over a line that would break the claim.
func _the_mover_scan_would_notice() -> void:
	var planted := PackedStringArray(["extends RefCounted", A_SECOND_MOVER])
	equal(_advances_in("res://sim/somewhere_else.gd", planted).size(), 1,
		"a second thing that advances a position is caught")
	equal(_advances_in("res://sim/somewhere_else.gd",
		PackedStringArray(["	actor.x = to.x"])).size(), 0,
		"and putting somebody down somewhere is not caught")


# --- 6. It is still a function of the seed and the tick -------------------


## Two worlds, one seed, the same walk to the last decimal at every tick.
func _two_worlds_on_one_seed_walk_the_same_walk() -> void:
	var here := SimWorld.new(WORLD_SEED)
	var there := SimWorld.new(WORLD_SEED)
	var same_place := true
	var same_digest := true
	for _tick in WORLD_TICKS:
		here.step()
		there.step()
		for one in here.combat.members:
			var twin := there.combat.member_of(one.id)
			if twin == null or one.x != twin.x or one.z != twin.z or one.y != twin.y:
				same_place = false
		if here.digest() != there.digest():
			same_digest = false
	check(same_place, "both worlds walked their casts to the same coordinates")
	check(same_digest, "and fingerprinted the same at every tick")


# --- The furniture --------------------------------------------------------


# Whether a line of code advances a combatant's ground position: it adds to the
# `x` or the `z` of something. Inside `sim/combatant.gd` those two fields are the
# class's own, so a bare `x +=` counts there and a bare one anywhere else is
# somebody's local variable and does not.
static func _advances_in(path: String, lines: PackedStringArray) -> PackedStringArray:
	var found := PackedStringArray()
	var numbered := 0
	for line in lines:
		numbered += 1
		var code := line.strip_edges()
		var moves := code.begins_with("x +=") or code.begins_with("z +=")
		if not path.ends_with("/combatant.gd"):
			moves = false
		if code.contains(".x +=") or code.contains(".z +="):
			moves = true
		if moves:
			found.append("%s:%d %s" % [path, numbered, code])
	return found


static func _every_code_file() -> PackedStringArray:
	var found := PackedStringArray()
	for dir_path in CODE_DIRS:
		_gather(dir_path, found)
	found.sort()
	return found


static func _gather(dir_path: String, into: PackedStringArray) -> void:
	var listing := DirAccess.open(dir_path)
	if listing == null:
		return
	listing.list_dir_begin()
	var entry := listing.get_next()
	while entry != "":
		var full := "%s/%s" % [dir_path, entry]
		if listing.current_is_dir():
			_gather(full, into)
		elif entry.ends_with(".gd"):
			into.append(full)
		entry = listing.get_next()
	listing.list_dir_end()


static func _code_lines(path: String) -> PackedStringArray:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		kept.append(AssetCheck.split_code_and_strings(line)["code"])
	return kept


func _row_of(world: SimWorld, id: int) -> Dictionary:
	for row in world.combat.snapshot()["pieces"]:
		if int(row["id"]) == id:
			return row
	return {}


# Two characters standing on no terrain: a walk is then arithmetic, and nothing
# about the world's fields can move a number here.
func _bare_scene() -> ActionScene:
	var scene := ActionScene.new()
	scene.add_actor(_stood("Rook", START))
	scene.add_actor(_stood("Wren", Vector2(2.0, 0.0)))
	return scene


static func _stood(called: String, at: Vector2) -> Combatant:
	var one := Combatant.commander_at(at.x, at.y, 0.0, 0.0, 2, AssetTags.KNIGHT)
	(one.piece as Commander).adopt(Character.make(called, 2))
	return one


static func _sheet(one: Combatant) -> Character:
	return (one.piece as Commander).sheet
