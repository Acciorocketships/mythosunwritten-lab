extends RefCounted
## The fourth mapping table: effect tag -> what it looks like *flying through
## the world*, as a body between two cells of the board.
##
## `render/asset_library.gd` answers "what does a fir look like" for what stands
## in the world; `render/effect_art.gd` answers the same question for the combat
## readout, where an effect is a sixteen-pixel sprite inside a panel; this file
## answers it for the board itself, where an arrow is a thing in the air between
## the cell it left and the cell it landed on. The two effect tables share their
## vocabulary -- `AssetTags.EFFECT_SPRITES`, the same six names the simulation
## puts on a blow -- and deliberately do not share their rows: a row here is a
## three-dimensional body and a row there is sixteen lines of pixels, and there
## is no piece of either that could stand in for the other. What they share is
## the tag, which is the point of tags.
##
## One row per effect tag, and every row has the same four fields, so the
## builder never asks which weapon's effect it is building:
##
##   model  -- a file of the pack's, for a tag the packs ship a literal body
##             for. The adventurer pack ships the arrow an arrow is.
##   colour -- what the body is painted or what it glows, for a row with no
##             model.
##   glow   -- whether the body is a light rather than a thing: what makes a
##             magic bolt read as magic beside an arrow that reads as wood.
##   size   -- how large the built body is along and across its flight, in
##             world units.
##
## The simulation never reaches this file. A blow says `arrow` or `bolt`; what
## either looks like crossing the board is decided here and nowhere else,
## exactly as what a `blade` looks like in the readout is `EffectArt`'s.
class_name FlightArt

## Where the pack's literal arrow lives. Named once, like the clip files in
## `render/character_rig.gd` are: a render-side table is allowed to know which
## files its art is in, and being the one place that does is what it is for.
const ARROW_MODEL := "res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Assets/gltf/arrow_bow.gltf"

## Every body a flight can wear, one row per effect tag the simulation can put
## on a blow. The three tags whose attacks actually travel today (arrow, bolt,
## flame) and the three that today only ever land instantly (blade, point,
## impact) all have rows, for the same reason all seven motions have clips:
## an attack composed tomorrow with any of the six must resolve to something,
## and which something is a row here and not a branch anywhere.
const BODIES := {
	AssetTags.EFFECT_ARROW: {
		"model": ARROW_MODEL, "colour": Color(0.85, 0.75, 0.55),
		"glow": false, "size": Vector3(0.16, 0.16, 1.26),
	},
	AssetTags.EFFECT_BOLT: {
		"model": "", "colour": Color(0.62, 0.42, 1.0),
		"glow": true, "size": Vector3(0.34, 0.34, 1.1),
	},
	AssetTags.EFFECT_FLAME: {
		"model": "", "colour": Color(1.0, 0.5, 0.12),
		"glow": true, "size": Vector3(0.55, 0.55, 0.8),
	},
	AssetTags.EFFECT_POINT: {
		"model": "", "colour": Color(0.62, 0.64, 0.68),
		"glow": false, "size": Vector3(0.12, 0.12, 0.9),
	},
	AssetTags.EFFECT_BLADE: {
		"model": "", "colour": Color(0.72, 0.74, 0.78),
		"glow": false, "size": Vector3(0.5, 0.06, 0.5),
	},
	AssetTags.EFFECT_IMPACT: {
		"model": "", "colour": Color(1.0, 0.92, 0.55),
		"glow": true, "size": Vector3(0.45, 0.45, 0.45),
	},
}

## What a tag with no row above flies as instead: a bright, plainly unauthored
## spark.
##
## An attack whose tag this table has never heard of still crossed the board,
## and the one thing it must not look like is nothing at all -- a character
## losing hit points to an invisible projectile is a bug that reads as a missing
## feature. A hot magenta glow is the honest fallback: it is plainly something
## flying, and plainly not a body anybody drew for the attack. Nothing shipped
## reaches it -- all six tags of the simulation's effect vocabulary have a row,
## and `tools/measure_flights.sh` counts how many of the shipped attacks fall
## through to this: today that number is zero.
const FALLBACK_BODY := {
	"model": "", "colour": Color(1.0, 0.2, 0.9),
	"glow": true, "size": Vector3(0.5, 0.5, 0.5),
}

# Loaded pack scenes, one each, on first ask -- the same little cache
# `EffectArt._made` is, for the same reason: a volley asks for the same arrow
# every time.
static var _loaded := {}


## Whether there is a body drawn (or named) for a tag.
static func has_body(tag: String) -> bool:
	return BODIES.has(tag)


## The row for a tag, falling back to the spark for one this table does not
## know. Never empty, so a caller holding a strange tag builds something
## visible rather than nothing.
static func body_row(tag: String) -> Dictionary:
	return BODIES.get(tag, FALLBACK_BODY)


## The body for an effect tag, built and ready to fly. Never null.
##
## Every body comes back with its flight axis along its own -Z, which is the
## direction `FlightView` points at the landing cell. The pack's arrow is
## authored with its head along +Z -- measured off the mesh: the fletching's
## fins are the wide end and they sit at -Z -- so a model is mounted in a
## holder turned half way round, and a built lozenge is simply longest in z.
static func build(tag: String) -> Node3D:
	var row := body_row(tag)
	var path := String(row.get("model", ""))
	if path != "":
		var packed: PackedScene = _loaded.get(path, null)
		if packed == null:
			packed = load(path)
			_loaded[path] = packed
		if packed != null:
			var holder := Node3D.new()
			holder.name = tag
			var model: Node3D = packed.instantiate()
			model.rotation.y = PI
			holder.add_child(model)
			return holder
		# A row that names a file that will not load is a broken row, and a
		# broken row must still be something visible: fall through to the spark.
		row = FALLBACK_BODY
	var body := MeshInstance3D.new()
	body.name = tag
	var size := row.get("size", Vector3.ONE) as Vector3
	var colour := row.get("colour", Color.WHITE) as Color
	var material := StandardMaterial3D.new()
	if bool(row.get("glow", false)):
		# A light rather than a thing: unshaded so no sun is needed to see it,
		# and emissive so the bloom pass picks it up like the window glow.
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		body.mesh = mesh
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 2.0
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		body.mesh = mesh
		material.roughness = 1.0
	material.albedo_color = colour
	body.material_override = material
	body.scale = size
	return body


## Every effect tag this table has a row for, in the order the simulation lists
## them. What a test walks and what a report tabulates.
static func tags() -> PackedStringArray:
	var found := PackedStringArray()
	for tag in AssetTags.EFFECT_SPRITES:
		if BODIES.has(tag):
			found.append(tag)
	return found


## Any tag of the effect vocabulary this table has no row for. Empty, and
## checked rather than assumed by `tests/test_flights.gd`.
static func missing_tags() -> PackedStringArray:
	var absent := PackedStringArray()
	for tag in AssetTags.EFFECT_SPRITES:
		if not BODIES.has(tag):
			absent.append(tag)
	return absent


## Any row here that names a tag the vocabulary does not contain. Empty, and
## checked: a row nothing can ask for is art that will never fly.
static func unknown_rows() -> PackedStringArray:
	var strange := PackedStringArray()
	for tag in BODIES:
		if not AssetTags.is_effect_sprite(tag):
			strange.append(String(tag))
	return strange
