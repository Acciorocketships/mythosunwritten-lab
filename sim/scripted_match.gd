extends RefCounted
## One whole match, played to a conclusion from a written-down list of decisions.
##
## Nothing here decides anything. Every move, every turn of a facing, every
## attack and every minion activation is a line in `DECISIONS`, in the order it
## happens, and the match state applies them and refuses the ones that are not
## legal. There is no policy, no search and no language model: section 3.9's
## minion AI is a later task, and a scripted list is what lets this one be
## checked against exact numbers.
##
## It is also the determinism witness. The board is typed out rather than
## generated, the decisions are a constant, and no layer under it reads a clock,
## a random number or an address -- so the transcript is a pure function of this
## file, and two processes playing it must print the same bytes.
##
##     ./run_match.sh
##
## ## The board
##
## ```
##  y=0   . . . . . . . . . . . . .
##  y=1   . . . . . . ~ ~ . . . . .     a chasm at (6,1) and (7,1)
##  y=2   . . . . . . . . . . . . .
##  y=3   . . . . . . . . . . . . .
##  y=4   . . . . . . . . . . . . .
##  y=5   . . . . . . . . . . . . .
##  y=6   . . . . . . . . . . . . .
##  y=7   . . . . . . . . . . . . .
##  y=8   . . . . . . . . . v v . .     a pit, eight units down
##  y=9   . . . . . . . . v v v . .
##  y=10  . . . . . . . . . . . . .
##  y=11  . . . . . . . . . . . . .
##  y=12  . . . . . . . . . . . . .
## ```
##
## Two holes of two different kinds, and they kill by two different branches of
## the same rule: the chasm is a cell with nothing to stand on, and the pit is a
## cell with a floor too far below to climb down to. A commander is shoved into
## each.
##
## ## The three commanders
##
## Every one of them is equipped out of the item layer, at its own level: gear is
## worth the creature it came off, so a level-1 commander carries level-1 gear.
## Nothing here is a tier or a flat constant; the four columns on the right are
## read off the budgets in the two columns beside them.
##
## | | level | weapon | armour | mov/def points | defence | health |
## |---|---|---|---|---|---|---|
## | #1 | 3 | shield, common L3 all defence | common L3 boots, **rare** L3 chestplate | 4/8, 16/11, 0/12 | 1 | 38 |
## | #2 | 2 | sword, common L2 | common L2 boots | 4/4 | 0 | 32 |
## | #3 | 1 | spear, common L1 | common L1 boots, common L1 helmet | 4/0, 0/4 | 0 | 26 |
##
## #1 is the one with the lucky drop: a rare chestplate off a level-3 creature is
## twenty-seven points where a common one is twelve, and sixteen of them buy the
## two-cell queen-like slide the decisions below use. The other two could not
## have afforded it at their level and rarity, which is the whole of why they
## move like kings and #1 moves like a queen.
##
## No two of them are on a side. #1 shoves #2 into the chasm in round 2; #3's
## Frog takes #2's Ent in round 1 while #3 is still nowhere near #1; #3's Cat
## takes two of #1's minions; #3 backstabs #1 in round 3 and flanks it in round
## 4; and #1 shoves #3 into the pit in round 6. Every one of those is one owner
## id compared against another.
class_name ScriptedMatch

## The seed the scenario is written for.
##
## The scripted match is the project's one hand-written fight, so it is also the
## one place a die can be shown doing its work against decisions nobody is
## allowed to change afterwards. This seed was picked by playing the same
## decisions under every seed from 1 to 400 and keeping one whose fight still
## reaches the same conclusion as the deterministic run it replaced -- six
## rounds, one survivor, #1 -- so that what the die changed is the size of each
## blow and nothing about the story the transcript tells.
const SEED := 1234

## The board, as it is typed out above.
const MAP := [
	".............",
	"......~~.....",
	".............",
	".............",
	".............",
	".............",
	".............",
	".............",
	".........vv..",
	"........vvv..",
	".............",
	".............",
	".............",
]

