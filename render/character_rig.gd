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
## snapshot. This file only makes the clips available to be chosen from -- and,
## since `W-attack-clips`, says which clip stands for each of the simulation's
## seven motion tags, which is the same sort of fact: a name out of the pack
## against a name out of `sim/asset_tags.gd`, with the choosing still done next
## door.
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
## Four of the eight `Rig_Medium` files. `General` carries the idles, the two
## hits and the two deaths; `MovementBasic` carries the walks, the runs and the
## five jump states; `CombatMelee` and `CombatRanged` carry the forty attack,
## block and aim clips the seven motions below are chosen out of. The other four
## -- Tools, Simulation, Special, MovementAdvanced -- stay unloaded for the same
## reason all six used to: nothing produces the state that would choose one.
## There is no tool use, no interaction and no advanced traversal, so a table
## pointing at them would point at nothing. Adding one is adding one line here,
## and the library it lands in is still the one library.
##
## The two that were added cost what `tools/measure_clips.sh` measures rather
## than what this comment guesses. `Rig_Large` keeps the two it had: nothing is
## skinned to it, so nothing on it can swing.
const CLIP_FILES := {
	RIG_MEDIUM: [
		"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_General.glb",
		"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb",
		"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_CombatMelee.glb",
		"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_CombatRanged.glb",
	],
	RIG_LARGE: [
		"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Large/Rig_Large_General.glb",
		"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Large/Rig_Large_MovementBasic.glb",
	],
}

## The two files the combat clips came out of, named again on their own so that
## what loading them costs can be measured against the two that were there
## before. `tools/measure_clips.sh` assembles both halves through the same
## `assemble()` the game uses and prints the difference.
const COMBAT_CLIP_FILES := [
	"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_CombatMelee.glb",
	"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_CombatRanged.glb",
]


# --- The motions -----------------------------------------------------------


## How many simulation ticks one second of a clip lasts.
##
## The shell steps the world twenty times a second -- `render/main.gd`'s own
## `TICKS_PER_SECOND` -- and how long a motion lasts is the only place the two
## rates have to meet, because a blow says which tick it began on and a clip
## says how many seconds it runs for. Restated here rather than reached for,
## because a table of clips must not have to know about the shell that draws
## them; `tests/test_attack_clips.gd` reads the shell's constant and fails if the
## two ever differ, so the restatement is checked rather than trusted.
const TICKS_PER_SECOND := 20.0

## Which clip plays each of the simulation's seven motions, and for how long.
##
## The whole of the render half of "a motion per item". `sim/attack.gd` carries
## an animation tag on every attack and `sim/asset_tags.gd` names the seven tags
## there are; this is the table that turns one of those names into something the
## rig can actually do. It sits beside `CLIP_FILES` because the clip it names
## has to be in one of those files, and `tests/test_attack_clips.gd` opens the
## assembled library and checks that every one of them is.
##
## Each row is the clip's own name out of the pack and `ticks`, which is how many
## simulation ticks the clip lasts at the rate above -- rounded up, so a motion
## is never cut off half a tick early. Those numbers are measured off the clips
## rather than chosen: the same test reads each clip's length out of the library
## and fails if a row has drifted from it.
##
## Which clip suits which tag is a judgement about the pack and is made here,
## which is the only place in the project allowed to make it:
##
##   | tag | clip | why |
##   |---|---|---|
##   | lunge | Melee_1H_Attack_Stab | the spear's thrust: one hand, straight ahead |
##   | slash | Melee_1H_Attack_Slice_Diagonal | the dagger's and the sword's cut |
##   | swing | Melee_1H_Attack_Slice_Horizontal | the sword's cleave: a sweep across the arc it covers |
##   | shoot | Ranged_Bow_Release | the bow, loosing rather than drawing |
##   | cast | Ranged_Magic_Shoot | the staff's fireball, thrown rather than summoned |
##   | spin | Melee_2H_Attack_Spin | the flail's sweep, all the way round like the pattern |
##   | bash | Melee_Block_Attack | the shield's shove: a strike made from behind a guard |
const MOTION_CLIPS := {
	AssetTags.ANIM_LUNGE: {"clip": "Melee_1H_Attack_Stab", "ticks": 32},
	AssetTags.ANIM_SLASH: {"clip": "Melee_1H_Attack_Slice_Diagonal", "ticks": 20},
	AssetTags.ANIM_SWING: {"clip": "Melee_1H_Attack_Slice_Horizontal", "ticks": 28},
	AssetTags.ANIM_SHOOT: {"clip": "Ranged_Bow_Release", "ticks": 27},
	AssetTags.ANIM_CAST: {"clip": "Ranged_Magic_Shoot", "ticks": 19},
	AssetTags.ANIM_SPIN: {"clip": "Melee_2H_Attack_Spin", "ticks": 48},
	AssetTags.ANIM_BASH: {"clip": "Melee_Block_Attack", "ticks": 22},
}

