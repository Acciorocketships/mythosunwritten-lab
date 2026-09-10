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
const RECORDED_ON := "2026-09-10"

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
	{"prompt": "a0db2c61ed7b1b00", "reply": "say text=Hello, Pell and Wren. What's in that pile? target=#7", "ms": 974},
	{"prompt": "230f9d3b6f839d2f", "reply": "examine target=#6", "ms": 386},
	{"prompt": "f05308a31847576e", "reply": "go_to target=#3", "ms": 448},
	{"prompt": "2f01ad292a802d5b", "reply": "go_to offset=(6, 0)", "ms": 873},
	{"prompt": "30e8343d72d0db14", "reply": "go_to target=#2", "ms": 469},
	{"prompt": "d110ae6a5a8432fa", "reply": "say text=Hail, traveler! What brings you here? target=#4", "ms": 935},
	{"prompt": "36e244dab4fe927f", "reply": "go_to target=#2", "ms": 1129},
	{"prompt": "63c645b95ad1e47b", "reply": "examine target=#6", "ms": 379},
	{"prompt": "3c30032079df75c7", "reply": "go_to offset=(3, 0)", "ms": 539},
	{"prompt": "6b0c632ca228b5df", "reply": "say text=Let's look. I'll check the pile. target=#2", "ms": 549},
	{"prompt": "23d9223f94432ace", "reply": "say text=Hail, traveler! I am Sable. target=#3", "ms": 681},
	{"prompt": "d9d0f202ed010dcf", "reply": "go_to offset=(3, 0)", "ms": 857},
	{"prompt": "42ee9cdbe069b539", "reply": "examine target=#6", "ms": 1065},
	{"prompt": "dd2181dad1ead784", "reply": "wait ticks=5", "ms": 440},
	{"prompt": "cb53906979d3cb34", "reply": "examine target=#6", "ms": 1501},
	{"prompt": "fdc652344e27559b", "reply": "go_to offset=(3, 0)", "ms": 15095},
	{"prompt": "35b76fc395381339", "reply": "say text=\"Let me know what you find in it.\" target=#7", "ms": 20749},
	{"prompt": "832eb5ddf68f184a", "reply": "say text=\"I wander these lands seeking purpose, friend. What of you?\" target=#3", "ms": 811},
	{"prompt": "7b7f351e1847e117", "reply": "go_to target=#6", "ms": 1103},
	{"prompt": "2ad009ecd8558fe7", "reply": "go_to offset=(3, 0)", "ms": 2030},
	{"prompt": "c603fecf0edd562a", "reply": "say text=Well met, Sable. I am Bram. Might you have goods to trade, or news of the road? target=#4", "ms": 4413},
	{"prompt": "85009244cf7ada22", "reply": "trade_accept target=#1", "ms": 3376},
	{"prompt": "acef3367a0b32c1f", "reply": "say text=\"I seek a purpose worth a spear, Bram. Might you know of work or trouble nearby?\" target=#3", "ms": 869},
	{"prompt": "64f3ddba8fd83701", "reply": "go_to offset=(6, 0)", "ms": 529},
	{"prompt": "292a288d64bc90f2", "reply": "say text=\"Good morning, Wren. Pell's checking that pile over there.\" target=#1", "ms": 7041},
	{"prompt": "6b26cb05b9ef2c91", "reply": "trade_propose target=#4 give=[common sword] want=[common spear]", "ms": 15229},
	{"prompt": "7965230db345226e", "reply": "go_to offset=(6, 0)", "ms": 1084},
	{"prompt": "d8d9ea64a14f5f23", "reply": "wait ticks=5", "ms": 13047},
	{"prompt": "c3fe9288ec030c84", "reply": "say text=\"I carry little but my spear and boots, friend. If you've work or coin, I'm your blade.\" target=#3", "ms": 792},
	{"prompt": "8d7a7a84f7f45ad0", "reply": "say text=\"I've seen no trouble yet, but there's a pile of goods some 40 paces east of here, unclaimed. Care to walk with me and see what fortune holds?\" target=#4", "ms": 7980},
	{"prompt": "08a8905a18c44c76", "reply": "go_to target=#6", "ms": 1754},
	{"prompt": "9919beea5b275f75", "reply": "wait ticks=5", "ms": 18553},
	{"prompt": "95aea66d8dbe98d6", "reply": "go_to offset=(3, 0)", "ms": 18848},
	{"prompt": "6bb98fb0ff62b35d", "reply": "say text=\"No goods worth coin, Bram - only this spear and these boots. Point me at work or trouble, and any news I gather on the road is yours to hear.\" target=#3", "ms": 15646},
	{"prompt": "6e54c3c4e7667de4", "reply": "go_to offset=(6, 0)", "ms": 952},
	{"prompt": "7ed7671c67da149f", "reply": "say text=Did you find anything in the pile? target=#7", "ms": 25602},
	{"prompt": "c4ddadd9877647c6", "reply": "go_to offset=(40, 0)", "ms": 15991},
	{"prompt": "89e1c162c0ea7a98", "reply": "say text=\"Lead on, Bram - I'll walk east with you and we'll split whatever that pile holds.\" target=#3", "ms": 1022},
	{"prompt": "f9cecbfbba5af5e5", "reply": "say text=\"What bargain is that, Wren?\" target=#1", "ms": 24641},
	{"prompt": "3861516e1005462c", "reply": "go_to offset=(6, 0)", "ms": 864},
	{"prompt": "460e16f2c570e69b", "reply": "say text=\"Not sure what the noise was — maybe Pell rustling through that pile. Now, what bargain did you mean?\" target=#1", "ms": 45876},
	{"prompt": "e9c3162933b646ca", "reply": "go_to offset=(6.0, 0.0)", "ms": 1076},
	{"prompt": "7134b531b225cca0", "reply": "go_to offset=(3, 0)", "ms": 31401},
	{"prompt": "3e06c7ffa7cb4c6f", "reply": "wait ticks=3", "ms": 6691},
	{"prompt": "5761f263c2ff04d3", "reply": "go_to offset=(3, 0)", "ms": 20223},
	{"prompt": "17c4a5f4a2e2f612", "reply": "go_to  offset=(10.0, 0.0)", "ms": 824},
	{"prompt": "34b9f74e7f5a2183", "reply": "say text=\"I don't see any pile from here — where is it?\" target=#2", "ms": 1869},
	{"prompt": "53e881cc2ad39b2c", "reply": "say text=\"Ah — I take it the bargain was our trade, Wren. Fair indeed; enjoy the cloak.\" target=#1", "ms": 43706},
	{"prompt": "ffd16ee8dab39856", "reply": "go_to offset=(3, 0)", "ms": 21625},
	{"prompt": "62dc5dba2ffdfa16", "reply": "go_to offset=(3, 0)", "ms": 9735},
	{"prompt": "b656106b971be482", "reply": "say text=\"I don't see any pile nearby — maybe it's beyond the drop to the south. I'll head that way.\" target=#2", "ms": 1026},
	{"prompt": "7d2fc77cebb04976", "reply": "say text=\"Southwest of us, past the drop by the hole — though it looks picked clean now; I see nothing left of it.\" target=#7", "ms": 12942},
	{"prompt": "70e1f5a14d034978", "reply": "go_to offset=(12, 0)", "ms": 28740},
	{"prompt": "4bb288b260cff817", "reply": "go_to  offset=(6.0, 0.0)", "ms": 704},
	{"prompt": "7e47bd8ae0bc0ed3", "reply": "go_to  offset=(0, -6)", "ms": 784},
	{"prompt": "26996bec12f23faf", "reply": "go_to target=#7", "ms": 11759},
	{"prompt": "5dacdead0764c9eb", "reply": "go_to offset=(40, 0)", "ms": 9769},
	{"prompt": "494bc9629051829b", "reply": "say text=\"Careful, Pell — there's a hole just past the drop; don't fall in.\" target=#7", "ms": 40846},
	{"prompt": "4bb288b260cff817", "reply": "go_to offset=(6.0, 0.0)", "ms": 572},
	{"prompt": "167705c2d023765c", "reply": "say text=\"Rook, the pile sounds picked clean — I'll head southwest past the drop and look for a brass lantern while I'm out.\" target=#2", "ms": 1733},
	{"prompt": "5096ec4c5b64375a", "reply": "go_to offset=(-6, 0)", "ms": 27092},
	{"prompt": "e3a4a14a0ad7deb0", "reply": "go_to target=#7", "ms": 42702},
	{"prompt": "b22731025478ae01", "reply": "go_to offset=(-6, -6)", "ms": 8350},
	{"prompt": "4931e3900313afe6", "reply": "", "ms": 0},
	{"prompt": "4bb288b260cff817", "reply": "go_to  offset=(6.0, 0.0)", "ms": 730},
	{"prompt": "246b34d234ca6bbc", "reply": "go_to offset=(-6, 0)", "ms": 25510},
	{"prompt": "300f23d7af5685d6", "reply": "recall about=the brass lantern", "ms": 20882},
	{"prompt": "bc0f51af0fb18475", "reply": "go_to offset=(12, 0)", "ms": 21285},
	{"prompt": "e23536e571f7f886", "reply": "go_to offset=(-3, -3)", "ms": 33775},
	{"prompt": "74e37789ca46bdd5", "reply": "go_to offset=(-3, 0)", "ms": 7492},
	{"prompt": "1986bd54a22940a8", "reply": "go_to offset=(-6, -6)", "ms": 11690},
	{"prompt": "4bb288b260cff817", "reply": "go_to  offset=(6.0, 0.0)", "ms": 1210},
	{"prompt": "48598df3761724f7", "reply": "wait ticks=5", "ms": 39906},
	{"prompt": "b23e4b896e1710e8", "reply": "go_to offset=(9, 0)", "ms": 32943},
	{"prompt": "e1c1cb3eef3f2ed3", "reply": "go_to offset=(-15, -15)", "ms": 1140},
	{"prompt": "7a0c98fbf15323ee", "reply": "go_to offset=(-6, -9)", "ms": 43059},
	{"prompt": "f680cf44596e70f5", "reply": "go_to offset=(6.0, 0.0)", "ms": 878},
	{"prompt": "124a0008d78f2238", "reply": "go_to offset=(35, 0)", "ms": 7636},
	{"prompt": "960dfa4c11d560df", "reply": "go_to offset=(9, 0)", "ms": 10632},
	{"prompt": "4bb288b260cff817", "reply": "go_to offset=(6.0, 0.0)", "ms": 4808},
	{"prompt": "c055093d375df0d8", "reply": "go_to target=#7", "ms": 11880},
	{"prompt": "e12c51905bda77ba", "reply": "go_to offset=(-3, 0)", "ms": 11109},
	{"prompt": "ada02c35b9bf2b39", "reply": "go_to offset=(-10, -10)", "ms": 856},
]

