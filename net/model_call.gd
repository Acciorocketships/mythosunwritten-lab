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

## Where a call goes when the environment names nowhere else. One host, named
## once.
##
## ## Two endpoints, and why only one of them is written down here
##
## What is named below is a paid service reached over TLS on port 443 with a
## bearer token in a header. A small model running on the same machine as the
## game is none of those things -- it is plain HTTP on a loopback port with no
## credential at all -- and three non-thinking 3-4B models answered this run's
## own prompt in 115 to 175 milliseconds warm, against a 5.2-second median for
## the calls the shipped recording was made with. That is worth having: a soak
## that would cost real money against the paid endpoint costs nothing against a
## local one, and a prompt change can be shaken out before a recording is paid
## for.
##
## So there are two endpoints, and the second one is read out of the environment
## for exactly the reason the key is. An address is a fact about somebody's
## machine and not about this project; writing `127.0.0.1` into the tree would
## make the repository claim something about whichever machine is reading it.
## `LOCAL_MODEL_ENDPOINT` names the whole URL and `LOCAL_MODEL` names the model to
## ask for. With neither set, every command in the repository means exactly what
## it meant before this seam existed.
##
## The seam is here and nowhere else. Nothing under `sim/` learns that a second
## endpoint exists, in the same way and for the same reason that nothing under
## `sim/` knows the first one's name: what crosses the line is a `Callable`.
const HOST := "openrouter.ai"
const ROUTE := "/api/v1/chat/completions"
const ENDPOINT := "https://openrouter.ai/api/v1/chat/completions"

## Which environment variable the key is read from. Never a file in the tree.
const KEY_VARIABLE := "OPENROUTER_API_KEY"

## Which environment variables the second endpoint is read from. Never a file in
## the tree either, and for the same reason. See the note above.
const ENDPOINT_VARIABLE := "LOCAL_MODEL_ENDPOINT"
const MODEL_VARIABLE := "LOCAL_MODEL"

## Which model is asked, how much of an answer is paid for, and how much
## thinking is asked of it. The temperature is nailed down because a recording
## of a coin toss is not a recording of anything.
##
## ## Why `REASONING` is not an option that could be dropped
##
## It goes into the request body as `"reasoning": {"effort": "low"}`, and it is
## the difference between a model that answers and a model that thinks until the
## money runs out. Every cheap model worth having here is a reasoning model, and
## at a ceiling of any size it will spend the ceiling working and come back with
## an empty string and `length` as the reason -- the failure the old note on
## `MAX_TOKENS` below describes for the model that used to be named here, except
## that on this class of model it is the normal case rather than the exception.
##
## Measured on this run's own first question -- 3,111 characters, the one
## `./run_record.sh` prints without `--live`:
##
##   * with no `reasoning` field at all, this model answered in 9.3 and 13.9
##     seconds, spending 209 and 326 completion tokens, of which 769 and 1,197
##     characters were thinking nobody reads;
##   * with `{"effort": "low"}`, 1.26 and 1.49 seconds, 7 and 18 completion
##     tokens, and no thinking at all.
##
## The obvious stronger form of the same idea does not work here: `{"enabled":
## false}` is answered with HTTP 400, "Reasoning is mandatory for this endpoint
## and cannot be disabled". Nor is `{"effort": "minimal"}` the smaller of the two
## efforts -- it is measurably slower than `low`, which is counter-intuitive
## enough to be worth writing down rather than rediscovering.
##
## The model that *does* take `{"enabled": false}`, `inception/mercury-2.5-preview`,
## is three times faster again and was recorded in full before this one. It is
## not what ships. With the thinking off it answered the character prompt very
## well and the world's prompt very badly: four of its five answers to the
## orchestrator spawned somebody at `(12.5, -4.0)`, which is the example
## coordinate out of the prompt's own format line, so the run carried out 1 of 15
## operations and spawned nobody, against this model's 5 of 9 and two characters
## with names and backstories. That is the whole reason the fallback the probe
## documented was taken.
##
## ## What the ceiling has to cover
##
## It is left where it was, at 1200, and it is slack rather than a budget --
## nothing is paid for a token that is not produced. What it has to cover is now
## two things rather than one, because this model's thinking can be turned down
## but not off:
##
##   * whatever working an `{"effort": "low"}` call still does, which on the
##     shipped prompt measured at none but is not promised to be none; and
##   * the longest answer any of the five runs asks for, which is not a character
##     choosing an action (7 to 18 tokens) but the orchestrator's "who is this",
##     answered with a whole persona -- name, traits, tendencies and backstory,
##     431 to 516 characters, so roughly 110 to 140 tokens.
##
## The note it replaces is kept because its reasoning is why this one exists: the
## ceiling counts everything the model spends *before* the line comes out, not
## the line itself. One answer to this run's prompt was once measured at 89
## tokens for seven tokens of "examine target=#6", and a ceiling set to the size
## of the wanted answer cut the answer off mid-word. That is still true, and it
## is why a model whose thinking cannot be held to nothing is not given a ceiling
## trimmed to the length of its line.
const MODEL := "z-ai/glm-5.3-flash"
const MAX_TOKENS := 1200
const TEMPERATURE := 0

