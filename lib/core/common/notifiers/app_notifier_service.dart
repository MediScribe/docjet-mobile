import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:docjet_mobile/core/common/models/app_message.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

part 'app_notifier_service.g.dart';

/// Notifier service for managing and displaying application-wide transient messages.
///
/// Manages a single [AppMessage] state, replacing the current message
/// when a new one is shown.
@riverpod
class AppNotifierService extends _$AppNotifierService {
  Timer? _dismissTimer;

  final Logger _logger = LoggerFactory.getLogger(AppNotifierService);
  static final String _tag = logTag(AppNotifierService);

  @override
  AppMessage? build() {
    // Ensure the timer is cancelled when the notifier is disposed.
    ref.onDispose(() {
      _logger.d('$_tag Disposing service, cancelling active timers');
      _dismissTimer?.cancel();
    });
    // Start with no message displayed.
    return null;
  }

  /// Shows a notification message, replacing any existing message.
  ///
  /// - [message]: The text content of the notification.
  /// - [type]: The type of notification (info, success, warning, error).
  /// - [duration]: Optional duration after which the message auto-dismisses.
  ///   If null, the message requires manual dismissal via [dismiss].
  ///   If <= 0, throws ArgumentError.
  /// - [id]: Optional unique ID for the message. If null, a UUID is generated.
  void show({
    required String message,
    required MessageType type,
    Duration? duration,
    String? id,
  }) {
    // Cancel any existing timer as a new message is about to be shown.
    _dismissTimer?.cancel();

    // Validate duration if provided
    if (duration != null && duration.inMilliseconds <= 0) {
      final errorMsg =
          'Invalid duration: $duration. Duration must be positive or null.';
      _logger.e('$_tag $errorMsg');
      throw ArgumentError(errorMsg);
    }

    final AppMessage newMessage = AppMessage(
      id: id, // Will be generated if null
      message: message,
      type: type,
      duration: duration,
    );

    _logMessageAction('Showing', newMessage);

    // Update the state to display the new message.
    state = newMessage;

    // If a duration is provided, schedule auto-dismissal.
    if (duration != null) {
      _dismissTimer = Timer(duration, dismiss);
    }
  }

  /// Manually dismisses the currently displayed notification message, if any.
  ///
  /// Cancels any active auto-dismiss timer.
  void dismiss() {
    // Return early if there's no message to dismiss
    if (state == null) return;

    _dismissTimer?.cancel();
    _dismissTimer = null;

    _logMessageAction('Dismissing', state!);
    state = null;
  }

  /// Helper method to log message actions with truncated preview
  void _logMessageAction(String action, AppMessage message) {
    final previewLength = message.message.length.clamp(0, 20).toInt();
    final truncated = message.message.length > 20 ? "..." : "";

    _logger.d(
      '$_tag $action message: "${message.message.substring(0, previewLength)}$truncated" '
      '(${message.type.name}, ${message.duration ?? "manual dismiss"})',
    );
  }
}
