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
const RECORDED_ON := "2026-09-04"

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
const CHECKS_RECORDED_ON := "2026-09-04"

## When the orchestrator table was recorded, which is its own date for the same
## reason the difficulty-class one is: `./run_record.sh --live --world` puts only
## its questions and writes the other four back unchanged.
const WORLD_RECORDED_ON := "2026-09-04"

## The exchange. Rewritten by the recorder; see the note above.
const ROWS := [
	{"prompt": "6a973c08474c3f48", "reply": "go_to target=#6", "ms": 4390},
	{"prompt": "842c2b0aebc8ac81", "reply": "examine target=#4", "ms": 11181},
	{"prompt": "285d77dfa04381d0", "reply": "say text=Hail, fellow commander. target=#3", "ms": 2096},
	{"prompt": "4d7bfe4a3f17ec1d", "reply": "examine target=#5", "ms": 1546},
	{"prompt": "ec1ca1523c67a93e", "reply": "go_to target=#2", "ms": 8750},
	{"prompt": "7c4d7261b61f586f", "reply": "go_to target=#6", "ms": 3844},
	{"prompt": "4d7bfe4a3f17ec1d", "reply": "go_to offset=(+2.0, -6.0)", "ms": 6345},
	{"prompt": "d9f9f2bb336d5812", "reply": "say text=Well met. What brings you this way? target=#3", "ms": 749},
	{"prompt": "5b9150bac621bbf5", "reply": "wait          ticks=3", "ms": 7107},
	{"prompt": "35844c1e64d6e6d3", "reply": "wait ticks=1", "ms": 14674},
	{"prompt": "9432e09f9c10e4f6", "reply": "examine target=#6", "ms": 59234},
	{"prompt": "4e55b4b634ed0b23", "reply": "say text=\"good morning to you too\" target=#1", "ms": 4917},
	{"prompt": "35844c1e64d6e6d3", "reply": "wait ticks=1", "ms": 14147},
	{"prompt": "35844c1e64d6e6d3", "reply": "say text=\"The road ahead looks quiet. Care to walk together a while?\" target=#3", "ms": 3493},
	{"prompt": "b72a6d50c40d3331", "reply": "examine target=(12.5, -4.0)", "ms": 7958},
	{"prompt": "dc514a9c1d419b70", "reply": "say text=where can I find a brass lantern target=#2", "ms": 3131},
	{"prompt": "b943c2785662f7e6", "reply": "say text=\"a fine morning for a walk\" target=#7", "ms": 13062},
	{"prompt": "9279176731fed73a", "reply": "say text=Well met, Sable. Just wandering these lands. target=#4", "ms": 529},
	{"prompt": "d7c448cf43ef8949", "reply": "explore\n\ngo_to offset=(+2.0, -6.0)", "ms": 1889},
	{"prompt": "259295905fce17e8", "reply": "say text=\"The road ahead looks quiet. Care to walk together a while?\" target=#3", "ms": 568},
	{"prompt": "9ace3964f4a28a4d", "reply": "wait ticks=1", "ms": 2483},
	{"prompt": "3d917f5534c8fd41", "reply": "recall about=brass lantern", "ms": 900},
	{"prompt": "113644b471931f93", "reply": "say text=\"I don't know where to find a brass lantern, sorry\" target=#7", "ms": 2137},
	{"prompt": "c25ce4c5136f7e63", "reply": "say text=\"A walk sounds fine. Lead the way.\" target=#4", "ms": 476},
	{"prompt": "ce0a3f5ba615dc9a", "reply": "say text=where can I find a brass lantern, Rook target=#2", "ms": 1928},
	{"prompt": "184e8c1850a5959f", "reply": "say text=\"Quiet lands make for easy travel. Shall we wander north together, then?\" target=#3", "ms": 3061},
	{"prompt": "c12a346cc298f434", "reply": "examine target=#6", "ms": 11221},
	{"prompt": "4cb27c5aa8fc0376", "reply": "go_to target=#4", "ms": 27905},
	{"prompt": "cb1d68c94ca9b7e3", "reply": "say text=where can I find a brass lantern, Wren target=#1", "ms": 2286},
	{"prompt": "53762d722e81efe1", "reply": "say text=\"North it is, then. Keep pace with me.\" target=#3", "ms": 3067},
	{"prompt": "e0928ade7b555915", "reply": "say target=#7 text=\"I already told you, Pell — I don't know where to find one\"", "ms": 5631},
	{"prompt": "6020db1014ad4311", "reply": "wait ticks=1", "ms": 3569},
	{"prompt": "8fa2250116d430b1", "reply": "learn text=Keep heading north across the rising slope.", "ms": 1739},
	{"prompt": "da39fb87142a8cd4", "reply": "recall about=brass lantern", "ms": 1234},
	{"prompt": "62b5a67b3cf27248", "reply": "go_to offset=(0.0, -6.0)", "ms": 4634},
	{"prompt": "ea741187652c2923", "reply": "say text=\"Pell, asking again won't change my answer — try the pile I saw nearby, maybe\" target=#7", "ms": 6360},
	{"prompt": "5b28530fbfe18b90", "reply": "go_to offset=(+0.0, -6.0)", "ms": 1648},
	{"prompt": "9b7fbc8d578b511e", "reply": "say text=I'll keep looking. Maybe someone in the market knows, Rook. target=#2", "ms": 2660},
	{"prompt": "284578098444f942", "reply": "say text=\"Pell, I've answered you three times now — leave me be\" target=#7", "ms": 2153},
	{"prompt": "6de6ede7f431b6a9", "reply": "say text=\"Wren, do you know where I could find a brass lantern? Rook mentioned a nearby pile.\" target=#1", "ms": 4846},
	{"prompt": "c9b9dd49d6fbf0cd", "reply": "say text=Pell, I've answered you three times now — leave me be target=#7", "ms": 1437},
	{"prompt": "935c0fb8bf884df0", "reply": "trade_propose target=#1 give_money=5 want=[brass lantern]", "ms": 24735},
	{"prompt": "2f4ebbe9140e7f30", "reply": "go_to offset=(+2.0, -6.0)", "ms": 9653},
	{"prompt": "7061cd14351797ef", "reply": "examine target=#7", "ms": 2742},
	{"prompt": "11889b6f24e6cc1d", "reply": "recall about=brass lantern pile", "ms": 691},
	{"prompt": "266e55123b362736", "reply": "say text=Enough, Pell — go ask Wren if you like target=#7", "ms": 5674},
	{"prompt": "42abc9731a4ea055", "reply": "pick_up        item=brass lantern target=#6", "ms": 4443},
	{"prompt": "7270b1ed70ea7cbe", "reply": "go_to offset=(+2.0, -6.0)", "ms": 1749},
	{"prompt": "17daa2c3e1c3f040", "reply": "say text=I already pointed you at the pile I saw nearby — and leave me be after this, Pell target=#7", "ms": 1870},
	{"prompt": "75fda6e03b38fd5c", "reply": "trade_propose target=#1 want=[brass lantern] give_money=9", "ms": 3318},
	{"prompt": "51428799c645ad1a", "reply": "say text=\"And I meant it, Pell — the market's your best bet. Good luck.\" target=#7", "ms": 6676},
	{"prompt": "0d020883847dfd30", "reply": "go_to offset=(+0.0, -6.0)", "ms": 2564},
	{"prompt": "9e3aafacb474519b", "reply": "go_to offset=(+3.0, +0.0)", "ms": 10458},
	{"prompt": "0148b10bc26bf56d", "reply": "say text=Wren, do you know where I could find a brass lantern? Rook mentioned a nearby pile. target=#1", "ms": 4448},
	{"prompt": "df582589e8c5d4fa", "reply": "say text=That's the last you'll hear from me, Pell — good luck at the market. target=#7", "ms": 6463},
	{"prompt": "76a6b4abfd107500", "reply": "go_to offset=(+0.0, -3.0)", "ms": 6344},
	{"prompt": "dc9355fe1632c67f", "reply": "recall about=brass lantern pile", "ms": 1939},
	{"prompt": "a19b239f0d548d49", "reply": "go_to offset=(+2.0, -6.0)", "ms": 1524},
	{"prompt": "9edd3bb19e6f7929", "reply": "wait ticks=2", "ms": 6262},
	{"prompt": "cfacfae9021d021e", "reply": "recall about=brass lantern", "ms": 39752},
	{"prompt": "6b9f805d462e692f", "reply": "go_to offset=(+2.0, -6.0)", "ms": 1286},
	{"prompt": "ffcd2bef57fccaf8", "reply": "recall         about=market", "ms": 11657},
	{"prompt": "9e3aafacb474519b", "reply": "say text=Lead on, Sable. I'll keep pace. target=#4", "ms": 10992},
	{"prompt": "d8e0655b91f4efab", "reply": "say text=Thank you, Rook. I'll head to the market then. target=#2", "ms": 4028},
	{"prompt": "cd1ac03935b28b77", "reply": "say text=hail, travelers target=#7", "ms": 1908},
	{"prompt": "3b5946e9223036db", "reply": "go_to offset=(+3.0, +0.5)", "ms": 8480},
	{"prompt": "27c3f61ff23ebbcf", "reply": "recall about=brass lantern", "ms": 2353},
	{"prompt": "a60ba354105875b7", "reply": "say text=I'll be off to the market now, farewell. target=#1", "ms": 2780},
	{"prompt": "010525267cc39cdb", "reply": "go_to offset=(+2.0, -6.0)", "ms": 1791},
	{"prompt": "1a7c5d48b74ad5e8", "reply": "recall about=brass lantern", "ms": 1557},
	{"prompt": "1a7d1ed244d19d1f", "reply": "examine target=#5", "ms": 3735},
	{"prompt": "bdf522a371866ccb", "reply": "go_to  offset=(0.0, -6.0)", "ms": 2049},
	{"prompt": "c0e1ce330db6f005", "reply": "say text=Take care, Pell. target=#7", "ms": 2484},
	{"prompt": "eec6da5c511116d9", "reply": "go_to offset=(+0.3, -3.0)", "ms": 1707},
	{"prompt": "d6ee92698859770c", "reply": "go_to offset=(+2.0, -6.0)", "ms": 1890},
	{"prompt": "e9257919647a053d", "reply": "say text=\"You too, Wren — nothing to worry over.\" target=#1", "ms": 3836},
	{"prompt": "ada2e00a7e798a16", "reply": "go_to offset=(+2.0, -6.0)", "ms": 6318},
]