## What a motion with no row above plays instead: a punch.
##
## An attack whose tag this table has never heard of still happened, and the one
## thing it must not look like is nothing at all -- a character standing
## perfectly still while somebody loses hit points is a bug that reads as a
## missing feature. A punch is the honest fallback: it is plainly a blow, it is
## plainly not the weapon's own motion, and it is short.
##
## Nothing shipped reaches it. All seven tags of the simulation's vocabulary have
## a row, and `tools/measure_clips.sh` counts how many of the catalogue's attacks
## fall through to this: today that number is zero, and the day somebody composes
## an eighth motion it will not be.
const FALLBACK_MOTION := {"clip": "Melee_Unarmed_Attack_Punch_A", "ticks": 24}


## How many simulation ticks a clip of some length lasts, rounded up so a motion
## is never cut half a tick short.
##
## The thousandth of a second taken off first is for the engine's own arithmetic
## rather than for the animation: a clip the pack authored at 1.6 seconds comes
## back as a single-precision number a hair either side of it, and without the
## slack a motion exactly thirty-two ticks long would round to thirty-three on
## some machines and thirty-two on others. This is the one definition; the table
## above is written from it and a test checks each row against it.
static func ticks_for_seconds(seconds: float) -> int:
	return maxi(1, int(ceil(seconds * TICKS_PER_SECOND - 0.001)))


## Which clip plays a motion tag, falling back to the punch for one this table
## does not name. A pure function of the tag and the constant above it.
static func clip_for_motion(tag: String) -> String:
	if MOTION_CLIPS.has(tag):
		return String((MOTION_CLIPS[tag] as Dictionary)["clip"])
	return String(FALLBACK_MOTION["clip"])


## How many simulation ticks a motion tag's clip lasts -- which is how long a
## blow struck with it is still being struck. Same fallback, same purity.
static func motion_ticks(tag: String) -> int:
	if MOTION_CLIPS.has(tag):
		return int((MOTION_CLIPS[tag] as Dictionary)["ticks"])
	return int(FALLBACK_MOTION["ticks"])


## Whether a motion tag has a clip of its own, or takes the fallback. For
## whoever is counting how many attacks fall through.
static func has_motion(tag: String) -> bool:
	return MOTION_CLIPS.has(tag)


## Every clip a motion can reach, the fallback included, in the order the table
## writes them. What a test walks to check the library holds them all.
static func motion_clips() -> PackedStringArray:
	var names := PackedStringArray()
	for tag in AssetTags.ANIMATIONS:
		if MOTION_CLIPS.has(tag):
			names.append(String((MOTION_CLIPS[tag] as Dictionary)["clip"]))
	names.append(String(FALLBACK_MOTION["clip"]))
	return names

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

	var assembled := assemble(CLIP_FILES[rig])
	_libraries[rig] = assembled
	libraries_assembled += 1
	return assembled


## One library out of a named list of clip files, assembled and handed back
## without being kept.
##
## Split out of `library()` above so that what a file costs can be measured
## through the same code the game runs -- `tools/measure_clips.sh` assembles the
## two files that were loaded before this item and the two that were added, one
## after the other, and prints the difference. A measurement taken through a
## second copy of this loop would be measuring the copy.
static func assemble(paths: Array) -> AnimationLibrary:
	var assembled := AnimationLibrary.new()
	for path in paths:
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
