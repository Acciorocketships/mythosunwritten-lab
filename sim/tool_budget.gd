extends RefCounted
## What an ask that costs the world no time costs a character.
##
## Twelve of the thirteen things a mind may answer with are actions, and every
## one of them costs the character a span of ticks: the `occupies` column of
## `ActionCatalog.ROWS`, spent standing in the world before anything happens. The
## other three -- `recall`, `learn` and `done`, the tools `ModelPrompt` offers
## beside the menu -- cost nothing at all. They touch what the character
## remembers and what it is after, they return on the tick they are asked, and
## the world is exactly as it was afterwards.
##
## That is a hole and it has been measured. On one 3,000-tick run of the shipped
## world a cheap local model spent 4,711 of its 4,854 turns on `recall`; four of
## the five characters made about 1,177 calls each and resolved not one action in
## the whole run. Nothing was wrong with the answers -- three of the four were
## told "0 things came back" every single time and asked again anyway. Nothing
## had to go wrong: an ask that costs no world time leaves the character standing
## in front of the same world it was standing in front of before, so the next
## question is the same question and the same answer comes back for as long as
## anybody keeps asking.
##
## ## The rule
##
## A character may make `FREE` asks of this kind between the *actions* it takes.
## One past that is refused in the world's own words, and *that* one costs it a
## turn: the world counts the turn (`ActionScene.note_action`, the same count a
## refused action moves) and the character stands for `costs()` ticks before it
## may choose again. Then it is asked as usual. One turn, and not the rest of the
## run.
##
## The free ones come back when the character takes a turn on an *action* --
## carried out or refused, the world does not mind which -- and not when it pays
## for a look. That is the whole difference between a guard that bounds the loop
## and one that only slows it down: with the free asks restored by the payment
## itself a mind that only looks still gets `FREE + 1` questions per span, which
## on the run that found this hole was a quarter off the bill and no more. As it
## stands, a mind that has stopped acting gets one question per span and pays a
## turn for every one of them, and a mind that acts is not touched at all: two
## looks after every action is more than the shipped model has ever used.
##
## So the tool is not taken away and nothing is added: past the budget it simply
## costs what looking costs.
##
## ## Why a budget rather than showing the character its own answer
##
## The other shape considered was feeding what a recall turned up back into what
## the character sees, so that a repeat would be visibly the same answer. Half of
## that already exists -- `ModelMind` keeps the lines a recall found and
## `ModelPrompt.memory_lines` prints them in the very next prompt -- and the run
## that found the hole is what it looks like when it is not enough: the model was
## shown "looked back for \"lately\": 0 things" and asked for the same thing
## again, one thousand one hundred and seventy-seven times. Making an answer
## visible relies on the mind reading it. A budget does not: it is arithmetic the
## world does, and it holds for a mind that reads nothing.
##
## ## Why the cost is what it is
##
## `costs()` is not a new number. It is what the catalogue already charges for
## `examine` -- the action that is looking at something -- because looking back
## through your own memory is the same shape of turn as looking at what is in
## front of you, and the world should not charge two different prices for a look.
##
## `FREE` is a choice and there is no deriving it: two asks between turns is
## enough to look something up and then follow it up, which is what section 10's
## "optional tool for querying older ones" is for, and few enough that a mind
## that only looks cannot outrun the world.
##
## ## It is the world's rule and not one mind's
##
## Nothing here knows what is deciding for the character. `asked()` takes the
## scene and the character, reads the world's own ledger and writes the world's
## own ledger; `free_to_choose()` is read by `ControlLoop` before it asks
## *anybody* anything. A person's hand on the same door gets the same sentence,
## pays the same turn and stands the same four ticks -- `sim/scripted_asks.gd`
## runs the three kinds of mind side by side and prints what each was told.
class_name ToolBudget

## How many asks that cost the world no time a character may make between the
## turns it spends.
const FREE := 2


## What one of those asks costs the character once the free ones are gone, in
## ticks: what the catalogue charges for `examine`, which is the action that is
## looking at something.
static func costs() -> int:
	return ActionCatalog.occupies_of(ActionCatalog.EXAMINE)


## One character asking the world for something that costs the world no time.
##
## Answers `{"allowed": bool, "why": String, "taken": int, "free": int,
## "until": int}` -- whether it may, the world's sentence when it may not, how
## many it has now made since it last spent a turn, how many were free, and the
## tick it stands until when this one cost it a turn.
##
## Whoever is deciding for the character calls this before carrying the ask out.
## The refusal is the world's and the caller does not phrase it.
##
## Asking again while standing out a turn one of these already cost is refused
## too, and charges nothing further: the cost of an ask past the budget is one
## turn, and asking twenty times over does not make it twenty.
static func asked(scene: ActionScene, actor: Combatant) -> Dictionary:
	if scene == null or actor == null:
		return {"allowed": true, "why": "", "taken": 0, "free": FREE, "until": 0}
	if not free_to_choose(scene, actor.id):
		return {
			"allowed": false, "taken": scene.asks_of(actor.id), "free": FREE,
			"until": scene.spent_until_of(actor.id),
			"why": "%s is standing out the turn its last ask cost it, until tick %d" % [
				ActionScene.name_of(actor), scene.spent_until_of(actor.id),
			],
		}
	var taken := scene.asks_of(actor.id) + 1
	scene.note_ask(actor.id)
	if taken <= FREE:
		return {"allowed": true, "why": "", "taken": taken, "free": FREE, "until": 0}
	var until := scene.tick + costs()
	var why := "%s has already asked %d things of no world time since it last acted; this one costs it a turn" % [
		ActionScene.name_of(actor), FREE,
	]
	scene.note_action(actor.id)
	scene.keep_asks(actor.id, FREE)
	scene.note_ask_spent(actor.id, until, why)
	return {"allowed": false, "why": why, "taken": taken, "free": FREE, "until": until}


## Whether a character may be asked for a choice at all, or is standing out the
## turn one of those asks cost it.
##
## `ControlLoop` reads this before it asks anybody anything, so a character that
## spent a turn this way stands exactly as one that spent a turn on an action
## the engine refused, and is asked again when the span runs out.
static func free_to_choose(scene: ActionScene, id: int) -> bool:
	return scene == null or scene.tick >= scene.spent_until_of(id)
