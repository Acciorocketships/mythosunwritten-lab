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
## ## Six tables, recorded in one pass
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
## that is. `GOODWILL_ROWS` answers the goodwill run's, and `BARGAIN_ROWS` the
## bargain run's -- the trader Hob's questions while a person buys a named item
## off him (`sim/scripted_bargain.gd`). They are separate tables and not one
## because they are separate runs; the groups that must agree are written by one
## command, in one pass, so that they can never be a recording of
## five different days against five different prompts.
##
## Nothing here is a decision of this project's. The replies are the model's own
## words, and where a reply chose something the world then refused, the refusal
## is in the transcript rather than edited out of the recording.
class_name ModelRecording

## Which model was asked, where, and when. Rewritten by the recorder.
const MODEL := "z-ai/glm-5.3-flash"
const ENDPOINT := "https://openrouter.ai/api/v1/chat/completions"
const RECORDED_ON := "2026-09-09"

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

## When the goodwill table was recorded, which is its own date for the same
## reason the other two are: `./run_record.sh --live --goodwill` puts only its
## questions and writes the other five back unchanged.
const GOODWILL_RECORDED_ON := "2026-09-07"

## When the bargain table was recorded, which is its own date for the same
## reason the others are: `./run_record.sh --live --bargain` puts only its
## questions and writes the other six back unchanged.
const BARGAIN_RECORDED_ON := "2026-09-09"

