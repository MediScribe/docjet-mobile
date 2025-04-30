#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

DEVICE_ID="00008140-00062C6401D3001C"
SECRETS_FILE="secrets.staging.json"

echo "Ensuring secrets file '$SECRETS_FILE' exists..."
if [ ! -f "$SECRETS_FILE" ]; then
    echo "Error: Secrets file '$SECRETS_FILE' not found in project root."
    echo "Please ensure the file exists and contains the necessary API keys and domain."
    exit 1
fi
echo "Secrets file found."

echo "Starting Flutter app on device '$DEVICE_ID' with staging secrets..."

# Run the Flutter app using the default entry point (lib/main.dart)
# Load secrets from the specified JSON file using --dart-define-from-file
# Target the specific device ID
flutter run -d "$DEVICE_ID" --dart-define-from-file="$SECRETS_FILE"

echo "Flutter run finished or was interrupted."

# No background server process to clean up in this script 