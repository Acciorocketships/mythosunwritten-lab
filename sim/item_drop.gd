extends RefCounted
## What a defeated character leaves behind: each item it carried, rolled on its
## own, kept about one time in five.
##
## Section 4 gives the rule in one line -- "each of a defeated enemy's items
## drops with some probability (~20% each), not always" -- and the whole of this
## file is that line made exact and made reproducible.
##
## ## One roll per item, addressed rather than sequential
##
## The obvious implementation draws five numbers from one stream and hands them
## out in order. This one gives every carried item its own stream, addressed by
## the kill, the item's place in what was carried, and its name:
##
##     drop:<kill>#<index>:<item name>
##
## The difference is worth the line it costs. With a shared sequence, whether the
## boots fall depends on how many items were listed before them, so adding a
## dagger to a corpse silently rerolls the armour. With addressed streams a
## verdict is a function of the item and the kill and nothing else, which is what
## makes "the same seed and the same kill produce the same drops" true even when
## the two runs assembled the carried list differently -- and it is checked that
## way in `tests/test_drops.gd`, by truncating the list and finding the surviving
## verdicts unchanged.
##
## ## Which stream this is
##
## The forge's streams are named `item:<source>` and these are named
## `drop:<kill>`, both forked from the world seed through `SimRng.fork`, which
## builds a fresh generator rather than advancing a shared one. No object is held
## between calls here -- there is no state on this class at all -- so rolling a
## drop cannot move any other stream in the project, world generation included.
## That is not an argument, it is measured: `tests/test_drops.gd` fingerprints a
## world, rolls thousands of drops against it, and fingerprints it again.
class_name ItemDrop

## One in five, as the numerator of a hundred. Section 4 says "~20% each"; this
## is that number, in one place, read by the roll and by the report alike.
const CHANCE_PERCENT := 20

## The draw is an integer in [0, 99] and the item falls when it lands under
## `CHANCE_PERCENT`, so the rate is exactly 20/100 by construction and any
## departure the measurement finds is the generator's, not the rule's.
const RESOLUTION := 100

## The prefix every stream this file opens is named with. `ItemForge` uses
## `item:`; nothing else in the project uses either.
const STREAM_PREFIX := "drop"


## The stream name one item's verdict is drawn from. Public because the report
## prints it: a claim about which streams exist is worth more when the name can
## be read next to the number it produced.
static func stream_label(kill: String, index: int, item: Item) -> String:
	return "%s:%s#%d:%s" % [
		STREAM_PREFIX, kill, maxi(0, index), "" if item == null else item.item_name,
	]


## The raw draw for one item, in [0, RESOLUTION - 1]. The verdict is this number
## against `CHANCE_PERCENT` and nothing else.
static func roll(world_seed: int, kill: String, index: int, item: Item) -> int:
	var draw := SimRng.new(world_seed).fork(stream_label(kill, index, item))
	return draw.next_int(0, RESOLUTION - 1)


## Whether the item at `index` of what was carried falls.
static func falls(world_seed: int, kill: String, index: int, item: Item) -> bool:
	return item != null and roll(world_seed, kill, index, item) < CHANCE_PERCENT


## The verdict for every carried item, in the order carried. Parallel to
## `carried`, so a caller can report what stayed on the body as easily as what
## fell off it.
static func verdicts(world_seed: int, kill: String, carried: Array[Item]) -> Array[bool]:
	var fell: Array[bool] = []
	for index in carried.size():
		fell.append(falls(world_seed, kill, index, carried[index]))
	return fell


## What the kill leaves on the ground: the carried items that fell, in the order
## they were carried. A drop lands as data -- there is no ground, no container
## and no inventory here, and section 4 does not ask for one yet.
static func drops(world_seed: int, kill: String, carried: Array[Item]) -> Array[Item]:
	var fallen: Array[Item] = []
	for index in carried.size():
		if falls(world_seed, kill, index, carried[index]):
			fallen.append(carried[index])
	return fallen


## One line naming what a kill produced, stable enough to compare byte for byte
## across processes. The count comes first so a diff of two transcripts fails on
## the count before it fails on the items.
static func line(world_seed: int, kill: String, carried: Array[Item]) -> String:
	var fallen := drops(world_seed, kill, carried)
	var written := PackedStringArray()
	for item in fallen:
		written.append(item.line())
	return "%s: %d of %d dropped [%s]" % [
		kill, fallen.size(), carried.size(), " | ".join(written),
	]
