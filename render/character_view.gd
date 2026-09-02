extends Node3D
## One character on screen: a model, the machinery that animates it, and one
## rule that turns the simulation's state into a clip.
##
## This is the render half of section 3.3's first tier. It holds no simulation
## state of any kind -- not a position it remembers, not a clip it was playing
## last frame that it needs in order to decide this frame's. It is handed a
## snapshot and it draws it. Everything it knows about being alive fits in
## `clip_for()` below, which is a pure function: the same state gives the same
## clip in any process, at any time, whatever this view has drawn before.
##
## That purity is the whole point of the split. The simulation says a character
## is moving at some speed and has just climbed; it has never heard of "Walking_A"
## and there is an automated check (tests/asset_check.gd) that fails the build if
## it ever does. Which animation that state *looks* like is a question about the
## pack that is installed, and it is answered here and nowhere else.
##
## The scene owns three things and the model owns none of them:
##
##   AnimationPlayer -- holds the shared clip library for the rig, and is the
##                      thing the tree drives.
##   AnimationTree   -- blends standing into walking into running on one number,
##                      and lays a one-off (a jump, a hit) or a death over it.
##   BoneAttachment3D x2 -- the two hand sockets, following `handslot.l` and
##                      `handslot.r` through the model's skeleton from outside it.
##
## The model is a *child*, swapped by set_model() and rewired when the swap
## lands. That is what makes changing which adventurer a character is cost one
## line rather than a second animation setup, and it is why the player and the
## tree are above the model in the tree rather than inside it. Nothing is
## socketed yet -- weapons wait for W-items -- but the sockets follow the hands
## from the moment a model arrives, so equipping one later is `add_child`.
class_name CharacterView

## The scene this class is the script of. Whoever wants a character instantiates
## this rather than building the nodes by hand, so there is exactly one place the
## structure is written down.
const SCENE := "res://render/character.tscn"

# --- The clips -----------------------------------------------------------
# The six the simulation can currently ask for, out of the shared library. Names
# out of the pack, and the only place in the project they appear.

const CLIP_IDLE := "Idle_A"
const CLIP_WALK := "Walking_A"
const CLIP_RUN := "Running_A"
const CLIP_JUMP := "Jump_Full_Short"
const CLIP_HIT := "Hit_A"
const CLIP_DEATH := "Death_A"

## Every clip this view can choose, in the order the rule reaches them. A test
## walks it to check the library really holds all six.
const CLIPS := [CLIP_IDLE, CLIP_WALK, CLIP_RUN, CLIP_JUMP, CLIP_HIT, CLIP_DEATH]

# --- Where the rule's thresholds sit -------------------------------------
# All three are in world units per simulation tick, because that is the unit the
# snapshot's motion is in. The observer walks at 0.9 (SimWorld.OBSERVER_SPEED),
# which is deliberately between the two speed thresholds: it is unmistakably
# moving and it is not sprinting, so the world as it stands draws a walk.

## Below this a character is standing still. Not zero, because a character
## shuffling a hair per tick is standing, and because a threshold at exactly zero
## would flicker on the last tick of a stop.
const WALK_SPEED := 0.05

## At or above this a character is running rather than walking. Above the
## observer's own speed on purpose: running is what a character with movement
## gear will do (§3.4), and nothing in the world moves that fast yet.
const RUN_SPEED := 1.30

## A rise of at least this much in one tick is a character leaving the ground
## rather than walking up a slope. The world's one hop is the climb onto a
## floating island's rim, which is metres rather than centimetres; a slope
## climbed at the observer's 0.9 units a tick gains far less.
const HOP_RISE := 0.60

# --- How the tree is wired -----------------------------------------------

## Where each of the three locomotion clips sits on the blend axis. The axis is
## the character's speed in units per tick, so the blend is over the same number
## the rule reads and standing/walking/running cross-fade instead of snapping.
const BLEND_IDLE := 0.0
const BLEND_WALK := 0.90
const BLEND_RUN := 1.80

## How fast the blend chases the speed the snapshot reports, per second. The
## simulation steps twenty times a second and the view draws sixty; without this
## a character crossing a threshold would pop.
const BLEND_CHASE := 6.0

## How long a one-off clip takes to fade in and out over the locomotion under it.
const SHOT_FADE := 0.15

## The bones the two sockets follow. Part of the shared 23-bone rig, which is why
## the same two names work on a knight and on a skeleton alike.
const SOCKET_BONES := {"HandLeft": "handslot.l", "HandRight": "handslot.r"}

