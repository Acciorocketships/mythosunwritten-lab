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
const RECORDED_ON := "2026-09-06"

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
	{"prompt": "aae16d1fbba77319", "reply": "examine target=#6", "ms": 1726},
	{"prompt": "070ba2060497f262", "reply": "say text=Hail, traveler. Who are you? target=#4", "ms": 1879},
	{"prompt": "4237226d506efcd5", "reply": "say text=Hail, traveler. target=#3", "ms": 1602},
	{"prompt": "a75bcb1db3f8a2d6", "reply": "recall about=nothing", "ms": 1793},
	{"prompt": "17052e48f19e0f22", "reply": "go_to target=#2", "ms": 1496},
	{"prompt": "af8411f4396c1290", "reply": "go_to offset=(3, 0)", "ms": 2296},
	{"prompt": "61322f7c035ba990", "reply": "say text=Well met. What brings you this way? target=#4", "ms": 1579},
	{"prompt": "556e6bab83a10623", "reply": "say text=I am Sable, a traveler with a spear. What brings you here? target=#3", "ms": 1557},
	{"prompt": "896fb5660f4004f3", "reply": "say text=good morning, Wren target=#1", "ms": 1579},
	{"prompt": "632237e9d1da868e", "reply": "wait ticks=3", "ms": 8527},
	{"prompt": "0b50af7faf29d252", "reply": "say text=I am headed north, exploring this land. Are you from around here? target=#3", "ms": 1827},
	{"prompt": "e42b5fefa84b21b0", "reply": "say text=a fine morning for it, Pell #7", "ms": 1592},
	{"prompt": "2102304ca74a9d6d", "reply": "say text=\"I am Bram, a swordsman. I saw a pile of goods some ways east of here — care to look at it together?\" target=#4", "ms": 2080},
	{"prompt": "fbe39d6ef1c4bcd4", "reply": "pick_up        item=brass lantern target=#6", "ms": 1942},
	{"prompt": "681d68ccc3e2ab64", "reply": "say text=\"Just exploring northward, seeking new lands. Safe travels to you, Bram.\" target=#3", "ms": 1817},
	{"prompt": "1de3827d8055fe6d", "reply": "say text=\"and a fine morning to you both\" target=#1", "ms": 1633},
	{"prompt": "0b335d3a64cb64c2", "reply": "explore east", "ms": 2289},
	{"prompt": "0571ecf954d8be0d", "reply": "say text=\"a fine morning indeed, Rook\" target=#2", "ms": 13901},
	{"prompt": "72bdce5e20e31d08", "reply": "go_to target=#6", "ms": 5388},
	{"prompt": "6b474e639cb77a84", "reply": "go_to offset=(0.0, -3.0)", "ms": 1325},
	{"prompt": "e2f6d5253b437982", "reply": "say text=\"what brings you out this way?\" target=#1", "ms": 1498},
	{"prompt": "0a268ac4f2dae91e", "reply": "say text=\"A pile of goods east, you say? Lead the way, Bram — I'll come along.\" target=#3", "ms": 1704},
	{"prompt": "1eb34ed6691f3657", "reply": "examine target=#6", "ms": 2372},
	{"prompt": "61d7333d161c335a", "reply": "say text=\"I asked first, Wren — what brings you out this way?\" target=#1", "ms": 1747},
	{"prompt": "fcf7e8754c62b87a", "reply": "say text=A pile of goods, you say? Lead the way east — my spear and I will come along. target=#3", "ms": 1992},
	{"prompt": "39f290250313c38a", "reply": "examine target=#6", "ms": 2090},
	{"prompt": "fa1ffa0c09258606", "reply": "say text=\"still waiting on you, Wren — what brings you this way?\" target=#1", "ms": 1766},
	{"prompt": "ffbad4a1d79c1321", "reply": "go_to target=#3", "ms": 1325},
	{"prompt": "ef8e45607ba4afd7", "reply": "examine target=#6", "ms": 1791},
	{"prompt": "e7e7b18a46b8e637", "reply": "go_to offset=(0.0, 3.0)", "ms": 1970},
	{"prompt": "92a6b27b6807a849", "reply": "examine target=#6", "ms": 12916},
	{"prompt": "6add82c794514366", "reply": "examine target=#6", "ms": 1554},
	{"prompt": "1210a1fbfacf35de", "reply": "go_to target=#6", "ms": 1575},
	{"prompt": "028e079d73b650a5", "reply": "wait ticks=2", "ms": 1672},
	{"prompt": "2676418595f36641", "reply": "say text=\"Safe travels, Sable. I'll check that pile just here before moving on.\" target=#4", "ms": 1655},
	{"prompt": "9190fb7310a141b8", "reply": "say text=\"well, if no one will talk, I'll have a look at that pile\" target=#1", "ms": 1665},
	{"prompt": "fc45b153c7a5aa4c", "reply": "examine target=#6", "ms": 1599},
	{"prompt": "b4ce04a913583f99", "reply": "wait ticks=1", "ms": 1830},
	{"prompt": "73045cdea7096dcc", "reply": "go_to offset=(0, 6)", "ms": 1714},
	{"prompt": "b1aa630236941c64", "reply": "examine target=#6", "ms": 3523},
	{"prompt": "856028f6916c18a6", "reply": "examine target=#6", "ms": 2292},
	{"prompt": "65b1e38bf91b0170", "reply": "examine target=#6", "ms": 1515},
	{"prompt": "42fe8a296d5d739e", "reply": "examine target=#6", "ms": 1493},
	{"prompt": "da8c44624c1826a0", "reply": "say text=\"Safe travels, Bram.\" target=#3", "ms": 1820},
	{"prompt": "04e17feddf161356", "reply": "examine target=#6", "ms": 1644},
	{"prompt": "8db33cadc0f0f3fa", "reply": "examine target=#6", "ms": 1257},
	{"prompt": "0f6b6ae37375540d", "reply": "examine target=#6", "ms": 1753},
	{"prompt": "61d57995dccaf400", "reply": "examine target=#6", "ms": 1622},
	{"prompt": "cdb7f8f9065bb717", "reply": "pick_up item=sword target=#6", "ms": 1368},
	{"prompt": "8db33cadc0f0f3fa", "reply": "examine target=#6", "ms": 1355},
	{"prompt": "cb99676891923d88", "reply": "go_to offset=(0.0, -3.0)", "ms": 1403},
	{"prompt": "b6bfa0320fecdd05", "reply": "examine target=#6", "ms": 1799},
	{"prompt": "19045705a9f02322", "reply": "go_to target=#6", "ms": 1398},
	{"prompt": "9b2946f78fe8205f", "reply": "examine target=#6", "ms": 1478},
	{"prompt": "623dd3837d9b5f93", "reply": "go_to target=#6", "ms": 1846},
	{"prompt": "e104db4907a41190", "reply": "say text=good morning, strangers — welcome to the market target=#3", "ms": 2226},
	{"prompt": "75d15db8174d15d0", "reply": "recall about=pile of goods east of here", "ms": 1559},
	{"prompt": "8b390259644bf15a", "reply": "examine target=#6", "ms": 1265},
	{"prompt": "0a8d65d1ea804d68", "reply": "say text=\"good morning, stranger — I'm Pell. Might you have a brass lantern to sell?\" target=#4", "ms": 2353},
	{"prompt": "c411879959a7a1d9", "reply": "go_to offset=(3.0, 0.0)", "ms": 1509},
	{"prompt": "f47abef681d27f53", "reply": "go_to target=#6", "ms": 1345},
	{"prompt": "01e5397d30255e42", "reply": "go_to target=#7", "ms": 1792},
	{"prompt": "b39c9bd8f8f3ad5f", "reply": "examine target=#6", "ms": 1499},
	{"prompt": "38eb5f39c3e93f49", "reply": "wait   ticks=3", "ms": 1774},
	{"prompt": "6f992bb5f5e0dd4f", "reply": "say text=\"Pell, good to see you — anyone care to tell me what that pile over there is about?\" target=#7", "ms": 1862},
	{"prompt": "193bb592078806c5", "reply": "say text=\"Anyone? I'm after a brass lantern — happy to pay.\" target=#4", "ms": 1905},
	{"prompt": "f2e97bbf812ffe8e", "reply": "go_to offset=(2.1, 0.0)", "ms": 1517},
	{"prompt": "b23bda9050724c77", "reply": "say text=\"No lantern on me, Pell — just boots and a spear.\" target=#7", "ms": 1567},
	{"prompt": "7fade27b566b3785", "reply": "say text=\"that 'fair bargain' pile — is that yours, Wren? what's in it?\" target=#1", "ms": 1949},
	{"prompt": "3865a4e28cc23111", "reply": "examine target=#2", "ms": 1551},
	{"prompt": "9a76b670bc62877a", "reply": "say text=\"That pile? I couldn't say, Rook — I'm just after a brass lantern myself.\" target=#2", "ms": 1823},
	{"prompt": "19252788f7168975", "reply": "wait ticks=3", "ms": 1736},
	{"prompt": "aa219b1a81203908", "reply": "say text=\"Good morning, Pell — this market looks busy. What goods are on offer?\" target=#7", "ms": 1919},
	{"prompt": "c905fe3ce0e9b18a", "reply": "say text=\"Wren, you shouted 'a fair bargain' — what bargain is that? Show me what you're offering.\" target=#1", "ms": 1786},
	{"prompt": "2db73155df03168b", "reply": "say text=\"Wren might have one, Pell — worth asking them.\" target=#7", "ms": 1746},
	{"prompt": "2b26c2d47b8b8a94", "reply": "say text=Bram, morning — no goods of mine yet; I'm hunting a brass lantern, happy to pay coins if anyone has one target=#3", "ms": 2295},
	{"prompt": "de8483d82a277acc", "reply": "explore\n\ngo_to offset=(3, 0)", "ms": 1475},
	{"prompt": "f4a1529efa33e12a", "reply": "say text=\"What goods are you selling, Pell? I have a sword and boots, and coin if the price is right.\" target=#7", "ms": 2143},
	{"prompt": "1dcb62013c5b1000", "reply": "say text=\"Any lantern leads, Wren? Pell here is paying for one.\" target=#1", "ms": 1731},
]

## The goal comparison's four questions, recorded in the same pass.
const GOAL_ROWS := [
	{"prompt": "a1fac88618de0162", "reply": "recall about=bargain", "ms": 1611},
	{"prompt": "5c42c15872933ee3", "reply": "go_to target=(-471.0, 416.0)", "ms": 1473},
	{"prompt": "6c60c917116cdd4d", "reply": "trade_propose target=#2 want_money=9", "ms": 1692},
	{"prompt": "9d15c4083930cb9b", "reply": "say text=a fair bargain indeed, friend Wren target=#1", "ms": 1406},
]

## The lesson comparison's four questions, recorded in the same pass.
const LESSON_ROWS := [
	{"prompt": "a1fac88618de0162", "reply": "say text=then let us trade target=#1", "ms": 1428},
	{"prompt": "09603f85aa582981", "reply": "recall about=pile #6", "ms": 8844},
	{"prompt": "42e05814d5e686b2", "reply": "trade_propose  target=#2 give_money=9", "ms": 2716},
	{"prompt": "282a40c81f9070c7", "reply": "wait ticks=1", "ms": 2172},
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
