#!/bin/bash

# Exit on error
set -e

echo "Running dart fix..."
dart fix --apply

echo "Running formatter..."
./scripts/format.sh

echo "Running analyzer..."
dart analyze

echo "All done! Code is fixed, formatted, and analyzed." 