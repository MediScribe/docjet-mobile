import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/theme/offline_banner_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A banner that displays an offline indicator when the app is offline.
///
/// This banner is designed to be placed at the top of the screen and will
/// automatically show/hide based on the app's connectivity state as tracked
/// by the [authNotifierProvider]. It adapts its colors to the current theme
/// and provides proper semantics for accessibility.
class OfflineBanner extends ConsumerWidget {
  /// Creates an OfflineBanner widget.
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the current auth state which includes offline status
    final authState = ref.watch(authNotifierProvider);
    final isOffline = authState.isOffline;

    // Use AnimatedContainer for smooth height transition and AnimatedOpacity for fade
    return Semantics(
      label: 'Offline status indicator',
      value:
          isOffline ? 'You are currently offline' : 'You are currently online',
      excludeSemantics:
          true, // Excludes children semantics to avoid duplication
      child: AnimatedContainer(
        duration: OfflineBannerTheme.animationDuration,
        height: isOffline ? OfflineBannerTheme.height : 0.0,
        color: OfflineBannerTheme.getBackgroundColor(context),
        child: AnimatedOpacity(
          duration: OfflineBannerTheme.animationDuration,
          opacity: isOffline ? 1.0 : 0.0,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.wifi_slash,
                  color: OfflineBannerTheme.getForegroundColor(context),
                  size: OfflineBannerTheme.iconSize,
                ),
                const SizedBox(width: OfflineBannerTheme.iconTextSpacing),
                Text(
                  'You are offline',
                  style: OfflineBannerTheme.getTextStyle(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
