#!/bin/bash
# Update test imports script
# This script will update all test files to use the new test_utils.dart barrel file

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to the project root
cd "$PROJECT_ROOT"

echo "Updating test files to use test_utils.dart..."
echo "Project root: $PROJECT_ROOT"

# Find all test files
TEST_FILES=$(find test -name "*.dart" -type f | grep -v "test_utils.dart" | grep -v "flutter_test_config.dart" | grep -v "generated_plugin_registrant.dart")

# Count of total files and updated files
TOTAL_FILES=0
UPDATED_FILES=0

for file in $TEST_FILES; do
  TOTAL_FILES=$((TOTAL_FILES + 1))
  
  # Check if the file already imports test_utils.dart
  if grep -q "import '../\+test_utils.dart';" "$file" || grep -q "import '..\/..\/test_utils.dart';" "$file" || grep -q "import '.\+\/test_utils.dart';" "$file"; then
    echo "✓ $file already uses test_utils.dart"
    continue
  fi
  
  # Determine the relative path to test_utils.dart
  REL_PATH=$(python -c "import os.path; print(os.path.relpath('$PROJECT_ROOT/test/test_utils.dart', os.path.dirname('$file')))")
  
  # Replace typical Flutter test imports with the barrel file import
  if grep -q "import 'package:flutter_test/flutter_test.dart';" "$file"; then
    sed -i.bak "s/import 'package:flutter_test\/flutter_test.dart';/import '$REL_PATH';/" "$file"
    rm -f "$file.bak"
    UPDATED_FILES=$((UPDATED_FILES + 1))
    echo "✓ Updated $file"
  else
    # If no flutter_test import, add the import at the top after other imports
    awk -v rel_path="$REL_PATH" '
      /^import / { count++ }
      /^$/ && count > 0 && !added { print "import '"'"'" rel_path "'"'"';"; added=1 }
      { print }
      END { if (!added) print "import '"'"'" rel_path "'"'"';" }
    ' "$file" > "$file.new"
    mv "$file.new" "$file"
    UPDATED_FILES=$((UPDATED_FILES + 1))
    echo "✓ Added import to $file"
  fi
  
  # Now look for LogLevel usage and TestLogger direct usage
  # and add the setUpAll/tearDownAll if the file has a main() function
  if grep -q "void main()" "$file"; then
    # Check if setUpAll and tearDownAll are already in the file
    if ! grep -q "setUpAll" "$file"; then
      # Add setUp and tearDown after the main() { line
      sed -i.bak '/void main().*{/a \
  setUpAll(setupTestLogging);\
  tearDownAll(teardownTestLogging);
' "$file"
      rm -f "$file.bak"
      echo "✓ Added logging setup to $file"
    fi
  fi
done

echo "Done!"
echo "Updated $UPDATED_FILES out of $TOTAL_FILES test files."
echo ""
echo "IMPORTANT: You need to run this script from the project root."
echo "Example: bash scripts/update_test_imports.sh" 