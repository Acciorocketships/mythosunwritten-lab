extends RefCounted
## Which name in the asset catalog an item is drawn as, and the one place that
## question is answered.
##
## The item layer builds a thing out of numbers: a rarity, a level, one budget
## split three ways. None of that says what the thing looks like, and it must
## not -- `sim/item.gd` is arithmetic and has never heard of a model. What it
## does carry is a *shape*: the forge draws "blade" or "buckler" for a held item
## and a slot for a worn one, and a shape is exactly the sort of thing the asset
## catalog already has names for.
##
## So this file is a two-column table from shapes to `AssetTags` names, and
## nothing else. It loads nothing, builds nothing and knows no more about a
## `gear_blade` than `BiomeCatalog` knows about a `fir`: which model that is
## remains one row of the render layer's table, and swapping the row is still the
## whole cost of changing what a sword looks like.
##
## ## Three answers, in order
##
## `of()` asks three questions and stops at the first that answers:
##
##   1. **What the item says it is.** `Item.model` is set at the forge, where the
##      shape was drawn, and it is the only answer that can tell a blade from a
##      bow -- both are held in the same slot and the slot cannot distinguish
##      them.
##   2. **Where it is worn.** A boot is boot-shaped whoever made it, so the four
##      worn slots resolve without anyone having said anything. This is what
##      gives a piece of armour a body even when it was built by a hand-written
##      scene rather than by the forge.
##   3. **Nothing.** An item that is neither -- a hand-held thing with no shape
##      recorded, an iron key, a wool blanket -- resolves to the empty string,
##      and the empty string is an honest answer rather than a hole. What is
##      drawn in its place is the render layer's decision and is made there
##      (`render/ground_items.gd`), because "what an unnamed thing looks like"
##      is a question about pictures.
##
## `tags_are_real()` exists so the table cannot rot: every name it hands out is
## checked against the catalog by the test suite, so a typo here is a failure
## rather than an invisible item.
class_name ItemModel

## Held shapes, as the forge and the weapon catalogue spell them, to the name
## each is drawn under.
##
## Nine keys for six tags, because two vocabularies meet here. The forge draws
## from its own six held shapes -- blade, spear, bow, staff, flail, buckler --
## and the weapon catalogue ships a sword, a dagger and a shield, which are the
## same three silhouettes under older names. A sword and a dagger are both a
## blade and a shield is a buckler; that is a fact about what they look like, so
## it is recorded here and not in either of the two files that use the words.
const BY_SHAPE := {
	"blade": AssetTags.GEAR_BLADE,
	"sword": AssetTags.GEAR_BLADE,
	"dagger": AssetTags.GEAR_BLADE,
	"spear": AssetTags.GEAR_SPEAR,
	"bow": AssetTags.GEAR_BOW,
	"staff": AssetTags.GEAR_STAFF,
	"flail": AssetTags.GEAR_FLAIL,
	"buckler": AssetTags.GEAR_BUCKLER,
	"shield": AssetTags.GEAR_BUCKLER,
}

## The four worn slots, to what a piece for that slot is drawn as. `Item`'s own
## slot constants are the keys, so a slot renamed there cannot leave a stale key
## here.
const BY_SLOT := {
	Item.SLOT_BOOTS: AssetTags.GEAR_BOOTS,
	Item.SLOT_LEGGINGS: AssetTags.GEAR_LEGGINGS,
	Item.SLOT_CHESTPLATE: AssetTags.GEAR_CHESTPLATE,
	Item.SLOT_HELMET: AssetTags.GEAR_HELMET,
}

## What is returned for an item this table cannot place: nothing, deliberately.
const NOTHING := ""


## The catalog name for one shape word, or `NOTHING` for a word that is not one.
static func for_shape(shape: String) -> String:
	return String(BY_SHAPE.get(shape, NOTHING))


## The catalog name for one worn slot, or `NOTHING` for a slot nothing is worn
## in -- the hand, and the no-slot a consumable sits in.
static func for_slot(slot: String) -> String:
	return String(BY_SLOT.get(slot, NOTHING))


## What an item is drawn as: what it says it is, else what its slot implies,
## else nothing. See the class note for why the third answer is a real one.
static func of(item: Item) -> String:
	if item == null:
		return NOTHING
	if item.model != NOTHING:
		return item.model
	return for_slot(item.slot)


## Whether an item resolves to a name at all.
static func is_named(item: Item) -> bool:
	return of(item) != NOTHING


## Every name this table can hand out, in a fixed order: the held shapes first,
## then the worn slots. What the suite checks against the catalog, and what a
## report walks.
static func tags() -> PackedStringArray:
	var named := PackedStringArray()
	for shape in BY_SHAPE:
		var tag := String(BY_SHAPE[shape])
		if not named.has(tag):
			named.append(tag)
	for slot in Item.ARMOUR_SLOTS:
		var tag := for_slot(slot)
		if tag != NOTHING and not named.has(tag):
			named.append(tag)
	return named


## Whether every name in the table is a name the catalog knows. False means a
## typo, and a typo here is an item that would resolve to nothing drawable.
static func tags_are_real() -> bool:
	for tag in tags():
		if not AssetTags.is_tag(tag):
			return false
	return true
