extends RefCounted
## Bargain tables recorded on days other than the shipped one, kept so that the
## bargain suite can be replayed through more than one draw.
##
## ## Why this file exists
##
## `tests/test_bargain.gd` used to hard-assert that the trader's model closed
## the sale. That made re-recording `ModelRecording.BARGAIN_ROWS` a lottery with
## the suite's colour as the prize: the first draw of 2026-09-09 had the trader
## propose from six units away, be refused for reach, and then examine the pile
## for the rest of the run, and six checks went red on it (see
## `reports/observation-position.md`, "The bargain table was recorded twice, and
## here is why"). The pass was made a second time and the second draw is what
## ships.
##
## A suite that asserts machinery rather than a draw has to be *shown* to assert
## machinery, and the only honest way to show it is to replay it through draws
## that did different things. These are those draws. They are not a second
## shipped recording and nothing quotes them as one: no report reads a number
## off them, no shell run replays them, and `./run_record.sh` neither reads nor
## rewrites this file. They are past evidence, kept.
##
## ## Where each one came from
##
## Both were `ModelRecording.BARGAIN_ROWS` at a commit of this repository, copied
## out of it verbatim -- the same model, the same endpoint, the same recorder --
## and each is named by the commit it was the shipped table at. Neither was
## edited: a table edited by hand would not be a draw any more, and the whole
## point of them is that nobody chose what they say.
##
## ## Why it is in `net/` and not in `sim/` or `tests/`
##
## For the reason `net/model_recording.gd` is: what is in it is a stranger's
## prose, and the simulation is scanned for words that would mean it knows what
## sort of thing it is holding, with string literals read as code. It is data
## that came off the wire and it belongs beside the wire. It is a sibling of the
## recording rather than part of it because the recorder rewrites that file from
## what a live pass answered, and a past draw is exactly what must survive that.
class_name BargainDraws

## Which model answered these, and where. The same two the shipped recording
## names, because both tables were recorded by the same recorder against the
## same endpoint; a draw recorded against anything else would not be comparable
## to the shipped one and would not belong here.
const MODEL := "z-ai/glm-5.3-flash"
const ENDPOINT := "https://openrouter.ai/api/v1/chat/completions"

## The first bargain table, recorded 2026-09-07 and shipped at 9871350.
##
## Its trader haggles at length, proposes his lantern twice, and the sale
## closes. It is the draw the observation-position report replayed by position
## to show that the coarser position line had not broken the purchase.
const ROWS_2026_09_07 := [
	{"prompt": "ae72e92ed9acb6df", "reply": "examine target=#5", "ms": 3811},
	{"prompt": "ba026dfcd2c95cd9", "reply": "say text=Fen, do you have any coins to spare? I need to raise some money. target=#1", "ms": 3183},
	{"prompt": "3fab35d4afcdb2fb", "reply": "wait ticks=2", "ms": 3218},
	{"prompt": "d132aa0445a47985", "reply": "trade_propose  target=#1  want_money=6  give=[brass lantern]", "ms": 2655},
	{"prompt": "2332d4a083d8498f", "reply": "examine target=#4", "ms": 4384},
	{"prompt": "2332d4a083d8498f", "reply": "wait ticks=3", "ms": 2069},
	{"prompt": "b1e27d38e6b31732", "reply": "say text=\"6 coins for the lantern\" target=#1", "ms": 1988},
	{"prompt": "f9b90672209782ea", "reply": "wait ticks=1", "ms": 3060},
	{"prompt": "471af4347a19509a", "reply": "say text=\"So, Fen, will you take it?\" target=#1", "ms": 2580},
	{"prompt": "ea3891a434d5e4e1", "reply": "trade_accept target=#1", "ms": 5417},
	{"prompt": "f68ef28968e09826", "reply": "wait ticks=3", "ms": 3379},
	{"prompt": "e043ba93113f4344", "reply": "trade_accept target=#1", "ms": 11830},
	{"prompt": "428f5dd2c2a3cb3c", "reply": "wait ticks=1", "ms": 2049},
	{"prompt": "059c9856552f5d52", "reply": "wait ticks=5", "ms": 1982},
	{"prompt": "059c9856552f5d52", "reply": "done goal=1", "ms": 1632},
	{"prompt": "059c9856552f5d52", "reply": "done goal=1", "ms": 11296},
	{"prompt": "e77c5cdff934e1de", "reply": "wait ticks=5", "ms": 2196},
	{"prompt": "d8b95d6fda03b81f", "reply": "wait  ticks=1", "ms": 1376},
	{"prompt": "253bb52460e45be6", "reply": "done goal=1", "ms": 3624},
	{"prompt": "d8b95d6fda03b81f", "reply": "wait ticks=1", "ms": 4975},
	{"prompt": "c26c4b1bec2d0b7b", "reply": "wait  ticks=3", "ms": 6250},
	{"prompt": "d8b95d6fda03b81f", "reply": "trade_propose  target=#1 give=[lantern] want_money=6", "ms": 2451},
]

