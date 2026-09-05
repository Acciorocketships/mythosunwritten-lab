extends RefCounted
## One exchange with a language model, carried out once and written down.
##
## This file is the reason `./run_tests.sh` and `./run_agent.sh` need no key, no
## network and no model: the questions the shipped run puts were put once to a
## real model over a real connection, and what came back is here. A replaying
## `ModelChannel` answers the n-th question of the run with the n-th row of this
## table, so the run is a fact about the seed rather than about what the machine
## running it happens to have installed.
##
## ## Why it is in `net/` and not in `sim/`
##
## Because what is in it is a stranger's prose. The simulation is scanned, file by
## file, for words that would mean it knows what sort of thing it is holding --
## `player`, `npc`, `human`, `llm`, `ai` -- and the scan reads string literals as
## code on purpose, so that a branch cannot hide in one. A table of things a
## language model said is therefore the last thing that can live under `sim/`: the
## endpoint alone tripped it on `openrouter.ai`, and any reply mentioning a person
## would trip it next. It is data that came off the wire, it belongs beside the
## wire, and the simulation is *handed* it rather than reaching for it -- which is
## also why nothing under `sim/` names this file.
##
## It is generated, not written. `./run_record.sh --live` plays the shipped run
## with a live channel and rewrites this file from what came back; everything
## below the marker is the recorder's output. Editing it by hand would make the
## word "recorded" untrue.
##
## ## What a row is
##
##   * `prompt` -- the first sixteen characters of the sha256 of the prompt that
##     was sent. The prompt itself is not kept here: it is two thousand
##     characters of observation and it is reproduced exactly by the run, so
##     keeping it would be keeping a copy of something the code already
##     generates. The digest is what makes drift *visible*: if the observation
##     layer changes under this recording, the replay still answers -- rows are
##     read in order -- and says in the transcript that the question it was
##     answering is not the question that was recorded.
##   * `reply` -- what the model said, verbatim.
##   * `ms` -- how many milliseconds that call actually took, which is the one
##     number in this file that says something about the live path rather than
##     about the replay.
##
## ## Five tables, recorded in one pass
##
## `ROWS` answers the shipped run's questions, in the order it puts them.
## `LESSON_ROWS` answers the four questions `./run_lesson.sh` puts -- one moment
## asked once with no lesson in the character's memory and once for each of three
## lessons. `GOAL_ROWS` answers the four `./run_goal.sh` puts -- the same moment,
## asked once after nothing at all and once for each of three goals. `CHECK_ROWS`
## answers the difficulty-class run's questions -- the judging question for each
## attempt of a shape the character has not attempted before, and a resolving
## question for each of those the engine then rolled a success on. `WORLD_ROWS`
## answers the orchestrator run's questions -- one every time it looks at the
## world, and one more every time a look spawned somebody and it was asked who
## that is. They are five tables and not one because they are five runs; they are
## written by one command, in one pass, so that they can never be a recording of
## five different days against five different prompts.
##
## Nothing here is a decision of this project's. The replies are the model's own
## words, and where a reply chose something the world then refused, the refusal
## is in the transcript rather than edited out of the recording.
class_name ModelRecording

## Which model was asked, where, and when. Rewritten by the recorder.
const MODEL := "z-ai/glm-5.3-flash"
const ENDPOINT := "https://openrouter.ai/api/v1/chat/completions"
const RECORDED_ON := "2026-09-05"

## Whether these replies came from a model running on the machine that recorded
## them rather than from the endpoint the shipped recording is made against.
##
## A local model answers this run's questions in a fifth of a second and for
## nothing, which makes it the right thing to iterate against and the wrong
## thing to ship: the replies checked in here are quoted across the reports as
## what a capable model chose. So a recording made against one says so in its
## own provenance line -- printed at the head of every run that replays it --
## and no report can quote it as the other thing.
const LOCAL := false

## When the difficulty-class table was recorded, which is its own date because
## it is the one table that can be recorded on its own -- `./run_record.sh
## --live --checks` puts only its questions and writes the other three back
## unchanged. A run that adds a fourth table is not a reason to spend a whole
## pass on the other three and to move every number quoted off their
## transcripts.
const CHECKS_RECORDED_ON := "2026-09-05"

## When the orchestrator table was recorded, which is its own date for the same
## reason the difficulty-class one is: `./run_record.sh --live --world` puts only
## its questions and writes the other four back unchanged.
const WORLD_RECORDED_ON := "2026-09-05"

