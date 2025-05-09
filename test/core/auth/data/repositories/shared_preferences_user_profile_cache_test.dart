import 'dart:convert';

import 'package:docjet_mobile/core/auth/data/repositories/shared_preferences_user_profile_cache.dart';
import 'package:docjet_mobile/core/auth/domain/repositories/i_user_profile_cache.dart';
import 'package:docjet_mobile/core/user/infrastructure/dtos/user_profile_dto.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Generate mocks for SharedPreferences
@GenerateMocks([SharedPreferences])
import 'shared_preferences_user_profile_cache_test.mocks.dart';

void main() {
  late MockSharedPreferences mockSharedPreferences;
  late IUserProfileCache cache;
  late UserProfileDto testProfileDto;
  const testUserId = 'user123';
  final testTimestamp = DateTime(2024, 1, 1, 12, 0, 0);
  const profileKeyPrefix = 'cached_profile_';
  const timestampKeySuffix = '_timestamp';

  // Helper function to generate expected keys
  String profileKey(String userId) => '$profileKeyPrefix$userId';
  String timestampKey(String userId) =>
      '${profileKey(userId)}$timestampKeySuffix';

  setUp(() {
    // Initialize mocks and the cache instance before each test
    mockSharedPreferences = MockSharedPreferences();
    final logger = LoggerFactory.getLogger(
      'SharedPreferencesUserProfileCacheTest',
    );
    cache = SharedPreferencesUserProfileCache(mockSharedPreferences, logger);

    // Sample UserProfileDto for testing
    testProfileDto = const UserProfileDto(
      id: testUserId,
      email: 'test@example.com',
      name: 'Test User',
      settings: {'theme': 'dark'},
    );
  });

  group('SharedPreferencesUserProfileCache', () {
    group('saveProfile', () {
      test('should save profile DTO and timestamp correctly', () async {
        // Arrange
        final profileJson = jsonEncode(testProfileDto.toJson());
        final timestampString = testTimestamp.toIso8601String();
        final expectedProfileKey = profileKey(testUserId);
        final expectedTimestampKey = timestampKey(testUserId);

        when(
          mockSharedPreferences.setString(expectedProfileKey, profileJson),
        ).thenAnswer((_) async => true);
        when(
          mockSharedPreferences.setString(
            expectedTimestampKey,
            timestampString,
          ),
        ).thenAnswer((_) async => true);

        // Act
        await cache.saveProfile(testProfileDto, testTimestamp);

        // Assert
        verify(
          mockSharedPreferences.setString(expectedProfileKey, profileJson),
        ).called(1);
        verify(
          mockSharedPreferences.setString(
            expectedTimestampKey,
            timestampString,
          ),
        ).called(1);
        verifyNoMoreInteractions(mockSharedPreferences);
      });
    });

    group('getProfile', () {
      test('should return profile DTO when found in cache', () async {
        // Arrange
        final profileJson = jsonEncode(testProfileDto.toJson());
        final expectedProfileKey = profileKey(testUserId);
        when(
          mockSharedPreferences.getString(expectedProfileKey),
        ).thenReturn(profileJson);

        // Act
        final result = await cache.getProfile(testUserId);

        // Assert
        expect(result, equals(testProfileDto));
        verify(mockSharedPreferences.getString(expectedProfileKey)).called(1);
        verifyNoMoreInteractions(mockSharedPreferences);
      });

      test('should return null when profile not found in cache', () async {
        // Arrange
        final expectedProfileKey = profileKey(testUserId);
        when(
          mockSharedPreferences.getString(expectedProfileKey),
        ).thenReturn(null);

        // Act
        final result = await cache.getProfile(testUserId);

        // Assert
        expect(result, isNull);
        verify(mockSharedPreferences.getString(expectedProfileKey)).called(1);
        verifyNoMoreInteractions(mockSharedPreferences);
      });

      test('should return null when JSON decoding fails', () async {
        // Arrange
        const invalidJson = '{ invalid json';
        final expectedProfileKey = profileKey(testUserId);
        when(
          mockSharedPreferences.getString(expectedProfileKey),
        ).thenReturn(invalidJson);

        // Act
        final result = await cache.getProfile(testUserId);

        // Assert
        expect(result, isNull);
        verify(mockSharedPreferences.getString(expectedProfileKey)).called(1);
        verifyNoMoreInteractions(mockSharedPreferences);
        // We might want to check for log output here in a real scenario
      });
    });

    group('clearProfile', () {
      test('should remove profile and timestamp keys', () async {
        // Arrange
        final expectedProfileKey = profileKey(testUserId);
        final expectedTimestampKey = timestampKey(testUserId);
        when(
          mockSharedPreferences.remove(expectedProfileKey),
        ).thenAnswer((_) async => true);
        when(
          mockSharedPreferences.remove(expectedTimestampKey),
        ).thenAnswer((_) async => true);

        // Act
        await cache.clearProfile(testUserId);

        // Assert
        verify(mockSharedPreferences.remove(expectedProfileKey)).called(1);
        verify(mockSharedPreferences.remove(expectedTimestampKey)).called(1);
        verifyNoMoreInteractions(mockSharedPreferences);
      });
    });

    group('clearAllProfiles', () {
      test('should remove all keys starting with the profile prefix', () async {
        // Arrange
        final keys = {
          profileKey('user1'),
          timestampKey('user1'),
          profileKey('user2'),
          timestampKey('user2'),
          'other_key', // Should not be removed
        };
        when(mockSharedPreferences.getKeys()).thenReturn(keys);
        // Mock remove for each key that should be removed
        when(
          mockSharedPreferences.remove(profileKey('user1')),
        ).thenAnswer((_) async => true);
        when(
          mockSharedPreferences.remove(timestampKey('user1')),
        ).thenAnswer((_) async => true);
        when(
          mockSharedPreferences.remove(profileKey('user2')),
        ).thenAnswer((_) async => true);
        when(
          mockSharedPreferences.remove(timestampKey('user2')),
        ).thenAnswer((_) async => true);
        // Ensure 'other_key' is NOT removed
        when(
          mockSharedPreferences.remove('other_key'),
        ).thenThrow(Exception('Should not be called'));

        // Act
        await cache.clearAllProfiles();

        // Assert
        verify(mockSharedPreferences.getKeys()).called(1);
        verify(mockSharedPreferences.remove(profileKey('user1'))).called(1);
        verify(mockSharedPreferences.remove(timestampKey('user1'))).called(1);
        verify(mockSharedPreferences.remove(profileKey('user2'))).called(1);
        verify(mockSharedPreferences.remove(timestampKey('user2'))).called(1);
        // Verify that remove was NOT called for 'other_key'
        verifyNever(mockSharedPreferences.remove('other_key'));
        verifyNoMoreInteractions(mockSharedPreferences);
      });
    });

    group('isProfileStale', () {
      // Helper to mock timestamp retrieval

      test(
        'should return true if both tokens are invalid, regardless of timestamp',
        () async {
          // Arrange
          // No need to mock timestamp as it shouldn't be checked

          // Act
          final isStale = await cache.isProfileStale(
            testUserId,
            isAccessTokenValid: false,
            isRefreshTokenValid: false,
          );

          // Assert
          expect(isStale, isTrue);
          // Timestamp SHOULD NOT be checked if tokens are invalid
          verifyNever(
            mockSharedPreferences.getString(timestampKey(testUserId)),
          );
          verifyNoMoreInteractions(mockSharedPreferences);
        },
      );

      test('should return false if access token is valid', () async {
        // Act
        final isStale = await cache.isProfileStale(
          testUserId,
          isAccessTokenValid: true,
          isRefreshTokenValid: false,
        );
        // Assert
        expect(isStale, isFalse);
        verifyNever(mockSharedPreferences.getString(timestampKey(testUserId)));
      });

      test('should return false if refresh token is valid', () async {
        // Act
        final isStale = await cache.isProfileStale(
          testUserId,
          isAccessTokenValid: false,
          isRefreshTokenValid: true,
        );
        // Assert
        expect(isStale, isFalse);
        verifyNever(mockSharedPreferences.getString(timestampKey(testUserId)));
      });

      test('should return false if both tokens are valid', () async {
        // Act
        final isStale = await cache.isProfileStale(
          testUserId,
          isAccessTokenValid: true,
          isRefreshTokenValid: true,
        );
        // Assert
        expect(isStale, isFalse);
        verifyNever(mockSharedPreferences.getString(timestampKey(testUserId)));
      });
    });
  });
}