## The exchange. Rewritten by the recorder; see the note above.
const ROWS := [
	{"prompt": "a0db2c61ed7b1b00", "reply": "examine target=#6", "ms": 2158},
	{"prompt": "230f9d3b6f839d2f", "reply": "examine target=#6", "ms": 6830},
	{"prompt": "f05308a31847576e", "reply": "examine target=#3", "ms": 3703},
	{"prompt": "2f01ad292a802d5b", "reply": "go_to offset=(0, -6)", "ms": 1302},
	{"prompt": "30e8343d72d0db14", "reply": "go_to target=#2", "ms": 2160},
	{"prompt": "054424fbbc454657", "reply": "go_to target=#6", "ms": 1460},
	{"prompt": "f05308a31847576e", "reply": "say text=Hail, traveler! What brings you here? target=#3", "ms": 2003},
	{"prompt": "fd6ab943f7b48c0e", "reply": "say text=\"good morning, Wren\" target=#1", "ms": 1828},
	{"prompt": "3defe809affd145e", "reply": "wait ticks=5", "ms": 1429},
	{"prompt": "14423f7d074d4eaa", "reply": "say text=there is a pile over east, shall we see what it holds? target=#1", "ms": 1781},
	{"prompt": "eba9b7d1f164afa4", "reply": "say text=Fine day for a walk, friend. Mind if I join you a while? target=#3", "ms": 1538},
	{"prompt": "c59c5a1f09cc0db9", "reply": "explore, nothing around. go_to offset=(0, 6)", "ms": 3758},
	{"prompt": "4c27f8b82f4dd76a", "reply": "say text=Where can I find a brass lantern? target=#2", "ms": 2952},
	{"prompt": "14f1188cc6f81c6b", "reply": "go_to target=#6", "ms": 2249},
	{"prompt": "6f9dbd1bb307bb90", "reply": "go_to  offset=(1, -2)", "ms": 1560},
	{"prompt": "15720ded5ffc259a", "reply": "go_to offset=(-15, 2)", "ms": 1464},
	{"prompt": "9d79f7d308eb5a85", "reply": "examine target=#6", "ms": 2762},
	{"prompt": "ffcbced7f6e4efad", "reply": "say text=\"Hail! Just wandering, friend. Looking for work or trade, mostly.\" target=#4", "ms": 2703},
	{"prompt": "e6aba871403ce268", "reply": "recall  about=brass lantern", "ms": 1612},
	{"prompt": "079fb8b49c03a191", "reply": "say text=Hail, Sable! Just wandering this board. What brings you? target=#4", "ms": 1472},
	{"prompt": "286a3d165f73ecb0", "reply": "go_to offset=(6, 0)", "ms": 1596},
	{"prompt": "d7409790f725dbc6", "reply": "say text=Does anyone have a brass lantern to sell? target=#3", "ms": 4745},
	{"prompt": "4f3e26806a4a9fe5", "reply": "say text=Nice sword, Bram. Mind the two strangers closing in behind you? target=#3", "ms": 2740},
	{"prompt": "5ad8d2db54f2c816", "reply": "examine target=#6", "ms": 1914},
	{"prompt": "af15b0009cb1c3f9", "reply": "say text=Just wandering, friend. Exploring this board. Who are the others with you? target=#4", "ms": 5222},
	{"prompt": "58a2b5021b2be074", "reply": "wait ticks=1", "ms": 3946},
	{"prompt": "6180cfee65a6af9b", "reply": "say text=Bram, do you know where I could buy a brass lantern? target=#3", "ms": 1670},
	{"prompt": "092a13b9605f6c13", "reply": "say text=\"I do not know, Pell. Perhaps ask Wren, or we might search the pile east of here.\" target=#7", "ms": 1890},
	{"prompt": "8b332bc78d011ac2", "reply": "go_to offset=(-30.0, 6.0)", "ms": 1910},
	{"prompt": "1cd6186ac6c8d3bb", "reply": "say text=I have no brass lantern, sorry Pell. target=#7", "ms": 1344},
	{"prompt": "30c2512a553ffcb2", "reply": "go_to offset=(3, 0)", "ms": 2976},
	{"prompt": "7ac54bf6d426968d", "reply": "say text=\"Wren, do you know where I could buy a brass lantern?\" target=#1", "ms": 1512},
	{"prompt": "5dac24c58baa75fa", "reply": "say text=\"The pile seems gone now, Pell. We may need to look elsewhere.\" target=#7", "ms": 2213},
	{"prompt": "a4362b3425ede58e", "reply": "say text=Welcome, strangers. Can I help either of you? target=#1", "ms": 2812},
	{"prompt": "0a73bc04db2af0df", "reply": "go_to          target=#1", "ms": 1608},
	{"prompt": "f0787d59afb4fb80", "reply": "say text=\"Pell, two armed strangers are nearby — one with a sword, one with a spear. Stay close to Wren and me.\" target=#7", "ms": 3001},
	{"prompt": "c4cf0a84697bcd1b", "reply": "say text=I could lend you a few coins if that helps, Pell. target=#7", "ms": 3531},
	{"prompt": "2a999650b577d326", "reply": "go_to offset=(-0.5, -1.0)", "ms": 1818},
	{"prompt": "8fdc226777afaabc", "reply": "wait ticks=5", "ms": 1579},
	{"prompt": "1571e09d88326a89", "reply": "say text=#3, #4 — who are you, and what brings you here? target=#3", "ms": 3571},
	{"prompt": "e663653834048524", "reply": "say text=Anyone else need anything, or shall we talk trade? target=#2", "ms": 1748},
	{"prompt": "796f2089d16cd138", "reply": "say text=\"We seem to have gathered quite a company here. Are you three travelers as well?\" target=#1", "ms": 1745},
	{"prompt": "5be0d5af42f0fc47", "reply": "recall about=brass lantern", "ms": 2118},
	{"prompt": "3891a781513ec1c2", "reply": "say text=#4, I asked you both a question — who are you, and what do you want here? target=#4", "ms": 1614},
	{"prompt": "1faaeb9d05292f65", "reply": "say text=Hello? Is anyone out there?", "ms": 4874},
	{"prompt": "f47142cafbc5c8b9", "reply": "examine target=#2", "ms": 2096},
	{"prompt": "81f295d23d41211a", "reply": "examine target=#4", "ms": 5127},
	{"prompt": "0b2021180ac83379", "reply": "say text=Rook asked who we are. I'm Bram, a wanderer with a sword and little coin. What do you trade in? target=#2", "ms": 2557},
	{"prompt": "8d90a5a300648824", "reply": "say text=\"Anyone? I'm at a flat spot by a tall ridge, north face. Shout back.\" target=#5", "ms": 1796},
	{"prompt": "d9e0aa718c61deda", "reply": "say text=Wren, do you know where I could buy a brass lantern? I have 9 coins. target=#1", "ms": 1539},
	{"prompt": "3a11d0b9bffe2abf", "reply": "say text=\"Bram, you didn't answer — who are you and Sable? But if it's trade you want, I have a silk cloak I might part with.\" target=#3", "ms": 1843},
	{"prompt": "56405a55dd7784b5", "reply": "say text=\"I'm Sable, a wanderer with a spear, looking for honest trade and safe roads. Nothing more than that.\" target=#2", "ms": 1714},
	{"prompt": "66cd6d45c4573109", "reply": "say text=\"Wren, you mentioned a fair bargain — what do you have to trade?\" target=#1", "ms": 3019},
	{"prompt": "d4c15c88a3b88ab5", "reply": "say text=\"Still nobody? I'll keep walking east and see what I find.\" target=#5", "ms": 1942},
	{"prompt": "3a8f47e14827ca96", "reply": "say text=\"And you, Rook? Who are you, and what brings you out here?\" target=#2", "ms": 1629},
	{"prompt": "f37a3c5e86d325f2", "reply": "say text=\"Bram, thank you for offering. Do you know anyone here who sells a brass lantern?\" target=#3", "ms": 2439},
	{"prompt": "5fc465a0ce076445", "reply": "trade_propose target=#4 give=[silk cloak] want_money=6", "ms": 3019},
	{"prompt": "d4c15c88a3b88ab5", "reply": "say text=I'm here, alone it seems. I'll keep moving. target=#5", "ms": 2213},
	{"prompt": "edee261da65bc49c", "reply": "say text=\"A fair bargain indeed, Wren. Four wanderers on one road — perhaps our luck lies in each other. What's your story, friend?\" target=#7", "ms": 2273},
	{"prompt": "627710b988e1fea5", "reply": "say text=\"Pell, I don't know of a seller yet, but I'll ask around — anyone here have a brass lantern?\" target=#7", "ms": 1865},
	{"prompt": "d4c15c88a3b88ab5", "reply": "say text=\"Hello? Anyone at all?\" target=#5", "ms": 1857},
	{"prompt": "be2499bb99d3df5a", "reply": "say text=Strangers, if either of you sells a brass lantern, I have 9 coins. target=#4", "ms": 1623},
	{"prompt": "dc2f329b9f9b0e80", "reply": "say text=\"I'm Rook, a trader by road and cloth. I have this silk cloak, worth 8 coins — either of you want it?\" target=#4", "ms": 1663},
	{"prompt": "7c5ad51bc73c8e3b", "reply": "say text=#4 Sable, wanderer and trader — Bram, Wren, Rook: what say we share the road together? target=#2", "ms": 1833},
	{"prompt": "d4c15c88a3b88ab5", "reply": "say text=Any voice at all would be a comfort in this empty place.", "ms": 2091},
	{"prompt": "f5d49793a4f70349", "reply": "trade_propose  target=#2 give=[common spear] want=[silk cloak]", "ms": 2449},
	{"prompt": "1cefa727dc4f9531", "reply": "say text=\"Rook, I told you — I'm Bram, a wanderer with a sword. Sable is my companion there with the spear. What price for that silk cloak?\" target=#2", "ms": 2902},
	{"prompt": "8de39ce001e3b502", "reply": "trade_propose  target=#4 give=[silk cloak] want_money=8", "ms": 2197},
	{"prompt": "f5048e90985abb6c", "reply": "say text=\"Still no one. I'll keep walking and shouting until the world answers.\" target=#5", "ms": 1611},
	{"prompt": "d697745b3ae42ece", "reply": "say text=\"I'm Pell — just passing through, hoping to buy a brass lantern. Anyone?\" target=#4", "ms": 1603},
	{"prompt": "5de2be831a47816f", "reply": "say  text=Rook, I have no coin on me, but I'd trade my common spear or boots for that silk cloak if you're willing. target=#2", "ms": 3125},
	{"prompt": "39fd8364640b978c", "reply": "say text=\"Pell, I'll ask around for a brass lantern too. Rook, ready to trade when you name a price.\" target=#7", "ms": 4175},
	{"prompt": "0dccfd7fcd8cfc0b", "reply": "say text=\"Still nothing but hills and silence. I'll walk east and see what the land holds.\" target=#5", "ms": 2317},
]

