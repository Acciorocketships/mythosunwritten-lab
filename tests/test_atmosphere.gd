extends TestSuite
## The lighting and atmosphere stack: what decides the mood, what is warm, what
## drifts, and -- the load-bearing one -- that none of it reaches the world.
##
## The last of those is why this suite exists in the shape it does. The stack is
## the biggest thing in the project that lives in the render shell rather than in
## the simulation, and the argument for that is that nothing in the world can
## interact with a photon: no rule reads the fog, nothing collides with a
## firefly, and the world is the same world in the dark. A claim like that has to
## be checked rather than asserted, so two checks do it from opposite ends -- a
## headless process is shown never to load a file of it, and the same seed run
## through the shell with and without the whole stack is shown to reach a
## byte-identical world.
##
## The rest is about the look itself: the fog, the sky and the fill light are the
## biome's numbers and not this layer's, the fill is warm-neutral rather than the
## blue of the sky it sits under, every warm pinpoint is warm and sits on
## something the simulation placed and the asset table draws as emissive, the
## motes thin out with the biome, the orbs wander around where the simulation put
## them without moving them, and the shadows are long and the depth of field is
## the miniature one.
class_name TestAtmosphere

const SEED := 5
const FIXED_FPS := 60
const FRAMES := 90
## FRAMES / FIXED_FPS seconds of simulated time, at the shell's tick rate of 20.
const EXPECTED_TICKS := 30

## A twilight marsh with water beside it, on seed 1234. Found by walking the
## world for marsh ground with wet cells around it; see reports/atmosphere.md.
const MARSH_X := -216.0
const MARSH_Z := -504.0

## The apparent width of the real sun, in degrees. What "soft" is measured
## against: a shadow edge is only soft because the thing casting it is lit by a
## disc rather than by a point.
const REAL_SUN_DEGREES := 0.53

## The tags whose light has to be warm. The glowing orb is deliberately not one
## of them -- it is the marsh's cold witch-light and the one cool pinpoint in the
## palette -- so it is checked separately, for being cool.
const WARM_TAGS := [
	AssetTags.LANTERN_POST, AssetTags.HANGING_LANTERN, AssetTags.CAMPFIRE,
	AssetTags.WINDOW_GLOW, AssetTags.TOADSTOOL,
]


func _init() -> void:
	suite_name = "atmosphere"


func run() -> void:
	_the_biome_decides_the_fog_the_sky_and_the_fill()
	_the_fill_light_is_warm_neutral_and_not_the_sky()
	_shadowed_stone_still_reads_as_stone()
	_every_warm_pinpoint_is_warm_and_sits_on_something_that_glows()
	_a_glowing_mushroom_lights_the_gloom_and_not_the_meadow()
	_the_bloom_only_takes_what_is_brighter_than_white()
	_the_motes_thin_out_and_brighten_with_the_biome()
	_changing_the_mote_count_rebuilds_nothing()
	_a_mote_pool_is_a_pure_function_of_the_seed()
	_the_twilight_pockets_carry_orbs_that_light_them()
	_an_orb_wanders_around_where_the_simulation_put_it()
	_the_shadows_are_long_and_soft()
	_the_depth_of_field_brackets_whatever_the_camera_is_looking_at()
	_headless_loads_no_atmosphere_at_all()
	_the_world_is_byte_identical_with_and_without_the_atmosphere()


