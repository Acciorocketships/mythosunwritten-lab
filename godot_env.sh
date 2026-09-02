#!/usr/bin/env bash
# Shared setup for the run scripts: locate the engine and give it a writable,
# project-local home for its cache and settings.
#
# The engine binary is not in git (it is 140 MB); tools/godot/godot4 is where the
# stack survey installed it. Set GODOT to use a different one.
GODOT="${GODOT:-$PWD/tools/godot/godot4}"
if [[ ! -x "$GODOT" ]]; then
	echo "godot binary not found at $GODOT" >&2
	echo "install Godot 4.7+ there, or set GODOT=/path/to/godot" >&2
	exit 127
fi

# Godot writes settings and an import cache under \$HOME. Keeping that inside the
# project makes runs reproducible and works where the real home is read-only.
export HOME="${GAME_GODOT_HOME:-$PWD/tools/godot-home}"
mkdir -p "$HOME"

# A fresh clone has no import cache, and without one the engine does not know the
# project's script class names, so entry points fail to parse. Build it once.
if [[ ! -f .godot/global_script_class_cache.cfg ]]; then
	echo "first run: importing project..." >&2
	env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . --import >/dev/null
fi
