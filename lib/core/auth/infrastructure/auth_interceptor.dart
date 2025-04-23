import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/config/api_config.dart';

/// Dio interceptor that handles authentication token management
///
/// This interceptor:
/// 1. Automatically adds the access token to requests
/// 2. Detects 401 Unauthorized responses
/// 3. Attempts to refresh the token
/// 4. Retries the original request with the new token
class AuthInterceptor extends Interceptor {
  /// API client for authentication operations
  final AuthApiClient apiClient;

  /// Credentials provider for token management
  final AuthCredentialsProvider credentialsProvider;

  /// Dio instance for retrying requests
  Dio? dio;

  /// Authentication endpoints that don't need tokens
  final List<String> _authEndpoints = [
    ApiConfig.loginEndpoint,
    ApiConfig.refreshEndpoint,
  ];

  /// Creates an [AuthInterceptor] with the required dependencies
  AuthInterceptor({
    required this.apiClient,
    required this.credentialsProvider,
    this.dio,
  });

  /// Adds the access token to authenticated requests
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip authentication for auth endpoints
    if (_isAuthEndpoint(options.path)) {
      return handler.next(options);
    }

    // Get the access token
    final accessToken = await credentialsProvider.getAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    return handler.next(options);
  }

  /// Handles authentication errors (401)
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only handle 401 unauthorized errors
    if (!_isUnauthenticatedError(err)) {
      return handler.next(err);
    }

    // Can't retry without a Dio instance
    if (dio == null) {
      return handler.next(err);
    }

    try {
      // Attempt to refresh the token
      final refreshToken = await credentialsProvider.getRefreshToken();
      if (refreshToken == null) {
        // No refresh token available, can't retry
        return handler.next(err);
      }

      // Get new tokens
      final authResponse = await apiClient.refreshToken(refreshToken);

      // Store the new tokens
      await credentialsProvider.setAccessToken(authResponse.accessToken);
      await credentialsProvider.setRefreshToken(authResponse.refreshToken);

      // Clone the original request
      final options = err.requestOptions;

      // Update the authorization header with the new token
      options.headers['Authorization'] = 'Bearer ${authResponse.accessToken}';

      // Retry the request with the new token
      final response = await dio!.fetch(options);

      // Return the response from the retried request
      return handler.resolve(response);
    } on AuthException {
      // Token refresh failed, propagate the original error
      return handler.next(err);
    } catch (e) {
      // Unexpected error during refresh, propagate the original error
      return handler.next(err);
    }
  }

  /// Checks if the path corresponds to an authentication endpoint
  bool _isAuthEndpoint(String path) {
    return _authEndpoints.any((endpoint) => path.contains(endpoint));
  }

  /// Checks if the error is a 401 Unauthorized error
  bool _isUnauthenticatedError(DioException err) {
    return err.response?.statusCode == 401;
  }
}
