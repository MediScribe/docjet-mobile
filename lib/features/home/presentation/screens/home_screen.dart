import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the auth state
    final authState = ref.watch(authNotifierProvider);

    // Extract user information if authenticated
    final user =
        authState.status == AuthStatus.authenticated ? authState.user : null;

    // TODO: Implement actual home screen UI (e.g., job list)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              // Call logout method on the notifier
              ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Home Screen Placeholder'),
            if (user != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('User ID: ${user.id}'),
              )
            else if (authState.status == AuthStatus.loading)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: CircularProgressIndicator(),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Text('Not logged in or error state'),
              ),
          ],
        ),
      ),
    );
  }
}
