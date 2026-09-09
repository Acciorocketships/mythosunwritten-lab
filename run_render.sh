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
# or right for free, and 0 ends your turn. The readout draws what is on offer --
# where you may go in green, what your weapons cover in rose -- and the buttons
# along its bottom press the same keys.
#
# The sheet is where what you carry is operated from: F turns the ring of what is
# carried and the sheet marks the row it is on, then 1 puts that on, 2 takes it
# off, 3 uses it up, X drops it and O offers it to whatever you have aimed at.
# The buttons along the bottom of the panel press those same keys.
# --no-model-tint draws the pack models in the colours they ship in, which is
# only useful for photographing what the biome tint is doing.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec "$GODOT" --path . -- "$@"
