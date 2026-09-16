# The silence budget: what was enforced, and what it is now

The runner kills an engine that prints nothing for too long. Two things about
that were wrong, and the certifying full-suite run over seventy-three suites is
where both showed.

Everything below was measured on this machine -- 27.4 GiB, 32 processors, no
swap -- with the logs beside this file.

## 1. The budget the run printed was not the budget it enforced

The watchdog held a counter that rose by one for every `sleep 1` plus one
`stat`, and called that pair one second whatever it really cost.

One `./run_tests.sh runner_fixtures/stalling` per row, `RUN_TESTS_SILENCE=120`.
"Enforced" is read off the run's own memory recording: the stretch from the
last moment the transcript grew to the moment the engine went away.

| load on the machine | budget | enforced, counting turns | enforced, reading the clock |
|---|---|---|---|
| idle (engine 0.30 GiB, 21.3 GiB free) | 120 s | 121 s | 120 s |
| python holding 21.4 GiB, 0.64 GiB free | 120 s | 120 s | -- |
| engine holding 22.56 GiB, 1.44 GiB free | 120 s | 118 s | 120 s |
| 1200 runnable shells, load average 482 | 120 s | **162 s (+35%)** | **121 s** |

The suspect was memory, and the suspect was wrong. Holding this machine's
memory does not move the watchdog at all: a python process holding 21.4 GiB,
the same process churning fresh pages with 0.2 GiB free, twenty such processes
at once, and a real engine holding 22.56 GiB were each measured at 1.00-1.01
seconds per counted second. An engine asked for 25 GiB was killed by the kernel
within seconds (exit 137 -- the ending test_settlements had), so the state the
certifying run sat in for thirty-five minutes, free memory pinned at 0.00 GiB
while the machine still ran, cannot be held here deliberately.

What moves it is a machine that cannot get round to the loop. `tools/busy_load.sh`
puts 1200 runnable shells on the machine and takes them off again; under it the
budget stretched by 35%. That matches the field evidence: during test_settlements
the run's own two-second sampler stretched to 244 s per step.

The watchdog now stamps the clock when the transcript last grew, and the
transcript says what it measured beside what it was given:

    FAIL  test_terrain_lod stalled: printed nothing for 3600s, budget 3600s

`./run_runner_guard.sh` checks this twice, once idle and once with 1200
runnable shells on the machine, requiring each time that the silence reported
is at least the budget and no more than a tenth over it. The old watchdog fails
the second check by 35%.

## 2. The budget was 65 s above honest work, not four times it

1800 s was set from three suites, whose worst gap between checks was 455 s.
The certifying run measured all seventy-three. Among the **seventy that reached
a verdict**, the worst gap between checks is:

| suite | worst gap between checks |
|---|---|
| test_scatter | 1735 s |
| test_atmosphere | 1664 s |
| test_islands | 1658 s |
| test_grass | 1571 s |
| test_ui_panel | 1564 s |
| test_ui_territory | 1390 s |
| test_ui_readout | 1264 s |

So 1800 s stood 65 s -- 3.6% -- above honest work.

The budget is now **3600 s**, twice 1735 s rounded up to the hour. Two parts of
the same measurement justify that margin. The top of the list is a cluster and
not a spike -- five suites inside 11% of each other -- so 1735 s is the cost of
the heaviest work these suites do rather than one suite's bad luck. And
whatever a busy machine does to the watchdog it does to the work: the 35%
measured above takes 1735 s to about 2342 s, and test_window_glow's own worst
gap went from 1115 s alone to 1852 s inside the certifying run, a stretch of
1.66. The cost of being wrong the other way is one extra hour before a dead run
says so, against a sixteen-hour run.

**Where this measurement stops.** Three suites never reached a verdict in that
run, so their own honest gaps are unknown and none of the above is set from
them: test_terrain_lod and test_window_glow, killed at the old budget, and
test_settlements, which the kernel took at 23.15 GiB before any budget applied.
The last is a size problem and not a silence one -- no silence budget short of
never firing would have caught it.

## 3. Which of the two killed suites was actually stuck

Each run alone, on an idle machine, under the corrected budget.

    $ ./run_tests.sh test_window_glow            # RUN_TESTS_SILENCE unset: 3600 s

| | wall time | peak resident | worst gap | verdict |
|---|---|---|---|---|
| test_window_glow | 2255.7 s (37.6 min) | 11.53 GiB | 1115 s | `FAIL  window glow    2255.7 s, 20651 checks, 1 failed` |
| test_terrain_lod | 4733 s (78.8 min) | 10.62 GiB | 3600 s | `FAIL  test_terrain_lod stalled: printed nothing for 3600s, budget 3600s` |

**test_window_glow was merely slow.** Given the machine to itself it reaches a
real verdict -- 20651 checks, one of them failing, which is a suite's own
business and not the runner's. Its worst gap alone is 1115 s, comfortably under
the 1735 s worst honest gap; inside the certifying run the same gap measured
1852 s. Being killed for stalling was a wrong verdict, which is the one thing
this runner must not produce, and the corrected budget does not produce it.

**test_terrain_lod is not merely slow.** Alone, on an idle machine, with
nothing competing for anything, it completed 26 checks in its first 1130 s and
then nothing at all for 3600 s while its engine grew from 8.45 to 10.62 GiB.
Every suite that finishes does its longest uninterrupted piece of work in under
1735 s; this one exceeds twice that with the machine to itself. So the
corrected budget separates the two: one is inside honest work by a wide margin,
the other is outside it by a wider one. Whether the ground really costs that or
the suite is looping is a question about the suite, and it has its own item
(W-terrain-lod-silence).

## The files

| file | what it is |
|---|---|
| `drift-before-*.log` | the counting watchdog, at four loads |
| `drift-after-*.log` | the clock-reading watchdog, at the two that matter |
| `runner-guard.log` | `./run_runner_guard.sh` passing, including the stall check under load |
| `test_terrain_lod.log`, `test_window_glow.log` | each suite alone under the corrected budget |
| `*-memory.log` | the per-run recordings the numbers above are read from |

`tools/watchdog_fired_at.awk` reads a recording and prints the silence a run
actually enforced. `tools/busy_load.sh` and `tools/memory_load.py` are the
loads; `tests/runner_fixtures/stalling_heavy.gd` is a suite that goes silent
while holding a chosen amount of this machine inside the engine.
