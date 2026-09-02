extends TestSuite
## The character view is a deliverable, so it is tested like one.
##
## Five claims, and the first is the one the other four exist to protect:
##
##   1. Which clip a character plays is a *pure function of the simulation's
##      state*. Two snapshots in, two named clips out, the same answer every
##      time, and no memory of what was drawn before. The check that this is
##      really being tested is included: the same comparison is run against a
##      deliberately broken rule and is required to fail.
##   2. Nothing under sim/ knows any of it. The tag vocabulary gained fourteen
##      names and not one clip name, model path or animation.
##   3. Models measured as sharing a skeleton share one library. Ten models, one
##      assembly; a second rig gets a second library and nothing points at it.
##   4. The scene owns the animation and the model is a swappable child: a
##      character mid-animation keeps animating across a model swap.
##   5. The rig each row names is the rig the file on disk actually has --
##      checked by opening the model, not by trusting the table.
class_name TestCharacters

## The two models the swap test uses. Both adventurers, both on the shared rig,
## so the swap is exactly the case the scene's shape exists for.
const SWAP_FROM := AssetTags.KNIGHT
const SWAP_TO := AssetTags.MAGE

## Every tag whose row names a rigged model. W-creature-packs measured all ten of
## these as carrying one skeleton; claim 5 re-checks that against the files.
const RIGGED_TAGS := [
	AssetTags.BARBARIAN, AssetTags.KNIGHT, AssetTags.MAGE,
	AssetTags.RANGER, AssetTags.ROGUE, AssetTags.HOODED_ROGUE,
	AssetTags.SKELETON_WARRIOR, AssetTags.SKELETON_ROGUE,
	AssetTags.SKELETON_MAGE, AssetTags.SKELETON_MINION,
]

## The four minions of section 3.3. No installed pack holds one as a creature;
## they resolve to board pieces, and the test says so out loud rather than
## letting a substitution pass as a model.
const MINION_TAGS := [
	AssetTags.MINION_TOADSTOOL, AssetTags.MINION_CAT,
	AssetTags.MINION_ENT, AssetTags.MINION_FROG,
]


func _init() -> void:
	suite_name = "characters"


func run() -> void:
	_the_clip_is_a_function_of_the_snapshot()
	_the_clip_test_would_notice()
	_the_rule_reaches_all_six_clips()
	_the_rule_has_no_memory()
	_the_simulation_never_names_an_animation()
	_every_character_tag_resolves()
	_one_skeleton_means_one_library()
	_the_library_holds_every_clip_the_rule_can_ask_for()
	_the_rig_a_row_names_is_the_rig_on_disk()
	_a_character_faces_the_way_it_walks()
	_a_swapped_model_carries_on_animating()
	_the_minions_are_named_as_uncovered()


# --- 1. The rule ---------------------------------------------------------


## Two snapshots, two clips. The observer standing still is idle; the observer
## walking at the speed the world actually moves it is walking.
##
## These are whole snapshots out of a real world rather than hand-built
## dictionaries: a rule that read the right key out of a dictionary nobody else
## produces would pass a test and fail the game.
func _the_clip_is_a_function_of_the_snapshot() -> void:
	var world := SimWorld.new(4242)

	# Freshly placed: nothing has moved yet.
	var standing := world.snapshot()
	equal(CharacterView.clip_for(CharacterView.observer_state(standing)),
		CharacterView.CLIP_IDLE,
		"an observer that has not moved should be standing still")

	# One step: the observer walks at SimWorld.OBSERVER_SPEED.
	world.step()
	var walking := world.snapshot()
	equal(CharacterView.clip_for(CharacterView.observer_state(walking)),
		CharacterView.CLIP_WALK,
		"an observer walking at %.2f units a tick should be walking"
			% SimWorld.OBSERVER_SPEED)

	# The two snapshots really are different in the way the rule reads, so the
	# pair above cannot be passing because both answers happened to agree.
	not_equal(float(walking["observer_speed"]), float(standing["observer_speed"]),
		"the two snapshots carry the same speed, so they test nothing")

	# And the answer does not depend on when it is asked.
	equal(CharacterView.clip_for(CharacterView.observer_state(standing)),
		CharacterView.CLIP_IDLE,
		"the standing snapshot gave a different clip the second time it was read")


