extends TestSuite
## A motion per item: the clip a blow is drawn with, chosen by the blow's own tag.
##
## `sim/attack.gd` has carried an animation tag on every attack since the effect
## base landed, and `sim/asset_tags.gd` names the seven motions there are --
## lunge, slash, swing, shoot, cast, spin, bash. Nothing drew them. The rig
## loaded two of its eight clip files, and `CharacterView.clip_for()` branched on
## standing, walking, running, jumping, being hit and being dead, with no branch
## for striking a blow. This is that branch, the two files the clips come out of,
## and the table between the two vocabularies.
##
## Seven claims:
##
##   1. **The library holds every clip the rule can ask for**, the seven motions
##      and the fallback included -- which is how the two combat clip files being
##      loaded is checked, rather than by reading the list of files.
##   2. **The table is checked against the catalog.** Every key is one of the
##      seven tags the simulation names, all seven have a row, every clip named
##      is in the library, and every row's length in ticks is the clip's own
##      length at the shell's rate. A typo in any of the four is a failure here,
##      not a character standing still in a fight.
##   3. **The attack branch keeps `clip_for()` pure**, held to the same test the
##      six branches before it are: the same state gives the same clip whatever
##      was drawn before, and the comparison is shown to be able to fail.
##   4. **Seven weapons in one seeded run each play their own motion.** The
##      catalogue's seven weapons stand on one board and fight; every blow the
##      run lands is drawn with the clip its own tag names, read off the
##      snapshot the render layer actually receives.
##   5. **The motion runs while the blow is being struck and ends when it ends**,
##      measured against the tick the record says it began on -- present on that
##      tick and on every tick until the clip's length has passed, gone after.
##   6. **A motion with no clip falls back to something visible**, and how many
##      of the catalogue's attacks take that fallback is counted rather than
##      assumed: today it is none of them.
##   7. **The simulation still names no clip.** Not a scan for asset paths, which
##      `AssetCheck` already does, but for the clip names in this table: the
##      pack's own words must appear under `render/` and nowhere else.
class_name TestAttackClips

## Which rig the clips are checked against. The one every shippable character
## wears, and the only one anything can swing on.
const RIG := CharacterRig.RIG_MEDIUM

## The four clip files that stay unloaded, named so that "unloaded" is checked
## against the files rather than asserted in a comment.
const UNLOADED_FILES := [
	"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_Tools.glb",
	"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_Simulation.glb",
	"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_Special.glb",
	"res://assets/kaykit_character_animations/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_MovementAdvanced.glb",
]

# --- The run --------------------------------------------------------------

## Where the fight is stood up and which seed the ground under it comes from. The
## same measured open meadow every other walkthrough uses, so this run invents no
## coordinate.
const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE

## The seed the control loop's continue-bias draws are hashed from. Nobody in
## this run has a decision function, so the loop only moves the clock -- but it
## moves it, and a blow that says which tick it began on needs a clock that runs.
const LOOP_SEED := 99

## How far out from the middle the commanders are placed, in world units.
##
## Ten rather than the six a duel is stood up at, and the difference is the
## staff: its fireball lands four cells ahead, and seven commanders dropped on
## top of each other are all already inside each other's shorter patterns before
## anybody with a longer one gets a shot. At ten, every one of the seven weapons
## is used before the fight is over.
const APART := 10.0

## How long the run is watched for, in ticks. Long enough for the longest
## cooldown in the catalogue -- the staff's five turns -- to come round, and for
## the fight it belongs to to end and the next to begin.
const TICKS := 240

## How tough the commanders are and how strong their weapons are, and these are
## deliberately far apart. The level a commander is gives it hit points; the
## level a weapon is forged at gives it damage. Tough commanders holding weak
## weapons make a long fight, and a long fight is one where every cooldown comes
## round rather than one that is over before the slowest weapon has fired.
const LEVEL := 20
const WEAPON_LEVEL := 1

## Who fights, and with what: the catalogue's seven weapons, one each, in the
## catalogue's own order. Named rather than taken from `Weapon.catalogue()` so
## that a weapon added to the catalogue does not silently change this run.
const FIGHTERS := ["Ash", "Bryn", "Cade", "Dell", "Esk", "Finn", "Gale"]

