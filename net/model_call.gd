extends RefCounted
## The one place in the repository that touches the network, the clock and a
## thread.
##
## It exists because of a rule the simulation already keeps and must go on
## keeping: **nothing under `sim/` reads a clock**. Every duration in the
## simulation is a count of ticks, and `tests/test_control_loop.gd` scans every
## file under `sim/` for `OS` and `Time` and fails on either. A language model,
## though, answers in seconds and not in ticks, and something somewhere has to
## own an HTTPS connection, a timeout and a worker thread.
##
## So the seam is here. `sim/model_channel.gd` holds no connection and no clock;
## it holds a `Callable`, asks it a question, and polls it. This file is what
## that `Callable` is, and it lives outside `sim/` for the same reason `render/`
## does: the simulation may be driven by it and must not know it exists.
##
## ## The contract, which is two Callables and no types
##
## A *transport* is
##
##     func(prompt: String) -> Callable
##
## and what it hands back is a *call in flight*:
##
##     func() -> Dictionary
##
## which answers `{}` while there is no answer yet, and
## `{"reply": String, "ms": int, "why": String}` once there is. Nothing but
## dictionaries and callables crosses the line, which is why `sim/` needs no name
## from this file and this file needs no type from `sim/`.
##
## Two transports are built here, and they differ in one thing only:
##
##   * `on_a_thread()` -- the call runs on a worker `Thread` and the flight
##     answers `{}` until that thread has finished. This is what a running
##     simulation uses: the world goes on ticking and the character stands in it.
##   * `at_once()` -- the call runs on the calling thread and the flight answers
##     on its first poll, because it waited. This is what the *recorder* uses,
##     and the one place in the project where waiting for a model is right:
##     the recorder is not simulating a world, it is transcribing an exchange.
class_name ModelCall

## Where a call goes. One endpoint, named once.
const HOST := "openrouter.ai"
const ROUTE := "/api/v1/chat/completions"
const ENDPOINT := "https://openrouter.ai/api/v1/chat/completions"

## Which environment variable the key is read from. Never a file in the tree.
const KEY_VARIABLE := "OPENROUTER_API_KEY"

## Which model is asked, and how much of an answer is paid for. The temperature
## is nailed down because a recording of a coin toss is not a recording of
## anything.
##
## The ceiling counts everything the model spends before the line comes out, not
## the line itself: one answer to this run's prompt was measured at 89 tokens for
## seven tokens of "examine target=#6". A ceiling set to the size of the wanted
## answer therefore cuts the answer off mid-word -- a reply of "go_to" with the
## target still to come, or nothing readable at all -- and it did, the first time
## this run was recorded against the larger observation packet. It is set well
## clear of that: an answer is still one line, and a run that stops paying for
## thinking part-way through is not cheaper, it is broken.
##
## It was raised again when the prompt grew to carry what the character
## remembers. One question out of eighteen came back with nothing readable in it
## and `length` as the reason -- the model had spent the whole ceiling working and
## never reached its line. The ceiling is about the working, not the answer, and
## the working grows with the question.
const MODEL := "anthropic/claude-fable-5"
const MAX_TOKENS := 1200
const TEMPERATURE := 0

## How long a call is given before it is called unanswered, in milliseconds, and
## how long the polling loop sleeps between looks. Neither is a simulation
## duration: no tick of any world is counted here.
const PATIENCE_MS := 60000
const REST_MS := 10


# --- The two transports ---------------------------------------------------


## A transport whose calls run on a worker thread.
##
## The flight answers `{}` until the thread has put something in the box. The
## caller is expected to poll it and get on with its life in between, which is
## exactly what a control loop does with a character that has not decided yet.
##
## `started` is where the threads are kept, and the caller keeps it so that it
## can `settle()` them when the run is over. A run can perfectly well end with a
## call still in flight -- a character was waiting for an answer when the last
## tick went by -- and a thread that is dropped without being waited on makes the
## engine complain and then abort. That is the whole reason the array is a
## parameter: the thing that ends the run is the thing that has to tidy up after
## it, and it cannot do that if the only handle is inside a closure.
static func on_a_thread(key: String, started: Array = []) -> Callable:
	var threads := started
	return func(prompt: String) -> Callable:
		var box := []
		var guard := Mutex.new()
		var thread := Thread.new()
		threads.append(thread)
		thread.start(func() -> void:
			var got := fetch(key, prompt)
			guard.lock()
			box.append(got)
			guard.unlock())
		return func() -> Dictionary:
			guard.lock()
			var answer: Variant = box[0] if not box.is_empty() else null
			guard.unlock()
			if answer == null:
				return {}
			if thread.is_started():
				thread.wait_to_finish()
			return answer


## Wait for every thread a transport started that has not been waited on, and
## hand back how many there were.
##
## Called once, when a run is over. Nothing in the simulation calls it: the
## simulation never waits for a model, and this is not the simulation -- it is
## the tidying up afterwards, which somebody has to do because a `Thread` dropped
## while it is still running aborts the engine.
static func settle(started: Array) -> int:
	var waited := 0
	for thread in started:
		if thread is Thread and thread.is_started():
			thread.wait_to_finish()
			waited += 1
	started.clear()
	return waited


