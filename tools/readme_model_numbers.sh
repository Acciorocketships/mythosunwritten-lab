#!/usr/bin/env bash
# Read the README's model-layer numbers back out of the transcripts that hold
# them: reports/agent-evidence.txt, reports/check-evidence.txt,
# reports/world-evidence.txt and net/model_recording.gd's own tables. Nothing is
# recorded and nothing is run -- it is a comparison of prose against artifacts.
# See tools/readme_model_numbers.py. No key, no network, no model.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
exec python3 tools/readme_model_numbers.py "$@"
