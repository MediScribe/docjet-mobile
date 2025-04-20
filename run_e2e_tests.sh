#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Starting mock API server..."
cd mock_api_server
# Start the server in the background and capture its PID
dart bin/server.dart &
SERVER_PID=$!
cd ..
echo "Mock server started with PID: $SERVER_PID"

# Function to kill the server process
cleanup() {
  echo "Stopping mock API server (PID: $SERVER_PID)..."
  # Check if the process exists
  if kill -0 $SERVER_PID > /dev/null 2>&1; then
    # Try graceful shutdown first (SIGTERM)
    kill $SERVER_PID
    # Wait a moment for it to terminate
    sleep 2 
    # Check if it's still running
    if kill -0 $SERVER_PID > /dev/null 2>&1; then
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
MAX_WAIT=30 # Maximum seconds to wait
WAIT_INTERVAL=1 # Seconds between polls
ELAPSED=0
# Target a real (but simple) endpoint and include the API key
SERVER_URL="http://localhost:8080/api/v1/jobs"
API_KEY="test-api-key"
# Add a dummy bearer token required by the mock server's auth middleware
DUMMY_TOKEN="dummy-bearer-token"

echo "Waiting for mock server at $SERVER_URL to be ready..."
while ! curl -s --head --fail \
  -H "X-API-Key: $API_KEY" \
  -H "Authorization: Bearer $DUMMY_TOKEN" \
  "$SERVER_URL" > /dev/null; do
  if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "Error: Mock server did not become ready within $MAX_WAIT seconds."
    exit 1 # Exit script, cleanup will run via trap
  fi
  sleep $WAIT_INTERVAL
  ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done
echo "Mock server is ready! (Took $ELAPSED seconds)"

echo "Running Flutter integration tests with mock server URL and API key..."
# Run the actual tests, defining BASE_URL and API_KEY for the app to use
flutter test integration_test/app_test.dart \
  --dart-define=BASE_URL=http://localhost:8080/api/v1 \
  --dart-define=API_KEY=test-api-key

echo "E2E tests finished."

# The cleanup function will run automatically on exit due to the trap 