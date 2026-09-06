extends Node3D
## Randomly generated items, one row per rarity tier, each labelled with the name
## it resolved through -- so what a tier looks like can be judged rather than
## described.
##
## This is a contact sheet and not part of the game. Nothing is standing where
## the world says anything belongs and the simulation is not running behind it;
## what is on screen is `ItemForge` output, resolved through `ItemModel` into a
## name and through the render layer's table into a model, which is the whole of
## the chain this sheet exists to show.
##
## Run it with:  ./run_item_sheet.sh [--screenshot path.png] [--seed N]
##
## ## How a tier gets a row
##
## The forge draws its own rarity -- half of everything it makes is common and
## one in a hundred is eternal -- so a sheet cannot ask for an eternal item. It
## forges through source labels in order, keeps the first `PER_TIER` items of
## each tier, and stops when every row is full. So every item here is one the
## forge really produced, at the seed named on the sheet, and the eternal row is
## rare gear rather than a common item relabelled.
##
## Held and worn items are forged alternately, so a row shows both what a tier
## puts in a hand and what it puts on a back.
##
## ## The pile
##
##     ./run_item_sheet.sh --pile
##
## A second picture out of the same scene, and not a rarity sheet at all: `PILE`
## forged items laid out by the same `GroundItems.spread()` the shell lays a heap
## out with, seen from above. It is what "a pile of several is legible rather
## than a single overlapping heap" looks like, so the claim can be looked at
## instead of taken on the word of a minimum-separation measurement.
##
## Items and offsets are magnified by the *same* factor, so the ratio between an
## item and the gap to its neighbour is exactly the ratio in the world -- which
## is the only thing legibility depends on -- at a size a screenshot can show.

## How many items each rarity tier shows.
const PER_TIER := 6

## How many items the pile picture holds.
const PILE := 8

## How much bigger than life the sheet draws everything: the items, and the
## spread of the pile alike.
const MAGNIFIED := 4.0

## How far apart the cells sit, in world units, and how far the rows are apart.
const CELL := Vector2(5.8, 5.4)

## The level every item on the sheet is forged at.
##
## One level for the whole sheet on purpose: an item's power is its rarity times
## the level of whatever dropped it, so holding the level still is what makes a
## row-to-row difference a difference of *tier*. Eight is high enough that even a
## common item has a budget worth dividing.
const LEVEL := 8

## The seed the sheet is forged from, and how many sources it will try before
## giving up on filling a row.
const SEED := 20260905
const TRIES := 4000

## Which biome's colours the sheet is drawn in. One biome for the whole sheet, so
## a difference between two cells is a difference between two items.
const SHEET_BIOME := BiomeCatalog.MEADOW

var _frames := 0
var _screenshot_path := ""
var _screenshot_frame := 30
var _seed := SEED
var _pile_only := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			_screenshot_path = args[i + 1]
		if args[i] == "--screenshot-frame" and i + 1 < args.size() \
				and args[i + 1].is_valid_int():
			_screenshot_frame = args[i + 1].to_int()
		if args[i] == "--seed" and i + 1 < args.size() and args[i + 1].is_valid_int():
			_seed = args[i + 1].to_int()
		if args[i] == "--pile":
			_pile_only = true

	var profile := BiomeCatalog.profile(SHEET_BIOME)
	if _pile_only:
		_build_pile_stage(profile)
		_add_a_pile(profile)
		print("item sheet: seed=%d level=%d one pile of %d, spacing %.2f, span %.2f"
			% [_seed, LEVEL, PILE, GroundItems.SPACING, GroundItems.DRAWN_SPAN])
		return
	var by_tier := _forge_a_row_per_tier()
	var span := Vector2(
		(PER_TIER - 1) * CELL.x, (ItemRarity.TIERS.size() - 1) * CELL.y
	)
	_build_stage(profile, span)

	var fallbacks := 0
	for row in ItemRarity.TIERS.size():
		var tier: String = ItemRarity.TIERS[row]
		var items: Array = by_tier[tier]
		_add_label("%s  x%d" % [tier, items.size()],
			Vector3(-span.x * 0.5 - CELL.x * 0.75, 1.4, row * CELL.y - span.y * 0.5),
			64, Color(0.08, 0.08, 0.10))
		for column in items.size():
			var item: Item = items[column]
			var tag := ItemModel.of(item)
			if tag == ItemModel.NOTHING:
				tag = GroundItems.FALLBACK_TAG
				fallbacks += 1
			var at := Vector3(
				column * CELL.x - span.x * 0.5,
				0.0,
				row * CELL.y - span.y * 0.5,
			)
			_add_item(item, tag, at, profile)

	print("item sheet: seed=%d level=%d %d tiers x %d, %d through the fallback" % [
		_seed, LEVEL, ItemRarity.TIERS.size(), PER_TIER, fallbacks,
	])
	for tier in ItemRarity.TIERS:
		for item in by_tier[tier]:
			print("  %-42s %s" % [ItemModel.of(item), item.line()])


