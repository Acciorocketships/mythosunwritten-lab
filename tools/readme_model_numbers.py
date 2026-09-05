#!/usr/bin/env python3
"""Read the README's model-layer numbers back out of the artifacts that hold them.

Nothing here is a copy of what the README says: every expected value is derived
from a checked-in transcript or from `net/model_recording.gd` itself, and the
check is that the derived value appears in README.md. A re-recording moves these
numbers, so this is the thing that fails when the prose is left behind.

    python3 tools/readme_model_numbers.py        # or tools/readme_model_numbers.sh
"""

import pathlib
import re
import statistics
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
README = (ROOT / "README.md").read_text(encoding="utf-8")
# compared with runs of whitespace collapsed, so re-wrapping a paragraph is not a
# failure and a changed number is
FLAT = " ".join(README.split())

failures: list[str] = []
checked = 0

ONES = [
    "zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
    "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
    "sixteen", "seventeen", "eighteen", "nineteen",
]
TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy",
        "eighty", "ninety"]


def spell(n: int) -> str:
    """The English for a small whole number, so a count can be checked in prose."""
    if n < 20:
        return ONES[n]
    if n < 100:
        return TENS[n // 10] + ("-" + ONES[n % 10] if n % 10 else "")
    if n < 1000:
        rest = n % 100
        head = ONES[n // 100] + " hundred"
        return head + (" and " + spell(rest) if rest else "")
    raise ValueError(n)


def want(label: str, fragment: str) -> None:
    """Require one derived fragment to appear in README.md."""
    global checked
    checked += 1
    if " ".join(fragment.split()) not in FLAT:
        failures.append("%s\n    looked for: %r" % (label, fragment))


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


# ---------------------------------------------------------------- the recording

recording = read("net/model_recording.gd")


def rows_of(name: str) -> list[str]:
    body = re.search(r"^const %s := \[\n(.*?)^\]" % name, recording, re.S | re.M).group(1)
    return [line for line in body.split("\n") if line.strip().startswith("{")]


cast_rows = len(rows_of("ROWS")) + len(rows_of("LESSON_ROWS")) + len(rows_of("GOAL_ROWS"))
check_rows = len(rows_of("CHECK_ROWS"))
world_rows = len(rows_of("WORLD_ROWS"))
all_rows = cast_rows + check_rows + world_rows
ms = sorted(int(x) for x in re.findall(r'"ms"\s*:\s*(\d+)', recording))
assert len(ms) == all_rows, "every row carries a millisecond column"
median_s = statistics.median(ms) / 1000.0
recorded_on = re.search(r'^const RECORDED_ON := "([^"]+)"', recording, re.M).group(1)

want(
    "the row breakdown, from the five const tables of net/model_recording.gd",
    "The %d replies of the\nfirst three, the %d of the difficulty-class run and the %d of the orchestrator run"
    % (cast_rows, check_rows, world_rows),
)
want("the recording date, from RECORDED_ON", "once, on %s,\nand are checked in verbatim" % recorded_on)
want(
    "the row count, spelled, in the passage about declined answers",
    "**Not one of the %s was declined" % spell(all_rows).replace("one hundred", "hundred"),
)
want(
    "the row count, spelled, in the timing sentence",
    "Those %s calls took a" % spell(all_rows).replace("one hundred", "hundred"),
)
want(
    "median, fastest and slowest, from the recording's own millisecond column",
    "median of **%g seconds** each — %g at the fastest, %g at the slowest"
    % (median_s, ms[0] / 1000.0, ms[-1] / 1000.0),
)
want(
    "the sample cloud provenance line, as the run prints it",
    "recorded %s from %s at %s, %d replies"
    % (
        recorded_on,
        re.search(r'^const MODEL := "([^"]+)"', recording, re.M).group(1),
        re.search(r'^const ENDPOINT := "([^"]+)"', recording, re.M).group(1),
        cast_rows,
    ),
)

# --------------------------------------------- the two controlled comparisons


def arms(rel: str) -> list[tuple[str, str, str]]:
    """Each arm of a one-moment comparison: its name, the reply, the action read back."""
    return [
        (name, said.strip(), chose.strip())
        for name, said, chose in re.findall(
            r"^arm: (.+?) -- prompt \w+.*?the model said:\s+(.+?)\n"
            r"\s+which read back as: (.+?)$",
            read(rel),
            re.S | re.M,
        )
    ]


for rel, kind in (("reports/lesson-evidence.txt", "lesson"), ("reports/goal-evidence.txt", "goal")):
    for name, said, chose in arms(rel):
        # a tool answers nothing readable, so the arm is checked by the reply itself
        want("%s arm %r, from %s" % (kind, name, rel), "`%s`" % (said if "readable" in chose else chose))

# ------------------------------------------------------------- the cast run

cast = read("reports/agent-evidence.txt")

total = re.search(r"^  total\s+(\d+)\s+(\d+)\s*$", cast, re.M)
calls = int(total.group(1))
ticks = int(re.search(r"ticks=(\d+)", cast).group(1))
a_tick = float(re.search(r"160 ticks, \d+ calls -> ([\d.]+) calls a tick", cast).group(1))
an_hour = int(re.search(r"(\d+) calls an hour for 5 characters, (\d+) each", cast).group(1))
each = int(re.search(r"(\d+) calls an hour for 5 characters, (\d+) each", cast).group(2))

want("model calls and the rate, from the run's own total row", "%d model calls over\n%d ticks — %s a tick" % (calls, ticks, a_tick))
want(
    "calls an hour, as the run computes it",
    "**{:,} calls an hour for five\ncharacters, about {:,} each**".format(an_hour, each),
)

asks = re.search(
    r"^  total\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+[\d.]+\s*$", cast, re.M
)
asked, ask_calls, held, polled, reevals = (int(g) for g in asks.groups())
share = re.search(r"asks that cost a call\s+\d+ of \d+ \(([\d.]+)%\)", cast).group(1)

want("asks, from the run's ask table", "Of %d asks across the five" % asked)
want("asks that cost a call", "minds, %d put a question (%s%%): %d were answered out of the choice the mind was" % (ask_calls, share, held))
want("polls and re-evaluations", "and %d were polls of a\nquestion already outstanding. %d mid-action re-evaluations against %d calls." % (polled, reevals, calls))

resolutions = len(re.findall(r"^t=.* -> ", cast, re.M))
refusals = len(re.findall(r"^t=.* -> [a-z_]+ refused:", cast, re.M))
want(
    "refusals against resolutions, counted off the transcript's own lines",
    "%s of the run's %s resolutions are refusals"
    % (spell(refusals).capitalize(), spell(resolutions)),
)

pending = int(re.search(r"ticks with more than one answer outstanding\s+(\d+) of \d+", cast).group(1))
want("ticks with more than one answer outstanding", "%d of the\nrun's %d ticks had more than one question pending" % (pending, ticks))

span = re.search(r"the longest span, by how many other answers were outstanding across it\n\s+(.*)", cast).group(1)
span = " ".join(span.split())
want("the no-serialising line", "`%s`" % span)

# --------------------------------------------------------- the memory readout

held_chars = int(re.search(r"^  characters held\s+(\d+)", cast, re.M).group(1))
entries = int(re.search(r"^  entries\s+(\d+) \(", cast, re.M).group(1))
packet = re.search(r"characters a packet carries (\d+) of \d+ \((\d+)%\)", cast)
question = re.search(r"the last question put\s+(\d+) characters, of which (\d+) \((\d+)%\)", cast)

want(
    "what the run's own memory readout holds",
    "hold **%d things in %s\ncharacters**, of which a packet carries **%d (%s%%)**"
    % (entries, "{:,}".format(held_chars), int(packet.group(1)), packet.group(2)),
)
want(
    "the memory block in the last question",
    "The last question put was {:,}\ncharacters, **{:,} of them ({}%)**".format(
        int(question.group(1)), int(question.group(2)), question.group(3)
    ),
)

table = re.findall(r"^  (\w+)\s+a (person|model)\s+(\d+)\s+(\d+)\s+\d+\s+\d+\s", cast, re.M)
person = [int(r[2]) for r in table if r[1] == "person"]
models = [int(r[2]) for r in table if r[1] == "model"]
want(
    "person against models, from the run's memory table",
    "ends with **%d\nremembered events**, against %d to %d for the five whose minds are models"
    % (person[0], min(models), max(models)),
)

# ------------------------------------------------------- the difficulty class

checks = read("reports/check-evidence.txt")
block = re.search(r"^the checks\n(.*?)\n\nwhat it cost", checks, re.S | re.M).group(1)
rows = []
for line in block.split("\n")[1:]:
    if re.match(r"^  \d ", line):
        t = line.split()
        # the tail is fixed width; the context in the middle carries spaces
        rows.append(
            [t[0], " ".join(t[1:-7]), t[-7], t[-6], t[-5], t[-4], t[-3], t[-2], t[-1], ""]
        )
    elif rows and line.strip().startswith("did"):
        rows[-1][-1] = re.search(r"did\s+(\S+\s+target=#\d+)", line).group(1)
assert len(rows) == 4, "four checks, each with the operation it earned"

for n, ctx, by, abil, score, roll, tot, dc, verdict, did in rows:
    arithmetic = (
        "%s %s + roll %s = %s vs dc %s" % (abil, score, roll, tot, dc)
        if by == "rolled"
        else "the same, reused"
    )
    settled = "rolled" if by == "rolled" else "**remembered**"
    want(
        "difficulty-class row %s, from reports/check-evidence.txt" % n,
        "| %s | `%s` | %s | %s | %s → `%s` |" % (n, ctx, settled, arithmetic, verdict, did),
    )

check_calls = int(re.search(r"^  calls\s+(\d+) put to a model", checks, re.M).group(1))
raised = int(re.search(r"^  checks\s+(\d+) raised", checks, re.M).group(1))
rolls = int(re.search(r"^  rolls\s+(\d+) rolled", checks, re.M).group(1))
want(
    "checks against model calls and rolls",
    "**%s checks, %s model calls, %s rolls.**"
    % (spell(raised).capitalize(), spell(check_calls), spell(rolls)),
)
want("the recording's own length for that run", "The recording is %s rows long" % spell(check_rows))

# ------------------------------------------------- what the world records

# README quotes only some of the run's edges; every row it does quote must be one
edges = {" ".join(l.split()) for l in cast.split("\n") if re.match(r"^  \w+\s+a (person|model)\s", l)}
quoted = re.search(
    r"```\nwho    driven by with.*?\n(.*?)```", README, re.S
).group(1).strip().split("\n")
for row in quoted:
    checked += 1
    if " ".join(row.split()) not in edges:
        failures.append("an edge README quotes is not in the run's table\n    quoted: %r" % row)

# the resolving prompt's own operations table, as the transcript prints it
resolving = re.search(
    r"You may name only these operations; anything else changes nothing:\n((?:    \S.*\n)+)", checks
).group(1)
for line in resolving.strip().split("\n"):
    want("an operation the resolving prompt offers", line.strip())

# ------------------------------------------------------------ the orchestrator

world = read("reports/world-evidence.txt")
named, carried = re.search(r"^  operations\s+(\d+) named, (\d+) carried out", world, re.M).groups()
looks = int(re.search(r"^  looks\s+(\d+) taken", world, re.M).group(1))
spawns = int(re.search(r"^  spawns\s+(\d+),", world, re.M).group(1))
want(
    "operations named against carried out",
    "Of the %s operations the\nrun's %s looks named, the engine carried out %s and refused %s"
    % (spell(int(named)), spell(looks), spell(int(carried)), spell(int(named) - int(carried))),
)
want(
    "the run_world.sh line",
    "# %s looks, %s spawns, %s operations" % (spell(looks), spell(spawns), spell(int(named))),
)
for reason in re.findall(r"^  would not \S+ target=#\d+\s+(.+?)\s*$", world, re.M):
    want("a refusal sentence, in the engine's own words", '*"%s"*' % reason)

# the charming fool: the spawn whose charisma is highest and wisdom lowest
fool = re.search(
    r"^  #(\d+)  a herald.*?\n      1\. rolled on tick (\d+).*?\n         (str .*?)\n"
    r"         highest cha, lowest wis.*?\n.*?answered on tick (\d+)\n"
    r"         name        (.+?)\n",
    world,
    re.S | re.M,
)
want(
    "the spawn example, from reports/world-evidence.txt",
    "rolled at tick %s   %s" % (fool.group(2), " ".join(fool.group(3).split())),
)
want("who those numbers were answered as", "answered at tick %s name        %s" % (fool.group(4), fool.group(5)))

# when the lantern left the market pile, which is why Pell never got it
lantern = re.search(r"^t=\s*(\d+)\s+Wren\s+began pick_up\(item=brass lantern\)", cast, re.M).group(1)
want("the tick the lantern was taken", "out of the market pile at tick %s and offers" % lantern)
want("the same tick, where the goal section tells it", "out of the market pile at tick %s and the pile" % lantern)

# --------------------------------------------------------------------- verdict

if failures:
    print("readme model numbers: %d of %d checks FAILED\n" % (len(failures), checked))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("readme model numbers: %d checks OK -- README.md agrees with the transcripts" % checked)
