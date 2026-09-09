# The suite told a lie, and what it took to earn a green run

This game is a small fantasy world that runs on a fixed clock, with the player as one character inside it rather than above it. Like anything of its size it is held together by automated tests, and this report is about the tests themselves — because for a stretch of this project's life they reported the wrong answer. A run in which a test crashed mid-way was printed as a run in which everything passed. That is worse than a broken test, because a broken test is noticed and a false pass is believed.

This page tells that story end to end: how the lie was found, what was changed in three places to end it, what the one apparent bug in the game's goal layer actually turned out to be, why the recorded conversation with a language model had to be made afresh, and what the game's own prompt now says about where a character is standing. It closes with the full run this milestone ends on, quoted with its exit status, and with what is still open.

**A few words used throughout.** A *suite* is one file of checks about one part of the game — movement, items, conversation. A *check* is one assertion inside it. The *runner* is what runs every suite in turn and prints a verdict: a shell script, `./run_tests.sh`, wrapped around a program running inside the game engine, `bin/test_main.gd`. A *SCRIPT ERROR* is the engine's own wording when a script hits a runtime error. An *exit status* is the number a command leaves behind when it ends — $0$ means success and anything else means failure. A *seeded run* is a run started from a fixed random number so that two machines produce identical bytes; a *tick* is one step of the world's clock, twenty a second; the *world fingerprint* is a digest of the whole world after $100$ ticks at seed $1234$, quoted on both sides of a change so that an accidental change to the simulation cannot hide.

## 1. The false pass, shown rather than described

The project keeps the log of its own full test runs. Here is one of them, `reports/ground-items-suite-evidence.txt`, recorded before any of this was known. Three lines from the same file, in the order they appear in it:

```
43: SCRIPT ERROR: Out of bounds get index '1' (on base: 'Array[Dictionary]')
              at: TestGoals._a_character_may_not_close_what_the_world_answers
                  (res://tests/test_goals.gd:320)

49: PASS  goals          129 checks

78: all 58 suites passed (201583 checks)
```

Exit status: $0$. A test crashed six lines above the runner calling it a pass, and thirty-five lines above the runner calling the whole run a success.

The reason is a property of this engine (Godot $4.7.2$), established by four probes rather than read out of a manual: **a runtime error abandons only the call frame it was raised in, and returns to that frame's caller, which carries on.** It does not unwind the stack and it does not end the process. So the crash killed the rest of that one test method and nothing else. The loop moved to the next method, the suite reported the checks it had managed — $129$, where the same suite prints $133$ today — and the run rolled on to a summary that was arithmetically correct and completely untrue.

One piece of received wisdom went with it. The milestone that opened this work was written up as *the runner hangs on the goals suite*. It never hung on that. Running `./run_tests.sh test_goals` under a $180$-second bound does get killed, but the suite is not stuck: it starts two child game engines that cost about $106$ seconds each, and finishes on its own in $5$ minutes $23$ seconds. A genuine hang did exist, and it was a different shape — an error raised in the runner's *own* frame, the one holding the loop, the summary and both exit calls. That one really did leave a process sitting idle forever.

The commit that ended the false pass is **`74a9855`**.

## 2. What the runner does now, and why its guard is in two pieces

The guard is deliberately split, because no single place can catch all three ways a suite can go wrong here.

*Inside the engine*, `bin/test_main.gd` now enters one suite per idle frame. It prints `RUN <name>` before the suite is even loaded and clears that name only when the suite returns — so a frame that never came back is reported by name on the next frame, and the run still reaches its summary and still exits non-zero. This is what catches the genuine hang, and it is also what makes an unfinished run say which suite it was in instead of requiring somebody to bisect a list of sixty-five by hand.

*Outside the engine*, `./run_tests.sh` takes the two shapes no in-engine guard can see. It fails any run whose output contains a `SCRIPT ERROR` line, blaming the suite named on the `RUN` line above it; and it kills a run that has printed nothing for `RUN_TESTS_SILENCE` seconds ($7200$ by default) and says which suite it was in. That wait measures *silence*, not total time, so an honest run of several hours is left alone.

The reason for the split is worth stating plainly, because it is a limit rather than a preference: this engine's scripting language gives a script no way to catch an error raised inside a call it made. The in-engine runner cannot be un-fooled. What the wrapper does is read the engine's own error text back and refuse to believe the summary.

An independent reviewer re-ran that rather than reading it, planting the exact shape of the original crash — a read one past the end of a list, inside a helper called below a test's entry point — into a throwaway suite in a byte-for-byte copy of the checkout:

