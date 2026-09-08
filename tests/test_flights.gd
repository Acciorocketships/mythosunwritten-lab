extends TestSuite
## An arrow that crosses the board: the flight objects the blow record fires.
##
## `render/blow_flights.gd` turns the snapshot's blow record into flights,
## `render/flight_art.gd` says what each effect tag flies as, and
## `render/flight_view.gd` is the body in the world that crosses between the
## two cells. This suite holds all three to the same contract the swing
## animation is held to: everything is a function of the record, and the record
## is the simulation's own word.
##
## Seven claims:
##
##   1. **Flights are a pure function of the snapshot.** A hand-built snapshot
##      dictionary -- no simulation object anywhere -- produces the flight its
##      blow row describes, twice over identically. Fired from the record, not
##      from the fight.
##   2. **What the attack says about its own movement is honoured.** An instant
##      blow launches nothing; a blow of another fight launches nothing; a blow
##      before its tick or after its motion has ended launches nothing.
##   3. **The endpoints are the record's, verbatim.** A blow whose `to_cell`
##      sits nowhere near any nominal pattern still flies exactly there,
##      because where a split or homed attack landed is what the resolution
##      step wrote down, and the render layer recomputes none of it.
##   4. **The flight leaves when the record says and arrives when the motion
##      ends** -- phase 0 on the blow's own tick, phase 1 on the last tick the
##      motion is still drawn, gone after, with the span read off the same
##      motion table the swing reads.
##   5. **In the seeded seven-weapon run, what travels flies and nothing else
##      does.** Every flight of every tick maps back to a projectile blow of
##      the record, every projectile blow in its window has its flight, and no
##      instant blow ever launches one.
##   6. **Every effect tag flies as something, and a magic bolt is not an
##      arrow.** All six tags have a body, a tag the table never heard of
##      falls back to something visible rather than to nothing, and the count
##      of shipped attacks taking that fallback is a number: zero.
##   7. **The flight object crosses between the two cells** -- at phase 0 it
##      stands over the start cell, at 1 over the end cell, in between on the
##      straight line between them.
##
## The eighth claim -- that none of this reaches the simulation -- is run last
## because it is the slowest: the render shell plays the volley scenario with
## every arrow drawn, and the world it arrives at is fingerprint-identical to
## the same seed run with no renderer at all.
class_name TestFlights

## The seed and length of the volley comparison, and the shell frames that
## cover them: FRAMES / FIXED_FPS seconds of simulated time at the shell's
## twenty ticks a second.
const SEED := 1234
const TICKS := 60
const FIXED_FPS := 60
const FRAMES := 180


func _init() -> void:
	suite_name = "flights"


func run() -> void:
	_flights_are_a_pure_function_of_the_record()
	_movement_is_honoured()
	_endpoints_are_the_records_verbatim()
	_the_flight_leaves_and_arrives_with_the_motion()
	_the_seeded_run_flies_what_travels_and_nothing_else()
	_every_effect_tag_flies_as_something()
	_no_shipped_attack_takes_the_fallback()
	_the_flight_object_crosses_between_the_cells()
	_rendering_the_volley_changes_nothing()


# --- A snapshot by hand ----------------------------------------------------


## The smallest snapshot that carries one blow: what the roster hands out, with
## only the fields the flight planner reads. Built by hand so that claim 1 is
## literal -- no simulation object is anywhere near the call.
func _snapshot(blow: Dictionary, tick_now: int, fights_begun: int = 1) -> Dictionary:
	return {"combat": {
		"tick": tick_now,
		"fights_begun": fights_begun,
		"pieces": [
			{"id": 7, "cell_x": 2, "cell_y": 3, "y": 4.0, "fighting": true},
			{"id": 9, "cell_x": 6, "cell_y": 3, "y": 5.0, "fighting": true},
		],
		"blows": [blow],
	}}


func _arrow_blow() -> Dictionary:
	return {
		"from": 7, "to": 9, "fight": 1, "tick": 20,
		"from_cell": Vector2i(2, 3), "to_cell": Vector2i(6, 3),
		"sprite": AssetTags.EFFECT_ARROW, "animation": AssetTags.ANIM_SHOOT,
		"movement": "projectile",
	}


