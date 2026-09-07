extends RefCounted
## The play stage with the trader's mind a language model: the stage a person
## buys a specific named item from a model-driven trader on.
##
##     ./tools/bargain_actions.sh                    # the run, printed
##     ./run_render.sh --scenario bargain --play     # the same stage, lived
##
## `sim/scripted_play.gd` is the smallest world every atomic action can be
## reached from, and its trader Hob drives a written-down bargain: he sells his
## lantern at his price and denies any bargain that asks him for anything. That
## rule is exactly what makes him the wrong subject for the one thing the play
## stage cannot show -- a person *buying a named item*, which needs the other
## side to weigh an offer rather than to match it against a rule. So this file
## is that stage again, byte for byte -- the same cast, the same gear, the same
## pile and chest on the same seed -- with one change: Hob decides by asking a
## language model, through the same `ModelMind` the shipped market run gives
## five of its six characters.
##
## ## What Hob is after, which is scenario setup and not steering
##
## Hob starts the run wanting to be carrying `AFTER_MONEY` coins or more, put on
## his sheet by `set_out()` exactly as the shipped run's Pell is given its
## three: a scene has to start somewhere, and a trader standing at a stall
## after nothing at all has no reason to part with the one thing he owns. The
## goal names something the world holds, so the world answers it out of its own
## state on every question; nothing here tells the model to sell, at what
## price, or to whom. He opens with `ScriptedPlay.HOB_MONEY` coins and the
## lantern's asking price is `ScriptedPlay.LANTERN_PRICE`, so the goal is
## reachable by exactly one honest sale -- or by whatever else the model
## thinks of.
##
## ## Nothing here is a mechanic
##
## The observation Hob's model reads, the offer it sees standing, the pack it
## is shown across that offer and the refusals it gets are all the same rules
## every character lives under (`sim/observation.gd`, `sim/action_engine.gd`).
## This file stages; it resolves nothing and steers nobody.
class_name ScriptedBargain

## The seed and the cast: the play stage's own, restated from nowhere.
const SEED := ScriptedPlay.SEED
const HOB := ScriptedPlay.HOB
const FEN := ScriptedPlay.FEN

## How many coins Hob wants to be carrying: his opening purse plus the price he
## has always asked for the lantern, so one honest sale closes it.
const AFTER_MONEY := ScriptedPlay.HOB_MONEY + ScriptedPlay.LANTERN_PRICE

## The seed the control loop hashes its continue-bias draws from, when the run
## is played outside a world. The shipped scenario's, for the shipped reason:
## two processes replaying the same exchange must draw the same.
const LOOP_SEED := ScriptedScenario.LOOP_SEED


## Set the stage out in a world, with Hob's mind on the channel handed in, and
## hand back how many characters are in it.
##
## The world's own control loop services everybody from here on, so the person
## handed Fen (`--play`, or a suite's written-down key presses) and the model
## behind Hob are asked through one loop that is not told which is which.
static func muster(world: SimWorld, minds: ModelChannel) -> int:
	world.clear_cast()
	var scene := world.combat.scene
	ScriptedPlay.populate(scene)
	drive(scene, minds)
	var fen := ScriptedPlay.id_of(scene, FEN)
	if fen != 0:
		world.follow(fen)
	for one in scene.actors:
		one.settle(world.terrain)
	for thing in scene.objects:
		thing.settle(world.terrain)
	return scene.actors.size()


## Put the decision functions on: the play stage's own, then Hob's replaced by
## a model mind asking through the channel handed in.
##
## `ScriptedPlay.drive` is called first and unchanged, so the stage
## `--scenario play` sets out is what it always was and no rule of it is
## restated here. The channel is handed in rather than chosen, so nothing in
## this file decides where an answer comes from -- the shipped run's is the
## recorded exchange, a recording pass's is a live transport.
static func drive(scene: ActionScene, minds: ModelChannel) -> ModelCast:
	ScriptedPlay.drive(scene)
	var cast := ModelCast.over(scene, minds, null, [HOB])
	set_out(scene)
	return cast


## Put what Hob is after onto his own sheet: to be carrying `AFTER_MONEY` coins
## or more. Scenario setup, not steering; see the head of this file.
static func set_out(scene: ActionScene) -> GoalSet:
	var hob := scene.actor_of(ScriptedPlay.id_of(scene, HOB))
	if hob == null or not (hob.piece is Commander):
		return null
	var sheet := (hob.piece as Commander).sheet
	sheet.goals.add(Goal.of(
		Goal.MONEY, {"amount": AFTER_MONEY}, "", Goal.SHORT, 0))
	return sheet.goals
