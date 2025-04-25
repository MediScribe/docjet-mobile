/// Holds application configuration values, primarily derived from
/// compile-time environment variables.
class AppConfig {
  /// The domain name (e.g., 'api.docjet.com' or 'localhost:8080') for the API.
  final String apiDomain;

  /// The API key used for authentication.
  final String apiKey;

  /// Private constructor.
  const AppConfig._({required this.apiDomain, required this.apiKey});

  /// Creates an AppConfig instance by reading from compile-time
  /// environment variables.
  ///
  /// Uses `String.fromEnvironment` which resolves values at compile time.
  factory AppConfig.fromEnvironment() {
    // Keys used for dart-define
    const apiKeyEnvKey = 'API_KEY';
    const apiDomainEnvKey = 'API_DOMAIN';

    // Default values
    const defaultApiDomain = 'staging.docjet.ai';
    const defaultApiKey = '';

    return AppConfig._(
      apiDomain: String.fromEnvironment(
        apiDomainEnvKey,
        defaultValue: defaultApiDomain,
      ),
      apiKey: String.fromEnvironment(apiKeyEnvKey, defaultValue: defaultApiKey),
    );
  }

  /// Creates a configuration for testing purposes.
  factory AppConfig.test({required String apiDomain, required String apiKey}) {
    return AppConfig._(apiDomain: apiDomain, apiKey: apiKey);
  }

  /// Creates a standard development configuration pointing to the mock server.
  factory AppConfig.development() {
    return const AppConfig._(
      apiDomain: 'localhost:8080', // Standard mock server address
      apiKey: 'test-api-key', // Standard mock server key
    );
  }

  /// Returns true if the configuration is for local development (mock server).
  bool get isDevelopment => apiDomain == 'localhost:8080';

  @override
  String toString() {
    return 'AppConfig(apiDomain: $apiDomain, apiKey: [REDACTED])';
  }
}