## The exchange. Rewritten by the recorder; see the note above.
const ROWS := [
	{"prompt": "6d9360f47822fdf7", "reply": "examine target=#6", "ms": 9748},
	{"prompt": "8d4cf7c16e0eb939", "reply": "examine target=#6", "ms": 16940},
	{"prompt": "4f3f02d102c78fb6", "reply": "say text=Hail, traveler. I am Sable. target=#3", "ms": 1479},
	{"prompt": "5db54dab037314b6", "reply": "go_to offset=(6, 0)", "ms": 1157},
	{"prompt": "3aab9986edfb9641", "reply": "go_to target=#2", "ms": 1508},
	{"prompt": "c0a595e1e00edaa4", "reply": "examine target=#6", "ms": 19157},
	{"prompt": "bcc0df1a5d1a676b", "reply": "say text=\"What brings you to these parts?\" target=#3", "ms": 1467},
	{"prompt": "522df99db5464106", "reply": "say text=good morning, Wren target=#1", "ms": 12141},
	{"prompt": "056d4014ad9215af", "reply": "say text=Well met, Sable. I am Bram. target=#4", "ms": 1328},
	{"prompt": "c8979cd8d5219667", "reply": "say text=\"Lovely quiet stretch of land, isn't it?\" target=#3", "ms": 2192},
	{"prompt": "759f0f363e1d4325", "reply": "say text=\"a fine morning for it. What brings you out here, Wren?\" target=#1", "ms": 871},
	{"prompt": "6994ca6df979c54b", "reply": "say text=\"Just passing through, friend. What brings you out here?\" target=#4", "ms": 918},
	{"prompt": "a7ba13e753ee5e61", "reply": "jump target=(-478, 469)", "ms": 24275},
	{"prompt": "e538d64142ba5719", "reply": "go_to target=#2", "ms": 1295},
	{"prompt": "8a424361e0b590a2", "reply": "say text=\"Care to see what's in that pile, Wren? Maybe something useful in there.\" target=#1", "ms": 3446},
	{"prompt": "ec2910a05dd958c6", "reply": "wait ticks=3", "ms": 19714},
	{"prompt": "81f76db654f169d6", "reply": "wait ticks=10", "ms": 19756},
	{"prompt": "4536f3bba456781c", "reply": "wait ticks=1", "ms": 13546},
	{"prompt": "d719ee1a172a59b7", "reply": "examine target=#6", "ms": 16914},
	{"prompt": "c84911ceff3d52e7", "reply": "say text=\"Oh, just wandering — looking for a bit of adventure, maybe some coin. Care to travel together?\" target=#3", "ms": 2349},
	{"prompt": "199a2edc450f7cb4", "reply": "say text=\"Wanderlust, mostly. And yourself — a soldier out this far?\" target=#4", "ms": 2036},
	{"prompt": "7de9219f0eb92fa5", "reply": "examine target=#6", "ms": 1517},
	{"prompt": "eb7e377ba5da5b8b", "reply": "wait ticks=2", "ms": 6895},
	{"prompt": "1e788c5c98a3c4b3", "reply": "go_to offset=(6, 0)", "ms": 24125},
	{"prompt": "977eaa729351f987", "reply": "examine target=#6", "ms": 2743},
	{"prompt": "25030c6e328123e3", "reply": "examine target=#6", "ms": 1842},
	{"prompt": "d4ef326e08e2b81f", "reply": "say text=\"A soldier out this way could find plenty of adventure, I'd wager. Traveling together suits me fine — where shall we head?\" target=#4", "ms": 2105},
	{"prompt": "505890496a43fb0a", "reply": "say text=\"Soldiering, mostly — a spear for hire, but the roads have been quiet of late. Perhaps coin and company lie the same direction; shall we walk together?\" target=#3", "ms": 4264},
	{"prompt": "f7721823d70aaeee", "reply": "examine target=#6", "ms": 4118},
	{"prompt": "925820a5498014b9", "reply": "say text=\"Wren, let's look in that pile together.\" target=#1", "ms": 1459},
	{"prompt": "13ff8488016d0b10", "reply": "say text=\"Northeast, perhaps — unexplored country lies that way. Ready when you are, Sable.\" target=#4", "ms": 1678},
	{"prompt": "b44b1926f0775a8a", "reply": "say text=\"East, then — up toward the high ground. Quiet roads seldom stay quiet, and hills hide the best adventures.\" target=#3", "ms": 25223},
	{"prompt": "74b84ec2a38a366b", "reply": "say text=Do either of you have a brass lantern to sell or trade? I have 9 coins. target=#2", "ms": 27738},
	{"prompt": "4285b2372d3fd5c1", "reply": "go_to #6", "ms": 2523},
	{"prompt": "986a881ead9e4ad6", "reply": "say text=\"Northeast, toward that stranger perhaps — but careful, Sable. Eyes up.\" target=#4", "ms": 4603},
	{"prompt": "06588d263b60ad86", "reply": "go_to offset=(6, 0)", "ms": 1242},
	{"prompt": "875c0e952b1df68e", "reply": "go_to offset=(3.0, 0.0)", "ms": 8326},
	{"prompt": "1e4e1cd28084dfaf", "reply": "wait   ticks=5", "ms": 1699},
	{"prompt": "03e9d1beed705271", "reply": "go_to offset=(+6.0, +1.2)", "ms": 1656},
	{"prompt": "37eff786c2517379", "reply": "examine target=#2", "ms": 56894},
	{"prompt": "c73bc607cdb048a4", "reply": "wait ticks=2", "ms": 1669},
	{"prompt": "9044d22564f6b2cb", "reply": "say text=\"I don't have a brass lantern, Pell, but I do have a silk cloak I'd sell for 9 coins.\" target=#7", "ms": 1519},
	{"prompt": "720ed297a1f360b4", "reply": "wait ticks=5", "ms": 1528},
	{"prompt": "caa782077c4d5e5c", "reply": "go_to offset=(3.0, 0.0)", "ms": 17329},
	{"prompt": "e1d43f10d8cf7e75", "reply": "go_to target=#3", "ms": 2073},
	{"prompt": "78cc68098a0b09f4", "reply": "go_to offset=(+6.0, -6.0)", "ms": 1644},
	{"prompt": "b544bcd2d674702b", "reply": "trade_propose target=#7 give=[silk cloak] want_money=9", "ms": 1637},
	{"prompt": "468df88ffa4f1828", "reply": "trade_propose target=#2 give_money=9 want=[silk cloak]", "ms": 1440},
	{"prompt": "6bf8a4291af06d57", "reply": "trade_propose target=#7 give=[silk cloak] want_money=9", "ms": 1739},
	{"prompt": "2c1d2f2eced69c93", "reply": "say text=\"Wren, do you have a brass lantern to sell? I have 9 coins.\" target=#1", "ms": 1872},
	{"prompt": "fc73e326f5054e19", "reply": "trade_propose target=#7 give=[silk cloak] want_money=9", "ms": 1459},
	{"prompt": "425ccc39e6123a2c", "reply": "say text=\"Thank you, Rook. I'll pass on the cloak — I'm set on a brass lantern. Wren, would you sell me one?\" target=#1", "ms": 1423},
	{"prompt": "481e8bd65d184c1f", "reply": "go_to offset=(3.0, 0.0)", "ms": 31161},
	{"prompt": "2501a62df39241f5", "reply": "go_to offset=(3.0, 0.0)", "ms": 2157},
	{"prompt": "fc73e326f5054e19", "reply": "trade_propose target=#7 give=[silk cloak] want_money=9", "ms": 2163},
	{"prompt": "1a04f852c23fdc53", "reply": "recall  about=brass lantern", "ms": 1540},
	{"prompt": "1b93457bb125dacf", "reply": "trade_propose  target=#1  give_money=9  want=[brass lantern]", "ms": 2823},
	{"prompt": "92a9493815a6c1ef", "reply": "trade_propose  target=#7  give=[silk cloak]  want_money=9", "ms": 1318},
	{"prompt": "a2aa97f827f5144b", "reply": "trade_propose target=#1 give_money=9 want=[brass lantern]", "ms": 2972},
	{"prompt": "92a9493815a6c1ef", "reply": "trade_propose target=#7 give=[silk cloak] want_money=9", "ms": 1448},
	{"prompt": "c8f23977ba316d0a", "reply": "go_to offset=(3.0, 0.0)", "ms": 13608},
	{"prompt": "19d9cba7acf3ef9b", "reply": "go_to offset=(6, 0)", "ms": 1534},
	{"prompt": "a2aa97f827f5144b", "reply": "say text=\"Wren, I'll take your silence as a no. I have 9 coins if you change your mind about a brass lantern.\" target=#1", "ms": 1458},
	{"prompt": "92a9493815a6c1ef", "reply": "trade_propose  target=#7 give=[silk cloak] want_money=9", "ms": 1968},
	{"prompt": "243ce279322f96f5", "reply": "go_to offset=(6.0, 3.0)", "ms": 1748},
	{"prompt": "7a6350f539852795", "reply": "trade_propose target=#7 give=[silk cloak] want_money=9", "ms": 1342},
	{"prompt": "bc8828d1af6ef0cc", "reply": "recall about=brass lantern", "ms": 4432},
	{"prompt": "3991ed02d7ccfe16", "reply": "say text=\"Farewell, then. I'll seek a brass lantern elsewhere.\" target=#2", "ms": 1531},
	{"prompt": "fa5575e5c83f385b", "reply": "trade_propose target=#7 give=[silk cloak] want_money=9", "ms": 2004},
	{"prompt": "76b9ec057263d4af", "reply": "trade_deny target=#2", "ms": 1803},
	{"prompt": "bfc8438137a15413", "reply": "go_to offset=(3.0, 0.0)", "ms": 574},
	{"prompt": "c83812b26d3c3f68", "reply": "recall about=noise", "ms": 1499},
	{"prompt": "4a26b55ce1afe4f9", "reply": "go_to offset=(6, 0)", "ms": 1336},
	{"prompt": "8d441dc67539b06f", "reply": "recall   about=brass lantern", "ms": 3786},
	{"prompt": "243ce279322f96f5", "reply": "say text=Agreed, eyes up. Lead the way northeast — I'll watch our flank. target=#3", "ms": 1490},
	{"prompt": "f4ca17bf147a42a3", "reply": "say text=\"Pell, changing your mind? The silk cloak is still yours for 9 coins.\" target=#7", "ms": 1345},
	{"prompt": "e1d081b940c87013", "reply": "go_to target=(0, -40)", "ms": 3096},
	{"prompt": "2a2ab5001da21ca1", "reply": "say text=\"Wait, Pell! Take the cloak for 9 coins, I'll trade you right here.\" target=#7", "ms": 2079},
	{"prompt": "6cde21ebed57398c", "reply": "go_to offset=(6.0, 3.0)", "ms": 3999},
]

