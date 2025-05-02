import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// Enum representing the type of message to be displayed.
enum MessageType { info, success, warning, error }

/// Data class representing a transient message to be displayed to the user.
@immutable
class AppMessage extends Equatable {
  /// A unique identifier for the message. Auto-generated if not provided.
  final String id;

  /// The content of the message to be displayed.
  final String message;

  /// The type of the message, influencing its appearance (e.g., color, icon).
  final MessageType type;

  /// The duration for which the message should be visible.
  /// If null, the message requires manual dismissal.
  final Duration? duration;

  /// Creates an instance of [AppMessage].
  ///
  /// If [id] is not provided, a unique UUID v4 is generated.
  AppMessage({
    String? id,
    required this.message,
    required this.type,
    this.duration,
    // TODO: Consider injecting Uuid as a dependency for easier deterministic testing
  }) : id = id ?? const Uuid().v4();

  @override
  List<Object?> get props => [id, message, type, duration];

  @override
  bool get stringify => true;
}
