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

/// Implementation for TDD
class PathResolverImpl implements PathResolver {
  PathResolverImpl({required this.pathProvider, required this.fileExists});
  final dynamic pathProvider;
  final FileExistsFunction fileExists;

  @override
  Future<String> resolve(String inputPath, {bool mustExist = false}) async {
    if (p.isAbsolute(inputPath)) {
      if (mustExist) {
        final exists = await fileExists(inputPath);
        if (exists) return inputPath;
        throw PathResolutionException(
          'Absolute path does not exist: $inputPath',
        );
      }
      return inputPath;
    }
    final docsDir = await pathProvider.getApplicationDocumentsDirectory();
    // Replace all backslashes with forward slashes for cross-platform consistency
    final sanitized = inputPath.replaceAll('\\', '/');
    final normalized = p.normalize(sanitized);
    final resolved = p.join(docsDir.path, normalized);
    if (mustExist) {
      final exists = await fileExists(resolved);
      if (exists) return resolved;
      throw PathResolutionException('Resolved path does not exist: $resolved');
    }
    return resolved;
  }
}
