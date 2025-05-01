import 'package:equatable/equatable.dart';

/// Represents a logged-in user in the domain layer
///
/// This is a pure domain entity with no framework dependencies.
/// It only contains properties that relate to the user's identity.
class User extends Equatable {
  /// Unique identifier for the user (UUID from API)
  final String id;

  /// Creates a new [User] with the provided [id]
  const User({required this.id});

  /// Creates an anonymous placeholder user
  ///
  /// This should be used when we need a valid User object
  /// but don't have the actual user data yet, typically
  /// in transient error scenarios.
  factory User.anonymous() {
    return const User(id: '_anonymous_');
  }

  /// Whether this user is an anonymous placeholder
  bool get isAnonymous => id == '_anonymous_';

  @override
  List<Object> get props => [id];
}
