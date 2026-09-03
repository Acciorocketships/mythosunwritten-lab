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
const MODEL := "anthropic/claude-fable-5"
const ENDPOINT := "https://openrouter.ai/api/v1/chat/completions"
const RECORDED_ON := "2026-09-02"

## When the difficulty-class table was recorded, which is its own date because
## it is the one table that can be recorded on its own -- `./run_record.sh
## --live --checks` puts only its questions and writes the other three back
## unchanged. A run that adds a fourth table is not a reason to spend a whole
## pass on the other three and to move every number quoted off their
## transcripts.
const CHECKS_RECORDED_ON := "2026-09-02"

## When the orchestrator table was recorded, which is its own date for the same
## reason the difficulty-class one is: `./run_record.sh --live --world` puts only
## its questions and writes the other four back unchanged.
const WORLD_RECORDED_ON := "2026-09-02"

## The exchange. Rewritten by the recorder; see the note above.
const ROWS := [
	{"prompt": "16dcbdfe447a1187", "reply": "examine target=#6", "ms": 5075},
	{"prompt": "7b9f60a49b2cdb12", "reply": "say text=Hail there, fellow commander! I am Bram. Do you come in peace? target=#4", "ms": 3974},
	{"prompt": "c9a74a2162a37689", "reply": "say text=Hail, commander. I don't believe we've met—I'm Sable. target=#3", "ms": 5144},
	{"prompt": "e10f88c0f21de232", "reply": "go_to target=(-460.0, 472.0)", "ms": 8762},
	{"prompt": "79030d91a5205c61", "reply": "go_to target=#2", "ms": 4308},
	{"prompt": "6c693ceeb32f4875", "reply": "wait ticks=2", "ms": 5066},
	{"prompt": "0229f522e816bd90", "reply": "say target=#3 text=\"Well met, Bram. Yes, I come in peace—I've no quarrel with you. What brings you to these parts?\"", "ms": 4049},
	{"prompt": "8c772b422fa74d12", "reply": "say text=good morning, Wren target=#1", "ms": 2917},
	{"prompt": "5790db16b724a7c2", "reply": "learn text=#4 is a commander named Sable, who greeted me peacefully.", "ms": 5440},
	{"prompt": "ff429f506fb863b1", "reply": "learn text=#3 is Bram, a fellow commander I met peacefully.", "ms": 5514},
	{"prompt": "e8610e206bdfc36c", "reply": "say text=morning, Pell — what brings you my way? target=#7", "ms": 4500},
	{"prompt": "7b7ea26132550cf5", "reply": "say target=#4 text=\"I'm scouting these lands, Sable. I spotted a pile of goods to the west—care to have a look at it together, as friends?\"", "ms": 3928},
	{"prompt": "c5837d4197d2f406", "reply": "wait ticks=5", "ms": 4090},
	{"prompt": "c336d1e5342bba40", "reply": "go_to target=(-460.0, 493.0)", "ms": 5174},
	{"prompt": "60f3d87ba25b6a79", "reply": "go_to target=#2", "ms": 5516},
	{"prompt": "64427f5cb5f1edcc", "reply": "wait ticks=3", "ms": 4832},
	{"prompt": "2f859e8834f9b5c8", "reply": "wait ticks=5", "ms": 5822},
	{"prompt": "92cf1f5fe079371a", "reply": "say target=#3 text=\"A pile of goods, you say? Aye, I'll join you—lead the way west, Bram.\"", "ms": 4088},
	{"prompt": "044fccdbef58d719", "reply": "wait ticks=3", "ms": 5065},
	{"prompt": "732044afe16ce44e", "reply": "wait ticks=2", "ms": 5472},
	{"prompt": "b2fb02a510ea57a5", "reply": "wait ticks=2", "ms": 5414},
	{"prompt": "29e3a193ecc475b3", "reply": "go_to target=#6", "ms": 6050},
	{"prompt": "cc08667f6e8537b0", "reply": "go_to target=#3", "ms": 5161},
	{"prompt": "2815af54616d434d", "reply": "wait ticks=2", "ms": 4938},
	{"prompt": "5cb2b86de2ffc1cb", "reply": "go_to target=(-436.0, 492.7)", "ms": 3606},
	{"prompt": "d14573f0d2bfb183", "reply": "say target=#2 text=Morning, Rook! I'm after a brass lantern — would you happen to have one, or know where I might find one?", "ms": 4321},
	{"prompt": "35815b44b4e79265", "reply": "wait ticks=2", "ms": 4756},
	{"prompt": "d265b7b8a7ac9ce7", "reply": "wait ticks=2", "ms": 4918},
	{"prompt": "59e910e9a2d108c1", "reply": "wait ticks=2", "ms": 5229},
	{"prompt": "1ab1e6cb8da2cf9f", "reply": "say text=No lantern on me, Pell — just this silk cloak. But there's a pile nearby with something in it; let's have a look. target=#7", "ms": 5201},
	{"prompt": "57c2263baacb2c4e", "reply": "wait ticks=3", "ms": 4594},
	{"prompt": "ad5eecac49097490", "reply": "go_to target=#6", "ms": 4506},
	{"prompt": "a2cf08ac4db2a772", "reply": "go_to target=#3", "ms": 6739},
	{"prompt": "b4c0c215596355b5", "reply": "go_to target=#6", "ms": 5195},
	{"prompt": "86af993a61b782c3", "reply": "go_to target=#6", "ms": 5207},
	{"prompt": "6444c38f021a7ae0", "reply": "go_to target=(-412.0, 468.0)", "ms": 3785},
	{"prompt": "6af4d532bfc9e737", "reply": "go_to target=(-466.5, 406.5)", "ms": 5621},
	{"prompt": "bdda27e8eeb537fa", "reply": "go_to target=#3", "ms": 5570},
	{"prompt": "3a7f7a9aa4f71710", "reply": "recall about=pile", "ms": 4565},
	{"prompt": "32ed210f3a5c1537", "reply": "go_to target=#6", "ms": 4342},
	{"prompt": "9b2e2e312fad56b3", "reply": "go_to target=#6", "ms": 3049},
	{"prompt": "c879421560c3ac1d", "reply": "go_to target=(-414.676, 476.754)", "ms": 13429},
	{"prompt": "6af4d532bfc9e737", "reply": "go_to target=(-460.0, 406.5)", "ms": 5749},
	{"prompt": "bdda27e8eeb537fa", "reply": "go_to target=#3", "ms": 5388},
	{"prompt": "35149a2dbe971dfc", "reply": "go_to target=#6", "ms": 4912},
	{"prompt": "f62fa4e6f250fcab", "reply": "", "ms": 1363},
	{"prompt": "f755150b371489fc", "reply": "go_to target=(-424.7, 470.8)", "ms": 5910},
	{"prompt": "d918c120164a6113", "reply": "", "ms": 2452},
	{"prompt": "d918c120164a6113", "reply": "", "ms": 2385},
	{"prompt": "d918c120164a6113", "reply": "", "ms": 2224},
	{"prompt": "d918c120164a6113", "reply": "", "ms": 2203},
	{"prompt": "6af4d532bfc9e737", "reply": "go_to target=(-460.0, 406.5)", "ms": 6269},
	{"prompt": "bdda27e8eeb537fa", "reply": "say text=\"Which way from here, Bram? I don't see the goods yet—point me to them.\" target=#3", "ms": 7029},
	{"prompt": "a9a564ee7ed960ab", "reply": "say text=Lead the way to that pile, Rook — I'll follow you. target=#2", "ms": 5396},
	{"prompt": "cc39d94343419026", "reply": "recall about=pile", "ms": 5671},
	{"prompt": "b4aee5a8d92abb0f", "reply": "go_to target=(-415.700, 461.800)", "ms": 7786},
	{"prompt": "c75841764b4772a8", "reply": "go_to target=#6", "ms": 4304},
	{"prompt": "aee75ce0d457a10b", "reply": "go_to target=#2", "ms": 5493},
	{"prompt": "226b5066a13502de", "reply": "go_to target=#3", "ms": 4355},
	{"prompt": "c7785d725235e79c", "reply": "go_to target=(-430.6, 465.7)", "ms": 6937},
	{"prompt": "fd5bd49ca87d7001", "reply": "recall about=pile", "ms": 5146},
	{"prompt": "022c8b4b7623fe12", "reply": "", "ms": 1318},
	{"prompt": "602a84b6eaea1b86", "reply": "wait ticks=3", "ms": 5876},
	{"prompt": "a562bdda894f8842", "reply": "go_to target=#6", "ms": 4674},
	{"prompt": "01d2a9a7e3d31f9c", "reply": "wait ticks=5", "ms": 6098},
	{"prompt": "62e4895cd01e2379", "reply": "", "ms": 992},
	{"prompt": "f80c7b7a08f96232", "reply": "go_to target=#2", "ms": 4968},
	{"prompt": "8ca3c021c2874cf9", "reply": "", "ms": 2685},
]

