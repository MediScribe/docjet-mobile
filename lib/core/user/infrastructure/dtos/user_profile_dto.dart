import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_profile_dto.g.dart';

/// Data Transfer Object for user profile data from the API
@JsonSerializable()
class UserProfileDto extends Equatable {
  /// User ID
  final String id;

  /// User's email address
  final String email;

  /// User's display name
  final String? name;

  /// User's settings (optional)
  final Map<String, dynamic>? settings;

  /// Creates a new UserProfileDto
  const UserProfileDto({
    required this.id,
    required this.email,
    this.name,
    this.settings,
  });

  /// Creates a UserProfileDto from JSON
  factory UserProfileDto.fromJson(Map<String, dynamic> json) =>
      _$UserProfileDtoFromJson(json);

  /// Converts this UserProfileDto to JSON
  Map<String, dynamic> toJson() => _$UserProfileDtoToJson(this);

  @override
  List<Object?> get props => [id, email, name, settings];
}
