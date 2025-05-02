import 'package:docjet_mobile/core/auth/presentation/widgets/offline_banner.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/common/models/app_message.dart';
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
    // Listen to the app notifier service for messages
    final AppMessage? appMessage = ref.watch(appNotifierServiceProvider);
    final appNotifier = ref.read(appNotifierServiceProvider.notifier);

    // Check if we're offline
    final isOffline = ref.watch(
      authNotifierProvider.select((state) => state.isOffline),
    );

    return Column(
      children: [
        // The offline banner automatically shows/hides based on connectivity
        const OfflineBanner(),

        // Display the configurable banner if there's a message
        if (appMessage != null)
          // Only wrap with SafeArea when we're NOT offline
          // This prevents gaps between stacked banners
          isOffline
              ? ConfigurableTransientBanner(
                message: appMessage,
                onDismiss: appNotifier.dismiss,
              )
              : SafeArea(
                top: true,
                bottom: false,
                child: ConfigurableTransientBanner(
                  message: appMessage,
                  onDismiss: appNotifier.dismiss,
                ),
              ),

        // Flexible child to take remaining space
        Expanded(child: child),
      ],
    );
  }
}
