#!/usr/bin/env bash
set -euo pipefail

# Usage: ci/check_startup_regression.sh <current_startup_json> <baseline_startup_json> [current_apk_path baseline_apk_size_file]
# Fails when:
#   • ΔTTFM (time-to-first-frame) > 100 ms
#   • APK/IPA size growth > 1 % (size check only runs when both optional args are provided)

# -------------------------------------------------------------------------------------------------
# Prerequisites: jq is MANDATORY. bc and du are required only when size diff check is executed.
# -------------------------------------------------------------------------------------------------

# Verify mandatory dependencies up-front so we fail fast with a clear error message.
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed or not on PATH" >&2
  exit 1
fi

# Optional dependencies for the size diff path. Check only if we are going to use them later.
function require_tool() {
  local tool_name=$1
  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "ERROR: $tool_name is required for APK size diff but is not installed" >&2
    exit 1
  fi
}

CURRENT_JSON=${1:-start_up_info.json}
BASELINE_JSON=${2:-perf/baseline/startup.json}
CURRENT_APK=${3:-}
BASELINE_APK_SIZE_FILE=${4:-perf/baseline/apk_size.txt}

if [[ ! -f "$CURRENT_JSON" ]]; then
  echo "Current startup json '$CURRENT_JSON' not found" >&2
  exit 1
fi
if [[ ! -f "$BASELINE_JSON" ]]; then
  echo "Baseline startup json '$BASELINE_JSON' not found" >&2
  exit 1
fi

# jq will output raw number (micros)
current_ttfm=$(jq '.timeToFirstFrameMicros' "$CURRENT_JSON")
baseline_ttfm=$(jq '.timeToFirstFrameMicros' "$BASELINE_JSON")

current_ms=$((current_ttfm/1000))
baseline_ms=$((baseline_ttfm/1000))

diff_ms=$((current_ms-baseline_ms))

printf "Baseline TTFM: %d ms\n" "$baseline_ms"
printf "Current  TTFM: %d ms\n" "$current_ms"

if (( diff_ms > 100 )); then
  echo "❌ Startup regression: ${diff_ms}ms (>100ms)" >&2
  exit 1
fi

echo "✅ Startup performance within 100ms budget (Δ${diff_ms}ms)"

# Binary size diff (optional)
if [[ -n "$CURRENT_APK" && -f "$CURRENT_APK" && -f "$BASELINE_APK_SIZE_FILE" ]]; then
  # Ensure du & bc are available before we proceed with the size check.
  require_tool du
  require_tool bc
  current_size=$(du -b "$CURRENT_APK" | cut -f1)
  baseline_size=$(cat "$BASELINE_APK_SIZE_FILE")
  if [[ -z "$baseline_size" ]]; then
    echo "Baseline APK size file empty" >&2
    exit 1
  fi
  diff=$((current_size-baseline_size))
  # percentage diff multiplied by 100 to avoid floating point
  percent=$((diff*10000 / baseline_size))
  # positive diff indicates growth
  if (( diff > 0 && percent > 100 )); then
    growth=$(echo "scale=2; $percent/100" | bc -l)
    echo "❌ APK size grew by ${growth}% (>1%)" >&2
    exit 1
  fi
  if (( diff >= 0 )); then sign="+"; else sign=""; fi
  echo "✅ APK size change ${sign}${diff} bytes (≤1%)"
fi 