## The mood on screen is the biome's numbers, not this layer's.
##
## Checked by handing the layer two different profiles and reading the engine
## objects back: every colour and every density that ends up on the environment
## has to be traceable to the profile it was given. Reading back rather than
## re-deriving is the point -- it is a check that the wiring goes where it is
## claimed to, which a re-derivation would not be.
func _the_biome_decides_the_fog_the_sky_and_the_fill() -> void:
	var layer := Atmosphere.new(SEED)
	var environment := layer.environment()
	var sky := layer.sky_material()
	var seen := {}
	for id in BiomeCatalog.IDS:
		var profile := BiomeCatalog.profile(id)
		layer.take(profile, Vector3(0.0, 12.0, 0.0))
		equal(environment.fog_light_color, profile.fog_color,
			"%s: the fog on screen is not the biome's fog colour" % id)
		check(is_equal_approx(environment.fog_density, profile.fog_density),
			"%s: the fog density on screen is %.5f, the biome's is %.5f"
			% [id, environment.fog_density, profile.fog_density])
		equal(environment.ambient_light_color, profile.ambient_color,
			"%s: the fill light is not the biome's ambient colour" % id)
		equal(sky.sky_top_color, profile.sky_top,
			"%s: the sky overhead is not the biome's" % id)
		equal(sky.sky_horizon_color, profile.sky_horizon,
			"%s: the horizon is not the biome's" % id)
		# The ground mist rides on the observer rather than on the world, so that
		# it lies over the floor of whatever valley is being stood in.
		check(is_equal_approx(environment.fog_height, 12.0 + Atmosphere.MIST_HEIGHT),
			"%s: the mist ceiling is at %.2f, not %.2f above the observer"
			% [id, environment.fog_height, Atmosphere.MIST_HEIGHT])
		check(environment.fog_height_density > 0.0,
			"%s: there is no ground mist at all" % id)
		seen[id] = [profile.fog_color, profile.sky_top, profile.ambient_color]

	# And the five are actually five different moods, or the check above would
	# pass on a table of identical rows.
	var distinct := {}
	for id in seen:
		distinct[str(seen[id])] = true
	equal(distinct.size(), BiomeCatalog.IDS.size(),
		"only %d of the %d biomes carry a distinct fog/sky/fill"
		% [distinct.size(), BiomeCatalog.IDS.size()])
	layer.dispose()


## The fill light is warm-neutral, not the blue of the sky over it.
##
## This is the one line of the global grade that is easy to get wrong and hard to
## see: taking the ambient from the sky is the default in most engines and it
## pours blue into every shadow. Measured per unit brightness, because the marsh
## sky is nearly black and comparing raw channel differences against it would
## flatter any ambient at all.
func _the_fill_light_is_warm_neutral_and_not_the_sky() -> void:
	for id in BiomeCatalog.IDS:
		var profile := BiomeCatalog.profile(id)
		var fill := _blue_bias(profile.ambient_color)
		var sky := _blue_bias(profile.sky_top)
		check(fill <= sky * 0.5,
			"%s: the fill light leans %.2f towards blue per unit brightness and "
			% [id, fill] + "the sky over it %.2f -- the fill is the sky" % sky)
		check(fill < 0.75,
			"%s: the fill light leans %.2f towards blue, which is not warm-neutral"
			% [id, fill])

	# And the environment is actually told to use that colour rather than to
	# sample the sky, which is the setting the whole paragraph rests on.
	var layer := Atmosphere.new(SEED)
	equal(layer.environment().ambient_light_source, Environment.AMBIENT_SOURCE_COLOR,
		"the fill light is being sampled from the sky instead of taken from the "
		+ "biome's warm-neutral ambient colour")
	layer.dispose()


