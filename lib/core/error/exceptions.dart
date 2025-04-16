/// Represents exceptions originating from server interactions.
class ServerException implements Exception {
  final String? message;
  ServerException([this.message]);
}

/// Represents exceptions originating from local cache interactions.
class CacheException implements Exception {
  final String? message;
  CacheException([this.message]);
}

/// Represents exceptions related to permissions.
class PermissionException implements Exception {
  final String? message;
  PermissionException([this.message]);
}

/// Represents exceptions related to file system operations.
class FileSystemException implements Exception {
  final String? message;
  FileSystemException([this.message]);
}

/// Represents exceptions related to API interactions (network, status codes, parsing).
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() {
    return 'ApiException(message: $message, statusCode: $statusCode)';
  }
}
