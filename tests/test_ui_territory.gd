extends TestSuite
## The territory readout is drawn from the pack, off the world the simulation
## is holding -- and every number on it is the simulation's own answer, asked
## on the frame it is drawn.
##
## Five claims, in the order they matter:
##
##   1. **The readout is a view and not a copy.** Who owns the ground and how
##      the followed character stands with everybody it knows are read off the
##      simulation on every frame, and the panel has no field holding any of
##      it. Checked the way every panel before it was: move the world without
##      telling the panel -- here, across the tick the market's honoured trade
##      flips the ground under Wren from neutral to owned.
##   2. **Every number is the rule's own answer.** The owner, the score and
##      each standing row equal what `OwnershipField.at` and the relationship
##      graph say when asked directly, on the same tick.
##   3. **The render side holds no piece of the rule.** Neither the panel nor
##      its source names a constant or a shape of the ownership arithmetic;
##      reading the field is asking the one function, never re-deriving it.
##   4. **The readout uses the pack and decides no idiom of its own**: the
##      shared theme, no overrides, the pack's own crown and heart.
##   5. **The readout changes nothing about the world**: the same seed with
##      and without it reaches the same fingerprint.
class_name TestUiTerritory

## The seed every write-up of the market run uses, so a tick number here means
## the same tick there.
const SEED := 1234

## How far into the market run to look for the tick the honoured trade flips
## the ground under Wren from neutral to owned. Not the tick itself: that is
## found by asking the rule, in `_flip_tick()` below, because it moves whenever
## anything changes how fast the run gets through its plan. It was tick 62
## before a walk started costing the strides it takes (ac63731) and is tick 34
## after, which is exactly how a `NEUTRAL_TICK := 55` written down here came to
## be a tick on already-owned ground. A bound rather than an answer is the only
## number about this run that is safe to write down.
const SEARCH_TICKS := 240

## Ticks to step past the flip without telling the panel. Any number that
## carries from the last neutral tick over the flip would do; ten leaves room
## on the far side for the score to settle.
const LATER_TICKS := 10

const FIXED_FPS := 60
const FRAMES := 60

## What `_flip_tick()` last answered; -1 until it has been asked.
var _flip_tick_found := -1


func _init() -> void:
	suite_name = "ui territory"


func run() -> void:
	_the_panel_reads_the_ground_and_keeps_no_copy()
	_every_number_is_the_simulations_own_answer()
	_the_render_side_holds_no_piece_of_the_rule()
	_the_panel_uses_the_pack_and_decides_no_idiom_of_its_own()
	_the_readout_changes_nothing_about_the_world()


# --- The readout is a view -------------------------------------------------


## Ownership moved after the panel was built shows on the panel. Nothing
## pushes it there and nothing is invalidated: the panel asks the rule again
## on every refresh.
func _the_panel_reads_the_ground_and_keeps_no_copy() -> void:
	if not SproutPack.is_installed():
		return
	var flip := _flip_tick()
	check(flip > 1, "the honoured trade never flips the ground under Wren"
		+ " within %d ticks, so there is no neutral tick to start from"
		% SEARCH_TICKS)
	if flip <= 1:
		return
	var sim := _market_world(flip - 1)
	var panel := TerritoryPanel.new()
	panel.watch(sim.world, sim.world.follow_id)
	panel.refresh()
	check(panel.visible, "the readout hid itself while the world held a cast")
	equal(panel._ground_owner.text, TerritoryPanel.NEUTRAL,
		"the ground under Wren did not read neutral before the trade")

	# Now live the world across the honoured trade, and ask the panel again
	# without telling it anything.
	for _step in LATER_TICKS:
		sim.step()
	panel.refresh()
	var claim := _claim_under(sim, sim.world.follow_id)
	check(claim != null and not claim.is_neutral(),
		"the market's honoured trade did not flip the ground by tick %d"
		% sim.world.tick)
	if claim == null or claim.is_neutral():
		panel.free()
		return
	equal(panel._ground_owner.text,
		"owned by %s" % TerritorySource.name_of(sim.world, claim.owner_id),
		"the flipped ground is not on the panel, or names the wrong owner")
	equal(panel._ground_score.text, "%+.2f" % claim.best,
		"the top score on the panel is not the claim's own")

	# And there is no second copy of any of it anywhere on this side. `owner`
	# itself cannot be scanned for: every Node carries the engine's own
	# scene-tree `owner` property, which is nothing of the simulation's.
	for field in ["owner_id", "claim", "score", "scores", "best",
			"edges", "edge", "standing", "standings", "sentiment", "ownership"]:
		check(not _has_property(panel, field),
			"the readout has a field of its own called '%s'" % field)
		check(not _has_property(TerritorySource.new(), field),
			"the source has a field of its own called '%s'" % field)
	panel.free()


