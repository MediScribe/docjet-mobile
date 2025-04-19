import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:path/path.dart' as p;

void main() {
  late IoFileSystem ioFileSystem;
  late String fakeDocumentsPath;

  setUp(() {
    fakeDocumentsPath = Directory.systemTemp.createTempSync('test_docs_').path;

    ioFileSystem = IoFileSystem(fakeDocumentsPath);
  });

  tearDown(() {
    final tempDir = Directory(fakeDocumentsPath);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('IoFileSystem', () {
    // Checks that fileExists returns false for a missing file
    test('fileExists returns false for missing file', () async {
      const missingFilePath = 'missing.txt';
      final exists = await ioFileSystem.fileExists(missingFilePath);
      expect(exists, isFalse);
    });

    // Checks that fileExists returns true for an existing file
    test('fileExists returns true for existing file', () async {
      final testFilePath = p.join(fakeDocumentsPath, 'test_file.txt');
      File(testFilePath).writeAsStringSync('test content');

      final exists = await ioFileSystem.fileExists('test_file.txt');
      expect(exists, isTrue);
    });

    // Demonstrates writing and verifying file contents
    test(
      'writeFile writes bytes and fileExists returns true (developer doc example)',
      () async {
        const filePath = 'written.txt';
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        await ioFileSystem.writeFile(filePath, bytes);
        final exists = await ioFileSystem.fileExists(filePath);
        expect(
          exists,
          isTrue,
          reason: 'fileExists should return true after writeFile',
        );

        final file = File(p.join(fakeDocumentsPath, filePath));
        final fileBytes = await file.readAsBytes();
        expect(
          fileBytes,
          bytes,
          reason: 'File contents should match what was written',
        );
      },
    );

    // Checks that readFile returns the bytes that were written
    test('readFile returns the bytes that were written', () async {
      const filePath = 'readme.txt';
      final bytes = Uint8List.fromList([10, 20, 30]);

      await ioFileSystem.writeFile(filePath, bytes);
      final readBytes = await ioFileSystem.readFile(filePath);
      expect(readBytes, bytes);
    });

    // Checks that deleteFile removes the file
    test('deleteFile removes the file', () async {
      const filePath = 'todelete.txt';
      final bytes = Uint8List.fromList([99, 100]);

      await ioFileSystem.writeFile(filePath, bytes);
      await ioFileSystem.deleteFile(filePath);
      final exists = await ioFileSystem.fileExists(filePath);
      expect(exists, isFalse);
    });

    // Checks that directoryExists returns false for a missing directory
    test('directoryExists returns false for missing directory', () async {
      const dirPath = 'missing_dir';
      final exists = await ioFileSystem.directoryExists(dirPath);
      expect(exists, isFalse);
    });

    // Checks that createDirectory creates a directory and directoryExists returns true
    test(
      'createDirectory creates a directory, directoryExists returns true',
      () async {
        const dirPath = 'created_dir';
        await ioFileSystem.createDirectory(dirPath);
        final exists = await ioFileSystem.directoryExists(dirPath);
        expect(exists, isTrue);
      },
    );

    // Checks that absolute paths are used as-is
    test(
      'absolute path is used as-is and not resolved relative to app dir',
      () async {
        final absPath = p.join(fakeDocumentsPath, 'absolute.txt');
        final bytes = Uint8List.fromList([42]);

        await ioFileSystem.writeFile(absPath, bytes);
        final exists = await ioFileSystem.fileExists(absPath);
        expect(exists, isTrue);

        final readBytes = await ioFileSystem.readFile(absPath);
        expect(readBytes, bytes);
      },
    );

    // Checks file operations in subdirectories
    test('can write, read, and delete files in subdirectories', () async {
      final subPath = p.join('foo', 'bar', 'baz.txt');
      final bytes = Uint8List.fromList([7, 8, 9]);

      await ioFileSystem.createDirectory(p.join('foo', 'bar'), recursive: true);
      await ioFileSystem.writeFile(subPath, bytes);
      final exists = await ioFileSystem.fileExists(subPath);
      expect(exists, isTrue);

      final readBytes = await ioFileSystem.readFile(subPath);
      expect(readBytes, bytes);

      await ioFileSystem.deleteFile(subPath);
      final existsAfterDelete = await ioFileSystem.fileExists(subPath);
      expect(existsAfterDelete, isFalse);
    });

    // Checks that reading a nonexistent file throws
    test('reading a nonexistent file throws', () async {
      expect(
        () => ioFileSystem.readFile('nope.txt'),
        throwsA(isA<Exception>()),
      );
    });

    // Checks that deleting a nonexistent file completes normally (doesn't throw)
    test('deleting a nonexistent file completes normally', () async {
      // Expecting successful completion, not an exception
      await expectLater(ioFileSystem.deleteFile('nope.txt'), completes);
    });

    // Checks that listDirectory returns the correct files
    test('listDirectory returns correct files', () async {
      const dirPath = 'list_dir';
      await ioFileSystem.createDirectory(dirPath);
      final file1 = p.join(dirPath, 'a.txt');
      final file2 = p.join(dirPath, 'b.txt');

      await ioFileSystem.writeFile(file1, Uint8List.fromList([1]));
      await ioFileSystem.writeFile(file2, Uint8List.fromList([2]));

      final entities = await ioFileSystem.listDirectory(dirPath).toList();
      final names = entities.map((e) => p.basename(e.path)).toSet();
      expect(names, containsAll({'a.txt', 'b.txt'}));
    });

    // Checks that stat returns info for files and directories, and throws for missing
    test(
      'stat returns info for files and directories, throws for missing',
      () async {
        const filePath = 'stat_file.txt';
        const dirPath = 'stat_dir';

        await ioFileSystem.writeFile(filePath, Uint8List.fromList([1]));
        await ioFileSystem.createDirectory(dirPath);

        final fileStat = await ioFileSystem.stat(filePath);
        final dirStat = await ioFileSystem.stat(dirPath);
        expect(fileStat.type, isNotNull);
        expect(dirStat.type, isNotNull);

        expect(() => ioFileSystem.stat('nope.txt'), throwsA(isA<Exception>()));
      },
    );

    // Checks that writeFile overwrites existing file contents
    test('writeFile overwrites existing file', () async {
      const filePath = 'overwrite.txt';

      await ioFileSystem.writeFile(filePath, Uint8List.fromList([1, 2, 3]));
      await ioFileSystem.writeFile(filePath, Uint8List.fromList([9, 8, 7]));
      final bytes = await ioFileSystem.readFile(filePath);
      expect(bytes, [9, 8, 7]);
    });

    // Checks that path traversal (../) is handled as expected
    test('path traversal (../) is handled as expected', () async {
      // Arrange: Attempt to write outside the base dir
      final relativePath = '../parent.txt';

      // Act & Assert: fileExists should return false because the path resolves
      // outside the allowed directory and we didn't create it there.
      final exists = await ioFileSystem.fileExists(relativePath);
      expect(exists, isFalse);
    });

    // Checks that path traversal normalization works within the base directory
    test(
      'path traversal normalization (../) works within base directory',
      () async {
        final targetDir = p.join(fakeDocumentsPath, 'foo');
        final targetPath = p.join(targetDir, 'bar.txt');
        final inputPath = p.join(
          'foo',
          'baz',
          '..',
          'bar.txt',
        ); // Should resolve to foo/bar.txt

        // Explicitly create the directory first
        await Directory(targetDir).create(recursive: true);

        await ioFileSystem.writeFile(inputPath, Uint8List.fromList([5]));
        // Check using the normalized target path
        final exists = await ioFileSystem.fileExists(targetPath);
        expect(exists, isTrue, reason: 'File should exist at normalized path');

        // Verify the file content via the normalized path
        final bytes = await ioFileSystem.readFile(targetPath);
        expect(bytes, [5]);

        // Clean up using the normalized path
        await ioFileSystem.deleteFile(targetPath);
        final existsAfter = await ioFileSystem.fileExists(targetPath);
        expect(existsAfter, isFalse);
      },
    );

    // Test that writeFile prevents path traversal
    test('writeFile prevents path traversal', () async {
      final relativePath = '../write_outside.txt';
      final bytes = Uint8List.fromList([66, 6]); // Some dummy bytes

      // Act & Assert: Expect a FileSystemException when trying to write outside
      expect(
        () => ioFileSystem.writeFile(relativePath, bytes),
        throwsA(isA<FileSystemException>()),
        reason:
            'Should throw FileSystemException for path traversal write attempt',
      );

      // Verify the file was NOT created outside the base directory
      // (This check is still useful as a backup)
      final outsidePath = p.normalize(p.join(fakeDocumentsPath, relativePath));
      final outsideFile = File(outsidePath);
      // Explicitly delete the file if it exists from a previous bad run
      if (await outsideFile.exists()) {
        await outsideFile.delete();
      }
      expect(
        await outsideFile.exists(),
        isFalse,
        reason: 'File should not be created outside the base directory',
      );
    });

    // Test that readFile prevents path traversal
    test('readFile prevents path traversal', () async {
      // Arrange: Create a file OUTSIDE the sandbox directory
      final outsidePath = p.normalize(
        p.join(fakeDocumentsPath, '../read_outside.txt'),
      );
      final outsideFile = File(outsidePath);
      await outsideFile.writeAsString('Cannot read this');

      // Ensure cleanup even if test fails
      addTearDown(() async {
        if (await outsideFile.exists()) {
          await outsideFile.delete();
        }
      });

      final relativePath = '../read_outside.txt';

      // Act & Assert: Expect a FileSystemException when trying to read outside
      expect(
        () => ioFileSystem.readFile(relativePath),
        throwsA(isA<FileSystemException>()),
        reason:
            'Should throw FileSystemException for path traversal read attempt',
      );
    });

    // Test that deleteFile prevents path traversal
    test('deleteFile prevents path traversal', () async {
      // Arrange: Create a file OUTSIDE the sandbox directory
      final outsidePath = p.normalize(
        p.join(fakeDocumentsPath, '../delete_outside.txt'),
      );
      final outsideFile = File(outsidePath);
      await outsideFile.writeAsString('Cannot delete this');

      // Ensure cleanup even if test fails
      addTearDown(() async {
        if (await outsideFile.exists()) {
          await outsideFile.delete();
        }
      });

      final relativePath = '../delete_outside.txt';

      // Act & Assert: Expect a FileSystemException when trying to delete outside
      expect(
        () => ioFileSystem.deleteFile(relativePath),
        throwsA(isA<FileSystemException>()),
        reason:
            'Should throw FileSystemException for path traversal delete attempt',
      );

      // Verify the outside file still exists
      expect(
        await outsideFile.exists(),
        isTrue,
        reason: 'External file should not be deleted',
      );
    });

    // Test that stat prevents path traversal
    test('stat prevents path traversal', () async {
      // Arrange: Create a file OUTSIDE the sandbox directory
      final outsidePath = p.normalize(
        p.join(fakeDocumentsPath, '../stat_outside.txt'),
      );
      final outsideFile = File(outsidePath);
      await outsideFile.writeAsString('Cannot stat this');

      // Ensure cleanup even if test fails
      addTearDown(() async {
        if (await outsideFile.exists()) {
          await outsideFile.delete();
        }
      });

      final relativePath = '../stat_outside.txt';

      // Act & Assert: Expect a FileSystemException when trying to stat outside
      expect(
        () => ioFileSystem.stat(relativePath),
        throwsA(isA<FileSystemException>()),
        reason:
            'Should throw FileSystemException for path traversal stat attempt',
      );
    });

    // Test that listDirectory prevents path traversal
    test('listDirectory prevents path traversal', () async {
      // Arrange: Create a directory and file OUTSIDE the sandbox directory
      final outsideDirPath = p.normalize(
        p.join(fakeDocumentsPath, '../list_outside_dir'),
      );
      final outsideDir = Directory(outsideDirPath);
      final outsideFilePath = p.join(outsideDirPath, 'list_me.txt');
      await outsideDir.create(recursive: true);
      await File(outsideFilePath).writeAsString('Cannot list this');

      // Ensure cleanup even if test fails
      addTearDown(() async {
        if (await outsideDir.exists()) {
          await outsideDir.delete(recursive: true);
        }
      });

      final relativePath = '../list_outside_dir';

      // Act & Assert: Expect a FileSystemException when trying to list outside
      expect(
        () =>
            ioFileSystem
                .listDirectory(relativePath)
                .toList(), // Consume the stream
        throwsA(isA<FileSystemException>()),
        reason:
            'Should throw FileSystemException for path traversal list attempt',
      );
    });

    // Test that createDirectory prevents path traversal
    test('createDirectory prevents path traversal', () async {
      final relativePath = '../create_outside_dir';
      final outsideDirPath = p.normalize(
        p.join(fakeDocumentsPath, relativePath),
      );
      final outsideDir = Directory(outsideDirPath);

      // Ensure cleanup even if test fails
      addTearDown(() async {
        if (await outsideDir.exists()) {
          await outsideDir.delete(recursive: true);
        }
      });

      // Act & Assert: Expect a FileSystemException when trying to create outside
      expect(
        () => ioFileSystem.createDirectory(relativePath, recursive: true),
        throwsA(isA<FileSystemException>()),
        reason:
            'Should throw FileSystemException for path traversal createDirectory attempt',
      );

      // Verify the outside directory wasn't created
      expect(
        await outsideDir.exists(),
        isFalse,
        reason: 'External directory should not be created',
      );
    });

    // Test that directoryExists prevents path traversal
    test('directoryExists prevents path traversal', () async {
      // Arrange: Create a directory OUTSIDE the sandbox directory
      final relativePath = '../dir_exists_outside';
      final outsideDirPath = p.normalize(
        p.join(fakeDocumentsPath, relativePath),
      );
      final outsideDir = Directory(outsideDirPath);
      await outsideDir.create(recursive: true);

      // Ensure cleanup even if test fails
      addTearDown(() async {
        if (await outsideDir.exists()) {
          await outsideDir.delete(recursive: true);
        }
      });

      // Act & Assert: Expect directoryExists to return false for paths outside the sandbox
      final exists = await ioFileSystem.directoryExists(relativePath);
      expect(
        exists,
        isFalse,
        reason:
            'directoryExists should return false for paths outside the sandbox',
      );
    });
  });

  // New group for resolvePath tests
  group('resolvePath', () {
    test('should return absolute paths unchanged', () {
      final absolutePath = p.join(fakeDocumentsPath, 'absolute', 'file.txt');
      final resolved = ioFileSystem.resolvePath(absolutePath);
      expect(resolved, equals(absolutePath));
    });

    test('should prepend documents path to relative paths', () {
      const relativePath = 'relative/file.txt';
      final expectedPath = p.join(fakeDocumentsPath, 'relative', 'file.txt');
      final resolved = ioFileSystem.resolvePath(relativePath);
      expect(resolved, equals(expectedPath));
    });

    test('should handle normalization (./)', () {
      const relativePath = './relative/./file.txt';
      final expectedPath = p.join(fakeDocumentsPath, 'relative', 'file.txt');
      final resolved = ioFileSystem.resolvePath(relativePath);
      // Use p.equals to handle platform-specific separators in comparison
      expect(p.equals(resolved, expectedPath), isTrue);
    });

    test('should handle normalization (../)', () {
      // Note: Resolving .. beyond the root might have platform-specific behavior
      // Here we test resolving within the known base path
      const relativePath = 'relative/../other/file.txt';
      final expectedPath = p.join(fakeDocumentsPath, 'other', 'file.txt');
      final resolved = ioFileSystem.resolvePath(relativePath);
      expect(p.equals(resolved, expectedPath), isTrue);
    });

    test('should handle redundant separators (//)', () {
      const relativePath = 'relative//file.txt';
      final expectedPath = p.join(fakeDocumentsPath, 'relative', 'file.txt');
      final resolved = ioFileSystem.resolvePath(relativePath);
      expect(p.equals(resolved, expectedPath), isTrue);
    });

    test(
      'should replace backslashes with forward slashes for normalization input',
      () {
        // Input with backslashes
        const relativePath = 'relative\\mixed/../file.txt';
        // Expected path after normalization (should resolve .. and use platform separator)
        final expectedPath = p.join(fakeDocumentsPath, 'file.txt');
        final resolved = ioFileSystem.resolvePath(relativePath);
        expect(p.equals(resolved, expectedPath), isTrue);
      },
    );

    test(
      'resolvePath should replace backslashes and normalize ../ correctly',
      () async {
        // Arrange
        final inputPath = 'relativemixed/../file.txt'; // Mixed separators
        final expectedPath = p.context.normalize(
          p.context.join(Directory(fakeDocumentsPath).path, 'file.txt'),
        ); // Should resolve to <tempDir>/file.txt

        // Act
        final resolvedPath = ioFileSystem.resolvePath(inputPath);

        // Assert
        expect(resolvedPath, expectedPath);
      },
    );
  });
}
