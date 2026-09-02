extends RefCounted
## The world, drawn a second time upside down, so the water can mirror it.
##
## Section 9.1's third reference beat is "amber windows and hanging lanterns
## mirrored in still water", and until this existed the water shader animated
## ripples and a little sparkle and reflected nothing at all. This is the
## missing half.
##
## ## Why a planar mirror and not one of the cheaper answers
##
## Three techniques were on the table and two of them cannot draw this beat:
##
## * **Screen-space reflections.** Godot's SSR traces the depth buffer, and the
##   depth buffer only holds what is on screen. A lit window reflected in the
##   pond in front of the house is very often a window that is *above* the top of
##   the frame or behind the camera, and SSR has nothing to trace for it -- it
##   fades the reflection out exactly where the beat needs it. It also does not
##   apply to transparent surfaces in the Forward+ renderer, and this water is
##   transparent by construction: its alpha is its depth, which is what makes a
##   shore fade out instead of ending at a line.
## * **A reflection probe.** A cube map is cheap and it is the right answer for a
##   rough, curved, incidental reflection. It is the wrong answer for a flat
##   mirror: a probe is a single point sample of the surroundings, so a pond
##   twenty units across reflects the same cube map at both ends and the house
##   does not move as you walk past it. What it gives is a glow on the water, not
##   a mirrored window.
## * **A planar mirror** -- this. The scene is rendered again from the camera
##   reflected through the water's plane, and the water samples that image where
##   it lands on screen. It is the only one of the three that puts a *recognisable*
##   window in the water, which is what the beat is.
##
## What it costs is a second view of the world, and that is measured rather than
## assumed: `tools/measure_reflection.sh` prices it on the same scene the game
## draws, and reports/atmosphere.md carries the numbers. The two things that keep
## it affordable are both here: the mirror is rendered at a fraction of the
## window's resolution (SCALE below), and it sees a shorter world than the main
## camera does (FAR below).
##
## ## The plane
##
## A planar mirror needs one plane, and the world's water is not one surface --
## a river follows the ground downhill. But *standing* water is, by construction:
## the water field defines a pond as the ground having fallen below a broad,
## slowly wandering water table, so every pond and lake is exactly level with
## that table. So the mirror plane is the water table under the viewer, read out
## of the water field. Where there is standing water that plane is the water's
## own surface and the reflection is exact; on a river it is out by the depth the
## river has cut below the table, which is where a mirror matters least -- a
## stream in a gully reflects the sky.
##
## ## Handedness
##
## Reflecting a camera basis through a plane flips its handedness, and a
## left-handed camera reverses the winding of every triangle it draws, so
## back-face culling would cull the fronts and the ground would vanish. So the
## mirror camera is *not* built by reflecting the basis. It is aimed with
## look_at from the reflected position at the reflected target with the reflected
## up, which is right-handed and draws the world correctly -- and which differs
## from the true mirror by a left-right flip. That flip is undone in the shader
## by sampling at `1.0 - u`. Doing it this way round costs one subtraction per
## water fragment and nothing else.
class_name WaterReflection

## How much of the window's resolution the mirror is drawn at, per side. A
## reflection is seen through a rippling surface that warps its lookup, so it
## carries far less detail than the frame it mirrors; half is the point where
## dropping further starts to show on the straight edges of a roof.
const SCALE := 0.5

## How far the mirror camera sees, in world units. Much shorter than the main
## camera's, which reaches the far-sky islands: what a pond reflects is the
## village on its bank and the sky, and the sky is drawn whatever the far plane
## is. Everything between here and the main camera's far plane is drawn once
## instead of twice.
const FAR := 220.0

## The visual layer everything that must not appear in the mirror is put on:
## the water itself, and the island ponds, which share its material. Water
## reflecting water is a feedback loop with nothing in it.
const HIDDEN_LAYER := 2

## How far above the mirror plane the camera has to be for the mirror to be
## worth drawing at all. Below it -- underwater, or inside a bank -- the
## reflection is of nothing and the viewport is left un-updated, which is the
## whole of switching it off for that frame.
const MIN_HEIGHT := 0.05

## Whether the mirror is drawn at all. False is the whole of switching it off
## from outside: the viewport stops being redrawn and the last frame is not
## shown. Only tools/measure_reflection.sh sets it, to price the frame with and
## without; the game's own switch is --no-reflection, which does not build one.
var enabled := true

## How much of the window the mirror is drawn at, per side. SCALE unless a
## measurement is pricing another setting.
var scale := SCALE

## What anti-aliasing the mirror is drawn with, as one of AntiAliasing.MODES.
## The shipped answer is the screen-space filter and no multi-sampling, and the
## measurement that chose it is in attach() below; a capture sets it with
## `run_render.sh --mirror-aa off` to photograph the alternative, which is how
## the question was answered rather than assumed.
var anti_aliasing := "fxaa"

## The window the mirror is drawn into, and the camera that draws it.
var _viewport: SubViewport = null
var _camera: Camera3D = null