## The goal comparison's four questions, recorded in the same pass.
const GOAL_ROWS := [
	{"prompt": "a2a5e1e44a3ae219", "reply": "say text=\"what bargain do you offer?\" target=#1", "ms": 2357},
	{"prompt": "4385c3db379e6198", "reply": "go_to   offset=(5.0, -6.0)", "ms": 1739},
	{"prompt": "b54959b49794a7c1", "reply": "trade_propose target=#2 give_money=9 want=[an axe]", "ms": 1356},
	{"prompt": "d8e8e038403335f2", "reply": "say text=a fair bargain, agreed target=#1", "ms": 1306},
]

## The lesson comparison's four questions, recorded in the same pass.
const LESSON_ROWS := [
	{"prompt": "a2a5e1e44a3ae219", "reply": "say text=\"what bargain did you have in mind?\" target=#1", "ms": 2583},
	{"prompt": "94a5bd0a9b549d16", "reply": "trade_accept  target=#1", "ms": 1749},
	{"prompt": "4c8ce6a67beefb8d", "reply": "recall about=bargain", "ms": 1771},
	{"prompt": "0e6dff84e0255831", "reply": "recall  about=bargain or trade with Wren", "ms": 4158},
]

## The difficulty-class run's questions, on their own date above.
const CHECK_ROWS := [
	{"prompt": "b723d1dc859f2ded", "reply": "dc=12 ability=str", "ms": 1271},
	{"prompt": "4b265df7f4e73b4a", "reply": "open target=#2", "ms": 1194},
	{"prompt": "424074711a1ba4fe", "reply": "dc=10 ability=dex", "ms": 1293},
	{"prompt": "8b86636a0af3979b", "reply": "open   target=#4", "ms": 5622},
]

