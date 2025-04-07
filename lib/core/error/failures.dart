import 'package:equatable/equatable.dart';

/// Base Failure class for handling errors across the application.
abstract class Failure extends Equatable {
  // If you want to pass properties to the failure, add them here.
  // const Failure([List properties = const <dynamic>[]]);
  // For simplicity, no properties for now.
  const Failure();

  @override
  List<Object> get props => [];
}

// General failures
class ServerFailure extends Failure {}

class CacheFailure extends Failure {}

class UnknownFailure extends Failure {
  final String message;
  const UnknownFailure(this.message);

  @override
  List<Object> get props => [message];
}

// Specific failure types can be defined below, e.g.:
// class ServerFailure extends Failure { ... }
// class CacheFailure extends Failure { ... }
// class PermissionFailure extends Failure { ... }
// class FileSystemFailure extends Failure { ... }
// class RecordingFailure extends Failure { ... }
// class ConcatenationFailure extends Failure { ... }

// --- Specific Failure Types ---

/// Failure related to permissions (e.g., microphone access denied).
class PermissionFailure extends Failure {
  final String message;
  const PermissionFailure([this.message = 'Permission denied']);

  @override
  List<Object> get props => [message];
}

/// Failure related to file system operations (e.g., cannot read/write/delete file).
class FileSystemFailure extends Failure {
  final String message;
  const FileSystemFailure([this.message = 'File system error']);

  @override
  List<Object> get props => [message];
}

/// Failure related to the recording process itself (e.g., start/stop/pause/resume failed).
class RecordingFailure extends Failure {
  final String message;
  const RecordingFailure([this.message = 'Recording process error']);

  @override
  List<Object> get props => [message];
}

/// Failure during audio concatenation.
class ConcatenationFailure extends Failure {
  final String message;
  const ConcatenationFailure([this.message = 'Audio concatenation failed']);

  @override
  List<Object> get props => [message];
}

/// General platform failure (e.g., unexpected platform exception).
class PlatformFailure extends Failure {
  final String message;
  const PlatformFailure([
    this.message = 'An unexpected platform error occurred',
  ]);

  @override
  List<Object> get props => [message];
}

/// Failure related to invalid input or arguments.
class ValidationFailure extends Failure {
  final String message;
  const ValidationFailure([this.message = 'Invalid input provided']);

  @override
  List<Object> get props => [message];
}

/// Failure related to API interactions (e.g., network errors, server errors, unexpected responses).
class ApiFailure extends Failure {
  final String message;
  final int? statusCode; // Optional HTTP status code
  final String? errorCode; // Optional backend-specific error code

  const ApiFailure({
    this.message = 'API request failed',
    this.statusCode,
    this.errorCode,
  });

  @override
  List<Object> get props => [
    message,
    if (statusCode != null) statusCode!,
    if (errorCode != null) errorCode!,
  ];

  @override
  String toString() {
    return 'ApiFailure(message: $message, statusCode: $statusCode, errorCode: $errorCode)';
  }
}
