extends RefCounted
## One chosen atomic action: what a decision function returns, and the whole of
## what it returns.
##
## This is a *choice*, not an outcome. Nothing here reaches the world, reads a
## position, checks a distance or decides whether the thing chosen is possible --
## an `Action` naming a jump across a chasm and an `Action` naming a step to the
## next cell are the same sort of object and are both perfectly well-formed. What
## is possible is `ActionEngine`'s answer, given a world; keeping the two apart
## is what lets a human's choice and a machine's choice be the same value and be
## resolved by the same code.
##
## There is one constructor per row of `ActionCatalog.ROWS`, named for that row,
## and `ActionCatalog.faults()` fails if this file grows one that is not an
## action or loses one that is.
##
## ## Targets are ids, and there is one id space
##
## `target` names a character or an object by the id the scene gave it -- both
## out of one counter, so an id is a thing and the caller never has to say which
## sort of list it came from. `go_to` also takes a position instead, and
## `examine` also takes the name of something carried; both are in the catalogue
## as the sorts those parameters accept, and a target of the wrong sort is
## refused by `ActionCatalog.fault()` before the world is consulted.
##
## ## Two shapes of `go to`, because a place can be named in two spaces
##
## Section 10 spells the row four ways and one of them is `MoveRelative(offset)`.
## So `go_to` has two constructors rather than one: `go_to()` names a place in
## the world's own coordinates, and `go_to_offset()` names it from wherever the
## character is standing. They build one action of one kind, differing in the
## key the place is written under, and the catalogue refuses a choice carrying
## both keys or neither. Nothing here works out what an offset comes to -- that
## needs a character standing somewhere, and where a character is standing is the
## engine's to know.
class_name Action

## An absent target: shouting names nobody, and dropping on the ground goes into
## nothing.
const NOBODY := ActionCatalog.NOBODY

## Which action this is: one of `ActionCatalog`'s names.
var kind: String = ""

## What it was chosen with, by the parameter names the catalogue's row declares.
var params: Dictionary = {}


## An action of a kind with its parameters. The constructors below are
## all this, and callers use them rather than this, because a name spelled wrong
## here is caught at the catalogue and a name spelled wrong there is caught by
## the engine that does not exist.
static func of(action_kind: String, with: Dictionary = {}) -> Action:
	var chosen := Action.new()
	chosen.kind = action_kind
	chosen.params = with
	return chosen


## Every action, and the one constructor that chooses it.
##
## The choosing half of the one list. `ActionCatalog.faults()` reads these keys
## against the catalogue's rows and against `ActionEngine.resolvers()`, so an
## action that is listed and cannot be chosen, or can be chosen and is not
## listed, is a failing check rather than a surprise at run time.
static func constructors() -> Dictionary:
	return {
		ActionCatalog.GO_TO: Action.go_to,
		ActionCatalog.JUMP: Action.jump,
		ActionCatalog.ATTACK: Action.attack,
		ActionCatalog.SAY: Action.say,
		ActionCatalog.TRADE_PROPOSE: Action.trade_propose,
		ActionCatalog.TRADE_ACCEPT: Action.trade_accept,
		ActionCatalog.TRADE_DENY: Action.trade_deny,
		ActionCatalog.PICK_UP: Action.pick_up,
		ActionCatalog.DROP: Action.drop,
		ActionCatalog.EXAMINE: Action.examine,
		ActionCatalog.INTERACT: Action.interact,
		ActionCatalog.WAIT: Action.wait,
		ActionCatalog.EQUIP: Action.equip,
		ActionCatalog.UNEQUIP: Action.unequip,
		ActionCatalog.USE: Action.use,
	}


## The constructors that build a second *shape* of a row rather than a row of
## their own, and the row each one builds.
##
## `constructors()` above is one per row, which is what `ActionCatalog.faults()`
## reads and what makes a thirteenth verb impossible. A row with more than one
## shape needs more than one constructor even so -- `go_to` names a place in
## either of two spaces and there is a constructor for each -- and this is where
## the extras are declared, so that anything reading constructor names off this
## file can tell a second shape of an action from a verb nobody listed.
static func shapes() -> Dictionary:
	return {"go_to_offset": ActionCatalog.GO_TO}


# --- One constructor per row of the one list ------------------------------


## Go to a position, an item or a character: a `Vector2` of world x and z, or the
## id of anything in the scene.
static func go_to(target: Variant) -> Action:
	return of(ActionCatalog.GO_TO, {"target": target})


## Go the same distance again from wherever the character is standing: a
## `Vector2` of world units east and south of it. Section 10's
## `MoveRelative(offset)`, and the same row of the one list as `go_to`.
static func go_to_offset(offset: Vector2) -> Action:
	return of(ActionCatalog.GO_TO, {"offset": offset})


## Jump to a position. How far is the character's DEX to say.
static func jump(target: Vector2) -> Action:
	return of(ActionCatalog.JUMP, {"target": target})


## Attack a character with a named item. Which of the item's attacks is used is
## not chosen here -- section 10 says the attack mode is "derived from item", and
## the engine derives it.
static func attack(target: int, item: String) -> Action:
	return of(ActionCatalog.ATTACK, {"target": target, "item": item})


## Say something, to one character or -- with no one named -- to everyone in
## range, which is the shout.
static func say(text: String, target: int = NOBODY) -> Action:
	if target == NOBODY:
		return of(ActionCatalog.SAY, {"text": text})
	return of(ActionCatalog.SAY, {"text": text, "target": target})


