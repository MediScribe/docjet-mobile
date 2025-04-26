import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:flutter/cupertino.dart';

/// A widget for displaying authentication-related error messages with consistent styling.
class AuthErrorMessage extends StatelessWidget {
  /// The error message to display
  final String errorMessage;

  /// The type of error (if known)
  final AuthErrorType? errorType;

  /// Creates an AuthErrorMessage widget
  const AuthErrorMessage({
    super.key,
    required this.errorMessage,
    this.errorType,
  });

  /// Creates an AuthErrorMessage specific to invalid credentials errors
  factory AuthErrorMessage.invalidCredentials() {
    return const AuthErrorMessage(
      errorMessage: 'Invalid email or password. Please try again.',
      errorType: AuthErrorType.invalidCredentials,
    );
  }

  /// Creates an AuthErrorMessage specific to network errors
  factory AuthErrorMessage.networkError() {
    return const AuthErrorMessage(
      errorMessage:
          'Network error. Please check your connection and try again.',
      errorType: AuthErrorType.network,
    );
  }

  /// Creates an AuthErrorMessage for offline mode indication
  factory AuthErrorMessage.offlineMode() {
    return const AuthErrorMessage(
      errorMessage: 'Offline Mode',
      errorType: AuthErrorType.offlineOperation,
    );
  }

  /// Creates an AuthErrorMessage based on the error type
  factory AuthErrorMessage.fromErrorType(
    AuthErrorType type, [
    String? customMessage,
  ]) {
    switch (type) {
      case AuthErrorType.invalidCredentials:
        return AuthErrorMessage.invalidCredentials();
      case AuthErrorType.network:
        return AuthErrorMessage.networkError();
      case AuthErrorType.offlineOperation:
        return AuthErrorMessage.offlineMode();
      case AuthErrorType.server:
        return AuthErrorMessage(
          errorMessage:
              customMessage ?? 'Server error occurred. Please try again later.',
          errorType: type,
        );
      case AuthErrorType.tokenExpired:
        return AuthErrorMessage(
          errorMessage:
              customMessage ?? 'Your session has expired. Please log in again.',
          errorType: type,
        );
      case AuthErrorType.unauthenticated:
        return AuthErrorMessage(
          errorMessage:
              customMessage ??
              'You are not logged in. Please log in to continue.',
          errorType: type,
        );
      case AuthErrorType.refreshTokenInvalid:
        return AuthErrorMessage(
          errorMessage:
              customMessage ??
              'Your session could not be refreshed. Please log in again.',
          errorType: type,
        );
      case AuthErrorType.userProfileFetchFailed:
        return AuthErrorMessage(
          errorMessage:
              customMessage ?? 'Failed to retrieve your profile information.',
          errorType: type,
        );
      case AuthErrorType.unauthorizedOperation:
        return AuthErrorMessage(
          errorMessage:
              customMessage ?? 'You are not authorized to perform this action.',
          errorType: type,
        );
      case AuthErrorType.missingApiKey:
        return AuthErrorMessage(
          errorMessage:
              customMessage ??
              'API key is missing. Please check app configuration.',
          errorType: type,
        );
      case AuthErrorType.malformedUrl:
        return AuthErrorMessage(
          errorMessage:
              customMessage ??
              'Invalid API URL path. Please report this issue.',
          errorType: type,
        );
      case AuthErrorType.unknown:
        return AuthErrorMessage(
          errorMessage:
              customMessage ?? 'An unknown error occurred. Please try again.',
          errorType: type,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        errorMessage,
        style: TextStyle(color: _getColorForErrorType()),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Determines the appropriate color based on the error type
  Color _getColorForErrorType() {
    // If explicit error type is provided, use it
    if (errorType != null) {
      // Offline mode uses gray
      if (errorType == AuthErrorType.offlineOperation) {
        return CupertinoColors.inactiveGray;
      }

      // All other errors use red
      return CupertinoColors.destructiveRed;
    }

    // Fallback based on message content (legacy support)
    if (errorMessage == 'Offline Mode') {
      return CupertinoColors.inactiveGray;
    }

    return CupertinoColors.destructiveRed;
  }
}
