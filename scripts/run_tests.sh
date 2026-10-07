#!/usr/bin/env bash
# Run semantic (no-pixel) tests for a Godot project: fast, dummy renderer.
# Usage: run_tests.sh <project-dir> [test-script...]
#   With no test-script args, runs every tests/test_*.gd in the project via --script.
# Each test script extends SceneTree (or MainLoop) and calls quit(exit_code) —
# nonzero exit fails the suite. Print "PASS <name>"/"FAIL <name>: <reason>" lines.
set -uo pipefail
PROJ="${1:?usage: run_tests.sh <project-dir> [test-script...]}"
shift || true

if [[ $# -eq 0 ]]; then
  mapfile -t TESTS < <(find "$PROJ/tests" -maxdepth 1 -name 'test_*.gd' 2>/dev/null | sort)
else
  TESTS=("$@")
fi

if [[ ${#TESTS[@]} -eq 0 ]]; then
  echo "no test scripts found under $PROJ/tests (expected test_*.gd)"; exit 1
fi

fails=0
for t in "${TESTS[@]}"; do
  name=$(basename "$t")
  echo "== $name"
  out=$(timeout 120 godot --headless --path "$PROJ" --script "res://${t#"$PROJ"/}" 2>&1)
  code=$?
  echo "$out" | grep -E '^(PASS|FAIL)' || true
  if [[ $code -ne 0 ]] || echo "$out" | grep -q '^FAIL'; then
    echo "$out" | grep -viE 'ALSA|alsa|audio' | tail -15
    fails=$((fails+1))
  fi
done

echo "== $(( ${#TESTS[@]} - fails ))/${#TESTS[@]} test scripts passed"
exit $(( fails > 0 ? 1 : 0 ))
