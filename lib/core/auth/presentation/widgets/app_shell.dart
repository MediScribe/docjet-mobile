import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/widgets/offline_banner.dart';
import 'package:docjet_mobile/core/common/notifiers/app_notifier_service.dart';
import 'package:docjet_mobile/core/common/widgets/configurable_transient_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A shell wrapper for the application that provides common UI elements
/// like the offline banner and global transient notifications.
///
/// This wrapper should be used around the main content of each screen
/// to ensure consistent presentation of application-wide UI elements.
class AppShell extends ConsumerWidget {
  /// The main content to be displayed.
  final Widget child;

  /// Creates an [AppShell] with the provided content.
  ///
  /// The [child] is the main content to be displayed.
  const AppShell({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the app notifier for messages
    final appNotifier = ref.watch(appNotifierServiceProvider.notifier);
    final appMessage = ref.watch(appNotifierServiceProvider);

    // Check if we're offline - needed to conditionally apply SafeArea
    final isOffline = ref.watch(
      authNotifierProvider.select((state) => state.isOffline),
    );

    return Column(
      children: [
        // The offline banner automatically shows/hides based on connectivity
        const OfflineBanner(),

        // Display the configurable banner if there's a message
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1.0, // Top alignment
              child: child,
            );
          },
          child:
              appMessage != null
                  ? Container(
                    // Key should be on the immediate child of AnimatedSwitcher
                    key: ValueKey(appMessage.id),
                    color:
                        Theme.of(
                          context,
                        ).scaffoldBackgroundColor, // Match app background
                    // Apply SafeArea conditionally: ONLY if OFFLINE banner is NOT visible
                    child: SafeArea(
                      top:
                          !isOffline, // Apply top padding ONLY when not offline
                      bottom: false, // Don't consume bottom safe area
                      child: ConfigurableTransientBanner(
                        message: appMessage,
                        onDismiss: appNotifier.dismiss,
                      ),
                    ),
                  )
                  : const SizedBox.shrink(), // Empty widget when no message
        ),

        // Flexible child to take remaining space
        Expanded(child: child),
      ],
    );
  }
}
