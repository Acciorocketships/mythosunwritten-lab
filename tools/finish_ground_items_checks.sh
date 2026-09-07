#!/usr/bin/env bash
# Wait for the running full-suite job to exit, then run the two structure
# checks and the seed-1234 world fingerprint, sequentially and alone.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT=reports/ground-items-final-checks.txt
: > "$OUT"

echo "=== waiting for full suite (pid ${SUITE_PID:-none}) ===" >> "$OUT"
if [[ -n "${SUITE_PID:-}" ]]; then
	while [[ -r /proc/$SUITE_PID/stat ]]; do sleep 20; done
fi
echo "=== suite process gone at $(date -Is) ===" >> "$OUT"

echo "" >> "$OUT"
echo "=== structure checks: ./run_tests.sh --layers-only ===" >> "$OUT"
./run_tests.sh --layers-only >> "$OUT" 2>&1
echo "layers-only exit=$?" >> "$OUT"

echo "" >> "$OUT"
echo "=== world fingerprint: ./run_headless.sh --seed 1234 --ticks 100 ===" >> "$OUT"
./run_headless.sh --seed 1234 --ticks 100 >> "$OUT" 2>&1
echo "headless exit=$?" >> "$OUT"
echo "=== done at $(date -Is) ===" >> "$OUT"
