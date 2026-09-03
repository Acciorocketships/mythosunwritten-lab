extends RefCounted
## Every relationship in the world, in one store the world owns.
##
## Section 10: "Relationships live on edges between entities, not inside any
## single NPC's memory -- a shared graph retrieved when interacting with that
## target. Each edge carries: target entity id, trust, fear, respect,
## familiarity, and a short summary of key interactions." This is that graph.
## One `RelationshipEdge` per pair of entity ids, reached from either end, held
## by the world and by no character.
##
## This file holds the *rules*: which field moves, at which end, by how much, and
## for what. It holds no cadence -- it does not know when it is called, how often
## a character is serviced or what is driving one. `sim/character_upkeep.gd`
## holds that, and hands each happening in once, which is the same split the two
## other per-character stores already have.
##
## ## Nothing moves an edge but something that happened in the world
##
## There are three writers on this file and each of them is the engine's own
## record of a thing that actually happened:
##
##   | writer     | the world's record it is folded from | what it is |
##   |------------|--------------------------------------|------------|
##   | `heard()`  | `ActionScene.said`                   | a line spoken, and who the engine says heard it |
##   | `traded()` | `ActionScene.trades`                 | an exchange the engine honoured, gifts included |
##   | `struck()` | `ActionScene.blows`                  | a blow the engine landed, and what it took |
##
## Each of the three is written by `ActionEngine` on the one path that action
## takes and by nothing else, so an edge cannot be moved by an intention, a
## claim, a proposal or a refusal -- only by an action the engine carried out. In
## particular a *proposed* trade moves nothing and a *denied* one moves nothing:
## an offer is a question, and questions are not what happened.
##
## No model writes here. There is no operation in `WorldEffects` that names a
## relationship, no tool in `ModelPrompt` that names one, and an answer that
## names one is refused by the engine in the same words any unknown operation is
## refused in -- shown on `./run_world.sh`. That is deliberate and it is the
## whole point of the store being the world's: an edge is the record of what
## happened, and a character that could write its own record could make anybody
## love it by saying so.
##
## ## The rules, one line each
##
## Every rule is one of two shapes -- `raise` closes a share of the distance left
## to 1, `lower` gives up a share of what is there -- so no rule can leave
## $[0, 1]$ and every one is worth most the first time it applies.
##
##   | happening | end | field | rule |
##   |-----------|-----|-------|------|
##   | any of the three | both | familiarity | raise by `MET` |
##   | words heard | either | trust, fear, respect | **unmoved** -- see below |
##   | trade honoured, both ways | both | trust | raise by `TRADE_TRUST` |
##   | trade honoured, both ways | both | respect | raise by `TRADE_RESPECT` |
##   | gift (nothing came back) | the receiver's | trust | raise by `GIFT_TRUST` |
##   | blow struck | the struck one's | fear | raise by the share of its full health the blow took |
##   | blow struck | the struck one's | trust | lower by `STRUCK_TRUST` |
##   | blow struck | the struck one's | respect | raise by `STRUCK_RESPECT` |
##
## **Words move familiarity and nothing else, on purpose.** Section 6 says pure
## talk raising sentiment is "deliberately hard -- only truly novel diplomacy is
## even considered", gated by an ability check. A rule here that let trust rise
## with every "good morning" would be exactly the cheese that sentence forbids,
## and it would arrive before the check that is supposed to gate it. So talking
## does the one thing talking plainly does: the two now know each other somewhat.
## Raising trust by *what was said* is a check, and it is the next work item.
##
## **Being struck raises respect as well as fear.** A blow is a demonstration of
## what somebody can do, and respect here is a reading of capability rather than
## of liking -- which is exactly why respect is not part of the sentiment term
## below. Fear moves by the share of full health the blow took, so a scratch from
## a giant and a killing stroke are not the same event.
##
## **Only the struck end moves.** Striking somebody tells you nothing about how
## you feel about them that you did not already know; being struck does. The
## striker's end gains familiarity, like every other end of every other
## happening, and nothing else.
##
## ## The one number section 6 reads
##
## Section 13's first open question is which scalar or composite is the raw
## sentiment term. It is decided here, it is `sentiment()`, and it is the only
## thing the ownership maths will read:
##
## $$s(A \to B) = \mathrm{familiarity} \times (\mathrm{trust} - \mathrm{fear})
##   \in [-1, 1]$$
##
## Three choices, each with a reason:
##
##   * **trust minus fear, and not either alone.** Ownership asks whether this
##     character would rather that one held the ground it is standing on. Trust
##     is why it would; fear is why it would not; and fear is not the absence of
##     trust -- a character can hold both about the same warlord at once, and
##     what is left over when you take one from the other is precisely the
##     question ownership asks. Either number on its own answers half of it.
##   * **respect is left out.** Respect measures capability, not welcome: a
##     feared, respected warlord and a trusted, respected healer would count the
##     same. Section 6 already carries capability, twice over -- it scales each
##     character's sentiment by that character's status and level -- so putting
##     respect in the raw term would count the same thing twice, once as the
##     opinion and once as the weight. It stays on the edge because it is real
##     and because a later rule may read it; ownership does not.
##   * **familiarity multiplies rather than adds.** An opinion about somebody
##     barely met should not decide who owns ground. Two characters who have
##     exchanged one greeting have familiarity near zero and therefore a
##     sentiment near zero however warm the greeting was; the same trust after
##     forty dealings counts in full. Multiplying is also what keeps the term
##     inside $[-1, 1]$ without a second clamp.
##
## No weighting by status or level happens here, and no distance is read: those
## are section 6's and belong to the ownership item that reads this one.
class_name RelationshipGraph

