import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'dart:math';

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
  final Dio dio;

  /// Event bus for authentication events
  final AuthEventBus authEventBus;

  /// Authentication endpoints that don't need tokens
  final List<String> _authEndpoints = [
    ApiConfig.loginEndpoint,
    ApiConfig.refreshEndpoint,
  ];

  /// Creates an [AuthInterceptor] with the required dependencies
  AuthInterceptor({
    required this.apiClient,
    required this.credentialsProvider,
    required this.dio,
    required this.authEventBus,
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

    // FINDINGS: Implemented retry logic with exponential backoff
    // and forced logout on irrecoverable errors.
    int retryCount = 0;
    const maxRetries = 3;
    const initialDelayMs = 500;

    while (retryCount < maxRetries) {
      try {
        // Attempt to refresh the token
        final refreshToken = await credentialsProvider.getRefreshToken();
        if (refreshToken == null) {
          // No refresh token available, can't retry
          // FINDINGS: Fire logout event as this is irrecoverable
          authEventBus.add(AuthEvent.loggedOut);
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
        // FINDINGS: Use the injected Dio instance directly
        final response = await dio.fetch(options);

        // Return the response from the retried request
        return handler.resolve(response);
      } on AuthException catch (e) {
        // Check if the exception is recoverable (e.g., network error)
        if (e == AuthException.networkError() && retryCount < maxRetries - 1) {
          retryCount++;
          final delay = Duration(
            milliseconds: initialDelayMs * pow(2, retryCount - 1).toInt(),
          );
          await Future.delayed(delay);
        } else {
          // Irrecoverable AuthException (e.g., refreshTokenInvalid, etc.)
          // or max retries reached for network error.
          // FINDINGS: Fire logout event
          authEventBus.add(AuthEvent.loggedOut);
          return handler.next(err);
        }
      } catch (e) {
        // Unexpected error during refresh, propagate the original error
        // Treat other errors as potentially transient for retry purposes?
        // For now, let's assume unexpected errors are not recoverable here.
        // TODO: Re-evaluate if other exception types should trigger retries
        return handler.next(err);
      }
    }

    // If loop completes (max retries reached), propagate the original error
    return handler.next(err);
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
