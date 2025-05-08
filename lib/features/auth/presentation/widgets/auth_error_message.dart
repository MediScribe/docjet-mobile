import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:flutter/cupertino.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart'; // Import theme utilities

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
    final appColors = getAppColors(context); // Get app colors

    // Special handling for offline mode to include a background
    if (errorType == AuthErrorType.offlineOperation) {
      return Container(
        color: appColors.baseStatus.offlineBg, // Use offlineBg for background
        width: double.infinity, // Ensure container takes full width
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8.0,
            horizontal: 16.0,
          ), // Adjusted padding
          child: Text(
            errorMessage,
            style: TextStyle(
              color: appColors.baseStatus.offlineFg,
            ), // Use offlineFg for text
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Default rendering for other error types
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        errorMessage,
        style: TextStyle(color: _getColorForErrorType(context)),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Determines the appropriate color based on the error type using theme tokens
  Color _getColorForErrorType(BuildContext context) {
    // Get app color tokens
    final appColors = getAppColors(context);

    // If explicit error type is provided, use it
    if (errorType != null) {
      // Offline mode uses its specific foreground color
      if (errorType == AuthErrorType.offlineOperation) {
        // This case should ideally be handled by the main build method's dedicated offline UI,
        // but if called directly, use the correct offline foreground.
        return appColors.baseStatus.offlineFg;
      }
      // Info messages (if we had a generic info type separate from offline)
      // else if (errorType == AuthErrorType.info) { // Example
      //   return appColors.baseStatus.infoFg;
      // }

      // All other errors use danger color
      return appColors.baseStatus.dangerFg;
    }

    // Fallback based on message content (legacy support)
    // This section might need review if "Offline Mode" text is still possible
    // without errorType being AuthErrorType.offlineOperation.
    if (errorMessage == 'Offline Mode') {
      // Assuming this also implies an offline state, use offlineFg.
      // However, relying on errorType is more robust.
      return appColors.baseStatus.offlineFg;
    }

    return appColors.baseStatus.dangerFg;
  }
}
