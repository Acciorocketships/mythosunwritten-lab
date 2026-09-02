extends RefCounted
## One sheet of water: plain numbers, no engine objects.
##
## Every river, pond and lake in view is this one surface. It is not cut up per
## chunk and it does not know that chunks exist -- its corners sit on a lattice
## fixed to the world origin, so the same world position always lands on the
## same corner at the same height whatever else is loaded. That is what makes it
## seamless: there is no tile boundary for a seam to appear on, and a river can
## run across a dozen chunk borders as one unbroken surface.
##
## Like chunk geometry, this is arrays of floats. The simulation produces it and
## never draws it; a headless run just hashes it.
class_name WaterSheet

## The stretch of world this sheet was built over, in world units. Water outside
## it is not missing, only not built yet.
var min_x := 0.0
var min_z := 0.0
var max_x := 0.0
var max_z := 0.0

## Triangle corners in world space, three per triangle. Their height is the
## water surface, except at a corner where the water has run out, where it is
## the ground -- so the sheet meets the land exactly at the shoreline.
var vertices := PackedVector3Array()

## One normal per vertex. Corners of the same triangle share a normal, to match
## the faceted look of the ground under it.
var normals := PackedVector3Array()

## One colour per vertex: the biome's water colour there, with the depth in the
## alpha, so shallow water fades out at the shore instead of ending on a line.
## Generated here rather than decided by a viewer, for the same reason the
## ground's colour is: what colour the water is here is a fact about here.
var colors := PackedColorArray()

## Which vertices form which triangles.
var indices := PackedInt32Array()

## How many lattice cells carried any water at all. Diagnostic: it is how a test
## or a report says "there is water in view" without looking at the geometry.
var wet_cells := 0

## How many lattice cells were considered, wet or dry.
var cells_considered := 0


func triangle_count() -> int:
	return indices.size() / 3


## A detached copy: same numbers, no shared storage.
##
## This is how the water reaches a viewer. The arrays are duplicated rather than
## assigned across, because this engine's packed arrays share their storage when
## assigned -- writing into an element of an array that was merely handed over
## would reach the original too.
func detached_copy() -> WaterSheet:
	var copy := WaterSheet.new()
	copy.min_x = min_x
	copy.min_z = min_z
	copy.max_x = max_x
	copy.max_z = max_z
	copy.vertices = vertices.duplicate()
	copy.normals = normals.duplicate()
	copy.colors = colors.duplicate()
	copy.indices = indices.duplicate()
	copy.wet_cells = wet_cells
	copy.cells_considered = cells_considered
	return copy


## A short, stable fingerprint of this sheet.
##
## Recomputed on every call for the same reason a chunk's is: a fingerprint
## cached at build time would answer for the sheet as it was built rather than
## for the sheet as it is, so anything that wrote into it would be invisible to
## every check that compares fingerprints.
func digest() -> String:
	var parts := PackedStringArray()
	parts.append("window=%.2f,%.2f,%.2f,%.2f" % [min_x, min_z, max_x, max_z])
	parts.append("wet=%d/%d" % [wet_cells, cells_considered])
	parts.append("tris=%d" % triangle_count())
	for i in vertices.size():
		var vertex := vertices[i]
		var normal := normals[i]
		var tint := colors[i] if i < colors.size() else Color(0, 0, 0, 0)
		parts.append("%.4f,%.4f,%.4f/%.4f,%.4f,%.4f/%.4f,%.4f,%.4f,%.4f" % [
			vertex.x, vertex.y, vertex.z,
			normal.x, normal.y, normal.z,
			tint.r, tint.g, tint.b, tint.a,
		])
	return "|".join(parts).sha256_text().substr(0, 16)
