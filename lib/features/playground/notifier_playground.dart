import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:docjet_mobile/core/common/models/app_message.dart';
import 'package:docjet_mobile/core/common/notifiers/app_notifier_service.dart';
import 'package:docjet_mobile/core/common/widgets/configurable_transient_banner.dart';

/// A playground screen for testing the [AppNotifierService]
/// and visualizing the [ConfigurableTransientBanner].
class NotifierPlaygroundScreen extends ConsumerWidget {
  const NotifierPlaygroundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMessage = ref.watch(appNotifierServiceProvider);
    final notifier = ref.read(appNotifierServiceProvider.notifier);

    // Button helper
    Widget buildButton(String label, VoidCallback onPressed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: ElevatedButton(onPressed: onPressed, child: Text(label)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifier Playground')),
      body: Column(
        children: [
          // --- Temporary Banner Display Area ---
          // Use AnimatedSwitcher for smooth transitions when message appears/disappears
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              // Use a slide transition from the top
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1), // Start off-screen top
                  end: Offset.zero, // End at normal position
                ).animate(animation),
                child: child,
              );
            },
            // Show banner if message exists, otherwise an empty SizedBox
            child:
                currentMessage != null
                    ? ConfigurableTransientBanner(
                      key: ValueKey(
                        currentMessage.id,
                      ), // Important for AnimatedSwitcher
                      message: currentMessage,
                      onDismiss:
                          notifier
                              .dismiss, // Use the dismiss method from the notifier
                    )
                    : const SizedBox.shrink(), // Empty space when no message
          ),

          // --- End Temporary Banner Display Area ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                buildButton(
                  'Show Info (3s)',
                  () => notifier.show(
                    message: 'This is an informational message.',
                    type: MessageType.info,
                    duration: const Duration(seconds: 3),
                  ),
                ),
                buildButton(
                  'Show Info (Manual Dismiss)',
                  () => notifier.show(
                    message:
                        'This informational message needs manual dismissal.',
                    type: MessageType.info,
                    duration: null,
                  ),
                ),
                const Divider(),
                buildButton(
                  'Show Success (4s)',
                  () => notifier.show(
                    message: 'Operation completed successfully!',
                    type: MessageType.success,
                    duration: const Duration(seconds: 4),
                  ),
                ),
                buildButton(
                  'Show Success (Manual Dismiss)',
                  () => notifier.show(
                    message: 'Success! Tap close to dismiss.',
                    type: MessageType.success,
                    duration: null,
                  ),
                ),
                const Divider(),
                buildButton(
                  'Show Warning (5s)',
                  () => notifier.show(
                    message: 'Warning: Please check your input.',
                    type: MessageType.warning,
                    duration: const Duration(seconds: 5),
                  ),
                ),
                buildButton(
                  'Show Warning (Manual Dismiss)',
                  () => notifier.show(
                    message: 'This is a warning. Be careful!',
                    type: MessageType.warning,
                    duration: null,
                  ),
                ),
                const Divider(),
                buildButton(
                  'Show Error (6s)',
                  () => notifier.show(
                    message: 'Error: Failed to load data.',
                    type: MessageType.error,
                    duration: const Duration(seconds: 6),
                  ),
                ),
                buildButton(
                  'Show Error (Manual Dismiss)',
                  () => notifier.show(
                    message: 'An error occurred. Please try again.',
                    type: MessageType.error,
                    duration: null,
                  ),
                ),
                const Divider(),
                buildButton('Show Rapid Fire (Success -> Error)', () async {
                  notifier.show(
                    message: 'Quick Success!',
                    type: MessageType.success,
                    duration: const Duration(milliseconds: 500),
                  );
                  await Future.delayed(const Duration(milliseconds: 250));
                  notifier.show(
                    message: 'Now Quick Error!',
                    type: MessageType.error,
                    duration: const Duration(seconds: 3),
                  );
                }),
                buildButton(
                  'Dismiss Current Banner',
                  notifier.dismiss, // Directly call dismiss
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
