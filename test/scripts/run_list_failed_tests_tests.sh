#!/bin/bash

# Run all tests for list_failed_tests.dart
echo "Running all tests for list_failed_tests.dart..."

# Run each test file
dart run test/scripts/test_models_test.dart
STATUS1=$?

dart run test/scripts/test_event_processor_test.dart
STATUS2=$?

dart run test/scripts/result_formatter_test.dart
STATUS3=$?

dart run test/scripts/failed_test_runner_test.dart
STATUS4=$?

# Check if any tests failed
if [ $STATUS1 -ne 0 ] || [ $STATUS2 -ne 0 ] || [ $STATUS3 -ne 0 ] || [ $STATUS4 -ne 0 ]; then
  echo -e "\n\e[31mTests failed!\e[0m"
  exit 1
else
  echo -e "\n\e[32mAll tests passed!\e[0m"
  exit 0
fi 