## The plane the last frame was mirrored through, in world units, and whether
## that frame was drawn at all.
var _plane := 0.0
var _drawn := false

## How many frames the mirror has been drawn for. Printed at exit, so a test can
## tell a run with a reflection from one without needing a screen to look at.
var frames_drawn := 0


## Build the mirror and hang it in the tree. `shell` is the render shell, which
## is what owns everything else on screen too.
func attach(shell: Node) -> void:
	_viewport = SubViewport.new()
	_viewport.name = "water_reflection"
	# Sharing the shell's own world is the whole trick: this is not a second
	# scene, it is a second view of the one scene, so anything the streamer loads
	# is in the mirror the same frame it is in the world.
	_viewport.own_world_3d = false
	_viewport.transparent_bg = false
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The filter, but not the sampling. The mirror is drawn at half the window's
	# resolution and resampled through a rippling surface, so *sampling* it four
	# times a pixel is spent on detail the water throws away -- and it is spent
	# on a second whole view of the world, which is why it is not cheap. Priced
	# on the pond beat with the main viewport already at 4x and FXAA, the mirror
	# drawn with nothing, with FXAA, and with both (reports/grass.md section 9.6):
	# the reflection's own noise goes 0.0204 -> 0.0170 -> 0.0161, and the frame
	# goes 5858 ms -> 5891 ms -> 8917 ms. The filter is 17% of the noise for 0.6%
	# of the frame; the sampling is a further 5% for another half a frame again.
	# So the mirror takes the free half and refuses the expensive one.
	if not AntiAliasing.apply(_viewport, anti_aliasing):
		AntiAliasing.apply(_viewport, "fxaa")
	# Debanding is still refused outright: it is dither over a gradient, and the
	# ripples are already dithering this image far harder than it would.
	_viewport.use_debanding = false
	_viewport.positional_shadow_atlas_size = 0

	_camera = Camera3D.new()
	_camera.name = "mirror"
	_camera.near = 0.5
	_camera.far = FAR
	_camera.cull_mask = 0xFFFFF & ~HIDDEN_LAYER
	_camera.current = true
	_viewport.add_child(_camera)
	shell.add_child(_viewport)


## Point the mirror at what the main camera is looking at, through the plane the
## water at the viewer stands on.
##
## Called once a frame with the transform and lens of the camera the game is
## drawn from, rather than with the camera itself. Taking the transform is what
## makes the aiming a piece of arithmetic that can be checked on its own: a
## Node3D only has a global transform while it is in a tree, and "is this really
## a mirror" should not depend on a scene being loaded to ask.
func aim(
	view: Transform3D,
	fov: float,
	table_level: float,
	size: Vector2i,
	water_on_screen: bool,
) -> void:
	_plane = table_level
	var wanted := Vector2i(
		maxi(2, int(round(float(size.x) * scale))),
		maxi(2, int(round(float(size.y) * scale))),
	)
	if _viewport.size != wanted:
		_viewport.size = wanted

	var eye := view.origin
	# Three ways a frame is not worth drawing, and each of them is the whole of
	# switching the mirror off for that frame -- the viewport is left un-updated,
	# so a second view of the world is not rendered at all:
	#
	# * there is no water in the streamed window, which is most of this world.
	#   8.3% of it is water, so most walks pay nothing for the mirror;
	# * the camera is under the plane -- underwater, or inside a bank -- where
	#   there is nothing above it to mirror;
	# * something outside has switched it off to price the frame without it.
	_drawn = enabled and water_on_screen and eye.y > _plane + MIN_HEIGHT
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _drawn \
		else SubViewport.UPDATE_DISABLED
	if not _drawn:
		return
	frames_drawn += 1

	_camera.fov = fov
	# Set as a local transform, not with look_at: the mirror camera hangs inside
	# a viewport rather than under a Node3D, so its local transform *is* its
	# global one, and building it here rather than asking the engine to point a
	# node keeps the aiming true whether or not anything is in a tree.
	var ahead := eye - view.basis.z
	var up := Vector3(view.basis.y.x, -view.basis.y.y, view.basis.y.z)
	_camera.transform = Transform3D(Basis(), _through(eye)) \
		.looking_at(_through(ahead), up)


## A point reflected through the mirror plane.
func _through(at: Vector3) -> Vector3:
	return Vector3(at.x, 2.0 * _plane - at.y, at.z)


## The image the water samples. A ViewportTexture, so it is the mirror as of the
## frame that is being drawn rather than a copy of one.
func texture() -> ViewportTexture:
	return _viewport.get_texture()


## The plane the last frame was mirrored through.
func plane() -> float:
	return _plane


## Whether the last frame was drawn at all.
func is_drawn() -> bool:
	return _drawn


## The window the mirror is drawn into, for a measurement tool that wants to
## switch it off or price it at another size.
func viewport() -> SubViewport:
	return _viewport


## The camera that draws the mirror. Handed out rather than fetched off the
## viewport, because a viewport only names its camera once it is in a tree and
## whether this is really a mirror is a question about arithmetic.
func camera() -> Camera3D:
	return _camera
