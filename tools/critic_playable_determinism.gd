extends SceneTree
## The world at one seed, with a person in its cast, printed in full.
##
## Written by the review of the playable layer (W-playable-review). Two
## processes run this and their bytes are compared: if a person in the cast made
## the world depend on anything but the seed -- a clock, a hash of an address, a
## thread -- the two transcripts would part company.
##
## The person is not a stand-in here. `WorldCast.hand_over` puts
## `DecisionSource.live` on the followed character's sheet, and the presses
## below are made from outside the loop, between ticks, the way a hand's are.
## Beside them a second character is handed to a language model reading a
## channel, so both of the minds that cannot answer at once are in the run.
##
## Everything printed is a fact about the seed: the journal the control loop
## wrote, the world's own digest every ten ticks, and the counters on the two
## holders.
##
## Run:  tools/critic_playable_determinism.sh

const SEED := 1234
const TICKS := 90

## When the person presses, and what they choose. Written down here so that the
## two processes press at the same ticks -- a fixed hand, not a fixed mind.
const PRESSES := {3: 0, 20: 1, 40: 2, 60: 0}


func _initialize() -> void:
	var world := SimWorld.new(SEED)
	var id := world.follow_id
	var driven := world.combat.member_of(id)
	var hand := WorldCast.hand_over(world, id)

	# A second of the cast, given a language model for a mind, so the run holds
	# both of the minds that answer late.
	var modelled := _someone_else(world, id)
	var mind: ModelMind = null
	if modelled != null:
		mind = ModelMind.with_channel(ModelChannel.replaying({
			"rows": [
				{"prompt": "", "reply": "wait ticks=6", "ms": 0},
				{"prompt": "", "reply": "go_to offset=(3.000, 0.000)", "ms": 0},
				{"prompt": "", "reply": "wait ticks=4", "ms": 0},
			],
			"from": "written by the review", "model": "none",
		}, "a channel the review wrote, so the model arm is a fact about the seed"))
		_sheet(modelled).decide = DecisionSource.model(mind)

	var choices := [
		Action.go_to(Vector2(driven.x + 6.0, driven.z + 2.0)),
		Action.jump(Vector2(driven.x + 8.0, driven.z + 3.0)),
		Action.wait(5),
	]

	print("seed %d, %d ticks" % [SEED, TICKS])
	print("the person drives #%d (%s)" % [id, ActionScene.name_of(driven)])
	print("a language model drives %s" % (
		"nobody -- the cast held only the person" if modelled == null
		else "#%d (%s)" % [modelled.id, ActionScene.name_of(modelled)]))
	print("")

	var digests := PackedStringArray()
	for _step in TICKS:
		if PRESSES.has(world.tick):
			hand.choose(choices[int(PRESSES[world.tick])])
		world.step()
		if world.tick % 10 == 0:
			digests.append("  t=%3d  %s" % [world.tick, world.digest()])

	print("--- the journal")
	for line in world.loop.journal:
		print("  %s" % line)
	print("")
	print("--- the world's digest every ten ticks")
	for line in digests:
		print(line)
	print("")
	print("--- the holders")
	print("  the person: made=%d offered=%d carried_out=%d standing=%s" % [
		hand.made, hand.offered, hand.carried_out, hand.line()])
	if mind != null:
		print("  the model: consulted=%d opened=%d held=%d answered=%d" % [
			mind.consulted, mind.opened, mind.held, mind.answered()])
	print("  actions resolved for the person: %d" % world.loop.actions_of(id))
	print("  final digest: %s" % world.digest())
	quit(0)


# Somebody in the cast who is not the person, and who has a sheet to put a mind
# on.
func _someone_else(world: SimWorld, not_this: int) -> Combatant:
	for one in world.combat.scene.actors:
		if one.id == not_this:
			continue
		if _sheet(one) != null:
			return one
	return null


func _sheet(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