## What each of them is drawn as. Seven different models out of the catalogue,
## for one reason: a photograph of this run has to show which of them is which,
## and seven knights would not. Nothing in the fight reads it -- an appearance is
## a tag, and the pieces, the patterns and the damage are the same whichever one
## is set.
const LOOKS := [
	AssetTags.KNIGHT, AssetTags.BARBARIAN, AssetTags.MAGE, AssetTags.ROGUE,
	AssetTags.RANGER, AssetTags.HOODED_ROGUE, AssetTags.SKELETON_WARRIOR,
]


func _init() -> void:
	suite_name = "attack clips"


func run() -> void:
	var played := play()
	_the_library_holds_every_clip(played)
	_the_table_is_checked_against_the_catalog()
	_the_attack_branch_is_pure()
	_the_branch_reaches_every_motion()
	_every_weapon_plays_its_own_motion(played)
	_the_motion_runs_while_the_blow_does(played)
	_a_motion_with_no_clip_is_still_visible()
	_the_simulation_names_no_clip()


# --- The fixture ----------------------------------------------------------


## The catalogue's seven weapons on one board, and what the render layer would
## have drawn on every tick of the fight.
##
## What comes back:
##
##   * `blows` -- the world's own record of every blow struck, in order.
##   * `frames` -- one row per commander per tick, exactly as the render shell
##     builds them: `CombatDiorama.placements()` of the snapshot the simulation
##     handed out, and `CharacterView.clip_for()` of the state in it.
##   * `weapons` -- who was carrying what.
##
## Nothing is drawn and no window is opened. The snapshot is the same dictionary
## `render/main.gd` draws a frame from, so a claim proved against these rows is a
## claim about what the shell puts on screen.
static func play(ticks: int = TICKS, seed_value: int = SEED) -> Dictionary:
	var staged := stage(seed_value)
	var frames: Array[Dictionary] = []
	for _step in maxi(0, ticks):
		var snapshot := advance(staged)
		frames.append_array(drawn(staged, snapshot))
	var roster: CombatantRoster = staged["roster"]
	return {
		"seed": seed_value,
		"ticks": ticks,
		"blows": roster.scene.blows.duplicate(true),
		"frames": frames,
		"weapons": staged["weapons"],
		"began": bool(staged["began"]),
	}


## The board, set out and not yet stepped.
##
## Split from `play()` above so that a workbench with a window can step the same
## run a tick at a time and draw it -- `tools/swing_sheet.sh` photographs exactly
## this fixture. One staging, two readers.
##
## What comes back: `roster` (which holds the scene), `loop` (which moves the
## clock), `weapons` (world id -> the weapon that id carries), `looks` (world id
## -> the model tag it wears) and `began`.
static func stage(seed_value: int = SEED) -> Dictionary:
	var roster := CombatantRoster.new()
	roster.scene.terrain = TerrainQuery.for_seed(seed_value)
	var weapons := _weapons()
	var carried := {}
	var looks := {}
	var anchor: Combatant = null
	for i in FIGHTERS.size():
		var angle := TAU * float(i) / float(FIGHTERS.size())
		var at := WHERE + Vector2(cos(angle), sin(angle)) * APART
		var one := roster.add(Combatant.commander_at(
			at.x, at.y, 0.0, 0.0, LEVEL, LOOKS[i]))
		(one.piece as Commander).adopt(Character.make(FIGHTERS[i], LEVEL))
		(one.piece as Commander).wield(Weapon.held(weapons[i], WEAPON_LEVEL))
		one.settle(roster.scene.terrain)
		carried[one.id] = weapons[i].weapon_name
		looks[one.id] = LOOKS[i]
		if anchor == null:
			anchor = one
	var began := roster.scene.begin_fight(anchor.id)
	return {
		"roster": roster,
		"loop": ControlLoop.on(roster.scene, LOOP_SEED),
		"weapons": carried,
		"looks": looks,
		"began": began != null and not began.refused,
	}


## One tick of the staged run, and the snapshot the render layer would receive
## for it -- in the shape `render/main.gd` is handed, with the roster's own
## snapshot under "combat".
static func advance(staged: Dictionary) -> Dictionary:
	var roster: CombatantRoster = staged["roster"]
	(staged["loop"] as ControlLoop).step()
	roster.step(roster.scene.terrain)
	return {"combat": roster.snapshot()}


