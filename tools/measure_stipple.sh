#!/usr/bin/env bash
# What the grass does to the ground under it: the share of pixels it touches,
# how far it brightens and darkens them, and where the colour goes -- at one
# blade-colour mix or a sweep of them. See measure_stipple.gd. Needs a display;
# use xvfb-run on a headless machine.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --path . --script res://tools/measure_stipple.gd -- "$@"
