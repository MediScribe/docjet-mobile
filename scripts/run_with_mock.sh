#!/usr/bin/env bash
#
# Purpose : Launch the Flutter app in development mode optionally backed
#           by the mock API server.
#
# Usage   : ./scripts/run_with_mock.sh [--offline] [--help]
#
# Env vars:
#   DOCJET_DEVICE_ID   Override auto–detected iOS simulator UDID.
#
# Notes   :
#  • The script runs in "strict mode" (`set -euo pipefail`) so any failure
#    will abort the run immediately.
#  • When the mock server is started, the process is cleaned-up automatically
#    (even on Ctrl-C) thanks to the EXIT/INT traps.
#
#  Dollar Bill once said: "I'm not renting space to uncertainty." Neither
#  does this script.  Every command is deliberate and checked.

set -euo pipefail

#######################################
# Constants
#######################################
readonly API_VERSION="v1"
readonly API_PREFIX="api"
readonly SERVER_PORT=8080
readonly VERSIONED_API_PATH="$API_PREFIX/$API_VERSION"
readonly HEALTH_ENDPOINT="$VERSIONED_API_PATH/health"
readonly MAX_WAIT=30
readonly WAIT_INTERVAL=1

#######################################
# Helpers
#######################################

log() { printf '[run_with_mock] %s\n' "$*"; }

abort() { log "ERROR: $*"; exit 1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run the Flutter app with an optional mock API server.

Options
  --offline       Disable mock API server and run in offline mode
  --help          Display this help message and exit
EOF
}

#######################################
# Arg parsing
#######################################
OFFLINE_MODE=false

while (( $# )); do
  case "$1" in
    --offline) OFFLINE_MODE=true ;;
    --help)    usage; exit 0 ;;
    *)         abort "Unknown option: $1" ;;
  esac
  shift
done

#######################################
# Path variables
#######################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
MOCK_SERVER_DIR="$PROJECT_ROOT/packages/mock_api_server"

#######################################
# Simulator handling
#######################################
first_ios_sim_id() {
  local sim_id

  sim_id="$(xcrun simctl list devices booted | grep -Eo '[A-F0-9-]{36}' | head -n1 || true)"
  if [[ -n "$sim_id" ]]; then
    printf '%s' "$sim_id"
    return 0
  fi

  sim_id="$(xcrun simctl list devices | grep -m1 'iPhone' | grep -Eo '[A-F0-9-]{36}' || true)"
  [[ -z "$sim_id" ]] && abort "No iOS simulators found. Install one via Xcode."

  log "Booting simulator $sim_id..."
  xcrun simctl boot "$sim_id"
  sleep 5
  printf '%s' "$sim_id"
}

SIM_ID="${DOCJET_DEVICE_ID:-$(first_ios_sim_id)}"

#######################################
# Mock server lifecycle
#######################################
SERVER_PID=""

ensure_port_free() {
  lsof -t -i:"$SERVER_PORT" | xargs -r kill -9 || true
}

start_mock_server() {
  [[ -d "$MOCK_SERVER_DIR" ]] || abort "Mock server directory not found at $MOCK_SERVER_DIR"

  log "Starting mock API server on port $SERVER_PORT..."
  ensure_port_free

  pushd "$MOCK_SERVER_DIR" >/dev/null
  dart bin/server.dart --port "$SERVER_PORT" &
  SERVER_PID=$!
  popd >/dev/null
}

wait_for_server() {
  local elapsed=0
  local url="http://localhost:$SERVER_PORT/$HEALTH_ENDPOINT"

  log "Waiting for mock server at $url..."
  until curl -s --fail "$url" >/dev/null; do
    (( elapsed >= MAX_WAIT )) && abort "Mock server did not become ready within $MAX_WAIT seconds."
    sleep "$WAIT_INTERVAL"
    (( elapsed += WAIT_INTERVAL ))
  done
  log "Mock server is ready (after ${elapsed}s)"
}

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    log "Stopping mock API server (PID: $SERVER_PID)..."
    if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
      kill "$SERVER_PID"
      sleep 1
      kill -0 "$SERVER_PID" >/dev/null 2>&1 && kill -9 "$SERVER_PID"
    fi
  fi
}
trap cleanup EXIT INT

#######################################
# Main
#######################################
pushd "$PROJECT_ROOT" >/dev/null

if [[ "$OFFLINE_MODE" == false ]]; then
  start_mock_server
  wait_for_server
else
  log "Running in offline mode – mock server disabled."
fi

log "Launching Flutter app (entry: lib/main_dev.dart) on simulator $SIM_ID..."
flutter run -t lib/main_dev.dart -d "$SIM_ID"

log "Flutter run finished."
popd >/dev/null
