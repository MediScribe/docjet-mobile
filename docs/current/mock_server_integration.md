# Mock Server Integration Guide

This guide explains how to use the mock API server for development and testing, including common troubleshooting steps.

## Mock Server Overview

The mock server provides a local implementation of the DocJet backend API for development, testing, and CI environments.

### Features

- **Authentication endpoints** (login, refresh, profile)
- **Job management endpoints** (list, create, update, get)
- **Document management** (multipart uploads)
- **Configurable responses** for testing error scenarios

## Running with Mock Server

### Using the Helper Script

The easiest way to run the app with the mock server is using the provided script:

```bash
./scripts/run_with_mock.sh
```

This script:
1. Starts the mock server on port 8080
2. Waits for the server to be ready
3. Runs the Flutter app with `secrets.test.json` configuration
4. Properly cleans up when the app exits

### Manual Setup

If you need to run things manually:

1. **Start the mock server**:
   ```bash
   cd mock_api_server && dart bin/server.dart --port 8080
   ```

2. **Run the Flutter app with test configuration**:
   ```bash
   flutter run --dart-define-from-file=secrets.test.json
   ```

### Configuration File

The `secrets.test.json` file contains environment variables for the mock server:

```json
{
  "API_KEY": "test-api-key",
  "API_DOMAIN": "localhost:8080"
}
```

## Testing With Mock Server

### Unit Tests

Many unit tests automatically use the mock server. Reference implementations:

```dart
// Example of testing with the mock server in JobDatasourcesIntegrationTest
test('should upload a job with file to the mock server', () async {
  // Test uses the mock server for real HTTP requests
});
```

### Integration Tests

To run integration tests with the mock server:

```bash
flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
```

### E2E Tests

To run end-to-end tests with the mock server:

```bash
./scripts/run_e2e_tests.sh
```

## Troubleshooting

### Provider Override Issues

#### Symptom: "authServiceProvider has not been overridden"

This error occurs when conflicting provider definitions exist in the codebase.

**Solution**:
1. Ensure you're using the generated provider from `auth_notifier.dart`
2. Don't redefine providers manually that are already defined via code generation
3. Make sure all references use the same provider instance

Example fix:
```dart
// CORRECT: Import and use the generated provider
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';

// In ProviderScope:
overrides: [
  authServiceProvider.overrideWithValue(getIt<AuthService>()),
],
```

#### Symptom: "Object/factory with type X is not registered inside GetIt"

This indicates a missing GetIt registration for a required dependency.

**Solution**:
1. Check that all required services are registered in `injection_container.dart`
2. For tests, mock all required dependencies:
   ```dart
   ProviderScope(
     overrides: [
       authServiceProvider.overrideWithValue(mockAuthService),
       authEventBusProvider.overrideWithValue(mockAuthEventBus),
     ],
     child: ComponentUnderTest(),
   ),
   ```

### Multipart Upload Issues

#### Symptom: "400 Bad Request" with multipart uploads

**Solution**:
1. Don't manually set Content-Type for multipart requests
2. Let Dio handle boundary creation
3. Ensure correct field names match server expectations

### Network Connection Issues

#### Symptom: Connection timeouts or errors

**Solution**:
1. Verify the mock server is running (`lsof -i:8080`)
2. Check that `API_DOMAIN` is set to `localhost:8080`
3. Check console for mock server logs to diagnose issues 