#!/usr/bin/env bash

# Usage function
usage() {
  cat <<EOF
Usage: $(basename "$0") [-d SIMULATOR_ID] [-h]

Attach to the iOS simulator to stream Flutter logs.

Options:
  -d SIMULATOR_ID    Specify simulator ID (default: $SIMULATOR_ID)
  -h, --help         Show this help message and exit
EOF
}

# Default simulator ID
SIMULATOR_ID="325985CC-C12D-4BF9-BC82-59B7AB1ACB66"

# Support long options by translating them to short ones
args=()
for arg in "$@"; do
  case "$arg" in
    --device) args+=("-d") ;;  
    --help) args+=("-h") ;;    
    *) args+=("$arg") ;;       
  esac
done
set -- "${args[@]}"

# Parse options
while getopts ":hd:" opt; do
  case $opt in
    h) usage; exit 0 ;;   
    d) SIMULATOR_ID="$OPTARG" ;;  
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

# Validate prerequisites
command -v stdbuf >/dev/null 2>&1 || { echo "Error: 'stdbuf' not found. Please install coreutils." >&2; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "Error: 'flutter' not found in PATH." >&2; exit 1; }

# Stream Flutter logs
stdbuf -oL flutter logs -d "$SIMULATOR_ID" | tee offline_restart.log

exit 0