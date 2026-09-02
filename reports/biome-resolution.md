# How fields become biomes

Section 13 of the design lists "biome roster and field→biome resolution
(thresholds, blend weights)" as an open decision. This is the decision, the
numbers it came out as, and why.

Everything here lives in `sim/biome_field.gd` (the resolution) and
`sim/biome_catalog.gd` (what each name looks like). Both are plain arithmetic
and plain data; nothing in either file knows that a renderer exists.

## The fields

Four continuous fields are sampled per world position, each one fractal value
noise (`sim/value_noise.gd`) hashed from the position rather than drawn from a
stream, so the answer at a position never depends on what was sampled before it
or in which process:

| field | what it means | period | layers |
| --- | --- | --- | --- |
| forest | how wooded the land is | 260 units | 3 |
| rocky | how stony and windswept it is | 330 units | 3 |
| moisture | how wet and soft it is | 205 units | 3 |
| pocket | where a twilight marsh hollow sits | 150 units | 2 |

Each is squashed into $[0, 1]$. The three periods are deliberately unequal and
mutually non-harmonic, so the axes do not line up into visible stripes, and all
of them are much wider than the 16-unit chunk, so a biome is a region you walk
through rather than a patch you step over. The pocket field is finer than the
others because a pocket should be a hollow you come across, not a province.

The first two axes are the "existing forest/rocky style axes" of the task;
moisture is the new mood axis.

## Resolution: soft nearest prototype

Each of the four distributed biomes sits at a point in $(\text{forest},
\text{rocky}, \text{moisture})$ space:

| biome | forest | rocky | moisture |
| --- | --- | --- | --- |
| meadow | 0.30 | 0.28 | 0.42 |
| deep forest | 0.80 | 0.34 | 0.60 |
| highland | 0.36 | 0.78 | 0.34 |
| blossom grove | 0.58 | 0.22 | 0.84 |

A position $x$ gives biome $b$ the weight

$$w_b(x) = \exp\!\left(-\frac{\lVert a(x) - c_b \rVert^2}{\tau}\right), \qquad \tau = 0.085$$

where $a(x)$ is the three axes at that position and $c_b$ is the biome's
prototype, and the four weights are then normalised to sum to one.

