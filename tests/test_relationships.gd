extends TestSuite
## Relationships live on edges between entities, held by the world, moved only by
## things that actually happened in it.
##
## Seven claims:
##
##   1. **An edge is one record between two entities.** The same object comes
##      back whichever end it is asked from, one happening makes one edge, and a
##      world serviced in one order is byte-for-byte the world serviced in the
##      other.
##   2. **Each field is moved by a happening, by the rule written down.** Words
##      heard, a trade honoured, a gift given and a blow struck are each played
##      through the engine and each field's new value is asserted against the
##      rule at the head of `sim/relationship_graph.gd`. Words move familiarity
##      and nothing else; an offer and a denial move nothing at all.
##   3. **The sentiment term is the stated composite.** It is
##      $\mathrm{familiarity} \times (\mathrm{trust} - \mathrm{fear})$, respect is
##      not in it, and moving respect alone does not move it.
##   4. **The world maintains them, whoever is deciding.** The three writers are
##      called from `sim/character_upkeep.gd` and from nowhere else under `sim/`
##      -- shown with a scan that is made to catch a planted call -- and a
##      character with no decision function at all still has its edges kept.
##   5. **A model may not write one.** No file of the three model-facing layers
##      names the graph; the operations table has no such operation, so a line
##      naming one reads as nothing and is refused by the engine in its own
##      words; and no action or tool of the character prompt names one either.
##   6. **A character sees its own edges and no others.** `edges_of` hands back
##      only edges the character is an end of, and the observation packet's test
##      for whether it knows a name reads the graph.
##   7. **The shipped run shows it.** On the run `./run_agent.sh` prints, the
##      character driven by written-down choices holds edges with numbers on
##      them, of the same order as the model-driven ones.
class_name TestRelationships

## The directory the structural scans read, all of it.
const SIM_DIR := "res://sim"

## The one file allowed to move an edge, and the one file allowed to hold the
## rules for how far.
const THE_SHARED_PATH := "res://sim/character_upkeep.gd"
const THE_RULES := "res://sim/relationship_graph.gd"

## How a line of code moves a relationship, matched against code with comments
## and string literals stripped.
const MOVES_AN_EDGE := [".heard(", ".traded(", ".struck("]

## What a planted call looks like: the shape a driver would use if it kept the
## graph itself. The scan has to catch this for its silence to mean anything.
const PLANTED_MOVE := "	scene.relationships.struck(one.id, other.id, 1, 10)"

## The layers a model's answer is read in. None of them may name the graph.
const MODEL_FACING := [
	"res://sim/model_mind.gd",
	"res://sim/model_prompt.gd",
	"res://sim/model_cast.gd",
	"res://sim/model_channel.gd",
	"res://sim/orchestrator.gd",
	"res://sim/orchestrator_prompt.gd",
	"res://sim/check_prompt.gd",
	"res://sim/check_desk.gd",
	"res://sim/ability_check.gd",
]

## How a line of code would name the graph at all.
const NAMES_THE_GRAPH := ["RelationshipGraph", "RelationshipEdge", "relationships"]

## The line a model might answer with if it wanted to write an edge itself.
const AN_EDGE_WRITING_ANSWER := "relate target=#2 trust=1.0 fear=0.0"

## Where the suite stands its characters, and what they carry.
const ROOK_AT := Vector2(0.0, 0.0)
const WREN_AT := Vector2(1.5, 0.0)
const MOTT_AT := Vector2(6.0, 0.0)
const MONEY := 30
const LANTERN := "brass lantern"

## How close two numbers have to be to count as the same.
const CLOSE := 0.0005


func _init() -> void:
	suite_name = "relationships"


func run() -> void:
	_an_edge_is_one_record_between_two()
	_every_field_is_moved_by_a_happening()
	_the_sentiment_term_is_the_stated_composite()
	_the_world_maintains_them_whoever_decides()
	_a_model_may_not_write_one()
	_a_character_sees_its_own_edges_only()
	_the_shipped_run_shows_it()


# --- 1. One record between two --------------------------------------------


