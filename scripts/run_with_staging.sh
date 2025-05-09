#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -e

usage() {
  cat <<EOF
Usage: $(basename "$0") [-d SIMULATOR_ID] [-s SECRETS_FILE] [-h]

Start Flutter app on a simulator with staging secrets.
If SIMULATOR_ID is not provided, Flutter will attempt to use the current open simulator.

Options:
  -d SIMULATOR_ID    Specify simulator device ID (optional)
  -s SECRETS_FILE    Specify secrets file path (default: secrets.staging.json)
  -h, --help         Show this help message and exit
EOF
}

# Default values
SIMULATOR_ID="" # Optional, Flutter will pick if not set
SECRETS_FILE="secrets.staging.json" # Default secrets file in project root

# Translate long options to short ones if any were to be added later
args=()
for arg in "$@"; do
  case "$arg" in
    --device|--simulator) args+=("-d") ;;\
    --secrets) args+=("-s") ;;\
    --help) args+=("-h") ;;\
    *) args+=("$arg") ;;\
  esac
done
set -- "${args[@]}"

# Parse options
while getopts ":hd:s:" opt; do
  case $opt in
    h) usage; exit 0 ;;\
    d) SIMULATOR_ID="$OPTARG" ;;\
    s) SECRETS_FILE="$OPTARG" ;;\
    :) echo "Error: Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;\
    \\?) echo "Error: Invalid option -$OPTARG" >&2; usage; exit 1 ;;\
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

# Construct path to secrets file relative to project root
# Assuming this script is in 'scripts/' and project root is one level up
SCRIPT_DIR_REAL=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_ROOT="$SCRIPT_DIR_REAL/.."
SECRETS_FILE_PATH="$PROJECT_ROOT/$SECRETS_FILE"

# If SECRETS_FILE was provided as an absolute path, use it directly
if [[ "$SECRETS_FILE" == /* ]]; then
  SECRETS_FILE_PATH="$SECRETS_FILE"
fi

# Verify secrets file exists
echo "Ensuring secrets file '$SECRETS_FILE_PATH' exists..."
if [ ! -f "$SECRETS_FILE_PATH" ]; then
  echo "Error: Secrets file '$SECRETS_FILE_PATH' not found." >&2
  echo "Please ensure it exists or specify the correct path using -s." >&2
  exit 1
fi
echo "Secrets file found."

# Build the flutter command arguments
flutter_args=()
if [ -n "$SIMULATOR_ID" ]; then
  flutter_args+=("-d" "$SIMULATOR_ID")
fi
# Pass the potentially adjusted SECRETS_FILE_PATH
flutter_args+=("--dart-define-from-file=$SECRETS_FILE_PATH")

# Launch Flutter app
echo "Starting Flutter app with secrets file '$SECRETS_FILE_PATH'..."
if [ -n "$SIMULATOR_ID" ]; then
  echo "Targeting simulator ID: '$SIMULATOR_ID'"
else
  echo "No simulator ID specified, Flutter will select target."
fi

flutter run "${flutter_args[@]}"

exit 0 