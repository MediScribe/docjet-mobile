import 'package:equatable/equatable.dart';

/// Base Failure class for handling errors across the application.
abstract class Failure extends Equatable {
  final List properties;
  const Failure([this.properties = const <dynamic>[]]);

  // Add an abstract message getter
  String get message;

  @override
  List<Object> get props => [properties, message]; // Include message in props
}

// --- General Failure Types ---

/// Represents an error originating from the backend server or API communication (non-2xx status code).
class ServerFailure extends Failure {
  @override
  final String message;
  final int? statusCode;
  const ServerFailure({this.message = 'Server error', this.statusCode});

  @override
  List<Object> get props => [message, statusCode ?? 0];
}

/// Represents an error originating from the local cache (e.g., Hive, SharedPreferences).
class CacheFailure extends Failure {
  @override
  final String message;
  const CacheFailure([this.message = 'Local cache error']);

  @override
  List<Object> get props => [message];
}

/// Represents an unexpected or unknown error.
class UnknownFailure extends Failure {
  @override
  final String message;
  const UnknownFailure(this.message);

  @override
  List<Object> get props => [message];
}

// --- Specific Failure Types ---

/// Failure related to permissions (e.g., microphone access denied).
class PermissionFailure extends Failure {
  @override
  final String message;
  const PermissionFailure([this.message = 'Permission denied']);

  @override
  List<Object> get props => [message];
}

/// Failure related to file system operations (e.g., cannot read/write/delete file).
class FileSystemFailure extends Failure {
  @override
  final String message;
  const FileSystemFailure([this.message = 'File system error']);

  @override
  List<Object> get props => [message];
}

/// Failure related to the recording process itself (e.g., start/stop/pause/resume failed).
class RecordingFailure extends Failure {
  @override
  final String message;
  const RecordingFailure([this.message = 'Recording process error']);

  @override
  List<Object> get props => [message];
}

/// Failure during audio concatenation.
class ConcatenationFailure extends Failure {
  @override
  final String message;
  const ConcatenationFailure([this.message = 'Audio concatenation failed']);

  @override
  List<Object> get props => [message];
}

/// General platform failure (e.g., unexpected platform exception).
class PlatformFailure extends Failure {
  @override
  final String message;
  const PlatformFailure([
    this.message = 'An unexpected platform error occurred',
  ]);

  @override
  List<Object> get props => [message];
}

/// Failure related to invalid input or arguments.
class ValidationFailure extends Failure {
  @override
  final String message;
  const ValidationFailure([this.message = 'Invalid input provided']);

  @override
  List<Object> get props => [message];
}

/// Failure related to API interactions (e.g., network errors, specific API error responses).
/// Consider using this or ServerFailure depending on the desired level of detail.
class ApiFailure extends Failure {
  @override
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

/// Authentication error
class AuthFailure extends Failure {
  @override
  String get message => 'Authentication failed';
}
