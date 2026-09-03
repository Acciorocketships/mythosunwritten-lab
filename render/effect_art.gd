extends RefCounted
## The second mapping table: effect tag -> what it looks like, and animation tag
## -> what it looks like happening.
##
## `render/asset_library.gd` answers "what does a fir look like" for every tag in
## the catalogue -- the things that can be standing in the world, each of which
## it builds as a scene and puts on the ground. This file answers the other two
## vocabularies `sim/asset_tags.gd` holds, and it is a separate table for the
## reason those tags are a separate list: a sprite is not a thing that stands
## somewhere, and a motion is not a thing at all. Folding either into the
## catalogue would also have broken the count `tests/test_asset_tags.gd` keeps
## between `AssetLibrary.tags()` and `AssetTags.all()`, which is the check that
## every placeable tag really resolves to something drawable.
##
## Two tables, one per question, and both are keyed on the tag the simulation
## already names:
##
##   * **`SPRITES`** -- one 16x16 pixel sprite per `AssetTags.EFFECT_SPRITES`
##     entry. Sixteen rows of source each, in the same idiom and the same three
##     colours as `render/ui/pixel_icons.gd`, which are sampled out of the
##     Sprout Lands frame. Written as text rather than kept as files so a change
##     to one shows in a diff as the shape it changes, and so nothing here is
##     derived from a pack file.
##   * **`MOTIONS`** -- one row per `AssetTags.ANIMATIONS` entry, saying how the
##     sprite moves while the action plays: how long a play lasts, how far it
##     travels along and across its own axis, how far it turns, whether it goes
##     out and comes back or crosses one way, and whether the travel across is a
##     rise or a rattle. `pose_of()` turns a row and a phase into an offset in
##     whole art pixels and a turn in whole quarter turns, so a caller draws an
##     animation without knowing which one it is drawing -- and cannot put a
##     pixel of it between two pixels of the screen.
##
## The simulation never reaches this file. It says `blade` and `slash`; what
## those look like is decided here and nowhere else, exactly as `fir` is.
class_name EffectArt

## The cell every sprite is drawn on, which is the interface's and the pack's.
const CELL := 16

## What a play is worth when a tag has no row -- which cannot happen while the
## table is complete, and is checked rather than assumed by
## `tests/test_ui_readout.gd`.
const STILL := {
	"seconds": 0.0, "reach": 0, "lift": 0, "sweep": 0,
	"one_way": false, "rattle": false,
}

# --- The six sprites ------------------------------------------------------
#
# `.` nothing, `o` the edge, `m` a shaded face, `l` a lit one. The same four
# characters and the same three colours as the drawn interface icons, so an
# effect sprite and a panel icon sit together.
#
#   arrow  -- a shaft with a head and fletching, pointing along its own axis
#   bolt   -- a lozenge of light with a short tail: what a spell throws
#   blade  -- a curved crescent with a hilt: an edge, mid-swing
#   point  -- a spearhead on a shaft: what a thrust puts into a cell
#   flame  -- a flame, the one sprite that is its own effect as well
#   impact -- an eight-rayed burst: a blow landing, with no travel of its own

