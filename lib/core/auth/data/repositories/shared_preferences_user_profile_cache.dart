import 'dart:convert';

import 'package:docjet_mobile/core/auth/domain/repositories/i_user_profile_cache.dart';
import 'package:docjet_mobile/core/user/infrastructure/dtos/user_profile_dto.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesUserProfileCache implements IUserProfileCache {
  final SharedPreferences _prefs;
  final Logger _logger;

  static const _profileKeyPrefix = 'cached_profile_';
  static const _timestampKeySuffix = '_timestamp';

  SharedPreferencesUserProfileCache(this._prefs, this._logger);

  String _profileKey(String userId) => '$_profileKeyPrefix$userId';
  String _timestampKey(String userId) =>
      '${_profileKey(userId)}$_timestampKeySuffix';

  @override
  Future<void> saveProfile(
    UserProfileDto profileDto,
    DateTime timestamp,
  ) async {
    final userId = profileDto.id;
    final profileJson = jsonEncode(profileDto.toJson());
    final timestampString = timestamp.toIso8601String();
    final pKey = _profileKey(userId);
    final tKey = _timestampKey(userId);

    try {
      await _prefs.setString(pKey, profileJson);
      await _prefs.setString(tKey, timestampString);
      _logger.d('Saved profile for user $userId at $timestampString');
    } catch (e, s) {
      _logger.e(
        'Failed to save profile for user $userId',
        error: e,
        stackTrace: s,
      );
      // Decide if we should rethrow or handle gracefully
    }
  }

  @override
  Future<UserProfileDto?> getProfile(String userId) async {
    final pKey = _profileKey(userId);
    try {
      final profileJson = _prefs.getString(pKey);
      if (profileJson != null) {
        final profileMap = jsonDecode(profileJson) as Map<String, dynamic>;
        final dto = UserProfileDto.fromJson(profileMap);
        _logger.d('Retrieved cached profile for user $userId');
        return dto;
      } else {
        _logger.d('No cached profile found for user $userId');
        return null;
      }
    } catch (e, s) {
      _logger.e(
        'Failed to retrieve or decode profile for user $userId',
        error: e,
        stackTrace: s,
      );
      // If decoding fails, it's like it wasn't there. Clear potentially corrupt data?
      // await clearProfile(userId); // Optional: Be aggressive?
      return null;
    }
  }

  @override
  Future<void> clearProfile(String userId) async {
    final pKey = _profileKey(userId);
    final tKey = _timestampKey(userId);
    try {
      await _prefs.remove(pKey);
      await _prefs.remove(tKey);
      _logger.d('Cleared cached profile for user $userId');
    } catch (e, s) {
      _logger.e(
        'Failed to clear profile for user $userId',
        error: e,
        stackTrace: s,
      );
    }
  }

  @override
  Future<void> clearAllProfiles() async {
    try {
      final keys = _prefs.getKeys();
      final profileKeysToRemove = keys.where(
        (key) => key.startsWith(_profileKeyPrefix),
      );

      for (final key in profileKeysToRemove) {
        await _prefs.remove(key);
      }
      _logger.d(
        'Cleared all cached user profiles (${profileKeysToRemove.length} keys removed).',
      );
    } catch (e, s) {
      _logger.e('Failed to clear all profiles', error: e, stackTrace: s);
    }
  }

  @override
  Future<bool> isProfileStale(
    String userId, {
    required bool isAccessTokenValid,
    required bool isRefreshTokenValid,
  }) async {
    // Rule 1: If both tokens are invalid, it's definitely stale.
    if (!isAccessTokenValid && !isRefreshTokenValid) {
      _logger.i('Profile for $userId stale: Both tokens invalid.');
      return true;
    }

    // If we reach here, at least one token is valid.
    _logger.d('Profile for $userId is not stale.');
    return false;
  }
}
