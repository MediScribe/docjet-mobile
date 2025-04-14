#!/bin/bash

# Cleanup script for obsolete logging files
# Run this script to identify and clean up files related to the old logging approach

echo "Obsolete logging files to consider removing:"
echo ""

# Deprecated logger.dart file - if it exists
if [ -f "lib/core/utils/logger.dart" ]; then
  echo "- lib/core/utils/logger.dart (deprecated logging system)"
fi

# Old test helpers
if [ -f "test/helpers/log_test_helpers.dart" ]; then
  echo "- test/helpers/log_test_helpers.dart (obsolete test helpers, functionality now in LoggerFactory)"
fi

# Old logger test files
if [ -f "test/core/utils/log_helpers_test.dart" ]; then
  echo "- test/core/utils/log_helpers_test.dart (old test file, incompatible with new logger)"
fi

if [ -f "test/core/utils/logger_factory_shared_output_test.dart" ]; then
  echo "- test/core/utils/logger_factory_shared_output_test.dart (old test approach)"
fi

if [ -f "test/helpers/log_test_helpers_test.dart" ]; then
  echo "- test/helpers/log_test_helpers_test.dart (tests for obsolete helpers)"
fi

echo ""
echo "Optional: Consider removing the entire docjet_test package (now redundant)"
echo "- packages/docjet_test"
echo ""
echo "Documentation has been preserved in docs/logging_guide.md"
echo ""
echo "To delete a specific file, use:"
echo "rm -f <path/to/file>"
echo ""
echo "To delete the entire docjet_test package (after verifying it's not needed):"
echo "rm -rf packages/docjet_test"
echo ""
echo "DISCLAIMER: Run this script in read-only mode - it doesn't delete anything automatically."

# Make the script executable
chmod +x cleanup_old_logging.sh 