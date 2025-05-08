import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:docjet_mobile/core/auth/auth_error_type.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/features/auth/presentation/widgets/auth_error_message.dart';
import 'package:docjet_mobile/features/auth/presentation/widgets/auth_loading_indicator.dart';

// ---------------------------------------------------------------------------
// String literals extracted for future localisation.
// ---------------------------------------------------------------------------

const String _kLoginTitle = 'DocJet Login';
const String _kOfflineButtonText = 'Login Disabled - Your Device is Offline';
const String _kLoginButtonText = 'Login';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _formValid = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateForm);
    _passwordController.removeListener(_validateForm);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    bool emailValid = true;
    bool passwordValid = true;
    String? currentEmailError;
    String? currentPasswordError;

    // Basic email validation
    if (email.isEmpty) {
      emailValid = false;
      currentEmailError = 'Email cannot be empty';
    } else if (!RegExp(
      r"^[a-zA-Z0-9.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$",
    ).hasMatch(email)) {
      emailValid = false;
      currentEmailError = 'Please enter a valid email address';
    }

    // Basic password validation
    if (password.isEmpty) {
      passwordValid = false;
      currentPasswordError = 'Password cannot be empty';
    }

    // Update state only if errors or validity change
    if (mounted &&
        (_emailError != currentEmailError ||
            _passwordError != currentPasswordError ||
            _formValid != (emailValid && passwordValid))) {
      setState(() {
        _emailError = currentEmailError;
        _passwordError = currentPasswordError;
        _formValid = emailValid && passwordValid;
      });
    }
  }

  void _handleLogin() {
    _validateForm(); // Ensure validation runs on submit too
    if (!_formValid) return; // Don't submit if invalid

    // Call the CORRECT method on the notifier
    ref
        .read(authNotifierProvider.notifier)
        .login(_emailController.text.trim(), _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the auth state
    final authState = ref.watch(authNotifierProvider);
    final bool isOffline = authState.isOffline;
    final bool isLoading = authState.status == AuthStatus.loading;

    // Get app color tokens
    final appColors = getAppColors(context);

    // Disable button if loading, form is invalid, or offline
    final bool isButtonDisabled = isLoading || !_formValid || isOffline;

    // Calculate spacing ~15 % of the available height. Adjust if design changes.
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topSpacing = screenHeight * 0.15;

    return CupertinoPageScaffold(
      // No navigation bar – this page owns the entire screen.
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: AutofillGroup(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Add spacing at the top
                  SizedBox(height: topSpacing),

                  // Add the title inside the form layout
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Text(
                      _kLoginTitle,
                      style: TextStyle(
                        fontSize: 26.0,
                        fontWeight: FontWeight.bold,
                        color: appColors.brandInteractive.colorBrandPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  CupertinoTextField(
                    controller: _emailController,
                    placeholder: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(CupertinoIcons.mail),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    clearButtonMode: OverlayVisibilityMode.editing,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            _emailError != null
                                ? appColors
                                    .baseStatus
                                    .dangerFg // Use theme token for error
                                : appColors
                                    .outlineColor, // Use outline token for normal state
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  if (_emailError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                      child: Text(
                        _emailError!,
                        style: TextStyle(
                          color:
                              appColors
                                  .baseStatus
                                  .dangerFg, // Use theme token for error
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _passwordController,
                    placeholder: 'Password',
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onEditingComplete: _handleLogin,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(CupertinoIcons.lock),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    clearButtonMode: OverlayVisibilityMode.editing,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            _passwordError != null
                                ? appColors
                                    .baseStatus
                                    .dangerFg // Use theme token for error
                                : appColors
                                    .outlineColor, // Use outline token for normal state
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  if (_passwordError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                      child: Text(
                        _passwordError!,
                        style: TextStyle(
                          color:
                              appColors
                                  .baseStatus
                                  .dangerFg, // Use theme token for error
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Show error messages for auth errors only (non-offline errors)
                  if (authState.status == AuthStatus.error &&
                      authState.errorMessage != null &&
                      authState.errorType != AuthErrorType.offlineOperation)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildErrorMessage(authState),
                    ),

                  // Show loading indicator OR Login Button
                  isLoading
                      ? const AuthLoadingIndicator()
                      : CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        onPressed: isButtonDisabled ? null : _handleLogin,
                        disabledColor:
                            appColors
                                .brandInteractive
                                .colorInteractiveSecondaryBackground,
                        child: Text(
                          isOffline ? _kOfflineButtonText : _kLoginButtonText,
                        ),
                      ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(AuthState authState) {
    // Legacy fallback using string matching (should rarely be needed now)
    final String errorMessage = authState.errorMessage ?? '';

    if (errorMessage.contains('Invalid credentials') ||
        errorMessage.contains('email or password')) {
      return AuthErrorMessage.invalidCredentials();
    }

    if (errorMessage.contains('Network error') ||
        errorMessage.contains('connection')) {
      return AuthErrorMessage.networkError();
    }

    // Default error message (for non-offline, unknown cases)
    return errorMessage.isEmpty
        ? const SizedBox.shrink()
        : AuthErrorMessage(errorMessage: errorMessage);
  }
}
