import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter/foundation.dart';

/// Client responsible for communication with authentication-related API endpoints
///
/// Handles the low-level HTTP details and error mapping specific to auth operations.
class AuthApiClient {
  /// Base API client
  final Dio httpClient;

  /// Provider for API key and tokens
  final AuthCredentialsProvider credentialsProvider;

  /// Creates an [AuthApiClient] with the required dependencies
  AuthApiClient({required this.httpClient, required this.credentialsProvider});

  /// Authenticates a user with email and password
  ///
  /// Returns [AuthResponseDto] with tokens and user ID on success.
  /// Throws [AuthException] if authentication fails.
  Future<AuthResponseDto> login(String email, String password) async {
    try {
      final apiKey = await credentialsProvider.getApiKey();

      final response = await httpClient.post(
        ApiConfig.loginEndpoint,
        data: {'email': email, 'password': password},
        options: Options(headers: {'x-api-key': apiKey}),
      );

      return AuthResponseDto.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Refreshes the authentication session using a refresh token
  ///
  /// Returns [AuthResponseDto] with new tokens and user ID on success.
  /// Throws [AuthException] if refresh fails.
  Future<AuthResponseDto> refreshToken(String refreshToken) async {
    try {
      final apiKey = await credentialsProvider.getApiKey();

      final response = await httpClient.post(
        ApiConfig.refreshEndpoint,
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'x-api-key': apiKey}),
      );

      return AuthResponseDto.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Retrieves the current user's profile information
  ///
  /// Returns UserProfileDto on success.
  /// Throws [AuthException] if fetching fails or user is unauthorized.
  Future<void> getUserProfile() async {
    // TODO: Return UserProfileDto
    try {
      final apiKey = await credentialsProvider.getApiKey();
      // Assuming access token is handled by an interceptor

      // TODO: Implement UserProfileDto
      /* final response = */
      await httpClient.get(
        ApiConfig.userProfileEndpoint, // Use config constant
        options: Options(headers: {'x-api-key': apiKey}),
      );

      // TODO: return UserProfileDto.fromJson(response.data);
      return; // Placeholder return
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Maps DioException to domain-specific AuthException
  AuthException _handleDioException(DioException e) {
    // Handle response errors
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final path = e.requestOptions.path;

      // Use ApiConfig constant
      const profileEndpoint = ApiConfig.userProfileEndpoint;

      switch (statusCode) {
        case 401:
          if (path.contains(ApiConfig.refreshEndpoint)) {
            return AuthException.refreshTokenInvalid();
          }
          // Could add check here if path == profileEndpoint later for specific 401 on profile
          return AuthException.invalidCredentials(); // Default for login/other 401s
        case 403:
          // Could add check here if path == profileEndpoint for specific 403 on profile
          return AuthException.unauthorizedOperation();
        case 500:
        case 503:
        // Add other server-side error codes as needed
        default:
          // Check if the error occurred on the profile endpoint path
          if (path.contains(profileEndpoint)) {
            return AuthException.userProfileFetchFailed();
          }
          return AuthException.serverError(statusCode ?? 500);
      }
    }

    // Handle network and connection errors
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return AuthException.networkError();
    }

    // Check for specific offline indicators
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      // Simple check for common offline error message
      // TODO: Improve offline detection (e.g., use connectivity package)
      if (e.message != null && e.message!.contains('SocketException')) {
        return AuthException.offlineOperationFailed();
      }
      return AuthException.networkError(); // Treat other connection errors as network issues
    }

    // Default fallback for unexpected errors (e.g., cancellation)
    return AuthException.serverError(500); // Or a more generic unknown error
  }

  // --- Test Helper ---
  // Re-added testHandleDioException method
  // Exposes the private method for testing purposes.
  // TODO: Revisit removing this if possible.
  @visibleForTesting
  void testHandleDioException(DioException e) {
    throw _handleDioException(e);
  }
}
