#!/usr/bin/env bash
# Print the asset table: every tag in the catalog and what it resolves to.
#
#   ./run_assets.sh
#
# Exits 0 when every catalog tag has a row and no row is orphaned.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://bin/asset_report.gd
