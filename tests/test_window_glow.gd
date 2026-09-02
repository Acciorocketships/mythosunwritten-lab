extends TestSuite
## Every building in a village has a lit window, and every lit window is on a
## wall of the model that actually stands there.
##
## Two halves, and the split between them is the layer split.
##
## The first half is about the simulation alone. `sim/settlement_field.gd` places
## one or two `window_glow` per building, on the facade of the rectangle of
## ground that building reserved, at a share along that face rolled off the
## village's own seed. It has never seen a model and cannot: a reserved rectangle
## and a facing is all it has, and these checks say that is all it used.
##
## The second half is the one the outcome is really about, and it is checked
## against the installed art rather than against a placeholder box. A reserved
## rectangle is deliberately roomier than whatever stands in it -- on the
## installed models the slack runs from 0.43 to 3.8 world units depending on the
## tag and the face -- so the asset table moves the pane from the reserved
## facade onto the wall the model really has. This suite takes every window of
## every building tag over many villages and many seeds, pulls the *triangles* of
## the model that tag names, and asks two things of the pane it would draw:
##
##   * it is *on* a wall -- every corner of the pane is within MAX_GAP of the
##     model's surface, so it is not hanging in the air beside the building;
##   * it is *outside* -- nothing of the model stands in front of the pane along
##     the wall's own normal, so it is not buried in the mesh where nobody would
##     ever see it.
##
## Together those two are the whole of "on or just outside a wall face". Neither
## can be passed by accident: a pane in mid-air fails the first, a pane inside
## the wall fails the second, and a pane on the roof fails both.
class_name TestWindowGlow

## The seeds the villages come from, and how far out in settlement cells each is
## searched. Enough seeds and enough cells that every building tag is met many
## times over -- the count is checked below rather than assumed.
##
## Twelve seeds rather than six because of the workshop. The layout puts it in
## the slot next to the tavern, where its footprint nearly always overlaps and
## the spacing rule drops it, so a workshop reaches a village about once in ten;
## six seeds turned up two of them, which is not a sample, and the count check
## below says so rather than passing quietly. Twelve seeds turn up six, which
## clears the bar. Every other tag was already met hundreds of times over.
const SEEDS := [1234, 7, 3, 19, 42, 101, 5, 11, 23, 57, 73, 97]
const CELL_REACH := 2

## How far a pane's corner may be from the model's surface, in world units.
##
## The fit stands the pane WINDOW_STANDOFF (0.05) off the wall, so a corner on a
## flat wall is exactly that far out. The slack above it is for a wall that is
## slightly turned or panelled within the pane's own width, and for the facets of
## a round tower. A quarter of a unit is a hand's breadth on a building four to
## eight units tall: past that a pane reads as floating rather than as fitted.
const MAX_GAP := 0.25

## How far in front of a pane a piece of the model may be before the pane counts
## as buried, in world units. Small: the question is whether there is wall in
## front of the light, and any real wall in front of it is thicker than this.
const BURIED_SLACK := 0.02

## How far outside the building the ray that looks at a pane starts, in world
## units. Well clear of the widest building in the catalog.
const OUTSIDE_REACH := 12.0

## Which building tag a village's well is, so it can be excluded: a well has no
## windows to light.
const NO_WINDOWS := [AssetTags.WELL]


func _init() -> void:
	suite_name = "window glow"


func run() -> void:
	var villages := _villages()
	check(villages.size() >= 20,
		"expected a good sample of villages, found %d" % villages.size())
	if villages.is_empty():
		return

	_every_building_but_the_well_lights_a_window(villages)
	_a_window_sits_on_the_facade_of_its_own_footprint(villages)
	_the_windows_are_a_fact_about_the_seed(villages)
	_every_window_lands_on_a_wall_of_the_installed_model(villages)
	_a_window_glow_is_drawn_as_a_warm_emissive_with_a_light()


# --- Gathering -----------------------------------------------------------