## What the render layer would draw for each commander on one tick: the same two
## calls the shell makes, `CombatDiorama.placements()` and
## `CharacterView.clip_for()`, and nothing else.
static func drawn(staged: Dictionary, snapshot: Dictionary) -> Array[Dictionary]:
	var roster: CombatantRoster = staged["roster"]
	var carried: Dictionary = staged["weapons"]
	var rows: Array[Dictionary] = []
	for row in CombatDiorama.placements(snapshot):
		if not bool(row["commander"]):
			continue
		var state: Dictionary = row["state"]
		rows.append({
			"tick": roster.scene.tick,
			"id": int(row["id"]),
			"weapon": String(carried.get(int(row["id"]), "")),
			"tag": String(row["tag"]),
			"motion": String(state.get("attack", CharacterView.NO_MOTION)),
			"began": int(state.get("attack_tick", -1)),
			"alive": bool(state.get("alive", true)),
			"clip": CharacterView.clip_for(state),
			"state": state,
			# Which of this striker's blows the snapshot was still carrying, by
			# the tick each began on. The snapshot carries the last few blows of
			# the whole world and no more, so a blow can leave it while its
			# motion is still meant to be running -- and a claim about the motion
			# has to know the difference between a motion that ended and a record
			# that was dropped.
			"carried": _carried_ticks(snapshot, int(row["id"])),
		})
	return rows


## The ticks of one striker's blows that a snapshot is still carrying.
static func _carried_ticks(snapshot: Dictionary, id: int) -> PackedInt32Array:
	var ticks := PackedInt32Array()
	var combat: Dictionary = snapshot.get("combat", {})
	for blow in combat.get("blows", []):
		if int((blow as Dictionary)["from"]) == id:
			ticks.append(int((blow as Dictionary)["tick"]))
	return ticks


## The seven weapons, in the order the fighters above take them up.
static func _weapons() -> Array[Weapon]:
	return [
		Weapon.spear(), Weapon.sword(), Weapon.flail(), Weapon.staff(),
		Weapon.bow(), Weapon.dagger(), Weapon.shield(),
	]


# --- 1. The two combat files are loaded -----------------------------------


## The library holds every clip the rule can return, which is the only honest way
## to say the two combat files were loaded: a file named in a list is a string,
## and a clip found in the library is the pack on disk.
func _the_library_holds_every_clip(_played: Dictionary) -> void:
	var library := CharacterRig.library(RIG)
	check(library != null, "the %s library did not assemble" % RIG)
	if library == null:
		return
	for clip in CharacterView.clips():
		check(library.has_animation(clip),
			"the %s library has no clip '%s', which the rule can return"
				% [RIG, clip])
	# And the two files really are the ones it came out of: a clip that is only
	# in CombatMelee and one that is only in CombatRanged.
	check(library.has_animation("Melee_1H_Attack_Stab"),
		"the melee clip file is not loaded")
	check(library.has_animation("Ranged_Bow_Release"),
		"the ranged clip file is not loaded")
	# And the four that stay unloaded stay unloaded. Asked of the files rather
	# than of a list of clip names: each one is opened, and each is required to
	# hold at least one clip the library does not, which it cannot do if it was
	# loaded. Nothing produces the state that would choose a tool, an interaction
	# or a vault, so a file holding them would be paid for and never played.
	for path in UNLOADED_FILES:
		var apart := CharacterRig.assemble([path])
		var only_there := 0
		for clip in apart.get_animation_list():
			if not library.has_animation(clip):
				only_there += 1
		check(only_there > 0,
			"every clip of %s is in the library, so a file nothing chooses from is loaded"
				% path.get_file())


# --- 2. The table against the catalog -------------------------------------


