# The atomic action set

Section 2.1's actions, as one call surface that a person's decision function and
a program's decision function use identically, with the engine resolving every
call and the caller only choosing it. Every call may fail, and a failure is a
sentence saying why.

Run it:

```
./run_actions.sh          # the one list, every action called once, a duel, two minds
./run_actions_suite.sh    # just this suite: 235 checks
./run_tests.sh            # all 31 suites
```

## 1. Section 2.1 and section 10 are one list, in one file

The design names the same set twice. Section 2.1 lists what a character may do;
section 10 lists the calls an agent makes to do it, and tells whoever reads it to
"keep the two in sync" -- a promise no code can check. So the two lists are not
written down twice here. `sim/action_catalog.gd` holds **one table**, and the two
are projections of it: the `listed` column is section 2.1's wording of a row, the
`calls` column is section 10's spelling of the same row.

| action | section 10's calls | section 2.1's wording |
|---|---|---|
| `go_to` | MoveTo, MoveRelative, Roam, Flee | go to (position / item / character) |
| `jump` | Jump | jump (position) |
| `attack` | Attack | attack (target, with which item) |
| `say` | Talk | say (text; targeted, or shout -> everyone in range hears) |
| `trade_propose` | ProposeTrade | trade (propose; items + money in/out) |
| `trade_accept` | AcceptTrade | trade (accept) |
| `trade_deny` | DenyTrade | trade (deny) |
| `pick_up` | Take | pick up (ground or chest) |
| `drop` | Drop | drop (ground or chest) |
| `examine` | Query, ViewInventory, AccessInventory | examine (observable info on an item/person in sight) |
| `interact` | Interact | interact (generic; target entity + item used) |
| `wait` | Wait | wait (duration) |

Twelve actions, seventeen call names. Several call names may share a row --
`MoveTo`, `MoveRelative`, `Roam` and `Flee` are four ways of saying "go to" --
because a row is the action and not the phrasing.

**Two of section 2.1's actions had no section 10 spelling at all.** Jump and wait
are in section 2.1's list and absent from section 10's call surface: the drift
this work item exists to end, present in the design document itself. Section 2.1
is authoritative, so the two rows carry `Jump` and `Wait` and the call surface is
now complete. No action was invented: both are section 2.1's, in section 2.1's
words.

### The check that they cannot drift

`ActionCatalog.faults(table, constructors, resolvers)` reads the table together
with the two files that implement it -- `Action.constructors()`, which is how a
caller says what it wants, and `ActionEngine.resolvers()`, which is what works it
out -- and returns one line per disagreement. It catches a row with no call name,
a row with no section 2.1 wording, one call name on two rows, an action nothing
can choose, an action nothing resolves, and a resolver for something that is not
an action.

`tests/test_actions.gd` runs it over the real table and requires nothing, and
then over **six deliberately broken copies**, each differing from the truth in
exactly one place, and requires each break to be caught:

| break | caught |
|---|---|
| `go_to` row with an empty `calls` column | yes |
| `jump` row with an empty section 2.1 wording | yes |
| `jump` row given `Attack` as its call name | yes |
| an extra `sing` row nothing chooses or resolves | yes |
| `wait` removed from the constructors | yes |
| `teleport` added to the resolvers | yes |

## 2. Every action exists and is callable

Not "the table has twelve rows" -- each row is chosen and resolved on a real
scene, and the world change it made is asserted. The suite walks the catalogue
rather than a list typed into the test, so an action added to the table with
nothing exercising it fails by leaving its name unticked.

The variants section 2.1 spells out are each exercised too: going to a position,
an item and a character; saying targeted and shouted; dropping on the ground and
into a chest; picking up from either; and a *gift*, which section 2.1 defines as
"a trade with nothing in return" and which is therefore not a separate call --
it is `trade_propose` with nothing wanted back.

