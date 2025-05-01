import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/auth/transient_error.dart';

/// A banner that displays transient error messages.
/// Automatically dismisses after a timeout or when the user taps the close button.
class TransientErrorBanner extends ConsumerStatefulWidget {
  /// The provider to listen to for transient errors.
  final NotifierProvider<AuthNotifier, AuthState> authNotifierProvider;

  /// The duration after which the banner automatically dismisses.
  final Duration autoDismissDuration;

  /// Creates a new [TransientErrorBanner].
  const TransientErrorBanner({
    super.key,
    required this.authNotifierProvider,
    this.autoDismissDuration = const Duration(seconds: 5),
  });

  @override
  TransientErrorBannerState createState() => TransientErrorBannerState();
}

/// Styling constants for the TransientErrorBanner. Kept internal to avoid polluting public API.
class _TransientErrorBannerTheme {
  static const double height = 50.0;
  static const Duration animationDuration = Duration(milliseconds: 300);

  // Using a hard-coded color keeps the banner clearly distinguishable from other banners.
  static const Color backgroundColor = Color(0xFFD32F2F); // red700

  static const TextStyle messageStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );
}

class TransientErrorBannerState extends ConsumerState<TransientErrorBanner> {
  Timer? _dismissTimer;
  TransientError? _lastError;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _setDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(widget.autoDismissDuration, () {
      if (mounted) {
        ref.read(widget.authNotifierProvider.notifier).clearTransientError();
      }
    });
  }

  void _dismissBanner() {
    _dismissTimer?.cancel();
    ref.read(widget.authNotifierProvider.notifier).clearTransientError();
  }

  @override
  Widget build(BuildContext context) {
    final transientError = ref.watch(
      widget.authNotifierProvider.select((state) => state.transientError),
    );

    // Return an empty SizedBox when there's no error to show
    if (transientError == null) {
      return const SizedBox.shrink();
    }

    // Reset the timer when the error changes or when no timer is running.
    if (_lastError != transientError || _dismissTimer == null) {
      _lastError = transientError;
      _setDismissTimer();
    }

    return Semantics(
      container: true,
      label: 'Error message: ${transientError.message}',
      liveRegion: true,
      child: SafeArea(
        top: true,
        bottom: false,
        child: AnimatedContainer(
          duration: _TransientErrorBannerTheme.animationDuration,
          curve: Curves.easeInOut,
          height: _TransientErrorBannerTheme.height,
          width: double.infinity,
          color: _TransientErrorBannerTheme.backgroundColor,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  transientError.message,
                  style: _TransientErrorBannerTheme.messageStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _dismissBanner,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
