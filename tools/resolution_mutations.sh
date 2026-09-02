#!/usr/bin/env bash
# Break one rule of the resolution layer at a time and ask whether the suite
# noticed.
#
#   ./tools/resolution_mutations.sh
#
# A test that passes whatever the code does is not a test. This edits one line of
# sim/ per run -- the line the rule is actually written on -- runs the combat
# resolution suite, and records whether it failed. Every mutation must make it
# fail; a mutation the suite survives is a rule nobody is checking.
#
# Every edit is undone afterwards, including when a run is interrupted.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TOUCHED=(sim/damage.gd sim/combat_resolution.gd sim/combat_match.gd \
	sim/weapon.gd sim/armour.gd sim/attack.gd sim/combat_policy.gd \
	sim/commander.gd)
BACKUP="$(mktemp -d)"
for kept in "${TOUCHED[@]}"; do cp "$kept" "$BACKUP/$(basename "$kept")"; done
restore() {
	local kept
	for kept in "${TOUCHED[@]}"; do cp "$BACKUP/$(basename "$kept")" "$kept"; done
}
trap 'restore; rm -rf "$BACKUP"' EXIT

# name | file | the text to replace | what to replace it with
MUTATIONS=(
"the modifier is applied after defence, not before|sim/damage.gd|	var blow := (maxi(0, power) * multiplier) / NONE
	var landed := (blow * maxi(0, swing) + NONE / 2) / NONE
	return maxi(MINIMUM, landed - maxi(0, defence))|	var blow := maxi(0, maxi(0, power) - maxi(0, defence)) * multiplier / NONE
	var landed := (blow * maxi(0, swing) + NONE / 2) / NONE
	return maxi(MINIMUM, landed)"
"defence does nothing at all|sim/damage.gd|	var blow := (maxi(0, power) * multiplier) / NONE
	var landed := (blow * maxi(0, swing) + NONE / 2) / NONE
	return maxi(MINIMUM, landed - maxi(0, defence))|	var blow := (maxi(0, power) * multiplier) / NONE
	var landed := (blow * maxi(0, swing) + NONE / 2) / NONE
	return maxi(MINIMUM, landed)"
"a blow can be reduced to nothing|sim/damage.gd|	var blow := (maxi(0, power) * multiplier) / NONE
	var landed := (blow * maxi(0, swing) + NONE / 2) / NONE
	return maxi(MINIMUM, landed - maxi(0, defence))|	var blow := (maxi(0, power) * multiplier) / NONE
	var landed := (blow * maxi(0, swing) + NONE / 2) / NONE
	return maxi(0, landed - maxi(0, defence))"
"the die is applied to the result, not to the blow|sim/damage.gd|	var blow := (maxi(0, power) * multiplier) / NONE
	var landed := (blow * maxi(0, swing) + NONE / 2) / NONE
	return maxi(MINIMUM, landed - maxi(0, defence))|	var blow := (maxi(0, power) * multiplier) / NONE
	var landed := blow - maxi(0, defence)
	return maxi(MINIMUM, (landed * maxi(0, swing) + NONE / 2) / NONE)"
"the die rounds a blow down rather than to the nearest point|sim/damage.gd|	var blow := (maxi(0, power) * multiplier) / NONE
	var landed := (blow * maxi(0, swing) + NONE / 2) / NONE
	return maxi(MINIMUM, landed - maxi(0, defence))|	var blow := (maxi(0, power) * multiplier) / NONE
	var landed := (blow * maxi(0, swing)) / NONE
	return maxi(MINIMUM, landed - maxi(0, defence))"
"a blow that missed its roll deals nothing -- the to-hit model|sim/damage.gd|	var blow := (maxi(0, power) * multiplier) / NONE
	var landed := (blow * maxi(0, swing) + NONE / 2) / NONE
	return maxi(MINIMUM, landed - maxi(0, defence))|	var blow := (maxi(0, power) * multiplier) / NONE
	if maxi(0, swing) < NONE:
		return 0
	var landed := (blow * maxi(0, swing) + NONE / 2) / NONE
	return maxi(MINIMUM, landed - maxi(0, defence))"
"the die is wider than the positional ladder can carry|sim/damage.gd|const SWING := 4|const SWING := 8"
"the die is one die and not two|sim/damage.gd|	var second := _die(SimRng.hash_ints(what, who, where))
	return NONE - 2 * SWING + first + second|	var second := first
	return NONE - 2 * SWING + first + second"
"the die does not read the fight's seed|sim/damage.gd|	var who := SimRng.hash_ints(fight_seed, attacker.id, target.id)|	var who := SimRng.hash_ints(NO_DIE, attacker.id, target.id)"
"the die does not read what it is being thrown at|sim/damage.gd|	var what := SimRng.hash_ints(target.cell.y, target.health, power)|	var what := SimRng.hash_ints(target.cell.y, 0, power)"
"a fight with no seed rolls anyway|sim/damage.gd|	if fight_seed == NO_DIE:
		return STEADY|	if false:
		return STEADY"
"a fight's seed does not depend on where it is|sim/damage.gd|	var folded := SimRng.hash_ints(world_seed, int(floor(at_x)), int(floor(at_z)))|	var folded := SimRng.hash_ints(world_seed, 0, 0)"
"one face of the die is favoured by the fold|sim/damage.gd|	return ((word & SimRng.MASK) * SWING_FACES) >> 32|	return (word & SimRng.MASK) % SWING_FACES"
"the die reaches the minion capture layer|sim/combat_resolution.gd|	# The seed is not passed on, because there is nothing here to pass it to: a
	# capture takes no power, no defence and no die.
	return capture(pieces, minion, target)|	if Damage.swing_for(fight_seed, minion, target, 1) < Damage.NONE:
		return {\"kind\": NOTHING, \"attacker\": minion.id, \"target\": target.id}
	return capture(pieces, minion, target)"
"a transcript hides which die was in play|sim/combat_resolution.gd|	var swing := \" swing=%d\" % hit[\"swing\"] if hit[\"rolled\"] else \"\"|	var swing := \"\""
"a fight is played with no die at all|sim/combat_match.gd|	match_state.fight_seed = seed_value|	match_state.fight_seed = Damage.NO_DIE"
"high ground and facing add instead of multiplying|sim/damage.gd|	return ground * facing_multiplier(relation(target, attacker.cell)) / NONE|	return ground + facing_multiplier(relation(target, attacker.cell)) - NONE"
"a backstab is worth no more than a flank|sim/damage.gd|const BACK := 200|const BACK := 150"
"high ground is worth nothing|sim/damage.gd|const HIGH_GROUND := 150|const HIGH_GROUND := 100"
"a flank is worth nothing|sim/damage.gd|const FLANK := 150|const FLANK := 100"
"behind and in front are the same place|sim/damage.gd|	return FRONT if local.y < 0 else BEHIND|	return FRONT"
"a target with no facing can still be backstabbed|sim/damage.gd|	if not target.has_facing():
		return FRONT|	if not target.has_facing():
		return BEHIND"
"a minion's health does not scale with its level|sim/damage.gd|	return MINION_HEALTH_BASE + MINION_HEALTH_PER_LEVEL * maxi(0, level)|	return MINION_HEALTH_BASE"
"a minion's defence does not scale with its level|sim/damage.gd|	return MINION_DEFENCE_BASE + MINION_DEFENCE_PER_LEVEL * maxi(0, level)|	return MINION_DEFENCE_BASE"
"a minion's blow does not scale with its level|sim/damage.gd|	return MINION_POWER_BASE + MINION_POWER_PER_LEVEL * maxi(0, level)|	return MINION_POWER_BASE"
"a commander's health does not scale with its level|sim/damage.gd|	return COMMANDER_HEALTH_BASE + COMMANDER_HEALTH_PER_LEVEL * maxi(0, level)|	return COMMANDER_HEALTH_BASE"
"a capture costs the taker its health|sim/combat_resolution.gd|	var cell := target.cell
	var removed := pieces.remove(target.id)|	var cell := target.cell
	attacker.wound(target.level)
	var removed := pieces.remove(target.id)"
"a capture is decided by level|sim/combat_resolution.gd|	var cell := target.cell
	var removed := pieces.remove(target.id)|	var cell := target.cell
	if attacker.level < target.level:
		return {\"kind\": NOTHING, \"attacker\": attacker.id, \"target\": target.id,
			\"cell\": cell, \"removed\": PackedInt32Array()}
	var removed := pieces.remove(target.id)"
"a capturing minion does not take the cell|sim/combat_resolution.gd|	pieces.move_piece(attacker.id, cell)
	return {
		\"kind\": CAPTURE,|	return {
		\"kind\": CAPTURE,"
"a minion reaching a commander captures it|sim/combat_resolution.gd|	if target.is_commander():
		return strike(
			board, pieces, minion, target, minion.attack_power(), 0, fight_seed
		)|	if false:
		return strike(
			board, pieces, minion, target, minion.attack_power(), 0, fight_seed
		)"
"a minion takes the commander's cell when it strikes|sim/combat_resolution.gd|	if target.is_commander():
		return strike(
			board, pieces, minion, target, minion.attack_power(), 0, fight_seed
		)|	if target.is_commander():
		var struck := strike(
			board, pieces, minion, target, minion.attack_power(), 0, fight_seed
		)
		pieces.move_piece(minion.id, to)
		return struck"
"a shove ignores what is under the cell it pushes into|sim/combat_resolution.gd|		if board.is_hole(to):
			outcome[\"killed\"] = true|		if false:
			outcome[\"killed\"] = true"
"a shove off a cliff is only a step|sim/combat_resolution.gd|		if board.height_at(from) - board.height_at(to) > CombatBoard.STEP_DOWN:|		if false:"
"a shove pushes towards its attacker|sim/combat_resolution.gd|	var away := target.cell - attacker.cell|	var away := attacker.cell - target.cell"
"a shove reads only the cell it lands on|sim/combat_resolution.gd|	for _step in distance:
		var from: Vector2i = target.cell
		var to := from + direction|	for _step in 1:
		var from: Vector2i = target.cell
		var to := from + direction * distance"
"a shove's distance is clamped to one cell|sim/attack.gd|		var worth := maxi(0, int(spec.get(named, 0)))|		var worth := mini(1, maxi(0, int(spec.get(named, 0))))"
"a shove's distance is tripled|sim/attack.gd|		var worth := maxi(0, int(spec.get(named, 0)))|		var worth := 3 * maxi(0, int(spec.get(named, 0)))"
"an attack with no damage still reaches the seam|sim/combat_resolution.gd|	if power > 0:
		dealt = Damage.resolve(power, multiplier, defence, swing)|	if power >= 0:
		dealt = Damage.resolve(power, multiplier, defence, swing)"
"an attack ignores its own cooldown|sim/combat_resolution.gd|	if not commander.can_attack(index, turn):
		return {\"ok\": false, \"reason\": \"on cooldown\"}|	if false:
		return {\"ok\": false, \"reason\": \"on cooldown\"}"
"an attack spares the pieces standing in it|sim/combat_resolution.gd|		if standing != null and standing.id != commander.id:|		if false:"
"a round never advances|sim/combat_match.gd|	if next_slot >= _order.size():
		next_slot = 0
		round_number += 1|	if next_slot >= _order.size():
		next_slot = 0"
"a turn never passes to the next commander|sim/combat_match.gd|	var next_slot := _slot if at < 0 else at + 1|	var next_slot := _slot if at < 0 else at"
"a commander may move as often as it likes|sim/combat_match.gd|	if me == null or _moved:|	if me == null:"
"a commander may act as often as it likes|sim/combat_match.gd|	if _acted:
		_write(\"  refused attack #%d: already acted this turn\" % me.id)
		return {\"ok\": false, \"reason\": \"already acted\"}|	if false:
		return {\"ok\": false, \"reason\": \"already acted\"}"
"a commander may march every minion it owns|sim/combat_match.gd|	if _minion_spent:|	if false:"
"a commander may command anybody's minions|sim/combat_match.gd|	if minion.owner_id != _active:|	if false:"
"a minion may be sent anywhere on the board|sim/combat_match.gd|	if not LegalMoves.destinations(board, pieces, minion).has(to):|	if false:"
"a cooldown is always measured from the first turn|sim/combat_match.gd|		board, pieces, me, index, turn_number(me.id)|		board, pieces, me, index, Commander.FIRST_TURN"
"the area attack is not a cheap one|sim/weapon.gd|			\"name\": \"fireball\",
			\"shape\": PieceGeometry.block(Vector2i(0, -4), 1),
			\"cooldown\": 5,
			\"damage\": 4,|			\"name\": \"fireball\",
			\"shape\": PieceGeometry.block(Vector2i(0, -4), 1),
			\"cooldown\": 5,
			\"damage\": 40,"
"a shove deals damage as well|sim/weapon.gd|			\"name\": \"shove\",
			\"shape\": [Vector2i(0, -1)] as Array[Vector2i],
			\"cooldown\": 2,
			\"damage\": 0,|			\"name\": \"shove\",
			\"shape\": [Vector2i(0, -1)] as Array[Vector2i],
			\"cooldown\": 2,
			\"damage\": 9,"
"a shove pushes nobody|sim/weapon.gd|			Attack.PUSH: 1,|			Attack.PUSH: 0,"
"a point of budget is a point of reduction|sim/armour.gd|	return maxi(0, points) / POINTS_PER_DEFENCE|	return maxi(0, points)"
"what is in a commander's hands does not defend it|sim/commander.gd|	if weapon != null and weapon.item != null:
		points += weapon.item.defence_for(score_for(weapon.item))|	if false:
		points += weapon.item.defence_for(score_for(weapon.item))"
"every wearer reads every item in full|sim/commander.gd|	return sheet.score(read.governing, read.level)|	return read.level"
"a weapon deals the catalogue's damage whatever it is worth|sim/weapon.gd|	return ItemBudget.split(power_for(score), weights)[index]|	return weights[index]"
"a weapon with no damage to divide still deals its budget|sim/weapon.gd|	if ItemBudget.sum(weights) <= 0:
		return 0|	if false:
		return 0"
"a cooldown is bought down by the point, not by the cell|sim/weapon.gd|		bought = item.movement_for(score) / maxi(1, attack.cell_count())|		bought = item.movement_for(score)"
# The last two break no rule of the fight -- both added lines are unused, so the
# transcript is unchanged and only the source scan can see them. They are here
# because the scan used to read a list of fourteen paths that combat_policy.gd
# was not on, and both of these passed every suite until it read the directory.
"a second file calls the damage seam|sim/combat_policy.gd|	if best_index >= 0:
		played.attack(best_index)|	if best_index >= 0:
		var _roll := Damage.resolve(1, Damage.NONE, 0)
		played.attack(best_index)"
"a random source reaches the file that plays a turn|sim/combat_policy.gd|	if best_index >= 0:
		played.attack(best_index)|	if best_index >= 0:
		var _roll := randi() % 2
		played.attack(best_index)"
"a second file rolls the die|sim/combat_policy.gd|	if best_index >= 0:
		played.attack(best_index)|	if best_index >= 0:
		var _swing := Damage.swing_for(1, played.pieces.piece_of(1), played.pieces.piece_of(1), 1)
		played.attack(best_index)"
"the die is drawn from a stream rather than hashed from the blow|sim/damage.gd|	var who := SimRng.hash_ints(fight_seed, attacker.id, target.id)|	var stream := SimRng.new(fight_seed)
	var who := stream.next_u32() ^ SimRng.hash_ints(fight_seed, attacker.id, target.id)"
)

printf '%-52s %-28s %s\n' "rule broken" "file" "the suite"
printf '%-52s %-28s %s\n' \
	"----------------------------------------------------" \
	"----------------------------" "---------"

survived=0
for entry in "${MUTATIONS[@]}"; do
	name="${entry%%|*}"
	rest="${entry#*|}"
	file="${rest%%|*}"
	rest="${rest#*|}"
	from="${rest%%|*}"
	to="${rest#*|}"

	restore
	FROM="$from" TO="$to" python3 - "$file" <<'PY'
import os, sys
path = sys.argv[1]
text = open(path).read()
old, new = os.environ["FROM"], os.environ["TO"]
if text.count(old) != 1:
    sys.exit("mutation target appears %d times in %s" % (text.count(old), path))
open(path, "w").write(text.replace(old, new))
PY
	if [[ $? -ne 0 ]]; then
		printf '%-52s %-28s %s\n' "$name" "$file" "COULD NOT APPLY"
		survived=$((survived + 1))
		continue
	fi

	if ./run_resolution.sh >/dev/null 2>&1; then
		printf '%-52s %-28s %s\n' "$name" "$file" "PASSED -- not checked"
		survived=$((survived + 1))
	else
		printf '%-52s %-28s %s\n' "$name" "$file" "failed, as it must"
	fi
done

restore
echo ""
if [[ $survived -eq 0 ]]; then
	echo "all ${#MUTATIONS[@]} broken rules were caught"
	exit 0
fi
echo "$survived of ${#MUTATIONS[@]} broken rules went unnoticed"
exit 1
