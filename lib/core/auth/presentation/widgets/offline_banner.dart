import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/theme/offline_banner_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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

    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    // When offline, wrap with AnnotatedRegion to make status bar icons visible
    final Widget banner = Semantics(
      label: 'Offline status indicator',
      value:
          isOffline ? 'You are currently offline' : 'You are currently online',
      excludeSemantics:
          true, // Excludes children semantics to avoid duplication
      child: AnimatedContainer(
        duration: OfflineBannerTheme.animationDuration,
        height: isOffline ? topPadding + OfflineBannerTheme.height : 0.0,
        color: OfflineBannerTheme.getBackgroundColor(context),
        // When offline we want the colored background to fill the system
        // status bar area as well, so we add top padding manually.
        child:
            isOffline
                ? Padding(
                  padding: EdgeInsets.only(top: topPadding),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.wifi_slash,
                          color: OfflineBannerTheme.getForegroundColor(context),
                          size: OfflineBannerTheme.iconSize,
                        ),
                        const SizedBox(
                          width: OfflineBannerTheme.iconTextSpacing,
                        ),
                        Text(
                          'You are offline',
                          style: OfflineBannerTheme.getTextStyle(context),
                        ),
                      ],
                    ),
                  ),
                )
                : const SizedBox.shrink(),
      ),
    );

    // Only apply AnnotatedRegion when offline to control system UI style
    return isOffline
        ? AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light, // White status bar icons
          child: banner,
        )
        : banner;
  }
}
