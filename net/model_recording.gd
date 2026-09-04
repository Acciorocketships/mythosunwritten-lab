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
const RECORDED_ON := "2026-09-03"

## When the difficulty-class table was recorded, which is its own date because
## it is the one table that can be recorded on its own -- `./run_record.sh
## --live --checks` puts only its questions and writes the other three back
## unchanged. A run that adds a fourth table is not a reason to spend a whole
## pass on the other three and to move every number quoted off their
## transcripts.
const CHECKS_RECORDED_ON := "2026-09-03"

## When the orchestrator table was recorded, which is its own date for the same
## reason the difficulty-class one is: `./run_record.sh --live --world` puts only
## its questions and writes the other four back unchanged.
const WORLD_RECORDED_ON := "2026-09-03"

## The exchange. Rewritten by the recorder; see the note above.
const ROWS := [
	{"prompt": "16dcbdfe447a1187", "reply": "examine target=#7", "ms": 1530},
	{"prompt": "7b9f60a49b2cdb12", "reply": "examine target=#4", "ms": 1450},
	{"prompt": "c9a74a2162a37689", "reply": "examine target=#3", "ms": 1057},
	{"prompt": "e10f88c0f21de232", "reply": "go_to target=(12.5, -4.0)", "ms": 5214},
	{"prompt": "79030d91a5205c61", "reply": "go_to target=#2", "ms": 895},
	{"prompt": "1630dac32c0b7ddf", "reply": "examine target=#4", "ms": 468},
	{"prompt": "c9a74a2162a37689", "reply": "say text=Hail, traveler. I am Sable. target=#3", "ms": 2098},
	{"prompt": "8c772b422fa74d12", "reply": "say text=\"good morning, Wren\" target=#1", "ms": 9326},
	{"prompt": "3c041dd4efe62db1", "reply": "examine target=#6", "ms": 468},
	{"prompt": "fab24e4daa3de1c2", "reply": "recall about=#3", "ms": 1694},
	{"prompt": "e8d7efc11f7276c0", "reply": "say text=\"good morning, Pell\" target=#7", "ms": 1238},
	{"prompt": "90f1bb05f847e4df", "reply": "say text=Well met, Bram. What brings you to these parts? target=#3", "ms": 1096},
	{"prompt": "de869bf3feff1f27", "reply": "say text=Hail, Sable. I am Bram, a traveler like yourself. target=#4", "ms": 1196},
	{"prompt": "cd110651cd303645", "reply": "go_to target=#7", "ms": 1893},
	{"prompt": "30d2f01f496d565b", "reply": "done goal=1", "ms": 1924},
	{"prompt": "ca5db59ae0f08136", "reply": "say text=\"good morning, Pell\" target=#7", "ms": 813},
	{"prompt": "f0ae7523d7eb234a", "reply": "say text=I am well, Bram. Just patrolling these lands. target=#3", "ms": 5773},
	{"prompt": "f72fd048d4b109f6", "reply": "say text=\"good morning, Rook\" target=#2", "ms": 2340},
	{"prompt": "b429e72553c9e465", "reply": "say text=I'm just passing through, friend. What lies ahead on this road? target=#4", "ms": 650},
	{"prompt": "545a6894f217a93b", "reply": "examine target=#6", "ms": 1680},
	{"prompt": "8c294f0fb21cc3de", "reply": "say text=It is good to meet a fellow traveler, Bram. Safe roads to you. target=#3", "ms": 1748},
	{"prompt": "2d8fbfe6c0e85084", "reply": "examine target=#6", "ms": 1793},
	{"prompt": "1689df6c207ca9b7", "reply": "say text=\"a fine morning for a walk\" target=#1", "ms": 1277},
	{"prompt": "23ede6902d31281c", "reply": "say text=\"I'm not sure yet, friend. Perhaps we could travel together a while?\" target=#4", "ms": 1074},
	{"prompt": "5405fe33e6388e43", "reply": "say text=good morning, Wren target=#1", "ms": 750},
	{"prompt": "cdee3493ae77988c", "reply": "go_to target=#7", "ms": 1705},
	{"prompt": "9cd8c59f0f191e79", "reply": "say text=\"The road ahead leads east toward the river crossing, Bram. Travel safely.\" target=#3", "ms": 6072},
	{"prompt": "0207ce55598d25b9", "reply": "say text=\"a fine morning, Pell\" target=#7", "ms": 2057},
	{"prompt": "b6b4bda54a162f70", "reply": "say text=\"What lies ahead on the road east, Sable? Any dangers I should watch for?\" target=#4", "ms": 2281},
	{"prompt": "e28f361bed640310", "reply": "say text=good morning target=#5", "ms": 1521},
	{"prompt": "733039842c3de30c", "reply": "say text=\"I am headed east myself, Bram. Walk with me a while, if you like.\" target=#3", "ms": 1663},
	{"prompt": "b133e32c07f761e2", "reply": "say text=who is that commander over there, Pell? target=#7", "ms": 1744},
	{"prompt": "d7cd8cf37691d466", "reply": "say text=Any dangers on the road east, Sable? Bandits or beasts? target=#4", "ms": 1753},
	{"prompt": "c5695344e2671fb5", "reply": "recall about=brass lantern", "ms": 1358},
	{"prompt": "80c6f51de5957a01", "reply": "wait ticks=1", "ms": 1750},
	{"prompt": "9c8b130d55ccd439", "reply": "say text=\"Then walk with me east, Bram. Two spears are safer than one on the road.\" target=#3", "ms": 7361},
	{"prompt": "b0c13590e468fd3e", "reply": "say text=\"that must be #5, heading our way; let us see who it is\" target=#2", "ms": 2075},
	{"prompt": "d4474d75940d9deb", "reply": "say text=hello there target=#7", "ms": 780},
	{"prompt": "ab444992e24b7bc0", "reply": "wait ticks=1", "ms": 1348},
	{"prompt": "00bdc634653fe2f2", "reply": "say text=\"I'd be glad to walk with you, Sable. Lead on east, and tell me what dangers we might meet.\" target=#4", "ms": 1956},
	{"prompt": "b930389c10162594", "reply": "say text=Pell, who is that commander over there? target=#7", "ms": 1736},
	{"prompt": "29c5046c4ce6d182", "reply": "say text=that must be #5, heading our way; let us see who it is target=#2", "ms": 1520},
	{"prompt": "139e09362d78d31d", "reply": "say text=\"No dangers I know of on the east road, Bram. Let us be off while the light holds.\" target=#3", "ms": 1924},
	{"prompt": "f25f870563a02def", "reply": "say text=hello, travelers target=#7", "ms": 5965},
	{"prompt": "765131b50342d649", "reply": "wait ticks=1", "ms": 1268},
	{"prompt": "3f4b43018e75b751", "reply": "go_to  target=#4", "ms": 1371},
	{"prompt": "a2dcec98c3c762b6", "reply": "say text=Hello there, travelers. target=#7", "ms": 1500},
	{"prompt": "fdf2674a0c9fdf2c", "reply": "say text=we shall wait and see who it is, then target=#7", "ms": 1514},
	{"prompt": "b9085fe64c2df6be", "reply": "go_to target=(12.5, -4.0)", "ms": 4006},
	{"prompt": "c791183080c4a0ca", "reply": "examine target=#5", "ms": 1449},
	{"prompt": "d8d386e458ee78e5", "reply": "say text=Well met, travelers. Odo here. target=#7", "ms": 1541},
	{"prompt": "2bdd6466e9db514b", "reply": "examine target=#5", "ms": 1287},
	{"prompt": "8efdf78d48d3f29d", "reply": "say text=I already told you, Rook; that must be #5 coming our way. Let us wait and greet them. target=#2", "ms": 2401},
	{"prompt": "a4a7b7750aee85c7", "reply": "wait          ticks=5", "ms": 1592},
	{"prompt": "7b995e8ca9bcfc3a", "reply": "say text=Hail, strangers! I am Odo. target=#7", "ms": 1511},
	{"prompt": "3c40ea75f3e37ee6", "reply": "examine target=#5", "ms": 1863},
	{"prompt": "e08a17301761b54c", "reply": "go_to target=#4", "ms": 1217},
	{"prompt": "e6bbda8013905b07", "reply": "say text=\"easy, friend; we mean no harm\" target=#5", "ms": 1652},
	{"prompt": "ac3510a3855016c8", "reply": "say text=hello there, strangers target=#7", "ms": 1531},
	{"prompt": "02a44ab362a6569a", "reply": "say text=I have a brass lantern to find; Wren, would you trade one? target=#1", "ms": 1903},
	{"prompt": "49754aad45aea4b4", "reply": "wait ticks=5", "ms": 1500},
	{"prompt": "ba8fac1a64906de2", "reply": "examine target=#7", "ms": 1392},
	{"prompt": "1b6c4b1b98994e24", "reply": "say  text=Wren, I have 9 coins and need a brass lantern; name your price.  target=#1", "ms": 1792},
	{"prompt": "b394bd4e61af168c", "reply": "say text=Hail, strangers! target=#7", "ms": 1732},
	{"prompt": "acdc6717e9bd7149", "reply": "wait ticks=5", "ms": 1664},
	{"prompt": "ae247c6403350226", "reply": "trade_propose target=#1 give_money=9 want=[brass lantern]", "ms": 1462},
	{"prompt": "162d93d865287811", "reply": "go_to target=(12.5, -4.0)", "ms": 8571},
	{"prompt": "8926b2146c2caa88", "reply": "say text=\"East then, together. Lead the way, Sable.\" target=#4", "ms": 1794},
	{"prompt": "05e484e4be1bebb4", "reply": "examine target=#7", "ms": 1360},
	{"prompt": "dc252064431989fc", "reply": "trade_propose target=#1 give_money=9 want=[brass lantern]", "ms": 2050},
	{"prompt": "390e1d04dac59186", "reply": "wait  ticks=5", "ms": 1257},
	{"prompt": "05e484e4be1bebb4", "reply": "examine target=#7", "ms": 1367},
	{"prompt": "dc252064431989fc", "reply": "trade_propose target=#1 give_money=9 want=[brass lantern]", "ms": 1481},
	{"prompt": "390e1d04dac59186", "reply": "recall about=#5 the unknown commander approaching", "ms": 1955},
	{"prompt": "157afffd8e8a6bea", "reply": "go_to target=#4", "ms": 1632},
	{"prompt": "54fe96cd647c4195", "reply": "wait ticks=5", "ms": 1338},
	{"prompt": "eb59f9fa8480d22d", "reply": "examine target=#7", "ms": 1309},
	{"prompt": "4c1a4c92bce06d08", "reply": "trade_propose target=#1 give_money=9 want=[brass lantern]", "ms": 1470},
	{"prompt": "e9a8e2a1b1940593", "reply": "wait ticks=1", "ms": 1693},
	{"prompt": "4e36a3e5b9335cb9", "reply": "say text=hello, travelers target=#7", "ms": 1540},
	{"prompt": "7c97cb5c3c15a7cd", "reply": "trade_propose target=#1 give_money=9 want=[brass lantern]", "ms": 1548},
	{"prompt": "397a6ccd163c8662", "reply": "say text=\"Wren, Pell thinks the stranger is #5, come to join us.\" target=#1", "ms": 2170},
	{"prompt": "c082ad070e9bcf8f", "reply": "go_to target=(12.5, -4.0)", "ms": 4963},
	{"prompt": "76129ca87c4c6f8b", "reply": "trade_propose target=#1 give_money=9 want=[brass lantern]", "ms": 1580},
	{"prompt": "8d7537a9edbd8292", "reply": "examine target=#7", "ms": 1462},
	{"prompt": "86b7e41a3ec2a4dc", "reply": "say text=\"\"Pell, Wren asks what that noise was — likely just the stranger's footsteps. Let us greet them.\"\" target=#7", "ms": 2442},
	{"prompt": "157afffd8e8a6bea", "reply": "go_to target=#4", "ms": 1439},
	{"prompt": "8bda9721d4f53179", "reply": "trade_propose target=#1 want=[brass lantern] want_money=0 give_money=9", "ms": 1570},
	{"prompt": "c2bbc842665d6937", "reply": "go_to target=#7", "ms": 1481},
	{"prompt": "6201ee2b8976d453", "reply": "wait ticks=5", "ms": 1542},
]

