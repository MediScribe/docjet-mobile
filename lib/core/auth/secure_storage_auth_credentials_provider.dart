import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart'; // For PlatformException

import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart';
import 'package:docjet_mobile/core/config/app_config.dart';

/// Concrete implementation of [AuthCredentialsProvider] using
/// `flutter_secure_storage` for JWT storage and `AppConfig` for API key retrieval.
///
/// IMPORTANT: Configuration values like API keys should be accessed via
/// `AppConfig` (provided through DI) rather than compile-time environment
/// variables (`String.fromEnvironment`) to ensure consistency across different
/// build configurations (e.g., main_dev.dart overrides).
class SecureStorageAuthCredentialsProvider implements AuthCredentialsProvider {
  final FlutterSecureStorage _secureStorage;
  final JwtValidator _jwtValidator;
  final AppConfig _appConfig;

  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';
  static const String _userIdKey = 'userId'; // Added key for user ID
  // Keep variable name for clarity

  // Constructor updated - removed EnvReader dependency and added JwtValidator dependency
  SecureStorageAuthCredentialsProvider({
    required FlutterSecureStorage secureStorage,
    required JwtValidator jwtValidator,
    required AppConfig appConfig,
  }) : _secureStorage = secureStorage,
       _jwtValidator = jwtValidator,
       _appConfig = appConfig;

  @override
  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: _accessTokenKey);
  }

  @override
  Future<String> getApiKey() async {
    // API Key is now retrieved using AppConfig
    final apiKey = _appConfig.apiKey;

    if (apiKey.isEmpty) {
      // Throw a specific exception if API key is missing from AppConfig
      throw Exception(
        'API Key not found in AppConfig. Ensure AppConfig is correctly configured.',
      );
    }
    return apiKey;
  }

  /// Stores the access token securely.
  @override
  Future<void> setAccessToken(String token) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);
  }

  /// Deletes the access token from secure storage.
  @override
  Future<void> deleteAccessToken() async {
    await _secureStorage.delete(key: _accessTokenKey);
  }

  @override
  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> setRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<void> deleteRefreshToken() async {
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  /// Stores the user ID securely.
  @override
  Future<void> setUserId(String userId) async {
    await _secureStorage.write(key: _userIdKey, value: userId);
  }

  /// Retrieves the stored user ID.
  @override
  Future<String?> getUserId() async {
    return _secureStorage.read(key: _userIdKey);
  }

  @override
  Future<bool> isAccessTokenValid() async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return false;
      }
      final isExpired = _jwtValidator.isTokenExpired(token);
      return !isExpired;
    } on PlatformException {
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isRefreshTokenValid() async {
    try {
      final token = await getRefreshToken();
      if (token == null) {
        return false;
      }
      final isExpired = _jwtValidator.isTokenExpired(token);
      return !isExpired;
    } on PlatformException {
      return false;
    } catch (e) {
      return false;
    }
  }
}
