extends SceneTree
## Why a pile on the ground cannot be seen: the three candidate reasons, each
## measured rather than argued.
##
##   ./tools/measure_ground_read.sh [--seed N] [--ticks N] [--scenario NAME]
##
## The second playtest photographed the `play` scenario at four cameras and found
## no frame with a pile in it, while the readout named a pile 0.4 units from the
## person. Three things could do that: the camera (the pile is off screen or
## behind something), the models' scale (the pile is drawn too small to be a
## pixel), or the placement (nothing is placed at all). This prints the numbers
## that separate them:
##
##   1. **The rows.** What `CombatantRoster.ground_rows()` says is lying where,
##      with each pile's distance from the person the camera follows.
##   2. **The placements.** What `GroundItems.placements()` makes of those rows:
##      one row per item to be drawn, or nothing, which would settle it as
##      placement before any picture is taken.
##   3. **The models.** Each placement's tag built through `AssetLibrary`, its
##      own size, the factor `GroundItems.scale_for` divides it by, and what that
##      leaves on screen -- in world units and in pixels at the shipping camera.
##
## Nothing here draws anything. Every number is read off the layer that owns it.

const DEFAULT_SEED := 1234
const DEFAULT_TICKS := 8
const DEFAULT_SCENARIO := "play"

## The window the game ships in, and the camera it ships with: what a pixel
## count has to be taken against. The camera is read off the shell rather than
## copied, so this cannot go on quoting a camera the game has stopped using.
const RenderShell := preload("res://render/main.gd")
const WINDOW_HEIGHT := 648.0
const SHIPPED_FOV := 75.0

## The camera this project shipped with until the character was measured at it,
## kept so that the two numbers can be printed side by side.
const WAS_OFFSET := Vector3(0.0, 42.0, 52.0)


func _initialize() -> void:
	var options := _parse(OS.get_cmdline_user_args())
	var sim := Simulation.new(int(options["seed"]))
	if not sim.begin_scenario(String(options["scenario"]), false, null):
		printerr("unknown scenario %s" % options["scenario"])
		quit(2)
		return
	for _i in int(options["ticks"]):
		sim.step()

	var snapshot := sim.world.snapshot()
	var observer := Vector3(
		snapshot["observer_x"], snapshot["observer_y"], snapshot["observer_z"])
	print("=== the run ===")
	print("  seed %d  scenario %s  tick %d" % [
		int(options["seed"]), options["scenario"], int(options["ticks"])])
	print("  observer at (%.2f, %.2f, %.2f)" % [observer.x, observer.y, observer.z])

	_the_rows(snapshot, observer)
	_the_placements(snapshot, observer, sim.world.terrain)
	quit()


## What the simulation says is lying on the ground, and how far it is from the
## person the camera is on.
func _the_rows(snapshot: Dictionary, observer: Vector3) -> void:
	print("=== the rows the simulation hands out ===")
	var combat: Dictionary = snapshot.get("combat", {})
	var rows: Array = combat.get("ground", [])
	if rows.is_empty():
		print("  none: the snapshot carries no ground rows at all")
		return
	for row in rows:
		var at := Vector3(float(row["x"]), float(row["y"]), float(row["z"]))
		var flat := Vector2(at.x - observer.x, at.z - observer.z).length()
		var items: Array = row.get("items", [])
		var names := PackedStringArray()
		for item in items:
			names.append("%s -> %s" % [
				item.get("name", "?"),
				"(nothing)" if String(item.get("model", "")) == ""
					else item.get("model")])
		print("  id=%d %-8s kind=%-6s shut=%s at=(%.2f, %.2f) %.2f from the person, %d item(s): %s" % [
			int(row["id"]), row["name"], row["kind"], row["shut"],
			at.x, at.z, flat, items.size(), ", ".join(names)])


## What the render layer makes of those rows, and how big each drawn thing ends
## up being on the screen.
func _the_placements(snapshot: Dictionary, observer: Vector3, terrain: TerrainQuery) -> void:
	print("=== the placements the render layer makes of them ===")
	var placements := GroundItems.placements(snapshot)
	print("  %d placement(s)" % placements.size())
	if placements.is_empty():
		print("  nothing is placed, so no camera and no model could have shown one")
		return
	var camera := observer + RenderShell.CAMERA_OFFSET
	var was := observer + WAS_OFFSET
	for row in placements:
		var at := Vector2(float(row["x"]), float(row["z"]))
		var tag := String(row["tag"])
		var visual := AssetLibrary.build(tag, terrain.profile_at(at.x, at.y))
		var built := "NOT BUILT"
		var drawn_span := 0.0
		if visual != null:
			get_root().add_child(visual)
			var box := _aabb(visual, Transform3D.IDENTITY)
			var factor := GroundItems.scale_for(box.size)
			drawn_span = maxf(box.size.x, maxf(box.size.y, box.size.z)) * factor
			built = "own size %.3f x %.3f x %.3f, factor %.4f, drawn %.3f tall" % [
				box.size.x, box.size.y, box.size.z, factor, box.size.y * factor]
			visual.queue_free()
		var flat := Vector2(at.x - observer.x, at.y - observer.z).length()
		var lying := Vector3(at.x, observer.y, at.y)
		var away := lying.distance_to(camera)
		var used_to_be := lying.distance_to(was)
		print("  key=%-6s tag=%-14s fallback=%s at=(%.2f, %.2f) %.2f from the person" % [
			row["key"], tag, row["fallback"], at.x, at.y, flat])
		print("      %s" % built)
		print("      %.1f units from the shipping camera -> %.1f px tall in a %d-px window" % [
			away, _pixels(drawn_span, away), int(WINDOW_HEIGHT)])
		print("      %.1f units from the camera this shipped with before -> %.1f px" % [
			used_to_be, _pixels(drawn_span, used_to_be)])


## How many pixels tall a thing of a given height is, that far from a camera of
## the shipped field of view, in the shipped window.
func _pixels(height: float, away: float) -> float:
	if away <= 0.0:
		return 0.0
	var half := tan(deg_to_rad(SHIPPED_FOV) * 0.5) * away * 2.0
	return WINDOW_HEIGHT * height / half


func _aabb(node: Node, so_far: Transform3D) -> AABB:
	var box := AABB()
	var started := false
	if node is VisualInstance3D:
		box = so_far * (node as VisualInstance3D).get_aabb()
		started = true
	for child in node.get_children():
		if not (child is Node3D):
			continue
		var below := _aabb(child, so_far * (child as Node3D).transform)
		if below.size == Vector3.ZERO:
			continue
		box = below if not started else box.merge(below)
		started = true
	return box


func _parse(args: PackedStringArray) -> Dictionary:
	var options := {
		"seed": DEFAULT_SEED, "ticks": DEFAULT_TICKS,
		"scenario": DEFAULT_SCENARIO,
	}
	var i := 0
	while i < args.size():
		match args[i]:
			"--seed":
				options["seed"] = args[i + 1].to_int()
				i += 1
			"--ticks":
				options["ticks"] = args[i + 1].to_int()
				i += 1
			"--scenario":
				options["scenario"] = args[i + 1]
				i += 1
		i += 1
	return options
