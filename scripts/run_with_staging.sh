#!/usr/bin/env bash

# Hard Bob demands strict mode: abort on unset vars & pipe errors too.
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [-d SIMULATOR_ID] [-s SECRETS_FILE] [-r] [-p] [-l LOG_LEVEL] [-h]

Start Flutter app on a simulator with staging secrets.
If SIMULATOR_ID is not provided, Flutter will attempt to use the current open simulator.

Options:
  -d SIMULATOR_ID    Specify simulator device ID (optional)
  -s SECRETS_FILE    Specify secrets file path (default: secrets.staging.json)
  -r, --release      Build & run in release mode (optional)
  -p, --profile      Build & run in profile mode (optional)
  -l LOG_LEVEL       Override log level via compile-time define (e.g., debug, info)
  -h, --help         Show this help message and exit
EOF
}

# Default values
SIMULATOR_ID="" # Optional, Flutter will pick if not set
SECRETS_FILE="secrets.staging.json" # Default secrets file in project root
RELEASE_MODE=false   # Toggle via -r|--release
PROFILE_MODE=false   # Toggle via -p|--profile
LOG_LEVEL=""        # Optional compile-time log level override

# Translate long options to short ones if any were to be added later
args=()
for arg in "$@"; do
  case "$arg" in
    --device|--simulator) args+=("-d") ;;\
    --secrets) args+=("-s") ;;\
    --release) args+=("-r") ;;\
    --profile) args+=("-p") ;;\
    --log-level) args+=("-l") ;;\
    --help) args+=("-h") ;;\
    *) args+=("$arg") ;;\
  esac
done
set -- "${args[@]}"

# Parse options (note the trailing colon only for opts requiring args)
while getopts ":hd:s:rpl:" opt; do
  case $opt in
    h) usage; exit 0 ;;\
    d) SIMULATOR_ID="$OPTARG" ;;\
    s) SECRETS_FILE="$OPTARG" ;;\
    r) RELEASE_MODE=true ;;\
    p) PROFILE_MODE=true ;;\
    l) LOG_LEVEL="$OPTARG" ;;\
    :) echo "Error: Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;\
    \?) echo "Error: Invalid option -$OPTARG" >&2; usage; exit 1 ;;\
  esac
done
shift $((OPTIND - 1))

# Validate mutually exclusive flags
if [ "$RELEASE_MODE" = true ] && [ "$PROFILE_MODE" = true ]; then
  echo "Error: --release and --profile are mutually exclusive." >&2
  exit 1
fi

# Check for unexpected arguments
if [ $# -gt 0 ]; then
  echo "Error: Unexpected argument(s): $*" >&2
  usage
  exit 1
fi

# Validate flutter presence
command -v flutter >/dev/null 2>&1 || { echo "Error: 'flutter' not found in PATH." >&2; exit 1; }

# Check if simulator ID exists (if specified)
if [ -n "$SIMULATOR_ID" ]; then
  echo "Using simulator: $SIMULATOR_ID"
  flutter_args=("--device-id=$SIMULATOR_ID")
else
  flutter_args=()
fi

# Add profile/release flags if requested
if [ "$PROFILE_MODE" = true ]; then
  flutter_args+=("--profile")
fi

if [ "$RELEASE_MODE" = true ]; then
  flutter_args+=("--release")
fi

# Add log level if provided
if [ -n "$LOG_LEVEL" ]; then
  flutter_args+=("--dart-define=LOG_LEVEL=$LOG_LEVEL")
fi

# Resolve secrets file path (absolute or project root-relative)
SCRIPT_DIR_REAL=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_ROOT="$SCRIPT_DIR_REAL/.."
if [[ "$SECRETS_FILE" == /* ]]; then
  SECRETS_FILE_PATH="$SECRETS_FILE"
else
  SECRETS_FILE_PATH="$PROJECT_ROOT/$SECRETS_FILE"
fi

# Verify secrets file exists
if [ ! -f "$SECRETS_FILE_PATH" ]; then
  echo "Error: Secrets file '$SECRETS_FILE_PATH' not found." >&2
  exit 1
fi

# Pass the potentially adjusted SECRETS_FILE_PATH
flutter_args+=("--dart-define-from-file=$SECRETS_FILE_PATH")

# Run the app with the collected arguments
echo "Running flutter run ${flutter_args[*]}"
flutter run "${flutter_args[@]}"

exit 0 