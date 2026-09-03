extends TestSuite
## The combat readout is drawn from the pack, off the fight the simulation is
## holding -- and the effect tags it draws with resolve to art on this side of
## the line only.
##
## Six claims, in the order they matter:
##
##   1. **The second table is complete and closed.** Every one of the six effect
##      sprites and the seven animations `sim/asset_tags.gd` names has a row in
##      `render/effect_art.gd`, and no row there names anything else. The prop
##      catalogue is untouched, which is the whole reason the table is a second
##      one.
##   2. **The sprites are real art on the pack's own cell**, in the same idiom
##      and the same three colours as the icons the character sheet drew.
##   3. **The animations actually animate.** Each of the seven moves its sprite
##      somewhere its still pose is not, and the seven differ from each other.
##   4. **The readout is a view and not a copy.** The round, the turn order and
##      every cooldown on it are read off the simulation's own objects on every
##      frame, and the panel has no field holding any of them. This is the claim
##      the whole design rests on, and it is checked the way the character
##      sheet's is: move the world without telling the panel.
##   5. **The cooldown arithmetic the last-blow reading rests on is true.** An
##      action with its whole wait still on it is one spent this round, and the
##      simulation's own transcript says which action that was.
##   6. **A headless run loads none of it**, and the readout changes nothing
##      about the world it is drawn over.
class_name TestUiReadout

## The seed the encounter scenario is played at. The same one every other
## write-up of that fight uses, so a tick number here means the same tick there.
const SEED := 1234

## How many ticks of that scenario to play before there is a fight on.
##
## The whole fight is seven ticks: it begins at tick 16 and is decided at tick 22,
## after which the world is back in real time. So this is inside it with room on
## both sides, and `LATER_TICKS` below stays inside it too.
const FIGHT_TICK := 18

## How many further ticks the panel is left alone for before being asked again.
## Three turns of a two-commander fight, which moves both the round and whose
## turn it is, and still lands before the fight is decided.
const LATER_TICKS := 3

const FIXED_FPS := 60
const FRAMES := 60


func _init() -> void:
	suite_name = "ui readout"


func run() -> void:
	_every_effect_tag_has_a_row_and_no_row_is_spare()
	_the_catalogue_was_not_extended()
	_every_sprite_is_sixteen_by_sixteen_in_three_colours()
	_every_animation_moves_and_no_two_move_alike()
	_every_pose_is_whole_pixels_and_right_angles()
	_the_readout_uses_the_pack_and_decides_no_idiom_of_its_own()
	_the_readout_reads_the_fight_and_keeps_no_copy()
	_a_whole_wait_still_on_an_action_means_it_was_spent_this_round()
	_a_headless_run_loads_no_effect_art()
	_the_readout_changes_nothing_about_the_world()


# --- The second table -----------------------------------------------------


func _every_effect_tag_has_a_row_and_no_row_is_spare() -> void:
	equal(",".join(EffectArt.missing_tags()), "",
		"an effect tag the simulation names has no row in the render layer's table")
	equal(",".join(EffectArt.unknown_rows()), "",
		"the table has a row for something neither vocabulary contains")
	equal(EffectArt.tags().size(),
		AssetTags.EFFECT_SPRITES.size() + AssetTags.ANIMATIONS.size(),
		"the table does not have exactly one row per tag of the two vocabularies")
	for tag in AssetTags.EFFECT_SPRITES:
		check(EffectArt.has_sprite(tag), "no sprite is drawn for '%s'" % tag)
		check(EffectArt.sprite_of(tag) != null,
			"the sprite for '%s' did not come back" % tag)
	for tag in AssetTags.ANIMATIONS:
		check(EffectArt.has_motion(tag), "no motion is written for '%s'" % tag)
		check(EffectArt.seconds_of(tag) > 0.0,
			"the animation '%s' plays for no time at all" % tag)


## The catalogue is the set of things that can be standing in the world, and
## `tests/test_asset_tags.gd` pins the render layer's prop table against it. The
## effect vocabularies are deliberately outside both, which is why they needed a
## table of their own; this is that claim, stated where the second table is.
func _the_catalogue_was_not_extended() -> void:
	equal(AssetLibrary.tags().size(), AssetTags.all().size(),
		"the prop catalogue and the render layer's table are no longer the same size")
	for tag in AssetTags.EFFECT_SPRITES:
		check(not AssetTags.is_tag(tag),
			"the effect sprite '%s' has been put in the prop catalogue" % tag)
		check(not AssetLibrary.has_visual(tag),
			"the effect sprite '%s' has been given a prop row" % tag)
	for tag in AssetTags.ANIMATIONS:
		check(not AssetTags.is_tag(tag),
			"the animation '%s' has been put in the prop catalogue" % tag)
		check(not AssetLibrary.has_visual(tag),
			"the animation '%s' has been given a prop row" % tag)


