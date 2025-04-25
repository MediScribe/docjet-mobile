import 'dart:io';

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_interceptor.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:docjet_mobile/core/di/injection_container.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter/foundation.dart';

/// Factory for creating [Dio] HTTP client instances with authentication support
///
/// This factory creates and configures Dio instances with appropriate
/// interceptors for authentication and token refresh.
class DioFactory {
  static final _logger = LoggerFactory.getLogger('DioFactory');

  /// Creates a basic Dio instance without authentication interceptors.
  /// Suitable for non-authenticated API calls or initial setup.
  static Dio createBasicDio() {
    // Get AppConfig from the service locator
    final appConfig = sl<AppConfig>();
    final baseUrl = ApiConfig.baseUrlFromDomain(appConfig.apiDomain);
    _logger.i(
      'Creating basic Dio instance for domain: ${appConfig.apiDomain} -> $baseUrl',
    );

    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      contentType: ContentType.json.value, // Use standard JSON content type
    );

    final dio = Dio(options);

    // Add logging interceptor for debugging if not in release mode
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (o) => _logger.d(o.toString()), // Use our logger
        ),
      );
    }

    return dio;
  }

  /// Creates a Dio instance configured with authentication interceptors.
  /// Requires AuthApiClient and AuthCredentialsProvider for token refresh.
  static Dio createAuthenticatedDio({
    required AuthApiClient authApiClient,
    required AuthCredentialsProvider credentialsProvider,
    required AuthEventBus authEventBus,
  }) {
    // Get AppConfig from the service locator
    final appConfig = sl<AppConfig>();
    // Create basic Dio using the AppConfig retrieved above (no need to pass env)
    final dio = createBasicDio();

    if (appConfig.apiKey.isEmpty) {
      _logger.w('API_KEY from AppConfig is empty!');
      // Depending on requirements, could throw an error here or allow proceeding
      // For now, we log a warning.
    }

    // Add interceptor to inject API key header BEFORE the AuthInterceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (appConfig.apiKey.isNotEmpty) {
            options.headers['x-api-key'] = appConfig.apiKey;
            _logger.t('Injected x-api-key header.');
          } else {
            _logger.w('Skipping x-api-key header injection: Key not found.');
          }
          return handler.next(options); // continue
        },
      ),
    );

    // Add the authentication interceptor for handling 401s and token refresh
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio, // Pass the Dio instance itself
        apiClient: authApiClient,
        credentialsProvider: credentialsProvider,
        authEventBus: authEventBus,
      ),
    );

    _logger.i(
      'Created authenticated Dio instance with API Key and Auth interceptors.',
    );
    return dio;
  }

  /// Creates a basic Dio client with a mock AppConfig for testing
  ///
  /// This allows tests to specify a custom AppConfig without needing to
  /// register it in GetIt first
  static Dio createBasicDioMocked(AppConfig mockConfig) {
    final baseUrl = ApiConfig.baseUrlFromDomain(mockConfig.apiDomain);
    _logger.d('Creating basic Dio with mock config: baseUrl=$baseUrl');

    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(milliseconds: 5000),
      receiveTimeout: Duration(milliseconds: 3000),
      // Add any other Dio configs needed
    );

    return Dio(options);
  }

  /// Creates a Dio instance configured with authentication interceptors.
  /// Suitable for tests where a mock AppConfig is provided
  static Dio createAuthenticatedDioMocked({
    required AuthApiClient authApiClient,
    required AuthCredentialsProvider credentialsProvider,
    required AuthEventBus authEventBus,
    required AppConfig mockConfig,
  }) {
    final dio = createBasicDioMocked(mockConfig);

    if (mockConfig.apiKey.isEmpty) {
      _logger.w('API_KEY from mock AppConfig is empty!');
    }

    // Add interceptor to inject API key header BEFORE the AuthInterceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (mockConfig.apiKey.isNotEmpty) {
            options.headers['x-api-key'] = mockConfig.apiKey;
            _logger.t('Injected x-api-key header.');
          } else {
            _logger.w('Skipping x-api-key header injection: Key not found.');
          }
          return handler.next(options); // continue
        },
      ),
    );

    // Add the authentication interceptor for handling 401s and token refresh
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio, // Pass the Dio instance itself
        apiClient: authApiClient,
        credentialsProvider: credentialsProvider,
        authEventBus: authEventBus,
      ),
    );

    _logger.d(
      'Created authenticated Dio instance with mock API Key and Auth interceptors.',
    );
    return dio;
  }
}
