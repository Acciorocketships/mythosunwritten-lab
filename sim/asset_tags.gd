extends RefCounted
## The vocabulary of things the world can contain, as names and nothing else.
##
## Every layer that decides *what goes where* -- the biome catalog now, the
## settlement and scatter layers next -- says "a fir goes here" by naming the
## string in this file. None of them says which model a fir is, where that model
## lives on disk, or which pack it came out of. That question is answered once,
## in the render layer's mapping table, and answering it differently is an edit
## to that one table rather than a change anywhere in generation.
##
## The point of the indirection is the swap. The art is bought low-poly packs
## that do not exist on this machine yet; until they do, every name here resolves
## to a placeholder primitive. When a pack arrives, the placeholder rows become
## scene paths and not one line of generation changes -- which is only true if
## generation never learned an asset path in the first place, so an automated
## check (tests/asset_check.gd) fails the build if a file under sim/ ever names
## one.
##
## There are two vocabularies here, not one. The catalog proper is the list of
## things that can be standing in the world, and the render layer's table has a
## row for every one of them. Beside it sits a second, smaller list -- the effect
## sprites and the animations -- which names what an effect looks like and what
## it looks like happening. Those are not props and nothing builds them as
## scenes, which is why they are kept out of the catalog rather than added to it.
##
## This file holds strings. It builds nothing, loads nothing, and draws nothing.
class_name AssetTags

# --- Flora ---------------------------------------------------------------
# Things that grow. Ground cover first, then the things with trunks.

const GRASS := "grass"
const FLOWER := "flower"
const FERN := "fern"
const BUSH := "bush"
const HARDY_SHRUB := "hardy_shrub"
const REED := "reed"
const CATTAIL := "cattail"
const LILY_PAD := "lily_pad"
const MUSHROOM := "mushroom"
const TOADSTOOL := "toadstool"
const PETAL_DRIFT := "petal_drift"
const FIR := "fir"
const CANOPY_TREE := "canopy_tree"
const BLOSSOM_TREE := "blossom_tree"
const DEAD_TREE := "dead_tree"
const FALLEN_LOG := "fallen_log"

## What hangs off the underside of a floating island: the torn ends of the roots
## that were holding the chunk of land in place. Its own name because nothing
## else in the catalog is a thing that hangs downwards from a surface, and
## because it is the one piece of dressing that says an island was pulled out of
## the ground rather than cast in one piece.
const HANGING_ROOT := "hanging_root"

# --- Rocks ---------------------------------------------------------------

const PEBBLE := "pebble"
const GRAVEL := "gravel"
const BOULDER := "boulder"
const ROCK_SPIRE := "rock_spire"
const STONE_HENGE := "stone_henge"

# --- Props ---------------------------------------------------------------
# Made things that are not shelter: what dresses a path or a market square.

const FENCE := "fence"
const CART := "cart"
const SIGNPOST := "signpost"
const BARREL := "barrel"
const CRATE := "crate"
const MARKET_STALL := "market_stall"
const WATER_WHEEL := "water_wheel"
const CRAFTING_BENCH := "crafting_bench"

# --- Buildings -----------------------------------------------------------
# What a settlement is made of. The settlement layer places these by name.

const HOUSE := "house"
const COTTAGE := "cottage"
const TAVERN := "tavern"
const WORKSHOP := "workshop"
const TOWER := "tower"
const WELL := "well"

# --- Bridges -------------------------------------------------------------
# What gets a path over water, and what gets a traveller onto a floating island.

const BRIDGE_WOOD := "bridge_wood"
const BRIDGE_STONE := "bridge_stone"
const ROPE_LADDER := "rope_ladder"

# --- Lanterns ------------------------------------------------------------
# The warm pinpoints. Everything here is meant to be seen glowing in the dark,
# which is why it is a category of its own rather than a handful of props: the
# render layer treats the whole group as light sources.

const LANTERN_POST := "lantern_post"
const HANGING_LANTERN := "hanging_lantern"
const CAMPFIRE := "campfire"
const GLOWING_ORB := "glowing_orb"
const WINDOW_GLOW := "window_glow"

# --- Characters ----------------------------------------------------------
# The first tier of section 3.3's two-tier army: the commanders, player and
# non-player alike, who carry gear and have facing.
#
# These are *appearances*, not classes. The design has no classes -- every
# ability lives on an item -- so a tag here says which figure is standing there
# and nothing whatever about what it can do. That is the same thing a `fir` tag
# says, and it is the only thing any tag in this file says.
#
# Nothing under sim/ knows these are rigged, animated or even three-dimensional.
# What a character is *doing* travels as ordinary state -- how fast it is
# moving, whether it just climbed, whether it is alive -- and which animation
# that becomes is decided in the render layer, from that state alone.

