import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
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

  /// Writes raw bytes to a file, overwriting if it exists.
  Future<void> writeFile(String path, Uint8List bytes);

  /// Reads the contents of a file as a list of bytes.
  Future<List<int>> readFile(String path);
}

/// Concrete implementation of [FileSystem] using dart:io.
class IoFileSystem implements FileSystem {
  final logger = LoggerFactory.getLogger(IoFileSystem, level: Level.debug);
  // final String _tag = logTag(IoFileSystem);

  final PathProvider _pathProvider;

  IoFileSystem(this._pathProvider);

  // Resolves relative paths to the app documents directory, absolute paths as-is
  Future<String> _resolvePath(String inputPath) async {
    if (p.isAbsolute(inputPath)) {
      return inputPath;
    }
    final docsDir = await _pathProvider.getApplicationDocumentsDirectory();
    return p.join(docsDir.path, inputPath);
  }

  @override
  Future<FileStat> stat(String path) async {
    final fullPath = await _resolvePath(path);
    final entity = File(fullPath);
    if (await entity.exists()) {
      return entity.stat();
    }
    final dir = Directory(fullPath);
    if (await dir.exists()) {
      return dir.stat();
    }
    throw Exception('No file or directory found at $fullPath');
  }

  @override
  Stream<FileSystemEntity> listDirectory(String path) {
    return Stream.fromFuture(_resolvePath(path)).asyncExpand((fullPath) {
      return Directory(fullPath).list(recursive: false);
    });
  }

  @override
  Future<bool> fileExists(String path) async {
    final fullPath = await _resolvePath(path);
    return File(fullPath).exists();
  }

  @override
  Future<void> writeFile(String path, Uint8List bytes) async {
    final fullPath = await _resolvePath(path);
    await File(fullPath).writeAsBytes(bytes);
  }

  @override
  Future<List<int>> readFile(String path) async {
    final fullPath = await _resolvePath(path);
    return File(fullPath).readAsBytes();
  }

  @override
  Future<void> deleteFile(String path) async {
    final fullPath = await _resolvePath(path);
    await File(fullPath).delete();
  }

  @override
  Future<void> createDirectory(String path, {bool recursive = false}) async {
    final fullPath = await _resolvePath(path);
    await Directory(fullPath).create(recursive: recursive);
  }

  @override
  Future<bool> directoryExists(String path) async {
    final fullPath = await _resolvePath(path);
    return Directory(fullPath).exists();
  }
}