## The orchestrator run's questions, on their own date above.
const WORLD_ROWS := [
	{"prompt": "b77c1f0f47dd07fa", "reply": "spawn role=scout at=(-476.0, 418.0)\nopen target=#3\nplace kind=stone at=(-470.0, 415.0)", "ms": 4497},
	{"prompt": "73280e9a88e2ef7c", "reply": "name=Vesper Quick\ntraits=agile, observant, soft-handed\ntendencies=ducks work that needs muscle, watches before speaking, smooths things over with charm\nbackstory=Raised on the edge of nine rings of settled ground, Vesper learned to slip through gaps and read a trail faster than anyone, but a body that tires early taught them to talk their way out of what their arms cannot carry.", "ms": 6623},
	{"prompt": "1ce5fe114cf96571", "reply": "spawn role=scout at=(-478.0, 416.0)\nspill target=#2", "ms": 1874},
	{"prompt": "1814df89cf7d67f9", "reply": "name=Quickfoot Sable\ntraits=agile, observant, awkward in company\ntendencies=acts first, trusts their own eyes, keeps to the edges\nbackstory=Raised on the outskirts of the nine rings, they learned to move light and watch close, more at home slipping past trouble than talking their way through it.", "ms": 1259},
	{"prompt": "82746f9a1990768f", "reply": "spawn role=herald at=(-472.0, 419.0)\nopen target=#5\nmove target=#7 to=(-475.0, 418.0)", "ms": 1502},
	{"prompt": "f5a7da6002a96f8d", "reply": "name=Veylin Brightvoice\ntraits=silver-tongued, charismatic, tactless\ntendencies=talks first, wins strangers over, misses the obvious\nbackstory=Born in the outer ninth ring, Veylin learned early that a charming word opens more doors than any sword arm. But a lifetime of being applauded for pretty speeches left no room for learning when to stay quiet.", "ms": 3886},
	{"prompt": "3a94ebb7269d8ddb", "reply": "spawn role=herald at=(-474.0, 416.0)\nplace kind=chest at=(-479.0, 421.0)\nopen target=#9", "ms": 1819},
	{"prompt": "b4e30dfb88bdb990", "reply": "name=Vessalius Goldtongue\ntraits=charismatic, sturdy, clumsy\ntendencies=talks first, collects followers, fumbles delicate work\nbackstory=Raised on the ninth ring's streets, Vessalius won every crowd with a silver voice and a thick hide to take the jeers, though her clumsy hands could never hold what her words promised.", "ms": 2318},
	{"prompt": "14c8709b4ee94a64", "reply": "place kind=chest at=(-468.0, 420.0)\nspawn role=scout at=(-466.0, 417.0)\nnothing", "ms": 3053},
	{"prompt": "5a8f65cec544f29a", "reply": "name=Quickfoot Sable\ntraits=light-fingered, restless, soft-spoken\ntendencies=flees before fighting, trusts instinct over plans, avoids heavy burdens\nbackstory=Raised on the far edges of the nine rings, Quickfoot learned early that being the fastest in any crowd mattered more than being the strongest, and a lifetime of dodging consequences left more than one promise dropped behind them.", "ms": 2521},
]