## Which tag this view is currently wearing, or "" for one with no model yet.
var model_tag := ""

## How many times a model has been mounted on this view. Diagnostic: a swap that
## rebuilt the animation setup would show up as a second library assembly, and
## this is the counter that says the swap happened at all.
var models_mounted: int = 0

var _mount: Node3D = null
var _player: AnimationPlayer = null
var _tree: AnimationTree = null

# The tree's own nodes, kept so a clip can be pointed at without rebuilding the
# graph. Which clip an overlay plays changes; the shape of the graph does not.
var _locomotion: AnimationNodeBlendSpace1D = null
var _shot_clip: AnimationNodeAnimation = null
var _death_clip: AnimationNodeAnimation = null

# The model currently mounted, and the skeleton inside it the sockets follow.
var _model: Node3D = null
var _skeleton: Skeleton3D = null

# What the view is showing, so that a one-off is fired on the tick it starts
# rather than re-fired on every frame it is still running. This is a fact about
# the picture -- which frame of which clip is on screen -- and not a copy of
# anything the simulation holds: apply() with the same state always ends with
# the same clip playing, whatever was here before.
var _shown_clip := ""
var _blend := 0.0


# --- The rule ------------------------------------------------------------


## Which clip a character in this state plays. A pure function: no member is
## read, none is written, and nothing outside the argument is consulted.
##
## `state` is what the simulation says about a character, with these keys:
##
##   alive -- false once it is dead. Beats everything: a dead character is not
##            walking, however fast it was going when it died.
##   hurt  -- true on the tick it takes damage. Beats motion, because being hit
##            interrupts what you were doing; that is what a hit reaction is.
##   rise  -- how far it went up on the last tick, signed, in world units. A big
##            positive is a character off the ground.
##   speed -- how far it went across the ground on the last tick, in world units.
##
## Every key has a default, so a snapshot that does not carry one yet reads as
## the quiet case: alive, unhurt, on the ground. `alive` and `hurt` are the two
## the world does not produce today -- there is no combat, so nothing can be hit
## and nothing can die -- and they are branches here rather than absences because
## the rule is the thing being fixed, not the state. When combat lands and the
## snapshot starts carrying them, no line of this function changes.
static func clip_for(state: Dictionary) -> String:
	if not bool(state.get("alive", true)):
		return CLIP_DEATH
	if bool(state.get("hurt", false)):
		return CLIP_HIT
	if float(state.get("rise", 0.0)) >= HOP_RISE:
		return CLIP_JUMP
	var speed := float(state.get("speed", 0.0))
	if speed < WALK_SPEED:
		return CLIP_IDLE
	if speed < RUN_SPEED:
		return CLIP_WALK
	return CLIP_RUN


## The observer's state, read out of a simulation snapshot and nothing else.
##
## The observer is the one character the world currently holds, so this is the
## whole bridge between the snapshot and the rule above. Every key is read with
## `get` and a default so that a snapshot from a world that does not carry a key
## yet -- which is every snapshot, for `alive` and `hurt` -- reads as the quiet
## case rather than crashing.
static func observer_state(snapshot: Dictionary) -> Dictionary:
	return {
		"speed": float(snapshot.get("observer_speed", 0.0)),
		"rise": float(snapshot.get("observer_rise", 0.0)),
		"alive": bool(snapshot.get("observer_alive", true)),
		"hurt": bool(snapshot.get("observer_hurt", false)),
	}


## Which way the pack's models face in their own frame.
##
## +Z, which is the opposite of the engine's own convention, and it was measured
## rather than assumed: on every adventurer the cape and the quiver -- things
## worn on the back -- sit entirely at negative Z, and the knight's helmet visor,
## which is on his face, reaches +0.766. Getting this backwards is invisible in a
## still and unmistakable in motion, because the character moonwalks.
const MODEL_FRONT := Vector3(0.0, 0.0, 1.0)


## Which way a character walking along a heading should be turned, in radians
## about the vertical.
##
## The simulation's heading is an angle in the ground plane: it walks along
## (cos h, sin h) in (x, z), and knows nothing else about it. This is the yaw
## that puts MODEL_FRONT along that direction. It is here rather than at the call
## site because "which way is a model's front" is a fact about the pack, and the
## pack is this layer's business.
static func yaw_for_heading(heading: float) -> float:
	return atan2(cos(heading), sin(heading))