func _flights_are_a_pure_function_of_the_record() -> void:
	var snapshot := _snapshot(_arrow_blow(), 20)
	var first := BlowFlights.flights(snapshot)
	var again := BlowFlights.flights(snapshot)
	equal(first.size(), 1, "one projectile blow in its window should fly once")
	equal(str(first), str(again), "the same snapshot should plan the same flights")
	if first.is_empty():
		return
	var flight := first[0]
	equal(flight["sprite"], AssetTags.EFFECT_ARROW, "the flight wears the record's sprite tag")
	equal(flight["animation"], AssetTags.ANIM_SHOOT, "the flight carries the record's animation tag")
	equal(flight["from_cell"], Vector2i(2, 3), "the flight leaves the record's from_cell")
	equal(flight["to_cell"], Vector2i(6, 3), "the flight lands on the record's to_cell")
	equal(float(flight["from_height"]), 4.0, "the start height is the striker's own")
	equal(float(flight["to_height"]), 5.0, "the end height is the struck one's own")


func _movement_is_honoured() -> void:
	var instant := _arrow_blow()
	instant["movement"] = "instant"
	equal(BlowFlights.flights(_snapshot(instant, 20)).size(), 0,
		"an instant blow must launch nothing")

	var elsewhere := _arrow_blow()
	elsewhere["fight"] = 1
	equal(BlowFlights.flights(_snapshot(elsewhere, 20, 2)).size(), 0,
		"a blow of an earlier fight must launch nothing")

	equal(BlowFlights.flights(_snapshot(_arrow_blow(), 19)).size(), 0,
		"a blow has not begun before its own tick")

	var span := CharacterRig.motion_ticks(AssetTags.ANIM_SHOOT)
	equal(BlowFlights.flights(_snapshot(_arrow_blow(), 20 + span)).size(), 0,
		"a flight ends when its motion does")


func _endpoints_are_the_records_verbatim() -> void:
	# A cell no pattern of the wielder could nominally reach: what a split that
	# homed onto somebody actually resolved to. The planner must copy it, not
	# re-derive it from any shape.
	var homed := _arrow_blow()
	homed["to_cell"] = Vector2i(-11, 17)
	homed["sprite"] = AssetTags.EFFECT_BOLT
	var rows := BlowFlights.flights(_snapshot(homed, 22))
	equal(rows.size(), 1, "a homed blow still flies")
	if rows.is_empty():
		return
	equal(rows[0]["to_cell"], Vector2i(-11, 17),
		"what is drawn follows what the simulation resolved: the record's "
		+ "to_cell, verbatim, however strange it looks")


func _the_flight_leaves_and_arrives_with_the_motion() -> void:
	var span := CharacterRig.motion_ticks(AssetTags.ANIM_SHOOT)
	check(span > 1, "the shoot motion should last more than one tick")

	var leaving := BlowFlights.flights(_snapshot(_arrow_blow(), 20))
	equal(float(leaving[0]["phase"]), 0.0,
		"on the tick the record says the blow began, the flight is at its start")

	var landing := BlowFlights.flights(_snapshot(_arrow_blow(), 20 + span - 1))
	equal(landing.size(), 1, "the flight is still drawn on the motion's last tick")
	if not landing.is_empty():
		equal(float(landing[0]["phase"]), 1.0,
			"on the motion's last tick the flight has arrived: the arrival is "
			+ "the swing's own end, by the same motion table")

	var midway := BlowFlights.flights(_snapshot(_arrow_blow(), 20 + span / 2))
	if not midway.is_empty():
		var phase := float(midway[0]["phase"])
		check(phase > 0.0 and phase < 1.0,
			"half way through the motion the flight is in the air (phase %.2f)" % phase)


# --- The seeded run --------------------------------------------------------


