import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:equatable/equatable.dart';

/// Represents a non-critical error that should be displayed to the user
/// without blocking app functionality or navigation
class TransientError extends Equatable {
  /// A user-friendly message explaining the error
  final String message;

  /// The type of authentication error
  final AuthErrorType type;

  /// Creates a [TransientError] with the provided values
  const TransientError({required this.message, required this.type});

  @override
  List<Object?> get props => [message, type];
}
