/// Data Transfer Object for parsing the token refresh response from the API
///
/// Maps between the JSON response from the /auth/refresh-session endpoint and
/// a strongly-typed Dart object.
class RefreshResponseDto {
  /// JWT access token for authenticating API requests
  final String accessToken;

  /// Refresh token for obtaining a new access token when it expires
  final String refreshToken;

  /// Creates a [RefreshResponseDto] with the required fields
  const RefreshResponseDto({
    required this.accessToken,
    required this.refreshToken,
  });

  /// Creates a [RefreshResponseDto] from a JSON map
  factory RefreshResponseDto.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'] as String?;
    final refreshToken = json['refresh_token'] as String?;

    if (accessToken == null || accessToken.isEmpty) {
      throw const FormatException(
        'Missing or empty required field "access_token" in RefreshResponseDto JSON',
      );
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const FormatException(
        'Missing or empty required field "refresh_token" in RefreshResponseDto JSON',
      );
    }

    return RefreshResponseDto(
      accessToken: accessToken,
      refreshToken: refreshToken,
      // Note: userId is intentionally ignored as it's not part of the refresh response
    );
  }

  /// Converts this DTO to a JSON map (primarily for debugging/logging)
  Map<String, dynamic> toJson() {
    return {'access_token': accessToken, 'refresh_token': refreshToken};
  }
}