## Stone lit only by the fill light is still stone-coloured.
##
## The statement the last check makes about the light, made again about what the
## light does to something: a boulder in shadow is lit by the ambient alone, so
## its colour there is the rock tint multiplied by the fill. If the fill were the
## sky, that product would be a different colour from the rock -- blue-grey
## instead of grey. The hue is compared rather than the brightness, because a
## shadow is of course darker; only its colour is in question.
func _shadowed_stone_still_reads_as_stone() -> void:
	for id in BiomeCatalog.IDS:
		var profile := BiomeCatalog.profile(id)
		var lit := Color(
			profile.rock_tint.r * profile.ambient_color.r,
			profile.rock_tint.g * profile.ambient_color.g,
			profile.rock_tint.b * profile.ambient_color.b,
		)
		var shift := absf(_blue_bias(lit) - _blue_bias(profile.rock_tint))
		# The absolute bound is asked of the biomes that are meant to read as
		# daylight. The twilight marsh is deliberately teal gloom -- it is the
		# eerie pocket, and stone in it is supposed to go cold -- so there the
		# claim is only the relative one below: the warm fill still shifts it far
		# less than filling from that biome's own sky would.
		if Atmosphere.gloom_of(profile) < 0.5:
			check(shift < 0.30,
				"%s: stone in shadow shifts %.2f towards blue against the stone in "
				% [id, shift] + "the light, so it stops reading as stone")
		# Against the control: the same stone lit by the sky instead, which is
		# what the setting above is a decision not to do.
		var by_sky := Color(
			profile.rock_tint.r * profile.sky_top.r,
			profile.rock_tint.g * profile.sky_top.g,
			profile.rock_tint.b * profile.sky_top.b,
		)
		var sky_shift := absf(_blue_bias(by_sky) - _blue_bias(profile.rock_tint))
		check(shift < sky_shift,
			"%s: filling with the warm ambient shifts stone %.2f and filling "
			% [id, shift] + "with the sky %.2f -- the ambient is no better"
			% sky_shift)


## Every warm pinpoint is warm, and sits on something the simulation places and
## the asset table draws as emissive.
##
## The second half is what stops this being a table checking itself. A light on a
## tag nothing places would never be seen; a light on a tag the table draws as
## matte would be a glow with no source, hanging in the air over a dark object.
func _every_warm_pinpoint_is_warm_and_sits_on_something_that_glows() -> void:
	AssetLibrary.restore_defaults()
	for tag in Atmosphere.GLOWING_TAGS:
		var settings: Dictionary = Atmosphere.GLOWING_TAGS[tag]
		check(AssetTags.is_tag(tag),
			"'%s' has a warm light but is not a tag the simulation can place" % tag)
		check(float(settings["energy"]) > 0.0 and float(settings["range"]) > 0.0,
			"%s: a light with no energy or no reach" % tag)
		var row := AssetLibrary.visual(tag)
		check(row != null, "%s: no row in the asset table to hang a light on" % tag)
		if row == null:
			continue
		var emissive := 0
		for part in row.parts:
			if float(part["emission"]) > 0.0:
				emissive += 1
		check(emissive >= 1,
			"%s carries a point light but the asset table draws it matte, so the "
			% tag + "light would have no visible source")

	for tag in WARM_TAGS:
		var colour: Color = Atmosphere.GLOWING_TAGS[tag]["color"]
		check(colour.r > colour.g and colour.g > colour.b,
			"%s: the light is %s, which is not warm" % [tag, colour])

	# The one deliberate exception, checked for being the exception rather than
	# quietly skipped: the marsh's orb is the cold light of the palette.
	var orb: Color = Atmosphere.GLOWING_TAGS[AssetTags.GLOWING_ORB]["color"]
	check(orb.b > orb.r and orb.g > orb.r,
		"the glowing orb is meant to be the one cool pinpoint, but it is %s" % orb)


## A glowing mushroom lights the gloom and not an open meadow.
##
## There are hundreds of toadstools in a marsh view and a point light each is a
## real cost, so they only cast where casting reads. Checked on the two biomes
## either side of the line and on the rule that draws it.
func _a_glowing_mushroom_lights_the_gloom_and_not_the_meadow() -> void:
	var layer := Atmosphere.new(SEED)
	var marsh := BiomeCatalog.profile(BiomeCatalog.TWILIGHT_MARSH)
	var meadow := BiomeCatalog.profile(BiomeCatalog.MEADOW)

	var in_marsh := layer.light_for(AssetTags.TOADSTOOL, marsh)
	check(in_marsh != null, "a toadstool in the twilight marsh casts no light")
	if in_marsh != null:
		check(in_marsh.omni_range > 0.0, "the toadstool's light has no reach")
		in_marsh.free()
	var in_meadow := layer.light_for(AssetTags.TOADSTOOL, meadow)
	check(in_meadow == null,
		"a toadstool in an open meadow carries a point light, which costs a "
		+ "light and lights nothing anyone can see")
	if in_meadow != null:
		in_meadow.free()

	# A lantern is a lantern anywhere, which is the other half of the rule.
	var lantern := layer.light_for(AssetTags.LANTERN_POST, meadow)
	check(lantern != null, "a lantern post in a meadow casts no light")
	if lantern != null:
		lantern.free()
	# And the gloom the rule reads is the biome's own fog, ordered as the biomes
	# are: the marsh is the gloomiest and the meadow the clearest.
	check(Atmosphere.gloom_of(marsh) > Atmosphere.gloom_of(meadow),
		"the marsh is not measured as gloomier than the meadow")
	layer.dispose()