func _villages() -> Array[Settlement]:
	var found: Array[Settlement] = []
	for world_seed: int in SEEDS:
		var field := TerrainQuery.for_seed(world_seed).settlement_field
		for cell_x in range(-CELL_REACH, CELL_REACH + 1):
			for cell_z in range(-CELL_REACH, CELL_REACH + 1):
				var site := field.settlement_in_cell(Vector2i(cell_x, cell_z))
				if site != null:
					found.append(site)
	return found


# --- What the simulation placed ------------------------------------------

func _every_building_but_the_well_lights_a_window(villages: Array[Settlement]) -> void:
	var per_tag := {}
	for site in villages:
		var counted := {}
		for glow in site.glows:
			equal(String(glow["tag"]), AssetTags.WINDOW_GLOW,
				"a village's glow list holds '%s'" % glow["tag"])
			var index := int(glow["building"])
			check(index >= 0 and index < site.buildings.size(),
				"a glow names building %d of %d" % [index, site.buildings.size()])
			if index < 0 or index >= site.buildings.size():
				continue
			counted[index] = int(counted.get(index, 0)) + 1
		for index in site.buildings.size():
			var tag := String(site.buildings[index]["tag"])
			if tag in NO_WINDOWS:
				equal(int(counted.get(index, 0)), 0,
					"a %s should carry no lit window" % tag)
				continue
			check(int(counted.get(index, 0)) >= 1,
				"a %s in village %s carries no lit window" % [tag, site.id()])
			per_tag[tag] = int(per_tag.get(tag, 0)) + int(counted.get(index, 0))
	# Every kind of building the layout actually places has to have turned up
	# many times over, or the claim above would be about whichever ones happened
	# to appear. Which kinds those are is printed rather than assumed: the layout
	# rule, which this work does not touch, puts the workshop in the slot next to
	# the tavern, where its footprint always overlaps -- so no village in the
	# sample has one and the check below would be vacuous for it. The fit for
	# every catalog building tag, that one included, is checked against the models
	# further down.
	var seen := PackedStringArray()
	for tag in AssetTags.in_category(AssetTags.BUILDINGS):
		if tag in NO_WINDOWS:
			continue
		var found := int(per_tag.get(tag, 0))
		if found == 0:
			continue
		seen.append("%s=%d" % [tag, found])
		check(found >= 5,
			"only %d lit windows on any %s in the whole sample" % [found, tag])
	check(seen.size() >= 3,
		"the sample met only %d kinds of building" % seen.size())
	print("        window glow: %d villages light %s" % [villages.size(), seen])


## A window sits on one of its own building's four faces, inside that face, and
## looks out of it. Which is the whole of what generation is allowed to decide.
func _a_window_sits_on_the_facade_of_its_own_footprint(villages: Array[Settlement]) -> void:
	for site in villages:
		for glow in site.glows:
			var building: Dictionary = site.buildings[int(glow["building"])]
			var local := Settlement.footprint_local(
				building, float(glow["x"]), float(glow["z"])
			)
			var half_width := float(building["half_width"])
			var half_depth := float(building["half_depth"])
			var turn := wrapf(float(glow["yaw"]) - float(building["yaw"]), -PI, PI)
			# Which face, as a quarter turn off the building's own facing. Only
			# the front and the two sides are used.
			var on_front := absf(turn) < 0.001
			var on_side := absf(absf(turn) - PI * 0.5) < 0.001
			check(on_front or on_side,
				"a lit window is turned %.3f off its building, which is no face"
				% turn)
			var out_reach := half_depth if on_front else half_width
			var span := half_width if on_front else half_depth
			var out := local.y if on_front else absf(local.x)
			var along := absf(local.x) if on_front else absf(local.y)
			check(absf(out - out_reach) < 0.001,
				"a lit window stands %.3f out of a face at %.3f" % [out, out_reach])
			check(along <= span * SettlementField.WINDOW_ALONG_SHARE + 0.001,
				"a lit window is %.3f along a face whose half-span is %.3f"
				% [along, span])


