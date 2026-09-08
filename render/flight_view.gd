extends Node3D
## One thing flying across the board: a launched blow's effect, in the world.
##
## The combat readout already draws a blow as a sixteen-pixel sprite inside a
## panel; this is the body in the world beside it -- the arrow that actually
## crosses the ground between the cell the attack began in and the cell the
## record says it landed on. It is presentation and nothing else: by the time
## one of these exists the blow has already been resolved, the damage already
## dealt and the record already written, so there is nothing here for the
## simulation to hear back.
##
## `launch()` takes a start cell, an end cell and the two tags the blow record
## carries -- which art says what it is, and which motion says how long it
## takes -- and `show_phase()` puts the body at a fraction of the way across.
## Where in the flight a given tick falls is `BlowFlights`' arithmetic, off the
## snapshot; this node holds only the two endpoints and the body, which is view
## bookkeeping in exactly the way a piece view is.
##
## No projectile physics. The flight is a straight line at a fixed height over
## the two cells, because the simulation has already decided what it hit; an
## arc, a wobble or a bounce would be the picture inventing facts.
class_name FlightView

## How far above a cell's ground the flight crosses, in world units. Chest
## height on the 2.5-unit rig, so an arrow leaves about where a bow is drawn
## and arrives about where a body stands.
const LIFT := 1.1

## The two tags the blow carried, kept as they were handed in: which art this
## flight wears, and which motion names its span. Read by nothing here after
## launch -- the body is already built and the span is the planner's business --
## but a flight that cannot say what it is cannot be told apart in a test.
var sprite_tag := ""
var animation_tag := ""

var _from := Vector3.ZERO
var _to := Vector3.ZERO


## Set the flight up: where it leaves, where it lands, what it looks like.
##
## The cells are lattice cells out of the blow record, turned into world
## positions by the same one rule everything else uses -- `CombatBoard.centre_of`
## -- so the flight leaves the middle of the archer's cell and arrives at the
## middle of the cell the record says the blow landed on. The two heights are
## the ground under each end, which the caller reads off the snapshot's own
## piece rows; the flight interpolates between them, so a shot fired up a
## terrace climbs and one fired off it descends.
func launch(
	from_cell: Vector2i,
	to_cell: Vector2i,
	sprite: String,
	animation: String,
	from_height: float = 0.0,
	to_height: float = 0.0,
) -> void:
	sprite_tag = sprite
	animation_tag = animation
	var leaving := CombatBoard.centre_of(from_cell)
	var landing := CombatBoard.centre_of(to_cell)
	_from = Vector3(leaving.x, from_height + LIFT, leaving.y)
	_to = Vector3(landing.x, to_height + LIFT, landing.y)
	for old in get_children():
		old.queue_free()
	add_child(FlightArt.build(sprite))
	position = _from
	# Point the body's -Z along the travel, which is the axis every body is
	# built to fly along. A flight whose record says it landed where it left --
	# a shot that found nobody -- has no direction, and keeps none.
	var along := _to - _from
	if along.length_squared() > 0.000001:
		basis = Basis.looking_at(along.normalized())


## Put the body a fraction of the way across, 0 at the start cell and 1 landed.
func show_phase(phase: float) -> void:
	position = _from.lerp(_to, clampf(phase, 0.0, 1.0))


## Where the flight is at a phase, without moving anything: what a test asks.
func point_at(phase: float) -> Vector3:
	return _from.lerp(_to, clampf(phase, 0.0, 1.0))
