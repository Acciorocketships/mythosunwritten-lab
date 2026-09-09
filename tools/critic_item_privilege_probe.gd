extends RefCounted
## Critic probe for `W-item-visuals-review`: the same weapon in two hands, and
## the same picture out the other end.
##
##     ./tools/critic_item_privilege_probe.sh            # spear, then bow
##
## Two commanders stand on one board carrying the *same* forged weapon. One of
## them is played by hand -- `ActionScene.take_by_hand`, then `BoardTurn`, which
## is what a person at a keyboard spends a turn through. The other is played by
## its own decision function, serviced by `ControlLoop` and answered by
## `ActionEngine`, which is what a model-driven character is played through.
##
## Every tick the world's snapshot is taken and run through the render layer's
## four drawing paths, exactly as the shell runs them:
##
##   * held item  -- `CombatDiorama.placements()` -> `state["equipped"]` ->
##                   `CharacterView.held_in_hands()`
##   * motion     -- `CombatDiorama.striking()` -> `state["attack"]` ->
##                   `CharacterView.clip_for()` -> `CharacterRig`
##   * projectile -- `BlowFlights.flights(snapshot)`
##
## Nothing here is a second implementation of any of them: every call is the one
## the shell makes. What is printed is the first blow each of the two struck,
## its record, and what the render layer drew from it, side by side.
class_name CriticItemPrivilegeProbe

const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE
const LOOP_SEED := ScriptedLoop.LOOP_SEED
const HAND := "Alder"
const MIND := "Briar"
const LEVEL := 3
const QUICK := 0
const HAND_PACE := 10


static func stage(shape: Weapon, apart: float) -> CombatantRoster:
	var roster := CombatantRoster.new()
	roster.scene.terrain = TerrainQuery.for_seed(SEED)
	var one := _put(roster, HAND, WHERE - Vector2(apart * 0.5, 0.0))
	var two := _put(roster, MIND, WHERE + Vector2(apart * 0.5, 0.0))
	(one.piece as Commander).wield(Weapon.held(shape, LEVEL))
	(two.piece as Commander).wield(Weapon.held(shape, LEVEL))
	var began := roster.scene.begin_fight(one.id)
	if began == null or began.refused:
		return roster
	roster.scene.take_by_hand(one.id)
	return roster


static func drive(roster: CombatantRoster, weapon_name: String) -> void:
	for one in roster.members:
		var sheet := _sheet(one)
		if sheet == null or sheet.character_name != MIND:
			continue
		sheet.decide = DecisionSource.scripted(
			func(scene: ActionScene, actor: Combatant) -> Action:
				for other in scene.actors:
					if other == actor or not other.is_alive() or not other.fighting:
						continue
					return Action.attack(other.id, weapon_name)
				return null
		)


## Play one run and keep, for every tick, the snapshot and what the render layer
## drew from it for each of the two.
static func played(shape: Weapon, weapon_name: String, apart: float, ticks: int) -> Dictionary:
	var roster := stage(shape, apart)
	var scene := roster.scene
	var loop := ControlLoop.on(scene, LOOP_SEED)
	drive(roster, weapon_name)
	var hand_id := _id_of(roster, HAND)
	var mind_id := _id_of(roster, MIND)
	var frames: Array[Dictionary] = []
	var journal := PackedStringArray()
	var said := 0
	var ending := false
	for _step in maxi(0, ticks):
		if ending:
			_end_the_turn(scene, hand_id)
			ending = false
		elif scene.tick > 0 and scene.tick % HAND_PACE == 0:
			_take_a_turn_by_hand(scene, hand_id)
			ending = BoardTurn.of(scene, hand_id) != null
		loop.step()
		roster.step(scene.terrain)
		for at in range(said, loop.journal.size()):
			journal.append(loop.journal[at])
		said = loop.journal.size()
		if roster.fight == null:
			continue
		var snapshot := roster.snapshot()
		frames.append({
			"tick": int(snapshot.get("tick", 0)),
			"drawn": _drawn(snapshot),
			"flights": BlowFlights.flights({"combat": snapshot}),
		})
	var run := {
		"hand_id": hand_id, "mind_id": mind_id,
		"blows": scene.blows.duplicate(true),
		"frames": frames,
		"journal": journal,
	}
	_release(scene)
	return run


# What the render layer draws this tick, by piece id: the shell's own two calls
# and nothing else.
static func _drawn(snapshot: Dictionary) -> Dictionary:
	var by_id := {}
	for row in CombatDiorama.placements({"combat": snapshot}):
		var state: Dictionary = row["state"]
		by_id[int(row["id"])] = {
			"tag": String(row["tag"]),
			"motion": String(state.get("attack", CharacterView.NO_MOTION)),
			"motion_tick": int(state.get("attack_tick", -1)),
			"clip": CharacterView.clip_for(state),
			"hands": CharacterView.held_in_hands(state.get("equipped", {})),
		}
	return by_id