func _every_sprite_is_sixteen_by_sixteen_in_three_colours() -> void:
	for tag in AssetTags.EFFECT_SPRITES:
		var rows: Array = EffectArt.SPRITES.get(tag, [])
		equal(rows.size(), EffectArt.CELL,
			"the sprite '%s' is %d rows, not the cell's %d"
			% [tag, rows.size(), EffectArt.CELL])
		var wrong_width := 0
		var strange := ""
		var drawn := 0
		for y in rows.size():
			var line: String = rows[y]
			if line.length() != EffectArt.CELL:
				wrong_width += 1
			for x in line.length():
				if not line[x] in ".oml":
					strange = line[x]
				elif line[x] != ".":
					drawn += 1
		equal(wrong_width, 0,
			"%d row(s) of '%s' are not the cell's %d characters wide"
			% [wrong_width, tag, EffectArt.CELL])
		equal(strange, "",
			"'%s' is drawn with '%s', which is none of the three colours"
			% [tag, strange])
		check(drawn > 0, "the sprite '%s' is blank" % tag)
		var texture := EffectArt.sprite_of(tag)
		check(texture != null and texture.get_width() == EffectArt.CELL
			and texture.get_height() == EffectArt.CELL,
			"the sprite '%s' did not come out one cell square" % tag)
	equal(EffectArt.CELL, SproutPack.CELL,
		"the effect sprites are not drawn on the pack's own cell")


## Each of the seven puts its sprite somewhere its still pose does not, and no
## two of them do the same thing -- a table of seven identical rows would pass
## every other check here and would be seven names for one animation.
func _every_animation_moves_and_no_two_move_alike() -> void:
	var traces := {}
	for tag in AssetTags.ANIMATIONS:
		var still := EffectArt.pose_of(tag, 0.0)
		var moved := false
		var trace := PackedStringArray()
		for step in 17:
			var pose := EffectArt.pose_of(tag, float(step) / 16.0)
			var offset: Vector2i = pose["offset"]
			var quarters := int(pose["quarter_turns"])
			trace.append("%d,%d,%d" % [offset.x, offset.y, quarters])
			if offset != Vector2i(still["offset"]) \
					or quarters != int(still["quarter_turns"]):
				moved = true
		check(moved, "the animation '%s' never moves its sprite" % tag)
		var key := "|".join(trace)
		check(not traces.has(key),
			"the animations '%s' and '%s' play identically"
			% [tag, traces.get(key, "?")])
		traces[key] = tag


## Every pose is a whole number of art pixels and a whole number of quarter
## turns. A sprite half a pixel off its grid, or turned by anything but a right
## angle, is the blurred edge the whole idiom exists to avoid -- and it would
## show up in tools/measure_ui.sh's off-grid share the moment a play was on
## screen.
func _every_pose_is_whole_pixels_and_right_angles() -> void:
	for tag in AssetTags.ANIMATIONS:
		for step in 65:
			var pose := EffectArt.pose_of(tag, float(step) / 64.0)
			check(pose["offset"] is Vector2i,
				"the pose of '%s' is not in whole art pixels" % tag)
			var quarters := int(pose["quarter_turns"])
			check(absi(quarters) <= 4,
				"the pose of '%s' turns %d quarter turns" % [tag, quarters])
			var angle := EffectArt.radians_of(quarters)
			check(is_equal_approx(fmod(absf(angle), PI * 0.5), 0.0),
				"the turn of '%s' is not a whole quarter turn" % tag)


# --- The pack, and one idiom ----------------------------------------------


## Every icon the readout takes from the pack is inside the sheet it is cut
## from, and every part of the readout is drawn by the theme the character sheet
## already established rather than by anything of its own.
func _the_readout_uses_the_pack_and_decides_no_idiom_of_its_own() -> void:
	if not SproutPack.is_installed():
		return
	for named in [SproutPack.ICON_STAR, SproutPack.ICON_MARK, SproutPack.ICON_DASH,
			SproutPack.ICON_TICK, SproutPack.ICON_BAR]:
		var icon := SproutPack.icon(named)
		check(icon != null and icon.get_width() == SproutPack.CELL
			and icon.get_height() == SproutPack.CELL,
			"the generic icon at column %d row %d is not one cell"
			% [named.x, named.y])

	var layer := PixelUi.build(false, true)
	check(layer != null, "the interface did not build")
	if layer == null:
		return
	check(layer.panel == null,
		"a run that asked for only the readout got a character sheet as well")
	check(layer.readout != null, "the readout was not built")
	if layer.readout == null:
		layer.free()
		return

	# One theme, carried by the frame both panels sit in. A panel with a theme
	# of its own would be a second idiom by definition.
	check(layer._frame.theme is Theme, "the interface layer carries no theme")
	check(layer.readout.theme == null,
		"the readout carries a theme of its own rather than the shared one")
	# And nothing under it overrides a font, a size or a style: those are the
	# three ways a Control stops being drawn by the theme above it.
	var overriding := _overriding_under(layer.readout)
	equal(",".join(overriding), "",
		"part of the readout overrides the theme's own font, size or style")

	# Every size the theme draws the readout with is a whole number of the
	# font's own fourteen-pixel cell.
	for type in ["Label", SproutTheme.HEADING_LABEL, SproutTheme.DIM_LABEL]:
		var size := int(layer._frame.theme.get_font_size("font_size", type))
		equal(size % SproutPack.FONT_CELL, 0,
			"the readout's '%s' is drawn at %d, which is not a multiple of the"
			% [type, size] + " font's own %d-pixel cell" % SproutPack.FONT_CELL)
	layer.free()