## How much of what is left to know two entities learn of each other from one
## happening between them, whatever the happening was.
const MET := 0.25

## What an exchange the engine honoured does to each side's trust and respect.
const TRADE_TRUST := 0.20
const TRADE_RESPECT := 0.10

## What a gift -- an honoured exchange with nothing coming back -- does to the
## receiver's trust, over and above the exchange itself.
const GIFT_TRUST := 0.35

## What being struck does to the struck one's trust and respect. The fear it
## causes is not a constant: it is the share of that character's full health the
## blow took.
const STRUCK_TRUST := 0.50
const STRUCK_RESPECT := 0.25

## How much of a line of speech goes into the shared summary.
const SAID_AT_MOST := 40

## How many rows of each of the world's three records this graph has already
## been shown. The count belongs to the graph rather than to whoever folds --
## `sim/character_upkeep.gd` reads and advances it -- so that one happening moves
## an edge exactly once however many upkeeps a run happens to make.
var heard_taken: int = 0
var traded_taken: int = 0
var struck_taken: int = 0

# Every edge, by `RelationshipEdge.key_for`. Insertion order, which is the order
# the pairs first had anything to do with each other.
var _edges: Dictionary = {}


# --- Reading --------------------------------------------------------------


## The edge between two entities, or null if they have never had anything to do
## with each other.
##
## The same object whichever way round the two are named, which is what "an edge
## lives between two entities rather than inside either one" comes to in code.
func between(a: int, b: int) -> RelationshipEdge:
	return _edges.get(RelationshipEdge.key_for(a, b), null)


## Whether these two have had anything to do with each other at all.
##
## This is what the observation packet's "does this character know that one"
## reads. It is symmetric because *meeting* is: if one of them heard the other
## speak, both were there.
func knows(a: int, b: int) -> bool:
	return a != b and _edges.has(RelationshipEdge.key_for(a, b))


## One character's own edges, in the order they were first made.
##
## **This is the whole of what a character may see about relationships, and it
## is keyed by that character's own id.** There is no accessor here that hands
## back somebody else's edge, and the observation packet reaches the graph
## through this and through `knows()` alone: a character can be shown what it is
## to the people it has met, and can never be shown what two other people are to
## each other. An edge it is not an end of is not addressable from where it
## stands.
func edges_of(id: int) -> Array[RelationshipEdge]:
	var found: Array[RelationshipEdge] = []
	for key in _edges:
		var edge: RelationshipEdge = _edges[key]
		if edge.joins(id):
			found.append(edge)
	return found


## Section 6's raw sentiment term, from one character toward another. Zero
## between two who have never met, which is the honest answer: nothing has
## happened to feel anything about.
func sentiment(from_id: int, to_id: int) -> float:
	var edge := between(from_id, to_id)
	return 0.0 if edge == null else edge.sentiment_of(from_id)


## How many edges there are.
func size() -> int:
	return _edges.size()