## Where a character turned for a heading is actually facing, as a direction in
## the ground plane. The inverse of the line above, for whoever wants to check it
## rather than trust it.
static func facing_for_heading(heading: float) -> Vector3:
	return Basis(Vector3.UP, yaw_for_heading(heading)) * MODEL_FRONT


# --- The scene -----------------------------------------------------------


func _ready() -> void:
	_wire()


## Find the scene's own nodes and build the blend graph, once.
##
## Called from _ready(), which is when this happens in the game, and again from
## the two entry points below, which is what makes the view work for a caller
## holding it outside a running tree -- a contact sheet posing a character, or a
## test stepping one by hand. Idempotent: the second call finds the graph already
## built and returns.
func _wire() -> void:
	if _tree != null:
		return
	_mount = get_node("Model") as Node3D
	_player = get_node("AnimationPlayer") as AnimationPlayer
	_tree = get_node("AnimationTree") as AnimationTree
	_build_tree()
	_tree.active = true
	# A model may have been asked for before this ran, in which case the mount
	# could not be wired yet. Now it can.
	if model_tag != "" and _model == null:
		_mount_model(model_tag)


## Wear a different model, keeping everything above it exactly as it was.
##
## This is the swap the whole shape of the scene exists for. The player, the
## tree, the library and the sockets are untouched; only the child under the
## mount is replaced and the three things that point *into* it are re-pointed.
## A character mid-stride goes on striding, because the clip and its position
## live in the tree and the tree was never inside the model.
func set_model(tag: String) -> void:
	if tag == model_tag and _model != null:
		return
	# Wired before the tag is recorded, so that wiring -- which mounts whatever
	# tag is already recorded -- cannot mount this one and then have it mounted
	# again below.
	_wire()
	model_tag = tag
	_mount_model(tag)


