import 'dart:io';

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
}

/// Concrete implementation of [FileSystem] using dart:io.
class IoFileSystem implements FileSystem {
  @override
  Future<FileStat> stat(String path) => File(path).stat();

  @override
  Future<bool> fileExists(String path) => File(path).exists();

  @override
  Future<void> deleteFile(String path) async {
    final file = File(path);
    // Check existence before deleting to match previous behavior?
    // Or let dart:io handle non-existent file deletion error?
    // Let's keep it simple and let dart:io throw if needed.
    await file.delete();
  }

  @override
  Future<bool> directoryExists(String path) => Directory(path).exists();

  @override
  Future<void> createDirectory(String path, {bool recursive = false}) async {
    await Directory(path).create(recursive: recursive);
  }

  @override
  Stream<FileSystemEntity> listDirectory(String path) =>
      Directory(path).list(recursive: false); // Assuming non-recursive listing

  @override
  List<FileSystemEntity> listDirectorySync(String path) =>
      Directory(path).listSync(recursive: false); // Assuming non-recursive
}
