import 'package:rxdart/rxdart.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';

/// A simple event bus for broadcasting authentication-related events.
///
/// Uses a [PublishSubject] from `rxdart` to allow multiple listeners.
/// Ensure [dispose] is called when the bus is no longer needed to release resources.
class AuthEventBus {
  final _eventSubject = PublishSubject<AuthEvent>();

  /// The stream of authentication events.
  ///
  /// Listeners can subscribe to this stream to react to auth changes.
  Stream<AuthEvent> get stream => _eventSubject.stream;

  /// Adds an authentication event to the stream.
  ///
  /// Any active listeners will receive this event.
  void add(AuthEvent event) {
    _eventSubject.add(event);
  }

  /// Closes the event stream.
  ///
  /// Should be called to release resources when the event bus is no longer needed,
  /// typically when the application or relevant scope is disposed.
  void dispose() {
    _eventSubject.close();
  }
}
