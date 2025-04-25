import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/features/auth/presentation/widgets/auth_error_message.dart';
import 'package:docjet_mobile/features/auth/presentation/widgets/auth_loading_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the auth state
    final authState = ref.watch(authNotifierProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('DocJet Login')),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Login Screen Placeholder',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Show loading indicator during authentication
              if (authState.status == AuthStatus.loading)
                const AuthLoadingIndicator(),

              // Show error messages if present
              if (authState.status == AuthStatus.error &&
                  authState.errorMessage != null)
                _buildErrorMessage(authState),

              // Conditionally display offline indicator
              if (authState.isOffline) AuthErrorMessage.offlineMode(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(AuthState authState) {
    // If we have an error type, use it directly
    if (authState.errorType != null) {
      return AuthErrorMessage.fromErrorType(
        authState.errorType!,
        authState.errorMessage,
      );
    }

    // Legacy fallback using string matching (should rarely be needed now)
    final errorMessage = authState.errorMessage!;

    if (errorMessage.contains('Invalid credentials') ||
        errorMessage.contains('email or password')) {
      return AuthErrorMessage.invalidCredentials();
    }

    if (errorMessage.contains('Network error') ||
        errorMessage.contains('connection')) {
      return AuthErrorMessage.networkError();
    }

    // Default error message
    return AuthErrorMessage(errorMessage: errorMessage);
  }
}