func _process(_delta: float) -> void:
	_frames += 1
	if _screenshot_path != "" and _frames >= _screenshot_frame:
		var path := _screenshot_path
		_screenshot_path = ""
		_save_screenshot(path)


## Forge through source labels in order, keeping the first `PER_TIER` of each
## tier. What the forge produced, not what the sheet wanted.
func _forge_a_row_per_tier() -> Dictionary:
	var by_tier := {}
	for tier in ItemRarity.TIERS:
		by_tier[tier] = []
	var filled := 0
	for index in TRIES:
		var of_kind := Item.KIND_ARMOUR if index % 2 == 1 else Item.KIND_WEAPON
		var item := ItemForge.forge(_seed, "sheet#%d" % index, LEVEL, of_kind)
		var row: Array = by_tier[item.rarity]
		if row.size() >= PER_TIER:
			continue
		row.append(item)
		if row.size() == PER_TIER:
			filled += 1
			if filled == ItemRarity.TIERS.size():
				break
	return by_tier


## One heap of `PILE` forged items, laid out by the shell's own `spread()`, at
## the sheet's magnification.
##
## Nothing here decides where anything goes. The offsets are `GroundItems`', the
## items are the forge's, and the only thing the sheet does is multiply both by
## the same number so the heap is big enough to photograph.
func _add_a_pile(profile: BiomeProfile) -> void:
	var middle := Vector3.ZERO
	for index in PILE:
		var item := ItemForge.forge(_seed, "pile#%d" % index, LEVEL, (
			Item.KIND_ARMOUR if index % 2 == 1 else Item.KIND_WEAPON
		))
		var tag := ItemModel.of(item)
		if tag == ItemModel.NOTHING:
			tag = GroundItems.FALLBACK_TAG
		var offset := GroundItems.spread(index) * MAGNIFIED
		var built := AssetLibrary.build(tag, profile)
		if built == null:
			continue
		add_child(built)
		var box := _bounds_of(built, Transform3D.IDENTITY)
		var factor := GroundItems.scale_for(box.size) * MAGNIFIED
		built.scale = Vector3.ONE * factor
		built.rotation.y = float(index) * GroundItems.GOLDEN_ANGLE
		built.position = middle + Vector3(offset.x, -box.position.y * factor, offset.y)
		_add_label("%d  %s" % [index, tag],
			built.position + Vector3(0.0, 0.05, GroundItems.SPACING * MAGNIFIED * 0.62),
			30, Color(0.10, 0.10, 0.12))