## The goal comparison's four questions, recorded in the same pass.
const GOAL_ROWS := [
	{"prompt": "9d1f8d9fedcb8e8d", "reply": "examine target=#6", "ms": 1358},
	{"prompt": "bcf8d2552df681b4", "reply": "go_to target=(-471.0, 416.0)", "ms": 1892},
	{"prompt": "39c75ed90fe09a38", "reply": "trade_propose  target=#2 give_money=1", "ms": 1440},
	{"prompt": "1427f3b27253d1aa", "reply": "say text=\"a fair bargain indeed\" target=#1", "ms": 1298},
]

## The lesson comparison's four questions, recorded in the same pass.
const LESSON_ROWS := [
	{"prompt": "9d1f8d9fedcb8e8d", "reply": "say text=\"what bargain do you offer?\" target=#1", "ms": 2936},
	{"prompt": "bd97aab0d327b347", "reply": "recall about=a fair bargain", "ms": 1489},
	{"prompt": "90f91eda299fba85", "reply": "trade_propose target=#2 give_money=5 want=[sword]", "ms": 1724},
	{"prompt": "f8af88581e3760f4", "reply": "trade_propose target=#1 give=[] give_money=1 want=[] want_money=2", "ms": 2774},
]

## The difficulty-class run's questions, on their own date above.
const CHECK_ROWS := [
	{"prompt": "b723d1dc859f2ded", "reply": "dc=10 ability=str", "ms": 11430},
	{"prompt": "b4dc9bc7079ce35a", "reply": "open target=#2", "ms": 5416},
	{"prompt": "424074711a1ba4fe", "reply": "dc=12 ability=dex", "ms": 3593},
]