## How much thinking is asked of the model, sent as `reasoning` in the request
## body. See the note above: this is what makes the model answer in a second
## rather than in ten, and on this endpoint it may not be set to nothing at all.
const REASONING := {"effort": "low"}

## How long a call is given before it is called unanswered, in milliseconds, and
## how long the polling loop sleeps between looks. Neither is a simulation
## duration: no tick of any world is counted here.
const PATIENCE_MS := 60000
const REST_MS := 10


# --- Which endpoint, and which model --------------------------------------


## Where a call goes, worked out from the environment.
##
## Answers a dictionary and not a URL, because a call needs all of it: the host
## and port to open, whether to wrap the socket in TLS, the route to POST to,
## which model to ask for, and whether a `reasoning` field belongs in the body.
##
## `ok` is false when the environment says something that cannot be obeyed, with
## `why` saying what, and `fetch` then refuses the call rather than quietly going
## to the other endpoint instead. A mistyped address is a mistake and not a
## fallback: silently calling and billing the paid endpoint because a port number
## had a letter in it is the one behaviour nobody would want.
static func endpoint() -> Dictionary:
	return endpoint_named(
		OS.get_environment(ENDPOINT_VARIABLE).strip_edges(),
		OS.get_environment(MODEL_VARIABLE).strip_edges())


## The same decision, given what the environment says rather than reading it.
##
## Pure, and that is the point: the whole of where a call goes can be checked by
## a suite that sets nothing in its own environment, which is the only way it
## could be checked beside every other check rather than by hand.
static func endpoint_named(address: String, model: String) -> Dictionary:
	if address == "":
		return {
			"ok": true, "why": "", "local": false,
			"url": ENDPOINT, "host": HOST, "port": 443, "tls": true,
			"route": ROUTE, "model": MODEL, "reasoning": REASONING,
		}
	var parsed := address_of(address)
	if not parsed["ok"]:
		return _nowhere("%s is set to '%s', which %s" % [
			ENDPOINT_VARIABLE, address, parsed["why"],
		])
	if model == "":
		return _nowhere("%s names an endpoint but %s names no model" % [
			ENDPOINT_VARIABLE, MODEL_VARIABLE,
		])
	return {
		"ok": true, "why": "", "local": true,
		"url": address, "host": parsed["host"], "port": parsed["port"],
		"tls": parsed["tls"], "route": parsed["route"], "model": model,
		# No `reasoning` field, and its absence is as deliberate as its presence
		# above. It is the word the paid endpoint's API understands for "do not
		# think until the ceiling is spent", and a server on a loopback port
		# speaks its own dialect of the same request shape: a field it does not
		# know is ignored at best and answered with HTTP 400 at worst. The models
		# measured against a local endpoint here were chosen for having no
		# thinking to turn down in the first place.
		"reasoning": {},
	}


## A URL split into the four things opening a connection to it needs.
##
## Deliberately small: `http://` or `https://`, a host, an optional `:port`, and
## whatever is left as the route. That is the whole shape of an OpenAI-compatible
## chat endpoint, and a parser that accepted more would be accepting addresses
## this file then could not call.
static func address_of(address: String) -> Dictionary:
	var tls := false
	var rest := ""
	if address.begins_with("https://"):
		tls = true
		rest = address.substr(8)
	elif address.begins_with("http://"):
		rest = address.substr(7)
	else:
		return {"ok": false, "why": "does not begin with http:// or https://"}
	var slash := rest.find("/")
	var authority := rest if slash < 0 else rest.substr(0, slash)
	var route := "/" if slash < 0 else rest.substr(slash)
	if authority == "":
		return {"ok": false, "why": "names no host"}
	var host := authority
	var port := 443 if tls else 80
	var colon := authority.rfind(":")
	if colon >= 0:
		var written := authority.substr(colon + 1)
		if not written.is_valid_int():
			return {"ok": false, "why": "has '%s' where a port number should be" % written}
		host = authority.substr(0, colon)
		port = written.to_int()
		if host == "":
			return {"ok": false, "why": "names a port but no host"}
		if port <= 0 or port > 65535:
			return {"ok": false, "why": "names port %d, which is not a port" % port}
	return {"ok": true, "why": "", "host": host, "port": port, "tls": tls, "route": route}