## The goal comparison's four questions, recorded in the same pass.
const GOAL_ROWS := [
	{"prompt": "6ee3266ffbedbb7f", "reply": "say text=then let us trade target=#1", "ms": 3139},
	{"prompt": "e268a7eacbb71f52", "reply": "go_to target=(-471.0, 416.0)", "ms": 2756},
	{"prompt": "8e549582ef6d5ff5", "reply": "trade_propose target=#2 give_money=1 want_money=0", "ms": 4203},
	{"prompt": "1636920c36bb19a2", "reply": "say text=I will deal fairly with you both target=#1", "ms": 2094},
]

## The lesson comparison's four questions, recorded in the same pass.
const LESSON_ROWS := [
	{"prompt": "6ee3266ffbedbb7f", "reply": "say text=\"a fair bargain indeed, Wren\" target=#1", "ms": 2574},
	{"prompt": "3d09a30f4e620bf8", "reply": "say text=what do you offer, Wren? target=#1", "ms": 16508},
	{"prompt": "6da73e452abf0402", "reply": "recall about=trade with Rook", "ms": 5476},
	{"prompt": "cf5d44db015b0995", "reply": "say text=a fair bargain, then. target=#1", "ms": 7601},
]

## The difficulty-class run's questions, on their own date above.
const CHECK_ROWS := [
	{"prompt": "b723d1dc859f2ded", "reply": "dc=12 ability=str", "ms": 2250},
	{"prompt": "b4dc9bc7079ce35a", "reply": "open target=#2", "ms": 5890},
	{"prompt": "424074711a1ba4fe", "reply": "dc=12 ability=dex", "ms": 3392},
]

