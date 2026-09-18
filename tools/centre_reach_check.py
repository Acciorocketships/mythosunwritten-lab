#!/usr/bin/env python3
"""Check a world dump against the bound SettlementField.centre_reach() states.

centre_reach() is what lets a scan of the settlement lattice skip cells on
arithmetic alone: it says no village of an ordinary cell stands further than a
quarter of a cell from that cell's middle, and that the cell holding the world
origin is bounded instead by its spawn ring's outer radius. The skip is only
exact if that bound is really a bound, so this reads every village out of a
dump written by tools/ground_world_dump.gd and measures it against the numbers
taken straight out of sim/settlement_field.gd -- no engine, and no constant
copied here to drift.

    python3 tools/centre_reach_check.py reports/ground-world-dump-after.txt
"""

import re
import sys


def constant(source: str, name: str) -> float:
    found = re.search(rf"^const {name} := ([\d.]+)$", source, re.M)
    if found is None:
        raise SystemExit(f"sim/settlement_field.gd no longer states {name}")
    return float(found.group(1))


def main(argv: list[str]) -> int:
    dump = argv[1] if len(argv) > 1 else "reports/ground-world-dump-after.txt"
    with open("sim/settlement_field.gd", encoding="utf-8") as handle:
        source = handle.read()
    cell_across = constant(source, "SITE_CELL")
    jitter_high = constant(source, "JITTER_HIGH")
    spawn_ring_max = constant(source, "SPAWN_RING_MAX")
    ordinary = cell_across * (jitter_high - 0.5)

    village = re.compile(r"^cell (-?\d+) (-?\d+) at (-?[\d.]+) (-?[\d.]+) ")
    checked = 0
    worst = 0.0
    outside = []
    with open(dump, encoding="utf-8") as handle:
        for line in handle:
            hit = village.match(line)
            if hit is None:
                continue
            cell_x, cell_z = int(hit.group(1)), int(hit.group(2))
            at_x, at_z = float(hit.group(3)), float(hit.group(4))
            bound = spawn_ring_max if (cell_x, cell_z) == (0, 0) else ordinary
            away = max(
                abs(at_x - cell_across * cell_x),
                abs(at_z - cell_across * cell_z),
            )
            checked += 1
            worst = max(worst, away / bound)
            if away > bound:
                outside.append((cell_x, cell_z, away, bound))

    print(f"dump: {dump}")
    print(
        f"bound: {ordinary:.1f} units for an ordinary cell, "
        f"{spawn_ring_max:.1f} for the cell holding the origin"
    )
    print(f"villages checked: {checked}")
    print(f"worst offset, as a share of its own cell's bound: {worst:.4f}")
    if outside:
        for cell_x, cell_z, away, bound in outside:
            print(f"OUTSIDE cell {cell_x} {cell_z}: {away:.3f} > {bound:.1f}")
        print("FAIL centre_reach is not a bound")
        return 1
    if checked == 0:
        print("FAIL no villages found in that dump")
        return 1
    print("OK every village stands inside the bound its cell states")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
