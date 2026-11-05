#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
# Keep both career saves and engine logs away from the player's data.
test_data_dir=$(mktemp -d /tmp/maras-tests.XXXXXX)
test_log="$test_data_dir/regression.log"
result=0
XDG_DATA_HOME="$test_data_dir" godot --headless --path . --fixed-fps 60 \
  --audio-driver Dummy res://tests/show_regression.tscn >"$test_log" 2>&1 || result=$?
cat "$test_log"
echo "Test artifacts: $test_data_dir"
if rg -q '^(SCRIPT ERROR|ERROR):|FAIL:|Regression watchdog' "$test_log"; then
  result=1
fi
if ! rg -q '^SHOW REGRESSION: [0-9]+ checks, 0 failures$' "$test_log"; then
  result=1
fi

# Optional end-to-end suites. Use --all for all suites, or --playability/--audio.
run_suite() {
  local scene="$1"
  local marker="$2"
  local filename="$3"
  local suite_log="$test_data_dir/$filename"
  local suite_result=0
  XDG_DATA_HOME="$test_data_dir" godot --headless --path . --fixed-fps 60 \
    --audio-driver Dummy "$scene" >"$suite_log" 2>&1 || suite_result=$?
  cat "$suite_log"
  if [[ "$suite_result" -ne 0 ]] || rg -q '^(SCRIPT ERROR|ERROR):|FAIL:|watchdog' "$suite_log" || ! rg -q "$marker" "$suite_log"; then
    result=1
  fi
}
if [[ "${1:-}" == "--playability" || "${1:-}" == "--all" ]]; then
  run_suite "res://tests/playability_regression.tscn" '^PLAYABILITY REGRESSION: [0-9]+ checks, 0 failures
# Usage: bash tests/run.sh --balance
if [[ "${1:-}" == "--balance" || "${1:-}" == "--all" ]]; then
  balance_log="$test_data_dir/balance.log"
  balance_result=0
  XDG_DATA_HOME="$test_data_dir" godot --headless --path . --fixed-fps 60 \
    --audio-driver Dummy res://tests/balance_benchmark.tscn >"$balance_log" 2>&1 || balance_result=$?
  cat "$balance_log"
  if [[ "$balance_result" -ne 0 ]] || rg -q '^(SCRIPT ERROR|ERROR):|FAIL:|BALANCE REGRESSION:' "$balance_log"; then
    result=1
  fi
  if ! rg -q '^BALANCE VISUAL REGRESSION: checks completed' "$balance_log" || ! rg -q '^BALANCE MEASUREMENTS ' "$balance_log"; then
    result=1
  fi
fi
exit "$result"
 "playability.log"
fi
if [[ "${1:-}" == "--audio" || "${1:-}" == "--all" ]]; then
  run_suite "res://tests/audio_regression.tscn" '^AUDIO REGRESSION: PASS
# Usage: bash tests/run.sh --balance
if [[ "${1:-}" == "--balance" ]]; then
  balance_log="$test_data_dir/balance.log"
  balance_result=0
  XDG_DATA_HOME="$test_data_dir" godot --headless --path . --fixed-fps 60 \
    --audio-driver Dummy res://tests/balance_benchmark.tscn >"$balance_log" 2>&1 || balance_result=$?
  cat "$balance_log"
  if [[ "$balance_result" -ne 0 ]] || rg -q '^(SCRIPT ERROR|ERROR):|FAIL:|BALANCE REGRESSION:' "$balance_log"; then
    result=1
  fi
  if ! rg -q '^BALANCE VISUAL REGRESSION: checks completed' "$balance_log" || ! rg -q '^BALANCE MEASUREMENTS ' "$balance_log"; then
    result=1
  fi
fi
exit "$result"
 "audio.log"
fi

# Run the longer balance/economy benchmark only when explicitly requested.
# Usage: bash tests/run.sh --balance
if [[ "${1:-}" == "--balance" ]]; then
  balance_log="$test_data_dir/balance.log"
  balance_result=0
  XDG_DATA_HOME="$test_data_dir" godot --headless --path . --fixed-fps 60 \
    --audio-driver Dummy res://tests/balance_benchmark.tscn >"$balance_log" 2>&1 || balance_result=$?
  cat "$balance_log"
  if [[ "$balance_result" -ne 0 ]] || rg -q '^(SCRIPT ERROR|ERROR):|FAIL:|BALANCE REGRESSION:' "$balance_log"; then
    result=1
  fi
  if ! rg -q '^BALANCE VISUAL REGRESSION: checks completed' "$balance_log" || ! rg -q '^BALANCE MEASUREMENTS ' "$balance_log"; then
    result=1
  fi
fi
exit "$result"