static func _overriding_under(root: Node) -> PackedStringArray:
	var found := PackedStringArray()
	for child in root.get_children():
		if child is Control:
			var one := child as Control
			for named in ["font", "font_size", "normal", "panel"]:
				if one.has_theme_font_override(named) \
						or one.has_theme_font_size_override(named) \
						or one.has_theme_stylebox_override(named):
					found.append("%s.%s" % [one.get_class(), named])
			if one.theme != null:
				found.append("%s.theme" % one.get_class())
		found.append_array(_overriding_under(child))
	return found


# --- The readout is a view ------------------------------------------------


## A fight moved after the panel was built shows on the panel. Nothing pushes it
## there and nothing is invalidated: the panel is looking at the same fight.
func _the_readout_reads_the_fight_and_keeps_no_copy() -> void:
	if not SproutPack.is_installed():
		return
	var sim := _fighting_world()
	var fight: Encounter = sim.world.combat.fight
	check(fight != null, "the encounter scenario held no fight by tick %d" % FIGHT_TICK)
	if fight == null:
		return

	var panel := CombatPanel.new()
	panel.watch(sim.world)
	panel.refresh()
	check(panel.visible, "the readout hid itself while a fight was on")
	_the_panel_agrees_with(panel, fight, "on the tick the panel was built")

	# Now move the fight, and ask the panel again without telling it.
	var before := panel._round_label.text
	var acting := panel._acting_label.text
	for _step in LATER_TICKS:
		sim.step()
	var still_on: Encounter = sim.world.combat.fight
	panel.refresh()
	if still_on == null:
		# The fight ended inside those ticks, which is the other half of the same
		# claim: the panel goes away with it.
		check(not panel.visible, "the readout stayed up after the fight ended")
		panel.free()
		return
	_the_panel_agrees_with(panel, still_on, "%d ticks later" % LATER_TICKS)
	check(panel._round_label.text != before or panel._acting_label.text != acting,
		"%d ticks of a fight moved neither the round nor whose turn it is"
		% LATER_TICKS)

	# And there is no second copy of any of it anywhere on this side.
	for field in ["round", "turn", "order", "actions", "cooldowns", "commanders",
			"active", "blow", "health"]:
		check(not _has_property(panel, field),
			"the readout has a field of its own called '%s'" % field)
	panel.free()


## The panel says what the fight says, field by field, read off the simulation's
## own objects rather than off the source the panel itself read.
func _the_panel_agrees_with(panel: CombatPanel, fight: Encounter, when: String) -> void:
	var state: CombatMatch = fight.match_state
	var turn := state.round_number
	var order := state.commanders()
	equal(panel._round_label.text, "round %d" % turn,
		"the round on the readout is not the fight's %s" % when)
	equal(panel._order_rows.get_child_count(),
		mini(order.size(), CombatPanel.ORDER_ROWS),
		"the readout draws a different number of commanders than are in the fight %s"
		% when)

	var acting: Commander = state.active_commander()
	check(acting != null, "the fight has no commander acting %s" % when)
	if acting == null:
		return
	equal(panel._acting_label.text, _name_of(acting),
		"the readout names the wrong commander as acting %s" % when)
	equal(panel._action_rows.get_child_count(),
		mini(acting.attack_count(), CombatPanel.ACTION_ROWS),
		"the readout draws a different number of weapon actions %s" % when)
	for index in panel._action_rows.get_child_count():
		var row := panel._action_rows.get_child(index)
		var one: Attack = acting.attack_at(index)
		equal((row.get_child(1) as Label).text, one.attack_name,
			"weapon action %d is named wrongly %s" % [index, when])
		var ready_now := acting.can_attack(index, turn)
		equal((row.get_child(3) as Label).text,
			"ready" if ready_now else "%d" % acting.turns_until_ready(index, turn),
			"weapon action '%s' reads the wrong state %s" % [one.attack_name, when])
		equal((row.get_child(0) as TextureRect).texture,
			EffectArt.sprite_of(one.sprite_tag),
			"weapon action '%s' is drawn with the wrong sprite %s"
			% [one.attack_name, when])


