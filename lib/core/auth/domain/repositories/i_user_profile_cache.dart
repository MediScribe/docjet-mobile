import 'package:docjet_mobile/core/user/infrastructure/dtos/user_profile_dto.dart';

/// Interface for caching user profile data locally.
abstract class IUserProfileCache {
  /// Saves the user profile DTO along with a timestamp.
  Future<void> saveProfile(UserProfileDto profileDto, DateTime timestamp);

  /// Retrieves the cached user profile DTO for the given user ID.
  /// Returns null if no profile is found.
  Future<UserProfileDto?> getProfile(String userId);

  /// Removes the cached profile for the specified user ID.
  Future<void> clearProfile(String userId);

  /// Removes all cached user profiles.
  Future<void> clearAllProfiles();

  /// Checks if the cached profile for the user is stale.
  ///
  /// Staleness can be determined by:
  /// 1. The validity of the access and refresh tokens. If both are invalid, the profile is stale.
  /// 2. An optional maximum age (`maxAge`). If the profile is older than `maxAge`, it's stale.
  ///
  /// Returns `true` if the profile is considered stale, `false` otherwise.
  Future<bool> isProfileStale(
    String userId, {
    required bool isAccessTokenValid,
    required bool isRefreshTokenValid,
    Duration? maxAge,
  });
}
