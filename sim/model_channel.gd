extends RefCounted
## Where a model's answer comes from, and how it arrives without stopping the
## world.
##
## A channel is asked a question and hands back a ticket. From then on it is
## polled: `reply_to()` returns "" for as long as the answer is outstanding, and
## the answer once it is there. Nothing in it ever waits for anything, which is
## the whole point -- section 12 requires that "the sim never blocks on an LLM; a
## character waits in-world instead of freezing the game", and a channel that
## blocked would make that impossible however carefully the loop was written.
##
## ## It holds no connection, no thread and no clock
##
## Nothing under `sim/` may read a clock: every duration in the simulation is a
## count of ticks, and `tests/test_control_loop.gd` scans this directory for `OS`
## and `Time` and fails on either. A model answers in seconds, so the connection,
## the timeout and the worker thread live outside the simulation, in
## `net/model_call.gd`. What reaches this file is a `Callable`:
##
##     a transport:      func(prompt: String) -> Callable
##     a call in flight: func() -> Dictionary
##
## where the flight answers `{}` while there is no answer and
## `{"reply", "ms", "why"}` once there is. That is the whole of what this file
## knows about calling anything, and it is why `sim/` needs no name out of
## `net/`: a transport is handed in from the entry point, exactly as a decision
## function is handed to a character.
##
## ## The recording is handed in, not reached for
##
## The rows a replay answers out of are a table of things a language model said,
## and the simulation is scanned for words that would mean it knows what sort of
## thing it is holding -- with string literals read as code, so that a branch
## cannot hide in one. A stranger's prose cannot live under `sim/` and pass that.
## So the recording lives in `net/`, beside the wire it came off, and reaches this
## file as an `exchange` dictionary handed in by whoever built the channel:
## `{"rows": Array, "from": String, "model": String}`. Nothing here names it.
##
## ## Three channels, one interface
##
##   * **replay** -- the answers are the rows of the exchange handed in: one
##     carried out once against a real model and written down. A replay answers
##     each question with the row recorded for that very prompt -- every row
##     carries the prompt's fingerprint -- falling back to the n-th row for the
##     n-th question when no row matches, and saying so. The answer arrives
##     `THINKS_FOR` ticks later. This is what `./run_tests.sh` and the shipped
##     `./run_agent.sh` use, so neither needs a credential, a network or a
##     running model, and two processes on one seed print the same bytes.
##   * **live** -- the question goes to a transport whose calls run on a worker
##     thread. The thread does the waiting; the simulation goes on ticking, and
##     the answer appears at whichever tick the flight first answers on.
##   * **record** -- the recorder's own, held by nothing else and described on
##     `recording()`: it replays what has been written down and calls the model
##     for what has not, so that a recording can be made in one pass.
##
## The three differ in where the text comes from and in nothing else. All hand
## back a ticket, all are polled, all keep what was asked and what came back, and
## `ModelMind` -- the thing that uses them -- cannot tell which it holds.
##
## ## Why a replayed answer still takes time
##
## A recording has no latency of its own: the text is already there and could be
## handed over on the tick it was asked for. It is not, because a decision that
## arrives instantly is not the decision this layer has to survive. `THINKS_FOR`
## is a stated number of ticks, in exactly the sense `DecisionSource.deliberate`
## is a stated number of ticks -- the scripted stand-in for an answer that takes
## arbitrarily long. What the live channel does with real latency, the replay
## does with a constant, and the shape of the wait is the same on both.
##
## ## What happens when there is no model at the other end
##
## Nothing here asks in advance whether a model can be reached; the only honest
## way to find out is to try, and a decision function that stopped to find out
## would be one that waited. A live call that comes back empty -- no key, a
## refused key, a connection that would not open -- is answered out of the
## recording for that question instead, with the reason kept beside it and
## printed. With no recorded reply for it either, the answer stays empty, the
## character goes on standing in the world, and the transcript says why.
class_name ModelChannel

## The three kinds a channel can be.
const REPLAY := "replay"
const LIVE := "live"
const RECORD := "record"

## How long a replayed answer takes to arrive, in ticks. See the note above: a
## recording has no latency, and a decision that arrives instantly would not
## exercise the thing this layer exists to survive.
const THINKS_FOR := 3

## Whether this channel replays a recording or calls a model.
var kind: String = REPLAY

## Which model the answers came from, live or recorded.
var model_name: String = ""

## One line saying where the recorded replies came from, printed at the head of
## a run beside `why`. Handed in with the rows, because this file does not know
## where they were written down.
var recorded: String = ""

## Why this channel and not another, in one sentence, printed at the head of
## every run so a transcript says where its answers came from.
var why: String = ""

## Every exchange this channel carried, in order: what was asked, what came back,
## and how long it took. What a recording is written out of.
var exchanges: Array[Dictionary] = []

var _rows: Array = []
var _used: Dictionary = {}
var _open: Dictionary = {}
var _call: Callable = Callable()
var _next_ticket: int = 1


