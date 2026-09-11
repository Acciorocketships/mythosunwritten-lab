extends RefCounted
## Which trees stand between the camera and the person, and how far out of the
## way each of them gets. Holds nothing, decides nothing else.
##
## The companion of `render/ground_items.gd` and built to the same rule:
## everything here is a pure function of positions and sizes, so what it claims
## can be walked by a test without a window, a pack model or a frame.
##
## ## Why anything is faded at all
##
## The playing camera looks down on the world from behind the person, and the
## world it looks across is a meadow with trees in it. A tree standing anywhere
## on that sight line hides the one thing on the screen a person is steering.
## The second playtest photographed exactly that: `playtest-enemy-t40.png` is a
## fight in which "every fighter is under a tree crown", and the shipping
## camera's own frame has the person's head inside a fir.
##
## Three answers were available -- move the camera off the obstruction, cut the
## obstruction out, or let it give way -- and the one chosen is the third, for
## the reason the grass over a board square is *shortened* rather than faded:
## this world's look is a diorama seen from a fixed angle, and a camera that
## swings to dodge a trunk trades a defect a person notices once for a picture
## that moves when they did not ask it to. A tree that is cut out pops; a tree
## that thins keeps its own silhouette, keeps its shadow (per-instance
## transparency in this engine does not switch shadow casting off), and says
## "the person is behind me" rather than vanishing.
##
## ## What counts as in the way
##
## One segment: from the camera to the person's chest. A prop is in the way when
## that segment passes through the cylinder it occupies -- inside its crown
## horizontally, between its feet and its top vertically, and *between* the two
## ends rather than past either of them. A tree behind the person's back is not
## hiding them from a camera in front of it, and t is checked for that.
##
## The edge is soft. A prop whose crown the segment misses by less than
## `CLEARANCE` is part of the way out of the way, so walking past a trunk thins
## it and thickens it again instead of switching it.
class_name FoliageFade

## Where on the person the sight line is aimed, in world units above their feet.
##
## The chest rather than the feet or the crown of the head: a shipped character
## measures 1.93 units (`reports/camera-read.md`), so this is a little over the
## middle of them. Aimed at the feet, a tree that hid the body but not the boots
## would be left alone; aimed at the head, the same tree would be left alone
## from the other end.
const SUBJECT_LIFT := 1.0

## How far outside its own crown a prop starts giving way, in world units.
##
## This is the whole of the soft edge: at the crown and inside it a prop is as
## far out of the way as it goes, and this far outside it is not out of the way
## at all. Three quarters of a unit is about a third of a second of walking at
## the world's own 0.90 units a tick, which is slow enough not to flicker and
## quick enough that a tree is already thin by the time it would have covered
## anything.
const CLEARANCE := 0.75

## How transparent a prop squarely in the way becomes: not all the way out.
##
## A tree faded to nothing is a tree that was never there, and the picture then
## lies about the world -- a person would walk at a gap that is a trunk. At this
## much the crown is a wash of its own colour with the character legible through
## it, which is the honest statement: something is in front of you, and here is
## what is behind it.
const DEEPEST := 0.82

## How fast a prop may thin or thicken, in transparency per second.
##
## The soft edge above is the *spatial* ramp and this is the temporal one; both
## exist because either alone still steps. At this rate a tree takes a quarter
## of a second to go from solid to `DEEPEST`, which is under the time it takes
## to walk the `CLEARANCE` above and so is never the slower of the two.
const RAMP := 3.4

## The widest crown any scattered prop could be drawn with, in world units.
##
## This decides only which scatter patches are worth walking at all -- never
## which props give way, which is `cover` above and is measured off the model
## that was actually built. So it is chosen generously and on purpose: the
## tallest thing the scatter asks for anywhere is a deep-forest tree at 12.5
## units (`ScatterCatalog`), the installed trees are at widest about as broad as
## they are tall (`tools/measure_models.sh Tree`), and half of that is under
## this. Too big costs a few more props looked at; too small would silently stop
## fading the one tree that mattered.
const WIDEST_CROWN := 6.0


## How far out of the way a prop at `at` should get, from 0 (not in the way at
## all) to 1 (squarely across the sight line).
##
## `at` is the prop's foot -- the point the shell stood it on -- `crown` is its
## horizontal radius as drawn and `stands` its height as drawn. `subject` is the
## person's feet; `SUBJECT_LIFT` is added here so that every caller aims at the
## same point on them.
static func cover(
	camera: Vector3, subject: Vector3, at: Vector3, crown: float, stands: float
) -> float:
	if crown <= 0.0 or stands <= 0.0:
		return 0.0
	var chest := subject + Vector3(0.0, SUBJECT_LIFT, 0.0)
	var along := Vector2(chest.x - camera.x, chest.z - camera.z)
	var span := along.length_squared()
	if span <= 0.0:
		return 0.0
	# How far along the camera-to-chest line the prop stands, as a share of it.
	# Outside (0, 1) it is not between the two and cannot be hiding anything:
	# past 1 it is behind the person's back, before 0 it is behind the camera.
	var share := Vector2(at.x - camera.x, at.z - camera.z).dot(along) / span
	if share <= 0.0 or share >= 1.0:
		return 0.0
	# And the sight line has to pass through the prop's own height, not over it
	# or under it. A camera looking down crosses a bush's height only when it is
	# nearly on top of it, which is exactly when a bush is in the way.
	var crossing := camera.y + share * (chest.y - camera.y)
	if crossing < at.y or crossing > at.y + stands:
		return 0.0
	var nearest := Vector2(camera.x, camera.z) + along * share
	var off := Vector2(at.x, at.z).distance_to(nearest)
	return clampf((crown + CLEARANCE - off) / CLEARANCE, 0.0, 1.0)


## How transparent a prop with that much of the sight line across it is drawn.
static func transparency_for(covered: float) -> float:
	return clampf(covered, 0.0, 1.0) * DEEPEST


## One frame's worth of movement from where a prop's transparency is towards
## where it should be, so nothing ever steps from one value to another.
static func toward(now: float, target: float, delta: float) -> float:
	return move_toward(now, target, RAMP * maxf(delta, 0.0))
