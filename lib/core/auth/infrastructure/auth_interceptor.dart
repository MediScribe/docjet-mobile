import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'dart:math';
import 'package:mutex/mutex.dart';

/// Dio interceptor that handles authentication token management
///
/// This interceptor:
/// 1. Automatically adds the access token to requests
/// 2. Detects 401 Unauthorized responses
/// 3. Attempts to refresh the token
/// 4. Retries the original request with the new token
/// 5. Implements exponential backoff for network errors
/// 6. Triggers logout events for irrecoverable auth errors
/// 7. Uses mutex to prevent concurrent refresh attempts
class AuthInterceptor extends Interceptor {
  /// Function to call for token refresh operations
  /// This breaks the circular dependency with AuthApiClient
  final Future<AuthResponseDto> Function(String) _refreshTokenFunction;

  /// Credentials provider for token management
  final AuthCredentialsProvider credentialsProvider;

  /// Dio instance for retrying requests
  final Dio dio;

  /// Event bus for authentication events
  final AuthEventBus authEventBus;

  /// Mutex lock to prevent concurrent token refresh attempts
  final Mutex _lock = Mutex();

  /// Authentication endpoints that don't need tokens
  final List<String> _authEndpoints = [
    ApiConfig.loginEndpoint,
    ApiConfig.refreshEndpoint,
  ];

  /// Maximum number of retry attempts for token refresh
  static const int _maxRetries = 3;

  /// Initial delay in milliseconds for exponential backoff
  static const int _initialDelayMs = 500;

  /// Creates an [AuthInterceptor] with the required dependencies
  ///
  /// Uses a function-based approach for token refresh to break circular dependencies.
  /// The [refreshTokenFunction] should typically point to AuthApiClient.refreshToken.
  AuthInterceptor({
    required Future<AuthResponseDto> Function(String) refreshTokenFunction,
    required this.credentialsProvider,
    required this.dio,
    required this.authEventBus,
  }) : _refreshTokenFunction = refreshTokenFunction;

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

    // Use mutex to prevent concurrent refresh attempts
    await _lock.acquire();
    try {
      int retryCount = 0;

      while (retryCount < _maxRetries) {
        try {
          // Attempt to refresh the token
          final refreshToken = await credentialsProvider.getRefreshToken();
          if (refreshToken == null) {
            // No refresh token available, can't retry
            _triggerLogout();
            return handler.next(err);
          }

          // Get new tokens using the provided function instead of direct dependency
          final authResponse = await _refreshTokenFunction(refreshToken);

          // Store the new tokens
          await credentialsProvider.setAccessToken(authResponse.accessToken);
          await credentialsProvider.setRefreshToken(authResponse.refreshToken);

          // Retry the original request with the new token
          final response = await _retryRequestWithNewToken(
            err.requestOptions,
            authResponse.accessToken,
          );

          // Return the response from the retried request
          return handler.resolve(response);
        } on AuthException catch (e) {
          if (_shouldRetryError(e, retryCount)) {
            // Apply exponential backoff for network errors
            await _applyBackoff(++retryCount);
          } else {
            // Irrecoverable auth error or max retries reached
            _triggerLogout();
            return handler.next(err);
          }
        } catch (e) {
          // Unexpected error during refresh
          // Create a new DioException to properly propagate the actual error
          final newError = DioException(
            requestOptions: err.requestOptions,
            error: e,
            message: 'Error during token refresh: ${e.toString()}',
            type: DioExceptionType.unknown,
          );

          // Trigger logout as this is likely an irrecoverable situation
          _triggerLogout();
          return handler.next(newError);
        }
      }

      // If loop completes (max retries reached), trigger logout and propagate error
      _triggerLogout();
      return handler.next(err);
    } finally {
      // Always release the lock, even if an exception occurs
      _lock.release();
    }
  }

  /// Retries a request with a new access token
  Future<Response<dynamic>> _retryRequestWithNewToken(
    RequestOptions options,
    String newAccessToken,
  ) async {
    // Clone the original request
    final newOptions = options.copyWith();

    // Update the authorization header with the new token
    newOptions.headers['Authorization'] = 'Bearer $newAccessToken';

    // Retry the request with the new token
    return await dio.fetch(newOptions);
  }

  /// Determines if an AuthException should be retried
  bool _shouldRetryError(AuthException e, int currentRetryCount) {
    // Only retry network errors and only if we haven't reached max retries - 1
    return e == AuthException.networkError() &&
        currentRetryCount < _maxRetries - 1;
  }

  /// Applies exponential backoff delay based on retry count
  Future<void> _applyBackoff(int retryCount) async {
    final delay = Duration(
      milliseconds: _initialDelayMs * pow(2, retryCount - 1).toInt(),
    );
    await Future.delayed(delay);
  }

  /// Triggers logout event
  void _triggerLogout() {
    authEventBus.add(AuthEvent.loggedOut);
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
