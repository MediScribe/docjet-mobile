import 'dart:async';
import 'package:path/path.dart' as p;

/// Exception thrown when path resolution fails.
class PathResolutionException implements Exception {
  final String message;
  PathResolutionException(this.message);
  @override
  String toString() => 'PathResolutionException: $message';
}

/// Abstract contract for resolving paths.
abstract class PathResolver {
  Future<String> resolve(String inputPath, {bool mustExist = false});
}

/// Function type for file existence check.
typedef FileExistsFunction = Future<bool> Function(String path);

/// Implementation of PathResolver that handles both absolute and relative paths.
///
/// This class resolves paths according to the following rules:
/// - Absolute paths are returned as-is (if they exist when mustExist=true)
/// - Relative paths are resolved against the application documents directory
/// - All paths are normalized and use forward slashes for cross-platform consistency
class PathResolverImpl implements PathResolver {
  /// Creates a new PathResolverImpl.
  ///
  /// Requires a [pathProvider] to get the application documents directory
  /// and a [fileExists] function to check if files exist when needed.
  PathResolverImpl({required this.pathProvider, required this.fileExists});

  /// Provider for platform-specific directories
  final dynamic pathProvider;

  /// Function to check if a file exists at a given path
  final FileExistsFunction fileExists;

  @override
  Future<String> resolve(String inputPath, {bool mustExist = false}) async {
    // Handle absolute paths
    if (p.isAbsolute(inputPath)) {
      // If mustExist is true, verify the file exists before returning
      if (mustExist) {
        final exists = await fileExists(inputPath);
        if (exists) return inputPath;
        throw PathResolutionException(
          'Absolute path does not exist: $inputPath',
        );
      }
      return inputPath;
    }

    // Handle relative paths
    final docsDir = await pathProvider.getApplicationDocumentsDirectory();

    // Replace all backslashes with forward slashes for cross-platform consistency
    final sanitized = inputPath.replaceAll('\\', '/');

    // Normalize the path to handle '.', '..', and redundant separators
    final normalized = p.normalize(sanitized);

    // Join with the application documents directory to get the full path
    final resolved = p.join(docsDir.path, normalized);

    // If mustExist is true, verify the resolved file exists
    if (mustExist) {
      final exists = await fileExists(resolved);
      if (exists) return resolved;
      throw PathResolutionException('Resolved path does not exist: $resolved');
    }

    return resolved;
  }
}
