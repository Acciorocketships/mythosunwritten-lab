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
const RECORDED_ON := "2026-09-18"

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
	{"prompt": "9e47e9d83aa60fb3", "reply": "go_to target=#6", "ms": 3139},
	{"prompt": "d70f6b0b2ee90be2", "reply": "say text=Hello there, travelers. What brings you this way? target=#4", "ms": 1715},
	{"prompt": "60a95282950730bd", "reply": "go_to target=#6", "ms": 3171},
	{"prompt": "37f3412d3e7f4934", "reply": "go_to offset=(-6, 0)", "ms": 2714},
	{"prompt": "28e890484b6b0449", "reply": "go_to target=#2", "ms": 10776},
	{"prompt": "449bb79a147dc87e", "reply": "say text=\"good morning, Wren\" target=#1", "ms": 1149},
	{"prompt": "acca87b518350c56", "reply": "go_to target=#4", "ms": 1960},
	{"prompt": "8e97a7fb09527beb", "reply": "go_to target=#2", "ms": 1493},
	{"prompt": "3cdc8e3a44daae7a", "reply": "go_to offset=(3.0, 0.0)", "ms": 1400},
	{"prompt": "fe612e0b9c141d1c", "reply": "pick_up item=brass lantern target=#6", "ms": 5164},
	{"prompt": "a536081b448fa1d5", "reply": "say text=what's in the pile? target=#1", "ms": 2061},
	{"prompt": "dcf4d9df47608b42", "reply": "go_to offset=(3.0, 0.0)", "ms": 1723},
	{"prompt": "20443257b87415af", "reply": "pick_up item=brass lantern target=#6", "ms": 1883},
	{"prompt": "9ea7e2bf1706f6d3", "reply": "go_to offset=(0, -3)", "ms": 2218},
	{"prompt": "fab618864b980c2f", "reply": "say text=\"a pile of goods, over that way — care to look?\" target=#1", "ms": 1956},
	{"prompt": "90b150035fb59bfd", "reply": "say text=Do you have a brass lantern I could buy or trade for? target=#1", "ms": 3006},
	{"prompt": "31bbe5565f2dad28", "reply": "say text=We should keep clear of those strangers by the buildings, or greet them properly. target=#4", "ms": 1766},
	{"prompt": "4d7317e8bfb38dc4", "reply": "go_to offset=(-3, 0)", "ms": 1389},
	{"prompt": "60b65b8d72c366aa", "reply": "trade_accept target=#1", "ms": 1797},
	{"prompt": "8aa3e04ce74a20ec", "reply": "say text=\"Do you have a brass lantern I could buy or trade for?\" target=#2", "ms": 2788},
	{"prompt": "9b1a928570df0ee8", "reply": "go_to offset=(0.0, 2.7)", "ms": 1561},
	{"prompt": "3a3550528ece9cc9", "reply": "say text=Strangers, if you can hear me, we mean no harm. Will you show yourselves? target=#1", "ms": 4328},
	{"prompt": "086a4dbebfdad329", "reply": "say text=\"let's head over and see what's in it\" target=#1", "ms": 2250},
	{"prompt": "b7ae0d9508a359c7", "reply": "go_to offset=(-6, 6)", "ms": 1595},
	{"prompt": "96b5a2853b841bf6", "reply": "trade_propose target=#2 give=[9 coins] want=[brass lantern]", "ms": 5145},
	{"prompt": "ec4c3a90a9557dd1", "reply": "say text=\"I don't have a brass lantern, Pell — sorry.\" target=#7", "ms": 15330},
	{"prompt": "3a3550528ece9cc9", "reply": "go_to target=#4", "ms": 1905},
	{"prompt": "b6cb5786695f3455", "reply": "trade_propose target=#1 give=[coins] give_money=9 want=[brass lantern]", "ms": 6107},
	{"prompt": "c66154a53d9b9376", "reply": "go_to offset=(0, -3)", "ms": 1129},
	{"prompt": "8b8bc0f1a8edbbc5", "reply": "go_to   target=#4", "ms": 1107},
	{"prompt": "3a3550528ece9cc9", "reply": "say text=Perhaps we should approach them together, carefully. target=#4", "ms": 1500},
	{"prompt": "22a97a25e6fdd4c1", "reply": "say text=Agreed, let's greet them properly. I'll approach with you. target=#3", "ms": 1434},
	{"prompt": "f2db543387a7cf22", "reply": "go_to target=(75, 342)", "ms": 1783},
	{"prompt": "99d3cbbcace356a8", "reply": "trade_propose target=#1 give=[coins] give_money=9 want=[brass lantern]", "ms": 1299},
	{"prompt": "7909d5d583f1b239", "reply": "say text=Let's move toward them slowly, Sable — stay close in case they turn hostile. target=#4", "ms": 1390},
	{"prompt": "dbb649083afa3096", "reply": "go_to offset=(0.0, 3.0)", "ms": 3768},
	{"prompt": "7a0e1cc66b5f2573", "reply": "trade_propose target=#1 give=[coins] give_money=9 want=[brass lantern]", "ms": 3281},
	{"prompt": "fbce70630e55fe96", "reply": "go_to offset=(-8, +15)", "ms": 1576},
	{"prompt": "a843c8711eb48c15", "reply": "go_to offset=(0.0, 2.7)", "ms": 4954},
	{"prompt": "a0c142148eba2b65", "reply": "trade_propose target=#1 give=[coins] want=[brass lantern]", "ms": 3639},
	{"prompt": "a0377534f1682359", "reply": "go_to offset=(-10.0, +20.0)", "ms": 1429},
	{"prompt": "63ba42e771411b6a", "reply": "go_to target=#1", "ms": 3629},
	{"prompt": "70b25906c8448cc0", "reply": "examine target=#5", "ms": 2729},
	{"prompt": "03b752ea2c648f54", "reply": "say text=\"Wren, you mentioned a fair bargain — would you trade me a brass lantern?\" target=#1", "ms": 724},
	{"prompt": "e8c0f207c13e6c2f", "reply": "go_to offset=(0, -3)", "ms": 3513},
	{"prompt": "ae38dc57b2fd488b", "reply": "say text=\"Wren, you said 'a fair bargain' — what would you want for a brass lantern?\" target=#1", "ms": 1471},
	{"prompt": "90f58efc69501d12", "reply": "go_to offset=(0, -3)", "ms": 2493},
	{"prompt": "88094ae06c749161", "reply": "go_to target=#2", "ms": 2161},
	{"prompt": "261ad54f240dda56", "reply": "say text=\"Wren, what would you want in trade for a brass lantern?\" target=#1", "ms": 1385},
	{"prompt": "50182e75a29338e9", "reply": "explore", "ms": 3197},
	{"prompt": "94bebd9c08b6cfb5", "reply": "go_to  offset=(2.0, 10.0)", "ms": 620},
	{"prompt": "7e407d94e79524d7", "reply": "go_to offset=(0, 3)", "ms": 3256},
	{"prompt": "dfcd7d5ee3bf22e9", "reply": "say text=\"Wren, Pell — there's a stranger nearby, #3, armed with a sword. Anyone know them?\" target=#1", "ms": 960},
	{"prompt": "f13c42055f4ab051", "reply": "go_to offset=(0.0, 2.7)", "ms": 764},
	{"prompt": "f5a8a21410edcd00", "reply": "say text=\"Wren, please — name your price for the brass lantern. I have coins.\" target=#1", "ms": 1957},
	{"prompt": "618c0e6ae2834b90", "reply": "go_to offset=(0.0, -3.0)", "ms": 1895},
	{"prompt": "f0ea7b9089979be1", "reply": "say text=#3, I see you there with that sword — friend or foe? State your business. target=#3", "ms": 1490},
	{"prompt": "90f58efc69501d12", "reply": "go_to offset=(3, 0)", "ms": 1845},
	{"prompt": "3136ea90155898b0", "reply": "say text=\"Greetings, strangers. We come in peace — may we approach?\" target=#2", "ms": 1612},
	{"prompt": "54bc727d2dea40b9", "reply": "say text=\"Rook, anyone — I have 9 coins. Who will sell me a brass lantern, or tell me where to find one?\" target=#2", "ms": 1854},
	{"prompt": "be58b4d65899ee3b", "reply": "say text=\"Pell, I have no lantern, but I have 20 coins if you'd rather buy one somewhere.\" target=#7", "ms": 3785},
	{"prompt": "be60e9a5a748ca70", "reply": "go_to offset=(-3.0, 0.0)", "ms": 964},
	{"prompt": "60df7c05f32d7b80", "reply": "go_to  offset=(0.0, 6.0)", "ms": 2119},
	{"prompt": "7dd06a8b5ca0b215", "reply": "say text=\"I am Bram, and this is Sable. We're exploring — no quarrel with you.\" target=#2", "ms": 1535},
	{"prompt": "892c116a7aba7faa", "reply": "go_to offset=(0.9, 0.9)", "ms": 673},
	{"prompt": "7ee5478ec41eacd3", "reply": "trade_propose target=#1 give_money=9 want=[brass lantern]", "ms": 824},
	{"prompt": "7c781ecee819e614", "reply": "examine target=x", "ms": 937},
	{"prompt": "52cef0505ddf393a", "reply": "say text=\"Aye, approach slowly and keep hands visible, Bram.\" target=#3", "ms": 1520},
	{"prompt": "4b0c70ec4a4eace4", "reply": "say text=\"I am Bram, and this is Sable. We're exploring — no quarrel with you.\" target=#2", "ms": 1480},
	{"prompt": "a768dd8683f7c999", "reply": "say text=\"Staying close, Bram. Let's greet them — hello there, friends!\" target=#1", "ms": 907},
	{"prompt": "0dec24ec4f251d22", "reply": "go_to target=#x", "ms": 1897},
	{"prompt": "f2c84f483e84bcb2", "reply": "trade_propose target=#1 give_money=9 want=[brass lantern]", "ms": 1289},
	{"prompt": "cca0ff48c85e4a40", "reply": "say text=\"Sable, is it? Welcome, Bram and Sable. We're four on this ground — no trouble from us either.\" target=#4", "ms": 1194},
	{"prompt": "778638f0c8154b8d", "reply": "say text=\"Hello there, friends! We come in peace — mind if we join you?\" target=#1", "ms": 1595},
	{"prompt": "cab1c9e05f8deffb", "reply": "go_to offset=(1, 0)", "ms": 1802},
	{"prompt": "6624fa40386a1233", "reply": "say text=Wren, I have 9 coins — will you sell me the brass lantern for them? target=#1", "ms": 726},
	{"prompt": "531b8d0e4e9bd91e", "reply": "say text=\"Hello there, friends! We come in peace — mind if we join you?\" target=#2", "ms": 890},
	{"prompt": "d30b9d8ecd38ae8c", "reply": "recall about=brass lantern", "ms": 2476},
	{"prompt": "03b417c5cdeac79f", "reply": "say text=\"Thank you, Rook. We'll keep our hands visible — may we come closer and talk?\" target=#2", "ms": 1353},
	{"prompt": "0dec24ec4f251d22", "reply": "wait ticks=10", "ms": 1118},
	{"prompt": "2d99480ca230cf76", "reply": "say text=Wren, I have 9 coins and Rook has 20 — between you, who will sell me a brass lantern? target=#1", "ms": 1775},
	{"prompt": "6bae4b5f62aa77ae", "reply": "say text=\"Good to meet you, Rook. Mind telling me your friend's name?\" target=#2", "ms": 2736},
	{"prompt": "331543273fefc6f4", "reply": "say text=\"Pell, we should search the buildings nearby for a lantern — Sable, Bram, seen any around?\" target=#7", "ms": 1815},
	{"prompt": "46824d8998afe4b4", "reply": "say text=\"Thank you, Rook. We'll approach slowly, hands visible. May I ask your names and what brings you here?\" target=#2", "ms": 935},
	{"prompt": "a153ccedea9f2324", "reply": "say text=\"Wren, I have 9 coins and Rook has 20 — who among you will sell me a brass lantern?\" target=#1", "ms": 975},
]

## The goal comparison's four questions, recorded in the same pass.
const GOAL_ROWS := [
	{"prompt": "090790218ee1f7f0", "reply": "say text=\"just the wind, I think\" target=#1", "ms": 1067},
	{"prompt": "6f7f4a0c09401924", "reply": "go_to target=(93.5, 290.0)", "ms": 1722},
	{"prompt": "77e576eb1280f1c9", "reply": "trade_propose target=#2 give_money=5 want=[]", "ms": 2602},
	{"prompt": "adec6dbac136e231", "reply": "say text=just the wind, I think target=#1", "ms": 2142},
]

## The lesson comparison's four questions, recorded in the same pass.
const LESSON_ROWS := [
	{"prompt": "090790218ee1f7f0", "reply": "say text=just me, sorry if I startled you target=#1", "ms": 781},
	{"prompt": "2e6bd489416263b0", "reply": "recall about=pile #6", "ms": 2109},
	{"prompt": "2268a9d4e3b21d12", "reply": "say text=what noise? target=#1", "ms": 5092},
	{"prompt": "fc029e7ee3c7efb9", "reply": "recall about=noise", "ms": 1982},
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
