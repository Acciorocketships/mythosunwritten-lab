extends SceneTree
## The ground along a road that runs through a junction, as CSV.
##
##   ./tools/road_profile_dump.sh > reports/assets/road-junction-after.csv
##   ./tools/road_profile_dump.sh --seed 7 --junction 207.8 -83.9 \
##       --in "l0,-1>l1,-1" --out "l1,-1>l2,-1"
##
## Walks in along one road, through the place two roads meet, and out along the
## other -- the traverse a character makes over a crossroads -- and prints the
## finished ground and the land under it at every step. What the plot in
## reports/roads.md is drawn from, and the reason it is a dump rather than a
## picture: the same walk is run against two versions of the carving and the two
## files are drawn on the same axes.
##
## Nothing is generated and nothing is written: every number comes out of
## TerrainQuery.

const DEFAULT_SEED := 1234
const DEFAULT_JUNCTION := Vector2(-157.2, 49.1)
const DEFAULT_IN := "l-1,0>l-2,0"
const DEFAULT_OUT := "l-2,0>l-3,0"

## How far either side of the junction the traverse runs, and how finely it is
## sampled, in world units.
const SPAN := 33.0
const STEP := 0.5


func _initialize() -> void:
	var world_seed := DEFAULT_SEED
	var junction := DEFAULT_JUNCTION
	var road_in := DEFAULT_IN
	var road_out := DEFAULT_OUT
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size():
			world_seed = args[i + 1].to_int()
		elif args[i] == "--junction" and i + 2 < args.size():
			junction = Vector2(args[i + 1].to_float(), args[i + 2].to_float())
		elif args[i] == "--in" and i + 1 < args.size():
			road_in = args[i + 1]
		elif args[i] == "--out" and i + 1 < args.size():
			road_out = args[i + 1]
	var query := TerrainQuery.for_seed(world_seed)
	var roads := {}
	for edge in query.path_network.edges_near(junction.x, junction.y, 14.0):
		roads[String(edge["id"])] = edge
	if not roads.has(road_in) or not roads.has(road_out):
		printerr("no such roads at that junction: ", roads.keys())
		quit(1)
		return
	print("s,x,z,ground,land")
	_dump(query, roads[road_in], junction, -1.0)
	_dump(query, roads[road_out], junction, 1.0)
	quit()


## One road's stretch nearest the junction, walked outward from it. `way` is -1
## for the road arriving and +1 for the road leaving, which is what puts the two
## on one axis with the junction at zero.
func _dump(query: TerrainQuery, edge: Dictionary, junction: Vector2, way: float) -> void:
	var points: PackedVector2Array = edge["points"]
	var walked := PackedVector2Array()
	for index in points.size() - 1:
		var pieces := maxi(1, int(ceil(points[index].distance_to(points[index + 1]) / STEP)))
		for piece in pieces:
			walked.append(points[index].lerp(points[index + 1], float(piece) / float(pieces)))
	walked.append(points[points.size() - 1])
	# Walk outward from whichever end of the road the junction is at, so that
	# the arclength printed really is the distance travelled from it.
	var head := walked[0].distance_to(junction) <= walked[walked.size() - 1].distance_to(junction)
	var order := range(walked.size()) if head else range(walked.size() - 1, -1, -1)
	var travelled := 0.0
	var last := junction
	var rows: Array[String] = []
	for index in order:
		var at := walked[index]
		travelled += last.distance_to(at)
		last = at
		if travelled > SPAN:
			break
		var bed := query.water_field.bed_height_at(at.x, at.y)
		rows.append("%.4f,%.4f,%.4f,%.4f,%.4f" % [
			way * travelled, at.x, at.y, query.ground_height_at(at.x, at.y),
			bed + query.settlement_field.ground_delta_at(at.x, at.y, bed),
		])
	if way < 0.0:
		rows.reverse()
	for row in rows:
		print(row)
