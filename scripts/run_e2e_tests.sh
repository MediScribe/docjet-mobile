#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

PROJECT_ROOT=$(pwd) # Capture project root

# Define API version - MUST match ApiConfig.apiVersion and mock server's _apiVersion
API_VERSION="v1"
API_PREFIX="api"
SERVER_PORT=8080
SERVER_DOMAIN="localhost:$SERVER_PORT"
VERSIONED_API_PATH="$API_PREFIX/$API_VERSION"
HEALTH_ENDPOINT="$VERSIONED_API_PATH/health"

echo "Starting mock API server..."

# Force kill any existing process on port $SERVER_PORT before starting
echo "Ensuring port $SERVER_PORT is free..."
lsof -t -i:$SERVER_PORT | xargs kill -9 || true

cd packages/mock_api_server
# Start the server in the background and capture its PID
dart bin/server.dart --port $SERVER_PORT &
SERVER_PID=$!
cd ..
echo "Mock server started with PID: $SERVER_PID"

# Function to kill the server process
cleanup() {
	echo "Stopping mock API server (PID: $SERVER_PID)..."
	# Check if the process exists
	if kill -0 $SERVER_PID >/dev/null 2>&1; then
		# Try graceful shutdown first (SIGTERM)
		kill $SERVER_PID
		# Wait a moment for it to terminate
		sleep 2
		# Check if it's still running
		if kill -0 $SERVER_PID >/dev/null 2>&1; then
			echo "Server did not stop gracefully, forcing termination (SIGKILL)..."
			kill -9 $SERVER_PID
		else
			echo "Mock server stopped gracefully."
		fi
	else
		echo "Mock server already stopped or PID ($SERVER_PID) not found."
	fi
}

# Trap EXIT signal to ensure cleanup runs even if the script fails or is interrupted
trap cleanup EXIT

# Wait for the server to be ready by polling
MAX_WAIT=30     # Maximum seconds to wait
WAIT_INTERVAL=1 # Seconds between polls
ELAPSED=0
# Use the dedicated health check endpoint
SERVER_URL="http://$SERVER_DOMAIN/$HEALTH_ENDPOINT"

echo "Waiting for mock server at $SERVER_URL to be ready..."
while ! curl -s --fail "$SERVER_URL" >/dev/null; do
	# No headers needed for health check
	if [ $ELAPSED -ge $MAX_WAIT ]; then
		echo "Error: Mock server did not become ready within $MAX_WAIT seconds."
		exit 1 # Exit script, cleanup will run via trap
	fi
	sleep $WAIT_INTERVAL
	ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done
echo "Mock server is ready! (Took $ELAPSED seconds)"

cd "$PROJECT_ROOT" # Explicitly cd back to project root

echo "Running Flutter integration tests using secrets.test.json..."
# Run the actual tests, defining variables from the secrets file
# Always use the iOS simulator to avoid device selection prompt
flutter test integration_test/app_test.dart \
	--dart-define-from-file=secrets.test.json \
	-d "ios simulator"

echo "E2E tests finished."

# The cleanup function will run automatically on exit due to the trap
