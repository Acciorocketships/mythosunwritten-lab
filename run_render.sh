#!/usr/bin/env bash
# Run the same simulation with rendering, in a window.
#
#   ./run_render.sh              # seed 1234
#   ./run_render.sh --seed 7
#
#   ./run_render.sh --sheet --scenario encounter   # ...with the character sheet
#   ./run_render.sh --readout --scenario encounter # ...with the combat readout
#   ./run_render.sh --dialogue --trade --scenario agent
#                # the shipped model run's opening conversation, stood still,
#                # with the dialogue and trade panels reading it
#   ./run_render.sh --scenario bargain --play
#                # the play stage with the trader's mind a language model
#                # (the shipped recording), for buying a named item off him
#   ./run_render.sh --territory --scenario market
#                # the market run with the territory readout: how the followed
#                # character stands with everyone it knows, and who owns the
#                # ground it is standing on -- watch the trade flip the ground
#
#   ./run_render.sh --scenario volley
#                # an archer, a mage and a swordsman: the fight whose blows
#                # travel, so arrows and bolts visibly cross the board
#
#   ./run_render.sh --play               # drive one of the characters yourself
#   ./run_render.sh --play --journal     # ...and print what everybody chose
#
# A fight that starts by itself while you are playing draws itself: the tactical
# lattice appears under it and the combat readout opens beside it, both on the
# tick the board arrives, and both go away when the fight is over. The overworld
# is not latticed the rest of the time -- that is what --board is for.
#
# Needs a display. Escape quits, Space pauses, R restarts on the next seed, and
# Z opens or shuts the character sheet while you play.
#
# With --play the character the camera is following is yours: WASD or the arrow
# keys walk it a step, G sends it to the nearest named place, J hops and K leaps
# further than an ordinary DEX reaches, so the engine refuses it and says why on
# screen. Every one of those is an action out of the catalogue; the world's own
# control loop picks it up on its next tick, and on every tick you have not
# chosen anything your character waits in the world while everybody else carries
# on. --input "20:w,60:g" presses the keys for you at the ticks it names, which
# is how a run is driven on a machine with no keyboard at it, and
# --screenshot-ticks "4:one.png,32:two.png" photographs one run at several named
# moments so a story does not have to be told across several runs.
#
# --scenario battle --play --readout puts you in a fight: the encounter scenario
# with the camera on one of the two commanders, so the board comes round to you
# and waits. On your turn [ picks the next cell you may step onto and ] steps
# onto it, ; picks one of your minions, ' picks where it goes and \ sends it,
# 4 5 6 7 use the first to fourth weapon action, 8 and 9 turn you a quarter left
# or right for free, 0 ends your turn, and . walks you out of the fight
# altogether -- off the board where you stand, alive, back into real time.
# The readout draws what is on offer --
# where you may go in green, what your weapons cover in rose -- and the buttons
# along its bottom press the same keys.
#
# The sheet is where what you carry is operated from: F turns the ring of what is
# carried and the sheet marks the row it is on, then 1 puts that on, 2 takes it
# off, 3 uses it up, X drops it and O offers it to whatever you have aimed at.
# The buttons along the bottom of the panel press those same keys.
# --no-model-tint draws the pack models in the colours they ship in, which is
# only useful for photographing what the biome tint is doing. --no-fade stops
# the trees between the camera and your character from thinning out of the way,
# which is only useful for pricing that rule against a run that differs in
# nothing else.
#
# THE CAPTURE DIALS, and what became of the ones that are gone.
#
# The world is drawn by the adopted base's own shell now: render/main.tscn is an
# inherited scene of res://scenes/world.tscn, so the ground, its water, its
# grass, its villages, its sun and its sky are FieldTerrainStreamer's and
# AtmosphereDirector's. The dials that still mean something mean the same thing
# they did:
#
#   --camera X Y Z   where the camera sits relative to the person. It is now
#                    handed to the adopted camera as its height (Y) and its
#                    distance (the length of X and Z), which is the pair that
#                    camera is steered by.
#   --aim N          how far above the person it looks. Their camera looked at
#                    the body; `aim_lift` was added to scripts/camera/camera.gd
#                    for this, in their own idiom, and defaults to 0 for them.
#   --fov N          how wide the view is. Set on their Camera3D directly.
#   --paused         hold the world still. A held frame also asks the adopted
#                    camera for its settled pose outright rather than easing
#                    into one over frames it will never get.
#   --focus N        where the miniature depth of field is focused. The band is
#                    AtmosphereDirector's, built in its own _ready; this moves
#                    that band rather than building a second one, keeping the
#                    near/far ratio it was composed with.
#   --no-grass       is now the adopted streamer's own GRASS_ENABLED, set
#                    before its _ready runs: nothing baked, nothing instanced.
#   --no-atmosphere  switches off THIS GAME'S half of the atmosphere -- the warm
#                    point lights, the orbs, the motes, the ground mist. The
#                    adopted world still lights itself.
#
# Gone, with what replaced each:
#
#   --no-distant-ground   there is no second, coarser ground to switch off. The
#                         adopted streamer fills the distance itself, out to its
#                         own KEEP_RADIUS.
#   --lod-levels          the coarse-ring diagnostic went with that layer. The
#                         adopted streamer's own diagnostics are its
#                         PROFILE_STREAMING export and TerrainStreamingTelemetry.
#   --lod-centre          the same.
#   --no-reflection       this project's mirror drew the retired water sheet.
#   --mirror-aa           the same.
#   --grass-give-way      priced this project's grass giving way over a board
#                         square. The adopted grass's equivalent is its own
#                         TrampleField; nothing tunes it from the command line
#                         yet.
#
# One thing worth knowing about a capture: nothing steps until the ground has
# been built. The adopted streamer builds a chunk a frame and says when its
# startup chunks have landed ("render-shell ground ready frames=N"), and the
# world is held at tick 0 until then -- so `--screenshot-tick N` photographs a
# world with ground under it however long the machine took to mesh it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec "$GODOT" --path . -- "$@"