func _an_edge_is_one_record_between_two() -> void:
	var graph := RelationshipGraph.new()
	equal(graph.size(), 0, "a fresh graph already has an edge in it")
	check(not graph.knows(1, 2), "two who have never met are said to know each other")
	equal(graph.between(1, 2), null, "an edge exists before anything happened")

	graph.heard(1, 2, "good morning", false)
	equal(graph.size(), 1, "one happening between two made more than one edge")

	var from_one := graph.between(1, 2)
	var from_two := graph.between(2, 1)
	check(from_one != null, "the edge cannot be reached from the end that spoke")
	check(is_same(from_one, from_two),
		"the two ends read different objects, so the edge is inside a character"
		+ " rather than between two")
	check(graph.knows(1, 2) and graph.knows(2, 1),
		"having met is not answered the same way from both ends")
	equal(from_one.low, 1, "the edge does not put the lower id first")
	equal(from_one.high, 2, "the edge does not put the higher id second")
	equal(RelationshipEdge.key_for(2, 1), RelationshipEdge.key_for(1, 2),
		"a pair named the other way round has a different key")

	# Both ends moved, and each end is read by the character it belongs to.
	check(from_one.field(1, "familiarity") > 0.0, "the speaker learned nothing")
	check(from_two.field(2, "familiarity") > 0.0, "the listener learned nothing")

	# The world does not depend on who is looked at first. Two identical worlds,
	# serviced in opposite orders, are the same world afterwards.
	var forwards := _staged()
	var backwards := _staged()
	_play_a_greeting(forwards)
	_play_a_greeting(backwards)
	var one_way := CharacterUpkeep.new()
	for one in forwards.actors:
		one_way.serve(forwards, one)
	var other_way := CharacterUpkeep.new()
	for at in range(backwards.actors.size() - 1, -1, -1):
		other_way.serve(backwards, backwards.actors[at])
	equal(backwards.relationships.fingerprint(), forwards.relationships.fingerprint(),
		"servicing the characters in the other order gave a different graph")
	equal(one_way.folded, other_way.folded,
		"the same happenings folded to a different number of moves")

	# And folding the same world twice folds nothing twice: the mark lives on the
	# graph, so a second upkeep over the same world has nothing left to take in.
	var again := CharacterUpkeep.new()
	var was := forwards.relationships.fingerprint()
	for one in forwards.actors:
		again.serve(forwards, one)
	equal(again.folded, 0, "a second upkeep folded the same happenings again")
	equal(forwards.relationships.fingerprint(), was,
		"folding twice moved the graph, so one happening is two moves")


# --- 2. The rules ---------------------------------------------------------


func _every_field_is_moved_by_a_happening() -> void:
	_words_move_familiarity_and_nothing_else()
	_a_trade_honoured_moves_trust_and_respect()
	_a_gift_moves_the_receiver_further()
	_a_blow_moves_fear_by_what_it_took()
	_nothing_that_did_not_happen_moves_anything()


func _words_move_familiarity_and_nothing_else() -> void:
	var scene := _staged()
	var rook := _named(scene, "Rook")
	var wren := _named(scene, "Wren")
	ActionEngine.resolve(scene, rook, Action.say("good morning", wren.id))
	CharacterUpkeep.new().serve(scene, rook)

	var edge := scene.relationships.between(rook.id, wren.id)
	check(edge != null, "a line the engine says was heard moved no edge")
	_about(edge.field(rook.id, "familiarity"), RelationshipGraph.MET,
		"the speaker's familiarity is not the rule's first step")
	_about(edge.field(wren.id, "familiarity"), RelationshipGraph.MET,
		"the listener's familiarity is not the rule's first step")
	for named in ["trust", "fear", "respect"]:
		_about(edge.field(rook.id, named), 0.0,
			"talking moved the speaker's %s, which section 6 says is a check" % named)
		_about(edge.field(wren.id, named), 0.0,
			"talking moved the listener's %s, which section 6 says is a check" % named)
	equal(edge.happenings, 1, "one line heard is not one happening")
	check(edge.notes.size() == 1 and edge.notes[0].contains("good morning"),
		"the summary does not carry what was said: %s" % str(edge.notes))

	# A second line closes a quarter of what is left again, and never passes 1.
	ActionEngine.resolve(scene, rook, Action.say("and again", wren.id))
	CharacterUpkeep.new().serve(scene, rook)
	var twice := RelationshipGraph.MET + (1.0 - RelationshipGraph.MET) * RelationshipGraph.MET
	_about(edge.field(rook.id, "familiarity"), twice,
		"a second line did not close a share of what was left")
	for _at in 60:
		scene.relationships.heard(rook.id, wren.id, "on and on", false)
	check(edge.field(rook.id, "familiarity") <= 1.0,
		"familiarity passed 1, so a rule can leave the range")

	# A shout is one move per listener the engine says heard it, and no more.
	var loud := _staged()
	var shouter := _named(loud, "Rook")
	ActionEngine.resolve(loud, shouter, Action.say("anyone about?"))
	var heard: PackedInt32Array = loud.said[0]["heard_by"]
	var moved := int(CharacterUpkeep.new().serve(loud, shouter)["moved"])
	equal(moved, heard.size(),
		"a shout moved a different number of edges than the engine says heard it")
	equal(loud.relationships.size(), heard.size(),
		"a shout made an edge with somebody the engine did not say heard it")