## The panel says what the rule and the graph say, number by number, asked of
## the simulation directly on the same tick.
func _every_number_is_the_simulations_own_answer() -> void:
	if not SproutPack.is_installed():
		return
	var flip := _flip_tick()
	if flip <= 1:
		return
	var sim := _market_world(flip - 1 + LATER_TICKS)
	var wren := sim.world.follow_id
	var panel := TerritoryPanel.new()
	panel.watch(sim.world, wren)
	panel.refresh()

	var claim := _claim_under(sim, wren)
	check(claim != null, "there is no claim to read under the followed character")
	if claim == null:
		panel.free()
		return
	equal(panel._ground_score.text, "%+.2f" % claim.best,
		"the score on the panel is not what the field answers")

	var graph := sim.world.combat.scene.relationships
	var edges := graph.edges_of(wren)
	equal(panel._standing_head.text, "standing %d" % edges.size(),
		"the heading does not count the graph's own edges")
	equal(panel._standing_rows.get_child_count(),
		mini(edges.size(), TerritoryPanel.STANDING_ROWS),
		"the panel draws a different number of standings than the graph holds")
	check(edges.size() > 0, "Wren knows nobody by tick %d, so nothing is checked"
		% sim.world.tick)
	for index in panel._standing_rows.get_child_count():
		var row := panel._standing_rows.get_child(index)
		var edge: RelationshipEdge = edges[index]
		var other := edge.other_than(wren)
		equal((row.get_child(1) as Label).text,
			TerritorySource.name_of(sim.world, other),
			"standing row %d names the wrong character" % index)
		equal((row.get_child(2) as Label).text,
			"%+.2f" % edge.sentiment_of(wren),
			"standing row %d does not read Wren's own sentiment" % index)
		equal((row.get_child(3) as Label).text,
			"%+.2f" % edge.sentiment_of(other),
			"standing row %d does not read the other's sentiment back" % index)
	check(not panel._resting.visible,
		"the panel says '%s' while Wren knows somebody" % TerritoryPanel.RESTING)
	panel.free()


# --- The render side holds no piece of the rule ----------------------------


## Reading the field is asking `OwnershipField.at`; re-deriving it would start
## with naming its constants or its shapes. Neither render file does.
func _the_render_side_holds_no_piece_of_the_rule() -> void:
	for path in ["res://render/ui/territory_panel.gd",
			"res://render/ui/territory_source.gd"]:
		var text := FileAccess.get_file_as_string(path)
		check(text != "", "cannot read %s" % path)
		for named in ["TEMPERATURE", "RADIUS", "THRESHOLD", "SOFTMIN",
				"NEARNESS", "proximity(", "exp(", "carry("]:
			check(not _code_of(text).contains(named),
				"%s names '%s', which is the rule's own arithmetic"
				% [path, named])


## The file with its comments stripped, so prose may discuss the rule while
## code may not reach for it -- the same reading tests/layer_check.gd does.
static func _code_of(text: String) -> String:
	var kept := PackedStringArray()
	for line in text.split("\n"):
		var at := line.find("#")
		kept.append(line if at == -1 else line.substr(0, at))
	return "\n".join(kept)


# --- The pack, and one idiom -----------------------------------------------


