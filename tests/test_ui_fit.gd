extends TestSuite
## Every panel is laid out inside the window it is drawn in.
##
## The interface is pixel art multiplied by a whole number, and until this suite
## existed nothing asked whether what was laid out at that whole number still
## fitted. It did not: at the window the game ships in -- Godot's own default
## 1152x648, which `project.godot` does not override -- the combat readout ran
## off the right edge and the bottom, taking the end-turn button with it, and
## opening the character sheet put the trade and dialogue panels below the
## bottom of the window altogether.
##
## Two claims, and the second is the one that would have caught it:
##
##   1. **The rule answers to the panels.** `PixelUi.scale_that_fits` is the
##      largest whole number by which what the panels need still fits both
##      across the window and down it -- checked as maximality rather than
##      against a table of expected answers, so it is the property that is
##      asserted and not one arithmetic spelling of it. It is never less than
##      one, because a fraction blurs the art.
##   2. **Nothing is laid out past the edge.** A real world, the panels a play
##      run builds watching it, and every panel that is showing measured where
##      the shell's own `geometry_of` says it landed -- at the window the game
##      ships in, at a second window inside the band the old rule overflowed in,
##      and at a third outside that band. With the sheet shut, with the sheet
##      open, and with a fight on.
##
## Laying a container out is normally the engine's own next idle frame, and a
## suite here is one call inside one frame, so `_sorted` does it on the spot:
## the containers are handed their own sort notification from the top down,
## which is the same work the idle frame would have done.
class_name TestUiFit

const SEED := ScriptedActions.SEED

## How far into the encounter scenario there is a fight to draw. The same tick
## `TestUiReadout` uses, for the same reason: it is where that scenario's fight
## is under way.
const FIGHT_TICK := 16

## The window the game ships in: Godot's default, which `project.godot` leaves
## alone.
const SHIPPED := Vector2(1152, 648)

## A second window inside the band the old rule overflowed in -- it scaled by
## `floor(height / 320)`, so 960 was three steps of a layout too tall for it.
const ALSO_TOO_SMALL := Vector2(1280, 960)

## And one outside that band, where the old rule happened to come out right.
const ROOMY := Vector2(1280, 720)


func _init() -> void:
	suite_name = "ui fit"


func run() -> void:
	_the_scale_is_the_largest_whole_one_that_fits()
	_a_play_run_keeps_every_panel_inside_the_window()
	_the_open_sheet_keeps_every_panel_inside_the_window()
	_a_fight_keeps_every_panel_inside_the_window()


# --- 1: the rule ----------------------------------------------------------


## The scale is the largest whole number of times what the panels need goes into
## the window, and never less than one.
##
## Asserted as the property rather than as a table: whatever the rule answers,
## that many copies must fit and one more must not.
func _the_scale_is_the_largest_whole_one_that_fits() -> void:
	var windows := [SHIPPED, ALSO_TOO_SMALL, ROOMY, Vector2(2560, 1440)]
	var wants := [
		Vector2(320, 200), Vector2(644, 685), Vector2(500, 300), Vector2(1152, 648),
	]
	for window in windows:
		for needed in wants:
			var chosen := PixelUi.scale_that_fits(window, needed)
			check(chosen >= 1,
				"a %s window with %s of panels was scaled by %d, which is not a scale"
				% [str(window), str(needed), chosen])
			if chosen > 1:
				check(needed.x * chosen <= window.x and needed.y * chosen <= window.y,
					"%s of panels at %dx does not fit a %s window"
					% [str(needed), chosen, str(window)])
			var more := chosen + 1
			check(needed.x * more > window.x or needed.y * more > window.y,
				"%s of panels would have fitted a %s window at %dx, and the rule"
				% [str(needed), str(window), more]
				+ " settled for %dx" % chosen)

	# Nothing to fit is not a licence to multiply by anything at all.
	equal(PixelUi.scale_that_fits(SHIPPED, Vector2.ZERO), 1,
		"an interface with no panels in it should be drawn at 1x")


# --- 2: nothing past the edge ---------------------------------------------


