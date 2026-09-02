extends RefCounted
## The animation half of the asset table: which skeleton a model wears, and the
## one library of clips that plays on everything wearing it.
##
## `W-creature-packs` measured the packs rather than trusting them, and found
## one answer that decides the shape of this whole file: all six adventurers and
## all four skeleton enemies carry the *same* 23-bone rig, named `Rig_Medium` --
## same bone names, same parentage, same rest pose. A Godot animation track
## addresses a bone by name, so one library of clips plays on all ten models.
## That is why this is a table keyed by *rig* and not by model: assembling the
## clips once per model would be ten copies of one thing, and would make
## "swap which adventurer this is" mean "rebuild the animations".
##
## A second rig exists and is deliberately kept apart. `Rig_Large` has the same
## twenty-three bone *names* and a rest pose about 1.8 times taller, so the
## engine will happily play a Large clip on a Medium character and hand back a
## stretched one. Nothing on disk is skinned to it -- the pack ships the clips
## and a bare mannequin and no character -- so it has an entry here, its own
## library, and no tag pointing at it. That entry is the demonstration that the
## sharing above is a measured fact and not a default: two rigs, two libraries,
## and a library is shared exactly as far as the skeleton is.
##
## Nothing here knows what any character is *doing*. Which clip out of the
## library plays is decided in CharacterView, per frame, out of the simulation's
## snapshot. This file only makes the clips available to be chosen from.
class_name CharacterRig

## The rig every shippable character wears. The node above the `Skeleton3D` is
## literally named this in all ten model files.
const RIG_MEDIUM := "Rig_Medium"

## The taller rig, which nothing is skinned to yet. Same bone names, different
## rest pose.
const RIG_LARGE := "Rig_Large"

const RIGS := [RIG_MEDIUM, RIG_LARGE]

## How many bones the shared rig has. Checked against the models rather than
## assumed: a file whose parent node says `Rig_Medium` is not necessarily it --
## the animation pack's own `Mannequin_Medium.glb` says so and ships 21.
const RIG_MEDIUM_BONES := 23

## The clip files each rig's library is assembled from.
##
## Two of the eight `Rig_Medium` files, because two of them hold every clip
## anything can currently be asked to play: `General` carries the idles, the two
## hits and the two deaths, and `MovementBasic` carries the walks, the runs and
## the five jump states. The other six -- CombatMelee, CombatRanged, Tools,
## Simulation, Special, MovementAdvanced, 106 clips between them -- are not
## loaded because nothing yet produces the state that would choose one: there is
## no combat, no inventory and no interaction. Adding one is adding one line
## here, and the library it lands in is still the one library.
const CLIP_FILES := {
	RIG_MEDIUM: [
		"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_General.glb",
		"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb",
	],
	RIG_LARGE: [
		"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Large/Rig_Large_General.glb",
		"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Large/Rig_Large_MovementBasic.glb",
	],
}

## The clips that are meant to run until something stops them, rather than to
## play once and hold their last pose. Standing, walking and running are states
## you are in; being hit, jumping and dying are things that happen to you.
##
## This is a property of the clip, not of the character, which is why it lives
## beside the library rather than beside whoever plays it.
const LOOPING_CLIPS := [
	"Idle_A", "Idle_B",
	"Walking_A", "Walking_B", "Walking_C", "Walking_Backwards",
	"Running_A", "Running_B",
	"Jump_Idle",
]

## The T-pose every clip file repeats. It is the rest pose with a name, not an
## animation, and a library that carries it invites something to play it.
const REST_CLIP := "T-Pose"

## How many libraries have actually been assembled. Diagnostic, and the number a
## test reads to show that ten models sharing a skeleton cost one assembly
## rather than ten.
static var libraries_assembled: int = 0

# rig name -> the assembled AnimationLibrary. Built on first use and kept, so
# the second character of a rig costs nothing.
static var _libraries := {}


## The library of clips for a rig, assembled on first ask and shared after.
##
## The same object comes back every time, which is the point: two characters on
## the same skeleton hold the same library, so there is one copy of the clips in
## memory however many characters are standing in the world.
static func library(rig: String) -> AnimationLibrary:
	if _libraries.has(rig):
		return _libraries[rig]
	if not CLIP_FILES.has(rig):
		push_error("CharacterRig: no clip files for rig '%s'" % rig)
		return null

	var assembled := AnimationLibrary.new()
	for path in CLIP_FILES[rig]:
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("CharacterRig: '%s' will not load" % path)
			continue
		var scene := packed.instantiate()
		var player := scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if player == null:
			push_error("CharacterRig: %s has no AnimationPlayer" % path)
			scene.free()
			continue
		for clip_name in player.get_animation_list():
			if clip_name == REST_CLIP or assembled.has_animation(clip_name):
				continue
			# Duplicated because the loop flag below is written on it, and the
			# resource it came from belongs to the engine's cache of that file.
			# A library that edited it would be editing the pack.
			var clip: Animation = player.get_animation(clip_name).duplicate()
			clip.loop_mode = (Animation.LOOP_LINEAR
				if clip_name in LOOPING_CLIPS else Animation.LOOP_NONE)
			assembled.add_animation(clip_name, clip)
		scene.free()

	_libraries[rig] = assembled
	libraries_assembled += 1
	return assembled


## The clip names a rig's library holds, sorted. For the report and for tests.
static func clips(rig: String) -> PackedStringArray:
	var found := library(rig)
	if found == null:
		return PackedStringArray()
	var names := PackedStringArray()
	for clip_name in found.get_animation_list():
		names.append(clip_name)
	names.sort()
	return names


## Forget every assembled library, so the next ask rebuilds it. For tests that
## want to count assemblies from a known start.
static func forget() -> void:
	_libraries = {}
	libraries_assembled = 0