# --- Choosing a channel ---------------------------------------------------


## The channel a run uses.
##
## With no transport -- what every shipped run and every test passes -- it is the
## recording, and nothing is consulted to decide that. The unconditionality is
## the point: a run that consulted the environment would print one thing on a
## machine with a key and another on a machine without one, and the shipped
## transcript would stop being a fact about the seed.
static func for_run(exchange: Dictionary, transport: Callable = Callable()) -> ModelChannel:
	if not transport.is_valid():
		return replaying(
			exchange,
			"the shipped run replays the recorded exchange, so it needs no key,"
			+ " no network and no model, and two processes print the same bytes")
	return calling(exchange, transport)


## A channel replaying a recorded exchange.
static func replaying(exchange: Dictionary, why_line: String) -> ModelChannel:
	var channel := ModelChannel.new()
	channel.kind = REPLAY
	channel._take(exchange)
	channel.why = why_line
	return channel


## A channel that puts every question to a transport.
##
## The transport is expected to be one whose calls run somewhere else -- see the
## contract at the head of this file -- because this channel polls it once a tick
## and does nothing else about it.
static func calling(exchange: Dictionary, transport: Callable) -> ModelChannel:
	var channel := ModelChannel.new()
	channel.kind = LIVE
	channel._call = transport
	channel._take(exchange)
	channel.why = "every question put to %s as the run reaches it" % channel.model_name
	return channel


## A channel that replays what has been recorded and calls the model for
## anything that has not been.
##
## This is the recorder's channel and nothing else ever holds one. The transport
## it is given is the one whose calls answer on their first poll, so a question
## the rows do not cover is asked and answered before the tick advances, and then
## handed over `THINKS_FOR` ticks later exactly as a recorded one would be. That
## is what makes the recording faithful: every question is asked at the tick the
## replaying run will ask it at, so the prompts are the same prompts and the
## digests match.
static func recording(exchange: Dictionary, transport: Callable) -> ModelChannel:
	var channel := ModelChannel.new()
	channel.kind = RECORD
	channel._call = transport
	channel._take(exchange)
	channel.why = "recording: %d replies already written down, the rest asked of %s" % [
		channel._rows.size(), channel.model_name,
	]
	return channel


# What a channel keeps out of the recording it is handed: the replies, where they
# came from, and who said them.
func _take(exchange: Dictionary) -> void:
	_rows = exchange.get("rows", [])
	recorded = String(exchange.get("from", ""))
	model_name = String(exchange.get("model", ""))


# --- Asking, and being answered later -------------------------------------


## Put a question, and take a ticket for it. Returns at once, always.
func ask(prompt: String, at_tick: int) -> int:
	var ticket := _next_ticket
	_next_ticket += 1
	var asking := {
		"ticket": ticket, "prompt": prompt,
		"digest": ModelPrompt.digest_of(prompt),
		"asked": at_tick, "answered": -1, "reply": "", "ms": 0,
		"note": "",
	}
	_open[ticket] = asking
	match kind:
		LIVE:
			_start_live(asking)
		RECORD:
			_start_recording(asking)
		_:
			_start_replay(asking)
	return ticket


## The answer to a ticket, or "" while it is still outstanding.
##
## The only thing the deciding side ever calls, and it never waits: a live answer
## is there when the flight says it is, and a replayed one when `THINKS_FOR`
## ticks have gone by.
func reply_to(ticket: int, at_tick: int) -> String:
	if not _open.has(ticket):
		return ""
	var asking: Dictionary = _open[ticket]
	if asking["answered"] >= 0:
		return String(asking["reply"])
	if kind == LIVE:
		_poll_live(asking, at_tick)
	else:
		_poll_replay(asking, at_tick)
	return String(asking["reply"]) if asking["answered"] >= 0 else ""


## Whether a ticket has been answered at all, which is not the same as whether
## its answer had anything in it.
##
## `reply_to()` hands back "" for both "not yet" and "answered with nothing", and
## the deciding side has to tell them apart: the first is a character standing in
## the world waiting, and the second is a question that has been closed and paid
## for. Without this a call that came back empty -- a provider that declined, a
## connection that dropped -- would leave a character waiting on a ticket nothing
## will ever answer, for the rest of the run.
func has_answered(ticket: int) -> bool:
	return _open.has(ticket) and int(_open[ticket]["answered"]) >= 0


## What a ticket cost in ticks, once it has been answered, or -1.
func waited_for(ticket: int) -> int:
	if not _open.has(ticket):
		return -1
	var asking: Dictionary = _open[ticket]
	return -1 if asking["answered"] < 0 else int(asking["answered"]) - int(asking["asked"])


## Anything worth saying about a ticket beyond its answer -- that the recording
## had nothing for it, or that a call came back empty.
func note_on(ticket: int) -> String:
	return "" if not _open.has(ticket) else String(_open[ticket]["note"])


## How many questions this channel has been asked.
func asked() -> int:
	return _open.size()