## The goal comparison's four questions, recorded in the same pass.
const GOAL_ROWS := [
	{"prompt": "9d1f8d9fedcb8e8d", "reply": "say text=A fair bargain, you say? What are you offering, Wren? target=#1", "ms": 4292},
	{"prompt": "bcf8d2552df681b4", "reply": "go_to target=(-471.0, 416.0)", "ms": 6987},
	{"prompt": "39c75ed90fe09a38", "reply": "trade_propose target=#2 give_money=1", "ms": 3377},
	{"prompt": "1427f3b27253d1aa", "reply": "say text=A fair bargain indeed, Wren — I deal honestly with all in this market. target=#1", "ms": 5596},
]

## The lesson comparison's four questions, recorded in the same pass.
const LESSON_ROWS := [
	{"prompt": "9d1f8d9fedcb8e8d", "reply": "say text=A fair bargain, you say? What are you offering, Wren? target=#1", "ms": 4549},
	{"prompt": "bd97aab0d327b347", "reply": "", "ms": 2100},
	{"prompt": "90f91eda299fba85", "reply": "say text=\"Wren's shouting again, but you're the one who actually deals. Got anything worth a few coins, Rook?\" target=#2", "ms": 6714},
	{"prompt": "f8af88581e3760f4", "reply": "wait ticks=3", "ms": 5360},
]

