#!/usr/bin/env python3
"""Enumerate every suite in tests/ that asks the ground about a position inside a loop.

Why this exists
---------------
The four suites that went quiet for more than 1500 s in the certifying run were
named from a transcript, not from the code. A transcript names the suites that
were slow *in that run*; it cannot say which suites sample the ground at
scattered positions, and a spot check of four files cannot either. This walks
every suite instead, so the list is an enumeration with a stated rule rather
than a guess.

The rule, in two parts
----------------------
1. *What counts as asking the ground.* Every function declared anywhere under
   sim/ or scripts/terrain/ whose first two parameters are a float x and a
   float z -- i.e. every query whose answer is about one position in the world.
   The set is read off the source at run time, so it cannot drift from it.
   `AdoptedGround.water_column` and friends are found this way, not listed.
2. *What counts as a sweep.* A call to one of those, textually inside at least
   one `for`/`while` in the same function, found by indentation. The loop
   headers enclosing it are reported, so how many positions and over how wide a
   square can be read off the report and checked by hand.

Usage:  python3 tools/ground_sweep_census.py [--tests tests] [--quiet]
Output: one block per suite, then a summary line. Exit status is always 0;
        this reports, it does not judge.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

FUNC = re.compile(r"^\s*(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\((.*)$")
LOOP = re.compile(r"^(\s*)(for|while)\b(.*)$")
CALL = re.compile(r"[.\s(]([A-Za-z_][A-Za-z0-9_]*)\s*\(")


def position_queries(roots: list[pathlib.Path]) -> dict[str, str]:
    """Name -> where declared, for every func whose first two params are x, z floats."""
    found: dict[str, str] = {}
    for root in roots:
        if not root.exists():
            continue
        for path in sorted(root.rglob("*.gd")):
            text = path.read_text(encoding="utf-8", errors="replace")
            lines = text.split("\n")
            for i, line in enumerate(lines):
                m = FUNC.match(line)
                if not m:
                    continue
                name, rest = m.group(1), m.group(2)
                # A signature can wrap; gather until the parens close.
                depth = 1 + rest.count("(") - rest.count(")")
                j = i
                sig = rest
                while depth > 0 and j + 1 < len(lines):
                    j += 1
                    sig += " " + lines[j].strip()
                    depth += lines[j].count("(") - lines[j].count(")")
                sig = sig.split(")")[0]
                params = [p.strip() for p in sig.split(",") if p.strip()]
                if len(params) < 2:
                    continue
                first, second = params[0], params[1]
                if re.match(r"^x\s*:\s*float", first) and re.match(r"^z\s*:\s*float", second):
                    found.setdefault(name, f"{path}:{i + 1}")
    return found


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip("\t "))


def args_of(code: str, name: str) -> list[str]:
    """The first two arguments of `name(...)` in this line, as written."""
    at = code.find(name + "(")
    if at < 0:
        at = code.find(name + " (")
        if at < 0:
            return []
    i = code.index("(", at)
    depth, start, out = 0, i + 1, []
    for j in range(i, len(code)):
        c = code[j]
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
            if depth == 0:
                out.append(code[start:j].strip())
                break
        elif c == "," and depth == 1:
            out.append(code[start:j].strip())
            start = j + 1
    return [a for a in out if a][:2]


def defs_of(lines: list[str], upto: int, ident: str) -> str:
    """The nearest `var ident :=` above line `upto`, as written."""
    if not re.match(r"^[A-Za-z_][A-Za-z0-9_.]*$", ident):
        return ""
    bare = ident.split(".")[0]
    pattern = re.compile(r"^\s*var\s+" + re.escape(bare) + r"\s*(:=|:)")
    for k in range(upto - 2, -1, -1):
        # Never past the head of the function the call is in: a `var x` in some
        # other function is not where this position came from.
        if FUNC.match(lines[k]):
            return ""
        if pattern.match(lines[k]):
            return "%d: %s" % (k + 1, lines[k].strip()[:88])
    return ""


def sweeps(path: pathlib.Path, names: dict[str, str]) -> list[dict]:
    """Every position query inside a loop in this file, with its enclosing loops."""
    lines = path.read_text(encoding="utf-8", errors="replace").split("\n")
    stack: list[tuple[int, int, str]] = []  # (indent, line no, header text)
    out: list[dict] = []
    for i, raw in enumerate(lines):
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        ind = indent_of(raw)
        while stack and ind <= stack[-1][0]:
            stack.pop()
        m = LOOP.match(raw)
        if m:
            stack.append((ind, i + 1, raw.strip()))
            continue
        if not stack:
            continue
        # A comment tail is not code.
        code = raw.split("#")[0]
        # A name alone is not a position query: BiomeCatalog.profile(id) and
        # TerrainQuery.profile_at(x, z) share a stem, and Vector2.distance_to
        # takes a vector. A hit has to be called with two arguments, which is
        # what a position is.
        hits = sorted({n for n in CALL.findall(code) if n in names
                       and len(args_of(code, n)) == 2})
        if hits:
            where = []
            for arg in args_of(code, hits[0]):
                got = defs_of(lines, i + 1, arg)
                if got:
                    where.append(got)
            out.append({
                "line": i + 1,
                "text": code.strip(),
                "calls": hits,
                "loops": list(stack),
                "where": where,
            })
    return out


BLOCK_WORLD = 192.0

STRIDE = re.compile(r"(?:float\(\s*)?([A-Za-z_][A-Za-z0-9_]*)\s*\)?\s*\*\s*([0-9]+(?:\.[0-9]+)?)")
NUMBER = re.compile(r"-?[0-9]+(?:\.[0-9]+)?")


def classify(hit: dict) -> tuple[str, float]:
    """How far apart consecutive samples of this sweep are, and why.

    Returns (reason, step in world units; -1 where it cannot be read off the
    source). A step above BLOCK_WORLD means every sample lands in a block the
    one before it did not touch, which is the cost this census is looking for.
    """
    where = " ; ".join(hit["where"])
    text = hit["text"] + " " + where
    if re.search(r"randf|randi|\brng\b|hash", text):
        return "randomised position", 1e9
    if "%" in where:
        return "modular stride (deliberately scattered)", 1e9
    inner = hit["loops"][-1][2] if hit["loops"] else ""
    var = ""
    m = re.match(r"for\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\b", inner)
    if m:
        var = m.group(1)
    if not where:
        # The position is not a local variable: it is a member of whatever the
        # loop walks (an item, a village, an island). Those are as far apart as
        # the collection is, which this cannot read off the source.
        return "position comes from the collection walked", -1.0
    if var:
        for line in hit["where"]:
            for ident, factor in STRIDE.findall(line):
                if ident == var:
                    return "grid, stride %.0f u" % float(factor), float(factor)
        if var not in where:
            return "position does not move with the innermost loop", 0.0
    return "position read off the source, stride not stated", -1.0


def registered_suites(runner: pathlib.Path) -> set[str]:
    """The suites a run actually runs: the SUITES list in bin/test_main.gd.

    tests/ holds far more test_*.gd files than a run enters -- the adopted base
    brought its own -- and a suite the runner never names cannot be one of the
    suites that went quiet. This is what "surviving suite" means here, read off
    the runner rather than assumed.
    """
    if not runner.exists():
        return set()
    text = runner.read_text(encoding="utf-8", errors="replace")
    block = text.split("const SUITES := [", 1)
    if len(block) < 2:
        return set()
    return set(re.findall(r'res://(tests/test_[a-z0-9_]+\.gd)', block[1].split("]", 1)[0]))


def suite_costs(log: pathlib.Path) -> dict[str, tuple[float, str]]:
    """suite_name -> (wall seconds, verdict) from a run transcript's PASS/FAIL lines."""
    out: dict[str, tuple[float, str]] = {}
    if not log.exists():
        return out
    for line in log.read_text(encoding="utf-8", errors="replace").split("\n"):
        m = re.match(r"^(PASS|FAIL)\s\s(.{14})\s+([0-9.]+) s, ", line)
        if m:
            out[m.group(2).strip()] = (float(m.group(3)), m.group(1))
    return out