## The goal comparison's four questions, recorded in the same pass.
const GOAL_ROWS := [
	{"prompt": "a5528da06c469f37", "reply": "say text=I heard nothing but the wind, friend. target=#1", "ms": 461},
	{"prompt": "573f9a15bf4480ef", "reply": "go_to target=(-471, 416)", "ms": 529},
	{"prompt": "325d31f025efa9de", "reply": "trade_propose  target=#2 give_money=4 want_money=0", "ms": 1053},
	{"prompt": "50a6df83b13a16e0", "reply": "say text=I heard no noise, friend — all is calm here target=#1", "ms": 539},
]

## The lesson comparison's four questions, recorded in the same pass.
const LESSON_ROWS := [
	{"prompt": "a5528da06c469f37", "reply": "say text=\"what bargain did you strike, Wren?\" target=#1", "ms": 1850},
	{"prompt": "c0a32bd85c901856", "reply": "recall about=pile #6", "ms": 610},
	{"prompt": "5659498e506febca", "reply": "say text=that bargain was meant for Rook, not me target=#1", "ms": 888},
	{"prompt": "2d8008533561cbec", "reply": "say text=just the wind, I think target=#1", "ms": 1068},
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
	{"prompt": "eaaf6bbafcc7590d", "reply": "examine target=#4", "ms": 1796},
	{"prompt": "620432247c45822d", "reply": "examine target=#4", "ms": 2240},
	{"prompt": "aa9c4a276fd21227", "reply": "examine target=#4", "ms": 1613},
	{"prompt": "5c84b7ef7fd004d2", "reply": "examine target=#4", "ms": 2559},
	{"prompt": "5c84b7ef7fd004d2", "reply": "examine target=#4", "ms": 3050},
	{"prompt": "21434a778a90ce94", "reply": "say text=Fen, do you have any coins to spare? I need 10. target=#1", "ms": 2203},
	{"prompt": "94c235ab8a859041", "reply": "say text=I have this brass lantern, six coins' worth — would you trade? target=#1", "ms": 2016},
	{"prompt": "ce4a6ac18a9a8183", "reply": "trade_propose target=#1 give=[brass lantern] give_money=0 want_money=6", "ms": 1638},
	{"prompt": "e018bf6f48710bb0", "reply": "trade_accept target=#1", "ms": 3004},
	{"prompt": "9425e4d4c5a8103a", "reply": "say text=\"Six coins for the lantern, Fen. Deal?\" target=#1", "ms": 1903},
	{"prompt": "477ce578b2ffe43c", "reply": "trade_accept target=#1", "ms": 2410},
	{"prompt": "bc8ec83309523b3a", "reply": "wait\tticks=3", "ms": 2455},
	{"prompt": "b4bded201f59ffa0", "reply": "say text=Six coins for the lantern, Fen. Deal? target=#1", "ms": 2233},
	{"prompt": "94ad7a59b6f62280", "reply": "trade_accept target=#1", "ms": 1634},
	{"prompt": "6292b0442328ed09", "reply": "say text=\"The lantern for six coins, Fen. That's my offer.\" target=#1", "ms": 1797},
	{"prompt": "c646d5e23034a1a6", "reply": "say text=\"Yes, Fen — six coins for the lantern, that's the trade. Do we have a deal?\" target=#1", "ms": 1606},
	{"prompt": "80f66637fc65db3f", "reply": "done goal=1", "ms": 2063},
	{"prompt": "f143796dbda6ddf0", "reply": "wait ticks=1", "ms": 2627},
	{"prompt": "3bfdda5a1ec9868c", "reply": "wait ticks=1", "ms": 3496},
	{"prompt": "3bfdda5a1ec9868c", "reply": "done goal=1", "ms": 2294},
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