## The first draw of 2026-09-09, shipped at 6c79f56 and replaced at c8c351f.
##
## This is the draw that went red. The trader proposes `give=[brass lantern]
## want_money=8` on the fourth tick from six units away, the engine refuses it
## for reach, and he spends the rest of the run examining the pile and repeating
## his price aloud. No sale closes in it, and nothing in this project says one
## had to: the world offered him the same trade surface it offers anybody, and
## what he did with it was his.
const ROWS_2026_09_09_FIRST := [
	{"prompt": "eaaf6bbafcc7590d", "reply": "trade_propose target=#1 give=[brass lantern] want_money=8", "ms": 2878},
	{"prompt": "620432247c45822d", "reply": "examine target=#4", "ms": 897},
	{"prompt": "aa9c4a276fd21227", "reply": "examine target=#4", "ms": 1852},
	{"prompt": "5c84b7ef7fd004d2", "reply": "examine target=#4", "ms": 1782},
	{"prompt": "5c84b7ef7fd004d2", "reply": "examine target=#4", "ms": 1617},
	{"prompt": "21434a778a90ce94", "reply": "examine        target=#4", "ms": 1929},
	{"prompt": "a93f3275d97157d9", "reply": "trade_propose  target=#1 give=[brass lantern] want_money=10", "ms": 5024},
	{"prompt": "80e775485dccfa13", "reply": "say text=\"10 coins for the lantern, as I offered\" target=#1", "ms": 2926},
	{"prompt": "5cb9300ef8a4f3fa", "reply": "trade_deny target=#1", "ms": 1952},
	{"prompt": "43cae16ce97f2d87", "reply": "say text=\"Ten coins, remember. Pay me and it's yours.\" target=#1", "ms": 1709},
	{"prompt": "ff172d20663c8f9d", "reply": "trade_deny target=#1", "ms": 1997},
	{"prompt": "991c5917f86719b1", "reply": "wait  ticks=1", "ms": 1626},
	{"prompt": "991c5917f86719b1", "reply": "say text=\"Ten coins. Pay up and I'll hand it over.\" target=#1", "ms": 3591},
	{"prompt": "2683a71afe020f1c", "reply": "say text=\"Ten coins, Fen. I've made my offer — pay up and the lantern is yours.\" target=#1", "ms": 1950},
	{"prompt": "f132deb87da7baf8", "reply": "wait ticks=5", "ms": 4463},
	{"prompt": "74ccbe307e4aa047", "reply": "trade_propose target=#1 give=[brass lantern] want_money=10", "ms": 1571},
	{"prompt": "da4c3c64f1ef8e65", "reply": "say text=\"Ten coins. Do we have a deal?\" target=#1", "ms": 2322},
	{"prompt": "766149a7b3daef11", "reply": "wait ticks=5", "ms": 1878},
]

## Every past draw, each with the line that says where it came from: what the
## suite replays its machinery claims through, alongside the shipped table.
static func past() -> Array[Dictionary]:
	return [
		{
			"name": "the first bargain table, 2026-09-07 (9871350)",
			"rows": ROWS_2026_09_07,
			"from": _provenance("2026-09-07", "9871350", ROWS_2026_09_07.size()),
			"model": MODEL,
		},
		{
			"name": "the first draw of 2026-09-09 (6c79f56), which closed no sale",
			"rows": ROWS_2026_09_09_FIRST,
			"from": _provenance("2026-09-09", "6c79f56", ROWS_2026_09_09_FIRST.size()),
			"model": MODEL,
		},
	]


# Where one past draw came from, said the way the shipped recording says it,
# with the commit it was the shipped table at on the end.
static func _provenance(on: String, at: String, rows: int) -> String:
	return "recorded %s from %s at %s, %d replies, shipped at %s" % [
		on, MODEL, ENDPOINT, rows, at,
	]
