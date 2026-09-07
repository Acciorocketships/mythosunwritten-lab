extends RefCounted
## What the world does for a character every time it services one, whoever is
## deciding for it.
##
## The character sheet declares two stores for *every* character -- what it
## remembers (`Character.memory`) and what it is after (`Character.goals`) --
## and section 1 says a person's character and a program's character differ in
## one thing only, the decision function on the sheet. A store filled on one
## driver's path and not on another's breaks that: the character with the richer
## driver would end the run remembering more and wanting less, and no amount of
## sameness above the seam would make up for it.
##
## The world holds a third store for the same reason and with more force: section
## 10's relationship graph, which is not on any sheet at all. It is the world's
## record of what has passed between two characters, section 6's ownership maths
## reads it, and a graph that filled only along one driver's path would hand that
## maths a map of who has the better brain rather than of who did what.
##
## So the three are maintained here, on a path both drivers pass:
## `ControlLoop.step()` runs this for every character it services, and
## `DecisionSource.drive()` runs it before every choice it asks for. Neither
## looks at what is on `Character.decide` and there is nothing here to look at
## it with -- this file names no decision function, no mind and no channel.
##
## ## It decides *when*, never *what*
##
## Three calls, and every one of them is somebody else's answer:
##
##   * `GoalCheck.settle()` reads the scene and closes the goals the world's own
##     state says are finished. Every comparison in it is the goal's own number
##     or the engine's own; this file supplies none.
##   * `CharacterMemory.witness()` writes down whatever is new in an
##     `Observation` of that character's own surroundings. What an observation
##     holds is `sim/observation.gd`'s business and what is worth writing down is
##     `sim/character_memory.gd`'s.
##   * `RelationshipGraph.heard/traded/struck()` move the edges between whoever
##     something has just passed between. Which field a blow moves, and by how
##     much, is `sim/relationship_graph.gd`'s and there is not a number of it
##     here; what is here is the reading of the world's three records that says a
##     blow happened at all.
##
## What is left for this file is the cadence, which is the one thing a store's
## own file cannot know: how often the world gets round to a character.
##
## ## The cadence, and why it is this one
##
## **A character is settled with every servicing, and takes in its surroundings
## once for every action of its own the world has carried out.**
##
## Settling is a reading of the world -- the same reading `GoalCheck` would give
## at any moment -- so it happens whenever the character is serviced, and a goal
## the world already answers true closes at that character's very first
## servicing rather than whenever somebody next thinks to ask.
##
## Witnessing costs an observation, so it happens at a stated cadence, and the
## count it is keyed to is the world's own: `ActionScene.actions_taken`, which
## `ActionEngine` writes on the one path every action goes through. A character
## looks around before it commits to something, which is section 10's loop --
## observe, retrieve, then act -- and one look per thing done is what that comes
## to. The first servicing counts as one: a character that has not done anything
## yet has still arrived somewhere and can see it.
##
## **The graph takes in everything the world has written down since it was last
## looked at, at every servicing.** Not once per character and not once per
## character *pair*: a happening has two ends and folding it per character would
## fold it twice, so what is folded is the world's own three records --
## `ActionScene.said`, `.trades` and `.blows` -- from wherever the graph had got
## to, and the mark saying where that is lives on the graph. That is what makes
## it come to the same thing whoever is serviced, in whichever order, however
## many upkeeps a run happens to make: one thing that happened is one move of one
## edge. A character nobody ever services still has its edges kept, because the
## edges were never its to keep.
##
## The look lands at a *servicing*, which means an action that is carried out
## part-way through one is looked up from at the next: the count moves when
## `ActionEngine` resolves the action, and the character is served again on its
## next tick. That is a tick of lag in the log and nothing else -- the packet a
## character is handed is always read at the moment it is asked -- and it is the
## price of the cadence being a rule about servicings rather than a hook hung on
## the engine, which would put a driver's business inside the resolver.
##
## It is deliberately *not* once per question put to a decision function, which
## is where the witness call used to live. How often a character is asked is a
## fact about its driver and not about the world: a mind waiting for a model is
## asked again every tick while its call is outstanding, a plan is asked again
## every `ControlLoop.REVIEW_EVERY` ticks while its character walks, and a person
## will be asked whenever a person looks at the screen. Keyed to questions, what
## a character remembers would be a readout of which driver it has -- which is
## the very thing this file exists to stop.
class_name CharacterUpkeep

## What is watching each character for the "recently changed" part of an
## observation. Optional: with none, that part of the packet is absent with its
## own stated reason, exactly as it is anywhere else an observation is taken
## without one.
var trail: ObservationTrail = null

## How many times a character has been shown its surroundings, and how many
## lines that came to. What a run prints when it wants to say the store was
## maintained rather than assert it.
var witnesses: int = 0
var written: int = 0

## How many goals the world has closed here, over everybody.
var settled: int = 0