## Every decision of the match, in order. The four words are all there are:
## `face` a direction, `move` the commander to a cell, `attack` with one of the
## held weapon's attacks, activate one `minion` onto a cell, and `end` the turn.
const DECISIONS := [
	# --- Round 1 ---
	# #1 steps up and its Frog hops the enemy line to take a Toadstool.
	["move", 6, 5], ["minion", 4, 5, 2], ["end"],
	# #2 turns to face the Frog now standing beside it and cuts at it.
	["face", PieceGeometry.WEST], ["attack", 0], ["minion", 8, 8, 4], ["end"],
	# #3, at the far corner and allied with nobody, takes #2's Ent.
	["move", 8, 6], ["minion", 11, 8, 4], ["end"],

	# --- Round 2 ---
	# #1 slides two cells north and shoves #2 into the chasm behind it.
	["move", 6, 3], ["attack", 0], ["minion", 5, 8, 5], ["end"],
	# #3 closes, and its Cat takes the Cat #1 just moved.
	["move", 7, 6], ["minion", 10, 8, 5], ["end"],

	# --- Round 3 ---
	# #1 comes back south. Its shove is still on cooldown, and is refused.
	["move", 6, 5], ["attack", 0], ["minion", 4, 7, 3], ["end"],
	# #3 steps in behind #1 and backstabs it.
	["move", 6, 6], ["face", PieceGeometry.NORTH], ["attack", 0],
	["minion", 10, 7, 4], ["end"],

	# --- Round 4 ---
	# #1 slides two diagonally to the lip of the pit.
	["move", 8, 7], ["face", PieceGeometry.SOUTH], ["minion", 4, 8, 5], ["end"],
	# #3 follows and flanks, and its Cat takes the Frog.
	["move", 7, 7], ["face", PieceGeometry.EAST], ["attack", 0],
	["minion", 10, 8, 5], ["end"],

	# --- Round 5 ---
	# #1 has only its Ent left and waits on the lip.
	["minion", 6, 5, 7], ["end"],
	# #3 steps onto the cliff edge to hit #1 from the front, for one point.
	["move", 8, 8], ["face", PieceGeometry.NORTH], ["attack", 0],
	["minion", 10, 7, 6], ["end"],

	# --- Round 6 ---
	# The shove is ready again, and #3 is standing over the pit.
	["attack", 0], ["end"],
]


## Set the board out and put every piece on it, in a fixed order so that the ids
## the decisions above name are the ids they get.
static func set_up() -> Dictionary:
	var board := BoardSketch.from_rows(PackedStringArray(MAP))
	var pieces := PieceMap.new()

	var first := Commander.make(Vector2i(6, 6), PieceGeometry.NORTH, AssetTags.KNIGHT, 3)
	first.equip(Armour.boots(3))
	first.equip(Armour.chestplate(3, ItemRarity.RARE))
	first.wield(Weapon.held(Weapon.shield(), 3, ItemRarity.COMMON, 0, 12))
	pieces.add(first)

	var second := Commander.make(Vector2i(6, 2), PieceGeometry.SOUTH, AssetTags.KNIGHT, 2)
	second.equip(Armour.boots(2))
	second.wield(Weapon.held(Weapon.sword(), 2))
	pieces.add(second)

	var third := Commander.make(Vector2i(9, 7), PieceGeometry.NORTH, AssetTags.KNIGHT, 1)
	third.equip(Armour.boots(1))
	third.equip(Armour.helmet(1))
	third.wield(Weapon.held(Weapon.spear(), 1))
	pieces.add(third)

	# #1's three, #2's three, #3's two -- added in that order, so the ids run
	# 4..6, 7..9, 10..11 and the decision list can name them.
	pieces.add(Minion.of_kind(Minion.FROG, first.id, Vector2i(6, 4), 3))
	pieces.add(Minion.of_kind(Minion.CAT, first.id, Vector2i(7, 6), 3))
	pieces.add(Minion.of_kind(Minion.ENT, first.id, Vector2i(5, 6), 3))

	pieces.add(Minion.of_kind(Minion.TOADSTOOL, second.id, Vector2i(5, 2), 2))
	pieces.add(Minion.of_kind(Minion.ENT, second.id, Vector2i(8, 2), 2))
	pieces.add(Minion.of_kind(Minion.CAT, second.id, Vector2i(3, 1), 2))

	pieces.add(Minion.of_kind(Minion.CAT, third.id, Vector2i(10, 7), 1))
	pieces.add(Minion.of_kind(Minion.FROG, third.id, Vector2i(9, 6), 1))

	return {"board": board, "pieces": pieces}


## Play the whole thing and hand back the transcript.
static func play() -> PackedStringArray:
	var set_out := set_up()
	var played := CombatMatch.start(set_out["board"], set_out["pieces"], SEED)
	for decision in DECISIONS:
		# Once the match is decided nothing else may act, but the turn it was
		# decided on still has to be ended, which is what writes the conclusion.
		if played.is_over() and str(decision[0]) != "end":
			continue
		apply(played, decision)
	return played.lines


## One decision. The whole vocabulary, and it is four words long.
static func apply(played: CombatMatch, decision: Array) -> void:
	match str(decision[0]):
		"face":
			played.face(int(decision[1]))
		"move":
			played.move_commander(Vector2i(int(decision[1]), int(decision[2])))
		"attack":
			played.attack(int(decision[1]))
		"minion":
			played.activate_minion(
				int(decision[1]), Vector2i(int(decision[2]), int(decision[3]))
			)
		"end":
			played.end_turn()
