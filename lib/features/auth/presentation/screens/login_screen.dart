import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the auth state
    final authState = ref.watch(authNotifierProvider);

    // TODO: Implement actual login form UI
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Login Screen Placeholder'),
            // Conditionally display offline indicator
            if (authState.isOffline)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Text(
                  'Offline Mode',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
