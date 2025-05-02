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
    // TODO(Elias): Fix bug: isOffline is not used!
    // final isOffline = ref.watch(
    //   authNotifierProvider.select((state) => state.maybeWhen(
    //     offline: (_) => true, // Consider offline if in explicit offline state
    //     orElse: () => false, // Otherwise online
    //   )),
    // );

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
                    color:
                        Theme.of(
                          context,
                        ).scaffoldBackgroundColor, // Match app background
                    child: SafeArea(
                      key: ValueKey(
                        appMessage.id,
                      ), // Important for AnimatedSwitcher
                      top: true,
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