func _a_trade_honoured_moves_trust_and_respect() -> void:
	var scene := _staged()
	var rook := _named(scene, "Rook")
	var wren := _named(scene, "Wren")
	_trade(scene, rook, wren, 5, 4)

	var edge := scene.relationships.between(rook.id, wren.id)
	check(edge != null, "a trade the engine honoured moved no edge")
	for end in [rook.id, wren.id]:
		_about(edge.field(end, "trust"), RelationshipGraph.TRADE_TRUST,
			"an exchange did not move #%d's trust by the rule" % end)
		_about(edge.field(end, "respect"), RelationshipGraph.TRADE_RESPECT,
			"an exchange did not move #%d's respect by the rule" % end)
		_about(edge.field(end, "familiarity"), RelationshipGraph.MET,
			"an exchange did not move #%d's familiarity by the rule" % end)
		_about(edge.field(end, "fear"), 0.0, "an even exchange frightened #%d" % end)


func _a_gift_moves_the_receiver_further() -> void:
	var scene := _staged()
	var rook := _named(scene, "Rook")
	var wren := _named(scene, "Wren")
	_trade(scene, rook, wren, 5, 0)

	var edge := scene.relationships.between(rook.id, wren.id)
	var evenly := RelationshipGraph.TRADE_TRUST
	var gifted := evenly + (1.0 - evenly) * RelationshipGraph.GIFT_TRUST
	_about(edge.field(wren.id, "trust"), gifted,
		"the one given something for nothing does not trust the giver further")
	_about(edge.field(rook.id, "trust"), evenly,
		"giving something away moved the giver's own trust")
	check(edge.notes[0].contains("for nothing"),
		"the summary does not say the gift was for nothing: %s" % edge.notes[0])


func _a_blow_moves_fear_by_what_it_took() -> void:
	var graph := RelationshipGraph.new()
	graph.struck(1, 2, 10, 40)
	var edge := graph.between(1, 2)
	check(edge != null, "a blow the engine landed moved no edge")
	_about(edge.field(2, "fear"), 0.25,
		"being hit for a quarter of full health is not a quarter of the fear")
	_about(edge.field(2, "respect"), RelationshipGraph.STRUCK_RESPECT,
		"being struck did not show the struck one what the other can do")
	_about(edge.field(1, "fear"), 0.0, "the one who swung is afraid of the one it hit")
	_about(edge.field(1, "respect"), 0.0, "swinging taught the striker something")
	_about(edge.field(1, "familiarity"), RelationshipGraph.MET,
		"a blow is not a meeting for the one who struck")

	# Trust falls by half of what is there, so a blow after a trade costs trust
	# without ever going below nothing.
	var after := RelationshipGraph.new()
	after.traded(1, 2, 1, 0, 1, 0)
	var trusted := after.between(1, 2).field(2, "trust")
	after.struck(1, 2, 1, 40)
	_about(after.between(1, 2).field(2, "trust"), trusted * (1.0 - RelationshipGraph.STRUCK_TRUST),
		"a blow did not take the stated share of the struck one's trust")
	for _at in 20:
		after.struck(1, 2, 1, 40)
	check(after.between(1, 2).field(2, "trust") >= 0.0,
		"trust went below 0, so a rule can leave the range")

	# A blow struck through the engine reaches the graph on the shared path. The
	# shipped turn run is two commanders both choosing `attack`; every blow it
	# lands is written into the world's own record and folded from there.
	var fought := ScriptedTurn.played()
	var board: ActionScene = fought["scene"]
	check(int(fought["landed"]) > 0, "the shipped turn run landed no blows")
	equal(board.blows.size(), int(fought["landed"]),
		"the engine wrote down a different number of blows than the run landed")
	var struck_edge := board.relationships.between(
		int(board.blows[0]["from"]), int(board.blows[0]["to"]))
	check(struck_edge != null, "a blow landed on a run left no edge behind it")
	check(struck_edge.field(int(board.blows[0]["to"]), "fear") > 0.0,
		"the character that was struck on the run fears nobody")


