#!/usr/bin/env bash
# Break one rule of the inventory at a time and ask whether the suite noticed.
#
#   ./tools/inventory_mutations.sh
#
# A test that passes whatever the code does is not a test. This edits one line of
# sim/ per run -- the line the rule is actually written on -- runs the inventory
# suite, and records whether it failed. Every mutation must make it fail; a
# mutation the suite survives is a rule nobody is checking.
#
# The rules under test are the ones this layer exists for: that what is equipped
# is a view onto what is carried and can be nothing else, that letting something
# go takes it off, that the board reads its gear out of the inventory rather than
# from a copy, that a trade is all or nothing in both directions, and that what
# somebody owns does not depend on the order they came by it.
#
# Every edit is undone afterwards, including when a run is interrupted.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TOUCHED=(sim/inventory.gd sim/commander.gd sim/character.gd)
BACKUP="$(mktemp -d)"
for kept in "${TOUCHED[@]}"; do cp "$kept" "$BACKUP/$(basename "$kept")"; done
restore() {
	local kept
	for kept in "${TOUCHED[@]}"; do cp "$BACKUP/$(basename "$kept")" "$kept"; done
}
trap 'restore; rm -rf "$BACKUP"' EXIT

# name | file | the text to replace | what to replace it with
MUTATIONS=(
"anything may be worn, carried or not|sim/inventory.gd|	if not has(entry) or not is_wearable(entry):
		return false|	if not is_wearable(entry):
		return false"
"letting something go leaves it worn|sim/inventory.gd|	for slot in _equipped.keys():
		if _equipped[slot] == entry:
			_equipped.erase(slot)
	carried.remove_at(index)|	carried.remove_at(index)"
"taking something off throws it away|sim/inventory.gd|	var removed: Variant = _equipped[slot]
	_equipped.erase(slot)
	return removed|	var removed: Variant = _equipped[slot]
	_equipped.erase(slot)
	release(removed)
	return removed"
"what is carried is not what is worn|sim/inventory.gd|	for slot in Item.ARMOUR_SLOTS:
		var entry: Variant = _equipped.get(slot, null)|	for slot in Item.ARMOUR_SLOTS:
		var entry: Variant = null"
"the hand is not read out of the inventory|sim/inventory.gd|	var entry: Variant = _equipped.get(Item.SLOT_HAND, null)|	var entry: Variant = null"
"armour is worn in the order it was put on|sim/inventory.gd|	pieces.sort_custom(func(left: Armour, right: Armour) -> bool:
		return left.slot < right.slot)
	return pieces|	pieces.reverse()
	return pieces"
"what you own depends on the order you got it|sim/inventory.gd|	var sorted := Array(lines)
	sorted.sort()|	var sorted := Array(lines)"
"a trade takes without checking it can be paid|sim/inventory.gd|	if maxi(0, given_coins) > left.money or maxi(0, back_coins) > right.money:
		return false|	if false:
		return false"
"a transfer moves coins nobody had|sim/inventory.gd|	var wanted := maxi(0, coins)
	if wanted > from.money:
		return false|	var wanted := maxi(0, coins)"
"equipping does not carry what it puts on|sim/commander.gd|	sheet.inventory.take_up(piece)|	sheet.inventory.equip(piece)"
"a weapon is wielded without being carried|sim/commander.gd|	sheet.inventory.take_up(held)|	sheet.inventory.equip(held)"
"equipment is its own store|sim/character.gd|	get:
		return inventory.equipment()|	get:
		return {}"
)

printf '%-52s %-24s %s\n' "rule broken" "file" "the suite"
printf '%-52s %-24s %s\n' "----------------------------------------------------" \
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
		printf '%-52s %-24s %s\n' "$name" "$file" "COULD NOT APPLY"
		survived=$((survived + 1))
		continue
	fi

	if ./run_inventory_suite.sh >/dev/null 2>&1; then
		printf '%-52s %-24s %s\n' "$name" "$file" "PASSED -- not checked"
		survived=$((survived + 1))
	else
		printf '%-52s %-24s %s\n' "$name" "$file" "failed, as it must"
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
