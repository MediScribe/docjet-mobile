import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_status.dart';
import 'package:docjet_mobile/core/auth/transient_error.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'; // Import ValueGetter

export 'package:docjet_mobile/core/auth/presentation/auth_status.dart';

/// Represents the current authentication state for the UI
///
/// This class is used by UI components to render the appropriate
/// screens and widgets based on the auth status.
class AuthState extends Equatable {
  /// The current authenticated user, if any
  final User? user;

  /// The current status of authentication
  final AuthStatus status;

  /// Error message if authentication failed
  final String? errorMessage;

  /// Type of authentication error (if any)
  final AuthErrorType? errorType;

  /// Indicates if the current state was determined while offline
  final bool isOffline;

  /// Non-critical error that should be displayed to the user
  /// without blocking app functionality
  final TransientError? transientError;

  /// Creates an [AuthState] with the provided values
  const AuthState({
    this.user,
    required this.status,
    this.errorMessage,
    this.errorType,
    this.isOffline = false, // Default to false
    this.transientError,
  });

  /// Initial unauthenticated state
  factory AuthState.initial() {
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Loading state during authentication
  factory AuthState.loading() {
    return const AuthState(status: AuthStatus.loading);
  }

  /// Successfully authenticated state with user
  factory AuthState.authenticated(
    User user, {
    bool isOffline = false,
    TransientError? transientError,
  }) {
    return AuthState(
      user: user,
      status: AuthStatus.authenticated,
      isOffline: isOffline, // Pass along offline status
      transientError: transientError,
    );
  }

  /// Error state with error message
  factory AuthState.error(
    String message, {
    bool isOffline = false,
    AuthErrorType errorType = AuthErrorType.unknown,
    TransientError? transientError,
  }) {
    return AuthState(
      status: AuthStatus.error,
      errorMessage: message,
      errorType: errorType,
      isOffline: isOffline, // Pass along offline status
      transientError: transientError,
    );
  }

  /// Creates a copy of this state with the given fields replaced with new values
  AuthState copyWith({
    // Use ValueGetter<T?> pattern to distinguish between null and missing
    ValueGetter<User?>? user,
    AuthStatus? status,
    ValueGetter<String?>? errorMessage,
    ValueGetter<AuthErrorType?>? errorType,
    bool? isOffline,
    ValueGetter<TransientError?>? transientError,
  }) {
    return AuthState(
      user: user != null ? user() : this.user,
      status: status ?? this.status,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      errorType: errorType != null ? errorType() : this.errorType,
      isOffline: isOffline ?? this.isOffline,
      transientError:
          transientError != null ? transientError() : this.transientError,
    );
  }

  @override
  List<Object?> get props => [
    user,
    status,
    errorMessage,
    errorType,
    isOffline,
    transientError,
  ];
}
