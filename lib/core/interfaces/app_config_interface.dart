/// Defines the AppConfig interface for accessing application configuration.
///
/// This interface abstracts access to configuration values, enabling
/// testing with different configurations and implementing the
/// dependency inversion principle.
abstract class AppConfigInterface {
  /// The domain name (e.g., 'api.docjet.com' or 'localhost:8080') for the API.
  String get apiDomain;

  /// The API key used for authentication.
  String get apiKey;

  /// Returns true if the configuration is for local development (mock server).
  bool get isDevelopment;

  /// Returns a string representation of the configuration for debugging.
  @override
  String toString();
}