func _nothing_that_did_not_happen_moves_anything() -> void:
	var scene := _staged()
	var rook := _named(scene, "Rook")
	var wren := _named(scene, "Wren")
	ActionEngine.resolve(scene, rook, Action.trade_propose(
		wren.id, PackedStringArray(), 5, PackedStringArray(), 0))
	CharacterUpkeep.new().serve(scene, rook)
	equal(scene.relationships.size(), 0,
		"an offer moved an edge, so a question counts as a thing that happened")

	ActionEngine.resolve(scene, wren, Action.trade_deny(rook.id))
	CharacterUpkeep.new().serve(scene, wren)
	equal(scene.relationships.size(), 0, "a denial moved an edge")

	# A refused action moves nothing either: the engine writes nothing down for
	# one, so there is nothing to fold.
	ActionEngine.resolve(scene, rook, Action.say("", wren.id))
	ActionEngine.resolve(scene, rook, Action.attack(wren.id, "sword"))
	CharacterUpkeep.new().serve(scene, rook)
	equal(scene.relationships.size(), 0, "a refused action moved an edge")


# --- 3. The composite -----------------------------------------------------


func _the_sentiment_term_is_the_stated_composite() -> void:
	var graph := RelationshipGraph.new()
	graph.traded(1, 2, 1, 0, 1, 0)
	var edge := graph.between(1, 2)
	var side := edge.toward(1)
	var stated := float(side["familiarity"]) * (float(side["trust"]) - float(side["fear"]))
	_about(graph.sentiment(1, 2), stated,
		"the sentiment term is not familiarity times trust less fear")
	check(graph.sentiment(1, 2) > 0.0, "an honoured trade left no sentiment at all")

	# Respect is deliberately not in it.
	var was := graph.sentiment(1, 2)
	edge.raise(1, "respect", 1.0)
	_about(edge.field(1, "respect"), 1.0, "respect did not move")
	_about(graph.sentiment(1, 2), was, "respect moved the sentiment term")

	# Fear takes it below nothing, and familiarity gates it.
	graph.struck(2, 1, 40, 40)
	check(graph.sentiment(1, 2) < 0.0,
		"being struck to nothing by somebody left a positive sentiment toward them")
	check(graph.sentiment(1, 2) >= -1.0 and graph.sentiment(1, 2) <= 1.0,
		"the sentiment term left [-1, 1]")

	var barely := RelationshipGraph.new()
	barely.heard(1, 2, "hello", false)
	barely.between(1, 2).raise(1, "trust", 1.0)
	check(absf(barely.sentiment(1, 2)) < 1.0,
		"complete trust in somebody barely met counts in full, so familiarity does"
		+ " not gate the term")

	# Two who have never met feel nothing about each other, which is the honest
	# answer rather than a missing one.
	_about(RelationshipGraph.new().sentiment(1, 2), 0.0,
		"a sentiment was read between two who have never met")

	# It is the only reading the ownership maths is offered: no other function
	# here hands back a single number to weigh a character by.
	var offered := PackedStringArray()
	for method in RelationshipGraph.new().get_script().get_script_method_list():
		var named := String(method["name"])
		if not named.begins_with("_") and int(method["return"]["type"]) == TYPE_FLOAT:
			offered.append(named)
	equal(offered, PackedStringArray(["sentiment"]),
		"the graph offers more than one number to read a relationship as")


# --- 4. Maintained by the world -------------------------------------------


