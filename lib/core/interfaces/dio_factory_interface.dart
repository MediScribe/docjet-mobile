import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/infrastructure/authentication_api_client.dart';

/// Defines the interface for a factory responsible for creating configured
/// [Dio] HTTP client instances.
///
/// Implementations of this interface will typically require an `AppConfigInterface`
/// dependency provided via their constructor to access necessary configuration
/// like API domain and keys.
abstract class DioFactoryInterface {
  /// Creates a basic Dio instance without authentication interceptors.
  /// Suitable for non-authenticated API calls.
  ///
  /// This instance should be configured with the base URL and timeouts
  /// derived from the `AppConfigInterface` provided during factory construction.
  Dio createBasicDio();

  /// Creates a Dio instance configured with necessary authentication interceptors
  /// (e.g., API key injection, token refresh).
  ///
  /// This instance relies on the `AppConfigInterface` provided during factory
  /// construction for API key and base URL, and requires explicit dependencies
  /// for handling authentication logic.
  ///
  /// Args:
  ///   [authApiClient]: The client responsible for authentication API calls (like refresh).
  ///   [credentialsProvider]: The provider for accessing stored tokens.
  ///   [authEventBus]: The bus for dispatching authentication events (e.g., on logout).
  Dio createAuthenticatedDio({
    required AuthenticationApiClient authApiClient,
    required AuthCredentialsProvider credentialsProvider,
    required AuthEventBus authEventBus,
  });
}
