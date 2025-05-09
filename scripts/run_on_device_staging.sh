#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [-d DEVICE_ID] [-s SECRETS_FILE] [-h] [-r|--release]

Start Flutter app on a device with staging secrets.

Options:
  -d DEVICE_ID       Specify device ID (default: $DEVICE_ID)
  -s SECRETS_FILE    Specify secrets file path (default: $SECRETS_FILE)
  -r, --release      Run the app in release mode (untethered)
  -h, --help         Show this help message and exit
EOF
}

# Default values
DEVICE_ID="00008140-00062C6401D3001C"
SECRETS_FILE="secrets.staging.json"
RELEASE_MODE=false

# Translate long options to short ones
args=()
for arg in "$@"; do
  case "$arg" in
    --device) args+=("-d") ;;
    --secrets) args+=("-s") ;;
    --release) args+=("-r") ;;
    --help) args+=("-h") ;;
    *) args+=("$arg") ;;
  esac
done
set -- "${args[@]}"

# Parse options
while getopts ":hrd:s:" opt; do
  case $opt in
    h) usage; exit 0 ;;
    r) RELEASE_MODE=true ;;
    d) DEVICE_ID="$OPTARG" ;;
    s) SECRETS_FILE="$OPTARG" ;;
    :) echo "Error: Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
    \?) echo "Error: Invalid option -$OPTARG" >&2; usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

# Check for unexpected arguments
if [ $# -gt 0 ]; then
  echo "Error: Unexpected argument(s): $*" >&2
  usage
  exit 1
fi

# Validate flutter presence
command -v flutter >/dev/null 2>&1 || { echo "Error: 'flutter' not found in PATH." >&2; exit 1; }

# Verify secrets file exists
echo "Ensuring secrets file '$SECRETS_FILE' exists..."
if [ ! -f "$SECRETS_FILE" ]; then
  echo "Error: Secrets file '$SECRETS_FILE' not found." >&2
  exit 1
fi
echo "Secrets file found."

# Build flutter command array (no eval, no injection risks)
cmd=(flutter run -d "$DEVICE_ID" --dart-define-from-file="$SECRETS_FILE")
if [ "$RELEASE_MODE" = true ]; then
  echo "Starting Flutter app in RELEASE mode on device '$DEVICE_ID' with secrets file '$SECRETS_FILE'..."
  cmd+=(--release)
else
  echo "Starting Flutter app on device '$DEVICE_ID' with secrets file '$SECRETS_FILE'..."
fi

# Execute and propagate exit code automatically
"${cmd[@]}" 