```
$ ./run_tests.sh test_rng critic_fixtures/critic_throwing test_asset_tags
EXIT=1  elapsed=12s

RUN   critic_throwing
SCRIPT ERROR: Out of bounds get index '1' (on base: 'Array[Dictionary]')
          at: CriticThrowingFixture._reads_past_the_end (…critic_throwing.gd:20)
PASS  critic throw   2 checks
RUN   test_asset_tags
PASS  asset tags     1576 checks

all 3 suites passed (2903 checks)

run_tests: suite 'critic_throwing' raised a runtime error (SCRIPT ERROR above).
run_tests: the engine returned to the caller and the runner could not see it,
run_tests: so the run is failed here whatever the summary said.
```

The middle of that output is the instructive part. The engine still prints `PASS` for a suite that aborted mid-method, and the runner inside it still prints `all 3 suites passed`. Every word of the old lie is still there. What has changed is that the run now ends at $1$ instead of $0$, and says whose fault it was.

An error planted in the runner's own frame is bounded the same way: exit $1$ after $12$ seconds under a $300$-second limit, with the next suite still running and the summary still printed. The whole demonstration is left behind as a command anyone can run — `./run_runner_guard.sh`, seven checks, about $87$ seconds — rather than as a one-off.

## 3. The guard that was reading a file that no longer existed

The fix above had a hole underneath it, and it bit exactly the long runs nobody wants to repeat.

The runner wrote each run's *transcript* — its own copy of everything the engine printed — into a scratch file in whatever temporary directory the launching shell pointed at. A full run takes hours and outlives the automation cycle that started it, and that cycle's temporary directory is torn down when it ends. Nothing visible happens at the time: the file was unlinked while the engine still held it open, so the log fills to the very end and the summary prints as normal. What breaks is the closing check. Searching a path that no longer exists prints `No such file or directory` and ends at $2$, and the shell reads *any* non-zero result there as *no match found* — so the guard is silently skipped. The milestone's own false-pass shape, reopened by where a temporary file happened to live.

It was reproduced before it was fixed, on a three-second run, and the fix was then measured on both sides:

| the same short run, with a crash planted in it | exit status |
|---|---|
| pre-fix runner (`f17e074`), temp directory deleted $4$ s into an $11$ s run | $0$ — the false pass, reproduced |
| at `b55f766`, same deletion | $1$, naming the suite that threw |
| at `b55f766`, the run's own directory destroyed instead | $2$, naming the missing transcript |

The change, in one sentence: the transcript and the stall watchdog's flag now live in `.testruns/` beside the checkout being tested — a place that belongs to the run rather than to the shell that launched it — and before either closing check runs, both files must be present and readable, on the reasoning that *a check which could not be run is not a check that passed*. Commit **`b55f766`**. Two new permanent checks in `./run_runner_guard.sh` delete each file under a running run and require a non-zero exit and the naming message; the second drives the watchdog to a real kill rather than assuming it.

One further pre-fix behaviour surfaced by accident and was recorded rather than chased: with the temporary directory gone, the watchdog's own subshell failed before reaching its kill, so a genuinely stalling suite was never killed at all and the run hung indefinitely — worse than the false pass it was already causing. The fix removes the precondition for both.

## 4. The goal-layer "regression" that was a price, not a fault

The crash at `tests/test_goals.gd:320` was a read one past the end of a list of refusals: the test expected two refusals to have been written down and found one. That looked like the game's goal layer having quietly stopped refusing something. It had not.

What actually happens: some of the things a character can ask for cost the world no time at all — `recall`, `learn` and `done`. Those are *priced*. A character gets $2$ free such asks (`ToolBudget.FREE = 2`, `sim/tool_budget.gd:80`) between the turns it spends on actual actions, a rule added deliberately by commit `1a5ca1e` so that a mind cannot loop forever on a free ask. The third `done` in a row was therefore refused by the budget (`sim/model_mind.gd:307`) before it ever reached the goal layer, so the goal layer wrote nothing down — and the test read the second element of a one-element list.

This was settled by running the suite at each commit rather than by reading the difference between them: at `4dd81ef` the suite passes with $132$ checks and no error; at `1a5ca1e` it throws at line $320$ with $129$ checks. (The original guess at which commit was responsible was wrong, and the test file itself was never touched by the commit that broke it.)

