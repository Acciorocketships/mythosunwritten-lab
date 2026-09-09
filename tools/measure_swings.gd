extends SceneTree
## Which motion each weapon plays, and when it starts and stops.
##
##   ./tools/measure_swings.sh [--ticks N]
##
## The seven weapons of the catalogue stand on one board and fight, and every
## tick the snapshot the simulation hands out is put through the two render-side
## functions the shell uses -- `CombatDiorama.placements()` for the state and
## `CharacterView.clip_for()` for the clip. So this is not a story about what
## ought to be drawn: it is the same calculation `render/main.gd` makes, printed.
##
## The run is `TestAttackClips.play()`, which is also what the suite asserts
## over, so the trace and the suite cannot disagree: one run, one calculation.
##
## Four sections:
##
##   * **the blows** -- every blow the run landed, with the weapon that struck
##     it, the motion tag it carries and the clip that motion plays.
##   * **a swing tick by tick** -- one weapon's blow followed from the tick the
##     record says it began on to the tick after its clip runs out.
##   * **every motion timed** -- how many comparisons were made and how many of
##     them the record had already been dropped for.
##   * **what falls back** -- how many of the catalogue's attacks have no clip of
##     their own.
##
## A workbench, not part of the game.

const DEFAULT_TICKS := TestAttackClips.TICKS


func _initialize() -> void:
	var ticks := DEFAULT_TICKS
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--ticks" and i + 1 < args.size():
			ticks = args[i + 1].to_int()

	var played := TestAttackClips.play(ticks)
	print("swings seed=%d ticks=%d weapons=%d blows=%d" % [
		int(played["seed"]), int(played["ticks"]),
		(played["weapons"] as Dictionary).size(), (played["blows"] as Array).size(),
	])
	print("")
	_the_blows(played)
	print("")
	_a_swing_tick_by_tick(played)
	print("")
	_every_motion_timed(played)
	print("")
	_what_falls_back()
	quit(0)


## Every blow, with the weapon that struck it and the clip its motion plays.
func _the_blows(played: Dictionary) -> void:
	var weapons: Dictionary = played["weapons"]
	var seen := {}
	print("the blows")
	print("  %5s %-8s %-8s %-10s %-7s %-34s %6s" % [
		"tick", "by", "weapon", "attack", "motion", "clip", "ticks"])
	for blow in played["blows"]:
		var motion := String(blow["animation"])
		seen[String(weapons.get(int(blow["from"]), ""))] = true
		print("  %5d %-8s %-8s %-10s %-7s %-34s %6d" % [
			int(blow["tick"]), String(blow["by"]),
			String(weapons.get(int(blow["from"]), "")), String(blow["attack"]),
			motion, CharacterRig.clip_for_motion(motion),
			CharacterRig.motion_ticks(motion),
		])
	print("  %d different weapons were used" % seen.size())


## One blow followed frame by frame: the ticks around it, and what the render
## layer would have drawn on each.
##
## The blow chosen is the first one of the run whose whole motion is inside the
## run and whose record the snapshot carries the whole way through, so that what
## is printed is a motion running out rather than a record being dropped.
func _a_swing_tick_by_tick(played: Dictionary) -> void:
	var frames: Array = played["frames"]
	for blow in played["blows"]:
		var id := int(blow["from"])
		var began := int(blow["tick"])
		var motion := String(blow["animation"])
		var lasts := CharacterRig.motion_ticks(motion)
		var rows := []
		for frame in frames:
			if int(frame["id"]) != id:
				continue
			var when := int(frame["tick"])
			if when < began - 1 or when > began + lasts + 1:
				continue
			rows.append(frame)
		if rows.size() < lasts + 2:
			continue
		var whole := true
		for row in rows:
			var when := int(row["tick"])
			var showing := String(row["motion"]) == motion
			var wanted := when >= began and when < began + lasts
			if showing != wanted:
				whole = false
		if not whole:
			continue
		print("a swing tick by tick: %s struck '%s' on tick %d, and it lasts %d ticks" % [
			String(blow["by"]), motion, began, lasts])
		print("  %5s %-7s %-34s %s" % ["tick", "motion", "clip", "began on"])
		for row in rows:
			print("  %5d %-7s %-34s %s" % [
				int(row["tick"]),
				String(row["motion"]) if String(row["motion"]) != "" else "-",
				String(row["clip"]),
				str(int(row["began"])) if int(row["began"]) >= 0 else "-",
			])
		return
	print("a swing tick by tick: no blow of the run was followed the whole way")


## Every blow timed against its own record, and how many were dropped from the
## snapshot before their motion was over.
func _every_motion_timed(played: Dictionary) -> void:
	var timed := TestAttackClips.timings(played)
	print("every motion timed")
	print("  %d comparisons against the tick the record names, %d wrong" % [
		int(timed["checked"]), (timed["failures"] as Array).size()])
	for failure in timed["failures"]:
		print("    %s" % String(failure))
	print("  %d comparisons were skipped: the blow had left the snapshot's own" % int(timed["dropped"]))
	print("  window -- each fighter's last %d blows struck and last %d taken --" % [
		CombatantRoster.BLOWS_EACH, CombatantRoster.BLOWS_EACH,
	])
	print("  before its motion was over, so there was nothing left to draw it")
	print("  from. Counted per fighter, only that fighter's own later blows can")
	print("  push one out, so a crowd cannot; this should read 0.")


func _what_falls_back() -> void:
	var counted := TestAttackClips.fallbacks()
	print("what falls back")
	print("  %d of the catalogue's %d attacks have no clip of their own%s" % [
		int(counted["taken"]), int(counted["total"]),
		"" if (counted["without"] as Array).is_empty()
			else ": %s" % str(counted["without"]),
	])
	print("  a motion with no row plays %s, which is a blow and is not standing still" % [
		String(CharacterRig.FALLBACK_MOTION["clip"])])