## The reading the last-blow strip rests on, checked against the fight's own
## transcript rather than against itself: an action whose whole wait is still on
## it was spent this round, and the transcript names which action that was.
func _a_whole_wait_still_on_an_action_means_it_was_spent_this_round() -> void:
	var sim := _fighting_world()
	var on: Encounter = sim.world.combat.fight
	if on == null:
		return
	# Step until the fight writes down a weapon action on a tick that did not
	# also wrap into the next round. The wrap matters: a cooldown is counted in
	# rounds, so the "whole wait still on it" reading is about the round the blow
	# landed in, and a tick that ends one round and begins another has already
	# moved past it. Every commander but the last in the order gives such a tick.
	var struck := ""
	for _step in 40:
		if sim.world.combat.fight != on:
			break
		var was := on.match_state.round_number
		var before := on.lines.size()
		sim.step()
		if sim.world.combat.fight != on or on.match_state.round_number != was:
			continue
		for index in range(before, on.lines.size()):
			var line: String = on.lines[index]
			if line.strip_edges().begins_with("attack #"):
				struck = line
		if struck != "":
			break
	check(struck != "", "no weapon action resolved inside its own round in forty ticks")
	if struck == "" or sim.world.combat.fight != on:
		return

	var blow := FightSource.last_blow(sim.world)
	check(not blow.is_empty(),
		"a weapon action resolved and the cooldowns showed no blow: %s" % struck)
	if blow.is_empty():
		return
	equal(int(blow["rounds_ago"]), 0,
		"the blow struck on this very round did not read as struck this round")
	check(struck.contains(String(blow["name"])),
		"the cooldowns name '%s' as the last blow; the fight wrote '%s'"
		% [String(blow["name"]), struck.strip_edges()])
	check(EffectArt.has_sprite(String(blow["sprite"])),
		"the blow's sprite tag '%s' has no row" % String(blow["sprite"]))
	check(EffectArt.has_motion(String(blow["animation"])),
		"the blow's animation tag '%s' has no row" % String(blow["animation"]))


# --- Headless, and the world underneath -----------------------------------


## A headless run loads no effect sprite and not one script of the interface,
## asked from outside of the engine's own resource cache -- the same way the
## same claim is asked about the models and about the character sheet.
func _a_headless_run_loads_no_effect_art() -> void:
	var output := _run(["--seed", str(SEED), "--ticks", "40", "--assets"],
		"res://bin/headless_main.gd")
	check(output.contains("assets visual-files found="),
		"the headless run printed no asset report")
	for line in output.split("\n"):
		if line.begins_with("assets visual-files") \
				or line.begins_with("assets render-scripts"):
			check(line.contains("loaded=0"),
				"a headless run loaded something it should not have: %s" % line)
	# And the table really is among what was counted, or the zero above would be
	# about a project with no effect art in it.
	check(FileAccess.file_exists(
		ProjectSettings.globalize_path("res://render/effect_art.gd")),
		"there is no effect table for the headless report to have skipped")


## The readout draws the fight and changes none of it: the same seed with and
## without it reaches the same world.
func _the_readout_changes_nothing_about_the_world() -> void:
	var without := _digest_of(_run_shell(["--scenario", Simulation.SCENARIO_ENCOUNTER]))
	var with_readout := _digest_of(_run_shell(["--readout", "--scenario",
		Simulation.SCENARIO_ENCOUNTER]))
	check(without != "", "the shell printed no world fingerprint")
	equal(with_readout, without,
		"the world the shell reached differed with the combat readout on screen")


# --- Helpers --------------------------------------------------------------


func _fighting_world() -> Simulation:
	var sim := Simulation.new(SEED)
	sim.begin_scenario(Simulation.SCENARIO_ENCOUNTER)
	for _tick in FIGHT_TICK:
		sim.step()
	return sim


static func _name_of(acting: Commander) -> String:
	if acting.sheet == null or acting.sheet.character_name == "":
		return "#%d" % acting.id
	return acting.sheet.character_name


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
	var args := ["--fixed-fps", str(FIXED_FPS), "--quit-after", str(FRAMES),
		"--", "--seed", str(SEED), "--no-grass", "--no-atmosphere"]
	args.append_array(extra)
	return _run(args, "")


func _run(args: Array, script: String) -> String:
	var full: Array = ["--headless", "--path",
		ProjectSettings.globalize_path("res://")]
	if script != "":
		full.append_array(["--script", script, "--"])
	full.append_array(args)
	var output: Array[String] = []
	OS.execute(OS.get_executable_path(), full, output, true)
	return "\n".join(output)
