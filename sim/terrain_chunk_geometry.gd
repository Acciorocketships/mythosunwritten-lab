extends RefCounted
## The geometry of one chunk of ground: plain numbers, no engine objects.
##
## The simulation produces these and never draws them. The render shell turns
## one into something the graphics card understands; a headless run just hashes
## it. Keeping the geometry as arrays of floats is what lets both do that from
## exactly the same generation code.
class_name TerrainChunkGeometry

## Which chunk this is, in chunk coordinates (not world units).
var chunk_x: int = 0
var chunk_z: int = 0

## Triangle corners in world space, three per triangle.
var vertices := PackedVector3Array()

## One normal per vertex. Corners of the same triangle share a normal, which is
## what makes the surface read as flat facets.
var normals := PackedVector3Array()

## One ground colour per vertex, blended from the biomes that have a share of
## that corner. It is generated, not decorated on afterwards: what colour the
## ground is here is a property of the world, so it belongs to the world's
## description of itself. The render shell reads these and does not compute
## them, which is also what makes a biome border reproduce across processes --
## the colours are inside the chunk fingerprint the determinism tests compare.
var colors := PackedColorArray()

## Which vertices form which triangles.
var indices := PackedInt32Array()

## Lowest and highest ground in this chunk, in world units.
var lowest := 0.0
var highest := 0.0


func _init(x: int = 0, z: int = 0) -> void:
	chunk_x = x
	chunk_z = z


func triangle_count() -> int:
	return indices.size() / 3


## A detached copy of this geometry: same numbers, no shared storage.
##
## The arrays are duplicated rather than assigned across, because this engine's
## packed arrays share their storage when assigned -- writing into an element of
## an array that was merely handed over reaches the original too. Duplicating is
## what makes the copy genuinely separate, so whatever a holder does to it, the
## chunk it was copied from is unaffected.
##
## This is how the ground reaches a viewer: cheap enough to pay once per chunk
## (about a microsecond against the ~790 microseconds of building the chunk in
## the first place) and paid only when a chunk is first handed out.
func detached_copy() -> TerrainChunkGeometry:
	var copy := TerrainChunkGeometry.new(chunk_x, chunk_z)
	copy.vertices = vertices.duplicate()
	copy.normals = normals.duplicate()
	copy.colors = colors.duplicate()
	copy.indices = indices.duplicate()
	copy.lowest = lowest
	copy.highest = highest
	return copy


## A short, stable fingerprint of this geometry.
##
## Two chunks with the same fingerprint are the same geometry for every purpose
## the determinism tests care about. Coordinates are rendered at fixed precision
## first, so the fingerprint does not depend on how floats happen to print.
##
## It is recomputed on every call, deliberately. A fingerprint that was cached
## at build time would answer for the geometry as it was built rather than for
## the geometry as it is now, so anything that wrote into a built chunk would be
## invisible to every check that compares fingerprints -- which is exactly what
## those checks exist to catch.
func digest() -> String:
	var parts := PackedStringArray()
	parts.append("chunk=%d,%d" % [chunk_x, chunk_z])
	parts.append("tris=%d" % triangle_count())
	for i in vertices.size():
		var vertex := vertices[i]
		var normal := normals[i]
		var tint := colors[i] if i < colors.size() else Color(0, 0, 0)
		parts.append("%.4f,%.4f,%.4f/%.4f,%.4f,%.4f/%.4f,%.4f,%.4f" % [
			vertex.x, vertex.y, vertex.z,
			normal.x, normal.y, normal.z,
			tint.r, tint.g, tint.b,
		])
	return "|".join(parts).sha256_text().substr(0, 16)
