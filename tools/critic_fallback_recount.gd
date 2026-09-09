extends RefCounted
## Critic recount for `W-item-visuals-review`: every fallback number the four
## item items reported, counted again here rather than quoted from them.
##
##     ./tools/critic_fallback_recount.sh
##
## Four counts, each walked from the shipped catalogue or the shipped scenarios
## and compared against the number the work item claimed:
##
##   * the motion with no clip  -- `CharacterRig.MOTION_CLIPS`
##   * the effect with no body  -- `FlightArt.BODIES`
##   * the gear tag with no face -- `PixelIcons.GEAR`
##   * the item with no model tag -- `ItemModel.of` over every shipped scenario
class_name CriticFallbackRecount

const CLAIMED_MOTION_FALLBACKS := 0
const CLAIMED_CATALOGUE_ATTACKS := 8
const CLAIMED_BODY_FALLBACKS := 0
const CLAIMED_SHIPPED_ATTACKS := 10
const CLAIMED_ITEM_FALLBACKS := 7
const CLAIMED_SHIPPED_ITEMS := 49
const CLAIMED_GEAR_TAGS := 13
const CLAIMED_FACES_DRAWN := 8
const SEED := 1234


static func report() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("the fallback counts, re-counted")
	written.append_array(_motions())
	written.append_array(_bodies())
	written.append_array(_faces())
	written.append_array(_items())
	return written


# 1. How many of the catalogue's attacks name a motion `CharacterRig` has no
#    clip for, and would therefore be drawn as the punch.
static func _motions() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("")
	written.append("1. motions with no clip of their own")
	var seen := 0
	var missing := 0
	var lines := PackedStringArray()
	for weapon in Weapon.catalogue():
		for index in weapon.attack_count():
			var attack := weapon.attack_at(index)
			seen += 1
			var tag := String(attack.animation_tag)
			if not CharacterRig.has_motion(tag):
				missing += 1
				lines.append("   %-12s %-14s %s -> FALLBACK %s" % [
					weapon.weapon_name, attack.attack_name, tag,
					CharacterRig.clip_for_motion(tag)])
	for line in lines:
		written.append(line)
	written.append("   %d of the catalogue's %d attacks take the fallback motion (claimed %d of %d)" % [
		missing, seen, CLAIMED_MOTION_FALLBACKS, CLAIMED_CATALOGUE_ATTACKS])
	written.append("   agrees: %s" % _verdict(
		missing == CLAIMED_MOTION_FALLBACKS and seen == CLAIMED_CATALOGUE_ATTACKS))
	# And the other half of the same claim: every motion tag the simulation's
	# vocabulary carries has a row.
	var tagless := PackedStringArray()
	for tag in AssetTags.ANIMATIONS:
		if not CharacterRig.has_motion(String(tag)):
			tagless.append(String(tag))
	written.append("   motion tags in the simulation's vocabulary: %d, without a clip: %s" % [
		AssetTags.ANIMATIONS.size(),
		"none" if tagless.is_empty() else str(tagless)])
	return written


# 2. How many shipped attacks resolve to the fallback flying body.
static func _bodies() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("")
	written.append("2. effect tags with no flying body of their own")
	var seen := 0
	var missing := 0
	var shipped: Array[Weapon] = []
	shipped.append_array(Weapon.catalogue())
	shipped.append_array(Weapon.composed())
	for weapon in shipped:
		for index in weapon.attack_count():
			var attack := weapon.attack_at(index)
			seen += 1
			if not FlightArt.BODIES.has(String(attack.sprite_tag)):
				missing += 1
				written.append("   %-14s %-14s %s -> FALLBACK" % [
					weapon.weapon_name, attack.attack_name, attack.sprite_tag])
	written.append("   %d of the %d shipped attacks take the fallback body (claimed %d of %d)" % [
		missing, seen, CLAIMED_BODY_FALLBACKS, CLAIMED_SHIPPED_ATTACKS])
	written.append("   agrees: %s" % _verdict(
		missing == CLAIMED_BODY_FALLBACKS and seen == CLAIMED_SHIPPED_ATTACKS))
	return written


# 3. How many gear tags have a face of their own, and how many are drawn new.
static func _faces() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("")
	written.append("3. gear tags and the faces they are drawn with")
	var tags := AssetTags.in_category(AssetTags.GEAR)
	var faces := {}
	var without := PackedStringArray()
	for tag in tags:
		var name_of := String(PixelIcons.GEAR.get(String(tag), ""))
		if name_of == "":
			without.append(String(tag))
			continue
		faces[name_of] = int(faces.get(name_of, 0)) + 1
	written.append("   %d gear tags (claimed %d); %d distinct faces behind them" % [
		tags.size(), CLAIMED_GEAR_TAGS, faces.size()])
	written.append("   gear tags with no face at all: %s" % (
		"none" if without.is_empty() else str(without)))
	var shared := PackedStringArray()
	for name_of in faces:
		if int(faces[name_of]) > 1:
			shared.append("%s x%d" % [name_of, int(faces[name_of])])
	written.append("   faces used by more than one tag: %s" % (
		"none" if shared.is_empty() else str(shared)))
	written.append("   agrees on the tag count: %s" % _verdict(tags.size() == CLAIMED_GEAR_TAGS))
	return written


# 4. How many of the items the shipped scenarios put in the world resolve to no
#    model tag, and are therefore shown as the tied parcel in a bag and laid on
#    the ground as one.
static func _items() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("")
	written.append("4. items the shipped scenarios hold that resolve to no tag")
	var items := 0
	var fallbacks := 0
	var by_scenario := PackedStringArray()
	for scenario in Simulation.SCENARIOS:
		if scenario == Simulation.SCENARIO_NONE:
			continue
		var sim := Simulation.new(SEED)
		if not sim.begin_scenario(scenario):
			by_scenario.append("   %-18s unavailable" % scenario)
			continue
		var scene := sim.world.combat.scene
		var here := 0
		var here_back := 0
		var packs: Array[Inventory] = []
		for one in scene.actors:
			var pack := ActionScene.inventory_of(one)
			if pack != null:
				packs.append(pack)
		for thing in scene.objects:
			if thing.holds_things():
				packs.append(thing.contents)
		for pack in packs:
			for item in pack.items():
				items += 1
				here += 1
				if ItemModel.of(item) == ItemModel.NOTHING:
					fallbacks += 1
					here_back += 1
		by_scenario.append("   %-18s %2d items, %d fall back" % [scenario, here, here_back])
	for line in by_scenario:
		written.append(line)
	written.append("   %d of %d shipped items take the fallback (claimed %d of %d)" % [
		fallbacks, items, CLAIMED_ITEM_FALLBACKS, CLAIMED_SHIPPED_ITEMS])
	written.append("   agrees: %s" % _verdict(
		fallbacks == CLAIMED_ITEM_FALLBACKS and items == CLAIMED_SHIPPED_ITEMS))
	return written


static func _verdict(same: bool) -> String:
	return "yes" if same else "NO"
