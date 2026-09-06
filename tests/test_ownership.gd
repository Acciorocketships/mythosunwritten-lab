extends TestSuite
## Section 6's ownership rule: one function of a world position and the state of
## the world, reading nothing but relationship edges and character sheets.
##
## Eight claims:
##
##   1. The rule is arithmetic that can be checked by hand. A world of three
##      characters is built with sentiments set to known numbers and the score
##      the rule gives is compared against the fraction worked out on paper --
##      including the fact that a claimant is not a voter in its own claim, which
##      shows up as a near-threefold difference in the answer.
##   2. The three numbers section 6 leaves open are named constants in one place,
##      and `at()` is `measured()` under exactly those four values. There is no
##      second copy of the arithmetic and no second place to change a constant.
##   3. Status and level both enter, and each moves ownership on its own. Two
##      worlds identical but for one character's standing, and two identical but
##      for the same character's level, each give a different answer -- and the
##      same one as each other, because section 6 adds the two.
##   4. The rule reads relationship edges and character sheets and nothing else.
##      Shown by a word scan of the two files the rule is made of, run against a
##      deliberately broken control line so that an empty result means the scan
##      looked. The scan also forbids every writing method on the graph, so "it
##      does not change sentiment" is the same check.
##   5. Asking changes nothing: the graph's fingerprint and every sheet's numbers
##      are the same after a whole grid has been sampled as before it.
##   6. Neutral is a real answer. Ground with nobody near it, ground whose
##      neighbours have met nobody, and ground whose best claim falls short of
##      the threshold are all neutral, and the claim says which it was.
##   7. Somebody no longer standing neither votes nor holds ground.
##   8. On the shipped seeded run the numbers `./run_ownership.sh` publishes are
##      the numbers this rule gives: the ground between the two who traded is
##      owned, 630 of 1681 sampled points are held, and the threshold is still
##      the sentiment one honoured exchange between strangers earns.
class_name TestOwnership

## The two files the rule is made of. Both are scanned.
const RULE_FILES := [
	"res://sim/ownership_field.gd",
	"res://sim/ownership_claim.gd",
]

## Words that would mean the rule knows what a fight, a conversation or a quest
## is -- or that it had reached past the graph to the events the graph is made
## of. The three writing methods on `RelationshipGraph` are in here too, so a
## rule that moved sentiment instead of reading it is the same finding.
const FORBIDDEN := [
	# a fight
	"fight", "fights", "fighting", "combat", "encounter", "battle", "duel",
	"attack", "attacks", "blow", "blows", "strike", "struck", "hit", "hits",
	"damage", "wound", "kill", "killed", "minion", "commanders", "match",
	# a conversation
	"say", "said", "says", "speech", "spoke", "spoken", "shout", "shouted",
	"heard", "hear", "talk", "talked", "conversation", "greeting",
	# a dealing
	"trade", "trades", "traded", "offer", "offers", "gift", "money", "coin",
	# a quest, a goal, a check
	"quest", "quests", "goal", "goals", "check", "checks", "roll", "rolled",
	# the stores and engines the rule must not reach into
	"memory", "memories", "inventory", "equipment", "item", "items", "weapon",
	"armour", "action", "actions", "engine", "scene", "world", "terrain",
	"orchestrator", "prompt", "model",
	# every way of reading or writing the graph that is not the two allowed
	"between", "edges_of", "all", "happenings", "note", "raise", "lower",
	"toward", "field",
]

## The two the rule may name on the graph, and the reason the list above can be
## as blunt as it is.
const ALLOWED := ["sentiment", "knows"]

## The control the scan is run against. Written to fail: four forbidden words in
## code, on two lines, one of them inside a string literal.
const CONTROL_LINE := "func owns() -> bool:\n\tif scene.fight != null:\n\t\treturn \"trade\" == goal\n"

## What `./run_ownership.sh` publishes for the shipped seeded run, and what this
## suite holds it to. If the scenario itself moves, these move with it and the
## report is re-read; they are here so that neither can move quietly.
const SHIPPED_EDGES := 2
const SHIPPED_HAPPENINGS := 10
const SHIPPED_POINTS := 1681
const SHIPPED_HELD := 630
const SHIPPED_TRADERS_FEEL := 0.1525

var _words := RegEx.create_from_string("[A-Za-z_][A-Za-z_0-9]*")


func _init() -> void:
	suite_name = "ownership"


