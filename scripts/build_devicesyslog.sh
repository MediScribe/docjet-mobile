#!/usr/bin/env bash
# scripts/build_devicesyslog.sh – Force-rebuild the native devicesyslog binary
# ---------------------------------------------------------------------------
# Usage: ./scripts/build_devicesyslog.sh
# Compiles packages/devicesyslog_cli/bin/devicesyslog.dart to tools/devicesyslog
# regardless of whether a binary already exists.
# ---------------------------------------------------------------------------

set -euo pipefail  # Hard Bob demands strict mode

# Set to 1 to enable debug output
DEBUG=0
if [[ "$DEBUG" -eq 1 ]]; then
  set -x  # Enable command echo
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
SRC_DART="$PROJECT_ROOT/packages/devicesyslog_cli/bin/devicesyslog.dart"
OUT_BIN="$PROJECT_ROOT/tools/devicesyslog"
OUT_DIR="$(dirname "$OUT_BIN")"

# Check dependencies
command -v dart >/dev/null 2>&1 || {
  echo "🔴  Dart SDK not found in PATH. Install it first (brew install dart)." >&2
  exit 1
}

# Check source file
if [[ ! -f "$SRC_DART" ]]; then
  echo "🔴  Source Dart file not found: $SRC_DART" >&2
  exit 1
fi

# Ensure tools directory exists
if [[ ! -d "$OUT_DIR" ]]; then
  echo "📁  Creating tools directory: $OUT_DIR"
  mkdir -p "$OUT_DIR" || {
    echo "🔴  Failed to create output directory: $OUT_DIR" >&2
    exit 1
  }
fi

# Check if output directory is writable
if [[ ! -w "$OUT_DIR" ]]; then
  echo "🔴  Output directory is not writable: $OUT_DIR" >&2
  exit 1
fi

echo "🏗   Rebuilding devicesyslog binary → $OUT_BIN"

dart compile exe "$SRC_DART" -o "$OUT_BIN"

chmod +x "$OUT_BIN" || {
  echo "🔴  Failed to make binary executable. Check file permissions." >&2
  exit 1
}

echo "✅  Build complete. Binary size: $(du -h "$OUT_BIN" | cut -f1)" 