const BARBARIAN := "barbarian"
const KNIGHT := "knight"
const MAGE := "mage"
const RANGER := "ranger"
const ROGUE := "rogue"
const HOODED_ROGUE := "hooded_rogue"

# --- Creatures -----------------------------------------------------------
# Everything alive that is not a commander: the second tier's minions, and the
# hostiles a commander fights.
#
# The four minions are the chess pieces of section 3.3 -- Toadstool the pawn,
# Cat the bishop, Ent the rook, Frog the knight. They are named for what they
# are in the world, and the `minion_` prefix is load-bearing on the first of
# them: a `toadstool` growing in the marsh is flora and already has a tag, and a
# Toadstool holding a lane is a unit. Two different things, two different names.

const MINION_TOADSTOOL := "minion_toadstool"
const MINION_CAT := "minion_cat"
const MINION_ENT := "minion_ent"
const MINION_FROG := "minion_frog"

const SKELETON_WARRIOR := "skeleton_warrior"
const SKELETON_ROGUE := "skeleton_rogue"
const SKELETON_MAGE := "skeleton_mage"
const SKELETON_MINION := "skeleton_minion"

# --- Gear ----------------------------------------------------------------
# What a generated item looks like lying on the ground or in a hand.
#
# The item layer builds a thing out of numbers -- a rarity, a level, one budget
# cut three ways -- and none of those numbers is a shape. What it does draw is a
# *shape*: the forge picks "blade" or "buckler" for a held item and a slot for a
# worn one, and those are names of the same sort as `fir` and `boulder`. So they
# get rows here, and `sim/item_model.gd` is the two-column table that says which
# shape is which name.
#
# The `gear_` prefix is load-bearing for the same reason `minion_` is on the
# Toadstool: a `boulder` is scenery and a `gear_chestplate` is a thing somebody
# owns, and a category whose names could collide with the props is a category
# that will eventually collide with them.
#
# `gear_bundle` is not a shape anything forges. It is what an item nobody
# recorded a shape for is drawn as -- a wrapped parcel -- so that a wool blanket
# on the ground is something a person can see and walk up to rather than nothing
# at all. Which items take it is the render layer's decision and is made there.
#
# A shape earns its own name here only when something in the simulation can
# actually be that shape. `gear_dagger` does: the catalogue ships a dagger with
# its own attack pattern (`Weapon.dagger()`), `ItemModel.BY_SHAPE` has always had
# a "dagger" key, and until it had a name of its own that key pointed at
# `gear_blade` -- so a dagger was drawn as the sword the same table draws a
# sword as. An axe, a crossbow, a wand and a spellbook are the ones that did not
# earn a name: the packs have models for all four, but nothing the forge draws
# and nothing the catalogue ships can produce an item of that shape, so the tag
# would be a name no item could ever carry. Giving them one needs an attack
# pattern first, which is a change to the combat catalogue and not to this list.

const GEAR_BLADE := "gear_blade"
const GEAR_DAGGER := "gear_dagger"
const GEAR_SPEAR := "gear_spear"
const GEAR_BOW := "gear_bow"
const GEAR_STAFF := "gear_staff"
const GEAR_FLAIL := "gear_flail"
const GEAR_BUCKLER := "gear_buckler"

const GEAR_BOOTS := "gear_boots"
const GEAR_LEGGINGS := "gear_leggings"
const GEAR_CHESTPLATE := "gear_chestplate"
const GEAR_HELMET := "gear_helmet"

const GEAR_DRAUGHT := "gear_draught"
const GEAR_BUNDLE := "gear_bundle"

# --- Effect sprites and animations ---------------------------------------
# What an effect looks like and what it looks like happening: the two tags every
# composable effect carries.
#
# These are deliberately *not* in the catalog below, and the reason is what the
# catalog is. The catalog is the list of things that can be standing in the
# world, every one of which the render layer builds as a scene and puts on the
# ground. An effect's sprite and its animation are neither: they are named state
# travelling with something that happened, on exactly the terms a character's
# animation travels on -- the simulation says "an arrow, shot" and what that
# resolves to is the render layer's table to answer.
#
# Keeping the two vocabularies apart means the catalog stays exactly the set of
# buildable props, and this file can name a motion without claiming a motion can
# be stood on.

const EFFECT_ARROW := "arrow"
const EFFECT_BOLT := "bolt"
const EFFECT_BLADE := "blade"
const EFFECT_POINT := "point"
const EFFECT_FLAME := "flame"
const EFFECT_IMPACT := "impact"

## Every effect sprite there is, in a fixed order.
const EFFECT_SPRITES := [
	EFFECT_ARROW, EFFECT_BOLT, EFFECT_BLADE, EFFECT_POINT, EFFECT_FLAME,
	EFFECT_IMPACT,
]