func run() -> void:
	_the_arithmetic_can_be_checked_by_hand()
	_the_three_numbers_are_named_in_one_place()
	_status_and_level_both_move_it()
	_it_reads_edges_and_sheets_only()
	_asking_changes_nothing()
	_neutral_is_a_real_answer()
	_the_fallen_neither_vote_nor_hold_ground()
	_the_shipped_run_gives_the_published_numbers()


# --- 1. The arithmetic ----------------------------------------------------


func _the_arithmetic_can_be_checked_by_hand() -> void:
	# Three characters on a line. #2 thinks the world of #1; #3 has met #1 and
	# feels nothing about it; #1 is standing on the point being asked about.
	var cast := _cast([
		{"id": 1, "at": Vector2(0.0, 0.0), "level": 1},
		{"id": 2, "at": Vector2(10.0, 0.0), "level": 1},
		{"id": 3, "at": Vector2(30.0, 0.0), "level": 1},
	])
	var graph := RelationshipGraph.new()
	_feel(graph, 2, 1, 1.0, 0.0)
	_feel(graph, 3, 1, 0.0, 0.0)

	var temperature := 12.0
	var claim := OwnershipField.measured(cast, graph, 0.0, 0.0,
		OwnershipField.SOFTMIN, temperature, 1000.0, 0.0)

	# By hand. Every carry is 1 + 1 = 2 and cancels; #1 is left out of its own
	# claim, so the average is over #2 and #3 alone:
	#
	#   O(1) = e^(-10/12) * 1.0 / (e^(-10/12) + e^(-30/12))
	var near := exp(-10.0 / temperature)
	var far := exp(-30.0 / temperature)
	var expected := near / (near + far)
	check(absf(claim.score_of(1) - expected) < 1.0e-6,
		"the score is not the weighted average worked out on paper: %.6f vs %.6f"
			% [claim.score_of(1), expected])
	equal(claim.owner_id, 1, "the character its neighbours favour does not own the point")
	equal(claim.considered, 3, "not every character within the radius had a say")
	equal(claim.scanned, 3, "the rule did not look at the whole cast")

	# What a claimant voting in its own claim would cost. #1 stands on the point,
	# so it would carry weight 1 against #2's 0.435 and #3's 0.082, and the
	# answer would be 0.287 instead of 0.841 -- nearly three times smaller. It is
	# not, so it is left out.
	var if_it_voted := near / (near + far + 1.0)
	check(claim.score_of(1) > 2.5 * if_it_voted,
		"a claimant is diluting its own claim: %.6f is near the %.6f it would be"
			% [claim.score_of(1), if_it_voted])

	# A stranger dilutes rather than being skipped: #3 is in the denominator
	# although it has nothing to say about #1.
	check(claim.score_of(1) < 1.0,
		"an entity with no opinion of the claimant was left out of the average")

	# The same question twice is the same answer, to the bit.
	var again := OwnershipField.measured(cast, graph, 0.0, 0.0,
		OwnershipField.SOFTMIN, temperature, 1000.0, 0.0)
	equal(again.line(), claim.line(), "two identical questions gave two answers")

	# Both proximity shapes are positive, greatest at nothing, and falling.
	for shape in OwnershipField.SHAPES:
		equal(OwnershipField.proximity(shape, 0.0, 12.0), 1.0,
			"%s does not weight an entity standing on the point at one" % shape)
		var closer := OwnershipField.proximity(shape, 5.0, 12.0)
		var further := OwnershipField.proximity(shape, 25.0, 12.0)
		check(closer > further and further > 0.0,
			"%s is not positive and falling: %.6f then %.6f" % [shape, closer, further])


# --- 2. The three numbers, in one place -----------------------------------


func _the_three_numbers_are_named_in_one_place() -> void:
	# The four the rule reads, and `at()` is `measured()` under exactly them.
	var cast := _cast([
		{"id": 1, "at": Vector2(0.0, 0.0), "level": 2},
		{"id": 2, "at": Vector2(8.0, 0.0), "level": 2},
	])
	var graph := RelationshipGraph.new()
	_feel(graph, 2, 1, 1.0, 0.0)
	for at in [Vector2(0.0, 0.0), Vector2(40.0, 40.0), Vector2(-200.0, 5.0)]:
		var settled := OwnershipField.at(cast, graph, at.x, at.y)
		var spelt := OwnershipField.measured(cast, graph, at.x, at.y,
			OwnershipField.PROXIMITY, OwnershipField.TEMPERATURE,
			OwnershipField.RADIUS, OwnershipField.THRESHOLD)
		equal(settled.line(), spelt.line(),
			"at() is not measured() under the four named constants, at (%.1f, %.1f)"
				% [at.x, at.y])

	# The threshold is the sentiment one honoured exchange between two strangers
	# earns, which is the whole of why it is that number. If what a trade is
	# worth ever moves, this fails rather than the defence quietly going stale.
	var one_dealing := RelationshipGraph.MET * RelationshipGraph.TRADE_TRUST
	check(absf(OwnershipField.THRESHOLD - one_dealing) < 1.0e-9,
		"the threshold %.4f is no longer what one honoured exchange earns (%.4f)"
			% [OwnershipField.THRESHOLD, one_dealing])

	# And the shape the rule ships with is one of the two that were measured.
	check(OwnershipField.SHAPES.has(OwnershipField.PROXIMITY),
		"the shape the rule uses was never one of the two measured")
	equal(OwnershipField.SHAPES.size(), 2,
		"more than two weighting shapes exist; the work allowed exactly two")


