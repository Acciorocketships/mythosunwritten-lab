extends TestSuite
## Every number the interface draws is legible: a zero cannot be read as an
## eight.
##
## The pack's font draws a slashed zero, and its slash meets both walls of the
## counter. At the size the interface ships at the middle closes completely, so
## the glyph has two enclosed holes -- which is what an `8` has -- and five
## pixels of a hundred and four are all that separate the two. On the frames the
## second playtest took, `TRADES 0` reads `TRADES 8` and a pile `0.4 AWAY` reads
## `8.4 AWAY`. Every health total, coin count, distance and round number in this
## game is drawn in that font, so this was every number on screen.
##
## `SproutTheme.unslash_the_zero()` points the digit at the pack's own capital
## `O`, which is that same zero with the slash lifted. Four claims hold it there:
##
##   1. **The fault is real, and it is in the pack rather than in this project.**
##      The pack's font as it ships draws a zero with two holes at every size the
##      interface uses, and of the ninety pairs of digits the closest by far is
##      the zero and the eight.
##   2. **The font the game draws with does not.** Its zero has one hole, its
##      eight still has two, and no pair of digits is as close as those two were.
##   3. **Nothing was drawn and nothing was copied.** The zero the game draws is
##      pixel for pixel the pack's own capital `O`, at every size -- so no art
##      entered this repository and none of the pack's left it, which its licence
##      forbids even for a modified copy. The switches that keep a pixel font
##      crisp are the ones `pack_font()` set: this changes which rectangle of the
##      cache a glyph is drawn from and nothing about how it is rasterised.
##   4. **It reaches every panel that draws a number.** There is one font. The
##      whole interface is built, handed a real world to read, laid out, and
##      every label on every panel that came out carrying a digit is asked which
##      font it resolves to -- and it is this one, with no override between.
##
## A picture of the before and the after is what `./tools/measure_ui.sh --digits`
## writes, and `reports/zero-glyph.md` is where it is looked at.
class_name TestUiDigits

const SEED := ScriptedActions.SEED

## Where the encounter scenario has a fight under way, so the combat readout
## draws its round number and its hit points. `TestUiReadout`'s own tick.
const FIGHT_TICK := 16

## The ten digits, as the strings a glyph is asked for by.
const DIGITS := ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

## How many holes a reader counts in each of the ten, once the zero is drawn with
## the unslashed ring. This is the whole claim in one line: the zero is no longer
## in the two-hole class with the eight.
const HOLES := {
	"0": 1, "1": 0, "2": 0, "3": 0, "4": 0, "5": 0,
	"6": 1, "7": 0, "8": 2, "9": 1,
}


func _init() -> void:
	suite_name = "ui digits"


func run() -> void:
	_the_packs_own_zero_is_an_eight()
	_the_zero_the_game_draws_is_not()
	_the_zero_the_game_draws_is_the_packs_own_ring()
	_every_panel_draws_its_numbers_with_this_font()


# --- 1: the fault, in the pack ---------------------------------------------


## The pack's font as it ships. If this ever stops failing the way it fails now
## -- a new pack, a different face -- the fix below is worth re-reading rather
## than carrying on out of habit, and that is what this check is for.
func _the_packs_own_zero_is_an_eight() -> void:
	if not SproutPack.is_installed():
		return
	var font := SproutTheme.pack_font()
	check(font != null, "the pack's font did not load")
	if font == null:
		return
	for size in SproutTheme.SIZES:
		var shapes := _digits_of(font, size)
		equal(GlyphShape.counters(shapes["0"]), 2,
			"the pack's own zero at size %d no longer has the two holes that" % size
			+ " made it an eight; re-read SproutTheme.unslash_the_zero()")
		equal(GlyphShape.counters(shapes["8"]), 2,
			"the pack's own eight at size %d does not have two holes" % size)
		var closest := _closest_pair(shapes)
		equal(String(closest["pair"]), "0 8",
			"the closest pair of digits in the pack's own font at size %d is no" % size
			+ " longer the zero and the eight, which is what this fix is about")


# --- 2: the font the game draws with ---------------------------------------