`./run_actions.sh` plays eleven of the twelve on one scene, in the order a
character would take them (the twelfth needs a board, and is section 3 below):

```
  Rook examine(target=2) -> examine ok id=2 name=Wren kind=commander health=unhurt fighting=false equipment=- distance=1.5
  Rook say(text=well met target=2) -> say ok shout=false heard_by=1
  Rook say(text=anyone about?) -> say ok shout=true heard_by=1
  Rook go_to(target=3) -> go_to ok at=(-476.400, 420.000) walked=3.6 steps=4
  Rook pick_up(item=worn hatchet) -> pick_up ok item=worn hatchet from=3
  Rook drop(item=worn hatchet) -> drop ok item=worn hatchet into=5
  Rook jump(target=(-466.000, 420.000)) -> jump refused: 10.40 is further than DEX 4 jumps (4.50)
  Rook jump(target=(-472.500, 419.000)) -> jump ok at=(-472.500, 419.000) gap=4.026 reach=4.5 dex=4
  Rook go_to(target=4) -> go_to ok at=(-471.664, 419.334) walked=0.9 steps=1
  Rook interact(target=4) -> interact refused: the chest needs a lockpick
  Rook interact(target=4 item=lockpick) -> interact ok target=4 opened=true used=lockpick
  Rook pick_up(item=steel cap target=4) -> pick_up ok item=steel cap from=4
  Rook trade_propose(target=2 give=[] give_money=5 want=[leather boots] want_money=0) -> trade_propose ok …
  Wren trade_deny(target=1) -> trade_deny ok from=1
  Wren trade_accept(target=1) -> trade_accept refused: the offer from Rook was denied
  Wren trade_accept(target=1) -> trade_accept ok from=1 took=0 took_money=5 gave=1 gave_money=0
  Rook wait(ticks=5) -> wait ok ticks=5 until=5
```

Rook ends the walkthrough carrying the boots, the steel cap and the lockpick,
with 15 of the 20 coins; Wren has 8 and an empty pack. Every one of those moves
went through `Inventory.transfer`, which is the same all-or-nothing move that
picking up, dropping, giving and paying already were.

## 3. Any action may fail, and returns the reason

Every path out of `ActionEngine` is an `ActionOutcome`, and there is no bare
`false` anywhere in the layer. Failures come in three layers, kept separate on
purpose: the *choice* is malformed (an unknown action, a missing parameter, a
target of the wrong sort -- answered by `ActionCatalog.fault()` without looking
at the world at all); the *actor* cannot act; or the *world* says no.

All twelve are made to fail in the suite, each with a non-empty sentence, and
**twelve refusals in a row move nothing**: the scene's fingerprint before and
after the sweep is one string.

The four worked cases the acceptance names:

| case | the sentence returned |
|---|---|
| a jump farther than DEX allows | `8.00 is further than DEX 4 jumps (4.50)` |
| a refused trade | `the offer from Rook was denied` |
| an attack outside the weapon's pattern | `Vex is outside the pattern of a common bow from here` |
| an interact without the item it needs | `the chest needs a lockpick` |

Each is paired with the case that succeeds, so the refusal is the rule biting and
not the call being broken: a jump of 4.00 with the same DEX lands; the same offer
proposed again is accepted and the boots and coins change hands; the same target
attacked with a spear instead of a bow takes 18 damage; the same chest opens to
the lockpick. A trade denied is answered *as denied* rather than as one that was
never made, because a denial is written down after the offer itself is gone.

The interact case is three different sentences for three different mistakes: no
item offered (`the chest needs a lockpick`), an item named that the character
does not carry (`Rook carries no leather boots`), and an item carried that is not
the one required.

### How far a jump goes

Section 2.1 gives the failure -- "jumping farther than DEX allows" -- but no
number. The line is `JUMP_BASE + JUMP_PER_DEX x DEX`, which is `1.5 + 0.75 x DEX`
world units:

| DEX | unrecorded | 0 | 2 | 4 | 8 |
|---|---|---|---|---|---|
| reach | 1.50 | 1.50 | 3.00 | 4.50 | 7.50 |

An unrecorded score reads as no points rather than as the item-gate's fallback,
because a jump is not an item being read through a gate: there is no item, so
there is nothing to fall back to but the base.

## 4. The engine resolves; the caller only chooses

Section 10's first paragraph is the division: the decision-maker "never simulates
the world". So `ActionEngine.resolve(scene, actor, action)` is handed a world, a
character and a choice, and works out everything else -- how far a walk is, which
attack of an item reaches, whether a chest opens, what a trade moves.

Two structural checks, each with a control:

* **Nothing asks who is calling.** The five files implementing the surface are
  opened and read, with comments and string literals taken off so prose about
  people and programs is not read as a branch on one. No line matches
  `player|human|npc|agent|llm|bot|user|caller|is_player|controlled_by|decide|
  scripted|recorded` as a whole word. The same scan is then run over three
  control lines that *do* ask -- `if actor.is_player():`,
  `if actor.decide.is_valid() and actor.is_human:`, `if actor.agent != null:` --
  and must catch all three, and over three that do not, and must catch none.
* **No resolver can be handed anything else.** Every one of the twelve is
  declared as `static func _<name>(scene: ActionScene, actor: Combatant, action:
  Action) -> ActionOutcome`, checked by reading the file with its whitespace
  collapsed; so is the one entry point. There is no parameter in that signature
  to say what sort of thing is calling, and no second way in.

`sim/decision_source.gd` is deliberately outside that scan: it is the caller's
side of the line, and it is where the words "recorded" and "scripted" belong.

### The two derivations that keep a choice from being half a resolution

The attack call is where this was hardest, and two things are derived rather than
chosen:

* **Which attack of the item is used.** Section 10 spells the call
  `Attack(target, weapon/attack-mode derived from item)`, so the engine derives
  it: the first of the item's attacks that covers the target's cell and is off
  its cooldown.
* **Which way the character is facing.** Section 3.5 makes rotating free -- no
  turn, no action cost -- and the design names no turn action, so a caller has no
  way to aim. All four facings are therefore tried, the one the character already
  has first. "Outside the pattern" consequently means something exact: *no
  rotation of any of the item's patterns reaches the target*, which is a fact
  about the shape of the pattern and not about which way somebody happened to be
  looking. A bow, whose ring starts five cells out, cannot reach a target two
  cells away however it turns; a spear can.

The blow itself is not resolved here. `_attack` hands the chosen index to
`CombatMatch.attack`, which spends the turn's one weapon action and goes through
the one damage seam in `CombatResolution` -- so this layer contains no damage
arithmetic, no die and no defence, and the suite that asserts `Damage.resolve(`
appears in exactly one file under `sim/` still passes.

## 5. A person's decision function and a program's, on one surface

A decision function is a `Callable` taking the world and the character, and
returning one `Action`:

```
func(scene: ActionScene, actor: Combatant) -> Action
```

`DecisionSource.recorded(choices)` is a person: a function fed choices written
down in advance, which is what a person's turns look like once they have been
taken and what stands in for one in a headless test. `DecisionSource.scripted(rule)`
is a program: a rule that works its choice out from the world it is handed.
(`DecisionSource.plan(choices)` is the same written-down list as `recorded`, read
so that being asked again does not spend an entry -- which is what a driver that
re-evaluates, such as `ControlLoop`, needs; see reports/decision-plan.md. Under
`drive` below, where one call is one resolution, the two are the same thing.)
Both go on `Character.decide` -- the one field section 2's sheet set aside for
exactly this -- and both are called by `DecisionSource.drive`, which hands what
comes back to `ActionEngine.resolve` and cannot tell which it called.

Two scenes are set out identically. One is driven by a person's list, the other
by a rule that reads the world:

```
recorded choices, driven by a person's list
  go_to(target=3) -> go_to ok at=(-476.400, 420.000) walked=3.6 steps=4
  pick_up(item=worn hatchet) -> pick_up ok item=worn hatchet from=3
  examine(target=worn hatchet) -> examine ok item=worn hatchet seen=common weapon hand L1 …
  fingerprint d7f1a545d0c879a2
computed choices, driven by a rule reading the world
  go_to(target=3) -> go_to ok at=(-476.400, 420.000) walked=3.6 steps=4
  pick_up(item=worn hatchet) -> pick_up ok item=worn hatchet from=3
  examine(target=worn hatchet) -> examine ok item=worn hatchet seen=common weapon hand L1 …
  fingerprint d7f1a545d0c879a2
same world change: yes
```

The fingerprint covers every position, every item, every coin, every offer, every
refusal and everything said, so "the same world change" is one string compared
and not an impression. The suite also checks the comparison can tell two worlds
apart, and that the two decision functions really are different sorts of thing:
handed a world where the hatchet is already carried, the rule chooses differently
while the list cannot.

## 6. What did not move

* The seed-1234 world fingerprint is unchanged: tick 100 and final
  `d178d38879097c1c`, byte-identical to the run taken before this work started.
  Nothing here touches generation.
* All 31 suites pass. Two existing expectations were updated, both because this
  work added a file rather than because a claim weakened:
  `bin/test_main.gd` gained the new suite, and `tests/test_effects.gd`'s list of
  the files allowed to name a weapon gained `sim/scripted_actions.gd`, which is a
  scenario file and forges every weapon it names (`Weapon.held(...)` on the same
  line as the `wield(` that hands it over), exactly as the other two do.

## 7. Decisions taken, and why

* **One id space over characters and objects.** Section 10 gives an agent its
  surroundings as one numbered list -- "nearby entities: id; type
  (NPC/player/monster/object)" -- so a target is an id and the caller never has to
  know which sort of list a thing came from. `ActionScene` hands ids out from one
  counter. This is why the scene owns its actors rather than borrowing
  `CombatantRoster`'s: the roster numbers combatants from its own counter for its
  own fights, and two counters over one id space would be the same drift this
  work item exists to end.
* **A pile on the ground and a chest are one class.** `WorldObject` holds an
  `Inventory`, which is already the class a pile is; so taking something out of a
  chest and picking it up off the ground are one `Inventory.transfer` and there is
  no second path for the second case. A drop with nothing named joins whatever
  open pile is already within reach, so a character that drops three things leaves
  one pile.
* **A fight is borrowed whole, not re-implemented.** `attack` requires a fight to
  be under way and hands the swing to `CombatMatch`; attacking with no fight on is
  a refusal with a reason, not a second combat path.
* **`interact` is state and not a lock mechanic.** An object carries `needs` -- the
  name of the item an interaction must be made with -- and `shut`. Nothing in the
  engine knows what a lock is; what a particular object requires is set by whoever
  puts it in the world, which is where the orchestrator will set it.
* **A minion cannot choose.** Every action needs a character sheet behind it, and
  a minion is a piece without one. A minion is commanded, and choosing is what
  this whole layer is for; the refusal says `only a character acts`.

## 8. What is deliberately not here

* No language model, no prompt and no network call. This is the interface a model
  will later be given, and nothing in it needed one to build or to test.
* No user interface. A person's decision function here is a function fed recorded
  choices.
* No action the design does not name. The set is extensible -- a new row plus a
  constructor plus a resolver, and the drift check keeps the three together --
  but extending it is a later decision.
* No asset path and no render class under `sim/`; the layer check still passes.
* `wait` writes down when a character next expects to act and nothing enforces it,
  because section 2.2's loop re-evaluates while an action is in progress and may
  change its mind. Enforcing it is the control loop's decision, not this one's.