const ANIM_LUNGE := "lunge"
const ANIM_SLASH := "slash"
const ANIM_SWING := "swing"
const ANIM_SHOOT := "shoot"
const ANIM_CAST := "cast"
const ANIM_SPIN := "spin"
const ANIM_BASH := "bash"

## Every animation there is, in a fixed order.
const ANIMATIONS := [
	ANIM_LUNGE, ANIM_SLASH, ANIM_SWING, ANIM_SHOOT, ANIM_CAST, ANIM_SPIN,
	ANIM_BASH,
]


# --- The catalog ---------------------------------------------------------

const FLORA := "flora"
const ROCKS := "rocks"
const PROPS := "props"
const BUILDINGS := "buildings"
const BRIDGES := "bridges"
const LANTERNS := "lanterns"
const CHARACTERS := "characters"
const CREATURES := "creatures"
const GEAR := "gear"

## Every category, in a fixed order, so anything that walks the catalog walks it
## the same way in every process.
const CATEGORIES := [
	FLORA, ROCKS, PROPS, BUILDINGS, BRIDGES, LANTERNS, CHARACTERS, CREATURES,
	GEAR,
]

## category -> the tags in it, in a fixed order. This is the whole catalog: a
## tag that is not in here is not a tag, and the render layer's table is checked
## against it rather than the other way round.
const BY_CATEGORY := {
	FLORA: [
		GRASS, FLOWER, FERN, BUSH, HARDY_SHRUB, REED, CATTAIL, LILY_PAD,
		MUSHROOM, TOADSTOOL, PETAL_DRIFT,
		FIR, CANOPY_TREE, BLOSSOM_TREE, DEAD_TREE, FALLEN_LOG, HANGING_ROOT,
	],
	ROCKS: [PEBBLE, GRAVEL, BOULDER, ROCK_SPIRE, STONE_HENGE],
	PROPS: [
		FENCE, CART, SIGNPOST, BARREL, CRATE, MARKET_STALL, WATER_WHEEL,
		CRAFTING_BENCH,
	],
	BUILDINGS: [HOUSE, COTTAGE, TAVERN, WORKSHOP, TOWER, WELL],
	BRIDGES: [BRIDGE_WOOD, BRIDGE_STONE, ROPE_LADDER],
	LANTERNS: [LANTERN_POST, HANGING_LANTERN, CAMPFIRE, GLOWING_ORB, WINDOW_GLOW],
	CHARACTERS: [BARBARIAN, KNIGHT, MAGE, RANGER, ROGUE, HOODED_ROGUE],
	CREATURES: [
		MINION_TOADSTOOL, MINION_CAT, MINION_ENT, MINION_FROG,
		SKELETON_WARRIOR, SKELETON_ROGUE, SKELETON_MAGE, SKELETON_MINION,
	],
	GEAR: [
		GEAR_BLADE, GEAR_DAGGER, GEAR_SPEAR, GEAR_BOW, GEAR_STAFF,
		GEAR_FLAIL, GEAR_BUCKLER,
		GEAR_BOOTS, GEAR_LEGGINGS, GEAR_CHESTPLATE, GEAR_HELMET,
		GEAR_DRAUGHT, GEAR_BUNDLE,
	],
}

# tag -> category. Built once from BY_CATEGORY, so the two cannot disagree.
static var _category_of := {}


## Every tag in the catalog, in category order then within-category order.
static func all() -> PackedStringArray:
	var tags := PackedStringArray()
	for category in CATEGORIES:
		for tag in BY_CATEGORY[category]:
			tags.append(tag)
	return tags


## The tags of one category, or an empty list for a name that is not one.
static func in_category(category: String) -> PackedStringArray:
	var tags := PackedStringArray()
	for tag in BY_CATEGORY.get(category, []):
		tags.append(tag)
	return tags


## Whether a string is one of the catalog's tags.
static func is_tag(tag: String) -> bool:
	return _index().has(tag)


## Which category a tag belongs to, or "" for a string that is not a tag.
static func category_of(tag: String) -> String:
	return _index().get(tag, "")


static func _index() -> Dictionary:
	if not _category_of.is_empty():
		return _category_of
	var index := {}
	for category in CATEGORIES:
		for tag in BY_CATEGORY[category]:
			index[tag] = category
	_category_of = index
	return _category_of


## Whether a string is one of the effect sprites. A separate vocabulary from the
## catalog above, and a separate question: nothing is both a prop and a sprite.
static func is_effect_sprite(tag: String) -> bool:
	return EFFECT_SPRITES.has(tag)


## Whether a string is one of the animations.
static func is_animation(tag: String) -> bool:
	return ANIMATIONS.has(tag)