const SPRITES := {
	AssetTags.EFFECT_ARROW: [
		"................",
		"................",
		".........o......",
		".........oo.....",
		"..o......olo....",
		"..oo.....ollo...",
		"...oo....olllo..",
		"ooooooooollllllo",
		"ooooooooollllllo",
		"...oo....olllo..",
		"..oo.....ollo...",
		"..o......olo....",
		".........oo.....",
		".........o......",
		"................",
		"................",
	],
	AssetTags.EFFECT_BOLT: [
		"................",
		"................",
		"................",
		"..........o.....",
		".........omo....",
		"........omllo...",
		".......omllllo..",
		"....oooomllllllo",
		"....oooomllllllo",
		".......omllllo..",
		"........omllo...",
		".........omo....",
		"..........o.....",
		"................",
		"................",
		"................",
	],
	AssetTags.EFFECT_BLADE: [
		"................",
		"..........oo....",
		"........oollo...",
		".......ollllo...",
		"......ollllo....",
		".....ollllo.....",
		"....ollllo......",
		"...ollllo.......",
		"..ollllo........",
		"..olllo.........",
		"..ollo..........",
		"..olo...........",
		".ommo...........",
		".oooo...........",
		"..oo............",
		"................",
	],
	AssetTags.EFFECT_POINT: [
		".......oo.......",
		"......ollo......",
		"......ollo......",
		".....ollllo.....",
		".....ollllo.....",
		".....ollllo.....",
		"....ollllllo....",
		"....olmllmlo....",
		"....ollllllo....",
		".....oommoo.....",
		"......ommo......",
		"......ommo......",
		"......ommo......",
		"......ommo......",
		"......oooo......",
		"................",
	],
	AssetTags.EFFECT_FLAME: [
		"................",
		".......o........",
		"......olo.......",
		"......ollo......",
		".....ollllo.....",
		"....ollllllo....",
		"....ollmmllo....",
		"...ollmmmmllo...",
		"...ollmmmmllo...",
		"...ollmmmmllo...",
		"...ollmmmmllo...",
		"....ollmmllo....",
		"....ollllllo....",
		".....oooooo.....",
		"................",
		"................",
	],
	AssetTags.EFFECT_IMPACT: [
		".......oo.......",
		".......ll.......",
		".o.....ll.....o.",
		".oo....ll....oo.",
		"..oo...ll...oo..",
		"...oo..ll..oo...",
		"....ooollooo....",
		"ooooollllllooooo",
		"ooooollllllooooo",
		"....ooollooo....",
		"...oo..ll..oo...",
		"..oo...ll...oo..",
		".oo....ll....oo.",
		".o.....ll.....o.",
		".......ll.......",
		".......oo.......",
	],
}

# --- The seven motions ----------------------------------------------------
#
# How a sprite moves while its action plays. Six fields each, and the same six
# for every row, so a caller never asks which animation it is drawing:
#
#   seconds -- how long one play lasts
#   reach   -- how far the sprite travels along its own axis, in whole art
#              pixels. Its axis is to the right, as the sprites are drawn
#   lift    -- how far it travels across that axis, in whole art pixels.
#              Negative is upwards, which is where a cast goes
#   sweep   -- how far it turns, in whole quarter turns
#   one_way -- whether it crosses and stays (a shot, a spin) or goes out and
#              comes back (a thrust). The whole of the difference is this flag
#   rattle  -- whether `lift` is a jitter across the axis rather than a
#              travel along it: what makes a bash rattle and a cast rise
#
# ## Whole pixels here too, for the same reason as everywhere else
#
# Every pose this table produces is a whole number of art pixels and a whole
# number of quarter turns. A pixel interface that slides by two-thirds of a pixel
# or turns by seventeen degrees has a blurred edge on every frame of the play,
# which is the one thing this whole idiom cannot have; a sprite that steps a
# whole pixel at a time and turns on the square is the pixel-art answer, and it
# is also what keeps tools/measure_ui.sh's off-grid share at zero while an
# animation is on screen. So the arithmetic below is smooth and its result is
# rounded, rather than the other way round.
#
# The seven are the design's own list, and each is the shortest reading of its
# own name: a lunge goes out and comes back, a slash turns through a quarter
# turn each way, a swing through twice that, a shot crosses and does not return,
# a cast rises, a spin turns a whole circle, and a bash is a short jab that
# rattles.

const MOTIONS := {
	AssetTags.ANIM_LUNGE: {
		"seconds": 0.28, "reach": 7, "lift": 0, "sweep": 0,
		"one_way": false, "rattle": false,
	},
	AssetTags.ANIM_SLASH: {
		"seconds": 0.24, "reach": 3, "lift": 0, "sweep": 1,
		"one_way": false, "rattle": false,
	},
	AssetTags.ANIM_SWING: {
		"seconds": 0.40, "reach": 4, "lift": 0, "sweep": 2,
		"one_way": false, "rattle": false,
	},
	AssetTags.ANIM_SHOOT: {
		"seconds": 0.50, "reach": 24, "lift": 0, "sweep": 0,
		"one_way": true, "rattle": false,
	},
	AssetTags.ANIM_CAST: {
		"seconds": 0.60, "reach": 0, "lift": -6, "sweep": 0,
		"one_way": false, "rattle": false,
	},
	AssetTags.ANIM_SPIN: {
		"seconds": 0.45, "reach": 0, "lift": 0, "sweep": 4,
		"one_way": true, "rattle": false,
	},
	AssetTags.ANIM_BASH: {
		"seconds": 0.22, "reach": 4, "lift": 2, "sweep": 0,
		"one_way": false, "rattle": true,
	},
}