# --- 3. Status and level --------------------------------------------------


func _status_and_level_both_move_it() -> void:
	# #2 is the only character with anything to say about #1, so what #2's
	# opinion is worth is exactly what moves #1's claim. #3 says nothing and is
	# what there is to be weighed against.
	var rows := [
		{"id": 1, "at": Vector2(0.0, 0.0), "level": 1},
		{"id": 2, "at": Vector2(20.0, 0.0), "level": 1},
		{"id": 3, "at": Vector2(20.0, 0.0), "level": 1},
	]
	var graph := RelationshipGraph.new()
	_feel(graph, 2, 1, 1.0, 0.0)
	_feel(graph, 3, 1, 0.0, 0.0)

	var shipped := _score_of_one(_cast(rows), graph)

	# The same world with one number changed: #2's level, standing pinned so it
	# cannot move with it.
	var levelled := _cast(rows)
	var sheet := OwnershipField.sheet_of(_of(levelled, 2))
	sheet.set_status(sheet.status())
	sheet.level += 4
	var by_level := _score_of_one(levelled, graph)

	# And again with one number changed: #2's standing, level untouched.
	var raised := _cast(rows)
	OwnershipField.sheet_of(_of(raised, 2)).set_status(1 + 4)
	var by_status := _score_of_one(raised, graph)

	check(by_level > shipped + 1.0e-6,
		"raising a level alone did not move ownership: %.6f then %.6f"
			% [shipped, by_level])
	check(by_status > shipped + 1.0e-6,
		"raising a standing alone did not move ownership: %.6f then %.6f"
			% [shipped, by_status])
	check(absf(by_level - by_status) < 1.0e-9,
		"status and level do not enter alike: %.6f by level, %.6f by standing"
			% [by_level, by_status])

	# And they add rather than one swallowing the other.
	var both := _cast(rows)
	var moved := OwnershipField.sheet_of(_of(both, 2))
	moved.set_status(1 + 4)
	moved.level += 4
	check(_score_of_one(both, graph) > by_level + 1.0e-6,
		"changing both did no more than changing one")

	# An unassigned standing tracks the level, so levelling up alone moves
	# ownership even where nobody has been assigned a standing at all.
	var untouched := _cast(rows)
	OwnershipField.sheet_of(_of(untouched, 2)).level += 4
	check(_score_of_one(untouched, graph) > by_level + 1.0e-6,
		"an unassigned standing did not rise with the level")


# --- 4. What it may read --------------------------------------------------


func _it_reads_edges_and_sheets_only() -> void:
	var offenders := PackedStringArray()
	for path in RULE_FILES:
		for word in _forbidden_in(FileAccess.get_file_as_string(path)):
			offenders.append("%s names '%s'" % [path.get_file(), word])
	equal(offenders.size(), 0,
		"the ownership rule reaches past edges and sheets: %s" % ", ".join(offenders))

	# The control. The same scan, over a line written to fail it.
	equal(_forbidden_in(CONTROL_LINE).size(), 4,
		"the scan cannot see its own broken control line: [%s]"
			% ", ".join(_forbidden_in(CONTROL_LINE)))
	# And what it deliberately does not read as code: prose. This file's own
	# header talks about fights and quests at length and must not be a finding.
	equal(_forbidden_in("## nothing here knows what a fight or a quest is").size(), 0,
		"the scan reads a comment as code")

	# The two the rule is allowed to name on the graph are named, so the scan
	# above is not passing because the rule reads nothing at all.
	var source := FileAccess.get_file_as_string(RULE_FILES[0])
	for named in ALLOWED:
		check(source.contains("graph.%s(" % named),
			"the rule never asks the graph for %s" % named)


# --- 5. Asking changes nothing --------------------------------------------


