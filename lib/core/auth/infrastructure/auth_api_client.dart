import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';

/// Client responsible for communication with authentication-related API endpoints
///
/// Handles the low-level HTTP details and error mapping specific to auth operations.
class AuthApiClient {
  /// Base API client
  final Dio httpClient;

  /// Provider for API key and tokens
  final AuthCredentialsProvider credentialsProvider;

  /// Login endpoint path
  static const String _loginEndpoint = '/api/v1/auth/login';

  /// Refresh token endpoint path
  static const String _refreshEndpoint = '/api/v1/auth/refresh-session';

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
        _loginEndpoint,
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
        _refreshEndpoint,
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'x-api-key': apiKey}),
      );

      return AuthResponseDto.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Maps DioException to domain-specific AuthException
  AuthException _handleDioException(DioException e) {
    // Handle response errors
    if (e.response != null) {
      final statusCode = e.response!.statusCode;

      if (statusCode == 401) {
        // For login endpoint, it's invalid credentials
        // For refresh endpoint, it's an expired token
        if (e.requestOptions.path.contains(_refreshEndpoint)) {
          return AuthException.tokenExpired();
        }
        return AuthException.invalidCredentials();
      }

      // Other server errors
      return AuthException.serverError(statusCode ?? 500);
    }

    // Handle network and connection errors
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return AuthException.networkError();
    }

    // Default fallback for unexpected errors
    return AuthException.serverError(500);
  }
}
