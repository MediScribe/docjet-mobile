#!/bin/sh

# Run tests and extract failed test information into a proper file
# Each failed test will be on its own line with its full command to run it again

# Clear the failed tests file if it exists
# echo "" > failed_tests.txt

# Run tests and extract the data
flutter test | grep "To run this test again: " | while read -r line; do
  # Extract file path (8th field) and test name (fields from 12 onward)
  filePath=$(echo "$line" | awk '{print $8}')
  testName=$(echo "$line" | awk '{for(i=12;i<=NF;i++) printf "%s ", $i}')
  
  # Extract directory and filename
  dirPath=$(dirname "$filePath")
  filename=$(basename "$filePath")

  # Print to screen with "Failed:", full path (filename colored red), and newline
  echo -e "Failed: ${dirPath}/\\033[0;31m${filename}\\033[0m\\n : ${testName}"
  
  # Also save the runnable command to the file for later use
  # echo "/Users/eburgwedel/Developer/flutter/bin/cache/dart-sdk/bin/dart test $filePath -p vm --plain-name $testName" >> failed_tests.txt
done

echo ""
# echo "Failed test commands saved to failed_tests.txt"
echo "Failed tests listed above"