func _the_world_maintains_them_whoever_decides() -> void:
	var sources := _files_under(SIM_DIR)
	check(sources.size() > 40, "the scan opened sim/ and found %d files" % sources.size())

	var movers := PackedStringArray()
	for path in sources:
		if path == THE_RULES:
			continue
		var code := _code_of(path)
		for word in MOVES_AN_EDGE:
			if code.contains(word):
				movers.append(path)
				break
	equal(movers, PackedStringArray([THE_SHARED_PATH]),
		"a file under sim/ moves a relationship that is not the shared servicing"
		+ " path")

	# The scan has teeth: with the planted line in it, a driver is a finding.
	var planted := _code_of("res://sim/control_loop.gd") + " " + PLANTED_MOVE
	var caught := false
	for word in MOVES_AN_EDGE:
		if planted.contains(word):
			caught = true
	check(caught, "the scan does not catch a driver that moves an edge itself")

	# And it is not a fact about who is deciding: a character with no decision
	# function at all is serviced, and the world's happenings still reach it.
	var scene := _staged()
	var rook := _named(scene, "Rook")
	var wren := _named(scene, "Wren")
	_sheet(rook).decide = Callable()
	_sheet(wren).decide = Callable()
	check(not _sheet(wren).decide.is_valid(), "the character was given a driver")
	ActionEngine.resolve(scene, rook, Action.say("good morning", wren.id))
	var upkeep := CharacterUpkeep.new()
	equal(int(upkeep.serve(scene, wren)["moved"]), 1,
		"servicing a character with no decision function folded nothing")
	check(scene.relationships.knows(rook.id, wren.id),
		"a character nobody drives has no edges")

	# A character never serviced at all still has its edges, because they were
	# never its to keep: servicing anybody folds everything the world wrote down.
	var third := _staged()
	var speaker := _named(third, "Rook")
	var spoken_to := _named(third, "Wren")
	var bystander := _named(third, "Mott")
	ActionEngine.resolve(third, speaker, Action.say("good morning", spoken_to.id))
	CharacterUpkeep.new().serve(third, bystander)
	check(third.relationships.knows(speaker.id, spoken_to.id),
		"servicing a bystander left the edge between the two who spoke unmade")


# --- 5. No model writes one -----------------------------------------------


func _a_model_may_not_write_one() -> void:
	for path in MODEL_FACING:
		var code := _code_of(path)
		for word in NAMES_THE_GRAPH:
			check(not code.contains(word),
				"%s names the relationship graph ('%s')" % [path, word])

	# The operations table has no operation that names one, so a line naming one
	# is not read as an operation at all...
	check(not PackedStringArray(WorldEffects.names()).has("relate"),
		"the operations table offers an operation that writes a relationship")
	equal(WorldEffects.read(AN_EDGE_WRITING_ANSWER).size(), 0,
		"an answer naming a relationship read as an operation")

	# ...and put through the engine anyway it is refused, in the engine's own
	# words, and changes nothing.
	var scene := _staged()
	var was := scene.relationships.fingerprint()
	var refused := WorldEffects.apply(scene, {
		"op": "relate", "line": AN_EDGE_WRITING_ANSWER,
	}, ScriptedScenario.SEED)
	check(not bool(refused["ok"]), "the engine carried out a relationship write")
	equal(String(refused["reason"]), "there is no such operation",
		"the refusal is not the engine's own wording: %s" % refused["reason"])
	equal(scene.relationships.fingerprint(), was, "the refused line moved the graph")

	# The character's own surface has no such action or tool either.
	for named in ActionCatalog.names():
		check(not String(named).contains("trust") and not String(named).contains("relat"),
			"the action list offers a way to write a relationship: %s" % named)
	var prompt := ModelPrompt.written_for(
		Observation.of(scene, _named(scene, "Rook")))
	for word in ["trust", "fear 0", "respect 0", "familiarity"]:
		check(not prompt.to_lower().contains(word.to_lower()),
			"the character prompt offers a relationship to write: '%s'" % word)


# --- 6. Its own edges only -------------------------------------------------


func _a_character_sees_its_own_edges_only() -> void:
	var graph := RelationshipGraph.new()
	graph.heard(1, 2, "one to two", false)
	graph.heard(2, 3, "two to three", false)
	equal(graph.size(), 2, "two happenings between three made a different number of edges")

	var ones := graph.edges_of(1)
	equal(ones.size(), 1, "a character was handed a number of edges it is not an end of")
	check(ones[0].joins(1), "a character was handed an edge it is not an end of")
	equal(graph.edges_of(2).size(), 2, "the character in the middle sees only one of its two")
	equal(graph.edges_of(9).size(), 0, "a character nothing has happened to has edges")

	# The packet reads the graph, and reads it keyed by the looker's own id.
	var scene := _staged()
	var rook := _named(scene, "Rook")
	var mott := _named(scene, "Mott")
	var before := Observation.of(scene, rook)
	equal(_row_for(before.entities, mott.id)["name_absent"], Observation.UNMET,
		"a stranger's name is absent for some reason other than not having met")
	scene.relationships.heard(mott.id, rook.id, "well met", false)
	var after := Observation.of(scene, rook)
	equal(_row_for(after.entities, mott.id)["name"], "Mott",
		"the packet does not read the world's graph for whether it knows a name")
	equal(_row_for(Observation.of(scene, mott).entities, rook.id)["name"], "Rook",
		"the same edge is not read from the other end")


