import 'dart:io';

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_interceptor.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:docjet_mobile/core/interfaces/app_config_interface.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter/foundation.dart';

/// Factory for creating [Dio] HTTP client instances with authentication support.
///
/// This factory creates and configures Dio instances based on the provided
/// [AppConfigInterface].
class DioFactory {
  static final _logger = LoggerFactory.getLogger('DioFactory');
  final AppConfigInterface _appConfig;

  /// Creates a DioFactory instance.
  ///
  /// Requires an [AppConfigInterface] to configure the Dio clients.
  DioFactory({required AppConfigInterface appConfig}) : _appConfig = appConfig {
    _logger.d('DioFactory initialized with config: ${_appConfig.toString()}');
  }

  /// Creates a basic Dio instance without authentication interceptors.
  /// Suitable for non-authenticated API calls or initial setup.
  Dio createBasicDio() {
    final baseUrl = ApiConfig.baseUrlFromDomain(_appConfig.apiDomain);
    _logger.i(
      'Creating basic Dio instance for domain: ${_appConfig.apiDomain} -> $baseUrl',
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
  ///
  /// Uses function-based DI to break the circular dependency between
  /// AuthInterceptor and AuthApiClient.
  Dio createAuthenticatedDio({
    required AuthApiClient authApiClient,
    required AuthCredentialsProvider credentialsProvider,
    required AuthEventBus authEventBus,
  }) {
    final dio = createBasicDio();

    if (_appConfig.apiKey.isEmpty) {
      _logger.w('API_KEY from AppConfig is empty!');
      // Depending on requirements, could throw an error here or allow proceeding
      // For now, we log a warning.
    }

    // Add interceptor to inject API key header BEFORE the AuthInterceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_appConfig.apiKey.isNotEmpty) {
            options.headers['x-api-key'] = _appConfig.apiKey;
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
        // Pass a function reference instead of the entire AuthApiClient instance
        // This breaks the circular dependency
        refreshTokenFunction:
            (refreshToken) => authApiClient.refreshToken(refreshToken),
        credentialsProvider: credentialsProvider,
        dio: dio,
        authEventBus: authEventBus,
      ),
    );

    _logger.i(
      'Created authenticated Dio instance with API Key and Auth interceptors.',
    );
    return dio;
  }
}