# Built once each, on first ask. A sprite is sixteen rows of source and costs a
# 256-pixel image to make; the panel asks for the same handful every frame.
static var _made := {}


## Whether there is a sprite drawn for a tag.
static func has_sprite(tag: String) -> bool:
	return SPRITES.has(tag)


## Whether there is a motion for a tag.
static func has_motion(tag: String) -> bool:
	return MOTIONS.has(tag)


## The sprite for an effect tag, or null for a name there is none for.
static func sprite_of(tag: String) -> Texture2D:
	if _made.has(tag):
		return _made[tag]
	if not SPRITES.has(tag):
		return null
	var texture := PixelIcons.draw(SPRITES[tag])
	_made[tag] = texture
	return texture


## The motion row for an animation tag, or a still one for a name there is none
## for. Never null, so a caller that has been handed a tag this table does not
## know draws a sprite that sits there rather than nothing at all.
static func motion_of(tag: String) -> Dictionary:
	return MOTIONS.get(tag, STILL)


## How long one play of an animation lasts, in seconds.
static func seconds_of(tag: String) -> float:
	return float(motion_of(tag).get("seconds", 0.0))


## Where the sprite is and how far round it is turned, at a phase between 0 and
## 1 of one play.
##
## Returns `{"offset": Vector2i, "quarter_turns": int}` -- the offset in whole
## art pixels from where the sprite rests, and the turn in whole quarter turns
## clockwise. Everything a caller needs to draw any of the seven, without knowing
## which of the seven it has, and nothing that could put a pixel between two
## pixels.
static func pose_of(tag: String, phase: float) -> Dictionary:
	var row := motion_of(tag)
	var at := clampf(phase, 0.0, 1.0)
	var one_way := bool(row.get("one_way", false))
	# One way, or out and back. A shot crosses the gap and stays crossed; a
	# thrust reaches its furthest half way through and is home again at the end.
	var along := at if one_way else sin(at * PI)
	var turned := at if one_way else at - 0.5
	var lift := float(row.get("lift", 0))
	var across := 0.0
	if bool(row.get("rattle", false)):
		# A square wave off the phase rather than a random number: the same play
		# draws the same way every time, in every process.
		across = 1.0 if int(at * 8.0) % 2 == 0 else -1.0
	else:
		across = along
	return {
		"offset": Vector2i(
			roundi(float(row.get("reach", 0)) * along), roundi(lift * across)
		),
		"quarter_turns": roundi(float(row.get("sweep", 0)) * turned),
	}


## The turn of a pose, in radians clockwise. The one place quarter turns become
## an angle, so nothing else has to know what a quarter turn is.
static func radians_of(quarter_turns: int) -> float:
	return float(quarter_turns) * PI * 0.5


## Every tag this table has a row for, sprites then motions, in the order the
## simulation lists them. What a test walks and what a report tabulates.
static func tags() -> PackedStringArray:
	var found := PackedStringArray()
	for tag in AssetTags.EFFECT_SPRITES:
		if SPRITES.has(tag):
			found.append(tag)
	for tag in AssetTags.ANIMATIONS:
		if MOTIONS.has(tag):
			found.append(tag)
	return found


## Any tag of either vocabulary this table has no row for. Empty, and checked.
static func missing_tags() -> PackedStringArray:
	var absent := PackedStringArray()
	for tag in AssetTags.EFFECT_SPRITES:
		if not SPRITES.has(tag):
			absent.append(tag)
	for tag in AssetTags.ANIMATIONS:
		if not MOTIONS.has(tag):
			absent.append(tag)
	return absent


## Any row here that names something neither vocabulary contains. Empty, and
## checked: a row nothing can ask for is art that will never be drawn.
static func unknown_rows() -> PackedStringArray:
	var strange := PackedStringArray()
	for tag in SPRITES:
		if not AssetTags.is_effect_sprite(tag):
			strange.append(String(tag))
	for tag in MOTIONS:
		if not AssetTags.is_animation(tag):
			strange.append(String(tag))
	return strange