**The decision was that the expectation was the wrong side.** The goal layer still refuses to close a goal that is not there and still writes that down with its own reason; a separate suite drives that directly and passes. What the test was relying on was three no-cost asks in a row all being carried out, which the design has not promised since `1a5ca1e`. Exempting `done` from the budget would have been redesigning the budget in order to keep an assertion. So the fix is in the test (commit **`3351e23`**): the character now spends a turn on an action first — which is how the world hands the free asks back, and the idiom the tool-budget suite already used — and one check was *added*, that the refusal the character receives is the goal layer's own `NO_SUCH_GOAL` rather than the budget's sentence. The test came out stronger than it went in: a budget swallowing this case again now fails by name instead of crashing out of bounds. The suite prints `PASS  goals          133 checks`, and the seed-$1234$ world fingerprint is unmoved at `32656f55cc5eeb1c`.

## 5. Why the recorded conversation had to be made again

`./run_tests.sh` needs no network connection and no paid key, because the questions the game's characters put to a language model were put once, for real, and the answers written down in `net/model_recording.gd`. A replaying channel answers the $n$-th question of a run with the $n$-th row of that table, which makes a test run a fact about the seed rather than a fact about what the machine happens to have installed.

Each row also keeps the first sixteen characters of a digest of the prompt that asked it — call it the *prompt fingerprint*. It is not used to look the answer up; it is there so that drift is *visible*: if the game starts asking different questions, the replay still answers in order but says in the transcript that the question it is answering is not the question that was recorded.

The trouble was that the packet of information sent with each question told the character where it was standing to three decimal places. Three decimals of a world unit is a millimetre. So any change to how anything moves changed every prompt, changed every fingerprint, and invalidated the whole recording. It happened twice in two days; after one movement change, $15$ of the run's $71$ questions still matched a recorded row and $56$ did not.

The work was scheduled on a premise — settle how position is stated first, so the *next* movement change does not break the recording again. **That premise was measured and it was false, and it was reported as false.** Re-derived across two checkouts, matching each question against the other tree's digests exactly as the game does, the collapse is $15$ of $71$ under three decimals, $15$ of $71$ under whole units, $15$ of $71$ under the coarse tactical cell, and $15$ of $71$ under any coarsening of the entity offsets, distances and movement trail. The ceiling was measured too: deleting the trail and the character's remembered lines gives $29$ of $71$, and replacing every number in the packet with a letter gives $48$ of $71$. No representation of position buys immunity. What *does* still invalidate a recording is now stated exactly: any change to how far a character has got by the time it is asked, because it then remembers a different number of things and different characters are asked at different moments.

The position line was settled anyway, on its own merits. The absolute frame stays, because the model demonstrably uses positions to choose positions — standing at $(-476, 422)$ it answers `go_to target=(-471, 416)` — and because that is the frame the action catalogue accepts. The three decimals go, because a millimetre is finer than anything else in the packet speaks in: the character's own memory speaks in whole metres, the trail in tenths, the ground in cells of three units, and the shortest move any action makes is a $0.9$ stride. Every digit printed there is a digit a fingerprint has to reproduce. The suite holds the new grain as a check: a shift of $0.4$ writes the same line, a walk of two units does not. Shipped, the line reads `at (-478, -2, 416)` where the earlier draw read `at (-478.000, -2.352, 416.000)`.

Then the exchange was re-recorded once, live, against the settled prompt: $83$ calls for the character, lesson and goal runs, plus $19$ and then $20$ for the trading table, $122$ calls in all, $101$ rows checked in, none empty, dated 2026-09-09.

**One disclosure belongs in the same breath.** The trading table that ships is the *second* draw. The first did not close the sale and failed six checks; the second was kept because those six passed. That is selection on the outcome of the test and it should be said in those words. Six checks in one method of that suite are claims about what one language-model draw happened to do; the rest of the suite — that the pack was shown, that the ask was built from the keyboard, that a proposal is denied in the engine's own words, that two replays print identical bytes — are claims about machinery and hold whatever the model says. The disclosure was also tested by its own author: replaying the *old* rows against the *new* packet, the sale still closes, so the coarsened packet is not what stopped the first draw. The independent review's verdict: believable for what the suite demonstrates about machinery, and those six checks should be read as a statement about one draw until they are split out.

Two things turned up that nobody was looking for. The script that checks the README's model-layer numbers had been aborting on its own internal assertion ever since two tables were added to it, so for four commits it had been checking nothing at all; it now counts the five tables it is about, all $48$ values are re-taken, and it was proved to be working by perturbation rather than by running it once — a one-digit change to a README number now fails it. And the conversation panel drawn over the new trading draw is $0.6715\%$ off the pixel grid where it has always been $0.0000\%$, because one of the model's lines contains an em dash the pixel font has no glyph for.

## 6. Four numbers an earlier edition of the published report got wrong

The published report page is regenerated from whatever report was published last, so a stale figure survives until somebody re-takes it. Four were flagged; all four are re-taken here off the current tree.