## The two records and the two drawn results, side by side.
static func compare(title: String, shape: Weapon, weapon_name: String, apart: float, ticks: int) -> PackedStringArray:
	var run := played(shape, weapon_name, apart, ticks)
	var hand_id := int(run["hand_id"])
	var mind_id := int(run["mind_id"])
	var written := PackedStringArray()
	written.append("")
	written.append("=== %s: %s, seed=%d ticks=%d ===" % [title, weapon_name, SEED, ticks])
	var a := _first_blow(run["blows"], hand_id)
	var b := _first_blow(run["blows"], mind_id)
	if a.is_empty() or b.is_empty():
		written.append("  one of them never struck: hand fields=%d mind fields=%d" % [a.size(), b.size()])
		written.append("  what the loop said (last 25 lines):")
		var journal: PackedStringArray = run["journal"]
		for at in range(maxi(0, journal.size() - 25), journal.size()):
			written.append("    " + journal[at])
		return written
	written.append("  the record")
	written.append("    %-12s %-28s %-28s" % ["field", "%s (a person)" % HAND, "%s (its own choice)" % MIND])
	var same_fields := true
	written.append("    %-12s %-28s %-28s" % ["by", str(a.get("by", "-")), str(b.get("by", "-"))])
	for field in ["attack", "sprite", "animation", "movement", "cooldown", "hits"]:
		written.append("    %-12s %-28s %-28s" % [field, str(a.get(field, "-")), str(b.get(field, "-"))])
		if str(a.get(field, "-")) != str(b.get(field, "-")):
			same_fields = false
	for field in ["from", "to", "tick", "round", "fight", "dealt", "out_of", "facing", "from_cell", "to_cell"]:
		written.append("    %-12s %-28s %-28s" % [field, str(a.get(field, "-")), str(b.get(field, "-"))])
	written.append("    keys        %s" % ("identical" if str(a.keys()) == str(b.keys()) else "DIFFERENT"))
	written.append("    the three tags and the movement agree: %s" % ("yes" if same_fields else "NO"))
	written.append("  what the render layer drew, on the tick each record says its blow began")
	written.append("    %-12s %-28s %-28s" % ["", "%s (a person)" % HAND, "%s (its own choice)" % MIND])
	var drew_a := _drawn_on(run["frames"], int(a["tick"]), hand_id)
	var drew_b := _drawn_on(run["frames"], int(b["tick"]), mind_id)
	for field in ["tag", "motion", "clip", "hands"]:
		written.append("    %-12s %-28s %-28s" % [
			field, str(drew_a.get(field, "-")), str(drew_b.get(field, "-"))])
	written.append("    motion_tick  %-28s %-28s" % [
		str(drew_a.get("motion_tick", "-")), str(drew_b.get("motion_tick", "-"))])
	written.append("    drawn the same way: %s" % (
		"yes" if str(drew_a.get("clip", "")) == str(drew_b.get("clip", ""))
			and str(drew_a.get("hands", "")) == str(drew_b.get("hands", ""))
			and str(drew_a.get("motion", "")) == str(drew_b.get("motion", "")) else "NO"))
	written.append("  how long each was drawn swinging, and what flew")
	written.append_array(_indent(_life(run, hand_id, a), 4))
	written.append_array(_indent(_life(run, mind_id, b), 4))
	return written


# Every tick this id was drawn mid-motion, and every flight the record fired.
static func _life(run: Dictionary, id: int, blow: Dictionary) -> PackedStringArray:
	var written := PackedStringArray()
	var began := int(blow["tick"])
	var motion := String(blow["animation"])
	var span := CharacterRig.motion_ticks(motion)
	var swinging: Array[int] = []
	var flying: Array[int] = []
	var phases: Array[float] = []
	for frame in run["frames"]:
		var drew: Dictionary = frame["drawn"]
		var mine: Dictionary = drew.get(id, {})
		if String(mine.get("motion", "")) == motion and int(mine.get("motion_tick", -1)) == began:
			swinging.append(int(frame["tick"]))
		for flight in frame["flights"]:
			if String(flight["key"]).ends_with(":%d:%d" % [id, began]):
				flying.append(int(frame["tick"]))
				phases.append(float(flight["phase"]))
	written.append("#%d struck at tick %d, motion %s, its clip runs %d ticks" % [
		id, began, motion, span])
	written.append("  drawn swinging on ticks %s (%d of them, the record promises %d)" % [
		_span_of(swinging), swinging.size(), span])
	written.append("  first drawn %d tick(s) after the tick the record names" % (
		-1 if swinging.is_empty() else swinging[0] - began))
	written.append("  a flight in the air on ticks %s (%d of them)" % [
		_span_of(flying), flying.size()])
	if not phases.is_empty():
		written.append("  the flight leaves at phase %.3f and lands at phase %.3f (0 is the archer, 1 the target)" % [
			phases[0], phases[-1]])
	return written


