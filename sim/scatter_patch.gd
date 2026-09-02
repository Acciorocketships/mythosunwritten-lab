extends RefCounted
## Everything the scatter layer put down inside one chunk.
##
## Plain data, in the same spirit as TerrainChunkGeometry and Settlement: a list
## of placed things, each of which is a tag, a position, a facing and a size.
## Nothing in here knows what any of it looks like.
##
## A patch is a *pure function of its chunk coordinate and the world seed*. That
## is the whole claim of this layer, and it is true for a structural reason
## rather than by care: every scatter cell lies inside exactly one chunk, and
## what a cell holds is hashed from the cell and the seed alone. No cell consults
## its neighbours, nothing accumulates between chunks, and no stream of random
## numbers is drawn from -- so a chunk built first, built after its neighbours,
## or built again after being dropped is the same chunk, and two processes agree
## without having to be told anything about each other.
class_name ScatterPatch

## Which chunk this is, in the same coordinates the terrain mesher uses.
var chunk := Vector2i.ZERO

## The placed things, in lattice order then cell order. Each is a dictionary:
##   tag      -- an AssetTags tag
##   x, z     -- where it stands, in world units
##   y        -- the height it stands at: the ground, the water surface, or a
##               little above either for something that floats
##   yaw      -- which way it faces, in radians; 0 faces +Z
##   size     -- how tall it is meant to stand, in world units
##   kind     -- ScatterCatalog.KIND_*, what sort of thing it is
##   context  -- ScatterCatalog.CONTEXT_*, why it was allowed to stand here
var items: Array[Dictionary] = []


func _init(chunk_key: Vector2i = Vector2i.ZERO) -> void:
	chunk = chunk_key


func count() -> int:
	return items.size()


## How many of one kind of thing this patch holds.
func count_of_kind(kind: String) -> int:
	var found := 0
	for item in items:
		if String(item["kind"]) == kind:
			found += 1
	return found


## Every tag in the patch, in placement order and with repeats.
func tags() -> PackedStringArray:
	var found := PackedStringArray()
	for item in items:
		found.append(String(item["tag"]))
	return found


## A detached copy: same values, no shared storage.
##
## The same reason chunk geometry has one. A viewer is handed one of these to
## draw and must not be able to edit the world it is drawing.
func detached_copy() -> ScatterPatch:
	var copy := ScatterPatch.new(chunk)
	for item in items:
		copy.items.append(item.duplicate())
	return copy


## A short, stable fingerprint of everything in this patch.
##
## Every number that decides what a thing is, where it stands and how big it is,
## at fixed precision, in placement order. Two patches with the same fingerprint
## hold the same things, which is how a test shows that a chunk dressed fresh and
## a chunk dressed after its neighbours are the same chunk.
func digest() -> String:
	var parts := PackedStringArray()
	parts.append("c=%d,%d" % [chunk.x, chunk.y])
	for item in items:
		parts.append("%s,%.4f,%.4f,%.4f,%.4f,%.4f" % [
			item["tag"], item["x"], item["z"], item["y"], item["yaw"], item["size"],
		])
	return "|".join(parts).sha256_text().substr(0, 16)