func _the_table_is_checked_against_the_catalog() -> void:
	var library := CharacterRig.library(RIG)
	if library == null:
		return
	for tag in CharacterRig.MOTION_CLIPS:
		check(AssetTags.is_animation(String(tag)),
			"'%s' has a row in the motion table and is not one of the simulation's"
				% str(tag))
	for tag in AssetTags.ANIMATIONS:
		check(CharacterRig.has_motion(tag),
			"the motion '%s' has no clip, so an attack carrying it falls back" % tag)
	for tag in CharacterRig.MOTION_CLIPS:
		var clip := CharacterRig.clip_for_motion(String(tag))
		check(library.has_animation(clip),
			"the motion '%s' names the clip '%s', which the library does not hold"
				% [str(tag), clip])
		if not library.has_animation(clip):
			continue
		# How long the motion lasts is the clip's own length at the shell's rate,
		# rounded up so a motion is never cut half a tick short. Written down in
		# the table and checked here, so the two cannot drift.
		var seconds: float = library.get_animation(clip).length
		var wanted := CharacterRig.ticks_for_seconds(seconds)
		equal(CharacterRig.motion_ticks(String(tag)), wanted,
			"the motion '%s' says its clip lasts a different number of ticks than the clip does (%.3fs)"
				% [str(tag), seconds])
	# And the flinch, which is not a motion tag's clip but is measured the same
	# way and for the same reason: `CombatDiorama.struck` draws a blow landing
	# for exactly this long, so a number that had drifted from the clip would
	# leave a character flinching after the flinch was over.
	if library.has_animation(CharacterView.CLIP_HIT):
		equal(CharacterRig.HIT_TICKS,
			CharacterRig.ticks_for_seconds(
				library.get_animation(CharacterView.CLIP_HIT).length),
			"the flinch says it lasts a different number of ticks than '%s' does"
				% CharacterView.CLIP_HIT)
	# And the fallback, held to exactly the same two conditions.
	var spare := String(CharacterRig.FALLBACK_MOTION["clip"])
	check(library.has_animation(spare),
		"the fallback clip '%s' is not in the library" % spare)
	if library.has_animation(spare):
		equal(int(CharacterRig.FALLBACK_MOTION["ticks"]),
			CharacterRig.ticks_for_seconds(library.get_animation(spare).length),
			"the fallback says its clip lasts a different number of ticks than the clip does")
	# The one number this table has to share with the shell that draws it: how
	# many ticks a second is. Read out of the shell rather than restated here.
	var shell: Dictionary = load("res://render/main.gd").get_script_constant_map()
	equal(CharacterRig.TICKS_PER_SECOND, float(shell["TICKS_PER_SECOND"]),
		"the rig and the shell disagree about how many ticks a second is")


# --- 3. The branch is a pure function -------------------------------------


## The same state gives the same clip, whatever the rule was asked before. The
## deliberately broken version below is included to show the comparison can fail.
func _the_attack_branch_is_pure() -> void:
	var swinging := {"speed": 0.9, "attack": AssetTags.ANIM_SPIN, "hurt": true}
	var standing := {"speed": 0.0}
	var first := CharacterView.clip_for(swinging)
	CharacterView.clip_for(standing)
	var again := CharacterView.clip_for(swinging)
	equal(again, first, "the same state gave two different clips")
	equal(first, CharacterRig.clip_for_motion(AssetTags.ANIM_SPIN),
		"a character striking a blow is not drawn with the blow's own motion")

	# The same comparison against a rule that does remember, which has to get the
	# second answer wrong. Without this, the two lines above would pass just as
	# happily against a rule with a memory, and would prove nothing.
	_broken_clip_for(standing)
	equal(_broken_clip_for(swinging), CharacterView.CLIP_IDLE,
		"a rule that remembers what it drew answered the second state correctly, so this check proves nothing")


# What clip_for would be if it remembered what it drew last. Only ever called by
# the check above, which requires it to fail.
static var _broken_memory := ""


static func _broken_clip_for(state: Dictionary) -> String:
	if _broken_memory != "":
		return _broken_memory
	_broken_memory = CharacterView.clip_for(state)
	return _broken_memory


## Every branch of the rule, including the seven motions and the fallback, and
## what beats what.
func _the_branch_reaches_every_motion() -> void:
	for tag in AssetTags.ANIMATIONS:
		equal(CharacterView.clip_for({"attack": tag}),
			CharacterRig.clip_for_motion(tag),
			"the motion '%s' is not drawn with its own clip" % tag)
	# A tag nothing has written a clip for still draws something.
	var unknown := "a motion nobody has written down"
	equal(CharacterView.clip_for({"attack": unknown}),
		String(CharacterRig.FALLBACK_MOTION["clip"]),
		"an unknown motion did not fall back to the punch")
	not_equal(CharacterView.clip_for({"attack": unknown}), CharacterView.CLIP_IDLE,
		"an unknown motion left the character standing still")
	# Being dead beats swinging; swinging beats a wound already taken, because a
	# blow is a thing happening on this tick and a wound is a state.
	equal(CharacterView.clip_for({"attack": AssetTags.ANIM_SLASH, "alive": false}),
		CharacterView.CLIP_DEATH, "a dead character went on swinging")
	equal(CharacterView.clip_for({"attack": AssetTags.ANIM_SLASH, "hurt": true}),
		CharacterRig.clip_for_motion(AssetTags.ANIM_SLASH),
		"a wounded character stopped swinging")
	# And a state with no blow in it reads exactly as it did before this branch.
	equal(CharacterView.clip_for({"speed": 0.0}), CharacterView.CLIP_IDLE,
		"a character with no blow to strike is not standing still")
	equal(CharacterView.clip_for({"speed": 0.0, "attack": CharacterView.NO_MOTION}),
		CharacterView.CLIP_IDLE, "an empty motion tag was taken for a blow")