| the earlier edition said | what the tree says now |
|---|---|
| the shipped recording is $99$ replies dated 2026-09-04 | it has been re-made twice since. `RECORDED_ON` is 2026-09-09, the model is `z-ai/glm-5.3-flash`. That live pass wrote $101$ rows across four tables — the shipped character run $73$, lesson $4$, goal $4$, trading $20$ — and none is empty. The five tables the model page tracks together hold $95$; seven tables ship in all, $119$ rows. |
| four of the five orchestrator answers were `spawn role=scout at=(12.5, -4.0)` — the coordinate printed in the prompt's own line explaining how a position is written | true of the draws of 2026-09-03 and 2026-09-04, and no longer true of anything. That coordinate is printed in no prompt any model is sent. Every slot now names what fills it instead of showing a specimen — `(<x>, <z>)`, `#<id>`, `(<x from here>, <z from here>)` — and the copies fell to $0$ and have stayed at $0$ across three draws since. |
| all $49$ suites pass ($196{,}324$ checks) | `all 65 suites passed (204835 checks)` |
| open question: is copying a worked example out of the prompt what cheap models do? | no longer open. It was tested, confirmed, and the cause removed. |

That last one is worth the numbers, because it is the clearest result in this stretch of work. Four small models running locally were each asked every question of all five runs, before and after the change, and the measure is how many of their answered lines hand a placeholder straight back:

| model | answers before | copies that can only be copies | answers after | copies |
|---|---|---|---|---|
| qwen3.5:0.8b | $113$ | $108$ ($95.6\%$) | $84$ | $1$ ($1.2\%$) |
| nemotron-3-nano:4b | $49$ | $1$ ($2.0\%$) | $56$ | $1$ ($1.8\%$) |
| gemma3n:e2b | $115$ | $8$ ($7.0\%$) | $96$ | $0$ |
| gemma3n:e4b | $140$ | $80$ ($57.1\%$) | $125$ | $23$ ($18.4\%$) |

A fifth column is left out of that table deliberately and named instead: before the change, one of the specimens was `#7`, and in the shipped run `#7` is also a real character standing beside the asker, so $39$ and $63$ of those two middle rows' answers were not separable into copy or choice. After the change no model answers `#7` at all, and the one model still copying hands back `#<id>`, which the catalogue now refuses outright rather than silently resolving to whoever happens to be entity seven.

What it bought where it matters: replaying the world-running model's own answers, the five spawn attempts went from $14$ attempts and $0$ landing to $8$ attempts and $7$ landing. On the model that actually ships, the $10$ placeholder copies in the checked-in recording went to $0$, the turns the engine could resolve went from $61$ to $67$ of $69$, and the whole live pass cost $\$0.0108$.

The seed-$1234$ world fingerprint is `32656f55cc5eeb1c`, and it was unmoved on both sides of every change described on this page.

## 7. The run this milestone ends on

```
RUN   test_goals
PASS  goals          133 checks
…
all 65 suites passed (204835 checks)
```

$65$ `RUN` lines matched by $65$ `PASS` lines, zero `FAIL` lines, and zero occurrences of the string `SCRIPT ERROR` anywhere in the file. Exit status **$0$** — and that number is deliberately not quoted from the log, because it is not in the log; it comes from the job record the run was supervised by, which reads `note: exit code 0`. $65$ is every suite there is: the tests directory holds $66$ files matching the suite naming pattern and the extra one is the base class every suite extends.

Nothing else ran beside it. Across its window of 07:20:08 to 08:29:14 the only files modified anywhere are the log itself, its job record, and the automation's own bookkeeping for three cycles that started no game engine — and no commit landed inside that window, so the tree did not change underneath the run.

**And the one thing wrong with it, named rather than left for a reader to find: that run's own guard was dead.** It was launched before `b55f766`, it outlived the cycle that launched it, its transcript was deleted underneath it, and the last line of its log is the failed search that proves it — `grep: /tmp/lab-sbx-uw2643gp/tmp/tmp.gDlawHVH8V: No such file or directory`. Its closing check could not have failed it whatever the output held. That was settled by reproducing it, not by arguing it: the pre-fix runner with its temporary directory deleted mid-run exits $0$ on a run containing a planted crash, and its last line has exactly the same shape.

It is believable anyway, and for reasons anyone can check rather than on anyone's word. The captured log is complete and contains no error line of any kind, which is the same text the guard would have read. And two other full runs of the same day report the identical $65$ suites and $204{,}835$ checks with live guards. The hole itself is closed in both directions at the current commit, as the table in section 3 shows.