func _the_seeded_run_flies_what_travels_and_nothing_else() -> void:
	var staged := TestAttackClips.stage()
	check(bool(staged["began"]), "the seven-weapon fight should begin")
	var flights_seen := 0
	var landings_checked := 0
	for _step in TestAttackClips.TICKS:
		var snapshot := TestAttackClips.advance(staged)
		var combat: Dictionary = snapshot["combat"]
		var by_key := {}
		for blow in combat.get("blows", []):
			var row: Dictionary = blow
			by_key["%d:%d:%d" % [
				int(row["fight"]), int(row["from"]), int(row["tick"]),
			]] = row
		var rows := BlowFlights.flights(snapshot)
		flights_seen += rows.size()
		for flight in rows:
			var source: Dictionary = by_key.get(String(flight["key"]), {})
			check(not source.is_empty(),
				"flight %s does not map back to any blow of the record" % flight["key"])
			if source.is_empty():
				continue
			equal(String(source["movement"]), BlowFlights.TRAVELS,
				"a flight was launched for a blow that says it does not travel")
			equal(flight["from_cell"], source["from_cell"],
				"the flight's start is not the record's")
			equal(flight["to_cell"], source["to_cell"],
				"the flight's end is not the record's")
		# And the other direction: every projectile blow inside its own window
		# is flying, and every instant blow is not.
		var tick_now := int(combat.get("tick", 0))
		var here := int(combat.get("fights_begun", 0))
		for blow in combat.get("blows", []):
			var row: Dictionary = blow
			if int(row["fight"]) != here:
				continue
			var key := "%d:%d:%d" % [int(row["fight"]), int(row["from"]), int(row["tick"])]
			var flying := false
			for flight in rows:
				if String(flight["key"]) == key:
					flying = true
			var since := tick_now - int(row["tick"])
			var span := CharacterRig.motion_ticks(String(row["animation"]))
			var should := String(row["movement"]) == BlowFlights.TRAVELS \
				and since >= 0 and since < span
			landings_checked += 1
			equal(flying, should,
				"blow %s (%s, since=%d of %d) %s" % [
					key, String(row["movement"]), since, span,
					"should be flying and is not" if should else "should not be flying and is",
				])
	check(flights_seen > 0,
		"the seeded run's bow never put a single flight in the air")
	check(landings_checked > 0, "no blows were checked at all")


# --- The art ----------------------------------------------------------------


func _every_effect_tag_flies_as_something() -> void:
	equal(FlightArt.missing_tags().size(), 0,
		"effect tags with no flight body: %s" % ", ".join(FlightArt.missing_tags()))
	equal(FlightArt.unknown_rows().size(), 0,
		"flight bodies nothing can ask for: %s" % ", ".join(FlightArt.unknown_rows()))
	for tag in AssetTags.EFFECT_SPRITES:
		var body := FlightArt.build(tag)
		check(body != null, "'%s' built no body at all" % tag)
		if body != null:
			check(_something_visible(body), "'%s' built a body with nothing to see" % tag)
			body.free()

	# A tag the table never heard of still flies as something visible.
	var strange := FlightArt.build("comet")
	check(strange != null, "an unknown tag built no body at all")
	if strange != null:
		check(_something_visible(strange),
			"the fallback body has nothing to see: an unknown tag flew as nothing")
		strange.free()
	check(not FlightArt.has_body("comet"),
		"has_body claims a row for a tag the table does not hold")

	# And a magic bolt is not an arrow: the arrow is the pack's own model, the
	# bolt is a glow, and the two rows say so.
	var arrow: Dictionary = FlightArt.BODIES[AssetTags.EFFECT_ARROW]
	var bolt: Dictionary = FlightArt.BODIES[AssetTags.EFFECT_BOLT]
	check(String(arrow["model"]) != "", "the arrow should fly as the pack's own arrow")
	equal(String(bolt["model"]), "", "the bolt should be drawn, not a wooden model")
	check(bool(bolt["glow"]) and not bool(arrow["glow"]),
		"a magic bolt should glow and an arrow should not: that is what tells "
		+ "them apart across a board")


## Whether a built body holds anything that would be seen: a mesh, or a model
## scene with meshes in it.
func _something_visible(body: Node) -> bool:
	if body is MeshInstance3D and (body as MeshInstance3D).mesh != null:
		return true
	for child in body.get_children():
		if _something_visible(child):
			return true
	return false


