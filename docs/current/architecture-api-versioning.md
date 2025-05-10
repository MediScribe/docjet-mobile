# API Versioning in DocJet Mobile

This document describes the centralized approach to API versioning in the DocJet Mobile application.

## Overview

The DocJet Mobile app uses a centralized approach to API versioning, which simplifies future version changes and ensures consistency across the app. The API version is specified in a single location (`ApiConfig`), and all API calls use this version.

## Key Components

### 1. ApiConfig Class

The `ApiConfig` class serves as the single source of truth for API versioning and endpoint construction:

```dart
// In lib/core/config/api_config.dart
class ApiConfig {
  /// The current API version (v1, v2, etc.)
  static const String apiVersion = 'v1';
  
  /// The API prefix path component - used in all API URLs
  static const String apiPrefix = 'api';
  
  /// Combined version path component (/api/v1)
  static const String versionedApiPath = '$apiPrefix/$apiVersion';
  
  // ... methods for constructing URLs and endpoints
}
```

### 2. Environment Configuration

Instead of hardcoding full API URLs with version prefixes, we use the domain and let `ApiConfig` build the URLs:

```json
// In secrets.test.json
{
  "API_KEY": "test-api-key",
  "API_DOMAIN": "localhost:8080"
}
```

### 3. Dio Factory Integration

The `DioFactory` uses `ApiConfig` to construct the base URL:

```dart
// In DioFactory
final baseUrl = ApiConfig.baseUrlFromDomain(_apiDomain);
```

### 4. Mock Server Integration

The mock server uses the same versioning constants to ensure consistency:

```dart
// In packages/mock_api_server/bin/server.dart
const String _apiVersion = 'v1';
const String _apiPrefix = 'api';
const String _versionedApiPath = '$_apiPrefix/$_apiVersion';
```

## Making a Version Change

To change the API version (e.g., from v1 to v2):

1. Update the `apiVersion` constant in `ApiConfig`
2. Update the `_apiVersion` constant in the mock server
3. Update any version-specific code in the app
4. Update the documentation as needed

No changes are needed to environment variables, as they only specify the domain, not the version.

## Testing Version Changes

To test a version change:

1. Create a branch with the updated version constants
2. Run the E2E tests to verify all endpoints still work
3. Test the app against multiple environments (test, staging, production)

## Best Practices

1. **Always Use ApiConfig**: Never hardcode API versions or paths
2. **Test Thoroughly**: Version changes require extensive testing
3. **Update Documentation**: Keep this document up to date with versioning changes
4. **Coordinate with Backend**: Coordinate version changes with the backend team

## References

- [API Documentation](docs/current/project-specification.md)
- [Architecture Documentation](docs/current/architecture-overview.md)

### Related Sections

* [Overall Architecture](./architecture-overview.md)
* [Environment Configuration](./setup-environment-config.md)

For example, to configure the app to use the staging environment, you might define the API domain in your configuration source:

```json
// Example: secrets.staging.json (used with `flutter run --dart-define-from-file=...` for release builds)
{
  "API_KEY": "staging-api-key",
  "API_DOMAIN": "staging.docjet.ai"
}

// NOTE: For local development against the mock server, the domain (`localhost:8080`)
// is typically set internally via `AppConfig.development()` when running 
// with the `main_dev.dart` entry point (`./scripts/run_with_mock.sh`).
// The use of `secrets.test.json` is now primarily limited to specific test setups like E2E.
```

Then, within the `DioFactory` or similar network setup code, the base URL is constructed using the domain from the runtime `AppConfig`: 