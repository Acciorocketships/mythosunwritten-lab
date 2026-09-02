#!/usr/bin/env bash
# Break one rule of the piece layer at a time and ask whether the suite noticed.
#
#   ./tools/piece_mutations.sh
#
# A test that passes whatever the code does is not a test. This edits one line of
# sim/ per run -- the line the rule is actually written on -- runs the combat
# piece suite, and records whether it failed. Every mutation must make it fail;
# a mutation the suite survives is a rule nobody is checking.
#
# Every edit is undone afterwards, including when a run is interrupted.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TOUCHED=(sim/legal_moves.gd sim/minion.gd sim/commander.gd sim/armour.gd \
	sim/attack.gd sim/piece_map.gd sim/piece_geometry.gd)
BACKUP="$(mktemp -d)"
for kept in "${TOUCHED[@]}"; do cp "$kept" "$BACKUP/$(basename "$kept")"; done
restore() {
	local kept
	for kept in "${TOUCHED[@]}"; do cp "$BACKUP/$(basename "$kept")" "$kept"; done
}
trap 'restore; rm -rf "$BACKUP"' EXIT

# name | file | the text to replace | what to replace it with
MUTATIONS=(
"a slide is not stopped by a piece|sim/legal_moves.gd|				if taking and standing.owner_id != piece.owner_id:
					cells.append(to)
				break|				if taking and standing.owner_id != piece.owner_id:
					cells.append(to)
				from = to
				continue"
"a slide ignores the climb limit|sim/legal_moves.gd|			if not board.can_step(from, to):
				break|			if not board.is_standable(to):
				break"
"a landing ignores the climb limit|sim/legal_moves.gd|		if not board.can_step(piece.cell, to):
			continue|		if not board.is_standable(to):
			continue"
"a landing is ridden to, not arrived on|sim/legal_moves.gd|			MoveGrant.LAND:
				cells.append_array(_landings(board, pieces, piece, grant, taking))|			MoveGrant.LAND:
				cells.append_array(_rays(board, pieces, piece, grant, taking))"
"a piece may take its own side|sim/legal_moves.gd|	if taking:
		return standing != null and standing.owner_id != piece.owner_id|	if taking:
		return standing != null"
"the Toadstool captures the way it moves|sim/minion.gd|	if of == TOADSTOOL:
		return [MoveGrant.land(PieceGeometry.DIAGONALS, TOADSTOOL)]|	if of == TOADSTOOL:
		return move_grants_of(of)"
"the Cat rides cardinally|sim/minion.gd|			return [MoveGrant.slide(PieceGeometry.DIAGONALS, MoveGrant.UNBOUNDED, CAT)]|			return [MoveGrant.slide(PieceGeometry.CARDINALS, MoveGrant.UNBOUNDED, CAT)]"
"the Ent rides diagonally|sim/minion.gd|			return [MoveGrant.slide(PieceGeometry.CARDINALS, MoveGrant.UNBOUNDED, ENT)]|			return [MoveGrant.slide(PieceGeometry.DIAGONALS, MoveGrant.UNBOUNDED, ENT)]"
"the Frog's L is one cell shorter|sim/minion.gd|			return [MoveGrant.land(PieceGeometry.KNIGHT_HOPS, FROG)]|			return [MoveGrant.land(PieceGeometry.DIAGONALS, FROG)]"
"a commander's base step is more than one cell|sim/commander.gd|	return MoveGrant.land(PieceGeometry.CARDINALS, \"base\")|	return MoveGrant.slide(PieceGeometry.CARDINALS, 2, \"base\")"
"an attack does not turn with its wielder|sim/attack.gd|	return PieceGeometry.rotate_all(offsets, facing)|	return PieceGeometry.rotate_all(offsets, 0)"
"turning spends the attack it was aimed with|sim/commander.gd|func face(direction: int) -> void:
	facing = ((direction % 4) + 4) % 4|func face(direction: int) -> void:
	facing = ((direction % 4) + 4) % 4
	for index in attack_count():
		_ready_on[index] = FIRST_TURN + attack_at(index).cooldown"
"a cooldown is not counted|sim/commander.gd|	_ready_on[index] = turn + cooldown_of(index)|	_ready_on[index] = turn"
"a chestplate grants a slide it did not pay for|sim/armour.gd|			if reach > 0:|			if reach >= 0:"
"leggings grant the hop they did not pay for|sim/armour.gd|			if points >= price(PieceGeometry.KNIGHT_HOPS.size(), 1):|			if points >= 0:"
"a chestplate is unbounded|sim/armour.gd|	return mini(cells, CHESTPLATE_REACH)|	return cells"
"a grant costs one point however far it reaches|sim/armour.gd|	return maxi(0, covers) * maxi(0, reach)|	return maxi(0, reach)"
"a commander's death spares its minions|sim/piece_map.gd|	if not piece.is_commander():
		return remove(id)|	return remove(id)
	if not piece.is_commander():
		return remove(id)"
"a pattern is not put in one order|sim/piece_geometry.gd|	return unique|	unique.reverse()
	return unique"
)

printf '%-48s %-24s %s\n' "rule broken" "file" "the suite"
printf '%-48s %-24s %s\n' "------------------------------------------------" \
	"------------------------" "---------"

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
		printf '%-48s %-24s %s\n' "$name" "$file" "COULD NOT APPLY"
		survived=$((survived + 1))
		continue
	fi

	if ./run_pieces.sh >/dev/null 2>&1; then
		printf '%-48s %-24s %s\n' "$name" "$file" "PASSED -- not checked"
		survived=$((survived + 1))
	else
		printf '%-48s %-24s %s\n' "$name" "$file" "failed, as it must"
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
