#!/bin/sh

# Run tests and extract failed test information, grouped by source file

# Get the project root directory
project_root=$(pwd)

# Create a temporary file to store the test information
temp_file=$(mktemp)

# Run tests and extract the data
flutter test | grep "To run this test again: " | while read -r line; do
  # Extract file path (8th field) and test name (fields from 12 onward)
  filePath=$(echo "$line" | awk '{print $8}')
  testName=$(echo "$line" | awk '{for(i=12;i<=NF;i++) printf "%s ", $i}')
  
  # Store the test information in the temp file with the file path as prefix
  echo "$filePath:::$testName" >> "$temp_file"
done

# If there are any failed tests
if [ -s "$temp_file" ]; then
  # Sort the temp file by file path to group tests by source file
  sort "$temp_file" > "${temp_file}.sorted"
  
  # Process the sorted file to display grouped tests
  current_file=""
  
  while IFS= read -r line; do
    file_path=$(echo "$line" | cut -d':' -f1)
    test_name=$(echo "$line" | cut -d':' -f4-)
    
    # If this is a new file, print the file header
    if [ "$current_file" != "$file_path" ]; then
      # Print a blank line between files (except for the first one)
      if [ -n "$current_file" ]; then
        echo ""
      fi
      
      # Convert absolute path to relative path (from project root)
      rel_path=${file_path#"$project_root/"}
      
      # Print the file header with filename in red (needs -e for color codes)
      echo -e "Failed tests in: \\033[0;31m${rel_path}\\033[0m"
      current_file="$file_path"
    fi
    
    # Print the test name with indentation (no escape sequences, so no -e needed)
    echo "  • $test_name"
  done < "${temp_file}.sorted"
  
  echo ""
  echo "Failed tests grouped by source file"
else
  echo "No failed tests found"
fi

# Clean up temporary files
rm -f "$temp_file" "${temp_file}.sorted"
