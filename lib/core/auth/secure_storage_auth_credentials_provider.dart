import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';

/// Interface to access environment variables
/// This helps with testing since dotenv is a global object
abstract class EnvReader {
  String? get(String key);
}

/// Default implementation using flutter_dotenv
class DotEnvReader implements EnvReader {
  @override
  String? get(String key) => dotenv.env[key];
}

/// Concrete implementation of [AuthCredentialsProvider] using
/// flutter_secure_storage for JWT and flutter_dotenv for the API Key.
class SecureStorageAuthCredentialsProvider implements AuthCredentialsProvider {
  final FlutterSecureStorage _secureStorage;
  final EnvReader _envReader;

  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';
  static const String _apiKeyEnvVariable = 'API_KEY';

  SecureStorageAuthCredentialsProvider({
    required FlutterSecureStorage secureStorage,
    EnvReader? envReader,
  }) : _secureStorage = secureStorage,
       _envReader = envReader ?? DotEnvReader();

  @override
  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: _accessTokenKey);
  }

  @override
  Future<String> getApiKey() async {
    // Load environment variables. Ensure dotenv.load() is called at app startup.
    final apiKey = _envReader.get(_apiKeyEnvVariable);
    if (apiKey == null || apiKey.isEmpty) {
      // Throw a specific exception or handle as appropriate
      // As per spec, API key is mandatory
      throw Exception(
        'API Key not found in environment variables. Ensure $_apiKeyEnvVariable is set in .env and dotenv.load() was called.',
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
