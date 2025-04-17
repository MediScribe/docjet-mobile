import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_status.dart';
import 'package:equatable/equatable.dart';

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

  /// Creates an [AuthState] with the provided values
  const AuthState({this.user, required this.status, this.errorMessage});

  /// Initial unauthenticated state
  factory AuthState.initial() {
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Loading state during authentication
  factory AuthState.loading() {
    return const AuthState(status: AuthStatus.loading);
  }

  /// Successfully authenticated state with user
  factory AuthState.authenticated(User user) {
    return AuthState(user: user, status: AuthStatus.authenticated);
  }

  /// Error state with error message
  factory AuthState.error(String message) {
    return AuthState(status: AuthStatus.error, errorMessage: message);
  }

  /// Creates a copy of this state with the given fields replaced with new values
  AuthState copyWith({User? user, AuthStatus? status, String? errorMessage}) {
    return AuthState(
      user: user ?? this.user,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [user, status, errorMessage];
}
