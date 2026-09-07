extends SceneTree
## What the two combat clip files cost, measured rather than assumed.
##
##   ./tools/measure_clips.sh
##
## `render/character_rig.gd` loaded two of the eight `Rig_Medium` clip files
## until `W-attack-clips`, and now loads four: the two it had, plus CombatMelee
## and CombatRanged, which is where the clips for the simulation's seven motion
## tags come from. Loading a file is not free, so this prints what it costs --
## how long the assembly takes and how much memory the process is holding after
## it -- for the two that were there, the two that were added, and the four
## together.
##
## Each set is assembled through `CharacterRig.assemble()`, which is the same
## function `CharacterRig.library()` calls in the game, so this measures the
## thing that actually runs. One set per process, because the engine keeps every
## file it has opened in a cache of its own and a second measurement in the same
## process would be measuring that cache instead.
##
##   --only base    the two loaded before this item
##   --only combat  the two added by it
##   --only all     what the game loads now (the default)
##
## It also prints the motion table itself -- tag, clip, how long the clip runs
## and how many ticks that is -- and counts how many of the weapon catalogue's
## attacks have no clip of their own and take the fallback.

const BASE := "base"
const COMBAT := "combat"
const ALL := "all"


func _initialize() -> void:
	var only := ALL
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--only" and i + 1 < args.size():
			only = args[i + 1]

	var files := _files_for(only)
	# Taken before anything is loaded, so the difference is what this set costs
	# in a process that has never opened one of these files.
	var before := OS.get_static_memory_usage()
	var started := Time.get_ticks_usec()
	var library := CharacterRig.assemble(files)
	var took := Time.get_ticks_usec() - started
	var after := OS.get_static_memory_usage()

	print("clip cost: %s -- %d file(s), %d clips" % [
		only, files.size(), library.get_animation_list().size()])
	for path in files:
		print("    %s" % String(path).get_file())
	print("  assembled in %.1f ms" % (float(took) / 1000.0))
	print("  static memory %+.2f MiB (%.2f -> %.2f)" % [
		float(after - before) / 1048576.0,
		float(before) / 1048576.0, float(after) / 1048576.0,
	])
	if only == ALL:
		_when_it_is_paid()
		_the_motions(library)
	quit(0)


func _files_for(only: String) -> Array:
	match only:
		BASE:
			var base := []
			for path in CharacterRig.CLIP_FILES[CharacterRig.RIG_MEDIUM]:
				if not CharacterRig.COMBAT_CLIP_FILES.has(path):
					base.append(path)
			return base
		COMBAT:
			return CharacterRig.COMBAT_CLIP_FILES.duplicate()
		_:
			return (CharacterRig.CLIP_FILES[CharacterRig.RIG_MEDIUM] as Array).duplicate()


## When the cost above is actually paid: on the first character mounted, and not
## again.
##
## `CharacterRig.library()` assembles on the first ask and hands the same object
## back after, so the second character on the same skeleton pays nothing. In the
## game the first ask is the observer's model being mounted, which happens in the
## shell's setup -- before a frame is drawn -- and every commander that appears
## later gets the library that is already there. This times both.
func _when_it_is_paid() -> void:
	CharacterRig.forget()
	print("")
	print("when it is paid")
	var scene: PackedScene = load(CharacterView.SCENE)
	for at in 3:
		var view: CharacterView = scene.instantiate()
		root.add_child(view)
		var started := Time.get_ticks_usec()
		view.set_model(AssetTags.KNIGHT)
		var took := Time.get_ticks_usec() - started
		print("  character %d mounted in %6.1f ms, libraries assembled so far: %d" % [
			at + 1, float(took) / 1000.0, CharacterRig.libraries_assembled])
		root.remove_child(view)
		view.queue_free()


## The table from the simulation's seven motion tags to the clips that play
## them, and what falls through it.
func _the_motions(library: AnimationLibrary) -> void:
	print("")
	print("the motion table")
	print("  %-8s %-34s %8s %7s" % ["tag", "clip", "seconds", "ticks"])
	for tag in AssetTags.ANIMATIONS:
		var clip := CharacterRig.clip_for_motion(tag)
		var seconds := 0.0
		if library.has_animation(clip):
			seconds = library.get_animation(clip).length
		print("  %-8s %-34s %8.3f %7d" % [
			tag, clip, seconds, CharacterRig.motion_ticks(tag)])
	var spare := String(CharacterRig.FALLBACK_MOTION["clip"])
	print("  %-8s %-34s %8.3f %7d" % [
		"(none)", spare,
		library.get_animation(spare).length if library.has_animation(spare) else 0.0,
		int(CharacterRig.FALLBACK_MOTION["ticks"]),
	])
	var counted := TestAttackClips.fallbacks()
	print("")
	print("  %d of the catalogue's %d attacks take the fallback%s" % [
		int(counted["taken"]), int(counted["total"]),
		"" if (counted["without"] as Array).is_empty()
			else ": %s" % str(counted["without"]),
	])