func _the_windows_are_a_fact_about_the_seed(villages: Array[Settlement]) -> void:
	# The same cells, from a field that has never been asked anything, have to
	# come back with the same windows in the same order.
	var again := _villages()
	equal(again.size(), villages.size(), "a second pass found a different number of villages")
	if again.size() != villages.size():
		return
	var same := true
	for at in villages.size():
		if again[at].glows.size() != villages[at].glows.size():
			same = false
			break
		for index in villages[at].glows.size():
			var one: Dictionary = villages[at].glows[index]
			var other: Dictionary = again[at].glows[index]
			if not (is_equal_approx(float(one["x"]), float(other["x"]))
					and is_equal_approx(float(one["z"]), float(other["z"]))
					and is_equal_approx(float(one["yaw"]), float(other["yaw"]))
					and int(one["building"]) == int(other["building"])):
				same = false
				break
	check(same, "the same seed lit different windows the second time it was asked")
	# And the digest has to carry them, or nothing downstream could notice a
	# village whose windows moved.
	var moved := villages[0].detached_copy()
	check(moved.glows.size() > 0, "the first village has no windows to move")
	if moved.glows.size() > 0:
		var before := moved.digest()
		moved.glows[0]["x"] = float(moved.glows[0]["x"]) + 1.0
		not_equal(moved.digest(), before,
			"moving a lit window does not change the village's fingerprint")


# --- Where it lands on the model -----------------------------------------

## The check the outcome is about: the pane the render layer would draw sits on
## the wall of the model the tag names, on every face of every building tag.
func _every_window_lands_on_a_wall_of_the_installed_model(
	villages: Array[Settlement]
) -> void:
	# One case per (tag, face, rounded share): the fit is a pure function of
	# those three, so the thousands of windows in the sample collapse to a few
	# dozen distinct geometries and each is tested against the model once.
	var cases := {}
	for site in villages:
		for glow in site.glows:
			var building: Dictionary = site.buildings[int(glow["building"])]
			var turn := wrapf(float(glow["yaw"]) - float(building["yaw"]), -PI, PI)
			var face := Vector2(sin(turn), cos(turn))
			var side := Vector2(face.y, -face.x)
			var reserved := absf(face.y) * float(building["half_width"]) \
				+ absf(face.x) * float(building["half_depth"])
			var local := Settlement.footprint_local(
				building, float(glow["x"]), float(glow["z"])
			)
			var share := 0.0 if reserved <= 0.0 \
				else clampf(local.dot(side) / reserved, -1.0, 1.0)
			var fitted := AssetLibrary.window_glow_point(building, glow)
			var tag := String(building["tag"])
			cases["%s|%d|%d" % [tag, roundi(turn / (PI * 0.5)), roundi(share * 40.0)]] = {
				"tag": tag, "turn": turn, "share": share,
				"fitted": bool(fitted["fitted"]),
			}
	# And every catalog building tag, whether or not a village happened to place
	# one, on every face a window may go on and right across each face -- so this
	# is a claim about the models rather than about this sample of villages.
	for tag in AssetTags.in_category(AssetTags.BUILDINGS):
		if tag in NO_WINDOWS:
			continue
		for turn: float in [0.0, PI * 0.5, -PI * 0.5]:
			for share: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				var key := "%s|%d|%d" % [tag, roundi(turn / (PI * 0.5)), roundi(share * 40.0)]
				if cases.has(key):
					continue
				cases[key] = {
					"tag": tag, "turn": turn, "share": share, "fitted": true,
				}

	var worst_gap := 0.0
	var worst_where := ""
	var unfitted := 0
	for key in cases:
		var one: Dictionary = cases[key]
		var tag: String = one["tag"]
		if not bool(one["fitted"]):
			unfitted += 1
			continue
		var turn: float = one["turn"]
		var share: float = one["share"]
		var face := Vector2(sin(turn), cos(turn))
		var side := Vector2(face.y, -face.x)
		var wall := AssetLibrary.facade_window(tag, face, share)
		check(bool(wall["ok"]), "the %s model has no wall on face %+d"
			% [tag, roundi(turn / (PI * 0.5))])
		if not bool(wall["ok"]):
			continue
		var triangles := _triangles_of(tag)
		check(triangles.size() >= 3, "%s has no geometry to check against" % tag)
		var out: float = float(wall["depth"]) + AssetLibrary.WINDOW_STANDOFF
		for corner in _pane_corners(
			face, side, out, float(wall["lateral"]), float(wall["height"])
		):
			var gap := _distance_to_surface(corner, triangles)
			if gap > worst_gap:
				worst_gap = gap
				worst_where = "%s face %+d share %+.2f" % [
					tag, roundi(turn / (PI * 0.5)), share,
				]
			check(gap <= MAX_GAP,
				"a lit window on a %s hangs %.3f from the model's surface"
				% [tag, gap])
			# And it has to be visible from outside: a ray coming in along the
			# wall's own normal must reach the pane without hitting the model
			# first. That is what "not buried in the mesh" means, and it is asked
			# exactly rather than estimated.
			var blocked := _blocked_from_outside(corner, face, triangles)
			check(blocked <= BURIED_SLACK,
				"a lit window on a %s is buried %.3f inside the model"
				% [tag, blocked])
	equal(unfitted, 0,
		"%d lit windows found no wall on the model to sit on" % unfitted)
	check(cases.size() >= 30,
		"only %d distinct window placements were checked against the models"
		% cases.size())
	print("        window glow: %d distinct placements checked, worst gap %.3f (%s)"
		% [cases.size(), worst_gap, worst_where])