# --- 4. Seven weapons, seven motions --------------------------------------


func _every_weapon_plays_its_own_motion(played: Dictionary) -> void:
	check(bool(played["began"]), "the fight was refused, so there is no run")
	var blows: Array = played["blows"]
	check(blows.size() >= FIGHTERS.size(),
		"the run landed %d blows, fewer than the %d weapons in it"
			% [blows.size(), FIGHTERS.size()])
	var by_weapon := {}
	var motions := {}
	for blow in blows:
		var weapon := String((played["weapons"] as Dictionary).get(int(blow["from"]), ""))
		by_weapon[weapon] = true
		motions[String(blow["animation"])] = true
	check(by_weapon.size() >= 3,
		"only %d weapons were used in the run; the claim needs at least three"
			% by_weapon.size())
	for tag in AssetTags.ANIMATIONS:
		check(motions.has(tag),
			"the motion '%s' was never struck in the run, so nothing shows it is drawn"
				% tag)

	# And every frame that shows a motion shows that motion's own clip. This is
	# the claim: the clip is chosen by the blow's tag and by nothing else.
	var drawn := 0
	for frame in played["frames"]:
		var motion := String(frame["motion"])
		if motion == CharacterView.NO_MOTION or not bool(frame["alive"]):
			continue
		drawn += 1
		equal(String(frame["clip"]), CharacterRig.clip_for_motion(motion),
			"on tick %d a %s striking '%s' was drawn with the wrong clip"
				% [int(frame["tick"]), String(frame["weapon"]), motion])
	check(drawn > 0, "no frame of the run showed a blow being struck")


# --- 5. It runs while the blow does ---------------------------------------


## For every blow, the striker is drawn with that motion on the tick the record
## says it began on and on every tick until the clip's length has passed, and is
## not drawn with it afterwards.
##
## Measured against the record's own tick rather than by eye, and against the
## frames the render layer would have drawn rather than against the rule asked in
## the abstract.
##
## Every comparison the run offers is made. The snapshot used to carry the last
## few blows of the whole world, so in a crowd a blow could be pushed out of it
## while its motion was still meant to be running -- seven commanders swinging
## did it to 6 of this run's 123 comparisons -- and a render layer reading only
## the snapshot cannot draw what it was not handed. The window is now each
## fighter's own last few blows (`CombatantRoster.BLOWS_EACH`), which no crowd
## can empty, so a comparison skipped for want of a record is a failure rather
## than a limit. Every frame still says which of the striker's blows the snapshot
## carried, and that is what the count below is read from.
func _the_motion_runs_while_the_blow_does(played: Dictionary) -> void:
	var timed := timings(played)
	check(int(timed["checked"]) > 0,
		"no blow in the run could be timed against its own record")
	equal(int(timed["dropped"]), 0,
		"%d comparison(s) could not be made: the blow had left the snapshot before its own motion was over"
			% int(timed["dropped"]))
	for failure in timed["failures"]:
		check(false, String(failure))