# An endpoint no call can be made to, and the sentence saying why not.
static func _nowhere(why: String) -> Dictionary:
	return {
		"ok": false, "why": why, "local": true,
		"url": "", "host": "", "port": 0, "tls": false, "route": "",
		"model": "", "reasoning": {},
	}


## The recorded exchange, said to have been answered by whichever model is about
## to be asked live.
##
## A channel takes the model's name out of the exchange it is handed, because
## nothing under `sim/` may name a model or an endpoint. That is right for a
## replay and wrong for a live run, whose head would otherwise name the model the
## rows were recorded from rather than the one actually answering. So the entry
## point swaps the name in on the way past: it is the one place that knows both,
## and swapping it there keeps the simulation as ignorant of the second endpoint
## as it is of the first.
static func live_exchange(recorded: Dictionary) -> Dictionary:
	var said := recorded.duplicate()
	said["model"] = endpoint()["model"]
	return said


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
	# Where the calls go, worked out once and here rather than once per call and
	# on a worker thread. The environment cannot change under a run, and reading
	# it on the thread that builds the transport keeps every call of a run going
	# to the one endpoint the run said at its head that it was using.
	var where := endpoint()
	return func(prompt: String) -> Callable:
		var box := []
		var guard := Mutex.new()
		var thread := Thread.new()
		threads.append(thread)
		thread.start(func() -> void:
			var got := fetch(key, prompt, where)
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
	var where := endpoint()
	return func(prompt: String) -> Callable:
		var got := fetch(key, prompt, where)
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
			got = fetch(key, prompt, where)
			left -= 1
		return func() -> Dictionary:
			return got


# --- The credential -------------------------------------------------------


## The key for wherever the call is going, out of the environment and out of
## nowhere else.
##
## Nothing for a local endpoint, and that is a rule and not an omission: a key is
## a secret belonging to one service, and a machine with both a key set and a
## local endpoint named would otherwise hand that secret to a server on a
## loopback port that never asked for it.
static func key() -> String:
	if bool(endpoint()["local"]):
		return ""
	return OS.get_environment(KEY_VARIABLE).strip_edges()


## Whether a call could be made from here at all, and why not when it could not.
##
## Three answers rather than two, because there are two endpoints. An endpoint
## the environment named but garbled is refused outright and named in the
## sentence; a local endpoint needs no credential at all and says which model it
## will be asked for; and with the environment silent this is what it always was,
## a question about one key.
static func credentials() -> Dictionary:
	var where := endpoint()
	if not where["ok"]:
		return {"ok": false, "why": where["why"]}
	if where["local"]:
		return {"ok": true, "why": "%s names %s, asked for %s, and needs no key" % [
			ENDPOINT_VARIABLE, where["url"], where["model"],
		]}
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
static func fetch(key_value: String, prompt: String, where: Dictionary = {}) -> Dictionary:
	var going: Dictionary = endpoint() if where.is_empty() else where
	if not going["ok"]:
		return _nothing(0, String(going["why"]))
	var host := String(going["host"])
	var began := Time.get_ticks_msec()
	var http := HTTPClient.new()
	# TLS on the paid endpoint, none on a loopback one. `connect_to_host` takes
	# the options it should wrap the socket in, and no options is a plain socket.
	var wrapping: TLSOptions = TLSOptions.client() if bool(going["tls"]) else null
	if http.connect_to_host(host, int(going["port"]), wrapping) != OK:
		return _nothing(0, "could not open a connection to %s" % host)
	while http.get_status() == HTTPClient.STATUS_CONNECTING \
			or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(REST_MS)
		if Time.get_ticks_msec() - began > PATIENCE_MS:
			return _nothing(0, "connecting to %s timed out" % host)
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return _nothing(0, "no connection to %s (status %d)" % [host, http.get_status()])

	var asking := {
		"model": going["model"],
		"max_tokens": MAX_TOKENS,
		"temperature": TEMPERATURE,
		"messages": [{"role": "user", "content": prompt}],
	}
	# Only where the endpoint has one. See the note beside `reasoning` in
	# `endpoint_named`: it is this provider's word, and a server that does not
	# know it may refuse the whole call over it.
	var reasoning: Dictionary = going["reasoning"]
	if not reasoning.is_empty():
		asking["reasoning"] = reasoning
	var body := JSON.stringify(asking)
	var headers := ["Content-Type: application/json"]
	# A local endpoint wants no credential and is not given one. Sending an empty
	# bearer token to a server that does not want one is a way of being refused
	# for a reason that has nothing to do with the question.
	if key_value != "":
		headers.append("Authorization: Bearer %s" % key_value)
	if http.request(HTTPClient.METHOD_POST, String(going["route"]), headers, body) != OK:
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
