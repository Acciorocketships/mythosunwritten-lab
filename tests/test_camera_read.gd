extends TestSuite
## The camera the game ships with, and the rule that keeps a tree from standing
## in front of the person it is aimed at.
##
## Both halves of one defect: at the camera this project shipped until now the
## person was thirteen pixels tall, and what pixels they had were often inside a
## fir. The first four checks are about the camera's own geometry -- how big a
## character is at it, and that pulling it in did not tilt it -- and the rest are
## about `FoliageFade`, which decides what gives way.
##
## Nothing here draws anything. A pixel height is the perspective projection
## worked out from the constants the shell ships, and an obstruction is a segment
## against a cylinder; both are arithmetic, so both can be checked without a
## window, a pack model or a frame. What the arithmetic claims is then shown in a
## photograph, in `reports/camera-read.md`.
class_name TestCameraRead

## The shell itself, for the two constants that are the camera.
const RenderShell := preload("res://render/main.gd")

## How tall the shipped character measures, in world units.
##
## Read off a frame rather than off a model: `playtest-walk-t8.png` was taken
## with the camera 11.18 units away and the character's armour occupies 73
## pixels of it, which at this window and this field of view is this many units.
## `reports/camera-read.md` has the working.
const CHARACTER_TALL := 1.93

## The window the game ships in, and the field of view it ships with -- Godot's
## own default, which `project.godot` does not override, and which is vertical
## because the viewport keeps its height.
const WINDOW_TALL := 648.0
const FIELD_OF_VIEW := 75.0

## What the camera used to be, kept so that "the angle did not change" is a
## comparison rather than a claim.
const WAS_OFFSET := Vector3(0.0, 42.0, 52.0)
const WAS_AIM := 10.0

## How tall the character has to come out on the screen at the shipped camera
## for this to have been worth doing, in pixels, and how tall it must not
## exceed -- past which a fight eight cells across stops fitting in frame.
const AT_LEAST := 40.0
const AT_MOST := 70.0


func _init() -> void:
	suite_name = "camera read"


func run() -> void:
	_the_person_is_big_enough_to_see()
	_the_camera_came_in_without_turning()
	_a_tree_across_the_sight_line_gives_way()
	_a_tree_that_is_not_in_the_way_is_left_alone()
	_the_edge_of_the_rule_is_soft()
	_nothing_ever_steps()


## The whole point of the change, as a number: how tall the character the person
## is steering comes out on the screen at the camera the game ships with.
func _the_person_is_big_enough_to_see() -> void:
	var was := _pixels(CHARACTER_TALL, WAS_OFFSET.length())
	var now := _pixels(CHARACTER_TALL, RenderShell.CAMERA_OFFSET.length())
	check(was < 20.0,
		"the old camera drew the character %.1f px tall, which was not the defect" % was)
	check(now >= AT_LEAST,
		"the shipped camera draws the character %.1f px tall, under the %.0f it was chosen for"
			% [now, AT_LEAST])
	check(now <= AT_MOST,
		"the shipped camera draws the character %.1f px tall, over the %.0f a board still fits at"
			% [now, AT_MOST])


## And the change was a distance and not a new angle. The tilt a camera looks
## down at is the ratio of its height to its distance back, and the tilt the aim
## lifts it by is the ratio of the lift to the whole distance; both are compared
## with what they were, because the diorama's look is that angle.
func _the_camera_came_in_without_turning() -> void:
	var offset: Vector3 = RenderShell.CAMERA_OFFSET
	check(offset.length() < WAS_OFFSET.length(),
		"the shipped camera is not nearer than the one it replaced")
	check(is_equal_approx(snappedf(offset.y / offset.z, 0.0001),
			snappedf(WAS_OFFSET.y / WAS_OFFSET.z, 0.0001)),
		"the camera looks down at %.4f where it used to look down at %.4f"
			% [offset.y / offset.z, WAS_OFFSET.y / WAS_OFFSET.z])
	check(absf(RenderShell.CAMERA_AIM_LIFT / offset.length()
			- WAS_AIM / WAS_OFFSET.length()) < 0.001,
		"the aim lifts the view by %.4f of the camera's distance where it used to lift it by %.4f"
			% [RenderShell.CAMERA_AIM_LIFT / offset.length(), WAS_AIM / WAS_OFFSET.length()])


