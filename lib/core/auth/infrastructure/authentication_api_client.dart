import 'dart:io'; // For SocketException

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter/foundation.dart';

/// Client responsible for authentication-specific API operations.
///
/// Handles login and token refresh operations using non-authenticated requests.
/// This client uses basicDio without authentication interceptors since these
/// endpoints don't require authentication (they establish it).
///
/// **Important:** This client handles the API operations needed before authentication
/// is established and is intentionally separate from UserApiClient which handles
/// authenticated endpoints.
class AuthenticationApiClient {
  /// Basic API client without auth interceptors, used for login and refresh
  final Dio basicHttpClient;

  /// Provider for API key and tokens
  final AuthCredentialsProvider credentialsProvider;

  /// Creates an [AuthenticationApiClient] with the required dependencies
  AuthenticationApiClient({
    required this.basicHttpClient,
    required this.credentialsProvider,
  });

  /// Authenticates a user with email and password
  ///
  /// Returns [AuthResponseDto] with tokens and user ID on success.
  /// Throws [AuthException] if authentication fails.
  Future<AuthResponseDto> login(String email, String password) async {
    try {
      final response = await basicHttpClient.post(
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
      final response = await basicHttpClient.post(
        ApiConfig.refreshEndpoint,
        data: {'refresh_token': refreshToken},
      );

      return AuthResponseDto.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Maps DioException to domain-specific AuthException
  AuthException _handleDioException(DioException e) {
    final requestPath = e.requestOptions.path;
    final hasApiKey = e.requestOptions.headers.containsKey('x-api-key');
    final isRefreshEndpoint = requestPath.contains(ApiConfig.refreshEndpoint);
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
        isProfileEndpoint: false, // This client never handles profile
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
        return AuthException.serverError(0, requestPath, stackTrace);
    }
  }

  // --- Test Helper ---
  @visibleForTesting
  void testHandleDioException(DioException e) {
    throw _handleDioException(e);
  }
}