def suite_name_of(path: pathlib.Path) -> str:
    """The name a suite prints itself under, read off its own _init()."""
    m = re.search(r'suite_name\s*=\s*"([^"]+)"',
                  path.read_text(encoding="utf-8", errors="replace"))
    return m.group(1) if m else ""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tests", default="tests")
    ap.add_argument("--sim", default="sim")
    ap.add_argument("--terrain", default="scripts/terrain")
    ap.add_argument("--quiet", action="store_true", help="only the per-suite summary line")
    ap.add_argument("--costs", default="reports/adopted-base-full-suite.log",
                    help="a run transcript, to join each suite to what it cost")
    ap.add_argument("--runner", default="bin/test_main.gd",
                    help="where the list of suites a run enters lives")
    ap.add_argument("--all-files", action="store_true",
                    help="include test_*.gd files no run enters")
    args = ap.parse_args()

    names = position_queries([pathlib.Path(args.sim), pathlib.Path(args.terrain)])
    print("# %d position queries declared under %s and %s"
          % (len(names), args.sim, args.terrain))
    if not args.quiet:
        print("# " + ", ".join(sorted(names)))
    print()

    costs = suite_costs(pathlib.Path(args.costs))
    if costs:
        print("# %d suite verdicts read from %s" % (len(costs), args.costs))
        print()
    entered = registered_suites(pathlib.Path(args.runner))
    suites = sorted(pathlib.Path(args.tests).glob("test_*.gd"))
    if entered and not args.all_files:
        print("# %d of %d test_*.gd files are suites a run enters (%s); the rest "
              "are skipped" % (len(entered), len(suites), args.runner))
        print()
        suites = [s for s in suites if s.as_posix() in entered]
    with_sweeps = 0
    total = 0
    for path in suites:
        found = sweeps(path, names)
        if not found:
            continue
        with_sweeps += 1
        total += len(found)
        marks = {"SCATTERED": 0, "local": 0, "unread": 0}
        for hit in found:
            _, step = classify(hit)
            marks["SCATTERED" if step > BLOCK_WORLD else ("local" if step >= 0 else "unread")] += 1
        name = suite_name_of(path)
        cost = costs.get(name)
        spent = ("%.0f s %s" % (cost[0], cost[1])) if cost else "not in the transcript"
        print("%s [%s]: %d position queries inside a loop "
              "(%d scattered, %d local, %d not readable from the source)"
              % (path, spent, len(found), marks["SCATTERED"], marks["local"],
                 marks["unread"]))
        if args.quiet:
            continue
        for hit in found:
            depth = len(hit["loops"])
            reason, step = classify(hit)
            mark = "SCATTERED" if step > BLOCK_WORLD else ("local" if step >= 0 else "unread")
            print("  line %d  depth %d  %s  [%s: %s]"
                  % (hit["line"], depth, ", ".join(hit["calls"]), mark, reason))
            for _, ln, header in hit["loops"]:
                print("      loop %d: %s" % (ln, header[:90]))
            print("      call:   %s" % hit["text"][:90])
            for line in hit["where"]:
                print("      where:  %s" % line)
        print()
    print("# %d of %d suites ask the ground about a position inside a loop "
          "(%d call sites)" % (with_sweeps, len(suites), total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