## Verified facts

- On this engine a runtime error abandons only the frame it was raised in; the caller resumes. Established by four probes, and by the project's own historical log in which a crashed suite is reported as `PASS` inside a run reported as a success at exit $0$.
- The runner cannot catch a crash inside a suite from within the engine. What fails such a run is the shell wrapper reading the engine's printed error text back — demonstrated by planting the original crash's exact shape and watching the engine print `PASS` and `all 3 suites passed` while the run ends at $1$.
- A closing check that reads a file which has been deleted underneath it reports *no match*, not *failure*. Reproduced at exit $0$ before the fix; exit $1$ and exit $2$ after it, in the two ways the file can go missing.
- The third free ask in a row is refused by the tool budget before it reaches the goal layer. Bisected by running the suite at two commits, not by reading their difference.
- No representation of a character's position saves a recorded exchange from a movement change. Measured across two checkouts under six schemes; the collapse is $15$ of $71$ under every one of them, against a measured ceiling of $48$ of $71$ with every number in the packet replaced by a letter.
- Showing a worked example inside a prompt's placeholder causes small models to hand it straight back — up to $95.6\%$ of answered lines — and removing it drops that to at most $18.4\%$, with the world-running model's spawn attempts going from $0$ of $14$ landing to $7$ of $8$.
- The certifying full run is `all 65 suites passed (204835 checks)`, exit $0$, with no error line in it — and its own guard was inert, corroborated instead by two other full runs of the same day carrying identical figures.
- The seed-$1234$ world fingerprint `32656f55cc5eeb1c` did not move across any change described here.

## Hypotheses

- That launching the child game engines under a time limit would turn a two-hour silence into a named failing check in seconds. The shape is measured — a child of that kind was shown still alive at $30$ seconds after a crash — and every suite already asserts that its child ended cleanly, so the change looks cheap. But it has not been done or measured end to end in a real suite.
- That the six end-to-end trading checks would pass on a freshly drawn conversation. Unknown, and honestly unknowable without spending the draw. What *is* measured is only that the previous set of recorded answers also closes the sale against the new packet, which rules out one explanation and not the general question.

## Decisions, each with its reason

- **The guard is split between the engine and the shell.** Because the engine's scripting language cannot catch an error raised inside a call it made, so an inner guard can only cover the runner's own frame and an outer one has to read the engine's error text back. Both shapes exist; each is answered where it can be.
- **The transcript lives beside the checkout, and a transcript that cannot be read fails the run.** Because a file in the launching shell's temporary directory does not survive a run that outlives the cycle that launched it, and because a check that could not be run is not a check that passed.
- **The goal test was changed, not the goal layer.** Because pricing `recall`, `learn` and `done` alike was a deliberate rule against a mind looping on a free ask forever, and exempting one of them to keep an assertion would be redesigning the budget to suit a test.
- **A character's own position is stated in whole world units, in the absolute frame.** The frame stays because the model demonstrably uses positions to choose positions and the action catalogue takes them. The decimals go because a millimetre is finer than anything else in the packet, and every digit is a digit a prompt fingerprint must reproduce — even though it was measured, and reported, that this buys no immunity from movement changes.
- **Every placeholder names its slot in angle brackets and shows no specimen value.** Because a specimen is a thing a model can copy, and it copied it.
- **The second trading draw was kept, and the fact that it was chosen because it passed is disclosed in the sharpest available words** rather than buried, together with a control experiment showing what did *not* cause the first draw to fail.

## What is still open

- **Six checks that turn on one draw.** The six end-to-end trading checks are claims about what one language-model reply happened to do, sitting in a suite otherwise full of claims about machinery. Until they are split apart, a green run means less for those six than for the rest.
- **The "waited on forever" complaint survives one level down.** Thirty-four of the sixty-five suites start a second game engine, at $40$ call sites. Those children are exactly the shape the old runner had, so a crash inside one never exits. The run then goes silent and is ended by the wrapper's watchdog — bounded and reported, never a false pass, which is the property this work was after, but at up to two hours a time.
- **The engine-side runner is still fooled, by construction.** Everything now rests on the crash text reaching the wrapper's output. That is a single point of trust, and it is a deliberate one rather than an oversight.
- **A green run recorded before `74a9855` is not evidence.** Any full run from before that commit may be a false pass and should not be quoted as though it were a pass.
- **A cosmetic defect from the new draw.** The conversation panel is $0.6715\%$ off the pixel grid where it has always been exactly on it, because one recorded line contains an em dash the pixel font has no glyph for.
- **The milestone's next step is playing it** — each component judged from the built game, and then the whole thing in one run.