## The bloom takes what is brighter than white and nothing else.
##
## A threshold below white blooms pale walls and sky, which is the difference
## between a cosy glow and a hazy smear. The emissive things the world actually
## holds are far above it -- the asset table drives a lantern bulb at several
## times white -- so this checks the threshold against what has to bloom.
func _the_bloom_only_takes_what_is_brighter_than_white() -> void:
	var layer := Atmosphere.new(SEED)
	var environment := layer.environment()
	check(environment.glow_enabled, "there is no bloom at all")
	check(environment.glow_hdr_threshold >= 1.0,
		"the bloom threshold is %.2f, below white, so unlit surfaces will bloom"
		% environment.glow_hdr_threshold)
	check(environment.glow_intensity > 0.0 and environment.glow_strength > 0.0,
		"the bloom has no intensity")

	AssetLibrary.restore_defaults()
	var brightest := 0.0
	for tag in Atmosphere.GLOWING_TAGS:
		var row := AssetLibrary.visual(tag)
		if row == null:
			continue
		for part in row.parts:
			brightest = maxf(brightest, float(part["emission"]))
	check(brightest > environment.glow_hdr_threshold,
		"the brightest emissive in the world is %.2f and the bloom threshold is "
		% brightest + "%.2f, so nothing would ever bloom"
		% environment.glow_hdr_threshold)
	layer.dispose()


## How thickly the motes drift, and how brightly, comes from the biome.
##
## The rule is stated in MoteField and checked here against the ordering it is
## meant to produce rather than against the numbers it happens to produce: the
## eerie enclosed hollow carries the most fireflies and the bare windswept tops
## the fewest, which is what section 9.9 asks for.
func _the_motes_thin_out_and_brighten_with_the_biome() -> void:
	var density := {}
	var brightness := {}
	for id in BiomeCatalog.IDS:
		var profile := BiomeCatalog.profile(id)
		density[id] = MoteField.density_for(profile)
		brightness[id] = MoteField.brightness_for(profile)
		check(density[id] >= 0.0 and density[id] <= 1.0,
			"%s: mote density %.3f is outside [0, 1]" % [id, density[id]])

	var thickest := ""
	var thinnest := ""
	for id in density:
		if thickest == "" or density[id] > density[thickest]:
			thickest = id
		if thinnest == "" or density[id] < density[thinnest]:
			thinnest = id
	equal(thickest, BiomeCatalog.TWILIGHT_MARSH,
		"the thickest firefly cloud is in %s, not the twilight marsh" % thickest)
	equal(thinnest, BiomeCatalog.HIGHLAND,
		"the thinnest firefly cloud is in %s, not the bare highland" % thinnest)
	check(density[thickest] > density[thinnest] * 2.0,
		"the marsh carries %.2f of the motes and the highland %.2f -- the "
		% [density[thickest], density[thinnest]]
		+ "difference between biomes is not visible")

	# A mote burns brighter where there is less other light, which is what makes
	# it the light source of a twilight pocket rather than a speck in a meadow.
	check(brightness[BiomeCatalog.TWILIGHT_MARSH] > brightness[BiomeCatalog.MEADOW],
		"a firefly is no brighter in the twilight marsh than in an open meadow")

	# And a border is a gradient in the motes too, because the profile it reads
	# is a blend: halfway between two biomes is halfway between their densities.
	var half := BiomeCatalog.blend({
		BiomeCatalog.MEADOW: 0.5, BiomeCatalog.TWILIGHT_MARSH: 0.5,
	})
	var between := MoteField.density_for(half)
	check(
		between > density[BiomeCatalog.MEADOW] and between < density[BiomeCatalog.TWILIGHT_MARSH],
		"halfway across a meadow/marsh border the motes are at %.2f, outside the "
		% between + "%.2f to %.2f the two sides carry"
		% [density[BiomeCatalog.MEADOW], density[BiomeCatalog.TWILIGHT_MARSH]])