## The check above, run against a rule that is broken in the one way that
## matters -- it answers out of what it answered last time instead of out of the
## state -- and required to come out wrong.
##
## A test that cannot fail proves nothing, and "this function is pure" is exactly
## the claim that quietly stops being tested. So the broken rule is kept here and
## exercised: `_broken_clip_for` is what CharacterView.clip_for would be if it
## held state, and feeding it the same two snapshots must produce the wrong
## answer for the second one. If it ever produces the right answer, the pair
## above has stopped distinguishing anything.
func _the_clip_test_would_notice() -> void:
	var world := SimWorld.new(4242)
	var standing := world.snapshot()
	world.step()
	var walking := world.snapshot()

	_broken_memory = ""
	var first := _broken_clip_for(CharacterView.observer_state(standing))
	var second := _broken_clip_for(CharacterView.observer_state(walking))
	equal(first, CharacterView.CLIP_IDLE,
		"the broken rule should still get the first snapshot right")
	not_equal(second, CharacterView.CLIP_WALK,
		"a rule that answers from memory got the walking snapshot right anyway,"
		+ " so the purity check above is not testing purity")

	# The real rule, over the same two snapshots in the same order, gets it right
	# -- which is the difference the broken one is here to measure.
	equal(CharacterView.clip_for(CharacterView.observer_state(walking)),
		CharacterView.CLIP_WALK,
		"the real rule disagreed with itself on the walking snapshot")


# What the rule would be if it remembered. Deliberately wrong: it repeats
# whatever it said last time, which is the shape of every bug where a view keeps
# a copy of the world. Nothing outside this suite may use it.
static var _broken_memory := ""


static func _broken_clip_for(state: Dictionary) -> String:
	if _broken_memory != "":
		return _broken_memory
	_broken_memory = CharacterView.clip_for(state)
	return _broken_memory


## Every one of the six clips is reachable, and each by the state that should
## reach it. Written as states rather than snapshots because two of them --
## being hit and being dead -- are states the world cannot yet produce: there is
## no combat, so nothing can hurt anything. The rule has the branches, the
## snapshot will gain the keys, and this is what says the branches work.
func _the_rule_reaches_all_six_clips() -> void:
	var cases := [
		[{"speed": 0.0}, CharacterView.CLIP_IDLE, "standing still"],
		[{"speed": SimWorld.OBSERVER_SPEED}, CharacterView.CLIP_WALK, "walking"],
		[{"speed": CharacterView.RUN_SPEED}, CharacterView.CLIP_RUN, "running"],
		[{"speed": 0.9, "rise": 1.5}, CharacterView.CLIP_JUMP, "climbing a rim"],
		[{"speed": 0.9, "hurt": true}, CharacterView.CLIP_HIT, "being hit"],
		[{"speed": 0.9, "alive": false}, CharacterView.CLIP_DEATH, "dead"],
	]
	for entry in cases:
		equal(CharacterView.clip_for(entry[0]), entry[1],
			"a character %s should play %s" % [entry[2], entry[1]])

	# The order the branches are tried in is itself a rule: a dead character is
	# not running, however fast it was going, and being hit interrupts a walk.
	equal(CharacterView.clip_for({"speed": 9.0, "rise": 9.0, "hurt": true, "alive": false}),
		CharacterView.CLIP_DEATH,
		"death should beat every other reason to play something")
	equal(CharacterView.clip_for({"speed": 9.0, "rise": 9.0, "hurt": true}),
		CharacterView.CLIP_HIT,
		"being hit should beat moving and jumping")


## The rule reads its argument and nothing else: an empty state is the quiet
## case, and a state carrying keys the rule has never heard of does not move it.
func _the_rule_has_no_memory() -> void:
	equal(CharacterView.clip_for({}), CharacterView.CLIP_IDLE,
		"a state saying nothing should be a character standing still")
	equal(CharacterView.clip_for({"speed": 2.0, "biome": "meadow", "tick": 7}),
		CharacterView.CLIP_RUN,
		"a state carrying keys the rule does not use should not change its answer")
	# A thousand calls in a row, alternating, all correct: nothing accumulates.
	for i in 500:
		equal(CharacterView.clip_for({"speed": 0.0}), CharacterView.CLIP_IDLE,
			"call %d of the alternating run gave the wrong idle" % i)
		equal(CharacterView.clip_for({"speed": 2.0}), CharacterView.CLIP_RUN,
			"call %d of the alternating run gave the wrong run" % i)


# --- 2. The simulation knows none of it ----------------------------------