func _no_shipped_attack_takes_the_fallback() -> void:
	var shipped: Array[Attack] = []
	for weapon in Weapon.catalogue():
		shipped.append_array(weapon.attacks)
	for weapon in Weapon.composed():
		shipped.append_array(weapon.attacks)
	check(shipped.size() >= 9, "the shipped catalogue lost attacks (%d)" % shipped.size())
	var falling := PackedStringArray()
	for attack in shipped:
		if not FlightArt.has_body(attack.sprite_tag):
			falling.append("%s (%s)" % [attack.attack_name, attack.sprite_tag])
	equal(falling.size(), 0,
		"shipped attacks taking the fallback body: %s" % ", ".join(falling))
	# The count can count: an attack with an unheard-of tag would be caught.
	check(not FlightArt.has_body("comet"),
		"the fallback count could never rise: unknown tags read as covered")


# --- The object itself ------------------------------------------------------


func _the_flight_object_crosses_between_the_cells() -> void:
	var flight := FlightView.new()
	flight.launch(Vector2i(2, 3), Vector2i(6, 3),
		AssetTags.EFFECT_ARROW, AssetTags.ANIM_SHOOT, 4.0, 5.0)
	var start := flight.point_at(0.0)
	var finish := flight.point_at(1.0)
	var from_centre := CombatBoard.centre_of(Vector2i(2, 3))
	var to_centre := CombatBoard.centre_of(Vector2i(6, 3))
	equal(Vector2(start.x, start.z), from_centre,
		"at phase 0 the flight stands over the start cell's centre")
	equal(Vector2(finish.x, finish.z), to_centre,
		"at phase 1 the flight stands over the end cell's centre")
	check(is_equal_approx(start.y, 4.0 + FlightView.LIFT),
		"the flight leaves at chest height over its ground (%.4f)" % start.y)
	check(is_equal_approx(finish.y, 5.0 + FlightView.LIFT),
		"the flight arrives at chest height over its ground (%.4f)" % finish.y)
	var midway := flight.point_at(0.5)
	equal(Vector2(midway.x, midway.z), (from_centre + to_centre) * 0.5,
		"half way through, the flight is half way between the two cells")
	equal(flight.sprite_tag, AssetTags.EFFECT_ARROW, "the flight says which art it wears")
	equal(flight.animation_tag, AssetTags.ANIM_SHOOT, "the flight says which motion timed it")
	flight.free()


# --- Nothing reaches the simulation ----------------------------------------


func _rendering_the_volley_changes_nothing() -> void:
	# The volley scenario, with no renderer anywhere: the ground truth.
	var headless := Simulation.new(SEED)
	check(headless.begin_scenario(Simulation.SCENARIO_VOLLEY),
		"the volley scenario refused to muster")
	headless.run(TICKS)

	# The record the whole feature hangs off actually has things that travel.
	var travelling := 0
	for blow in headless.world.combat.scene.blows:
		if String(blow["movement"]) == BlowFlights.TRAVELS:
			travelling += 1
	check(travelling > 0, "the volley scenario struck no projectile blow at all")

	# The same seed and ticks through the render shell, arrows drawn and all.
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--fixed-fps", str(FIXED_FPS),
		"--quit-after", str(FRAMES),
		"--",
		"--seed", str(SEED),
		"--scenario", Simulation.SCENARIO_VOLLEY,
	], output, true)
	var printed := "\n".join(output)
	equal(exit_code, 0, "render shell should exit 0 (output: %s)" % printed)
	var drawn_digest := _digest_from(printed)
	check(drawn_digest != "", "render shell did not report a digest: %s" % printed)
	equal(drawn_digest, headless.world.digest(),
		"drawing the flights changed the simulation: the volley at seed %d " % SEED
		+ "reached different worlds rendered and headless at tick %d" % TICKS)


func _digest_from(output: String) -> String:
	for line in output.split("\n"):
		var at := line.find("digest=")
		if at >= 0:
			return line.substr(at + "digest=".length()).strip_edges()
	return ""