static func _span_of(ticks: Array[int]) -> String:
	if ticks.is_empty():
		return "none"
	return "%d..%d" % [ticks[0], ticks[-1]]


static func _drawn_on(frames: Array, tick: int, id: int) -> Dictionary:
	for frame in frames:
		if int(frame["tick"]) != tick:
			continue
		return (frame["drawn"] as Dictionary).get(id, {})
	return {}


static func _first_blow(blows: Array, id: int) -> Dictionary:
	for row in blows:
		if int((row as Dictionary)["from"]) == id:
			return row
	return {}


static func _take_a_turn_by_hand(scene: ActionScene, id: int) -> void:
	var turn := BoardTurn.of(scene, id)
	if turn == null:
		return
	for _quarter in PieceGeometry.FACINGS.size():
		if _covers_somebody(scene, turn):
			break
		turn.turn_right()
	turn.swing(QUICK)


static func _end_the_turn(scene: ActionScene, id: int) -> void:
	var turn := BoardTurn.of(scene, id)
	if turn != null:
		turn.finish()


static func _covers_somebody(scene: ActionScene, turn: BoardTurn) -> bool:
	var covered := turn.attack_cells(QUICK)
	for one in scene.actors:
		if one == turn.member or not one.is_alive() or not one.fighting:
			continue
		if covered.has(one.piece.cell):
			return true
	return false


static func _put(roster: CombatantRoster, called: String, at: Vector2) -> Combatant:
	var one := roster.add(Combatant.commander_at(
		at.x, at.y, 0.0, 0.0, LEVEL, AssetTags.KNIGHT))
	var sheet := Character.make(called, LEVEL)
	sheet.record_scores({Ability.DEX: 4, Ability.STR: 5})
	(one.piece as Commander).adopt(sheet)
	one.settle(roster.scene.terrain)
	return one


static func _sheet(one: Combatant) -> Character:
	if one == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet


static func _id_of(roster: CombatantRoster, called: String) -> int:
	for one in roster.members:
		var sheet := _sheet(one)
		if sheet != null and sheet.character_name == called:
			return one.id
	return ActionScene.NOBODY


static func _release(scene: ActionScene) -> void:
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null:
			sheet.decide = Callable()


static func _indent(lines: PackedStringArray, by: int) -> PackedStringArray:
	var out := PackedStringArray()
	for line in lines:
		out.append(" ".repeat(by) + line)
	return out


## A third arm: a weapon action a person spends that finds nobody.
##
## `BoardTurn.swing` spends the turn's action wherever the piece is facing; the
## atomic action surface a model-driven character is answered through refuses an
## attack whose pattern does not cover the named target ("... is outside the
## pattern of a ..."). So a blow that found nobody is a thing only a person can
## put in the record. This prints what the render layer draws from one.
static func a_blow_that_found_nobody(shape: Weapon, weapon_name: String, apart: float, ticks: int) -> PackedStringArray:
	var run := played(shape, weapon_name, apart, ticks)
	var hand_id := int(run["hand_id"])
	var written := PackedStringArray()
	written.append("")
	written.append("=== a blow that found nobody: %s, %0.1f units apart ===" % [weapon_name, apart])
	var missed := {}
	for row in run["blows"]:
		var blow: Dictionary = row
		if int(blow["from"]) == hand_id and int(blow["to"]) == ActionScene.NOBODY:
			missed = blow
			break
	if missed.is_empty():
		written.append("  nobody missed in this run")
		return written
	written.append("  the record: #%d struck at tick %d, %s/%s/%s, hits=%d, to=%d (NOBODY)" % [
		int(missed["from"]), int(missed["tick"]), String(missed["attack"]),
		String(missed["sprite"]), String(missed["movement"]), int(missed["hits"]),
		int(missed["to"])])
	written.append("  from_cell %s   to_cell %s   -- the same cell: %s" % [
		str(missed["from_cell"]), str(missed["to_cell"]),
		"yes" if missed["from_cell"] == missed["to_cell"] else "no"])
	var began := int(missed["tick"])
	var flying := 0
	var first_row := {}
	for frame in run["frames"]:
		for flight in frame["flights"]:
			if String(flight["key"]).ends_with(":%d:%d" % [hand_id, began]):
				flying += 1
				if first_row.is_empty():
					first_row = flight
	written.append("  the render layer draws a flight for it on %d ticks" % flying)
	if not first_row.is_empty():
		written.append("  and it crosses from %s to %s -- distance %d cells" % [
			str(first_row["from_cell"]), str(first_row["to_cell"]),
			(first_row["to_cell"] as Vector2i - first_row["from_cell"] as Vector2i).length()])
	return written
