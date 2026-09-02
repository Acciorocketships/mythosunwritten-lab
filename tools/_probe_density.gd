extends SceneTree
func _initialize() -> void:
	for spot in [Vector2(228,-60), Vector2(0,0), Vector2(96,-240)]:
		var w := SimWorld.new(1234)
		w.place_observer(spot.x, spot.y)
		var p := w.terrain.profile_at(w.observer_x, w.observer_z)
		var layer := GrassLayer.new(w.terrain, 1234)
		var keys: Array = w.terrain_streamer.loaded_keys()
		var total := 0
		var chunks := 0
		var wet := 0
		var steep := 0
		for k in keys:
			var d := TerrainChunkMesher.distance_to_chunk(k, w.observer_x, w.observer_z)
			if not GrassLayer.wanted_at(d): continue
			var v = layer.build(w.terrain_streamer.geometry(k))
			chunks += 1
			if v != null:
				total += v.multimesh.instance_count
				v.free()
		# how much of the ground here is eligible at all
		for i in 400:
			var x := w.observer_x + float(i % 20) * 2.0 - 20.0
			var z := w.observer_z + float(i / 20) * 2.0 - 20.0
			if w.terrain.is_water_at(x, z): wet += 1
			if w.terrain.normal_at(x, z).y < GrassLayer.SLOPE_COS: steep += 1
		print("%-16s biome=%-14s foliage=%.3f density=%.3f  chunks=%d tufts/chunk=%.0f share=%.3f wet=%d%% steep=%d%%" % [
			str(spot), p.id, p.foliage_density,
			GrassLayer.grown_share(
				GrassLayer.clearing_at(w.observer_x, w.observer_z, 1234),
				GrassLayer.coverage_for(w.terrain.biome_field.weights_at(
					w.observer_x, w.observer_z
				))
			),
			chunks, float(total)/float(max(1,chunks)),
			float(total)/float(max(1,chunks))/float(GrassLayer.LATTICE*GrassLayer.LATTICE),
			wet*100/400, steep*100/400,
		])
	quit()
