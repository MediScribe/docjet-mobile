import 'package:docjet_mobile/core/auth/presentation/widgets/offline_banner.dart';
import 'package:docjet_mobile/core/common/widgets/transient_error_banner.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:flutter/material.dart';

/// A shell wrapper for the application that provides common UI elements
/// like the offline banner.
///
/// This wrapper should be used around the main content of each screen
/// to ensure consistent presentation of application-wide UI elements.
class AppShell extends StatelessWidget {
  /// The main content to be displayed.
  final Widget child;

  /// Creates an AppShell widget.
  ///
  /// The [child] parameter is required and represents the main content
  /// to be displayed below any application-wide UI elements.
  const AppShell({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The offline banner automatically shows/hides based on connectivity
        const OfflineBanner(),

        // The transient error banner shows/hides based on transient errors in auth state
        TransientErrorBanner(authNotifierProvider: authNotifierProvider),

        // Flexible child to take remaining space
        Expanded(child: child),
      ],
    );
  }
}
