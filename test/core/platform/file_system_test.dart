import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:path/path.dart' as p;

class FakePathProvider implements PathProvider {
  final Directory dir;
  FakePathProvider(this.dir);
  @override
  Future<Directory> getApplicationDocumentsDirectory() async => dir;
}

void main() {
  group('FileSystem', () {
    late FileSystem fileSystem;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_system_test');
      final fakePathProvider = FakePathProvider(tempDir);
      fileSystem = IoFileSystem(fakePathProvider);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    // Checks that fileExists returns false for a missing file
    test('fileExists returns false for missing file', () async {
      final missingFilePath = 'missing.txt';
      final exists = await fileSystem.fileExists(missingFilePath);
      expect(exists, isFalse);
    });

    // Checks that fileExists returns true for an existing file
    test('fileExists returns true for existing file', () async {
      final filePath = 'exists.txt';
      final file = File(p.join(tempDir.path, filePath));
      await file.writeAsString('hello');
      final exists = await fileSystem.fileExists(filePath);
      expect(exists, isTrue);
    });

    // Demonstrates writing and verifying file contents
    test(
      'writeFile writes bytes and fileExists returns true (developer doc example)',
      () async {
        final filePath = 'written.txt';
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        await fileSystem.writeFile(filePath, bytes);
        final exists = await fileSystem.fileExists(filePath);
        expect(
          exists,
          isTrue,
          reason: 'fileExists should return true after writeFile',
        );

        final file = File(p.join(tempDir.path, filePath));
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
      final filePath = 'readme.txt';
      final bytes = Uint8List.fromList([10, 20, 30]);

      await fileSystem.writeFile(filePath, bytes);
      final readBytes = await fileSystem.readFile(filePath);
      expect(readBytes, bytes);
    });

    // Checks that deleteFile removes the file
    test('deleteFile removes the file', () async {
      final filePath = 'todelete.txt';
      final bytes = Uint8List.fromList([99, 100]);

      await fileSystem.writeFile(filePath, bytes);
      await fileSystem.deleteFile(filePath);
      final exists = await fileSystem.fileExists(filePath);
      expect(exists, isFalse);
    });

    // Checks that directoryExists returns false for a missing directory
    test('directoryExists returns false for missing directory', () async {
      final dirPath = 'missing_dir';
      final exists = await fileSystem.directoryExists(dirPath);
      expect(exists, isFalse);
    });

    // Checks that createDirectory creates a directory and directoryExists returns true
    test(
      'createDirectory creates a directory, directoryExists returns true',
      () async {
        final dirPath = 'created_dir';
        await fileSystem.createDirectory(dirPath);
        final exists = await fileSystem.directoryExists(dirPath);
        expect(exists, isTrue);
      },
    );

    // Checks that absolute paths are used as-is
    test(
      'absolute path is used as-is and not resolved relative to app dir',
      () async {
        final absPath = p.join(tempDir.path, 'absolute.txt');
        final bytes = Uint8List.fromList([42]);

        await fileSystem.writeFile(absPath, bytes);
        final exists = await fileSystem.fileExists(absPath);
        expect(exists, isTrue);

        final readBytes = await fileSystem.readFile(absPath);
        expect(readBytes, bytes);
      },
    );

    // Checks file operations in subdirectories
    test('can write, read, and delete files in subdirectories', () async {
      final subPath = p.join('foo', 'bar', 'baz.txt');
      final bytes = Uint8List.fromList([7, 8, 9]);

      await fileSystem.createDirectory(p.join('foo', 'bar'), recursive: true);
      await fileSystem.writeFile(subPath, bytes);
      final exists = await fileSystem.fileExists(subPath);
      expect(exists, isTrue);

      final readBytes = await fileSystem.readFile(subPath);
      expect(readBytes, bytes);

      await fileSystem.deleteFile(subPath);
      final existsAfterDelete = await fileSystem.fileExists(subPath);
      expect(existsAfterDelete, isFalse);
    });

    // Checks that reading a nonexistent file throws
    test('reading a nonexistent file throws', () async {
      expect(() => fileSystem.readFile('nope.txt'), throwsA(isA<Exception>()));
    });

    // Checks that deleting a nonexistent file throws
    test('deleting a nonexistent file throws', () async {
      expect(
        () => fileSystem.deleteFile('nope.txt'),
        throwsA(isA<Exception>()),
      );
    });

    // Checks that listDirectory returns the correct files
    test('listDirectory returns correct files', () async {
      final dirPath = 'list_dir';
      await fileSystem.createDirectory(dirPath);
      final file1 = p.join(dirPath, 'a.txt');
      final file2 = p.join(dirPath, 'b.txt');

      await fileSystem.writeFile(file1, Uint8List.fromList([1]));
      await fileSystem.writeFile(file2, Uint8List.fromList([2]));

      final entities = await fileSystem.listDirectory(dirPath).toList();
      final names = entities.map((e) => p.basename(e.path)).toSet();
      expect(names, containsAll({'a.txt', 'b.txt'}));
    });

    // Checks that stat returns info for files and directories, and throws for missing
    test(
      'stat returns info for files and directories, throws for missing',
      () async {
        final filePath = 'stat_file.txt';
        final dirPath = 'stat_dir';

        await fileSystem.writeFile(filePath, Uint8List.fromList([1]));
        await fileSystem.createDirectory(dirPath);

        final fileStat = await fileSystem.stat(filePath);
        final dirStat = await fileSystem.stat(dirPath);
        expect(fileStat.type, isNotNull);
        expect(dirStat.type, isNotNull);

        expect(() => fileSystem.stat('nope.txt'), throwsA(isA<Exception>()));
      },
    );

    // Checks that writeFile overwrites existing file contents
    test('writeFile overwrites existing file', () async {
      final filePath = 'overwrite.txt';

      await fileSystem.writeFile(filePath, Uint8List.fromList([1, 2, 3]));
      await fileSystem.writeFile(filePath, Uint8List.fromList([9, 8, 7]));
      final bytes = await fileSystem.readFile(filePath);
      expect(bytes, [9, 8, 7]);
    });

    // Checks that path traversal (../) is handled as expected (writes outside temp dir)
    test('path traversal (../) is handled as expected', () async {
      final parentFile = p.join('..', 'parent.txt');
      await fileSystem.writeFile(parentFile, Uint8List.fromList([5]));
      final exists =
          await File(p.join(tempDir.parent.path, 'parent.txt')).exists();
      expect(exists, isTrue);
      // Clean up
      await File(p.join(tempDir.parent.path, 'parent.txt')).delete();
    });
  });
}
