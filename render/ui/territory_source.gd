extends RefCounted
## The one place the interface reaches into the simulation for a standing and
## for the ownership of a point of ground.
##
## The territory readout is a view onto two things the simulation already
## holds: the relationship graph, which is where how two characters stand with
## each other lives, and the ownership rule, which is section 6's one function
## of a world position and the state of the world (`sim/ownership_field.gd`).
## This file's whole job is to ask both on behalf of the panel and hand the
## answers straight over. Nothing is stored here and nothing is stored in the
## panel, so there is no second copy of an ownership score or of a relationship
## edge for the two sides to disagree about.
##
## ## Reading the field is not computing it
##
## There is no ownership map anywhere in the simulation to look a point up in:
## ownership *is* `OwnershipField.at`, a reading of the graph that changes
## nothing, and every caller in the project -- the territory run, the sweeps
## that chose the constants, this file -- asks that one function. So the panel
## asking it on the frame it draws is exactly what "reads the field" means, and
## the alternative -- a cached claim pushed across on a tick -- would be the
## copy this design exists to avoid. Not one weight, radius or threshold is
## named on this side of the line, and tests/test_ui_territory.gd scans this
## file and the panel for the field's own constants to keep it that way.
##
## ## Why the hops are dynamic
##
## The same reason `render/ui/fight_source.gd` gives: the types between the
## world and the answers -- the roster, the scene, the entities standing in it
## -- are the combat layer's own, and `tests/layer_check.gd` fails the render
## layer for naming them. What may be named is what is read-only by
## construction: `Character` (a handle, exactly as the sheet reads it),
## `OwnershipClaim` (a verdict built fresh per call and thrown away), and
## `OwnershipField` itself (a static function with nothing to hold).
class_name TerritorySource


## The scene the world's entities are standing in, or null. An `Object` rather
## than its own type on purpose: see the note above.
static func scene_in(world: SimWorld) -> Object:
	if world == null or world.combat == null:
		return null
	var stage: Variant = world.combat.scene
	return stage if stage is Object else null


## The entity standing in the world under this id, or null: nobody, or no
## longer standing.
static func standing_in(world: SimWorld, id: int) -> Object:
	var stage := scene_in(world)
	if stage == null or id == 0:
		return null
	var one: Variant = stage.actor_of(id)
	return one if one is Object else null


## Who owns the point this character is standing on, asked of the simulation's
## own rule at the moment of the call, or null when there is nobody to stand.
##
## The claim that comes back is built by `OwnershipField.at` for this call and
## carries the verdict, the top scores and how many entities had a say. It is
## read, drawn and dropped; nothing keeps it.
static func claim_under(world: SimWorld, id: int) -> OwnershipClaim:
	var stage := scene_in(world)
	var one := standing_in(world, id)
	if stage == null or one == null:
		return null
	return OwnershipField.at(
		stage.actors, stage.relationships, float(one.x), float(one.z))


## How one character stands with every character it knows of, one row per edge
## of the world's relationship graph:
##
##     {"id", "name", "yours", "theirs"}
##
## `yours` is this character's sentiment toward the other and `theirs` the
## other's toward it, both the graph's own composite
## (`RelationshipEdge.sentiment_of`) read at the moment the row is made. The
## rows are made when the panel asks and dropped when it has drawn them --
## the edges themselves stay the simulation's.
static func standings_of(world: SimWorld, id: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var stage := scene_in(world)
	if stage == null or id == 0:
		return rows
	var graph: Variant = stage.relationships
	if graph == null:
		return rows
	for edge in graph.edges_of(id):
		var other := int(edge.other_than(id))
		rows.append({
			"id": other,
			"name": name_of(world, other),
			"yours": float(edge.sentiment_of(id)),
			"theirs": float(edge.sentiment_of(other)),
		})
	return rows


## What somebody standing in the world is called: the name on the character
## sheet it carries, or the id it is known by while it has none.
static func name_of(world: SimWorld, id: int) -> String:
	var one := standing_in(world, id)
	if one == null:
		return "#%d" % id
	var piece: Variant = one.piece
	if piece == null:
		return "#%d" % id
	var sheet: Variant = piece.get("sheet")
	if sheet is Character and (sheet as Character).character_name != "":
		return (sheet as Character).character_name
	return "#%d" % id
