/// Data Transfer Object for parsing authentication response from the API
///
/// Maps between the JSON response from the auth endpoints and
/// a strongly-typed Dart object.
class LoginResponseDto {
  /// JWT access token for authenticating API requests
  final String accessToken;

  /// Refresh token for obtaining a new access token when it expires
  final String refreshToken;

  /// Unique identifier for the authenticated user
  final String userId;

  /// Creates an [LoginResponseDto] with the required fields
  const LoginResponseDto({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  /// Creates an [LoginResponseDto] from a JSON map
  factory LoginResponseDto.fromJson(Map<String, dynamic> json) {
    return LoginResponseDto(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      userId: json['user_id'] as String,
    );
  }

  /// Converts this DTO to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user_id': userId,
    };
  }
}
