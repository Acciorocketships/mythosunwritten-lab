# Evidence: §8.4's board table regenerated from its own artifact

What this file holds: the commands that were run to establish that
`reports/mountain-survey-1234.txt` is current, the six rows §8.4 now prints and
where each comes from, the check of every *other* table in `reports/mountains.md`
against the same artifact, and the two things that had to stay put — no file
under `sim/` or `render/`, and the headless world fingerprint.

Nothing in the world was changed by this work. The whole change is prose, one
table and one screenshot in `reports/mountains.md`.

## 1. The artifact re-runs identically

```
./tools/measure_mountains.sh > /tmp/survey-rerun.txt
diff reports/mountain-survey-1234.txt /tmp/survey-rerun.txt
```

The diff is one line long, and it is the allowed one — the published file was
made with `--trace`, which adds a line naming the route file it wrote:

```
57d56
< climb trace reports/assets/climb-1234.txt points=131
```

91 published lines against 90 re-run lines, every other line identical, so the
survey is the current output of the tool and the table was the stale half. (This
is the second independent re-run: `reports/review/survey-rerun-1234.txt` is the
review's, from `W-mountain-review`, and it agrees line for line.)

## 2. The six rows, before and after

Left is what §8.4 used to print; right is the artifact line it claims to come
from. Only the first row was ever right.

| board | §8.4 before | `mountain-survey-1234.txt` (now printed) |
|---|---|---|
| summit-1, top | 0 holes, 3 cliff edges, 10 refused (0.6%) | 0, 3, 10 (0.6%) — agreed already |
| summit-3, top | 0 holes, 1 cliff edge, 0 refused (0.0%) | **0, 148, 145 (8.6%)** |
| summit-8, top | 0 holes, 18 cliff edges, 11 refused (0.7%) | **0, 0, 0 (0.0%)** |
| summit-1, flank | 0 holes, 158 cliff edges, 252 refused (15.0%) | **0, 178, 287 (17.1%)** |
| summit-8, flank | **1 hole**, 281 cliff edges, 417 refused (24.9%), 1 672 steps | **0 holes, 149, 236 (14.0%), 1 680 steps** |
| summit-3, flank | 0 holes, 339 cliff edges, 587 refused (34.9%) | **0, 345, 576 (34.3%)** |

Every one of the 16 board lines in the survey — a top and a flank on each of the
eight summits — reads `holes=0`, so the holes column is 0 on every row of the
table and the section's leading claim ("a face is a wall, not a hole") is the
whole survey rather than a sample of it.

## 3. The conclusion that had to be restated

§8.4 used to conclude "A fight on a summit is a fight on an ordinary open
board". That is false of summit-3's top once the artifact's numbers are in:
148 of its 441 cells (34%) are cliff edges and 145 of its 1 680 steps (8.6%) are
refused. It is now stated as a summit board being open where the top is broad
and a ledge with a rim where the top is a crest, with all three tops given.

The rest of the paragraph was re-checked quantity by quantity against the
regenerated rows:

| quantity in the old paragraph | true of the new rows? | what it says now |
|---|---|---|
| "a third of the moves between neighbouring cells are illegal" | only of summit-3's flank (34.3%); the others are 17.1% and 14.0% | "14.0% to 34.3% of the moves" |
| "three quarters of the cells are cliff edges" | only of summit-3's flank (345/441 = 78%); the others are 178/441 = 40% and 149/441 = 34% | "34% to 78% of the cells are cliff edges (149, 178 and 345 of 441)" |
| "the lanes that do exist run along the contour rather than up it" | qualitative, unchanged | unchanged |
| the Frog paragraph | qualitative, unchanged | unchanged |

## 4. The picture

The caption named `(103, 106)` "the steepest cell within reach of summit-3",
where the survey lays summit-3's flank board at `(98, 104)` (and summit-4's at
`(101, 107)`), so the frame was re-captured at the artifact's own position:

```
xvfb-run -a tools/godot/godot4 --path . -- --seed 1234 --paused --start 98 104 \
  --board --camera 0 30 42 --aim 3 \
  --screenshot reports/assets/mountain-board.png --screenshot-frame 90
```

The render shell's own last line reports the board it drew, and it is the
artifact's board: `board=441/0` — 441 cells, 0 holes.

## 5. Every other table in the report, against the same artifact

53 mechanical checks, all passing: §2's relief row, all eight climbs of §3, all
eight faces of §4, the *after* column of all thirteen windows in §5, §5's uplift
shares and mask mean, all five biome rows of §6, the six regenerated rows of
§8.4, the holes-are-zero-everywhere property, and the absence of each stale
figure and of the old capture position from the report.

Four sets of numbers in the report do not come from this artifact and were not
checked against it, which is stated rather than glossed: §2's and §5's *before*
columns (a run made before the field existed), §7's fingerprints
(`./run_headless.sh`), §8.1's village counts (`tests/bench_settlements.gd`) and
§8.3's water figures. So this was one stale table, not a pattern.

## 6. How it came to differ: not established

The six rows and the old caption's `(103, 106)` agree with each other, so they
came from one earlier run of this same tool rather than from six separate
mistakes. Which run cannot be recovered: the repository holds a single commit
("Initial commit (created by lab)"), so there is no history of either the report
or the tool, and §7 of the report records that the ground moved twice while the
task was being written (`a6aa8e5776ebfe8c` → `33985caf0a411dd7` →
`d4e31b0904ff45c0`). Establishing which of those states produced the rows would
mean reverting `sim/` to an intermediate state, which this task is not allowed to
do. It is stated as unknown in §8.4.

One related stale quotation is recorded rather than edited here, because it is
outside this task's section: the `W-mountain-uplift` result text carries the same
old figures ("up to 34.9% of moves illegal and 339 of 441 cells shove-off edges
on a flank, against 0-0.7% on a summit"). The last clause is the one the artifact
contradicts — summit-3's *top* refuses 8.6%.

## 7. The world did not move

```
find sim render -type f | sort | xargs md5sum      # before and after: identical, 135 files
./run_headless.sh --seed 1234 --ticks 100 | tail -1
done ticks=100 chunks=41 built=69 final=d4e31b0904ff45c0
```

`d4e31b0904ff45c0` is the fingerprint §7 of the report already publishes, so the
world is where the mountains task left it. No mutation harness was running at any
point (`pgrep -af mutations.sh` was empty before the render capture and before
the headless run), so nothing was editing `sim/` in place while these ran.