## A tree standing on the line from the camera to the person's chest is squarely
## in the way, and is drawn as far out of the way as the rule ever puts anything.
func _a_tree_across_the_sight_line_gives_way() -> void:
	var person := Vector3.ZERO
	var camera := person + RenderShell.CAMERA_OFFSET
	var between := person + RenderShell.CAMERA_OFFSET * 0.5
	between.y = 0.0
	var covered := FoliageFade.cover(camera, person, between, 1.6, 7.0)
	equal(covered, 1.0, "a tree halfway along the sight line is not squarely in the way")
	equal(FoliageFade.transparency_for(covered), FoliageFade.DEEPEST,
		"a tree squarely in the way is not drawn at the rule's own deepest")


## And the three ways of not being in the way: behind the person, behind the
## camera, and off to one side.
func _a_tree_that_is_not_in_the_way_is_left_alone() -> void:
	var person := Vector3.ZERO
	var camera := person + RenderShell.CAMERA_OFFSET
	var beyond := person - RenderShell.CAMERA_OFFSET * 0.5
	beyond.y = 0.0
	equal(FoliageFade.cover(camera, person, beyond, 1.6, 7.0), 0.0,
		"a tree behind the person's back is treated as hiding them")
	var back := person + RenderShell.CAMERA_OFFSET * 1.5
	back.y = 0.0
	equal(FoliageFade.cover(camera, person, back, 1.6, 7.0), 0.0,
		"a tree behind the camera is treated as hiding the person")
	var aside := person + RenderShell.CAMERA_OFFSET * 0.5 + Vector3(9.0, 0.0, 0.0)
	aside.y = 0.0
	equal(FoliageFade.cover(camera, person, aside, 1.6, 7.0), 0.0,
		"a tree nine units off the sight line is treated as hiding the person")
	# And the one that is on the line in plan but under it in height: the camera
	# looks down, so a mushroom halfway to the person is below the line.
	var low := person + RenderShell.CAMERA_OFFSET * 0.5
	low.y = 0.0
	equal(FoliageFade.cover(camera, person, low, 1.6, 0.3), 0.0,
		"a mushroom the sight line passes over is treated as hiding the person")


## Walked out sideways from the line: full cover inside the crown, none past the
## crown and the clearance, and never a step in between. A hard edge here is a
## tree that switches as the person walks, which is the thing the soft edge and
## the ramp both exist to stop.
func _the_edge_of_the_rule_is_soft() -> void:
	var person := Vector3.ZERO
	var camera := person + RenderShell.CAMERA_OFFSET
	var crown := 1.6
	var last := 1.1
	var steps := 60
	var out := (crown + FoliageFade.CLEARANCE) * 1.2
	for at in steps + 1:
		var aside := person + RenderShell.CAMERA_OFFSET * 0.5
		aside.y = 0.0
		aside.x += out * float(at) / float(steps)
		var covered := FoliageFade.cover(camera, person, aside, crown, 7.0)
		check(covered <= last + 0.0001,
			"the cover rises again %.3f units out from the line" % (out * float(at) / float(steps)))
		check(last - covered < 0.2,
			"the cover steps by %.3f at %.3f units out from the line"
				% [last - covered, out * float(at) / float(steps)])
		last = covered
	equal(last, 0.0, "a tree past the crown and the clearance is still giving way")


## A prop never jumps from one transparency to another, however big a frame was,
## and it always arrives.
func _nothing_ever_steps() -> void:
	var now := 0.0
	var frames := 0
	while now < FoliageFade.DEEPEST and frames < 1000:
		var next := FoliageFade.toward(now, FoliageFade.DEEPEST, 1.0 / 60.0)
		check(next - now <= FoliageFade.RAMP / 60.0 + 0.0001,
			"a prop moved %.3f in one sixtieth of a second" % (next - now))
		now = next
		frames += 1
	equal(now, FoliageFade.DEEPEST, "a prop never arrives at the deepest it should be drawn")
	check(frames > 4, "a prop reaches its deepest in %d frames, which is a switch" % frames)
	check(frames < 60, "a prop takes %d frames of sixty to give way, which is a lag" % frames)
	equal(FoliageFade.toward(0.4, 0.0, 10.0), 0.0,
		"a whole second of thickening does not get a prop back to solid")


## How many pixels tall a thing of a given height is that far from the shipped
## camera, in the window the game ships in. The perspective projection and
## nothing else: the field of view is vertical, so the window's height spans
## `2 tan(fov / 2) * distance` world units at that distance.
func _pixels(tall: float, away: float) -> float:
	return WINDOW_TALL * tall / (2.0 * tan(deg_to_rad(FIELD_OF_VIEW) * 0.5) * away)