Why a kernel rather than thresholds. A threshold table ("forest > 0.6 and
moisture > 0.5 → deep forest") produces exactly the thing the task rules out: a
border is the level set of an inequality, so the profile snaps from one biome's
numbers to the other's at a single sample. The kernel has no branch in it at
all, so there is nothing to snap: every biome has a nonzero share of every
position, the shares vary as smoothly as the underlying noise, and what you get
at a "border" is the place where two shares happen to cross. The name is then
only the argmax of the weights — used for prose, censuses and prop gating, never
for anything you can see.

Why $\tau = 0.085$. $\tau$ is the width of a border, in squared axis units. A
biome's share falls to about a third of its peak at $\lVert a - c_b \rVert =
0.29$, which is roughly the distance between neighbouring prototypes; so the
middle of a region is nearly pure and the mixing happens over the last third of
the way to the neighbour. Since the axes cross their whole range over a couple
of hundred world units, that puts the visible width of a border at roughly
20–60 units — a few seconds of walking, wide enough to read as a transition and
narrow enough that most of a region reads as itself. Smaller values sharpen
borders towards a snap; larger values grey the whole map towards the average of
all four biomes.

## The twilight marsh is a separate layer, not a fifth prototype

The design asks for the marsh to be "a scattered pocket biome — it can appear
anywhere as an isolated eerie hollow, independent of distance/difficulty". A
fifth prototype cannot do that: it would own its own province of axis space,
which would be a region like any other, adjacent to whichever biomes are nearest
it in that space.

So the marsh is laid over the top instead. Its strength is

$$s(x) = \operatorname{smoothstep}(0.72,\ 0.90,\ p(x))$$

where $p$ is the pocket field, and the final weights are $(1 - s)$ times the
four normalised kernel weights, plus $s$ for the marsh. Consequences, all of
them wanted:

* A pocket can sit inside any biome without disturbing the map around it.
* Its rim is a gradient, because $s$ is a smooth ramp rather than a threshold —
  the same no-snap property the kernel gives the other four.
* There is no distance-from-spawn term anywhere in the file, so a pocket is
  exactly as likely at the frontier as at the doorstep. This is the mood/danger
  split of §9.1: mood is biome-driven, difficulty is carried by enemy level.

Why 0.72 and 0.90. The marsh dominates a position once $s$ passes the largest of
the other weights, which is at about $p \approx 0.81$, the midpoint of the ramp.
Moving the pair up makes pockets rarer and smaller; moving it down turns the
marsh into a province. This pair puts the marsh at 11–15% of sampled area, which
reads as "you come across one every few minutes of walking" rather than "you
live in one". The gap between the two values, 0.18, is what makes the rim a
blend rather than a coastline.

## What that produces

Percentage of sampled positions resolving to each biome, over a 181 × 181
lattice at 18-unit spacing (about 3.2 km square), at the origin and at
(120000, −85000):

| seed | region | meadow | deep forest | highland | blossom grove | twilight marsh |
| --- | --- | --- | --- | --- | --- | --- |
| 1234 | spawn | 21.6 | 22.7 | 30.7 | 13.9 | 11.1 |
| 1234 | far | 25.8 | 20.9 | 30.0 | 9.6 | 13.8 |
| 13 | spawn | 29.8 | 19.9 | 27.3 | 8.9 | 14.1 |
| 13 | far | 23.1 | 28.4 | 24.6 | 11.4 | 12.5 |
| 99 | spawn | 27.4 | 22.1 | 25.4 | 10.8 | 14.4 |
| 99 | far | 20.5 | 22.8 | 28.5 | 13.1 | 15.1 |

All five names occur everywhere; none swallows the map; the marsh's share does
not depend on how far from spawn the region is. The blossom grove is the
scarcest of the four distributed biomes, which suits a biome the design
describes as a soft dreamy pocket of pastel.

## Blending the profiles

A profile (`sim/biome_profile.gd`) is a bag of independently interpolatable
values — three tints, a fog colour and density, two sky colours, an ambient
colour, a foliage density — plus a set of allowed prop tags. Every numeric value
of a blended profile is the weighted average of the contributing biomes' values,
which is what makes a border a gradient in everything at once: ground colour,
fog, sky, fill light and how thickly things grow all slide together.

The prop tag set is the one thing that cannot be averaged, so it is a union
instead: a biome contributes its tags once it holds at least **0.15** of the
mix. Below that its colours still bleed in proportionally but a prop belonging to
it would look misplaced; above it, a border legitimately allows both biomes'
props. (No props are placed by this task — the tags are named here and the
scatter layer will read them.)

The blended profile's *name* is the strongest contributor's, so a blend still
answers "where am I" with one word.

## What was checked

`tests/test_biomes.gd`, in the ordinary suite (`./run_tests.sh`):

* the biome and the blended profile at a position do not change when the same
  positions are sampled in a different order with hundreds of unrelated samples
  in between, when other chunks are built first or in reverse order, or when the
  whole thing is resolved in a separate process;
* all five names occur in a sampled region and none takes more than 60% of it;
* the marsh occurs at both distances from spawn, in similar proportion (within
  3×), in at least 4 of 36 separate blocks of the near region, and never as more
  than 30% of it;
* every named biome carries every profile field, with a non-empty prop tag set
  of tags rather than asset paths, and no two biomes share a ground colour;
* a 48-unit transect across a border moves the profile by at most 15% of the
  total change in any one step, spread over at least 30 of its 239 steps, while
  the same transect resolved by name alone moves more than half of the change in
  a single step — the control is what makes "gradual" mean something;
* a profile handed out of the simulation is detached: writing into it changes
  neither the catalog nor what the field answers next time.

Both halves of the design were also checked by breaking them on purpose.
Replacing the blend with a lookup by strongest name failed four checks
("the blended profile moved 100.0% of the whole change in a single step, which
is a snap, not a blend"); multiplying the marsh strength by a term that falls off
with distance from spawn failed two ("the marsh is 999.7x more common in one
region than the other").

## What is deliberately not decided here

* **Spawn is not forced to be meadow.** §9.3 calls meadow "(spawn)", but pinning
  the biome at the origin belongs with the settlement layer that decides where
  the starting village goes, not with the field resolution.
* **The roster is these five.** §9.3's roster is exactly what is implemented; the
  fields would take more prototypes without any change to the machinery.
* **Height does not feed the biome.** Highland is a rocky *style*, not an
  altitude band. Coupling the biome to the heightfield is a plausible later
  refinement (and the fields are already sampled from the same positions), but it
  would make the biome map depend on the terrain layer, and there is no evidence
  yet that it looks better.