## Changing how many motes are drawn rebuilds nothing.
##
## The same trick the grass uses for its level of detail, and it matters more
## here: the biome under a walking observer changes continuously, so if thinning
## the cloud re-hashed the pool then every step across a border would cost a
## rebuild -- and, worse, every mote on screen would jump.
func _changing_the_mote_count_rebuilds_nothing() -> void:
	var field := MoteField.new(SEED)
	var view := field.view()
	var before := view.multimesh.buffer
	var count := view.multimesh.instance_count

	field.take(BiomeCatalog.profile(BiomeCatalog.TWILIGHT_MARSH))
	var thick := view.multimesh.visible_instance_count
	field.take(BiomeCatalog.profile(BiomeCatalog.HIGHLAND))
	var thin := view.multimesh.visible_instance_count

	check(thin < thick,
		"the highland draws %d motes and the marsh %d -- the biome is not "
		% [thin, thick] + "reaching the cloud")
	equal(view.multimesh.instance_count, count,
		"thinning the cloud changed the size of the pool")
	equal(view.multimesh.buffer, before,
		"thinning the cloud rewrote the instance buffer, so every mote on "
		+ "screen would jump as the observer crossed a border")
	view.free()


## A mote pool is a pure function of the seed.
func _a_mote_pool_is_a_pure_function_of_the_seed() -> void:
	var one := MoteField.new(SEED)
	var two := MoteField.new(SEED)
	var other := MoteField.new(SEED + 1)
	equal(one.view().multimesh.buffer, two.view().multimesh.buffer,
		"two mote clouds built from the same seed differ")
	not_equal(one.view().multimesh.buffer, other.view().multimesh.buffer,
		"two mote clouds built from different seeds are identical")

	# The pool is spread through the box rather than filled in order, which is
	# what lets a prefix of it be drawn without clearing one corner of the view.
	# Checked on the first tenth: if it were ordered, that tenth would sit in a
	# tenth of the box.
	var buffer: PackedFloat32Array = one.view().multimesh.buffer
	var prefix := maxi(16, MoteField.COUNT / 10)
	var low := INF
	var high := -INF
	for at in prefix:
		var x := buffer[at * 20 + 3]
		low = minf(low, x)
		high = maxf(high, x)
	check(high - low > MoteField.BOX * 0.85,
		"the first %d motes of the pool span %.1f of the %.1f-unit box, so "
		% [prefix, high - low, MoteField.BOX]
		+ "drawing a share of the cloud would clear one side of the view")
	one.view().free()
	two.view().free()
	other.view().free()