## Every blow of a run timed against the frames drawn for its striker.
##
## Shared with `tools/measure_swings.sh` so that the trace a person reads and the
## claim the suite makes are one calculation. What comes back: how many
## comparisons were made, how many blows had left the snapshot before their
## motion was over, and one sentence per comparison that came out wrong.
static func timings(played: Dictionary) -> Dictionary:
	var by_striker := {}
	for frame in played["frames"]:
		var key := int(frame["id"])
		if not by_striker.has(key):
			by_striker[key] = {}
		(by_striker[key] as Dictionary)[int(frame["tick"])] = frame

	var checked := 0
	var dropped := 0
	var failures: Array[String] = []
	var blows: Array = played["blows"]
	for at in blows.size():
		var blow: Dictionary = blows[at]
		var id := int(blow["from"])
		var began := int(blow["tick"])
		var motion := String(blow["animation"])
		var lasts := CharacterRig.motion_ticks(motion)
		var next_blow := _next_blow_tick(blows, at, id)
		var ticks: Dictionary = by_striker.get(id, {})
		# The tick it began on, the last tick it should still be running, and the
		# tick after it should have stopped.
		var offsets: Array[int] = [0, maxi(0, lasts - 1), lasts]
		for offset in offsets:
			var when := began + offset
			if when >= next_blow or not ticks.has(when):
				continue
			var frame: Dictionary = ticks[when]
			if not bool(frame["alive"]):
				continue
			var still_there := (frame["carried"] as PackedInt32Array).has(began)
			if not still_there:
				# The record was dropped from the snapshot before the motion was
				# over. Nothing to draw it from, so nothing to require.
				if offset < lasts:
					dropped += 1
				continue
			checked += 1
			if offset < lasts:
				if String(frame["motion"]) != motion:
					failures.append(
						"a blow struck on tick %d with '%s' was not still being struck %d tick(s) later"
							% [began, motion, offset])
				elif int(frame["began"]) != began:
					failures.append(
						"the frame on tick %d names tick %d as the blow's start, not %d"
							% [when, int(frame["began"]), began])
			elif String(frame["motion"]) != CharacterView.NO_MOTION:
				failures.append(
					"a blow struck on tick %d was still being struck %d ticks later, after its %s clip ended"
						% [began, lasts, motion])
	return {"checked": checked, "dropped": dropped, "failures": failures}


# The tick the same striker's next blow begins on, or a tick past the end of the
# run. A motion cut off by the striker's own next blow is not a motion that
# outstayed its clip.
static func _next_blow_tick(blows: Array, after: int, id: int) -> int:
	for at in range(after + 1, blows.size()):
		if int((blows[at] as Dictionary)["from"]) == id:
			return int((blows[at] as Dictionary)["tick"])
	return 1 << 30


# --- 6. The fallback ------------------------------------------------------


## How many of the catalogue's attacks fall back, counted rather than assumed.
static func fallbacks() -> Dictionary:
	var taken := 0
	var total := 0
	var without: Array[String] = []
	for weapon in Weapon.catalogue():
		for index in weapon.attack_count():
			total += 1
			var tag := String(weapon.attack_at(index).animation_tag)
			if CharacterRig.has_motion(tag):
				continue
			taken += 1
			without.append("%s %s (%s)" % [
				weapon.weapon_name, weapon.attack_at(index).attack_name, tag])
	return {"taken": taken, "total": total, "without": without}


func _a_motion_with_no_clip_is_still_visible() -> void:
	var counted := fallbacks()
	equal(int(counted["taken"]), 0,
		"%d of the catalogue's %d attacks have no clip of their own: %s"
			% [int(counted["taken"]), int(counted["total"]), str(counted["without"])])
	# The fallback is a real clip and it is not standing still, which is the
	# whole of what "visible" means here.
	var library := CharacterRig.library(RIG)
	if library == null:
		return
	var spare := String(CharacterRig.FALLBACK_MOTION["clip"])
	check(library.has_animation(spare), "the fallback names no clip in the library")
	not_equal(spare, CharacterView.CLIP_IDLE, "the fallback is the idle")


# --- 7. The simulation names no clip --------------------------------------


## Every clip name in the table, searched for across `sim/`. `AssetCheck` already
## fails the build on an asset path under there; this is the other half of the
## same rule, and the one this item could have broken -- a clip name is not a
## path, so a simulation that named "Melee_1H_Attack_Stab" would pass that check
## and still know what a swing looks like.
func _the_simulation_names_no_clip() -> void:
	var names := CharacterView.clips()
	var found: Array[String] = []
	for path in _files_under("res://sim"):
		var text := FileAccess.get_file_as_string(path)
		for clip in names:
			if text.contains(clip):
				found.append("%s names the clip '%s'" % [path, clip])
	check(found.is_empty(), "the simulation names a clip: %s" % str(found))


static func _files_under(directory: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var found := DirAccess.open(directory)
	if found == null:
		return paths
	for name in found.get_files():
		if name.ends_with(".gd"):
			paths.append("%s/%s" % [directory, name])
	return paths
