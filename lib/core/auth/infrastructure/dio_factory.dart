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

  /// Environment variable keys
  static const String _apiDomainKey = 'API_DOMAIN';
  static const String _apiKeyKey = 'API_KEY';

  /// Centralized environment variable defaults
  static final Map<String, String> _environmentDefaults = {
    _apiDomainKey: 'staging.docjet.ai',
    _apiKeyKey: '',
  };

  /// Gets environment variable value with consistent fallback to defaults
  ///
  /// This method provides centralized access to environment variables with
  /// well-defined defaults for known variables.
  ///
  /// Parameters:
  /// - [name]: The name of the environment variable to retrieve
  /// - [environment]: Optional map of environment values (for testing)
  ///
  /// Returns the environment value, falling back to defaults for known variables
  /// or empty string for unknown variables.
  static String getEnvironmentValue(
    String name,
    Map<String, String>? environment,
  ) {
    // If environment map is provided (primarily for testing)
    if (environment != null) {
      // Validate that all values in the map are non-null
      if (environment.containsKey(name) && environment[name] == null) {
        throw AssertionError(
          'Environment map contains null value for key: $name',
        );
      }

      // Return the value from the map if present, otherwise fall back to defaults
      return environment.containsKey(name)
          ? environment[name]!
          : _environmentDefaults[name] ?? '';
    }

    // Otherwise use String.fromEnvironment with appropriate default
    return String.fromEnvironment(
      name,
      defaultValue: _environmentDefaults[name] ?? '',
    );
  }

  /// Creates a basic Dio instance without authentication interceptors.
  /// Suitable for non-authenticated API calls or initial setup.
  static Dio createBasicDio({Map<String, String>? environment}) {
    final apiDomain = getEnvironmentValue(_apiDomainKey, environment);
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
    final apiKey = getEnvironmentValue(_apiKeyKey, environment);

    if (apiKey.isEmpty) {
      _logger.w('$_apiKeyKey environment variable is not set!');
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