## A twilight pocket carries orbs, and each one lights what is around it.
##
## Asked of the simulation rather than of this layer: the orbs are props the
## scatter layer placed, and the whole of the layer's part in them is turning
## each into something that glows and wanders. So this stands the observer in a
## marsh, counts what the simulation put there, and checks the light the layer
## would hang on one.
func _the_twilight_pockets_carry_orbs_that_light_them() -> void:
	var world := SimWorld.new(1234)
	world.place_observer(MARSH_X, MARSH_Z)
	for step in 10:
		world.step()
	equal(world.observer_biome(), BiomeCatalog.TWILIGHT_MARSH,
		"the spot this check stands in is not a twilight marsh any more")

	var orbs := 0
	var wet_things := 0
	for key in world.scatter_streamer.loaded_keys():
		var patch := world.scatter_streamer.patch(key)
		if patch == null:
			continue
		for item in patch.items:
			var tag := String(item["tag"])
			if tag == AssetTags.GLOWING_ORB:
				orbs += 1
			elif tag == AssetTags.CATTAIL or tag == AssetTags.REED:
				wet_things += 1
	check(orbs >= 3,
		"a twilight marsh view holds %d glowing orbs beside %d reeds and "
		% [orbs, wet_things] + "cattails, which is not a pocket lit by orbs")

	var layer := Atmosphere.new(1234)
	var light := layer.light_for(
		AssetTags.GLOWING_ORB, world.terrain.profile_at(MARSH_X, MARSH_Z)
	)
	check(light != null, "a glowing orb casts no light")
	if light != null:
		check(light.omni_range >= 6.0,
			"an orb reaches %.1f units, which does not light its surroundings"
			% light.omni_range)
		light.free()
	layer.dispose()


## An orb wanders around where the simulation put it, and does not move it.
##
## The same split the far-sky islands already use: the simulation says where the
## orb is, and the picture breathes around that point. Checked by holding a node,
## running the clock, and requiring both that the node moves and that it never
## leaves the neighbourhood of its anchor -- and separately that nothing the
## simulation says about the world has changed while it wandered.
func _an_orb_wanders_around_where_the_simulation_put_it() -> void:
	var world := SimWorld.new(1234)
	world.place_observer(MARSH_X, MARSH_Z)
	for step in 8:
		world.step()
	var before := world.digest()

	var layer := Atmosphere.new(1234)
	var anchor := Vector3(MARSH_X, 4.0, MARSH_Z)
	var node := Node3D.new()
	node.position = anchor
	layer.hold_orb(node, 1234)
	equal(layer.orb_count(), 1, "the layer is not holding the orb")

	var seen: Array[Vector3] = []
	var furthest := 0.0
	for tick in 40:
		layer.drift(float(tick) * 0.9)
		seen.append(node.position)
		furthest = maxf(furthest, node.position.distance_to(anchor))
	var moved := 0.0
	for at in seen.size():
		moved = maxf(moved, seen[at].distance_to(seen[0]))
	check(moved > 0.2, "the orb did not move at all over 36 seconds")
	check(furthest <= Atmosphere.ORB_WANDER * 1.45,
		"the orb wandered %.2f units from where the simulation put it, past the "
		% furthest + "%.2f it is allowed" % Atmosphere.ORB_WANDER)
	# Slow: a full circuit takes the better part of a minute, so over one second
	# an orb moves a few centimetres rather than darting.
	layer.drift(0.0)
	var at_rest := node.position
	layer.drift(1.0)
	check(at_rest.distance_to(node.position) < 0.35,
		"an orb moved %.2f units in one second, which reads as a bug rather "
		% at_rest.distance_to(node.position) + "than as a drift")

	equal(world.digest(), before,
		"the world changed while an orb wandered over it")
	node.free()
	layer.dispose()


## The shadows are long and the sun edge is soft.
##
## Long is a statement about the sun's height, so it is checked as one: at this
## angle a thing throws a shadow longer than it is tall, which is the raking
## light the diorama look wants. Soft is a statement about the sun's apparent
## size, checked against the real sun's half a degree.
func _the_shadows_are_long_and_soft() -> void:
	var layer := Atmosphere.new(SEED)
	var light := layer.key_light()
	var pitch := absf(Atmosphere.SUN_PITCH)
	check(pitch > 5.0 and pitch < 45.0,
		"the sun sits %.1f degrees up, which is not a raking angle" % pitch)
	var shadow_per_height := 1.0 / tan(deg_to_rad(pitch))
	check(shadow_per_height > 1.2,
		"a thing throws a shadow %.2f times its own height, which is not long"
		% shadow_per_height)
	check(light.light_angular_distance > REAL_SUN_DEGREES,
		"the sun is %.2f degrees across, no wider than the real one, so the "
		% light.light_angular_distance + "shadow edges are hard")
	check(light.shadow_blur > 1.0,
		"the shadow edge is not blurred (%.2f)" % light.shadow_blur)
	check(light.shadow_enabled, "the key light casts no shadow at all")
	# A warm key against a cool fill is the whole grade, so the key has to be
	# the warm half of it.
	check(Atmosphere.SUN_COLOR.r > Atmosphere.SUN_COLOR.b,
		"the key light is not warm: %s" % Atmosphere.SUN_COLOR)
	layer.dispose()