## Offer a trade: items and money out, items and money back. Section 2.1 defines
## giving as "a trade with nothing in return", so a gift is this with `want`
## empty and `want_money` zero, and there is no second call for it.
static func trade_propose(
	target: int,
	give: PackedStringArray = PackedStringArray(),
	give_money: int = 0,
	want: PackedStringArray = PackedStringArray(),
	want_money: int = 0,
) -> Action:
	return of(ActionCatalog.TRADE_PROPOSE, {
		"target": target,
		"give": give, "give_money": give_money,
		"want": want, "want_money": want_money,
	})


## Accept the offer standing from a character.
static func trade_accept(target: int) -> Action:
	return of(ActionCatalog.TRADE_ACCEPT, {"target": target})


## Deny the offer standing from a character.
static func trade_deny(target: int) -> Action:
	return of(ActionCatalog.TRADE_DENY, {"target": target})


## Pick a named item up, out of a named container or -- with nothing named --
## off the ground within reach.
static func pick_up(item: String, target: int = NOBODY) -> Action:
	if target == NOBODY:
		return of(ActionCatalog.PICK_UP, {"item": item})
	return of(ActionCatalog.PICK_UP, {"item": item, "target": target})


## Drop a named item into a named container or -- with nothing named -- on the
## ground.
static func drop(item: String, target: int = NOBODY) -> Action:
	if target == NOBODY:
		return of(ActionCatalog.DROP, {"item": item})
	return of(ActionCatalog.DROP, {"item": item, "target": target})


## Examine something in sight: a character or object by id, or something carried
## by name.
static func examine(target: Variant) -> Action:
	return of(ActionCatalog.EXAMINE, {"target": target})


## Interact with an object, optionally using a named item -- the lockpick case.
static func interact(target: int, item: String = "") -> Action:
	if item == "":
		return of(ActionCatalog.INTERACT, {"target": target})
	return of(ActionCatalog.INTERACT, {"target": target, "item": item})


## Wait a number of ticks.
static func wait(ticks: int) -> Action:
	return of(ActionCatalog.WAIT, {"ticks": ticks})


## Put a carried item on: wear it, or take it in hand. Named by the item, as
## every other action that reaches into an inventory is, so a caller addresses
## what it can read rather than a slot it has to work out.
static func equip(item: String) -> Action:
	return of(ActionCatalog.EQUIP, {"item": item})


## Take a worn or held item off. It stays carried: taking your boots off is not
## the same as leaving them behind.
static func unequip(item: String) -> Action:
	return of(ActionCatalog.UNEQUIP, {"item": item})


## Use a carried consumable up. What it does is what its effect is worth, read
## through the user's own ability score; that it is gone afterwards is the whole
## difference between this and equipping something.
static func use(item: String) -> Action:
	return of(ActionCatalog.USE, {"item": item})


# --- Reading a chosen action ----------------------------------------------


## A parameter, or a default when it was not chosen.
func param(key: String, fallback: Variant = null) -> Variant:
	return params.get(key, fallback)


## The target as an id, or `NOBODY`.
func target_id() -> int:
	var target: Variant = params.get("target", NOBODY)
	return target if target is int else NOBODY


## The target as a position. Only meaningful where the catalogue says a position
## is one of the sorts the target may be.
func target_position() -> Vector2:
	var target: Variant = params.get("target", Vector2.ZERO)
	return target if target is Vector2 else Vector2.ZERO


## The target as a name, or "".
func target_name() -> String:
	var target: Variant = params.get("target", "")
	return target if target is String else ""


## Whether the target is a position rather than an id or a name.
func targets_a_position() -> bool:
	return params.get("target", null) is Vector2


## Whether the target is a name rather than an id or a position.
func targets_a_name() -> bool:
	return params.get("target", null) is String


## Whether the place was named from where the character is standing rather than
## from the world's origin.
func names_an_offset() -> bool:
	return params.get("offset", null) is Vector2


## The offset the place was named by, or a zero one. Only meaningful where the
## catalogue says the action takes an offset.
func offset() -> Vector2:
	var named: Variant = params.get("offset", Vector2.ZERO)
	return named if named is Vector2 else Vector2.ZERO


## The chosen action in one line, in the form the transcripts and the tests
## compare. Parameters are written in the catalogue row's own order -- required
## first, then optional -- so two equal choices print equal lines.
func line() -> String:
	var row := ActionCatalog.row_of(kind)
	if row.is_empty():
		return "%s(?)" % kind
	var written := PackedStringArray()
	for key in row["params"]:
		written.append("%s=%s" % [key, _value_line(params.get(key, null))])
	for key in ActionCatalog.either_of(row):
		if params.has(key):
			written.append("%s=%s" % [key, _value_line(params[key])])
	for key in row["optional"]:
		if params.has(key):
			written.append("%s=%s" % [key, _value_line(params[key])])
	return "%s(%s)" % [kind, " ".join(written)]


# How one parameter prints. Positions are written at fixed precision so a
# transcript does not depend on how floats happen to print.
static func _value_line(value: Variant) -> String:
	if value == null:
		return "-"
	if value is Vector2:
		return "(%.3f, %.3f)" % [value.x, value.y]
	if value is PackedStringArray:
		return "[%s]" % ", ".join(value)
	return str(value)
