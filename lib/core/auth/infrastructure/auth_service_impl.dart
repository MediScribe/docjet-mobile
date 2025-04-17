import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';

/// Implementation of the AuthService interface
///
/// Orchestrates authentication flows by coordinating between
/// the AuthApiClient and AuthCredentialsProvider.
class AuthServiceImpl implements AuthService {
  /// Client for making authentication API requests
  final AuthApiClient apiClient;

  /// Provider for storing and retrieving authentication credentials
  final AuthCredentialsProvider credentialsProvider;

  /// Creates an [AuthServiceImpl] with the required dependencies
  AuthServiceImpl({required this.apiClient, required this.credentialsProvider});

  @override
  Future<User> login(String email, String password) async {
    final authResponse = await apiClient.login(email, password);

    // Store tokens securely
    await credentialsProvider.setAccessToken(authResponse.accessToken);
    await credentialsProvider.setRefreshToken(authResponse.refreshToken);

    // Return a domain entity
    return User(id: authResponse.userId);
  }

  @override
  Future<bool> refreshSession() async {
    // Get the stored refresh token
    final refreshToken = await credentialsProvider.getRefreshToken();

    // Can't refresh without a refresh token
    if (refreshToken == null) {
      return false;
    }

    try {
      // Attempt to refresh the session
      final authResponse = await apiClient.refreshToken(refreshToken);

      // Store the new tokens
      await credentialsProvider.setAccessToken(authResponse.accessToken);
      await credentialsProvider.setRefreshToken(authResponse.refreshToken);

      return true;
    } on AuthException {
      // If token is expired or invalid, refreshing failed
      return false;
    }
  }

  @override
  Future<void> logout() async {
    // Clear stored tokens
    await credentialsProvider.deleteAccessToken();
    await credentialsProvider.deleteRefreshToken();
  }

  @override
  Future<bool> isAuthenticated() async {
    // Check if we have a valid access token
    final accessToken = await credentialsProvider.getAccessToken();
    return accessToken != null;
  }
}
