/// Centralized API configuration for version management and endpoints
///
/// This class provides a single source of truth for API versioning
/// and endpoint construction, making it easier to manage version changes.
///
/// Important implementation notes:
/// 1. The `baseUrlFromDomain` method always adds a trailing slash to the base URL.
///    This is critical for Dio to correctly resolve paths: when a baseUrl ends
///    with a slash, Dio properly appends paths even when they don't have a leading slash.
/// 2. The `joinPaths` utility ensures paths are always joined correctly regardless
///    of whether components have trailing/leading slashes.
/// 3. Endpoint constants are defined without leading slashes, but the `joinPaths`
///    utility or Dio with a properly configured baseUrl (ending with slash) will
///    handle this correctly.
class ApiConfig {
  /// The current API version (v1, v2, etc.)
  static const String apiVersion = 'v1';

  /// The API prefix path component - used in all API URLs
  static const String apiPrefix = 'api';

  /// Combined version path component (/api/v1)
  static const String versionedApiPath = '$apiPrefix/$apiVersion';

  /// Constructs a complete base URL from a domain
  ///
  /// Automatically determines protocol (http vs https) based on domain:
  /// - localhost and IP addresses use http://
  /// - All other domains use https://
  /// - Adds the versioned API path
  static String baseUrlFromDomain(String domain) {
    final bool isLocalhost =
        domain.startsWith('localhost') || domain.startsWith('127.0.0.1');
    final String protocol = isLocalhost ? 'http' : 'https';
    return '$protocol://$domain/$versionedApiPath/';
  }

  /// Safely joins base URL and path segments with proper slash handling
  ///
  /// This utility ensures that paths are joined correctly regardless of
  /// whether components have leading/trailing slashes.
  /// - Removes duplicate slashes
  /// - Ensures a single slash between components
  /// - Works with both path segments and full URLs
  static String joinPaths(String base, String path) {
    // Strip trailing slash from base if present
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    // Ensure path starts with slash
    if (!path.startsWith('/')) {
      path = '/$path';
    }

    return '$base$path';
  }

  // ===== Endpoint Getters (Unprefixed) =====
  // These return path components WITHOUT the /api/v1 prefix

  /// Health check endpoint (unprefixed)
  static const String healthEndpoint = 'health';

  /// Login endpoint (unprefixed)
  static const String loginEndpoint = 'auth/login';

  /// Refresh token endpoint (unprefixed)
  static const String refreshEndpoint = 'auth/refresh-session';

  /// User profile endpoint (unprefixed)
  static const String userProfileEndpoint = 'users/me';

  /// Jobs listing endpoint (unprefixed)
  static const String jobsEndpoint = 'jobs';

  /// Single job endpoint (unprefixed)
  static String jobEndpoint(String jobId) => 'jobs/$jobId';

  /// Job documents endpoint (unprefixed)
  static String jobDocumentsEndpoint(String jobId) => 'jobs/$jobId/documents';

  // ===== Full URL Methods =====
  // These construct complete URLs (including domain and version prefix)

  /// Full health check endpoint URL
  static String fullHealthEndpoint(String domain) =>
      joinPaths(baseUrlFromDomain(domain), healthEndpoint);

  /// Full login endpoint URL
  static String fullLoginEndpoint(String domain) =>
      joinPaths(baseUrlFromDomain(domain), loginEndpoint);

  /// Full refresh token endpoint URL
  static String fullRefreshEndpoint(String domain) =>
      joinPaths(baseUrlFromDomain(domain), refreshEndpoint);

  /// Full jobs listing endpoint URL
  static String fullJobsEndpoint(String domain) =>
      joinPaths(baseUrlFromDomain(domain), jobsEndpoint);

  /// Full single job endpoint URL
  static String fullJobEndpoint(String domain, String jobId) =>
      joinPaths(baseUrlFromDomain(domain), jobEndpoint(jobId));

  /// Full job documents endpoint URL
  static String fullJobDocumentsEndpoint(String domain, String jobId) =>
      joinPaths(baseUrlFromDomain(domain), jobDocumentsEndpoint(jobId));
}