## The goal comparison's four questions, recorded in the same pass.
const GOAL_ROWS := [
	{"prompt": "0dc1ae39032a2ea3", "reply": "say text=then let us trade, Wren target=#1", "ms": 4047},
	{"prompt": "62de394ca0d260db", "reply": "go_to target=(-471, 416)", "ms": 2596},
	{"prompt": "af12840da270f4d6", "reply": "trade_propose  target=#2 give=[] give_money=9 want=[] want_money=0", "ms": 1540},
	{"prompt": "5f9e515879fa36e7", "reply": "trade_propose target=#1 give_money=5", "ms": 3169},
]

## The lesson comparison's four questions, recorded in the same pass.
const LESSON_ROWS := [
	{"prompt": "0dc1ae39032a2ea3", "reply": "say text=a fair bargain indeed, friends target=#1", "ms": 1608},
	{"prompt": "fd74d854c733dc85", "reply": "say text=\"what bargain do you offer?\" target=#1", "ms": 2662},
	{"prompt": "8494a69675622153", "reply": "go_to  target=#2", "ms": 2411},
	{"prompt": "e799b607a3727686", "reply": "recall about=trade", "ms": 1359},
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

## The goodwill run's questions, on their own date above.
const GOODWILL_ROWS := [
	{"prompt": "15fa8511e7354e85", "reply": "goodwill=0.6", "ms": 2623},
	{"prompt": "e77172f1a6958897", "reply": "goodwill=0.7", "ms": 3472},
	{"prompt": "ea866cef976b2852", "reply": "goodwill=0.5", "ms": 4773},
	{"prompt": "ad2b503ddf4740f3", "reply": "goodwill=0.6", "ms": 2332},
]

## The bargain run's questions, on their own date above.
const BARGAIN_ROWS := [
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


## The goodwill run's own exchange, in the same shape, and with its own date
## on it.
static func goodwill_exchange() -> Dictionary:
	return {"rows": GOODWILL_ROWS, "from": goodwill_provenance(), "model": MODEL}


## The bargain run's own exchange, in the same shape, and with its own date
## on it.
static func bargain_exchange() -> Dictionary:
	return {"rows": BARGAIN_ROWS, "from": bargain_provenance(), "model": MODEL}


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


## Where the goodwill replies came from.
static func goodwill_provenance() -> String:
	return "recorded %s from %s at %s, %d replies" % [
		GOODWILL_RECORDED_ON, said_by(), ENDPOINT, GOODWILL_ROWS.size(),
	]


## Where the bargain replies came from.
static func bargain_provenance() -> String:
	return "recorded %s from %s at %s, %d replies" % [
		BARGAIN_RECORDED_ON, said_by(), ENDPOINT, BARGAIN_ROWS.size(),
	]


## How many replies the recording holds.
static func size() -> int:
	return ROWS.size() + LESSON_ROWS.size() + GOAL_ROWS.size() \
		+ CHECK_ROWS.size() + WORLD_ROWS.size() + GOODWILL_ROWS.size() \
		+ BARGAIN_ROWS.size()


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