func _asking_changes_nothing() -> void:
	var cast := _cast([
		{"id": 1, "at": Vector2(0.0, 0.0), "level": 2},
		{"id": 2, "at": Vector2(6.0, 0.0), "level": 3},
		{"id": 3, "at": Vector2(40.0, 12.0), "level": 1},
	])
	var graph := RelationshipGraph.new()
	_feel(graph, 2, 1, 0.8, 0.1)
	_feel(graph, 3, 2, 0.2, 0.6)

	var was_graph := graph.fingerprint()
	var was_sheets := _sheet_lines(cast)
	for step in range(400):
		var at := float(step) * 0.7 - 140.0
		OwnershipField.at(cast, graph, at, -at)
	equal(graph.fingerprint(), was_graph,
		"sampling ownership moved the relationship graph")
	equal(_sheet_lines(cast), was_sheets,
		"sampling ownership moved a character sheet")


# --- 6. Neutral is a real answer ------------------------------------------


func _neutral_is_a_real_answer() -> void:
	var cast := _cast([
		{"id": 1, "at": Vector2(0.0, 0.0), "level": 1},
		{"id": 2, "at": Vector2(10.0, 0.0), "level": 1},
	])
	var graph := RelationshipGraph.new()

	# Nobody near: neutral, and the claim says so rather than being empty.
	var empty := OwnershipField.at(cast, graph, 4000.0, 4000.0)
	check(empty.is_neutral(), "ground with nobody within the radius has an owner")
	check(not empty.any_near(), "ground with nobody within the radius heard somebody")
	equal(empty.considered, 0, "somebody outside the radius had a say")
	equal(empty.scanned, 2, "the rule did not look at the whole cast")

	# Near, but nobody has met anybody: neutral, and the difference is visible.
	var strangers := OwnershipField.at(cast, graph, 5.0, 0.0)
	check(strangers.is_neutral(), "a world where nobody has met anybody has an owner")
	check(strangers.any_near(), "the two standing here were not heard")
	equal(strangers.best_id, OwnershipField.NOBODY,
		"somebody nobody has met is a claimant")

	# Met, but not favoured enough: neutral by falling short, with the score
	# kept so that "neutral by a hair" is a thing the answer can say.
	_feel(graph, 2, 1, 0.20, 0.16)
	var faint := OwnershipField.at(cast, graph, 5.0, 0.0)
	check(faint.best > 0.0 and faint.best < OwnershipField.THRESHOLD,
		"the faint claim is not below the threshold: %.4f" % faint.best)
	check(faint.is_neutral(), "a claim below the threshold owns the ground")
	equal(faint.best_id, 1, "the best claim was not recorded")

	# One more happening of the same kind carries it over.
	_feel(graph, 2, 1, 1.0, 0.0)
	var held := OwnershipField.at(cast, graph, 5.0, 0.0)
	equal(held.owner_id, 1, "a claim above the threshold does not own the ground")
	check(held.margin() > 0.0, "the winner has no margin over anybody")


# --- 7. The fallen --------------------------------------------------------


func _the_fallen_neither_vote_nor_hold_ground() -> void:
	var cast := _cast([
		{"id": 1, "at": Vector2(0.0, 0.0), "level": 2},
		{"id": 2, "at": Vector2(4.0, 0.0), "level": 2},
		{"id": 3, "at": Vector2(8.0, 0.0), "level": 2},
	])
	var graph := RelationshipGraph.new()
	_feel(graph, 2, 3, 1.0, 0.0)

	var standing := OwnershipField.at(cast, graph, 4.0, 0.0)
	equal(standing.owner_id, 3, "the character its neighbour favours does not own it")

	# #3 falls. It can hold no ground, and #2's opinion of it claims nothing.
	_of(cast, 3).piece.health = 0
	var without := OwnershipField.at(cast, graph, 4.0, 0.0)
	check(without.is_neutral(), "somebody no longer standing still owns ground")
	equal(without.considered, 2, "somebody no longer standing still had a say")

	# And a fallen voter's opinion is not counted either.
	var other := _cast([
		{"id": 1, "at": Vector2(0.0, 0.0), "level": 2},
		{"id": 2, "at": Vector2(4.0, 0.0), "level": 2},
	])
	var second := RelationshipGraph.new()
	_feel(second, 2, 1, 1.0, 0.0)
	equal(OwnershipField.at(other, second, 4.0, 0.0).owner_id, 1,
		"the standing pair do not agree who owns it")
	_of(other, 2).piece.health = 0
	check(OwnershipField.at(other, second, 4.0, 0.0).is_neutral(),
		"a character no longer standing is still voting")


# --- 8. The shipped seeded run --------------------------------------------