## The panels a play run builds, with nobody's sheet open, at all three windows.
func _a_play_run_keeps_every_panel_inside_the_window() -> void:
	_every_panel_is_inside(false, false, "a play run")


## The same run with the character sheet open -- the case that used to push the
## trade panel and the dialogue panel off the bottom of the window.
func _the_open_sheet_keeps_every_panel_inside_the_window() -> void:
	_every_panel_is_inside(true, false, "a play run with the sheet open")


## And a run with a fight on, which is when the combat readout is drawn at all.
func _a_fight_keeps_every_panel_inside_the_window() -> void:
	_every_panel_is_inside(false, true, "a fight")


## Build the interface a run of that shape builds, watch a real world with it,
## and measure where every showing panel landed at each of the three windows.
func _every_panel_is_inside(sheet_open: bool, fighting: bool, what: String) -> void:
	if not SproutPack.is_installed():
		return
	var world := _fighting_world() if fighting else _played_world()
	var layer := PixelUi.build(sheet_open, true, true, true, true, true)
	check(layer != null, "the interface did not build")
	if layer == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(layer)
	_watch(layer, world)

	for window in [SHIPPED, ALSO_TOO_SMALL, ROOMY]:
		layer.fit_to(window)
		_sorted(layer)
		check(layer.art_scale >= 1 and layer.scale.x == float(layer.art_scale)
			and layer.scale.y == float(layer.art_scale),
			"%s in a %s window is drawn at %s, which is not a whole number"
			% [what, str(window), str(layer.scale)])
		var inside := Rect2i(Vector2i.ZERO, Vector2i(int(window.x), int(window.y)))
		var showing := 0
		for named in _panels_of(layer):
			var which: Control = named[1]
			if which == null or not which.visible:
				continue
			showing += 1
			var at := layer.geometry_of(which)
			check(inside.encloses(at),
				"in %s at %s the %s panel is laid out at %s, which is not inside"
				% [what, str(window), named[0], str(at)]
				+ " the window it is drawn in")
		check(showing > 0,
			"%s at %s drew no panel at all, so nothing was measured"
			% [what, str(window)])

	tree.root.remove_child(layer)
	layer.free()


# --- The world, the panels, and laying them out ---------------------------


## A world with somebody being played in it: the scripted play stage, which has
## a followed character for the panels to read.
func _played_world() -> SimWorld:
	var world := SimWorld.new(SEED)
	ScriptedPlay.muster(world)
	return world


## A world with a fight under way, so that the combat readout draws itself.
func _fighting_world() -> SimWorld:
	var sim := Simulation.new(TestUiReadout.SEED)
	sim.begin_scenario(Simulation.SCENARIO_ENCOUNTER)
	for _tick in FIGHT_TICK:
		sim.step()
	return sim.world


## Hand every panel the world it reads, the way `render/main.gd` does, and read
## each of them off it once. Nothing is pushed to a panel: these are the handles
## the panel reads through on every frame it draws.
func _watch(layer: PixelUi, world: SimWorld) -> void:
	var id := world.follow_id
	layer.panel.show_sheets(SheetSource.sheets_in(world))
	layer.readout.watch(world)
	layer.play.watch(world, id, PlayerControls.new())
	layer.answer.watch(world, id, LiveChoice.new())
	layer.territory.watch(world, id)
	layer.trade.watch(world, id)
	layer.dialogue.watch(world, id)
	for named in _panels_of(layer):
		(named[1] as Control).call("refresh")


## The panels, each with the name a failure should call it by.
static func _panels_of(layer: PixelUi) -> Array:
	return [
		["character sheet", layer.panel],
		["combat readout", layer.readout],
		["play", layer.play],
		["answer", layer.answer],
		["territory", layer.territory],
		["trade", layer.trade],
		["dialogue", layer.dialogue],
	]


## Lay the whole interface out now, rather than on the idle frame that will
## never come inside one suite: every container under the layer is handed the
## sort notification the engine would have handed it, parents before children,
## so that each one is placed inside the rectangle its parent has just given it.
static func _sorted(layer: PixelUi) -> void:
	_sort_under(layer)


static func _sort_under(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_PRE_SORT_CHILDREN)
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		_sort_under(child)
