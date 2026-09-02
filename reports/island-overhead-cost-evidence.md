# What the candidate bound recovered: the raw recordings

Every number in the "asked of the hashes first" section of
`reports/settlements.md` and in the "a question the hashes can answer" section of
`reports/islands.md` comes from the runs pasted below. They were taken in one
sitting on one machine, on one tree, with the four-line gate in
`SettlementField._clear_overhead` taken out and put back and nothing else
touched, so the two columns differ by the gate alone.

The tree with the gate is the one that ships. "Ungated" is the corrected veto as
it stood before this change: both walkable aerial storeys asked directly, every
cell of both bands built to answer.

## The bench: `tests/bench_settlements.gd`

Two runs of the bench per tree are quoted in the report; the ungated and gated
runs printed below are the pair that were taken back to back. The bench times all
three forms of the overhead question itself on every run, on the same positions
out of equally cold fields, which is why the `padded-lower` and `both-storeys`
rows agree across the two trees to within a percent: those two rows do not touch
the gate at all.

### ungated (both storeys, no bound)

```
bench settlements seed=1234 cells=25 villages=5 sites=a944e9c7013a498a ae91b3d783fc7cea 89f90e2544ea8161 c02678d9477e59b6 35fc8c53dded0549
bench settlements seed=7 cells=25 villages=4 sites=f2056e63ac51ee90 27116ce02d9864e2 bb0588c6ea052d5b 70738ca7d7fce8d4
bench settlements seed=3 cells=25 villages=4 sites=1772f7a319365f0d ea2b3c35308de15c fdc416e9b2e3c157 ab3bf556ea8494b9
bench settlements seed=19 cells=25 villages=4 sites=840a597536d3c79a d388a5ad100db299 69c87495e8bfea17 306f5fef5661a1e4
bench settlements seed=42 cells=25 villages=3 sites=0ae99160bc9eff3e 3bd18b6f3e9f1400 19bd852128cb9cee
bench settlements seed=101 cells=25 villages=7 sites=2683ac1aa99d42ce 8b97cd57d714b571 1d13a2342e97788e 12b2d5daa3f97869 8bead2f90be62afa 66ed4f86ebb34130 6f4aab387765e79f
bench settlements seeds=6 cells=150 villages=27 warm_usec_per_cell=31869
bench settlements cold cells=54 villages=13 cold_usec_per_cell=49196
bench overhead form=padded-lower asked=144 refused=91 usec_per_ask=94010
bench overhead form=both-storeys asked=144 refused=56 usec_per_ask=125726
bench overhead form=both-storeys-gated asked=144 refused=56 usec_per_ask=67304
```

### gated (both storeys, bound first) -- the shipped tree

```
bench settlements seed=1234 cells=25 villages=5 sites=a944e9c7013a498a ae91b3d783fc7cea 89f90e2544ea8161 c02678d9477e59b6 35fc8c53dded0549
bench settlements seed=7 cells=25 villages=4 sites=f2056e63ac51ee90 27116ce02d9864e2 bb0588c6ea052d5b 70738ca7d7fce8d4
bench settlements seed=3 cells=25 villages=4 sites=1772f7a319365f0d ea2b3c35308de15c fdc416e9b2e3c157 ab3bf556ea8494b9
bench settlements seed=19 cells=25 villages=4 sites=840a597536d3c79a d388a5ad100db299 69c87495e8bfea17 306f5fef5661a1e4
bench settlements seed=42 cells=25 villages=3 sites=0ae99160bc9eff3e 3bd18b6f3e9f1400 19bd852128cb9cee
bench settlements seed=101 cells=25 villages=7 sites=2683ac1aa99d42ce 8b97cd57d714b571 1d13a2342e97788e 12b2d5daa3f97869 8bead2f90be62afa 66ed4f86ebb34130 6f4aab387765e79f
bench settlements seeds=6 cells=150 villages=27 warm_usec_per_cell=22487
bench settlements cold cells=54 villages=13 cold_usec_per_cell=21816
bench overhead form=padded-lower asked=144 refused=91 usec_per_ask=94031
bench overhead form=both-storeys asked=144 refused=56 usec_per_ask=126024
bench overhead form=both-storeys-gated asked=144 refused=56 usec_per_ask=67468
```