# --- 7. The shipped run ----------------------------------------------------


func _the_shipped_run_shows_it() -> void:
	var played := ScriptedAgent.played_with(
		ModelChannel.for_run(ModelRecording.exchange()))
	var scene: ActionScene = played["scene"]
	var graph := scene.relationships
	check(graph.size() > 0, "the shipped run made no relationships at all")

	var person := _named(scene, ScriptedAgent.PERSON)
	check(person != null, "the run has no character driven by a person in it")
	var theirs := graph.edges_of(person.id)
	check(theirs.size() > 0,
		"the character a person drives ended the run with no edges, which is the"
		+ " privilege the shared path exists to stop")
	var numbers := 0
	for edge in theirs:
		if edge.field(person.id, "familiarity") > 0.0:
			numbers += 1
	equal(numbers, theirs.size(),
		"an edge of the person-driven character carries no numbers")

	# Of the same order as a model-driven one's: at least as many as the fewest
	# any model-driven character ended with.
	var fewest := 1 << 30
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet == null or sheet.character_name == ScriptedAgent.PERSON:
			continue
		fewest = mini(fewest, graph.edges_of(one.id).size())
	check(theirs.size() >= fewest,
		"the person-driven character has fewer edges (%d) than the model-driven"
			% theirs.size()
		+ " character with the fewest (%d)" % fewest)


# --- The furniture --------------------------------------------------------


# Three characters standing three units apart, all carrying money and one of them
# a lantern to give away.
func _staged() -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(ScriptedScenario.SEED))
	var at := ScriptedScenario.WHERE
	for row in [["Rook", ROOK_AT], ["Wren", WREN_AT], ["Mott", MOTT_AT]]:
		var where: Vector2 = at + (row[1] as Vector2)
		var one := scene.add_actor(Combatant.commander_at(
			where.x, where.y, 0.0, 0.0, 2, AssetTags.KNIGHT))
		(one.piece as Commander).adopt(Character.make(String(row[0]), 2))
		ActionScene.inventory_of(one).gain(MONEY)
		one.settle(scene.terrain)
	return scene


func _play_a_greeting(scene: ActionScene) -> void:
	var rook := _named(scene, "Rook")
	var wren := _named(scene, "Wren")
	ActionEngine.resolve(scene, rook, Action.say("good morning", wren.id))
	ActionEngine.resolve(scene, wren, Action.say("and to you", rook.id))


# An exchange the engine honours: money one way, money the other, or nothing back
# at all, which is what makes it a gift.
func _trade(
	scene: ActionScene, from_one: Combatant, to_one: Combatant, out: int, back: int
) -> void:
	ActionEngine.resolve(scene, from_one, Action.trade_propose(
		to_one.id, PackedStringArray(), out, PackedStringArray(), back))
	ActionEngine.resolve(scene, to_one, Action.trade_accept(from_one.id))
	equal(scene.trades.size(), 1, "the exchange was not honoured by the engine")
	CharacterUpkeep.new().serve(scene, from_one)


func _about(actual: float, expected: float, message: String) -> void:
	check(absf(actual - expected) < CLOSE,
		"%s (%.4f, wanted %.4f)" % [message, actual, expected])


func _row_for(rows: Array[Dictionary], id: int) -> Dictionary:
	for row in rows:
		if int(row["id"]) == id:
			return row
	return {}


static func _sheet(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet


static func _named(scene: ActionScene, who: String) -> Combatant:
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null and sheet.character_name == who:
			return one
	return null


func _files_under(directory: String) -> PackedStringArray:
	var found := PackedStringArray()
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"):
			found.append("%s/%s" % [directory, name])
	found.sort()
	return found


# One file's code, with comments and string literals stripped, so that prose
# about a call is not read as one.
func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in _read(path).split("\n"):
		kept.append(String(AssetCheck.split_code_and_strings(line)["code"]).strip_edges())
	return " ".join(kept)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