## The miniature depth of field brackets whatever the camera is looking at.
##
## Near blur inside the subject and far blur outside it, both moving with the
## camera -- which is what lets a report move the camera in for a detail shot
## without the whole frame going soft.
func _the_depth_of_field_brackets_whatever_the_camera_is_looking_at() -> void:
	var layer := Atmosphere.new(SEED)
	var attributes := layer.camera_attributes() as CameraAttributesPractical
	for distance in [12.0, 66.0, 140.0]:
		layer.focus_at(distance)
		check(attributes.dof_blur_near_enabled and attributes.dof_blur_far_enabled,
			"only one side of the depth of field is on, which is a background "
			+ "blur rather than a miniature one")
		check(attributes.dof_blur_near_distance < distance,
			"at %.0f units the near blur starts at %.1f, past the subject"
			% [distance, attributes.dof_blur_near_distance])
		check(attributes.dof_blur_far_distance > distance,
			"at %.0f units the far blur starts at %.1f, in front of the subject"
			% [distance, attributes.dof_blur_far_distance])
		check(attributes.dof_blur_amount > 0.0, "the depth of field blurs nothing")
	# Moving the camera moves the band with it, rather than leaving it where the
	# game's own camera left it.
	layer.focus_at(12.0)
	var close := attributes.dof_blur_far_distance
	layer.focus_at(140.0)
	check(attributes.dof_blur_far_distance > close,
		"the depth-of-field band did not follow the camera")
	layer.dispose()


## A headless process loads no part of the atmosphere stack.
##
## The same check the grass gets, and it is the strongest statement available:
## not that the stack is switched off headless, but that its files are never
## loaded, so there is no environment, no light, no bloom, no depth of field and
## no mote in that process to switch off. Read off the engine's own resource
## cache by the headless run itself, from outside the render layer.
func _headless_loads_no_atmosphere_at_all() -> void:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/headless_main.gd",
		"--",
		"--seed", str(SEED), "--ticks", "40", "--assets",
	], output, true)
	var text := "\n".join(output)
	equal(exit_code, 0, "headless run should exit 0 (output: %s)" % text)

	var render_scripts := _asset_line(text, "render-scripts")
	check(not render_scripts.is_empty(),
		"the headless run reported no render-scripts line: %s" % text)
	if render_scripts.is_empty():
		return
	equal(render_scripts["loaded"], 0,
		"a headless run loaded %d file(s) of the render layer, which is where "
		% render_scripts["loaded"] + "the whole atmosphere stack lives")
	# The count has to include both files of the stack, or "none of them was
	# loaded" is an answer about a set the atmosphere is not in.
	for path in ["res://render/atmosphere.gd", "res://render/mote_field.gd"]:
		check(FileAccess.file_exists(path),
			"%s is missing, so the check above covers nothing" % path)
	check(render_scripts["found"] >= 7,
		"only %d render scripts were counted; the atmosphere and the motes are "
		% render_scripts["found"] + "not among them")