func _the_shipped_run_gives_the_published_numbers() -> void:
	var scene := ScriptedScenario.played_to(ScriptedOwnership.TICKS, ScriptedOwnership.SEED)
	var graph := scene.relationships
	equal(graph.size(), SHIPPED_EDGES, "the shipped run no longer has two edges")
	equal(graph.happenings(), SHIPPED_HAPPENINGS,
		"the shipped run no longer has ten happenings")

	# The ground the two who traded are standing on is owned by one of them, and
	# the claim on it is the sentiment they actually feel, barely diluted.
	var probe := ScriptedOwnership.probe_at(scene)
	var claim := OwnershipField.at(scene.actors, graph, probe.x, probe.y)
	check(not claim.is_neutral(), "the market the two who traded stand on is neutral")
	check(claim.owner_id == 1 or claim.owner_id == 2,
		"the market is owned by somebody who was not standing in it: #%d" % claim.owner_id)
	check(claim.best > 0.90 * SHIPPED_TRADERS_FEEL,
		"the claim on the market is far below what the two feel: %.4f of %.4f"
			% [claim.best, SHIPPED_TRADERS_FEEL])
	check(claim.best > 2.0 * OwnershipField.THRESHOLD,
		"the strongest claim in the shipped run barely clears the threshold: %.4f"
			% claim.best)

	# And the whole sampled grid comes out as the report publishes it.
	var points := ScriptedOwnership.grid()
	equal(points.size(), SHIPPED_POINTS, "the stated grid is no longer 41 by 41")
	var held := 0
	var most := 0
	for at in points:
		var here := OwnershipField.at(scene.actors, graph, at.x, at.y)
		most = maxi(most, here.considered)
		if not here.is_neutral():
			held += 1
	equal(held, SHIPPED_HELD,
		"the share of sampled ground that is held has moved: %d of %d" % [
			held, points.size(),
		])
	equal(most, 4, "more or fewer than the whole standing cast was ever considered")


# --- The furniture --------------------------------------------------------


## A cast standing in a world: one commander per row, with a sheet at the stated
## level and no assigned standing, so status tracks the level.
func _cast(rows: Array) -> Array[Combatant]:
	var made: Array[Combatant] = []
	for row in rows:
		var at: Vector2 = row["at"]
		var one := Combatant.commander_at(at.x, at.y, 0.0, 0.0, int(row["level"]))
		one.id = int(row["id"])
		(one.piece as Commander).adopt(
			Character.make("#%d" % int(row["id"]), int(row["level"])))
		made.append(one)
	return made


## Make one character feel a stated way about another, by writing the two fields
## the sentiment is made of straight onto the edge. The graph's own rules are
## exercised where they belong -- in the relationship suite -- and what this
## suite needs is a known number.
func _feel(graph: RelationshipGraph, from_id: int, to_id: int,
		trust: float, fear: float) -> void:
	var edge := graph.heard(from_id, to_id, "", false)
	edge.raise(from_id, "familiarity", 1.0)
	edge.raise(from_id, "trust", trust)
	edge.raise(from_id, "fear", fear)


func _of(cast: Array[Combatant], id: int) -> Combatant:
	for one in cast:
		if one.id == id:
			return one
	return null


func _score_of_one(cast: Array[Combatant], graph: RelationshipGraph) -> float:
	return OwnershipField.measured(cast, graph, 0.0, 0.0,
		OwnershipField.SOFTMIN, 12.0, 1000.0, 0.0).score_of(1)


func _sheet_lines(cast: Array[Combatant]) -> PackedStringArray:
	var written := PackedStringArray()
	for one in cast:
		var sheet := OwnershipField.sheet_of(one)
		written.append("#%d level=%d status=%d health=%d" % [
			one.id, sheet.level, sheet.status(), sheet.health,
		])
	return written


## Every forbidden word appearing in the *code* of a source text. Comments are
## cut first; string literals are kept.
func _forbidden_in(source: String) -> PackedStringArray:
	var found := PackedStringArray()
	for line in source.split("\n"):
		for hit in _words.search_all(_code_of(line)):
			if FORBIDDEN.has(hit.get_string().to_lower()):
				found.append(hit.get_string())
	return found


## The part of a line that is code: everything before the first `#` that is not
## inside a string.
func _code_of(line: String) -> String:
	var in_string := false
	var index := 0
	while index < line.length():
		var here := line[index]
		if in_string and here == "\\":
			index += 2
			continue
		if here == "\"":
			in_string = not in_string
		elif here == "#" and not in_string:
			return line.substr(0, index)
		index += 1
	return line