## The orchestrator run's questions, on their own date above.
const WORLD_ROWS := [
	{"prompt": "22f1292b9d684f27", "reply": "open target=#3\nspill target=#2\nspawn role=scout at=(-470.0, 418.0)", "ms": 6518},
	{"prompt": "346ecaac8f2ac8a8", "reply": "name=Swiftbrook\ntraits=quick-fingered, observant, soft-spoken\ntendencies=tests every path twice, notices what others miss, avoids brute force\nbackstory=A scout with quick hands and sharp eyes but little strength, Swiftbrook learned early to survive by watching and staying light rather than standing and fighting.", "ms": 3965},
	{"prompt": "9322c3c96440021f", "reply": "spawn role=herald at=(-466.0, 424.0)\nspawn role=guard at=(-480.0, 412.0)\nnothing", "ms": 3020},
	{"prompt": "81121fb07d1d8671", "reply": "name=Vessaline\ntraits=silver-tongued, magnetic, careless of counsel\ntendencies=charms first, asks never, forgets warnings\nbackstory=Born in the ninth ring's edge-lands, Vessaline learned early that a beautiful voice opens doors that strength and sense cannot, and has talked their way into a herald's office while leaving a trail of ignored advice behind them.", "ms": 7189},
	{"prompt": "3e2d2ab066156f34", "reply": "name=Grum Vask\ntraits=brutishly strong, tireless, stone-faced\ntendencies=settles arguments by looming rather than talking, keeps his five belongings in exact order, misreads kindness as mockery\nbackstory=Ten years of gate duty carved Grum into a slab of muscle with a dull wit and no grace to spare, and the same lonely stretches on watch left him unable to hold a civil conversation. Travelers remember him as the guard they were glad to have behind them rather than in front of them.", "ms": 35053},
	{"prompt": "64008373031daed2", "reply": "spawn role=guard at=(-488.0, 416.0)", "ms": 2488},
	{"prompt": "b9ee3dc30d6509de", "reply": "name=Brakk Stonegrip\ntraits=musclebound, blunt, gruff\ntendencies=solves problems by force, distrusts clever talk, stands his ground\nbackstory=Born at the edge of the ten rings, Brakk earned his guard post on raw strength alone, though his rough manner and slow wits have cost him every promotion but this one.", "ms": 10161},
	{"prompt": "4383cfbd6b2dd8f7", "reply": "spawn role=scholar at=(-484.0, 410.0)\nplace kind=chest at=(-490.0, 420.0)\nmove target=#4 to=(-478.0, 416.0)", "ms": 2607},
	{"prompt": "3d229a466eda60fd", "reply": "name=Sage Verrin\ntraits=Perceptive, Contemplative, Clumsy\ntendencies=Studies old texts for hours, Asks quiet probing questions, Fumbles with tools and small objects\nbackstory=At level ten with wisdom as their loudest gift, Verrin has spent years at the rings of the world learning to read people and omens, though a weak hand at coordination has always made fieldwork and craft embarrassing.", "ms": 15802},
	{"prompt": "3cd4c95d23e541f5", "reply": "spawn role=scout at=(-478.0, 414.0)\nplace kind=chest at=(-476.0, 416.0)\nnothing", "ms": 2190},
	{"prompt": "e8380b759c127e1c", "reply": "name=Serra Quickfoot\ntraits=quick-fingered, silver-tongued, thin-skinned\ntendencies=scouts wide arcs, talks her way past trouble, bruises and keeps moving\nbackstory=Raised on the ninth ring's fringe roads, she learned to slip ahead of caravans and charm her way back with news, though every scrape she takes lingers longer than she admits.", "ms": 5382},
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
