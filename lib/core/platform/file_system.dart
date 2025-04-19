import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path_pkg;
// import 'package:path_provider_platform_interface/path_provider_platform_interface.dart'; // UNUSED
import 'package:docjet_mobile/core/utils/log_helpers.dart';

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

  /// Resolves a relative path against the application's documents directory.
  /// Returns absolute paths unchanged.
  /// Handles path normalization (e.g., './', '../', '//').
  String resolvePath(String path);
}

/// Concrete implementation of [FileSystem] using dart:io.
class IoFileSystem implements FileSystem {
  final logger = LoggerFactory.getLogger(IoFileSystem, level: Level.debug);
  // final String _tag = logTag(IoFileSystem);

  final String _documentsPath;

  IoFileSystem(this._documentsPath);

  /// Converts a potentially relative path into an absolute, normalized path.
  /// - If the path is already absolute, it's normalized and returned.
  /// - If the path is relative, it's joined with the application documents
  ///   directory, then normalized.
  /// Backslashes are converted to forward slashes for consistency before normalization.
  @override
  String resolvePath(String path) {
    logger.d('[resolvePath] Input: $path');
    // Use the path package context for platform-aware operations
    final p = path_pkg.context;

    if (p.isAbsolute(path)) {
      final normalizedPath = p.normalize(path.replaceAll('\\\\', '/'));
      logger.d('[resolvePath] Absolute Normalized: $normalizedPath');
      return normalizedPath;
    } else {
      // Sanitize first (replace backslashes)
      final sanitizedPath = path.replaceAll('\\\\', '/');
      logger.d('[resolvePath] Relative Sanitized: $sanitizedPath');

      // Join with the base documents path FIRST
      final joinedPath = p.join(_documentsPath, sanitizedPath);
      logger.d('[resolvePath] Relative Joined: $joinedPath');

      // THEN normalize the combined path
      final normalizedPath = p.normalize(joinedPath);
      logger.d('[resolvePath] Relative Final Normalized: $normalizedPath');
      return normalizedPath;
    }
  }

  @override
  Future<FileStat> stat(String path) async {
    final fullPath = resolvePath(path);

    // Security Check FIRST: Ensure the resolved path is within the base directory
    if (!path_pkg.context.isWithin(_documentsPath, fullPath)) {
      final message =
          'Stat access denied: Path "$path" resolves to "$fullPath" outside of base "$_documentsPath"';
      logger.e(message);
      throw FileSystemException(message, path);
    }

    // If path is safe, proceed with stat
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
    final fullPath = resolvePath(path);

    // Security Check FIRST: Ensure the resolved path is within the base directory
    if (!path_pkg.context.isWithin(_documentsPath, fullPath)) {
      final message =
          'List access denied: Path "$path" resolves to "$fullPath" outside of base "$_documentsPath"';
      logger.e(message);
      // Return a stream that immediately emits the error
      return Stream.error(FileSystemException(message, path));
    }

    // If path is safe, proceed to list the directory
    return Directory(fullPath).list(recursive: false);
  }

  @override
  Future<bool> fileExists(String path) async {
    final fullPath = resolvePath(path);
    // Security Check: Ensure the resolved path is still within the base directory
    if (!path_pkg.context.isWithin(_documentsPath, fullPath)) {
      logger.w(
        'Access denied: Path "$path" resolves to "$fullPath" outside of base "$_documentsPath"',
      );
      return false; // Path traversal detected, treat as non-existent
    }
    return File(fullPath).exists();
  }

  @override
  Future<void> writeFile(String path, Uint8List bytes) async {
    final fullPath = resolvePath(path);

    // Security Check FIRST: Ensure the resolved path is within the base directory
    if (!path_pkg.context.isWithin(_documentsPath, fullPath)) {
      final message =
          'Write access denied: Path "$path" resolves to "$fullPath" outside of base "$_documentsPath"';
      logger.e(message);
      throw FileSystemException(message, path);
    }

    // If path is safe, proceed with directory creation and write
    final dirPath = path_pkg.context.dirname(fullPath);
    await Directory(dirPath).create(recursive: true);
    await File(fullPath).writeAsBytes(bytes);
  }

  @override
  Future<List<int>> readFile(String path) async {
    final fullPath = resolvePath(path);

    // Security Check FIRST: Ensure the resolved path is within the base directory
    if (!path_pkg.context.isWithin(_documentsPath, fullPath)) {
      final message =
          'Read access denied: Path "$path" resolves to "$fullPath" outside of base "$_documentsPath"';
      logger.e(message);
      throw FileSystemException(message, path);
    }

    // If path is safe, proceed with read
    return File(fullPath).readAsBytes();
  }

  @override
  Future<void> deleteFile(String path) async {
    final fullPath = resolvePath(path);

    // Security Check FIRST: Ensure the resolved path is within the base directory
    if (!path_pkg.context.isWithin(_documentsPath, fullPath)) {
      final message =
          'Delete access denied: Path "$path" resolves to "$fullPath" outside of base "$_documentsPath"';
      logger.e(message);
      throw FileSystemException(message, path);
    }

    // If path is safe, check existence before deleting
    if (await File(fullPath).exists()) {
      await File(fullPath).delete();
    } else {
      logger.w('Attempted to delete non-existent file: $fullPath');
      // Optionally throw, but often deleting non-existent is not an error
    }
  }

  @override
  Future<void> createDirectory(String path, {bool recursive = false}) async {
    final fullPath = resolvePath(path);

    // Security Check FIRST: Ensure the resolved path is within the base directory
    if (!path_pkg.context.isWithin(_documentsPath, fullPath)) {
      final message =
          'Create directory access denied: Path "$path" resolves to "$fullPath" outside of base "$_documentsPath"';
      logger.e(message);
      throw FileSystemException(message, path);
    }

    // If path is safe, proceed to create directory
    await Directory(fullPath).create(recursive: recursive);
  }

  @override
  Future<bool> directoryExists(String path) async {
    final fullPath = resolvePath(path);

    // Security Check FIRST: Ensure the resolved path is within the base directory
    if (!path_pkg.context.isWithin(_documentsPath, fullPath)) {
      logger.w(
        'Directory exists check denied: Path "$path" resolves to "$fullPath" outside of base "$_documentsPath"',
      );
      return false; // Path traversal detected, treat as non-existent
    }

    // If path is safe, proceed to check directory existence
    return Directory(fullPath).exists();
  }
}
