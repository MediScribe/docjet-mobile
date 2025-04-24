import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
// TODO: Import UserProfileDto when created
// import 'package:docjet_mobile/core/auth/infrastructure/dtos/user_profile_dto.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'dart:io'; // For SocketException

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
    // TODO: Return UserProfileDto when implemented
    try {
      final apiKey = await credentialsProvider.getApiKey();
      // Assuming access token is handled by an interceptor adding Authorization header

      /* final response = */
      await httpClient.get(
        ApiConfig.userProfileEndpoint, // Use the constant
        options: Options(headers: {'x-api-key': apiKey}),
      );

      // TODO: return UserProfileDto.fromJson(response.data);
      return; // Placeholder return until UserProfileDto is ready
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Maps DioException to domain-specific AuthException
  AuthException _handleDioException(DioException e) {
    final requestPath = e.requestOptions.path;

    // Handle response errors (status codes)
    if (e.response != null) {
      final statusCode = e.response!.statusCode;

      switch (statusCode) {
        case 401:
          if (requestPath.contains(ApiConfig.refreshEndpoint)) {
            return AuthException.refreshTokenInvalid();
          }
          if (requestPath.contains(ApiConfig.userProfileEndpoint)) {
            // If 401 occurs on profile endpoint, assume token invalid/expired
            // (interceptor should have handled refresh)
            return AuthException.userProfileFetchFailed();
          }
          // Default 401 assumed to be login failure
          return AuthException.invalidCredentials();
        case 403:
          // 403 is generally an authorization issue, regardless of path
          return AuthException.unauthorizedOperation();
        // Handle common server errors specifically for profile fetch
        case 500:
        case 502:
        case 503:
        case 504:
          if (requestPath.contains(ApiConfig.userProfileEndpoint)) {
            return AuthException.userProfileFetchFailed();
          }
          // For other endpoints, map to generic server error
          return AuthException.serverError(statusCode ?? 0);
        default:
          // Fallback for unexpected status codes
          if (requestPath.contains(ApiConfig.userProfileEndpoint)) {
            return AuthException.userProfileFetchFailed();
          }
          // Use 0 if statusCode is null, though it shouldn't be in a response error
          return AuthException.serverError(statusCode ?? 0);
      }
    }

    // Handle non-response errors (network, timeout, etc.)
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AuthException.networkError();
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return AuthException.offlineOperationFailed();
        }
        // Treat other connection/unknown errors as generic network errors
        return AuthException.networkError();
      case DioExceptionType.cancel:
        // Request was cancelled, typically not a server/network issue
        // Might need a specific exception type if cancellation needs special handling
        return AuthException.networkError(); // Treat as network error for now
      case DioExceptionType.badCertificate:
        return AuthException.networkError(); // Treat as network error
      case DioExceptionType.badResponse:
        // This case should ideally be handled by the status code checks above,
        // but can act as a fallback.
        if (requestPath.contains(ApiConfig.userProfileEndpoint)) {
          return AuthException.userProfileFetchFailed();
        }
        return AuthException.serverError(0); // Use 0 as status code is unknown
    }
  }

  // --- Test Helper ---
  @visibleForTesting
  void testHandleDioException(DioException e) {
    throw _handleDioException(e);
  }
}
