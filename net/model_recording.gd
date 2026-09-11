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
const RECORDED_ON := "2026-09-11"

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
	{"prompt": "62f4269849130446", "reply": "examine target=#6", "ms": 1564},
	{"prompt": "541a9b531bc5a2fb", "reply": "say text=Hail, traveler! target=#4", "ms": 884},
	{"prompt": "4886caedf2f50b35", "reply": "go_to target=#3", "ms": 745},
	{"prompt": "0475d89e65291196", "reply": "go_to offset=(6, 0)", "ms": 937},
	{"prompt": "32c8a374b933cf9d", "reply": "go_to target=#2", "ms": 29060},
	{"prompt": "0a5c54a1b7b34d36", "reply": "go_to target=#6", "ms": 784},
	{"prompt": "a55271283d2193d5", "reply": "say text=good morning target=#1", "ms": 593},
	{"prompt": "2ad7fe4d6360643c", "reply": "say text=\"What brings you this way?\" target=#4", "ms": 1503},
	{"prompt": "98fb1c8bead53904", "reply": "examine target=x", "ms": 778},
	{"prompt": "b980ed962c29c85d", "reply": "say text=Hail, Bram! What brings you out here? target=#3", "ms": 1110},
	{"prompt": "7f4867531a518961", "reply": "pick_up item=brass lantern target=#6", "ms": 1181},
	{"prompt": "52f0ea4772693c00", "reply": "say text=\"a fine morning for exploring\" target=#1", "ms": 917},
	{"prompt": "8a948a47e8bd74a9", "reply": "go_to  offset=(3, 0)", "ms": 653},
	{"prompt": "fc63b2cd9158c99d", "reply": "say text=\"Fine day for a walk, isn't it?\" target=#4", "ms": 662},
	{"prompt": "6deba7aa4b4e1ac4", "reply": "go_to target=#6", "ms": 1164},
	{"prompt": "d27aeb9609db58ea", "reply": "go_to offset=(3, 0)", "ms": 1007},
	{"prompt": "802d59d4d800f98e", "reply": "say text=\"a fine morning for exploring\" target=#1", "ms": 805},
	{"prompt": "d317bb894f9e7f8f", "reply": "say text=\"Just wandering, seeing what the land holds. Care to travel together?\" target=#3", "ms": 1000},
	{"prompt": "1f1e456798afecdf", "reply": "go_to offset=(3, 0)", "ms": 654},
	{"prompt": "d30c5321ed8e2be9", "reply": "say text=\"Aye, it is. Safe travels, friend.\" target=#4", "ms": 1178},
	{"prompt": "1bbb9b98d695265a", "reply": "trade_accept target=#1", "ms": 663},
	{"prompt": "8e1fd728953bf5ef", "reply": "go_to offset=(3, 0)", "ms": 904},
	{"prompt": "4c2e923552e98add", "reply": "say text=\"Then let's wander together, friend.\" target=#3", "ms": 721},
	{"prompt": "22c3eeab9bf27550", "reply": "say text=\"shall we head out and explore together?\" target=#1", "ms": 1078},
	{"prompt": "07c5c9df82a3d5f3", "reply": "go_to  offset=(3, 0)", "ms": 924},
	{"prompt": "7de1b16e9ee7ec56", "reply": "say text=\"Traveling together sounds good to me. Lead the way?\" target=#4", "ms": 2536},
	{"prompt": "4a5ef75e49c12a2a", "reply": "go_to target=#6", "ms": 12234},
	{"prompt": "a2d68bf15be3e678", "reply": "say text=\"shall we head out and explore together?\" target=#7", "ms": 5845},
	{"prompt": "a4d8c478c2c1dfb5", "reply": "go_to offset=(9, 0)", "ms": 3246},
	{"prompt": "5af74e40f34e1289", "reply": "go_to  offset=(0.0, -3.0)", "ms": 652},
	{"prompt": "6f3061d324ecaf31", "reply": "say text=\"Pell, Wren and I could make a fine exploring party — shall we three head out together?\" target=#7", "ms": 832},
	{"prompt": "6505b943bf2ed553", "reply": "say text=\"After you, then — which way shall we wander?\" target=#4", "ms": 2091},
	{"prompt": "0fbc5fa01af220c7", "reply": "go_to  offset=(2.0, 0.0)", "ms": 1784},
	{"prompt": "4b70e6d80af40b13", "reply": "go_to offset=(3, 0)", "ms": 1150},
	{"prompt": "f291ae0259fc0741", "reply": "say text=\"then let us be off — east, toward the open ground\" target=#1", "ms": 1330},
	{"prompt": "421a6e2807be60c9", "reply": "say text=\"East looks promising — let's head that way.\" target=#4", "ms": 1950},
	{"prompt": "f8e06d6bcef6437a", "reply": "go_to offset=(3, 0)", "ms": 988},
	{"prompt": "fc521f27ba407fd3", "reply": "say text=\"East, toward that rise — the land looks promising that way.\" target=#3", "ms": 2568},
	{"prompt": "a55bd2f5f3052280", "reply": "go_to offset=(6.0, 0.0)", "ms": 1341},
	{"prompt": "c0c45cbc100f93fe", "reply": "go_to offset=(3, 0)", "ms": 851},
	{"prompt": "6285b34a1bbf17e7", "reply": "go_to  offset=(6.0, 0.0)", "ms": 4328},
	{"prompt": "c92affdbcdcb4c48", "reply": "go_to offset=(3, 0)", "ms": 1160},
	{"prompt": "1170ae8a087fe83b", "reply": "go_to offset=(6.0, 0.0)", "ms": 901},
	{"prompt": "44565719dfec053e", "reply": "go_to  offset=(3, 0)", "ms": 690},
	{"prompt": "39248742505e543b", "reply": "say text=\"Aye, Rook — let the three of us head out together.\" target=#2", "ms": 11150},
	{"prompt": "a9947b74064329b6", "reply": "go_to offset=(3, 0)", "ms": 1798},
	{"prompt": "ef2b5fa54e5a3b89", "reply": "go_to offset=(3.0, 0.0)", "ms": 2208},
	{"prompt": "1671b962dce61db6", "reply": "go_to  offset=(+3.0, +0.0)", "ms": 1887},
	{"prompt": "3fa503e3be617dba", "reply": "go_to  offset=(3.0, 0.0)", "ms": 2253},
	{"prompt": "c9ca9596038aab68", "reply": "go_to offset=(3, 0)", "ms": 2180},
	{"prompt": "7e8b4827e9743618", "reply": "go_to target=#6", "ms": 3739},
	{"prompt": "ca7a0aba162c8f7d", "reply": "go_to offset=(10, 0)", "ms": 1947},
	{"prompt": "14ca02001a1010d5", "reply": "go_to offset=(3.0, 0.0)", "ms": 1942},
	{"prompt": "a6e4f185843c1b91", "reply": "go_to  offset=(3.0, 0.0)", "ms": 6402},
	{"prompt": "5c964e59407c6247", "reply": "go_to offset=(3, 0)", "ms": 742},
	{"prompt": "d5a9d165d8916b19", "reply": "go_to  offset=(3.0, 0.0)", "ms": 899},
	{"prompt": "1900812c67b200ff", "reply": "go_to  offset=(3.0, 0.0)", "ms": 8933},
	{"prompt": "c703da78afdb76c7", "reply": "go_to offset=(3, 0)", "ms": 963},
	{"prompt": "d6e18d959b459960", "reply": "go_to  offset=(3.0, 0.0)", "ms": 745},
	{"prompt": "ff7926c6687fffeb", "reply": "go_to offset=(3.0, 0.0)", "ms": 702},
	{"prompt": "97c3d23fad5e0bab", "reply": "go_to offset=(3.0, 0.0)", "ms": 690},
	{"prompt": "75601b2044895087", "reply": "go_to offset=(3, 0)", "ms": 694},
	{"prompt": "1439de63516bd282", "reply": "go_to offset=(3.0, 0.0)", "ms": 631},
	{"prompt": "7306ae0ca32176ef", "reply": "say text=\"Wren, Pell — I heard it too. Stay sharp; let's move east together and find what made that noise.\" target=#1", "ms": 907},
	{"prompt": "35b51eb05aba8c2a", "reply": "go_to  offset=(3.0, 0.0)", "ms": 1916},
	{"prompt": "e69d69752d32f77c", "reply": "go_to offset=(6, 0)", "ms": 2147},
	{"prompt": "958f3b4492fd8345", "reply": "say text=\"What noise, Wren? I heard nothing but the wind.\" target=#1", "ms": 846},
	{"prompt": "402d91b958048434", "reply": "go_to offset=(3.0, 0.0)", "ms": 641},
	{"prompt": "5987f4d790c9b69d", "reply": "go_to offset=(3.0, 0.0)", "ms": 661},
	{"prompt": "f7634d8ae9de1d79", "reply": "say text=I heard nothing myself — perhaps #3, the armed one moving east? target=#1", "ms": 1041},
	{"prompt": "5ddb618374ba2a19", "reply": "say text=Shall we set off, then? Rook, Wren — the road waits. target=#2", "ms": 1240},
	{"prompt": "c0f25dd5fcae1d25", "reply": "go_to offset=(3, 0)", "ms": 621},
	{"prompt": "23179774e706725b", "reply": "go_to offset=(3, 0)", "ms": 1014},
	{"prompt": "1b06e0d6639ff245", "reply": "go_to offset=(3.0, 0.0)", "ms": 1575},
	{"prompt": "f9ed2a37e5bee1fb", "reply": "say text=\"Wren, Pell — I heard it too. Let us move east together and find what made that noise.\" target=#1", "ms": 1381},
	{"prompt": "854cebafa81c5ae8", "reply": "go_to offset=(3.0, 0.0)", "ms": 786},
	{"prompt": "cd7db9e6f71a73a2", "reply": "go_to offset=(3, 0)", "ms": 682},
	{"prompt": "17b5ec1e5f2d24a2", "reply": "say text=Set off east, then — keep together, and mind the edge south of here. target=#2", "ms": 1525},
	{"prompt": "aa7cbb4b0cfbe0ac", "reply": "go_to  offset=(3.0, 0.0)", "ms": 692},
	{"prompt": "3cb28b1a0180f83a", "reply": "go_to  offset=(3.0, 0.0)", "ms": 859},
	{"prompt": "db3b95cd22e62d57", "reply": "go_to  offset=(3, 0)", "ms": 1091},
	{"prompt": "efe2817f493862c0", "reply": "say text=the three of us are set — east, toward that open ground, and let us find what made that noise target=#1", "ms": 806},
	{"prompt": "50deaf0000bd259a", "reply": "go_to offset=(3.0, 0.0)", "ms": 640},
	{"prompt": "85953438f7c6ddda", "reply": "say text=\"Rook, Wren — eastward, and mind the drop south of here.\" target=#2", "ms": 1175},
	{"prompt": "fe168dddff9c2857", "reply": "say text=\"East it is — after you, Sable.\" target=#4", "ms": 785},
	{"prompt": "785102a593d63545", "reply": "go_to offset=(3, 0)", "ms": 5912},
	{"prompt": "4eb5abd55fb61ea4", "reply": "go_to offset=(3.0, 0.0)", "ms": 690},
	{"prompt": "315fda818dda8c21", "reply": "go_to offset=(3, 0)", "ms": 847},
	{"prompt": "8f6784bcadadfa01", "reply": "go_to offset=(3.0, 0.0)", "ms": 1429},
	{"prompt": "3014f19e79abf7ce", "reply": "go_to offset=(3, 0)", "ms": 1725},
	{"prompt": "42f4241db0f8a4d8", "reply": "go_to  target=#4", "ms": 686},
	{"prompt": "b0d31d79cc0d126e", "reply": "go_to  offset=(3.0, 0.0)", "ms": 760},
	{"prompt": "3358aaa1cd552b75", "reply": "go_to  offset=(3.0, 0.0)", "ms": 756},
	{"prompt": "ce800fc532c05e24", "reply": "go_to offset=(3.0, 0.0)", "ms": 1026},
	{"prompt": "b4e507ce0d5ce046", "reply": "go_to offset=(3, 0)", "ms": 662},
	{"prompt": "57fd1737b51bb1f9", "reply": "go_to offset=(3.0, 0.0)", "ms": 737},
	{"prompt": "d5c38382cf4fc4cf", "reply": "go_to offset=(6, 0)", "ms": 1373},
	{"prompt": "6fe04e16fb1d5eca", "reply": "go_to offset=(3.0, 0.0)", "ms": 1153},
	{"prompt": "063d38c5d1ad7948", "reply": "go_to offset=(3, 0)", "ms": 840},
	{"prompt": "494c9f02f5752697", "reply": "go_to  offset=(3.0, 0.0)", "ms": 1858},
	{"prompt": "9d5a635231604277", "reply": "go_to target=#2", "ms": 5039},
	{"prompt": "063d38c5d1ad7948", "reply": "go_to offset=(0, -3)", "ms": 445},
	{"prompt": "09f4ae51d0f48cee", "reply": "go_to  offset=(3.0, 0.0)", "ms": 1792},
	{"prompt": "2b5f23dbf02dc306", "reply": "go_to offset=(9, 0)", "ms": 1165},
	{"prompt": "d86d3b7120842499", "reply": "go_to  offset=(3.0, 0.0)", "ms": 1009},
	{"prompt": "063d38c5d1ad7948", "reply": "go_to offset=(3, 0)", "ms": 856},
	{"prompt": "796e093db3ff8b9f", "reply": "go_to  offset=(3.0, 0.0)", "ms": 7714},
	{"prompt": "540cf71d41bf158e", "reply": "go_to offset=(3.0, 0.0)", "ms": 662},
]

## The goal comparison's four questions, recorded in the same pass.
const GOAL_ROWS := [
	{"prompt": "f256a9e7201e9ba3", "reply": "say text=\"just me, sorry\" target=#1", "ms": 754},
	{"prompt": "e120ce0dc35266be", "reply": "go_to target=(-471.0, 416.0)", "ms": 1026},
	{"prompt": "55bf4364b6bc36bb", "reply": "trade_propose target=#2 give_money=4", "ms": 734},
	{"prompt": "d5e52485b38c6f16", "reply": "say text=I heard nothing amiss, Wren. All is well here. target=#1", "ms": 881},
]

## The lesson comparison's four questions, recorded in the same pass.
const LESSON_ROWS := [
	{"prompt": "f256a9e7201e9ba3", "reply": "say text=\"just me, Pell\" target=#1", "ms": 1420},
	{"prompt": "48495b2f29542471", "reply": "recall about=pile #6", "ms": 946},
	{"prompt": "759906ee8445c861", "reply": "recall about=the noise Wren heard", "ms": 734},
	{"prompt": "c0e12cb8a47f97b8", "reply": "recall about=noise", "ms": 692},
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
