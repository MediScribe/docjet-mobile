#!/usr/bin/env dart

import 'dart:io';

void main(List<String> args) {
  // Parse arguments
  final isDryRun = args.contains('--dry-run');
  final skipConfirmation = args.contains('--force');
  final backupDir = Directory(
    'test/backup_${DateTime.now().millisecondsSinceEpoch}',
  );

  print('Starting test import fix script...');
  if (isDryRun) {
    print('DRY RUN MODE: No changes will be made.');
  }

  // Get all test files
  final testDir = Directory('test');
  if (!testDir.existsSync()) {
    print('Error: test directory not found!');
    exit(1);
  }

  // Validate that test_utils.d.dart exists
  final barrelFile = File('test/test_utils.d.dart');
  if (!barrelFile.existsSync()) {
    print('Error: test/test_utils.d.dart not found! Cannot proceed safely.');
    exit(1);
  }

  final testFiles = _findDartFiles(testDir);
  print('Found ${testFiles.length} test files to process');

  // First pass: identify what would change
  final Map<File, String> filesToChange = {};

  for (final file in testFiles) {
    final content = file.readAsStringSync();

    // Skip files that are example tests or the utils file itself
    if (file.path.contains('test_utils.dart') ||
        file.path.contains('test_utils.d.dart') ||
        file.path.contains('example/test_utils_example_test.dart')) {
      continue;
    }

    // Check if the file imports test_utils.dart
    if (content.contains("import '../test_utils.dart'") ||
        content.contains('import "../test_utils.dart"')) {
      // Replace the import with the barrel file
      final updatedContent = content
          .replaceAll(
            "import '../test_utils.dart'",
            "import '../test_utils.d.dart'",
          )
          .replaceAll(
            'import "../test_utils.dart"',
            'import "../test_utils.d.dart"',
          );

      // Only mark for change if something changed
      if (updatedContent != content) {
        filesToChange[file] = updatedContent;
      }
    }
  }

  if (filesToChange.isEmpty) {
    print('No files need to be updated. Exiting.');
    exit(0);
  }

  // Summary of changes
  print('\nWill update ${filesToChange.length} files:');
  for (final file in filesToChange.keys) {
    print('  ${file.path}');
  }

  // Dry run exit point
  if (isDryRun) {
    print('\nDRY RUN COMPLETE. No files were changed.');
    print('Run without --dry-run to apply changes.');
    exit(0);
  }

  // Confirmation
  if (!skipConfirmation) {
    stdout.write('\nProceed with these changes? (y/N): ');
    final response = stdin.readLineSync()?.toLowerCase() ?? '';
    if (response != 'y') {
      print('Operation cancelled by user.');
      exit(0);
    }
  }

  // Create backup directory if we're making changes
  if (!backupDir.existsSync()) {
    backupDir.createSync(recursive: true);
    print('Created backup directory: ${backupDir.path}');
  }

  // Apply changes with backups
  int updated = 0;
  for (final entry in filesToChange.entries) {
    final file = entry.key;
    final newContent = entry.value;

    // Create backup
    final backupFile = File('${backupDir.path}/${file.path.split('/').last}');
    file.copySync(backupFile.path);

    // Apply change
    file.writeAsStringSync(newContent);
    updated++;
    print('Updated ${file.path}');
  }

  print('\nUpdate complete! Modified $updated test files.');
  print('Backups created in ${backupDir.path}');
  print('\nTo restore from backup if needed:');
  print('  cp ${backupDir.path}/* test/');
}

List<File> _findDartFiles(Directory dir) {
  final List<File> result = [];
  final List<FileSystemEntity> entities = dir.listSync(recursive: true);

  for (final entity in entities) {
    if (entity is File && entity.path.endsWith('_test.dart')) {
      result.add(entity);
    }
  }

  return result;
}

// Helper method to print usage
void printUsage() {
  print('Usage: dart scripts/fix_test_imports.dart [options]');
  print('Options:');
  print('  --dry-run    Show what would be changed without making changes');
  print('  --force      Skip confirmation prompt');
}