## The world the shell reaches is byte-identical with the atmosphere and without.
##
## Three runs rather than two: the shell with the whole stack, the shell with
## --no-atmosphere, and a simulation with no renderer at all. All three must
## arrive at the same fingerprint at the same tick. The two shell runs also have
## to differ in the ways they are supposed to -- one draws hundreds of motes and
## hangs dozens of warm lights and the other does neither -- or "the fingerprints
## matched" would be a statement about two runs that did the same thing.
func _the_world_is_byte_identical_with_and_without_the_atmosphere() -> void:
	var lit := _run_render_shell([])
	var dark := _run_render_shell(["--no-atmosphere"])
	equal(lit["exit_code"], 0, "render shell should exit 0 (output: %s)" % lit["output"])
	equal(dark["exit_code"], 0, "render shell should exit 0 (output: %s)" % dark["output"])

	var lit_counts := _counts_from(lit["output"])
	var dark_counts := _counts_from(dark["output"])
	check(not lit_counts.is_empty(), "no counters from the shell: %s" % lit["output"])
	check(not dark_counts.is_empty(), "no counters from the shell: %s" % dark["output"])
	if lit_counts.is_empty() or dark_counts.is_empty():
		return

	check(lit_counts["motes"] > 100,
		"the lit run drew only %d motes, so comparing it against a run with "
		% lit_counts["motes"] + "none shows nothing")
	check(lit_counts["lights"] > 0,
		"the lit run hung no warm lights at all")
	equal(dark_counts["motes"], 0, "--no-atmosphere still drew %d motes"
		% dark_counts["motes"])
	equal(dark_counts["lights"], 0, "--no-atmosphere still hung %d warm lights"
		% dark_counts["lights"])
	equal(lit_counts["tick"], EXPECTED_TICKS,
		"the shell should have run %d ticks" % EXPECTED_TICKS)

	var headless := Simulation.new(SEED)
	headless.run(EXPECTED_TICKS)
	equal(_digest_from(lit["output"]), headless.world.digest(),
		"the shell with the atmosphere reached a different world from a headless "
		+ "run of seed %d at tick %d" % [SEED, EXPECTED_TICKS])
	equal(_digest_from(dark["output"]), _digest_from(lit["output"]),
		"the same seed reached different worlds with and without the atmosphere "
		+ "stack: lighting the world is changing it")


# --- helpers -------------------------------------------------------------


## How far a colour leans towards blue, per unit of how bright it is.
##
## Dividing by the brightness is what makes two colours of very different
## brightness comparable: the twilight marsh's sky is nearly black, and a raw
## blue-minus-red on it would be small however blue the colour actually is.
func _blue_bias(colour: Color) -> float:
	var brightness := maxf(
		0.0005, 0.2126 * colour.r + 0.7152 * colour.g + 0.0722 * colour.b
	)
	return (colour.b - colour.r) / brightness


func _run_render_shell(extra: Array) -> Dictionary:
	var output: Array[String] = []
	var args: Array = [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--fixed-fps", str(FIXED_FPS),
		"--quit-after", str(FRAMES),
		"--",
		"--seed", str(SEED),
	]
	args.append_array(extra)
	var exit_code := OS.execute(OS.get_executable_path(), args, output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


func _digest_from(output: String) -> String:
	for line in output.split("\n"):
		if not line.contains("render-shell stop tick="):
			continue
		var at := line.find("digest=")
		if at == -1:
			continue
		return line.substr(at + "digest=".length()).strip_edges()
	return ""


func _counts_from(output: String) -> Dictionary:
	for line in output.split("\n"):
		if not line.contains("render-shell stop tick="):
			continue
		var counts := {}
		for field in line.strip_edges().split(" "):
			var parts := field.split("=")
			if parts.size() == 2 and parts[1].is_valid_int():
				counts[parts[0]] = parts[1].to_int()
		return counts
	return {}


## The "assets <label> found=N loaded=M" line of a headless report, as
## {found, loaded}, or empty when the line is missing.
func _asset_line(text: String, label: String) -> Dictionary:
	for line in text.split("\n"):
		if not line.contains("assets %s " % label):
			continue
		var found := {}
		for field in line.strip_edges().split(" "):
			var parts := field.split("=")
			if parts.size() == 2 and parts[1].is_valid_int():
				found[parts[0]] = parts[1].to_int()
		return found
	return {}
