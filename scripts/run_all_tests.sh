#!/bin/bash

# Create a temp file for nohup output
TEMP_NOHUP_FILE=$(mktemp)

# Cleanup function to run on exit (even if script is interrupted)
function cleanup {
    echo "Cleaning up..."
    
    # Kill the app if it's still running
    if [[ -n "$APP_PID" ]] && ps -p $APP_PID > /dev/null; then
        echo "Killing app process (PID: $APP_PID)"
        kill -9 $APP_PID 2>/dev/null || true
    fi
    
    # Remove temp file
    if [[ -f "$TEMP_NOHUP_FILE" ]]; then
        rm -f "$TEMP_NOHUP_FILE"
    fi
    
    # Remove any nohup.out files in current directory
    if [[ -f "nohup.out" ]]; then
        rm -f nohup.out
    fi
    
    echo "Cleanup complete."
}

# Register cleanup to run on exit, interrupt, or terminate signals
trap cleanup EXIT INT TERM

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
./scripts/list_failed_tests.dart
if [[ $? -ne 0 ]]; then
    error_exit "Unit tests failed! See output above for details."
fi
echo "✅ All unit tests are passing!"

# Step 2: Run mock API server tests
echo "🔎 Checking mock API server tests..."
./scripts/list_failed_tests.dart mock_api_server
if [[ $? -ne 0 ]]; then
    error_exit "Mock API server tests failed! See output above for details."
fi
echo "✅ All mock API server tests are passing!"

# Step 3: Run E2E tests
echo "🔎 Running E2E tests..."
./scripts/run_e2e_tests.sh
E2E_RESULT=$?
if [[ $E2E_RESULT -ne 0 ]]; then
    error_exit "E2E tests failed or were interrupted! Exit code: $E2E_RESULT"
fi
echo "✅ All E2E tests passed!"

# Step 4: Run app with mock server and verify it starts
echo "🔎 Starting app with mock server..."
echo "Will verify app starts and is stable"

# Start the mock server wrapper script in the background
# Redirect output to our temp file instead of default nohup.out
nohup ./scripts/run_with_mock.sh > "$TEMP_NOHUP_FILE" 2>&1 &
APP_PID=$!

# Check if the app started successfully
sleep 5
if ! ps -p $APP_PID > /dev/null; then
    echo "Process failed to start. Last output:"
    tail -n 20 "$TEMP_NOHUP_FILE"
    error_exit "App failed to start!"
fi

echo "✅ App started successfully with PID: $APP_PID"
echo "Checking stability for 5 seconds..."

# Short stability check
sleep 5

# Final check that the app is still running
if ! ps -p $APP_PID > /dev/null; then
    echo "Process crashed. Last output:"
    tail -n 20 "$TEMP_NOHUP_FILE"
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