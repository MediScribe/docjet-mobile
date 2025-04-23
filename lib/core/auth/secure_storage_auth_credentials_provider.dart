import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // Removed - Use String.fromEnvironment

import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';

/// Concrete implementation of [AuthCredentialsProvider] using
/// flutter_secure_storage for JWT and String.fromEnvironment for the API Key.
class SecureStorageAuthCredentialsProvider implements AuthCredentialsProvider {
  final FlutterSecureStorage _secureStorage;
  // final EnvReader _envReader; // Removed

  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';
  static const String _apiKeyEnvVariable =
      'API_KEY'; // Keep variable name for clarity

  // Constructor updated - removed EnvReader dependency
  SecureStorageAuthCredentialsProvider({
    required FlutterSecureStorage secureStorage,
    // EnvReader? envReader, // Removed
  }) : _secureStorage = secureStorage;
  // _envReader = envReader ?? DotEnvReader(); // Removed

  @override
  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: _accessTokenKey);
  }

  @override
  Future<String> getApiKey() async {
    // API Key is now retrieved using compile-time definitions
    const apiKey = String.fromEnvironment(_apiKeyEnvVariable);

    if (apiKey.isEmpty) {
      // Throw a specific exception or handle as appropriate
      // As per spec, API key is mandatory
      throw Exception(
        'API Key not found. Ensure $_apiKeyEnvVariable is provided via --dart-define=API_KEY=YOUR_KEY or --dart-define-from-file=secrets.json',
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
}
