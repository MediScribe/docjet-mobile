#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Starting mock API server..."
# Check if mock_api_server exists relative to script location
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
MOCK_SERVER_DIR="$SCRIPT_DIR/../mock_api_server"

if [ ! -d "$MOCK_SERVER_DIR" ]; then
	echo "Error: Mock server directory not found at $MOCK_SERVER_DIR"
	exit 1
fi

cd "$MOCK_SERVER_DIR"
# Start the server in the background and capture its PID
dart bin/server.dart &
SERVER_PID=$!
cd "$SCRIPT_DIR/.." # Go back to project root
echo "Mock server started with PID: $SERVER_PID"

# Function to kill the server process
cleanup() {
	echo "Stopping mock API server (PID: $SERVER_PID)..."
	# Check if the process exists using kill -0
	if kill -0 $SERVER_PID >/dev/null 2>&1; then
		# Try graceful shutdown first (SIGTERM)
		kill $SERVER_PID
		# Wait a moment for it to terminate
		sleep 1
		# Check if it's still running
		if kill -0 $SERVER_PID >/dev/null 2>&1; then
			echo "Server did not stop gracefully, forcing termination (SIGKILL)..."
			kill -9 $SERVER_PID
		else
			echo "Mock server stopped gracefully."
		fi
	else
		# This handles cases where the server might have already stopped or the PID is stale
		echo "Mock server process (PID: $SERVER_PID) not found or already stopped."
	fi
}

# Trap EXIT and INT signals to ensure cleanup runs
# EXIT: Runs when the script finishes normally or due to 'exit' or 'set -e' failure
# INT: Runs when Ctrl+C is pressed
trap cleanup EXIT INT

echo "Starting Flutter app with mock server config (secrets.test.json)..."
# Run the flutter app, defining variables from the secrets file
# Flutter run will keep running until interrupted (e.g., Ctrl+C) or it quits
flutter run --dart-define-from-file=secrets.test.json

# Since flutter run is interactive and we want the trap to handle cleanup
# when flutter run exits or is interrupted, we don't need a 'wait' here.
# The script will naturally exit after flutter run finishes, triggering the EXIT trap.
# Pressing Ctrl+C triggers the INT trap.

echo "Flutter run finished."

# The cleanup function will run automatically on exit due to the trap
