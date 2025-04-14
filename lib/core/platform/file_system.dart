import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:path/path.dart' as p;

/// Abstract interface for file system operations to allow for mocking in tests.
abstract class FileSystem {
  /// Gets the status of a file or directory.
  Future<FileStat> stat(String path);

  /// Checks if a file exists at the given path.
  Future<bool> fileExists(String path);

  /// Deletes the file at the given path.
  Future<void> deleteFile(String path);

  /// Checks if a directory exists at the given path.
  Future<bool> directoryExists(String path);

  /// Creates a directory at the given path.
  ///
  /// If [recursive] is true, creates all non-existent parent directories.
  Future<void> createDirectory(String path, {bool recursive = false});

  /// Lists the contents of a directory asynchronously.
  Stream<FileSystemEntity> listDirectory(String path);

  /// Lists the contents of a directory synchronously.
  List<FileSystemEntity> listDirectorySync(String path);

  /// Writes raw bytes to a file, overwriting if it exists.
  Future<void> writeFile(String path, Uint8List bytes);

  /// Get application documents directory
  Future<Directory> getApplicationDocumentsDirectory();

  /// Builds an absolute path from a relative path (relative to app documents directory)
  Future<String> getAbsolutePath(String relativePath);
}

/// Concrete implementation of [FileSystem] using dart:io.
class IoFileSystem implements FileSystem {
  final logger = LoggerFactory.getLogger(IoFileSystem, level: Level.debug);
  final String _tag = logTag(IoFileSystem);

  final PathProvider _pathProvider;

  IoFileSystem(this._pathProvider);

  @override
  Future<Directory> getApplicationDocumentsDirectory() async {
    return await _pathProvider.getApplicationDocumentsDirectory();
  }

  @override
  Future<String> getAbsolutePath(String relativePath) async {
    if (p.isAbsolute(relativePath)) {
      logger.w(
        '$_tag getAbsolutePath() was called with an absolute path: $relativePath',
      );
      return relativePath;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, relativePath);
  }

  @override
  Future<FileStat> stat(String path) async {
    logger.d('$_tag stat() called for path: $path');
    try {
      final fullPath = await getAbsolutePath(path);
      final stat = await File(fullPath).stat();
      logger.d('$_tag stat() result: type=${stat.type}, size=${stat.size}');
      return stat;
    } catch (e, s) {
      logger.e('$_tag stat() error for $path', error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<bool> fileExists(String path) async {
    logger.d('$_tag fileExists() checking: $path');
    try {
      final fullPath = await getAbsolutePath(path);
      final exists = await File(fullPath).exists();
      logger.d('$_tag fileExists() result: $exists');

      if (!exists) {
        // If file doesn't exist, log info about parent directory
        final parent = File(fullPath).parent;
        final parentExists = await parent.exists();
        logger.d('$_tag fileExists() - Parent directory exists: $parentExists');

        if (parentExists) {
          try {
            final contents = await parent.list().toList();
            logger.d(
              '$_tag fileExists() - Parent directory has ${contents.length} files',
            );
          } catch (e) {
            logger.e(
              '$_tag fileExists() - Error listing parent directory',
              error: e,
            );
          }
        }
      }

      return exists;
    } catch (e, s) {
      logger.e('$_tag fileExists() error for $path', error: e, stackTrace: s);
      return false;
    }
  }

  @override
  Future<void> deleteFile(String path) async {
    logger.d('$_tag deleteFile() called for: $path');
    try {
      final fullPath = await getAbsolutePath(path);
      final file = File(fullPath);

      final exists = await file.exists();
      if (exists) {
        await file.delete();
        logger.d('$_tag deleteFile() - File deleted successfully');
      } else {
        logger.w('$_tag deleteFile() - File does not exist, nothing to delete');
      }
    } catch (e, s) {
      logger.e('$_tag deleteFile() error for $path', error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<bool> directoryExists(String path) async {
    logger.d('$_tag directoryExists() checking: $path');
    try {
      final fullPath = await getAbsolutePath(path);
      final exists = await Directory(fullPath).exists();
      logger.d('$_tag directoryExists() result: $exists');
      return exists;
    } catch (e, s) {
      logger.e(
        '$_tag directoryExists() error for $path',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }

  @override
  Future<void> createDirectory(String path, {bool recursive = false}) async {
    logger.d(
      '$_tag createDirectory() called for: $path (recursive: $recursive)',
    );
    try {
      final fullPath = await getAbsolutePath(path);
      await Directory(fullPath).create(recursive: recursive);
      logger.d('$_tag createDirectory() - Directory created successfully');
    } catch (e, s) {
      logger.e(
        '$_tag createDirectory() error for $path',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  @override
  Stream<FileSystemEntity> listDirectory(String path) {
    logger.d('$_tag listDirectory() called for: $path');

    final controller = StreamController<FileSystemEntity>();

    getAbsolutePath(path)
        .then((fullPath) {
          Directory(fullPath)
              .list(recursive: false)
              .listen(
                controller.add,
                onError: controller.addError,
                onDone: controller.close,
              );
        })
        .catchError((e, s) {
          logger.e(
            '$_tag listDirectory() error for $path',
            error: e,
            stackTrace: s,
          );
          controller.addError(e, s);
          controller.close();
        });

    return controller.stream;
  }

  @override
  List<FileSystemEntity> listDirectorySync(String path) {
    logger.d('$_tag listDirectorySync() called for: $path');
    try {
      // Warning: This is sync but we need to know the docs directory
      // In most cases, path will already be absolute, so try that first
      if (p.isAbsolute(path)) {
        return Directory(path).listSync(recursive: false);
      }

      // For relative paths, make a best effort with current directory
      final currentDir = Directory.current.path;
      final fullPath = p.join(currentDir, path);
      logger.w(
        '$_tag listDirectorySync() - Using current dir for relative path: $fullPath',
      );
      return Directory(fullPath).listSync(recursive: false);
    } catch (e, s) {
      logger.e(
        '$_tag listDirectorySync() error for $path',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  @override
  Future<void> writeFile(String path, Uint8List bytes) async {
    logger.d('$_tag writeFile() called for: $path (${bytes.length} bytes)');
    try {
      final fullPath = await getAbsolutePath(path);
      final file = File(fullPath);

      // Ensure parent directory exists
      final parent = file.parent;
      final parentExists = await parent.exists();

      if (!parentExists) {
        logger.d(
          '$_tag writeFile() - Creating parent directory: ${parent.path}',
        );
        await parent.create(recursive: true);
      }

      await file.writeAsBytes(bytes);

      // Verify file was written
      final exists = await file.exists();
      if (exists) {
        final size = await file.length();
        logger.d(
          '$_tag writeFile() - File written successfully, size: $size bytes',
        );
      } else {
        logger.e('$_tag writeFile() - ERROR: File not found after write!');
      }
    } catch (e, s) {
      logger.e('$_tag writeFile() error for $path', error: e, stackTrace: s);
      rethrow;
    }
  }
}