## The orchestrator run's questions, on their own date above.
const WORLD_ROWS := [
	{"prompt": "22f1292b9d684f27", "reply": "spawn role=guard at=(-470.0, 425.0)\nopen target=#3\nplace kind=stone at=(-460.0, 418.0)", "ms": 2158},
	{"prompt": "1d698476143903db", "reply": "name=Brak Stonehand\ntraits=musclebound, blunt, socially awkward\ntendencies=solving problems with force, standing silent at posts, fumbling small talk\nbackstory=Raised on the edge of the nine rings where words matter less than a strong back, Brak took guard work because it pays a body for what it already has.", "ms": 3484},
	{"prompt": "aee4ee80fbc4c9e5", "reply": "nothing", "ms": 1277},
	{"prompt": "a6c0bba3a25571a0", "reply": "spawn  role=herald at=(-476.0, 428.0)", "ms": 2103},
	{"prompt": "80d0d0f4755ca59f", "reply": "spawn role=herald at=(12.5, -4.0)\nplace kind=chest at=(12.5, -4.0)\nnothing", "ms": 865},
	{"prompt": "bcee866c834efba8", "reply": "spawn role=scholar at=(-465.0, 421.0)\nopen target=#5\nplace kind=crate at=(-468.0, 416.0)", "ms": 2249},
	{"prompt": "5bcbc91e67907124", "reply": "name=Mireth\ntraits=bookish, frail, perceptive\ntendencies=overthinks, lectures at length, avoids hardship\nbackstory=Mireth spent years buried in archives, sharp-minded and wise beyond their years, but a weak constitution drove them out of the library and toward a life where thinking, not enduring, is the work.", "ms": 3689},
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
