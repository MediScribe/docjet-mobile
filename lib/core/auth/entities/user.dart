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

  @override
  List<Object> get props => [id];
}
