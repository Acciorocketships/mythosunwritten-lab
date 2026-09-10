extends RefCounted
## What a person has chosen, written as a sentence a person can read.
##
## `Action.line()` is the simulation's own spelling of a choice, and it is a
## *call*: `attack(target=2 item=)`, `say(text="what will you take for it?")`.
## That spelling is load-bearing everywhere it is used -- the journal, the
## traces, the loop's record of what it answered, and every test that compares
## one run against another -- and nothing here changes it. What it is not is
## something to put in front of somebody playing. In the pack's pixel font the
## brackets are bare vertical strokes and the comma reads as a full stop, so the
## line above was drawn on the answer panel as
## `SAYITEXT="WHAT WILL YOU TAKE FOR IT?"I`: a person could not tell the
## punctuation from the words.
##
## So there are two spellings of a choice and this is the second one. It is on
## this side of the line because it is about the reader and not about the world:
## no fact here is one the simulation has not already decided, and changing a
## word here cannot change what any run does. The split is checked --
## `tests/test_panel_sentences.gd` pins `Action.line()` and this side by side for
## the same action, so it is visible which string lives where.
##
## ## What it may say, and what it may not
##
## It may only re-word what is *in the action*. Every sentence below is the
## action's own kind and its own parameters, and nothing is read out of the
## world: not where the character is, not what is within reach, not whether any
## of it is possible. That last one is the important one. A sentence about why
## something did not happen belongs to the layer that decided it did not happen,
## and that is never this one -- see `LayerCheck.RENDER_NOTES`. This file
## describes a choice; whether the world allows it is the answer drawn on the
## row underneath.
##
## ## The punctuation it avoids
##
## No round brackets and no commas, for the reason above: the font draws the
## first as bare strokes and the second as a full stop. Ids keep the project's
## own `#7` spelling and are turned into letters the font has by
## `SproutPack.drawable()`, like every other sentence that reaches a panel.
class_name ActionSentence

## The eight ways a walk can head, in the world's own (x, z) plane: x grows east
## and z grows south, which is the same reading `render/player_controls.gd`'s
## walk keys are written in and the same one `tools/playtest.sh` walks east by.
const COMPASS := [
	"north", "north-east", "east", "south-east",
	"south", "south-west", "west", "north-west",
]

## What an empty hand is called in a sentence. The action carries "" for it --
## bare hands are a choice and not an item -- and "" in the middle of a sentence
## is a hole in it.
const BARE_HANDED := "bare-handed"

## What a half of a trade with nothing in it is called. The same word the trade
## and play panels use for the same emptiness, because section 2.1's gift is a
## trade with nothing in return and it has to read as a half rather than a blank.
const NOTHING := "nothing"


## One chosen action, as a sentence. "" for no choice at all.
##
## Pure: the same action gives the same sentence, on any machine, with no world
## anywhere. That is what lets a test pin all fifteen rows headless.
static func of(chosen: Action) -> String:
	if chosen == null:
		return ""
	return of_choice(chosen.kind, chosen.params)


## The same, from the two things an action is made of.
##
## Taken apart so a test can write a shape the constructors do not offer --
## a `go_to` with neither key, an `attack` with no item -- without building a
## malformed `Action` to do it.
static func of_choice(kind: String, params: Dictionary) -> String:
	match kind:
		ActionCatalog.GO_TO:
			return _walk(params)
		ActionCatalog.JUMP:
			return "leaps to %s" % _place(params.get("target", null))
		ActionCatalog.ATTACK:
			var weapon := String(params.get("item", ""))
			return "attacks %s %s" % [
				_whom(params),
				BARE_HANDED if weapon == "" else "with %s" % _named(weapon)]
		ActionCatalog.SAY:
			return _speech(params)
		ActionCatalog.TRADE_PROPOSE:
			return "offers %s %s for %s" % [
				_whom(params),
				_worth(params, "give", "give_money"),
				_worth(params, "want", "want_money"),
			]
		ActionCatalog.TRADE_ACCEPT:
			return "accepts the offer from %s" % _whom(params)
		ActionCatalog.TRADE_DENY:
			return "turns down the offer from %s" % _whom(params)
		ActionCatalog.PICK_UP:
			if _has_target(params):
				return "takes %s out of %s" % [_item(params), _whom(params)]
			return "picks up %s" % _item(params)
		ActionCatalog.DROP:
			if _has_target(params):
				return "puts %s into %s" % [_item(params), _whom(params)]
			return "drops %s" % _item(params)
		ActionCatalog.EXAMINE:
			return "looks at %s" % _examined(params)
		ActionCatalog.INTERACT:
			if String(params.get("item", "")) == "":
				return "interacts with %s" % _whom(params)
			return "uses %s on %s" % [_item(params), _whom(params)]
		ActionCatalog.WAIT:
			return "waits %s" % _ticks(int(params.get("ticks", 0)))
		ActionCatalog.EQUIP:
			return "puts on %s" % _item(params)
		ActionCatalog.UNEQUIP:
			return "takes off %s" % _item(params)
		ActionCatalog.USE:
			return "uses up %s" % _item(params)
	# A kind this file has no sentence for is quoted in the simulation's own
	# spelling rather than described in a guess. There is no such kind today --
	# the fifteen above are the whole catalogue and `tests/test_panel_sentences.gd`
	# checks that they are -- so this is what a sixteenth would read as until
	# somebody wrote its sentence.
	return Action.of(kind, params).line()


