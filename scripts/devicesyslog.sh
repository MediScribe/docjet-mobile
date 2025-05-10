#!/usr/bin/env bash
# scripts/devicesyslog.sh – One-touch iOS log viewer for the DocJet app
#
# Usage: ./scripts/devicesyslog.sh [--save] [--wifi] [--help]
#   --save   Also save logs to timestamped file (same behaviour as CLI flag)
#   --wifi   Connect via Wi-Fi instead of USB (device must support Wi-Fi Sync)
#   --help   Show this help and exit
#
# The script auto-detects your device UDID when only one is connected.
# If multiple devices are found it lets you pick interactively.
# It then launches the compiled devicesyslog binary with the DocJet bundle ID
# pre-filled so you never have to remember it.

set -euo pipefail

DOCJET_BUNDLE_ID="com.docjet.mobile"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
BINARY="${ROOT_DIR}/tools/devicesyslog"

SAVE_FLAG=""
WIFI_FLAG=""

# Parse CLI flags (robust while/shift loop)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --save) SAVE_FLAG="--save" ;;
    --wifi) WIFI_FLAG="--wifi" ;;
    --help|-h)
      grep "^# Usage:" -A3 "$0" | sed 's/^# *//'
      exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1 ;;
  esac
  shift
done

# Ensure dependencies exist
command -v idevice_id >/dev/null 2>&1 || { printf '\n🔴  '\''idevice_id'\'' not found. Install libimobiledevice (brew install libimobiledevice)\n' >&2; exit 1; }
# Check Dart SDK for on-the-fly compilation
command -v dart >/dev/null 2>&1 || { printf '\n🔴  '\''dart'\'' not found. Install the Dart SDK (brew install dart)\n' >&2; exit 1; }

# Build binary on-the-fly if missing
if [[ ! -x "$BINARY" ]]; then
  echo "ℹ️  Compiled devicesyslog binary not found – building it now (one-time)…"
  (cd "$ROOT_DIR" && dart compile exe packages/devicesyslog_cli/bin/devicesyslog.dart -o tools/devicesyslog) || {
    echo "🔴  Failed to build devicesyslog binary" >&2; exit 1; }
fi

# Detect connected devices
DEVICES=$(idevice_id -l || true)
# shellcheck disable=SC2207
DEVICES_ARRAY=($(echo "$DEVICES"))
DEVICE_COUNT=${#DEVICES_ARRAY[@]}

# Helper to fetch human-readable name; falls back gracefully
function _device_name() {
  local udid="$1"
  if command -v ideviceinfo >/dev/null 2>&1; then
    ideviceinfo -u "$udid" -k DeviceName 2>/dev/null || echo "Unknown iOS Device"
  else
    echo "iOS Device"
  fi
}

if [[ "$DEVICE_COUNT" -eq 0 ]]; then
  echo "🔴  No iOS devices detected. Plug in a device via USB and make sure it's trusted." >&2
  exit 1
elif [[ "$DEVICE_COUNT" -eq 1 ]]; then
  SELECTED_DEVICE="${DEVICES_ARRAY[0]}"
  DEVICE_NAME=$(_device_name "$SELECTED_DEVICE")
  echo "✅  Using connected device: ${DEVICE_NAME} (${SELECTED_DEVICE})"
else
  echo "Multiple iOS devices detected. Choose one:"
  # Show a numbered list with friendly names
  i=1
  for udid in "${DEVICES_ARRAY[@]}"; do
    printf "%2d) %s (%s)\n" "$i" "$(_device_name "$udid")" "$udid"
    ((i++))
  done

  PS3="Select device #: "
  select choice in "${DEVICES_ARRAY[@]}"; do
    if [[ -n "$choice" ]]; then
      SELECTED_DEVICE="$choice"; break; fi
    echo "Invalid selection – try again."
  done
fi

CMD=("$BINARY" --bundle-id "$DOCJET_BUNDLE_ID" --udid "$SELECTED_DEVICE" $SAVE_FLAG $WIFI_FLAG)
# Flatten array (in case some flags are empty strings)
RUN_CMD=()
for part in "${CMD[@]}"; do [[ -n "$part" ]] && RUN_CMD+=("$part") ; done

printf "\n🚀  Starting devicesyslog with command: %s\n\n" "${RUN_CMD[*]}"
exec "${RUN_CMD[@]}" 

