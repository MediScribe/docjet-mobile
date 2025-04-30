import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/events/auth_events.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/refresh_response_dto.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'dart:math';
import 'package:mutex/mutex.dart';

/// Dio interceptor that handles authentication token management
class AuthInterceptor extends Interceptor {
  /// Function to call for token refresh operations
  final Future<RefreshResponseDto> Function(String) _refreshTokenFunction;

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

  AuthInterceptor({
    required Future<RefreshResponseDto> Function(String) refreshTokenFunction,
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
            _triggerLogout();
            return handler.next(err);
          }

          // Get new tokens using the provided function
          final refreshResponse = await _refreshTokenFunction(refreshToken);

          // Store the new tokens from RefreshResponseDto
          await credentialsProvider.setAccessToken(refreshResponse.accessToken);
          await credentialsProvider.setRefreshToken(
            refreshResponse.refreshToken,
          );

          // Retry the original request with the new token
          final response = await _retryRequestWithNewToken(
            err.requestOptions,
            refreshResponse.accessToken,
          );

          return handler.resolve(response);
        } on AuthException catch (e) {
          // Check if the error is retryable (e.g., network error)
          if (_shouldRetryAuthError(e, retryCount)) {
            await _applyBackoff(++retryCount);
          } else {
            // Irrecoverable auth error or max retries reached
            _triggerLogout();
            return handler.next(err); // Propagate original 401
          }
        } catch (e) {
          // Unexpected error during refresh
          final newError = DioException(
            requestOptions: err.requestOptions,
            error: e,
            message: 'Error during token refresh: ${e.toString()}',
            type: DioExceptionType.unknown,
          );
          _triggerLogout();
          return handler.next(newError);
        }
      }

      // If loop completes (max retries reached), trigger logout
      _triggerLogout();
      return handler.next(err);
    } finally {
      _lock.release();
    }
  }

  /// Retries a request with a new access token
  Future<Response<dynamic>> _retryRequestWithNewToken(
    RequestOptions options,
    String newAccessToken,
  ) async {
    final newOptions = options.copyWith();
    newOptions.headers['Authorization'] = 'Bearer $newAccessToken';
    return await dio.fetch(newOptions);
  }

  /// Determines if an AuthException should be retried
  bool _shouldRetryAuthError(AuthException e, int currentRetryCount) {
    // Keep existing logic - assume AuthException has necessary checks or equality defined
    return e == AuthException.networkError() &&
        currentRetryCount < _maxRetries - 1;
  }

  /// Applies exponential backoff delay
  Future<void> _applyBackoff(int retryCount) async {
    final delay = Duration(
      milliseconds: _initialDelayMs * pow(2, retryCount - 1).toInt(),
    );
    await Future.delayed(delay);
  }

  /// Triggers logout event
  void _triggerLogout() {
    // Keep existing event firing logic - assume AuthEventBus.add is correct
    authEventBus.add(AuthEvent.loggedOut);
  }

  /// Checks if the error is a 401 Unauthorized error and not an auth endpoint
  bool _isUnauthenticatedError(DioException err) {
    return err.response?.statusCode == 401 &&
        !_isAuthEndpoint(err.requestOptions.path);
  }

  /// Checks if the path corresponds to an authentication endpoint
  bool _isAuthEndpoint(String path) {
    return _authEndpoints.any((endpoint) => path.contains(endpoint));
  }
}