func _the_panel_uses_the_pack_and_decides_no_idiom_of_its_own() -> void:
	if not SproutPack.is_installed():
		return
	var layer := PixelUi.build(false, false, false, false, false, true)
	check(layer != null, "the interface did not build")
	if layer == null:
		return
	check(layer.territory != null, "the territory readout was not built")
	check(layer.panel == null and layer.readout == null and layer.trade == null
		and layer.dialogue == null,
		"a run that asked for only the territory readout got another panel too")
	if layer.territory == null:
		layer.free()
		return
	check(layer.territory.theme == null,
		"the readout carries a theme of its own rather than the shared one")
	var overriding := TestUiReadout._overriding_under(layer.territory)
	equal(",".join(overriding), "",
		"part of the readout overrides the theme's own font, size or style")
	# The two icons it draws with are the pack's own cells.
	for face in layer.territory._faces.values():
		var icon := face as Texture2D
		check(icon != null and icon.get_width() == SproutPack.CELL
			and icon.get_height() == SproutPack.CELL,
			"an icon on the readout is not one cell of the pack")
	layer.free()


# --- The world underneath --------------------------------------------------


## The readout draws the world and changes none of it: the same seed with and
## without it reaches the same fingerprint.
func _the_readout_changes_nothing_about_the_world() -> void:
	var without := _digest_of(_run_shell(["--scenario", Simulation.SCENARIO_MARKET]))
	var with_readout := _digest_of(_run_shell(["--territory", "--scenario",
		Simulation.SCENARIO_MARKET]))
	check(without != "", "the shell printed no world fingerprint")
	equal(with_readout, without,
		"the world the shell reached differed with the territory readout on screen")


# --- Helpers ---------------------------------------------------------------


## The tick the market run's honoured trade flips the ground under Wren from
## neutral to owned, asked of the rule rather than written down: step a run of
## this suite's own and watch `OwnershipField` answer about the ground the
## followed character is standing on. Returns 0 if it never flips inside
## `SEARCH_TICKS`, which is a failure of this suite's premise and is reported
## as one.
##
## The run stepped here is the same seed and the same scenario as the one the
## checks then use, and this project's worlds are deterministic
## (`TestDeterminism`), so the tick found is the tick that will arrive. It
## costs one extra market run of a few dozen ticks, which is the price of never
## again having a number in this file go quietly out of date.
##
## Cached because both checks want it and the answer cannot change inside one
## run of the suite: -1 is "not asked yet", 0 is "asked, and it never flips".
func _flip_tick() -> int:
	if _flip_tick_found >= 0:
		return _flip_tick_found
	_flip_tick_found = 0
	var sim := Simulation.new(SEED)
	sim.begin_scenario(Simulation.SCENARIO_MARKET)
	for _tick in SEARCH_TICKS:
		sim.step()
		var claim := _claim_under(sim, sim.world.follow_id)
		if claim != null and not claim.is_neutral():
			_flip_tick_found = sim.world.tick
			break
	return _flip_tick_found


func _market_world(ticks: int) -> Simulation:
	var sim := Simulation.new(SEED)
	sim.begin_scenario(Simulation.SCENARIO_MARKET)
	for _tick in ticks:
		sim.step()
	return sim


## The rule's own answer for the ground under one character, asked directly of
## the field rather than through the render layer being tested.
static func _claim_under(sim: Simulation, id: int) -> OwnershipClaim:
	var scene := sim.world.combat.scene
	var one := scene.actor_of(id)
	if one == null:
		return null
	return OwnershipField.at(scene.actors, scene.relationships, one.x, one.z)


static func _has_property(on: Object, named: String) -> bool:
	for entry in on.get_property_list():
		if String(entry["name"]) == named:
			return true
	return false


func _digest_of(output: String) -> String:
	for line in output.split("\n"):
		if line.begins_with("render-shell stop"):
			return line.substr(line.find("digest="))
	return ""


func _run_shell(extra: Array) -> String:
	var args: Array = ["--headless", "--path",
		ProjectSettings.globalize_path("res://"),
		"--fixed-fps", str(FIXED_FPS), "--quit-after", str(FRAMES),
		"--", "--seed", str(SEED), "--no-grass", "--no-atmosphere"]
	args.append_array(extra)
	var output: Array[String] = []
	OS.execute(OS.get_executable_path(), args, output, true)
	return "\n".join(output)