## Every question this channel has been put, answered or not, in the order they
## were put: the prompt itself, its digest, and when it was asked. What the
## recorder prints when it is run without `--live`, so that what a model would be
## handed can be read without handing it to one.
func questions() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for ticket in range(1, _next_ticket):
		if _open.has(ticket):
			found.append(_open[ticket])
	return found


# --- The recording side ---------------------------------------------------


func _start_replay(asking: Dictionary) -> void:
	var at := _row_for(asking)
	if at < 0 or at >= _rows.size():
		asking["note"] = (
			"the recording holds %d replies and this is question %d, so there is"
			% [_rows.size(), int(asking["ticket"])] + " nothing to answer with")
		return
	_used[at] = true
	var row: Dictionary = _rows[at]
	asking["row"] = row
	if String(row.get("prompt", "")) != String(asking["digest"]):
		asking["note"] = (
			"this reply was recorded for another question: the prompt put here"
			+ " fingerprints %s and the recorded one %s"
			% [asking["digest"], row.get("prompt", "?")])


# Which recorded row answers this question.
#
# By fingerprint first: the earliest row not already spent that was recorded for
# this very prompt. By position second -- the n-th question gets the n-th row --
# when no unspent row fingerprints the same, which is what happens when the world
# has changed under the recording, and which is the case the note above is for.
#
# Position alone is not enough, and the run that needed the whole cast is what
# found that out. A recording is written in the order its answers *arrived*, and a
# character in a fight is not serviced every tick, so its answer can be picked up
# several ticks after it was ready and land in the table behind an answer to a
# later question. Reading rows by position alone then hands one character's reply
# to another from that point on. The fingerprint is already in every row, so
# matching on it costs nothing and cannot be thrown off by the order.
func _row_for(asking: Dictionary) -> int:
	var digest := String(asking["digest"])
	for at in _rows.size():
		if _used.has(at):
			continue
		if String((_rows[at] as Dictionary).get("prompt", "")) == digest:
			return at
	var by_position := int(asking["ticket"]) - 1
	return -1 if _used.has(by_position) else by_position


func _poll_replay(asking: Dictionary, at_tick: int) -> void:
	if not asking.has("row"):
		return
	if at_tick - int(asking["asked"]) < THINKS_FOR:
		return
	var row: Dictionary = asking["row"]
	asking["reply"] = String(row.get("reply", ""))
	asking["ms"] = int(row.get("ms", 0))
	asking["answered"] = at_tick
	_remember(asking)


# The recorder's side: a question the rows already answer is replayed, and one
# they do not is put to the model through a transport that answers at once.
func _start_recording(asking: Dictionary) -> void:
	if int(asking["ticket"]) - 1 < _rows.size():
		_start_replay(asking)
		return
	var flight: Callable = _call.call(String(asking["prompt"]))
	var got: Dictionary = flight.call()
	asking["note"] = String(got.get("why", ""))
	asking["row"] = {
		"prompt": String(asking["digest"]),
		"reply": String(got.get("reply", "")),
		"ms": int(got.get("ms", 0)),
	}


# --- The live side --------------------------------------------------------


# One question, one call in flight. Starting it is the transport's business, and
# whatever it does about threads is the transport's too; from here a flight is a
# `Callable` that either has an answer or has not.
func _start_live(asking: Dictionary) -> void:
	asking["flight"] = _call.call(String(asking["prompt"]))


func _poll_live(asking: Dictionary, at_tick: int) -> void:
	var flight: Callable = asking["flight"]
	var got: Dictionary = flight.call()
	if got.is_empty():
		return
	asking["reply"] = String(got.get("reply", ""))
	asking["ms"] = int(got.get("ms", 0))
	asking["note"] = String(got.get("why", ""))
	if String(asking["reply"]).strip_edges() == "":
		_fall_back_to_the_recording(asking)
	asking["answered"] = at_tick
	_remember(asking)


# A call that came back with nothing is answered out of the recording instead,
# with the reason kept and printed. See the note at the head of this file.
func _fall_back_to_the_recording(asking: Dictionary) -> void:
	var at := int(asking["ticket"]) - 1
	if at >= _rows.size():
		asking["note"] = "%s, and the recording has no reply for question %d either" % [
			asking["note"], at + 1,
		]
		return
	var row: Dictionary = _rows[at]
	asking["reply"] = String(row.get("reply", ""))
	asking["ms"] = int(row.get("ms", 0))
	asking["note"] = "%s, so the recorded reply was replayed instead" % asking["note"]


# --- What was said, kept ---------------------------------------------------


func _remember(asking: Dictionary) -> void:
	exchanges.append({
		"prompt": String(asking["digest"]),
		"reply": String(asking["reply"]),
		"ms": int(asking["ms"]),
		"waited": int(asking["answered"]) - int(asking["asked"]),
		"note": String(asking["note"]),
		"text": String(asking["prompt"]),
	})
