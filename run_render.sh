#!/usr/bin/env bash
# Run the same simulation with rendering, in a window.
#
#   ./run_render.sh              # seed 1234
#   ./run_render.sh --seed 7
#
#   ./run_render.sh --sheet --scenario encounter   # ...with the character sheet
#   ./run_render.sh --readout --scenario encounter # ...with the combat readout
#
#   ./run_render.sh --play               # drive one of the characters yourself
#   ./run_render.sh --play --journal     # ...and print what everybody chose
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