func _the_zero_the_game_draws_is_not() -> void:
	if not SproutPack.is_installed():
		return
	var font := SproutTheme.build_font()
	check(font != null, "the interface's font did not load")
	if font == null:
		return
	for size in SproutTheme.SIZES:
		var shapes := _digits_of(font, size)
		for digit in DIGITS:
			check(not shapes[digit].is_empty(),
				"the font draws nothing at all for '%s' at size %d" % [digit, size])
			equal(GlyphShape.counters(shapes[digit]), int(HOLES[digit]),
				"the '%s' the interface draws at size %d has the wrong number of" % [
					digit, size]
				+ " enclosed holes, which is what a reader counts first")
		# Every pair of digits, not only the pair that was misread: the two the
		# playtest caught were the closest, and nothing is allowed to be as close.
		var closest := _closest_pair(shapes)
		not_equal(String(closest["pair"]), "0 8",
			"the zero and the eight are still the closest pair of digits at size %d"
			% size)
		check(int(closest["apart"]) > 5,
			"two digits at size %d are only %d pixels apart (%s), which is as" % [
				size, int(closest["apart"]), String(closest["pair"])]
			+ " close as the zero and the eight were when they were misread")


# --- 3: whose glyph it is ---------------------------------------------------


## The zero the game draws is the pack's own unslashed ring, which is the reason
## no art was drawn for this and nothing of the pack's was written out.
func _the_zero_the_game_draws_is_the_packs_own_ring() -> void:
	if not SproutPack.is_installed():
		return
	var packed := SproutTheme.pack_font()
	var font := SproutTheme.build_font()
	if packed == null or font == null:
		return
	for size in SproutTheme.SIZES:
		equal(GlyphShape.differing(
				GlyphShape.of(font, size, "0"), GlyphShape.of(packed, size, "O")), 0,
			"the zero the interface draws at size %d is not the pack's own" % size
			+ " capital O, so it is a glyph from somewhere else")
		# And the letter itself is untouched: only the digit was pointed anywhere.
		equal(GlyphShape.differing(
				GlyphShape.of(font, size, "O"), GlyphShape.of(packed, size, "O")), 0,
			"the capital O the interface draws at size %d is not the pack's" % size)
		for other in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "M", "W", "."]:
			equal(GlyphShape.differing(GlyphShape.of(font, size, other),
					GlyphShape.of(packed, size, other)), 0,
				"'%s' at size %d is not the pack's own glyph any more; only the" % [
					other, size]
				+ " zero was meant to move")

	# And the switches that decide whether a pixel font looks right are the ones
	# the pack's own font was loaded with: nothing here re-rasterises anything.
	equal(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE,
		"the interface's font is antialiased")
	equal(font.hinting, TextServer.HINTING_NONE, "the interface's font is hinted")
	equal(font.oversampling, 1.0,
		"the interface's font is rasterised at the canvas scale rather than at"
		+ " its own size, so a whole-number scale no longer means whole pixels")
	for size in SproutTheme.SIZES:
		equal(size % SproutPack.FONT_CELL, 0,
			"the interface draws at size %d, which is not a multiple of the" % size
			+ " font's own %d-pixel cell" % SproutPack.FONT_CELL)


# --- 4: every panel that draws a number ------------------------------------


## Build the whole interface, hand it a world, lay it out, and find every label
## that came out with a digit in it. Each one is asked which font it resolves to.
##
## Two worlds, because the panels do not all have something to say about one:
## the combat readout only draws while there is a fight, and the panels a person
## plays through only draw while there is somebody being played.
func _every_panel_draws_its_numbers_with_this_font() -> void:
	if not SproutPack.is_installed():
		return
	var numbered := {}
	for world in [_played_world(), _fighting_world()]:
		var layer := PixelUi.build(true, true, true, true, true, true)
		check(layer != null, "the interface did not build")
		if layer == null:
			return
		var tree := Engine.get_main_loop() as SceneTree
		tree.root.add_child(layer)
		_watch(layer, world)
		layer.fit_to(TestUiFit.SHIPPED)
		TestUiFit._sorted(layer)

		var font: FontFile = layer._frame.theme.default_font
		check(font != null, "the interface carries no font of its own")
		for named in TestUiFit._panels_of(layer):
			var which: Control = named[1]
			if which == null:
				continue
			var lines := _numbered_under(which, font, String(named[0]))
			if not lines.is_empty():
				numbered[named[0]] = lines

		tree.root.remove_child(layer)
		layer.free()

	# Every panel the interface builds draws a number somewhere, and none was
	# skipped because it happened to have nothing to say on the tick it was read.
	for named in ["character sheet", "combat readout", "play", "answer",
			"territory", "trade", "dialogue"]:
		check(numbered.has(named),
			"the %s panel drew no number at all in either world, so nothing on" % named
			+ " it was checked; drive it until it does rather than dropping it")


