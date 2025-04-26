import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
// TODO: Import UserProfileDto when created
// import 'package:docjet_mobile/core/auth/infrastructure/dtos/user_profile_dto.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'dart:io'; // For SocketException

/// Client responsible for communication with authentication-related API endpoints.
///
/// Handles the low-level HTTP details and error mapping specific to auth operations.
/// **Important:** This client relies on the injected [Dio] instance (`httpClient`)
/// having the necessary interceptors configured (e.g., via [DioFactory])
/// to handle tasks like adding the `x-api-key` header and managing
/// access token injection and refresh via [AuthInterceptor]. It does NOT
/// handle these concerns directly.
class AuthApiClient {
  /// Base API client, expected to be pre-configured with necessary interceptors
  /// (e.g., API key, token refresh).
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
      final response = await httpClient.post(
        ApiConfig.loginEndpoint,
        data: {'email': email, 'password': password},
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
      final response = await httpClient.post(
        ApiConfig.refreshEndpoint,
        data: {'refreshToken': refreshToken},
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
      // Assuming access token is handled by an interceptor adding Authorization header

      /* final response = */
      await httpClient.get(
        ApiConfig.userProfileEndpoint, // Use the constant
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
    final hasApiKey = e.requestOptions.headers.containsKey('x-api-key');
    final isRefreshEndpoint = requestPath.contains(ApiConfig.refreshEndpoint);
    final isProfileEndpoint = requestPath.contains(
      ApiConfig.userProfileEndpoint,
    );
    final stackTrace = e.stackTrace;

    // Handle response errors (status codes)
    if (e.response != null) {
      final statusCode = e.response!.statusCode ?? 0;

      // Use the unified status code handler
      return AuthException.fromStatusCode(
        statusCode,
        requestPath,
        hasApiKey: hasApiKey,
        isRefreshEndpoint: isRefreshEndpoint,
        isProfileEndpoint: isProfileEndpoint,
        stackTrace: stackTrace,
      );
    }

    // Handle non-response errors (network, timeout, etc.)
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AuthException.networkError(requestPath, stackTrace);

      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return AuthException.offlineOperationFailed(stackTrace);
        }
        // Treat other connection/unknown errors as generic network errors
        return AuthException.networkError(requestPath, stackTrace);

      case DioExceptionType.cancel:
        // Request was cancelled, typically not a server/network issue
        return AuthException.networkError(requestPath, stackTrace);

      case DioExceptionType.badCertificate:
        return AuthException.networkError(requestPath, stackTrace);

      case DioExceptionType.badResponse:
        // This case should ideally be handled by the status code checks above,
        // but can act as a fallback.
        if (isProfileEndpoint) {
          return AuthException.userProfileFetchFailed(stackTrace);
        }
        return AuthException.serverError(0, requestPath, stackTrace);
    }
  }

  // --- Test Helper ---
  @visibleForTesting
  void testHandleDioException(DioException e) {
    throw _handleDioException(e);
  }
}
