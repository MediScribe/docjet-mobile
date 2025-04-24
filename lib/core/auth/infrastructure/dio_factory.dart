import 'dart:io';

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_interceptor.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter/foundation.dart';

/// Factory for creating [Dio] HTTP client instances with authentication support
///
/// This factory creates and configures Dio instances with appropriate
/// interceptors for authentication and token refresh.
class DioFactory {
  static final _logger = LoggerFactory.getLogger('DioFactory');

  // Allow overriding environment variables for testing
  static String _getEnv(String name, Map<String, String>? environment) {
    if (environment != null) {
      return environment[name] ?? '';
    }
    // In release mode or when environment is not provided, use String.fromEnvironment
    // Add default values for common cases like API_DOMAIN
    const defaultValue = '';
    if (name == 'API_DOMAIN') {
      return String.fromEnvironment(name, defaultValue: 'staging.docjet.ai');
    }
    if (name == 'API_KEY') {
      // No default API key, should be provided
      return String.fromEnvironment(name, defaultValue: defaultValue);
    }
    return String.fromEnvironment(name, defaultValue: defaultValue);
  }

  static String _getApiDomain(Map<String, String>? environment) =>
      _getEnv('API_DOMAIN', environment);
  static String _getApiKey(Map<String, String>? environment) =>
      _getEnv('API_KEY', environment);

  /// Creates a basic Dio instance without authentication interceptors.
  /// Suitable for non-authenticated API calls or initial setup.
  static Dio createBasicDio({Map<String, String>? environment}) {
    final apiDomain = _getApiDomain(environment);
    final baseUrl = ApiConfig.baseUrlFromDomain(apiDomain);
    _logger.i('Creating basic Dio instance for domain: $apiDomain -> $baseUrl');

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
    Map<String, String>? environment,
  }) {
    final dio = createBasicDio(environment: environment);
    final apiKey = _getApiKey(environment);

    if (apiKey.isEmpty) {
      _logger.w('API_KEY environment variable is not set!');
      // Depending on requirements, could throw an error here or allow proceeding
      // For now, we log a warning.
    }

    // Add interceptor to inject API key header BEFORE the AuthInterceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (apiKey.isNotEmpty) {
            options.headers['x-api-key'] = apiKey;
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
}