## Every label under one panel that came out with a digit in it, checked against
## the font the interface carries -- and returned so a panel that drew no number
## at all can be told from one that drew one badly.
func _numbered_under(
	root: Node, font: FontFile, panel: String
) -> PackedStringArray:
	var found := PackedStringArray()
	for child in root.get_children():
		if child is Label:
			var label := child as Label
			var text := label.text
			var has_digit := false
			for digit in DIGITS:
				if text.contains(digit):
					has_digit = true
					break
			if has_digit:
				found.append(text)
				check(label.get_theme_font("font") == font,
					"the %s panel draws '%s' in a font that is not the one the" % [
						panel, text]
					+ " interface carries, so its zero is not the fixed one")
		found.append_array(_numbered_under(child, font, panel))
	return found


# --- The worlds and the panels ---------------------------------------------


## A world with somebody being played in it, so the panels a person plays
## through have something to read.
func _played_world() -> SimWorld:
	var world := SimWorld.new(SEED)
	ScriptedPlay.muster(world)
	return world


## A world with a fight under way, so the combat readout draws itself.
func _fighting_world() -> SimWorld:
	var sim := Simulation.new(TestUiReadout.SEED)
	sim.begin_scenario(Simulation.SCENARIO_ENCOUNTER)
	for _tick in FIGHT_TICK:
		sim.step()
	return sim.world


## Hand every panel the world it reads, the way `render/main.gd` does, and read
## each of them off it once.
##
## Two of the panels say nothing at all about a world nobody has touched: the
## play panel writes how far away the thing aimed at is, and there is nothing
## aimed at, and the answer panel writes the choice standing, and nothing has
## been chosen. So this aims at the first thing in sight and stands a walk in the
## holder -- which is the state those two panels exist for, and the state the
## numbers on them are drawn in.
func _watch(layer: PixelUi, world: SimWorld) -> void:
	var id := world.follow_id
	var controls := PlayerControls.new()
	var view := world.surroundings_of(id)
	if not view.aims.is_empty():
		controls.aimed_id = int((view.aims[0] as Dictionary)["id"])
	var choice := LiveChoice.new()
	choice.choose(Action.go_to_offset(Vector2(3.5, 0.0)))
	layer.panel.show_sheets(SheetSource.sheets_in(world))
	layer.readout.watch(world)
	layer.play.watch(world, id, controls)
	layer.answer.watch(world, id, choice)
	layer.territory.watch(world, id)
	layer.trade.watch(world, id)
	layer.dialogue.watch(world, id)
	for named in TestUiFit._panels_of(layer):
		(named[1] as Control).call("refresh")


# --- Measuring --------------------------------------------------------------


## The ten digits of one font at one size, as rasterised.
func _digits_of(font: FontFile, size: int) -> Dictionary:
	var shapes := {}
	for digit in DIGITS:
		shapes[digit] = GlyphShape.of(font, size, digit)
	return shapes


## The two digits that are hardest to tell apart, and by how many pixels.
func _closest_pair(shapes: Dictionary) -> Dictionary:
	var apart := 1 << 30
	var pair := ""
	for one in DIGITS:
		for other in DIGITS:
			if one >= other:
				continue
			var between := GlyphShape.differing(shapes[one], shapes[other])
			if between >= 0 and between < apart:
				apart = between
				pair = "%s %s" % [one, other]
	return {"pair": pair, "apart": apart}