## A transport whose calls run here and now.
##
## The flight has already finished by the time it is handed back, so its first
## poll answers. Only the recorder holds one: a simulation that did would be a
## simulation that waits on a model, which is the thing this whole layer exists
## not to do.
##
## `tries` is how many times one question is put before its answer is taken as
## final, and it is greater than one only because the recorder needs it -- see
## the note inside. Nothing that ships passes it.
static func at_once(key: String, tries: int = 1) -> Callable:
	return func(prompt: String) -> Callable:
		var got := fetch(key, prompt)
		var left := maxi(1, tries) - 1
		while left > 0 and String(got.get("reply", "")).strip_edges() == "":
			# One question, asked again. A provider that answers a question with
			# nothing -- a rate limit, a dropped connection, a classifier that
			# fired on the world's own prose -- has said nothing about the
			# question, and a recording of that silence would replay as a
			# character that never chooses anything. So the recorder asks again a
			# stated number of times and only then gives up, which is what makes
			# recording a run of fifty questions practical at all. Nothing that
			# ships uses this: the live channel makes one call and reports what
			# came back.
			got = fetch(key, prompt)
			left -= 1
		return func() -> Dictionary:
			return got


# --- The credential -------------------------------------------------------


## The key, out of the environment and out of nowhere else.
static func key() -> String:
	return OS.get_environment(KEY_VARIABLE).strip_edges()


## Whether a call could be made from here at all, and why not when it could not.
static func credentials() -> Dictionary:
	if key() == "":
		return {"ok": false, "why": "%s is not set in the environment" % KEY_VARIABLE}
	return {"ok": true, "why": "%s is set" % KEY_VARIABLE}


# --- One call -------------------------------------------------------------


## One HTTPS call, and everything that can go wrong with it said in a sentence.
##
## Never returns an error and never pushes one: a call that did not work comes
## back as an empty reply with a `why`, because the thing that asked is a
## character standing in a field and the only thing it can do about any of this
## is go on standing there.
static func fetch(key_value: String, prompt: String) -> Dictionary:
	var began := Time.get_ticks_msec()
	var http := HTTPClient.new()
	if http.connect_to_host(HOST, 443, TLSOptions.client()) != OK:
		return _nothing(0, "could not open a connection to %s" % HOST)
	while http.get_status() == HTTPClient.STATUS_CONNECTING \
			or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(REST_MS)
		if Time.get_ticks_msec() - began > PATIENCE_MS:
			return _nothing(0, "connecting to %s timed out" % HOST)
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return _nothing(0, "no connection to %s (status %d)" % [HOST, http.get_status()])

	var body := JSON.stringify({
		"model": MODEL,
		"max_tokens": MAX_TOKENS,
		"temperature": TEMPERATURE,
		"messages": [{"role": "user", "content": prompt}],
	})
	var headers := [
		"Authorization: Bearer %s" % key_value,
		"Content-Type: application/json",
	]
	if http.request(HTTPClient.METHOD_POST, ROUTE, headers, body) != OK:
		return _nothing(0, "the request could not be sent")
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(REST_MS)
		if Time.get_ticks_msec() - began > PATIENCE_MS:
			return _nothing(0, "the call timed out")

	var raw := PackedByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(REST_MS)
		else:
			raw.append_array(chunk)
		if Time.get_ticks_msec() - began > PATIENCE_MS:
			return _nothing(0, "the answer timed out part-way")
	var code := http.get_response_code()
	http.close()
	var spent := Time.get_ticks_msec() - began
	if code != 200:
		return _nothing(spent, "the model answered with HTTP %d: %s" % [
			code, raw.get_string_from_utf8().substr(0, 200)])
	return _said_in(raw.get_string_from_utf8(), spent)


# What the model said, out of the answer it came in.
static func _said_in(text: String, spent: int) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary) or not parsed.has("choices"):
		return _nothing(spent, "the answer was not of the shape expected")
	var choices: Array = parsed["choices"]
	if choices.is_empty():
		return _nothing(spent, "the model chose nothing")
	var message: Dictionary = choices[0].get("message", {})
	# An answer with nothing readable in it is an answer, not a crash. A model
	# that declines says so in `refusal`, and one that ran out of room to speak
	# leaves `content` empty or null; both come back here as no reply and a
	# sentence saying which, so the recorder can refuse to write it down and say
	# why rather than the run falling over mid-question.
	var content: Variant = message.get("content", "")
	if not (content is String):
		var refused: Variant = message.get("refusal", null)
		if refused is String and (refused as String).strip_edges() != "":
			return _nothing(spent, "the model declined: %s" % (
				(refused as String).substr(0, 200)))
		return _nothing(spent, "the model answered with nothing to read (%s)" % (
			choices[0].get("finish_reason", "no reason given")))
	return {"reply": (content as String).strip_edges(), "ms": spent, "why": ""}


static func _nothing(spent: int, why: String) -> Dictionary:
	return {"reply": "", "ms": spent, "why": why}