## How many happenings every edge in the graph is made of, all told.
func happenings() -> int:
	var total := 0
	for key in _edges:
		total += (_edges[key] as RelationshipEdge).happenings
	return total


## Every edge, one line each, oldest pair first.
func lines() -> PackedStringArray:
	var written := PackedStringArray()
	for key in _edges:
		written.append((_edges[key] as RelationshipEdge).line())
	return written


## A short, stable digest of the whole graph, for the world's own fingerprint.
func fingerprint() -> String:
	if _edges.is_empty():
		return "no edges"
	var parts := PackedStringArray()
	for key in _edges:
		parts.append((_edges[key] as RelationshipEdge).fingerprint())
	return "%d edges %s" % [_edges.size(), "|".join(parts).sha256_text().substr(0, 16)]


# --- The three things that move an edge -----------------------------------


## A line spoken, and heard. Familiarity at both ends and nothing else -- the
## reasoning is at the head of this file.
func heard(speaker: int, listener: int, said: String, shouted: bool) -> RelationshipEdge:
	if speaker == listener:
		return null
	var edge := _edge_for(speaker, listener)
	edge.raise(speaker, "familiarity", MET)
	edge.raise(listener, "familiarity", MET)
	edge.note("#%d %s #%d \"%s\"" % [
		speaker, "shouted where" if shouted else "said to", listener,
		_clipped(said),
	])
	return edge


## An exchange the engine honoured. A gift is this with nothing coming back, and
## it is the same call: what makes it a gift is what was in it, which is the
## world's own record and not a second sort of event.
func traded(
	from_id: int, to_id: int,
	gave: int, gave_money: int, back: int, back_money: int
) -> RelationshipEdge:
	if from_id == to_id:
		return null
	var edge := _edge_for(from_id, to_id)
	for end in [from_id, to_id]:
		edge.raise(end, "familiarity", MET)
		edge.raise(end, "trust", TRADE_TRUST)
		edge.raise(end, "respect", TRADE_RESPECT)
	var given := gave > 0 or gave_money > 0
	var returned := back > 0 or back_money > 0
	if given and not returned:
		edge.raise(to_id, "trust", GIFT_TRUST)
	elif returned and not given:
		edge.raise(from_id, "trust", GIFT_TRUST)
	edge.note("#%d gave %s to #%d for %s" % [
		from_id, _parcel(gave, gave_money), to_id, _parcel(back, back_money),
	])
	return edge


## A blow the engine landed. `out_of` is the struck character's full health, so
## that the fear a blow causes is the share of that character it took rather than
## a number of points that means something different to everybody.
func struck(
	striker: int, struck_id: int, dealt: int, out_of: int
) -> RelationshipEdge:
	if striker == struck_id:
		return null
	var edge := _edge_for(striker, struck_id)
	edge.raise(striker, "familiarity", MET)
	edge.raise(struck_id, "familiarity", MET)
	var share := 0.0 if out_of <= 0 else clampf(float(dealt) / float(out_of), 0.0, 1.0)
	edge.raise(struck_id, "fear", share)
	edge.lower(struck_id, "trust", STRUCK_TRUST)
	edge.raise(struck_id, "respect", STRUCK_RESPECT)
	edge.note("#%d struck #%d for %d of %d" % [striker, struck_id, dealt, out_of])
	return edge


# --- The furniture --------------------------------------------------------


# The edge between two entities, made if this is the first thing to pass between
# them. The one place an edge is ever created.
func _edge_for(a: int, b: int) -> RelationshipEdge:
	var key := RelationshipEdge.key_for(a, b)
	if not _edges.has(key):
		_edges[key] = RelationshipEdge.between(a, b)
	return _edges[key]


static func _clipped(said: String) -> String:
	var bare := said.strip_edges()
	return bare if bare.length() <= SAID_AT_MOST \
		else bare.substr(0, SAID_AT_MOST - 1) + "..."


static func _parcel(things: int, money: int) -> String:
	if things == 0 and money == 0:
		return "nothing"
	var parts := PackedStringArray()
	if things > 0:
		parts.append("%d thing%s" % [things, "" if things == 1 else "s"])
	if money > 0:
		parts.append("%d coin%s" % [money, "" if money == 1 else "s"])
	return " and ".join(parts)
