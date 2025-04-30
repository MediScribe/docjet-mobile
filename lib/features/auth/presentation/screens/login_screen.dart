import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/features/auth/presentation/widgets/auth_error_message.dart';
import 'package:docjet_mobile/features/auth/presentation/widgets/auth_loading_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart'; // Import theme utilities

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
    final bool isLoading = authState.status == AuthStatus.loading;

    // Get app color tokens
    final appColors = getAppColors(context);

    // Disable button if loading or form is invalid
    final bool isButtonDisabled = isLoading || !_formValid;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('DocJet Login')),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: AutofillGroup(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                              appColors.dangerFg, // Use theme token for error
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
                              appColors.dangerFg, // Use theme token for error
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Show server/auth error messages if present
                  if (authState.status == AuthStatus.error &&
                      authState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: _buildErrorMessage(authState),
                    ),

                  // Show loading indicator OR Login Button
                  isLoading
                      ? const AuthLoadingIndicator()
                      : CupertinoButton.filled(
                        onPressed: isButtonDisabled ? null : _handleLogin,
                        child: const Text('Login'),
                      ),

                  // Conditionally display offline indicator
                  if (authState.isOffline) const SizedBox(height: 10),
                  if (authState.isOffline) AuthErrorMessage.offlineMode(),
                ],
              ),
            ),
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
