import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_interceptor.dart';

/// Factory for creating [Dio] HTTP client instances with authentication support
///
/// This factory creates and configures Dio instances with appropriate
/// interceptors for authentication and token refresh.
class DioFactory {
  // Read the base URL from compile-time variables
  // Default to staging if not specified
  static const _baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://staging.docjet.ai/api/v1', // Default to staging
  );

  /// Creates a basic [Dio] instance without authentication
  ///
  /// This is used for the auth API client itself to avoid circular dependencies.
  static Dio createBasicDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl, // Use the environment-defined base URL
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
      ),
    );

    // Add logging interceptor for debug builds
    assert(() {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
      return true;
    }());

    return dio;
  }

  /// Creates an authenticated [Dio] instance with token refresh capabilities
  ///
  /// This configures Dio with the AuthInterceptor for automatic token management.
  static Dio createAuthenticatedDio({
    required AuthApiClient authApiClient,
    required AuthCredentialsProvider credentialsProvider,
  }) {
    final dio = createBasicDio();

    // Add API key interceptor to add API key to all requests
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final apiKey = await credentialsProvider.getApiKey();
          options.headers['x-api-key'] = apiKey;
          return handler.next(options);
        },
      ),
    );

    // Add auth interceptor for token management
    final authInterceptor = AuthInterceptor(
      apiClient: authApiClient,
      credentialsProvider: credentialsProvider,
      dio: dio, // Circular reference for retrying
    );

    dio.interceptors.add(authInterceptor);

    return dio;
  }
}