## Draw one frame of a character in this state.
##
## `state` is the dictionary clip_for() takes. Everything about which clip and
## how far into the blend comes out of it; `delta` only paces the cross-fade,
## which is a property of the picture rather than of the world.
func apply(state: Dictionary, delta: float) -> void:
	_wire()
	if not _tree.active:
		# Something took a still through pose(), which stops the tree so the
		# player can hold a frame. Drawing a live character resumes it.
		_tree.active = true
	var wanted := clip_for(state)

	# The locomotion axis follows the speed whatever else is happening, so a
	# character that was running when it was hit is running again when the hit
	# finishes, without the hit having had to remember it.
	var speed := float(state.get("speed", 0.0))
	_blend = lerpf(_blend, speed, clampf(delta * BLEND_CHASE, 0.0, 1.0))
	_tree.set("parameters/locomotion/blend_position", _blend)

	var dead := wanted == CLIP_DEATH
	_death_clip.animation = CLIP_DEATH
	_tree.set("parameters/death/blend_amount", 1.0 if dead else 0.0)

	if wanted == _shown_clip:
		return
	_shown_clip = wanted
	if dead:
		_tree.set("parameters/shot/request",
			AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		return
	if wanted == CLIP_JUMP or wanted == CLIP_HIT:
		_shot_clip.animation = wanted
		_tree.set("parameters/shot/request",
			AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		return
	# Back to standing, walking or running: whatever was laid over the locomotion
	# is no longer wanted, and the blend below it is already carrying the answer.
	_tree.set("parameters/shot/request",
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


## Which clip is on screen right now. Diagnostic and test-facing: apply() decides
## it from the state alone, so this only ever repeats what the rule said.
func shown_clip() -> String:
	return _shown_clip


## The model currently mounted, or null. For a test that wants to look inside.
func model() -> Node3D:
	return _model


## The skeleton the sockets are following, or null.
func skeleton() -> Skeleton3D:
	return _skeleton


## Advance the blend tree by hand, for a caller with no frame loop -- a test, or
## a contact sheet holding a pose. In the game the tree advances itself.
func step_animation(delta: float) -> void:
	_wire()
	_tree.advance(delta)


## Hold one named clip at one moment of it, and stop.
##
## This is the still-photograph route and it deliberately bypasses the blend
## tree: a contact sheet wants a character *at* the ninth frame of a death, not
## somewhere in a cross-fade towards it. Nothing in the game calls it.
func pose(clip: String, at: float) -> void:
	_wire()
	if not _player.has_animation(clip):
		push_error("CharacterView: no clip '%s' to pose" % clip)
		return
	_tree.active = false
	_player.play(clip)
	_player.advance(at)
	_player.pause()


# --- Wiring --------------------------------------------------------------


## The blend graph, built once and never rebuilt.
##
##   locomotion (blend space on speed) -> shot (one-off over it) -> death -> out
##
## Three nodes because there are three kinds of thing a character can be doing at
## once: it is always somewhere on the standing-walking-running axis, it may have
## something brief laid over that, and it may be dead, which replaces both.
func _build_tree() -> void:
	var graph := AnimationNodeBlendTree.new()

	_locomotion = AnimationNodeBlendSpace1D.new()
	_locomotion.min_space = BLEND_IDLE
	_locomotion.max_space = BLEND_RUN
	_locomotion.add_blend_point(_clip_node(CLIP_IDLE), BLEND_IDLE, -1, CLIP_IDLE)
	_locomotion.add_blend_point(_clip_node(CLIP_WALK), BLEND_WALK, -1, CLIP_WALK)
	_locomotion.add_blend_point(_clip_node(CLIP_RUN), BLEND_RUN, -1, CLIP_RUN)
	graph.add_node("locomotion", _locomotion, Vector2(0.0, 0.0))

	_shot_clip = _clip_node(CLIP_JUMP)
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = SHOT_FADE
	shot.fadeout_time = SHOT_FADE
	graph.add_node("shot", shot, Vector2(260.0, 0.0))
	graph.add_node("shot_clip", _shot_clip, Vector2(260.0, 140.0))
	graph.connect_node("shot", 0, "locomotion")
	graph.connect_node("shot", 1, "shot_clip")

	_death_clip = _clip_node(CLIP_DEATH)
	var death := AnimationNodeBlend2.new()
	graph.add_node("death", death, Vector2(520.0, 0.0))
	graph.add_node("death_clip", _death_clip, Vector2(520.0, 140.0))
	graph.connect_node("death", 0, "shot")
	graph.connect_node("death", 1, "death_clip")

	graph.connect_node("output", 0, "death")
	_tree.tree_root = graph


func _clip_node(clip_name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = clip_name
	return node


## Put a model under the mount and point everything that reads into it at the
## new one: the player's root, the sockets' skeleton, and the library for
## whichever rig the table says this model wears.
func _mount_model(tag: String) -> void:
	var was_playing := _tree.active
	if _model != null:
		_mount.remove_child(_model)
		_model.queue_free()
		_model = null
		_skeleton = null

	var built := AssetLibrary.build(tag)
	if built == null:
		push_error("CharacterView: '%s' has no visual" % tag)
		return
	_mount.add_child(built)
	_model = built
	models_mounted += 1

	# The clips address bones through the path the pack's own files use, which
	# starts at the model's own root: "Rig_Medium/Skeleton3D:hips". Pointing both
	# players' roots at the model is what makes that path resolve, and together
	# with the library below it is the whole of what a swap has to redo.
	#
	# Two mixers, one library, one root, and a clear division of labour. The tree
	# is what runs in the game: it blends standing into walking into running and
	# lays a one-off over the result, and it holds the library directly rather
	# than sourcing it from the player, so it works for a caller holding a
	# character outside a running scene tree -- a contact sheet, a test. The
	# player is for playing one named clip outright and stopping on a frame of
	# it, which is how a still of a death or a jump gets taken. Only one of them
	# is ever running, so they never write the same bone in the same frame.
	_player.root_node = _player.get_path_to(_model)
	_tree.root_node = _tree.get_path_to(_model)

	var row := AssetLibrary.visual(tag)
	var rig := "" if row == null else row.scene_rig
	for mixer in [_player, _tree]:
		if mixer.has_animation_library(""):
			mixer.remove_animation_library("")
		if rig != "":
			var shared := CharacterRig.library(rig)
			if shared != null:
				mixer.add_animation_library("", shared)

	_skeleton = _find_skeleton(_model)
	for socket_name in SOCKET_BONES:
		var socket := get_node_or_null(NodePath(socket_name)) as BoneAttachment3D
		if socket == null:
			continue
		if _skeleton == null:
			socket.set_use_external_skeleton(false)
			continue
		socket.set_use_external_skeleton(true)
		socket.set_external_skeleton(socket.get_path_to(_skeleton))
		socket.bone_name = SOCKET_BONES[socket_name]

	# The tree is re-activated rather than rebuilt: its graph, its blend position
	# and how far into the clip it is were never in the model and are still here.
	_tree.active = was_playing


static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
