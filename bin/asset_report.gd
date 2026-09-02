extends SceneTree
## Print the asset table: every tag in the catalog and what it currently
## resolves to. One line per tag, so a repoint shows up as a one-line diff.
##
## Run it with:  ./run_assets.sh
##
## This is the render layer talking, which is why it is a separate entry point
## from the headless run: asking what a fir looks like is a rendering question,
## and the headless simulation must be able to run a whole world without ever
## asking it.


func _initialize() -> void:
	var missing := AssetLibrary.missing_tags()
	var unknown := AssetLibrary.unknown_rows()
	var dropped := AssetLibrary.dropped_tints()

	for category in AssetTags.CATEGORIES:
		print("[%s]" % category)
		for tag in AssetTags.in_category(category):
			var row := AssetLibrary.visual(tag)
			if row == null:
				print("  %-16s MISSING" % tag)
				continue
			print("  %-16s %s" % [tag, row.describe()])
		print("")

	print("tags=%d resolved=%d missing=%d unknown-rows=%d dropped-tints=%d" % [
		AssetTags.all().size(), AssetLibrary.tags().size(),
		missing.size(), unknown.size(), dropped.size(),
	])
	if not missing.is_empty():
		printerr("no visual for: %s" % ", ".join(missing))
	if not unknown.is_empty():
		printerr("rows for names that are not tags: %s" % ", ".join(unknown))
	if not dropped.is_empty():
		# A model that takes less of the biome than the placeholder it replaced.
		# Left alone this ships silently and only shows up in a screenshot, which
		# is how the bare tree came to be orange in the twilight marsh.
		printerr("models that drop their placeholder's biome colour: %s"
			% ", ".join(dropped))
	quit(0 if missing.is_empty() and unknown.is_empty() and dropped.is_empty() else 1)
