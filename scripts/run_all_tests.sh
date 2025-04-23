#!/bin/bash

# Exit on error, with a helpful message
function error_exit {
    echo "ERROR: $1"
    exit 1
}

echo "=================================="
echo "🧪 RUNNING ALL TESTS & VERIFICATIONS"
echo "=================================="

# Step 1: Run unit tests check
echo "🔎 Checking for failed unit tests..."
./scripts/list_failed_tests.dart || error_exit "Unit tests failed!"
echo "✅ All unit tests are passing!"

# Step 2: Run mock API server tests
echo "🔎 Checking mock API server tests..."
./scripts/list_failed_tests.dart mock_api_server || error_exit "Mock API server tests failed!"
echo "✅ All mock API server tests are passing!"

# Step 3: Run E2E tests
echo "🔎 Running E2E tests..."
./scripts/run_e2e_tests.sh || error_exit "E2E tests failed!"
echo "✅ All E2E tests passed!"

# Step 4: Run app with mock server and verify it starts
echo "🔎 Starting app with mock server..."
echo "Will verify app starts and is stable"

# Start the mock server wrapper script in the background
# The nohup is to ensure it doesn't get signals meant for this parent script
nohup ./scripts/run_with_mock.sh &
APP_PID=$!

# Check if the app started successfully
sleep 5
if ! ps -p $APP_PID > /dev/null; then
    error_exit "App failed to start!"
fi

echo "✅ App started successfully with PID: $APP_PID"
echo "Checking stability for 5 seconds..."

# Short stability check
sleep 5

# Final check that the app is still running
if ! ps -p $APP_PID > /dev/null; then
    error_exit "App crashed during stability check!"
fi

# Kill the app gracefully (SIGTERM first)
echo "App is stable! Sending SIGTERM to PID $APP_PID"
kill $APP_PID

# Wait a bit for graceful shutdown
sleep 2

# If still running, force kill
if ps -p $APP_PID > /dev/null; then
    echo "App still running, sending SIGKILL to PID $APP_PID"
    kill -9 $APP_PID
fi

echo "=================================="
echo "✅ ALL TESTS COMPLETE AND PASSING!"
echo "==================================" 