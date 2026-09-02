extends TestSuite
## The layer split is a deliverable, so it is tested like one.
##
## Three rules are checked, and each of them twice: that it holds right now, and
## that the checker would actually notice if it stopped holding -- a check that
## can never fail is worth nothing. The rules are the simulation not knowing the
## render layer exists, the render layer holding no piece of the fight, and the
## interface naming its art in one table and never falling back to the engine's
## own theme or typeface.
class_name TestLayering


func _init() -> void:
	suite_name = "layering"


func run() -> void:
	_simulation_layer_is_clean()
	_checker_catches_a_reference()
	_checker_reads_real_files()
	_render_layer_holds_no_combat_state()
	_combat_checker_catches_a_held_piece()
	_interface_names_its_art_in_one_table()
	_interface_checker_catches_a_default()


func _simulation_layer_is_clean() -> void:
	var violations := LayerCheck.run()
	var report := PackedStringArray()
	for violation in violations:
		report.append(LayerCheck.format_violation(violation))
	check(violations.is_empty(),
		"sim/ references the render layer:\n      %s" % "\n      ".join(report))


func _checker_catches_a_reference() -> void:
	# The rules, exercised directly on lines of source that do not exist on disk.
	var offending_lines := [
		"var scene = preload(\"res://render/main.tscn\")",
		"const MAIN = \"render/main.gd\"",
		"var view: MeshInstance3D = null",
		"func _process(delta: float) -> void:",
		"get_tree().quit()",
	]
	for line in offending_lines:
		not_equal(LayerCheck._first_match(line), "",
			"the checker should have flagged: %s" % line)

	var innocent_lines = [
		"var mote_speed: Array[float] = []",
		"# the render layer reads res://render/main.tscn, this comment must not trip it",
		"func step() -> void:",
		"var meshless_count := 0",
		"self._process_order = 1",
	]
	for line in innocent_lines:
		equal(LayerCheck._first_match(LayerCheck._strip_comment(line)), "",
			"the checker should not have flagged: %s" % line)


func _checker_reads_real_files() -> void:
	# Guard against the check silently passing because it found nothing to scan.
	var files := LayerCheck._files_under(LayerCheck.SIM_DIR)
	check(files.size() >= 3,
		"expected the checker to find the simulation sources, found %d file(s)" % files.size())
	var drawn := LayerCheck._files_under(LayerCheck.RENDER_DIR)
	check(drawn.size() >= 3,
		"expected the checker to find the render sources, found %d file(s)" % drawn.size())


## The render layer draws the fight and holds none of it.
##
## The shell reads combat through `SimWorld.snapshot()` and through a detached
## `CombatBoard`, and there is nothing else of the combat layer it may name. This
## is the structural half of "the render layer holds no piece of combat state of
## its own"; the behavioural half -- that throwing the shell's view bookkeeping
## away and rebuilding it from the same snapshot draws the identical picture --
## is in tests/test_combat_snap.gd.
func _render_layer_holds_no_combat_state() -> void:
	var violations := LayerCheck.run_render()
	var report := PackedStringArray()
	for violation in violations:
		report.append(LayerCheck.format_render_violation(violation))
	check(violations.is_empty(),
		"render/ holds combat state:\n      %s" % "\n      ".join(report))


func _combat_checker_catches_a_held_piece() -> void:
	var offending_lines := [
		"var _match: CombatMatch = null",
		"_pieces = PieceMap.new()",
		"var moves = LegalMoves.moves_for(board, pieces, piece)",
		"if piece is Commander:",
		"ScriptedEncounter.muster(_sim.world)",
	]
	for line in offending_lines:
		not_equal(LayerCheck.first_combat_match(line), "",
			"the combat checker should have flagged: %s" % line)

	# The two handles the shell is allowed, and an ordinary render-layer line.
	var innocent_lines = [
		"var board := _sim.world.combat_board()",
		"var rows := CombatDiorama.placements(snapshot)",
		"var tint := BOARD_CLIFF",
		"if board.is_cliff_edge(cell):",
		"_sim.begin_scenario(scenario)",
	]
	for line in innocent_lines:
		equal(LayerCheck.first_combat_match(LayerCheck._strip_comment(line)), "",
			"the combat checker should not have flagged: %s" % line)


## The interface names the pack in one file, and reaches for no default look.
##
## Two ways a pixel interface goes quietly wrong, and this is the structural half
## of both. A widget that never gets a style still draws -- in the engine's grey
## -- so "the panel is drawn from the pack and from no engine default" cannot be
## checked by looking at whether it drew. The other half is measured rather than
## read: tools/measure_ui.sh counts the colours in a real frame of the panel
## against the pack's own palette, and reports/ui.md has that table.
func _interface_names_its_art_in_one_table() -> void:
	var files := LayerCheck._files_under(LayerCheck.UI_DIR)
	check(files.size() >= 3,
		"expected the checker to find the interface sources, found %d file(s)"
		% files.size())
	var violations := LayerCheck.run_ui()
	var report := PackedStringArray()
	for violation in violations:
		report.append(LayerCheck.format_ui_violation(violation))
	check(violations.is_empty(),
		"render/ui/ names art outside its table:\n      %s" % "\n      ".join(report))


func _interface_checker_catches_a_default() -> void:
	var offending_lines := [
		"var font := ThemeDB.fallback_font",
		"label.add_theme_font_override(\"font\", get_theme_default_font())",
		"var sheet := load(\"res://assets/sprout_lands_ui/icons.png\")",
		"const FRAME := \"assets/sprout_lands_ui/ui_sheet.png\"",
	]
	for line in offending_lines:
		not_equal(LayerCheck.first_ui_match(line), "",
			"the interface checker should have flagged: %s" % line)

	# Ordinary interface lines, and the table's own right to name its files.
	var innocent_lines := [
		"var frame := SproutPack.region(SproutPack.SHEET, SproutPack.FRAME)",
		"theme.set_font(\"font\", \"Label\", font)",
		"_name.text = sheet.character_name",
	]
	for line in innocent_lines:
		equal(LayerCheck.first_ui_match(LayerCheck._strip_comment(line)), "",
			"the interface checker should not have flagged: %s" % line)
	equal(LayerCheck.first_ui_match(
		"const SHEET := ROOT + \"ui_sheet.png\"", LayerCheck.UI_TABLE), "",
		"the table itself must be allowed to name the pack's files")
