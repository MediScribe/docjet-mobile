import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_status.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'; // Import ValueGetter

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

  /// Indicates if the current state was determined while offline
  final bool isOffline;

  /// Creates an [AuthState] with the provided values
  const AuthState({
    this.user,
    required this.status,
    this.errorMessage,
    this.isOffline = false, // Default to false
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
  factory AuthState.authenticated(User user, {bool isOffline = false}) {
    return AuthState(
      user: user,
      status: AuthStatus.authenticated,
      isOffline: isOffline, // Pass along offline status
    );
  }

  /// Error state with error message
  factory AuthState.error(String message, {bool isOffline = false}) {
    return AuthState(
      status: AuthStatus.error,
      errorMessage: message,
      isOffline: isOffline, // Pass along offline status
    );
  }

  /// Creates a copy of this state with the given fields replaced with new values
  AuthState copyWith({
    // Use ValueGetter<T?> pattern to distinguish between null and missing
    ValueGetter<User?>? user,
    AuthStatus? status,
    ValueGetter<String?>? errorMessage,
    bool? isOffline,
  }) {
    return AuthState(
      user: user != null ? user() : this.user,
      status: status ?? this.status,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  @override
  List<Object?> get props => [user, status, errorMessage, isOffline];
}
