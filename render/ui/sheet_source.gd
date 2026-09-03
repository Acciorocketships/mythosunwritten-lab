extends RefCounted
## The one place the interface reaches into the simulation for a character sheet.
##
## The panel is a view onto a `Character` the simulation is holding -- the same
## object, not a copy of it -- so this file's whole job is to hand one over and
## then get out of the way. Everything the panel shows it reads off that object
## every frame, so a blow landed on a tick is on the panel on the next frame with
## nobody having pushed it there.
##
## ## Why this is allowed, and what it is not
##
## The layer rule is one-directional (`tests/layer_check.gd`): the simulation must
## not know the render layer exists, and the render layer may read the simulation
## but must hold no piece of the fight. `LayerCheck.FORBIDDEN_IN_RENDER` is the
## list of what "no piece of the fight" means -- every unit, the board's rules,
## the match, the roster, gear -- and `Character` is deliberately not on it, for
## the same reason `CombatBoard` is not: it is a read-only handle. This file
## reads one and never writes one, and nothing under render/ui/ writes a field of
## the simulation at all.
##
## What is deliberately *not* done here is copying. There is no dictionary of
## scores, no cached level and no snapshot of an inventory anywhere in the
## interface; a second copy of a character sheet is exactly the bug the sheet
## itself was written to prevent (sim/inventory.gd's opening note), and it would
## be no better on this side of the line.
##
## ## Which characters there are
##
## The world holds a roster of everyone who can fight, and an ordinary run fills
## it with the handful of characters who live there (sim/world_cast.gd). A named
## scenario clears that and puts its own cast in instead:
## `./run_render.sh --scenario market` sets out the five of the character
## walkthrough. Either way the panel shows what is in the world; with nobody in
## it -- a world something has emptied -- there is nothing to show and the shell
## says so.
class_name SheetSource

## Every character sheet the world is holding, in the simulation's own id order.
##
## The roster's snapshot says which of its members is a commander -- a character
## rather than one of the summoned minions -- and each of those carries the
## `Character` it is. Reading the sheet off the member is a dynamic hop on
## purpose: the type between the roster and the sheet is one of the combat
## layer's own, and naming it here would be this layer holding a piece of the
## fight.
static func sheets_in(world: SimWorld) -> Array[Character]:
	var found: Array[Character] = []
	if world == null or world.combat == null:
		return found
	var rows: Array = world.combat.snapshot()["pieces"]
	for row in rows:
		if not bool(row["commander"]):
			continue
		var stood: Variant = world.combat.member_of(int(row["id"]))
		if stood == null:
			continue
		var sheet: Variant = stood.piece.sheet
		if sheet is Character:
			found.append(sheet)
	return found