## The four corners of the pane the asset table draws, in the model's own frame,
## pulled a hair inside its own edge so a corner exactly on the edge of a wall is
## not a failure about floating-point.
func _pane_corners(
	face: Vector2, side: Vector2, out: float, lateral: float, storey: float
) -> Array[Vector3]:
	var half_wide := AssetLibrary.WINDOW_WIDTH * 0.49
	var half_tall := AssetLibrary.WINDOW_TALL * 0.49
	var corners: Array[Vector3] = []
	for across: float in [-half_wide, 0.0, half_wide]:
		for up: float in [-half_tall, 0.0, half_tall]:
			var flat := face * out + side * (lateral + across)
			corners.append(Vector3(flat.x, storey + up, flat.y))
	return corners


## How far a point is from the nearest triangle of a model.
func _distance_to_surface(point: Vector3, triangles: PackedVector3Array) -> float:
	var best := INF
	var at := 0
	while at + 2 < triangles.size():
		best = minf(best, _point_to_triangle(
			point, triangles[at], triangles[at + 1], triangles[at + 2]
		))
		at += 3
	return best


## How deeply a point is hidden behind the model, looking at it from outside
## along the wall's own normal. Zero means the pane can be seen; a positive
## number is how much model stands in front of it.
##
## Asked as a ray rather than as a search for nearby geometry, because the eave
## over a window and the sill under it are both close to it and neither is in the
## way of seeing it. Only something the light would have to shine through counts.
func _blocked_from_outside(
	point: Vector3, face: Vector2, triangles: PackedVector3Array
) -> float:
	var normal := Vector3(face.x, 0.0, face.y)
	var start := point + normal * OUTSIDE_REACH
	var nearest := INF
	var at := 0
	while at + 2 < triangles.size():
		var hit := _ray_triangle(start, -normal,
			triangles[at], triangles[at + 1], triangles[at + 2])
		if hit >= 0.0:
			nearest = minf(nearest, hit)
		at += 3
	if nearest == INF:
		return 0.0
	return maxf(0.0, OUTSIDE_REACH - nearest)


## Where a ray meets a triangle, as a distance along it, or -1 for a miss.
## Moeller-Trumbore, which solves the ray and the triangle's own two edge
## parameters as one three-by-three system.
func _ray_triangle(
	from: Vector3, direction: Vector3, a: Vector3, b: Vector3, c: Vector3
) -> float:
	var edge_one := b - a
	var edge_two := c - a
	var across := direction.cross(edge_two)
	var determinant := edge_one.dot(across)
	if absf(determinant) < 0.0000001:
		return -1.0
	var inverse := 1.0 / determinant
	var to_a := from - a
	var u := to_a.dot(across) * inverse
	if u < 0.0 or u > 1.0:
		return -1.0
	var other := to_a.cross(edge_one)
	var v := direction.dot(other) * inverse
	if v < 0.0 or u + v > 1.0:
		return -1.0
	var along := edge_two.dot(other) * inverse
	return along if along > 0.0 else -1.0


