import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

import '../../scripts/list_failed_tests.dart' as script;

void main() {
  group('Package Directory Utils', () {
    // Create temp directory structure for tests
    late Directory tempDir;
    late Directory mockSubPackageDir;
    late File mockMainPubspec;
    late File mockSubPubspec;

    setUp(() async {
      // Create a temporary directory structure for testing
      tempDir = await Directory.systemTemp.createTemp(
        'list_failed_tests_test_',
      );

      // Main package directory
      mockMainPubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      await mockMainPubspec.create(recursive: true);
      await mockMainPubspec.writeAsString('name: main_package\n');

      // Create a sub-package
      mockSubPackageDir = Directory(path.join(tempDir.path, 'mock_api_server'));
      await mockSubPackageDir.create(recursive: true);

      mockSubPubspec = File(path.join(mockSubPackageDir.path, 'pubspec.yaml'));
      await mockSubPubspec.create();
      await mockSubPubspec.writeAsString('name: mock_api_server\n');

      // Create a test directory in the sub-package
      final mockSubTestDir = Directory(
        path.join(mockSubPackageDir.path, 'test'),
      );
      await mockSubTestDir.create();

      // Create a test file in the sub-package
      final mockTestFile = File(
        path.join(mockSubTestDir.path, 'auth_test.dart'),
      );
      await mockTestFile.create();
      await mockTestFile.writeAsString('void main() {}\n');
    });

    tearDown(() async {
      // Clean up
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('findPackageRoot should find closest pubspec.yaml directory', () {
      // Test for a file in the root package
      final rootTestPath = path.join(tempDir.path, 'test', 'some_test.dart');
      Directory? rootResult = script.findPackageRoot(rootTestPath);

      final expectedRootPath =
          Directory(tempDir.path).resolveSymbolicLinksSync();
      final actualRootPath = rootResult!.resolveSymbolicLinksSync();
      expect(actualRootPath, equals(expectedRootPath));

      // Test for a file in a sub-package
      final subPackageTestPath = path.join(
        mockSubPackageDir.path,
        'test',
        'auth_test.dart',
      );
      Directory? subResult = script.findPackageRoot(subPackageTestPath);

      final expectedSubPath =
          Directory(mockSubPackageDir.path).resolveSymbolicLinksSync();
      final actualSubPath = subResult!.resolveSymbolicLinksSync();
      expect(actualSubPath, equals(expectedSubPath));
    });

    test(
      'getTestCommandForPath should generate correct command for root package tests',
      () {
        final testPath = path.join(tempDir.path, 'test', 'some_test.dart');
        final result = script.getTestCommandForPath(testPath);

        final expectedPath = Directory(tempDir.path).resolveSymbolicLinksSync();
        final actualPath =
            Directory(result.workingDirectory).resolveSymbolicLinksSync();
        expect(actualPath, equals(expectedPath));
        expect(result.testPath, equals('test/some_test.dart'));
      },
    );

    test(
      'getTestCommandForPath should generate correct command for sub-package tests',
      () {
        final testPath = path.join(
          mockSubPackageDir.path,
          'test',
          'auth_test.dart',
        );
        final result = script.getTestCommandForPath(testPath);

        final expectedPath =
            Directory(mockSubPackageDir.path).resolveSymbolicLinksSync();
        final actualPath =
            Directory(result.workingDirectory).resolveSymbolicLinksSync();
        expect(actualPath, equals(expectedPath));
        expect(result.testPath, equals('test/auth_test.dart'));
      },
    );

    test('getTestCommandForPath should convert absolute paths to relative', () {
      final absolutePath = path.join(
        mockSubPackageDir.path,
        'test',
        'auth_test.dart',
      );
      final result = script.getTestCommandForPath(absolutePath);

      final expectedPath =
          Directory(mockSubPackageDir.path).resolveSymbolicLinksSync();
      final actualPath =
          Directory(result.workingDirectory).resolveSymbolicLinksSync();
      expect(actualPath, equals(expectedPath));
      expect(result.testPath, equals('test/auth_test.dart'));
    });

    test('getTestCommandForPath should handle relative paths correctly', () {
      // Change working directory to the tempDir for this test
      final originalDir = Directory.current;
      Directory.current = tempDir;

      try {
        final relativePathFromRoot = path.join(
          'mock_api_server',
          'test',
          'auth_test.dart',
        );
        final result = script.getTestCommandForPath(relativePathFromRoot);

        // Use Directory.resolveSymbolicLinksSync() to handle macOS private directory symlinks
        final expectedPath =
            Directory(mockSubPackageDir.path).resolveSymbolicLinksSync();
        final actualPath =
            Directory(result.workingDirectory).resolveSymbolicLinksSync();

        expect(actualPath, equals(expectedPath));
        expect(result.testPath, equals('test/auth_test.dart'));
      } finally {
        // Restore original working directory
        Directory.current = originalDir;
      }
    });

    test(
      'getTestCommandForPath should handle package directory path correctly',
      () {
        // Test giving the package directory itself as the target
        final packageDirectoryPath = mockSubPackageDir.path;
        final result = script.getTestCommandForPath(packageDirectoryPath);

        final expectedWorkingDirPath =
            Directory(packageDirectoryPath).resolveSymbolicLinksSync();
        final actualWorkingDirPath =
            Directory(result.workingDirectory).resolveSymbolicLinksSync();

        expect(actualWorkingDirPath, equals(expectedWorkingDirPath));
        expect(
          result.testPath,
          equals('test/'),
        ); // Should target the 'test/' subdirectory
      },
    );

    test(
      'getTestCommandForPath should handle relative package directory path correctly',
      () {
        // Change working directory to the tempDir for this test
        final originalDir = Directory.current;
        Directory.current = tempDir;

        try {
          final relativePackageDirPath = path.basename(
            mockSubPackageDir.path,
          ); // e.g., "mock_api_server"
          final result = script.getTestCommandForPath(relativePackageDirPath);

          final expectedWorkingDirPath =
              Directory(mockSubPackageDir.path).resolveSymbolicLinksSync();
          final actualWorkingDirPath =
              Directory(result.workingDirectory).resolveSymbolicLinksSync();

          expect(actualWorkingDirPath, equals(expectedWorkingDirPath));
          expect(
            result.testPath,
            equals('test/'),
          ); // Should target the 'test/' subdirectory
        } finally {
          // Restore original working directory
          Directory.current = originalDir;
        }
      },
    );
  });
}
