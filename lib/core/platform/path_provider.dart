import 'dart:io';

import 'package:path_provider/path_provider.dart' as pp;

/// Abstract interface for path provider operations to allow for mocking in tests.
abstract class PathProvider {
  /// Gets the application documents directory.
  Future<Directory> getApplicationDocumentsDirectory();
}

/// Concrete implementation of [PathProvider] using the path_provider package.
class AppPathProvider implements PathProvider {
  @override
  Future<Directory> getApplicationDocumentsDirectory() =>
      pp.getApplicationDocumentsDirectory();
}