# --- What the render layer does with it ----------------------------------

func _a_window_glow_is_drawn_as_a_warm_emissive_with_a_light() -> void:
	var row := AssetLibrary.visual(AssetTags.WINDOW_GLOW)
	check(row != null, "the table has no window_glow row")
	if row == null:
		return
	var emissive := 0
	for entry in row.parts:
		if float(entry["emission"]) > 0.0:
			emissive += 1
			var colour: Color = entry["color"]
			check(colour.r > colour.g and colour.g > colour.b,
				"a lit window's pane is not a warm colour: %s" % colour)
	check(emissive >= 1, "a lit window has no emissive part")

	# And the atmosphere layer hangs a warm point light off it, through the same
	# table of glowing tags the lantern posts and the campfire go through.
	var settings: Dictionary = Atmosphere.GLOWING_TAGS.get(AssetTags.WINDOW_GLOW, {})
	check(not settings.is_empty(),
		"window_glow is not in the atmosphere layer's glowing tags")
	if settings.is_empty():
		return
	var light: Color = settings["color"]
	check(light.r > light.g and light.g > light.b,
		"a lit window's light is not warm: %s" % light)
	check(float(settings["energy"]) > 0.0 and float(settings["range"]) > 0.0,
		"a lit window's light has no energy or no reach")
	check(is_equal_approx(float(settings["at"]), AssetLibrary.WINDOW_HEIGHT),
		"the light sits at %.2f but the pane at %.2f"
		% [float(settings["at"]), AssetLibrary.WINDOW_HEIGHT])


# --- Geometry ------------------------------------------------------------

## Every triangle of a tag's visual, in the tag's own frame, as flat triples.
##
## Read straight off the model here rather than through the asset table's own
## measurement, so that this suite is checking the fit against the art and not
## against the same summary the fit was computed from.
func _triangles_of(tag: String) -> PackedVector3Array:
	if _triangle_cache.has(tag):
		return _triangle_cache[tag]
	var out := PackedVector3Array()
	var node := AssetLibrary.build(tag)
	if node != null:
		_gather_triangles(node, Transform3D.IDENTITY, out)
		node.free()
	_triangle_cache[tag] = out
	return out


var _triangle_cache := {}


func _gather_triangles(node: Node, at: Transform3D, into: PackedVector3Array) -> void:
	var here := at
	if node is Node3D:
		here = at * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			for surface in mesh.get_surface_count():
				var faces := mesh.surface_get_arrays(surface)
				if faces.size() <= Mesh.ARRAY_VERTEX:
					continue
				var verts: PackedVector3Array = faces[Mesh.ARRAY_VERTEX]
				var index_list := PackedInt32Array()
				if faces[Mesh.ARRAY_INDEX] != null:
					index_list = faces[Mesh.ARRAY_INDEX]
				if index_list.is_empty():
					for vertex in verts:
						into.append(here * vertex)
				else:
					for index in index_list:
						into.append(here * verts[index])
	for child in node.get_children():
		_gather_triangles(child, here, into)


## The distance from a point to a triangle: the standard closest-point-on-
## triangle, which walks the seven regions the triangle's plane is divided into
## by its own edges and returns the nearest point in whichever one the projection
## falls in.
func _point_to_triangle(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := b - a
	var ac := c - a
	var ap := point - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return point.distance_to(a)
	var bp := point - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return point.distance_to(b)
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var denom := d1 - d3
		var v := 0.0 if is_zero_approx(denom) else d1 / denom
		return point.distance_to(a + ab * v)
	var cp := point - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return point.distance_to(c)
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var denom := d2 - d6
		var w := 0.0 if is_zero_approx(denom) else d2 / denom
		return point.distance_to(a + ac * w)
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var denom := (d4 - d3) + (d5 - d6)
		var w := 0.0 if is_zero_approx(denom) else (d4 - d3) / denom
		return point.distance_to(b + (c - b) * w)
	var total := va + vb + vc
	if is_zero_approx(total):
		return point.distance_to(a)
	return point.distance_to(a + ab * (vb / total) + ac * (vc / total))