The `sites=` fields are `Settlement.digest()`, the same text the determinism
suite compares villages by: cell, centre, radius, core radius, pad height, biome,
spawn and shore flags, and every building's tag, position, yaw and footprint.
Diffing the two runs' `sites=` lines is empty, so all 27 villages are in the same
cells at the same positions with the same buildings.

## The headless walks

Ten walks, each `./run_headless.sh`, the final fingerprint of each. The two lists
diff empty.

### ungated

```
seed=1234 ticks=100 done ticks=100 chunks=41 built=69 final=020507a9a1d52a1e
seed=7 ticks=100 done ticks=100 chunks=39 built=66 final=6b34e8f8e8444ea4
seed=3 ticks=100 done ticks=100 chunks=36 built=65 final=050f0d23594e1309
seed=19 ticks=100 done ticks=100 chunks=40 built=68 final=eaacc7fc32ad4ad3
seed=42 ticks=100 done ticks=100 chunks=37 built=64 final=4a95c1f219bed53a
seed=101 ticks=100 done ticks=100 chunks=37 built=64 final=101546704bef355b
seed=7 ticks=50 done ticks=50 chunks=38 built=49 final=daf74475a4699924
seed=101 ticks=100 start=276,214 done ticks=100 chunks=39 built=98 final=c38a78c90de3dd56
seed=1234 ticks=600 done ticks=600 chunks=37 built=246 final=107db826524b1b80
seed=101 ticks=600 done ticks=600 chunks=40 built=241 final=fc41ba865b453745
```

### gated -- the shipped tree

```
seed=1234 ticks=100 done ticks=100 chunks=41 built=69 final=020507a9a1d52a1e
seed=7 ticks=100 done ticks=100 chunks=39 built=66 final=6b34e8f8e8444ea4
seed=3 ticks=100 done ticks=100 chunks=36 built=65 final=050f0d23594e1309
seed=19 ticks=100 done ticks=100 chunks=40 built=68 final=eaacc7fc32ad4ad3
seed=42 ticks=100 done ticks=100 chunks=37 built=64 final=4a95c1f219bed53a
seed=101 ticks=100 done ticks=100 chunks=37 built=64 final=101546704bef355b
seed=7 ticks=50 done ticks=50 chunks=38 built=49 final=daf74475a4699924
seed=101 ticks=100 start=276,214 done ticks=100 chunks=39 built=98 final=c38a78c90de3dd56
seed=1234 ticks=600 done ticks=600 chunks=37 built=246 final=107db826524b1b80
seed=101 ticks=600 done ticks=600 chunks=40 built=241 final=fc41ba865b453745
```

Timed separately, two runs each, seed 1234 at 100 ticks: **7.76 / 7.76 s**
ungated, **6.83 / 6.83 s** gated.

## The whole suite

`./run_tests.sh`, same machine, same tree bar the gate:

| | wall | suites | checks |
|---|---|---|---|
| ungated | 10m41.9s | 18 | 161,870 |
| gated | 8m43.8s | 18 | 161,870 |

Both runs pass everything. The check counts are identical, so the 18% is time and
not work removed from the suite.

The bound's own soundness check is inside that count, in `tests/test_islands.gd`:
it runs the bound and the real scan side by side on 484 positions per walkable
storey across four seeds and requires the bound never to say no where the scan
finds an island. It printed:

```
        islands: candidate bound ruled out 523 of 968 asks, 199 had an island
```

Per band, over the same grid: the lower storey is ruled out on 208 of 484 asks
(43%), the upper storey on 315 of 484 (65%). The upper storey being the one most
often ruled out is what makes the saving as large as it is, because an upper
island is also the expensive one -- building one builds the lower one under it
first.
