import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/features/jobs/presentation/pages/job_list_page.dart';
import 'package:docjet_mobile/features/jobs/presentation/pages/job_list_playground.dart';
import 'package:flutter/cupertino.dart';
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

    // Get offline status
    final isOffline = authState.isOffline;

    // TODO: Implement actual home screen UI (e.g., job list)
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Home'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.square_arrow_right),
          onPressed: () {
            ref.read(authNotifierProvider.notifier).logout();
          },
        ),
      ),
      child: Center(
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
                child: CupertinoActivityIndicator(),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Text('Not logged in or error state'),
              ),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed:
                  isOffline
                      ? null
                      : () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => const JobListPage(),
                          ),
                        );
                      },
              child: const Text('Go to Jobs List'),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => const JobListPlayground(),
                  ),
                );
              },
              child: const Text('Go to Job List Playground'),
            ),
          ],
        ),
      ),
    );
  }
}