## How many edge-moves this upkeep has folded into the world's relationship
## graph. What a run prints when it wants to say the graph was maintained here
## rather than assert it.
var folded: int = 0

# The world's count of actions carried out for a character, as it stood the last
# time that character was shown its surroundings. Keyed by the scene's own id.
var _witnessed_after: Dictionary = {}


## An upkeep reading a trail, or none.
static func watching(watched: ObservationTrail = null) -> CharacterUpkeep:
	var upkeep := CharacterUpkeep.new()
	upkeep.trail = watched
	return upkeep


## Maintain all three stores, and say what that came to:
## `{"closed": Array, "witnessed": bool, "wrote": int, "moved": int}`.
##
## Called by a driver before it asks the character what it does next, so that
## what the character is shown is what it still wants, and what it remembers
## includes where it is standing now.
##
## The graph is brought up to date first and unconditionally -- before the sheet
## is even looked for -- because it is the world's and not this character's: a
## combatant with no sheet at all still passes through here, and everything that
## has happened in the world is still to be taken in.
func serve(scene: ActionScene, actor: Combatant) -> Dictionary:
	var nothing := {
		"closed": [] as Array[Dictionary], "witnessed": false, "wrote": 0, "moved": 0,
	}
	if scene == null or actor == null:
		return nothing
	var moved := fold(scene)
	nothing["moved"] = moved
	var sheet := _sheet_of(actor)
	if sheet == null:
		return nothing
	var closed := GoalCheck.settle(sheet.goals, scene, actor)
	settled += closed.size()
	if not _due(scene, actor):
		return {"closed": closed, "witnessed": false, "wrote": 0, "moved": moved}
	_witnessed_after[actor.id] = scene.actions_of(actor.id)
	var wrote := 0
	if sheet.memory != null:
		wrote = sheet.memory.witness(Observation.of(scene, actor, trail))
	witnesses += 1
	written += wrote
	return {"closed": closed, "witnessed": true, "wrote": wrote, "moved": moved}


## Fold everything the world has written down since the graph last looked into
## the graph, and say how many edge-moves that came to.
##
## The three loops below are the whole of it, and each of them reads one of the
## world's own records from the mark the graph itself carries. Nothing here
## decides what a happening *means*: every call is `RelationshipGraph`'s, and
## every number is that file's or the world's.
##
## A line of speech moves one edge per listener, because a shout heard by four
## people is four people who have now heard this character speak; the engine
## already worked out who those are and wrote them into `heard_by`, and there is
## no second opinion about earshot here any more than there is in an observation.
func fold(scene: ActionScene) -> int:
	if scene == null:
		return 0
	var graph := scene.relationships
	if graph == null:
		return 0
	var moved := 0
	while graph.heard_taken < scene.said.size():
		var spoken: Dictionary = scene.said[graph.heard_taken]
		graph.heard_taken += 1
		for listener in PackedInt32Array(spoken["heard_by"]):
			if graph.heard(
				int(spoken["speaker"]), int(listener), String(spoken["text"]),
				bool(spoken["shout"])
			) != null:
				moved += 1
	while graph.traded_taken < scene.trades.size():
		var swapped: Dictionary = scene.trades[graph.traded_taken]
		graph.traded_taken += 1
		if graph.traded(
			int(swapped["from"]), int(swapped["to"]),
			int(swapped.get("gave", 0)), int(swapped.get("gave_money", 0)),
			int(swapped.get("back", 0)), int(swapped.get("back_money", 0))
		) != null:
			moved += 1
	while graph.struck_taken < scene.blows.size():
		var blow: Dictionary = scene.blows[graph.struck_taken]
		graph.struck_taken += 1
		# A swing that found nobody is on the world's record -- something happened
		# and whatever draws the world draws it -- but it is nothing between two
		# people, and there is nobody for the other end of an edge.
		if int(blow["to"]) == ActionScene.NOBODY:
			continue
		if graph.struck(
			int(blow["from"]), int(blow["to"]),
			int(blow["dealt"]), int(blow["out_of"])
		) != null:
			moved += 1
	folded += moved
	return moved


## How many actions the world had carried out for a character the last time it
## was shown its surroundings, or -1 for a character that never has been.
func witnessed_after(id: int) -> int:
	return int(_witnessed_after.get(id, -1))


# Whether this character is due a look: it has never had one, or the world has
# carried something out for it since the last one. See the cadence note above.
func _due(scene: ActionScene, actor: Combatant) -> bool:
	return witnessed_after(actor.id) != scene.actions_of(actor.id)


# The character sheet behind a combatant, or null for anything that keeps none.
# The two stores are the sheet's, so a thing without one has nothing to maintain.
static func _sheet_of(actor: Combatant) -> Character:
	if actor == null or actor.piece == null or not (actor.piece is Commander):
		return null
	return (actor.piece as Commander).sheet