## No clip name, model path or animation word appears anywhere under sim/.
##
## The project's asset check already fails the build on a path or a loader. This
## is the narrower rule this task adds: the six clip names are pack strings, and
## a simulation that named one would be deciding what a character looks like.
func _the_simulation_never_names_an_animation() -> void:
	var forbidden := PackedStringArray()
	for clip in CharacterView.CLIPS:
		forbidden.append(clip)
	forbidden.append(CharacterRig.RIG_MEDIUM)
	forbidden.append(CharacterRig.RIG_LARGE)
	forbidden.append("AnimationPlayer")
	forbidden.append("AnimationTree")
	forbidden.append("AnimationLibrary")

	var offenders := PackedStringArray()
	for path in _sim_files():
		var text := FileAccess.get_file_as_string(path)
		for word in forbidden:
			if text.contains(word):
				offenders.append("%s names '%s'" % [path, word])
	equal(offenders.size(), 0,
		"the simulation names animation: %s" % ", ".join(offenders))

	# And the check can fail: the same scan over a line that does name one.
	var sample := "var clip := \"%s\"" % CharacterView.CLIP_WALK
	check(sample.contains(CharacterView.CLIP_WALK),
		"the animation-name scan cannot see a clip name it is given")


func _sim_files() -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open("res://sim")
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.get_extension() == "gd":
			found.append("res://sim".path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return found


# --- 3. One skeleton, one library ----------------------------------------


## The fourteen new tags are in the catalog and the table resolves every one of
## them, on exactly the same terms as a fir or a well: one row, a scene path
## first and a placeholder underneath.
func _every_character_tag_resolves() -> void:
	var expected := 6 + 8
	var counted := (AssetTags.in_category(AssetTags.CHARACTERS).size()
		+ AssetTags.in_category(AssetTags.CREATURES).size())
	equal(counted, expected, "the two new categories should hold %d tags" % expected)

	for category in [AssetTags.CHARACTERS, AssetTags.CREATURES]:
		for tag in AssetTags.in_category(category):
			var row := AssetLibrary.visual(tag)
			check(row != null, "tag '%s' has no row in the table" % tag)
			if row == null:
				continue
			check(not row.scene_path.is_empty(),
				"tag '%s' names no model" % tag)
			check(row.parts.size() > 0,
				"tag '%s' has no placeholder underneath its model" % tag)
			check(row.natural_height() > 0.0,
				"tag '%s' does not say how tall it stands" % tag)
			var built := AssetLibrary.build(tag)
			check(built != null, "tag '%s' would not build" % tag)
			if built != null:
				built.free()


## Ten models on one measured skeleton hold one library between them, and the
## rig that genuinely differs holds its own.
func _one_skeleton_means_one_library() -> void:
	CharacterRig.forget()
	equal(CharacterRig.libraries_assembled, 0, "libraries should start unassembled")

	var shared := CharacterRig.library(CharacterRig.RIG_MEDIUM)
	check(shared != null, "the shared rig has no library")
	equal(CharacterRig.libraries_assembled, 1,
		"asking for the shared library once should assemble it once")

	# Every rigged tag resolves to that same object. Identity, not equality: two
	# libraries holding the same clips would still be two copies of the clips.
	for tag in RIGGED_TAGS:
		var row := AssetLibrary.visual(tag)
		if row == null:
			continue
		equal(row.scene_rig, CharacterRig.RIG_MEDIUM,
			"tag '%s' should wear the shared rig" % tag)
		check(CharacterRig.library(row.scene_rig) == shared,
			"tag '%s' got a different library object" % tag)
	equal(CharacterRig.libraries_assembled, 1,
		"ten models sharing a skeleton should cost one assembly, not ten")

	# The second rig exists, is a different library, and nothing points at it --
	# which is what makes the sharing above a measurement rather than a default.
	var large := CharacterRig.library(CharacterRig.RIG_LARGE)
	check(large != null, "the second rig has no library")
	check(large != shared, "the two rigs share one library object")
	equal(CharacterRig.libraries_assembled, 2,
		"a genuinely different skeleton should cost a second assembly")
	for tag in AssetTags.all():
		var row := AssetLibrary.visual(tag)
		if row != null:
			not_equal(row.scene_rig, CharacterRig.RIG_LARGE,
				"tag '%s' points at a rig no model on disk is skinned to" % tag)


## The shared library really holds the six clips the rule can name, each one
## loopable or not according to what kind of thing it is.
func _the_library_holds_every_clip_the_rule_can_ask_for() -> void:
	var shared := CharacterRig.library(CharacterRig.RIG_MEDIUM)
	if shared == null:
		return
	for clip in CharacterView.CLIPS:
		check(shared.has_animation(clip),
			"the shared library has no '%s' for the rule to choose" % clip)
	# Standing, walking and running run until stopped; the rest play once.
	for clip in [CharacterView.CLIP_IDLE, CharacterView.CLIP_WALK, CharacterView.CLIP_RUN]:
		if shared.has_animation(clip):
			equal(shared.get_animation(clip).loop_mode, Animation.LOOP_LINEAR,
				"'%s' should loop" % clip)
	for clip in [CharacterView.CLIP_JUMP, CharacterView.CLIP_HIT, CharacterView.CLIP_DEATH]:
		if shared.has_animation(clip):
			equal(shared.get_animation(clip).loop_mode, Animation.LOOP_NONE,
				"'%s' should play once and hold" % clip)
	# The rest pose is not an animation and is kept out.
	check(not shared.has_animation(CharacterRig.REST_CLIP),
		"the library carries the rest pose, which something could play by mistake")


## The rig a row names is the rig the file has. Opened and counted, because a
## file whose parent node says `Rig_Medium` is not necessarily it -- the
## animation pack's own mannequin says so and ships 21 bones instead of 23.
func _the_rig_a_row_names_is_the_rig_on_disk() -> void:
	var bone_sets := {}
	for tag in RIGGED_TAGS:
		var built := AssetLibrary.build(tag)
		check(built != null, "tag '%s' would not build" % tag)
		if built == null:
			continue
		check(built.get_node_or_null(NodePath(CharacterRig.RIG_MEDIUM)) != null,
			"'%s' has no node named %s" % [tag, CharacterRig.RIG_MEDIUM])
		var skeleton := CharacterView._find_skeleton(built)
		check(skeleton != null, "'%s' has no skeleton in it" % tag)
		if skeleton != null:
			equal(skeleton.get_bone_count(), CharacterRig.RIG_MEDIUM_BONES,
				"'%s' does not have the shared rig's bone count" % tag)
			var names := PackedStringArray()
			for i in skeleton.get_bone_count():
				names.append(skeleton.get_bone_name(i))
			# Sorted: the six adventurers list the same bones in six different
			# orders, and a track resolves a bone by name and never by index.
			names.sort()
			bone_sets["|".join(names)] = true
			# The two weapon sockets are part of the shared rig, which is why the
			# same socket names work on a hero and on a skeleton.
			for bone in CharacterView.SOCKET_BONES.values():
				check(skeleton.find_bone(bone) != -1,
					"'%s' has no '%s' bone for a socket to follow" % [tag, bone])
		built.free()
	equal(bone_sets.size(), 1,
		"the ten rigged models do not all carry the same set of bone names")


## A character turned for a heading faces along that heading, and the front the
## turn assumes is the front the models actually have.
##
## Two halves, and the second is the one that is easy to get wrong. The engine's
## convention is that a node faces its own -Z; these models face +Z, which is
## invisible in a still and unmistakable in motion. So it is measured off the
## art: the cape and the quiver are worn on the back and must sit behind the
## middle of the body, and the knight's visor is on his face and must sit in
## front of it.
func _a_character_faces_the_way_it_walks() -> void:
	for step in 16:
		var heading := TAU * float(step) / 16.0
		var walked := Vector3(cos(heading), 0.0, sin(heading))
		var facing := CharacterView.facing_for_heading(heading)
		check(facing.distance_to(walked) < 0.0001,
			"a character on heading %.2f faces %s and walks %s"
				% [heading, facing, walked])

	# Which way the art faces, read off the art. `back` is a piece of kit worn on
	# the back, `front` a piece worn on the face.
	var cases := [
		[AssetTags.RANGER, "Quiver", ""],
		[AssetTags.KNIGHT, "Cape", "HelmetVisor"],
	]
	for entry in cases:
		var built := AssetLibrary.build(entry[0])
		if built == null:
			continue
		var back := _mesh_centre(built, entry[1])
		check(back.z < -0.05,
			"%s's %s is not on the model's back, so +Z is not its front (z=%.3f)"
				% [entry[0], entry[1], back.z])
		if entry[2] != "":
			var front := _mesh_centre(built, entry[2])
			check(front.z > 0.05,
				"%s's %s is not on the model's face (z=%.3f)"
					% [entry[0], entry[2], front.z])
		built.free()


## The middle of the first mesh under a node whose name ends in `suffix`, in the
## node's own frame. Zero when there is no such mesh, which the caller's check
## then fails on.
func _mesh_centre(node: Node, suffix: String) -> Vector3:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.name.ends_with(suffix) and mesh.mesh != null:
			return mesh.mesh.get_aabb().get_center()
	for child in node.get_children():
		var found := _mesh_centre(child, suffix)
		if found != Vector3.ZERO:
			return found
	return Vector3.ZERO


# --- 4. The model is a swappable child -----------------------------------


## A character that is already animating keeps animating when its model is
## swapped, because the animation was never inside the model.
##
## What is checked, in order: the first model is posed away from its rest pose
## (so it really is animating); the swap replaces the model and the skeleton;
## the tree keeps the same graph and does not rebuild the shared library; and
## the *new* skeleton is posed too, from a further point in the same clip.
func _a_swapped_model_carries_on_animating() -> void:
	var before := CharacterRig.libraries_assembled
	var view: CharacterView = (load(CharacterView.SCENE) as PackedScene).instantiate()
	Engine.get_main_loop().get_root().add_child(view)
	view.set_model(SWAP_FROM)

	equal(view.model_tag, SWAP_FROM, "the view did not take the first model")
	var first := view.model()
	var first_skeleton := view.skeleton()
	check(first != null and first_skeleton != null,
		"the first model arrived without a skeleton")

	# Walk it for half a second and check the bones actually moved.
	var walking := {"speed": SimWorld.OBSERVER_SPEED}
	view.apply(walking, 1.0)
	equal(view.shown_clip(), CharacterView.CLIP_WALK,
		"the view is not playing the walk the state asks for")
	var rest := Vector3.ZERO
	var posed := Vector3.ZERO
	if first_skeleton != null:
		var bone := first_skeleton.find_bone("hips")
		rest = first_skeleton.get_bone_rest(bone).origin
		for i in 30:
			view.step_animation(1.0 / 60.0)
			view.apply(walking, 1.0 / 60.0)
		posed = first_skeleton.get_bone_pose_position(bone)
		check(rest.distance_to(posed) > 0.001,
			"the first model is not being posed, so there is nothing to carry on")

	# The swap.
	view.set_model(SWAP_TO)
	equal(view.model_tag, SWAP_TO, "the view did not take the second model")
	equal(view.models_mounted, 2, "the swap did not mount a second model")
	check(view.model() != first, "the model was not replaced")
	equal(CharacterRig.libraries_assembled, before,
		"the swap assembled a library, so the animation setup was duplicated")

	# And it carries on: same clip, same graph, and the new skeleton is posed.
	equal(view.shown_clip(), CharacterView.CLIP_WALK,
		"the swap stopped the walk the character was in the middle of")
	var second_skeleton := view.skeleton()
	check(second_skeleton != null and second_skeleton != first_skeleton,
		"the swap did not bring a new skeleton")
	if second_skeleton != null:
		var bone := second_skeleton.find_bone("hips")
		var second_rest := second_skeleton.get_bone_rest(bone).origin
		for i in 30:
			view.step_animation(1.0 / 60.0)
			view.apply(walking, 1.0 / 60.0)
		var second_posed := second_skeleton.get_bone_pose_position(bone)
		check(second_rest.distance_to(second_posed) > 0.001,
			"the swapped-in model is standing at rest instead of walking")

	view.queue_free()


# --- 5. What no pack covers --------------------------------------------


## The four minions have no creature model in any installed pack, and this says
## so by name rather than letting a board piece pass for a frog.
##
## reports/creature-packs.md measured it; this pins it, so that the day a pack
## does arrive the row and this check move together.
func _the_minions_are_named_as_uncovered() -> void:
	for tag in MINION_TAGS:
		var row := AssetLibrary.visual(tag)
		check(row != null, "minion tag '%s' has no row" % tag)
		if row == null:
			continue
		check(row.scene_rig.is_empty(),
			"minion '%s' claims a rig, but no board piece has bones" % tag)
		check(row.scene_path.contains("board_game"),
			("minion '%s' resolves to something other than the abstract board"
			+ " piece the report names it as: %s") % [tag, row.scene_path])
		var built := AssetLibrary.build(tag)
		if built != null:
			check(CharacterView._find_skeleton(built) == null,
				"minion '%s' turned out to have a skeleton after all" % tag)
			built.free()
