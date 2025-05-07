#!/usr/bin/env bash

usage() {
  cat <<EOF
Usage: $(basename "$0") [-d DEVICE_ID] [-s SECRETS_FILE] [-h]

Start Flutter app on a device with staging secrets.

Options:
  -d DEVICE_ID       Specify device ID (default: $DEVICE_ID)
  -s SECRETS_FILE    Specify secrets file path (default: $SECRETS_FILE)
  -h, --help         Show this help message and exit
EOF
}

# Default values
DEVICE_ID="00008140-00062C6401D3001C"
SECRETS_FILE="secrets.staging.json"

# Translate long options to short ones
args=()
for arg in "$@"; do
  case "$arg" in
    --device) args+=("-d") ;;
    --secrets) args+=("-s") ;;
    --help) args+=("-h") ;;
    *) args+=("$arg") ;;
  esac
done
set -- "${args[@]}"

# Parse options
while getopts ":hd:s:" opt; do
  case $opt in
    h) usage; exit 0 ;;
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

# Launch Flutter app
echo "Starting Flutter app on device '$DEVICE_ID' with secrets file '$SECRETS_FILE'..."
flutter run -d "$DEVICE_ID" --dart-define-from-file="$SECRETS_FILE"

exit 0 