## The difficulty-class run's questions, on their own date above.
const CHECK_ROWS := [
	{"prompt": "b723d1dc859f2ded", "reply": "dc=12 ability=str", "ms": 5972},
	{"prompt": "b4dc9bc7079ce35a", "reply": "open target=#2", "ms": 4725},
	{"prompt": "424074711a1ba4fe", "reply": "dc=12 ability=dex", "ms": 5427},
]

## The orchestrator run's questions, on their own date above.
const WORLD_ROWS := [
	{"prompt": "22f1292b9d684f27", "reply": "spawn role=scout at=(-470.0, 415.0)", "ms": 5951},
	{"prompt": "1920b2c3e744288c", "reply": "name=Sable Quickstep\ntraits=light-footed, keen-eyed, slight of frame\ntendencies=slips past trouble rather than facing it, notices what others miss, lets stronger hands do the lifting\nbackstory=Nine rings out from the world's heart, Sable earned a scout's name by never being where danger looked, reading the ground with a sharp eye and a wary patience. Whatever they carry stays light, for arms that were never built for burden.", "ms": 5740},
	{"prompt": "ea3cdec2fd38b2bc", "reply": "spawn role=herald at=(-478.0, 425.0)", "ms": 6666},
	{"prompt": "d9a08a749a8ba1ba", "reply": "spawn role=herald at=(-476.0, 428.0)", "ms": 6443},
	{"prompt": "04355f4f1297a956", "reply": "spawn role=herald at=(-486.0, 408.0)\nopen target=#3", "ms": 8922},
	{"prompt": "8d6d76b8a9ab6d29", "reply": "name=Silverbell\ntraits=magnetic voice, tireless traveler, hopelessly credulous\ntendencies=charms crowds and gatekeepers alike, repeats any message given without questioning it, wanders far past sensible bounds\nbackstory=Silverbell has carried proclamations across nine rings of the world, their voice opening doors that swords could not, and their sturdy legs outlasting every road. Yet they have delivered lies as gladly as truths, for they have never once thought to ask what a message means before shouting it.", "ms": 6510},
	{"prompt": "80ea3618c51a9a87", "reply": "spawn role=scholar at=(-478.0, 412.0)", "ms": 7080},
	{"prompt": "9ba7ece4478ecff6", "reply": "name=Maren Quill\ntraits=keen-eyed, patient, frail of arm\ntendencies=weighs words before speaking, reads everything twice, avoids lifting what others carry easily\nbackstory=Ten years of study nine rings from the world's heart made Maren sharp in judgment and learning alike, though the body withered while the mind grew. They keep only five possessions, having long since decided that anything heavier than wisdom is not worth hauling.", "ms": 6630},
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


## Where the orchestrator replies came from.
static func world_provenance() -> String:
	return "recorded %s from %s at %s, %d replies" % [
		WORLD_RECORDED_ON, MODEL, ENDPOINT, WORLD_ROWS.size(),
	]


## Where the difficulty-class replies came from.
static func check_provenance() -> String:
	return "recorded %s from %s at %s, %d replies" % [
		CHECKS_RECORDED_ON, MODEL, ENDPOINT, CHECK_ROWS.size(),
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
		RECORDED_ON, MODEL, ENDPOINT,
		ROWS.size() + LESSON_ROWS.size() + GOAL_ROWS.size(),
	]