## Which of the eight ways an offset heads. Public because the walk sentence is
## the one of the fifteen that turns a pair of numbers into a word, and a test
## that pins the word should be able to ask for it directly.
static func heading_of(offset: Vector2) -> String:
	if offset == Vector2.ZERO:
		return COMPASS[0]
	# Screen-north is -z, and the compass runs clockwise from it: the angle from
	# north, in eighths of a turn, rounded to the nearest one.
	var turns := atan2(offset.x, -offset.y) / TAU
	var eighth := int(roundf(fposmod(turns, 1.0) * COMPASS.size())) % COMPASS.size()
	return COMPASS[eighth]


# --- The parts a sentence is built out of ---------------------------------


# A walk, in whichever of the two spaces the caller named a place in. Which one
# is the name of the key it was given under -- `ActionCatalog`'s own reading --
# so this asks the parameters rather than guessing from the value.
static func _walk(params: Dictionary) -> String:
	var offset: Variant = params.get("offset", null)
	if offset is Vector2:
		var way: Vector2 = offset
		return "walks %.1f to the %s" % [way.length(), heading_of(way)]
	var target: Variant = params.get("target", null)
	if target is Vector2:
		return "walks to %s" % _place(target)
	return "walks over to %s" % _whom(params)


# What was said, and whether it was said to somebody or to everybody. Section
# 2.1 spells the action "say (text; targeted, or shout -> everyone in range
# hears)", and the two shapes read as two different things a person does.
static func _speech(params: Dictionary) -> String:
	var words := String(params.get("text", ""))
	if _has_target(params):
		return "says to %s \"%s\"" % [_whom(params), words]
	return "shouts \"%s\"" % words


# Whatever is being examined, which is the one target the catalogue lets be
# either an id or a name.
static func _examined(params: Dictionary) -> String:
	var target: Variant = params.get("target", null)
	if target is String:
		return _named(String(target))
	return _whom(params)


# One half of a trade: what goes across, and what it is worth in coin.
static func _worth(params: Dictionary, items_key: String, money_key: String) -> String:
	var written := PackedStringArray()
	for one in PackedStringArray(params.get(items_key, PackedStringArray())):
		written.append(_named(one))
	var money := int(params.get(money_key, 0))
	if money > 0:
		written.append(_coins(money))
	# " and " rather than the comma the trade and play panels join a half with:
	# a half in a panel is a list to scan and a half in a sentence is a clause to
	# read, and the font draws a comma as a full stop.
	return NOTHING if written.is_empty() else " and ".join(written)


# A character or a thing, by the id the world knows it by, in the project's own
# spelling. `SproutPack.drawable()` is what turns the hash into letters the
# font has, on the panel that draws it.
static func _whom(params: Dictionary) -> String:
	return "#%d" % int(params.get("target", ActionCatalog.NOBODY))


static func _has_target(params: Dictionary) -> bool:
	return int(params.get("target", ActionCatalog.NOBODY)) != ActionCatalog.NOBODY


# The item an action names, or bare hands.
static func _item(params: Dictionary) -> String:
	return _named(String(params.get("item", "")))


# A named thing, with the article a person would say it with. "" cannot happen
# on any path that reaches here except a malformed action, and it reads as bare
# hands there for the same reason it does everywhere else.
static func _named(thing: String) -> String:
	return BARE_HANDED if thing == "" else "the %s" % thing


# A place in the world, written without the brackets and the comma the font
# cannot draw.
static func _place(where: Variant) -> String:
	if not (where is Vector2):
		return NOTHING
	var at: Vector2 = where
	return "the spot %.1f by %.1f" % [at.x, at.y]


static func _coins(money: int) -> String:
	return "1 coin" if money == 1 else "%d coins" % money


static func _ticks(ticks: int) -> String:
	return "1 tick" if ticks == 1 else "%d ticks" % ticks
