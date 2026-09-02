extends SceneTree
## Standalone structure checks: exits 0 when the simulation layer is clean, 1
## when it has started to reference the render layer or to name art.
##
## Run it with:  ./run_tests.sh --layers-only
##
## Four rules. The layer check says the simulation must not know the render
## layer exists -- not its files, not its types, and since the character sheet
## landed not the vocabulary of an interface either: no Control, no CanvasLayer,
## no Theme, no font. The combat check says the render layer, which may read the
## simulation, must not hold a piece of the fight -- it draws what a snapshot
## says and keeps nothing. The asset check says the simulation must not know what
## anything looks like: it names tags, and the render layer's table turns a tag
## into a model. The interface check covers the directory the player-facing
## interface lives in, render/ui/: the art it is drawn from is named in one table
## and nowhere else, and nothing in it reaches for the engine's own theme or
## typeface, which is the silent way a pixel interface ends up half grey. The
## same rules run inside the test suite; this entry point exists so all four can
## be wired into a commit hook or a build without running it.


func _initialize() -> void:
	var failed := false

	var layer_violations := LayerCheck.run()
	if layer_violations.is_empty():
		print("layer check: OK -- %s references nothing in the render layer" % LayerCheck.SIM_DIR)
	else:
		failed = true
		printerr("layer check: FAILED -- the simulation layer must not know about the render layer")
		for violation in layer_violations:
			printerr("  " + LayerCheck.format_violation(violation))

	var render_violations := LayerCheck.run_render()
	if render_violations.is_empty():
		print("combat check: OK -- %s draws the fight and holds none of it"
			% LayerCheck.RENDER_DIR)
	else:
		failed = true
		printerr("combat check: FAILED -- the render layer must not hold combat state")
		for violation in render_violations:
			printerr("  " + LayerCheck.format_render_violation(violation))

	var ui_violations := LayerCheck.run_ui()
	if ui_violations.is_empty():
		print("interface check: OK -- %s names its art through %s alone"
			% [LayerCheck.UI_DIR, LayerCheck.UI_TABLE.get_file()])
	else:
		failed = true
		printerr("interface check: FAILED -- the interface must name its art in one"
			+ " table and never fall back to the engine's own look")
		for violation in ui_violations:
			printerr("  " + LayerCheck.format_ui_violation(violation))

	var asset_violations := AssetCheck.run()
	if asset_violations.is_empty():
		print("asset check: OK -- %s names asset tags and no asset" % AssetCheck.SIM_DIR)
	else:
		failed = true
		printerr("asset check: FAILED -- generation must name tags, never scenes, paths or packs")
		for violation in asset_violations:
			printerr("  " + AssetCheck.format_violation(violation))

	quit(1 if failed else 0)
