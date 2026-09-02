#!/usr/bin/env bash
# Print the individual items behind reports/assets/item-trade.png as CSV.
#
#   ./tools/item_trade_dump.sh > reports/assets/item-trade.csv
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://tools/item_trade_dump.gd"