## One cell: the item as the table draws it, standing on the ground, with what it
## is and which name it went through written under it.
func _add_item(item: Item, tag: String, at: Vector3, profile: BiomeProfile) -> void:
	var built := AssetLibrary.build(tag, profile)
	if built == null:
		push_error("item sheet: '%s' would not build" % tag)
		return
	add_child(built)
	var box := _bounds_of(built, Transform3D.IDENTITY)
	# The same normalisation the shell makes, scaled up so the sheet is readable:
	# every cell shows a thing of the same size, whatever pack it came from.
	var factor := GroundItems.scale_for(box.size) * MAGNIFIED
	built.scale = Vector3.ONE * factor
	built.position = at - Vector3(0.0, box.position.y * factor, 0.0)

	_add_label(item.item_name, at + Vector3(0.0, 0.05, CELL.y * 0.20), 40,
		Color(0.10, 0.10, 0.12))
	_add_label(tag, at + Vector3(0.0, 0.05, CELL.y * 0.32), 36,
		Color(0.22, 0.30, 0.46))
	_add_label("P=%d  mov=%d def=%d eff=%d" % [
		item.budget(), item.movement, item.defence, item.effects_power(),
	], at + Vector3(0.0, 0.05, CELL.y * 0.44), 28, Color(0.30, 0.30, 0.32))


## The box a built visual occupies in its own frame. The same measurement the
## shell makes for the same reason: the packs do not agree on which axis a thing
## is long along.
func _bounds_of(node: Node, so_far: Transform3D) -> AABB:
	var box := AABB()
	var started := false
	if node is VisualInstance3D:
		box = so_far * (node as VisualInstance3D).get_aabb()
		started = true
	for child in node.get_children():
		if not (child is Node3D):
			continue
		var below := _bounds_of(child, so_far * (child as Node3D).transform)
		if below.size == Vector3.ZERO:
			continue
		box = below if not started else box.merge(below)
		started = true
	return box


## The stage the pile picture stands on: the same ground and light, seen from
## almost directly above, because a heap's *spread* is what the picture is of and
## a low camera hides the far half of it behind the near half.
func _build_pile_stage(profile: BiomeProfile) -> void:
	var reach := GroundItems.SPACING * MAGNIFIED * sqrt(float(PILE)) + 2.0
	_build_stage(profile, Vector2(reach * 2.0, reach * 2.0))
	for child in get_children():
		if child is Camera3D:
			(child as Camera3D).size = reach * 3.3
			(child as Camera3D).position = Vector3(0.0, 40.0, 14.0)
			(child as Camera3D).look_at_from_position(
				Vector3(0.0, 40.0, 14.0), Vector3.ZERO, Vector3.UP)


## The ground, the light and the air the sheet stands in: the same cool-ambient,
## warm-key setup the world uses, so steel reads here the way it will read there.
func _build_stage(profile: BiomeProfile, span: Vector2) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(span.x + CELL.x * 2.6, span.y + CELL.y * 1.6)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = profile.ground_tint
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	add_child(ground)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	light.light_energy = 1.15
	light.light_color = Color(1.0, 0.94, 0.82)
	light.shadow_enabled = true
	add_child(light)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = profile.sky_top
	sky_material.sky_horizon_color = profile.sky_horizon
	sky_material.ground_horizon_color = profile.sky_horizon
	sky_material.ground_bottom_color = profile.fog_color
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = profile.ambient_color
	environment.ambient_light_energy = 0.75
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.15
	world_environment.environment = environment
	add_child(world_environment)

	# Orthogonal, so every cell is the same size on screen and the back row is
	# not a set of smaller items.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = maxf((span.x + CELL.x * 2.6) * 1.03, (span.y + CELL.y) * 1.24)
	camera.near = 0.1
	camera.far = 500.0
	camera.position = Vector3(0.0, 46.0, 40.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.6, 0.0), Vector3.UP)
	add_child(camera)


func _add_label(text: String, at: Vector3, size: int, tint: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.010
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = tint
	label.outline_size = 0
	label.position = at
	label.no_depth_test = true
	add_child(label)


func _save_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("item sheet: screenshot %s" % path)
	else:
		printerr("item sheet: screenshot failed (%d) for %s" % [error, path])
	get_tree().quit(0 if error == OK else 1)
