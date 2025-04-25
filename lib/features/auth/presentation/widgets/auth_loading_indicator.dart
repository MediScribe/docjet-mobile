import 'package:flutter/cupertino.dart';

/// A standardized loading indicator for authentication-related UI components
class AuthLoadingIndicator extends StatelessWidget {
  /// Creates an AuthLoadingIndicator widget
  const AuthLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: CupertinoActivityIndicator(),
      ),
    );
  }
}