## The whole recording as one thing to hand to a channel: the replies, a line
## saying where they came from, and which model said them.
##
## One bundle rather than three arguments, because `sim/model_channel.gd` may not
## name this file and so has to be given everything it needs about it in one go.
static func exchange() -> Dictionary:
	return {"rows": ROWS, "from": provenance(), "model": MODEL}


## The lesson comparison's own exchange, in the same shape.
static func lesson_exchange() -> Dictionary:
	return {"rows": LESSON_ROWS, "from": provenance(), "model": MODEL}


## The goal comparison's own exchange, in the same shape.
static func goal_exchange() -> Dictionary:
	return {"rows": GOAL_ROWS, "from": provenance(), "model": MODEL}


## The difficulty-class run's own exchange, in the same shape, and with its own
## date on it.
static func check_exchange() -> Dictionary:
	return {"rows": CHECK_ROWS, "from": check_provenance(), "model": MODEL}


## The orchestrator run's own exchange, in the same shape, and with its own date
## on it.
static func world_exchange() -> Dictionary:
	return {"rows": WORLD_ROWS, "from": world_provenance(), "model": MODEL}


## How a provenance line names who answered: the model, and whether it was one
## running on the machine that recorded it. See `LOCAL` above.
static func said_by() -> String:
	return "a local model, %s" % MODEL if LOCAL else MODEL


## Where the orchestrator replies came from.
static func world_provenance() -> String:
	return "recorded %s from %s at %s, %d replies" % [
		WORLD_RECORDED_ON, said_by(), ENDPOINT, WORLD_ROWS.size(),
	]


## Where the difficulty-class replies came from.
static func check_provenance() -> String:
	return "recorded %s from %s at %s, %d replies" % [
		CHECKS_RECORDED_ON, said_by(), ENDPOINT, CHECK_ROWS.size(),
	]


## How many replies the recording holds.
static func size() -> int:
	return ROWS.size() + LESSON_ROWS.size() + GOAL_ROWS.size() \
		+ CHECK_ROWS.size() + WORLD_ROWS.size()


## One line saying where the replies came from, printed at the head of a run that
## replays them.
##
## It counts the three tables it is the date of, and not the difficulty-class or
## orchestrator tables, each of which has its own date and its own line.
static func provenance() -> String:
	return "recorded %s from %s at %s, %d replies" % [
		RECORDED_ON, said_by(), ENDPOINT,
		ROWS.size() + LESSON_ROWS.size() + GOAL_ROWS.size(),
	]
