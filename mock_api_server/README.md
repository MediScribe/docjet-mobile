# DocJet Mock API Server

## Overview

This mock server simulates the DocJet backend API for local development and testing. It provides endpoints that match the production API but with predefined responses and in-memory storage.

## Running the Server

Start the server from the project root using:

```bash
cd mock_api_server && dart bin/server.dart
```

To run in background:

```bash
cd mock_api_server && dart bin/server.dart &
```

The server will start on `localhost:8080` by default.

## Server Configuration

- Default port: 8080
- Default API key: `test-api-key` (for use in tests)
- In-memory job storage (data is not persisted between restarts)

## API Endpoints

### Authentication

- `POST /api/v1/auth/login` - Login with email and password
- `POST /api/v1/auth/refresh-session` - Refresh authorization tokens

### Jobs

- `GET /api/v1/jobs` - List all jobs
- `GET /api/v1/jobs/{id}` - Get job by ID
- `POST /api/v1/jobs` - Create a new job (multipart/form-data)
- `PATCH /api/v1/jobs/{id}` - Update job details
- `GET /api/v1/jobs/{id}/documents` - Get documents related to a job

## Headers

All endpoints (except auth endpoints) require:

- `X-API-Key: test-api-key`
- `Authorization: Bearer <token>` (any non-empty string works for testing)

## MultiPart Uploads

The server correctly handles multipart/form-data uploads for job creation with the following fields:

- `user_id` (required) - User ID string
- `audio_file` (required) - Audio file to process
- `text` (optional) - Text content
- `additional_text` (optional) - Additional notes

### Multipart Testing Notes

When making multipart requests, ensure:

1. Content-Type header includes the correct `multipart/form-data; boundary=...` format
2. Do not manually set or override the Content-Type when using Dio with FormData (let Dio handle it)
3. For manual testing with curl:
   ```bash
   curl -v -X POST \
     -H "X-API-Key: test-api-key" \
     -H "Authorization: Bearer fake-access-token" \
     -F "user_id=fake-user-id-123" \
     -F "text=Test text" \
     -F "audio_file=@/path/to/your/file.mp3" \
     "http://localhost:8080/api/v1/jobs"
   ```

## Quick Debug Commands

For debugging the server and tests in one go, you can use the following one-liner that:
1. Starts the mock server
2. Waits for it to initialize
3. Tests it with a curl request
4. Runs the integration tests

```bash
# Run server, test with curl, and then run integration tests
cd mock_api_server && dart bin/server.dart & sleep 2 && curl -v -X POST -H "X-API-Key: test-api-key" -H "Authorization: Bearer fake-access-token" -F "user_id=fake-user-id-123" -F "text=Test text" -F "audio_file=@README.md" "http://localhost:8080/api/v1/jobs" && cd .. && flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
```

A simpler version to just run the test:

```bash
# Kill any existing server, start a new one and run tests
pkill -f "dart bin/server.dart" || true && cd mock_api_server && dart bin/server.dart & sleep 2 && cd .. && flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
```

## Running All Tests (Simplified)

To run the main integration tests (which now include testing against the mock server):

```bash
# Kill any existing server first
pkill -f "dart bin/server.dart" || true

# Run integration tests (server started/stopped automatically within)
flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
```

## Known Issues and Troubleshooting

1. **400 Bad Request errors with Dio**:
   - URL concatenation: Make sure you're not doubling up paths like `${_mockBaseUrl}api/v1/jobs`
   - Auth headers: Verify `X-API-Key` and `Authorization` are present in all requests
   - Content-Type: Don't manually set Content-Type for multipart requests, let Dio handle it

2. **Common integration test errors**:
   - `Failed to create job. Status: 400` - Check the request format and headers
   - "Expected Content-Type starting with multipart/form-data" - Check how FormData is constructed

3. **Boundary handling**:
   - Default approach: `final formData = FormData();` (let Dio handle boundaries)
   - If custom boundary needed: Use format like `boundary=------------------------${timestamp}`
   - Never manually construct multipart payloads without proper boundary handling

4. **Testing multipart uploads**:
   - Always validate against httpbin.org first if something fails
   - Use `LogInterceptor` with Dio to see exact request/response details
   - Compare working curl requests with failing Dio requests

5. **WARNING: Persistent 400 Errors in Flutter Tests? CHECK YOUR BINDING!**
   - If your integration tests using `flutter test` consistently fail with 400 Bad Request errors (even against httpbin.org or when curl works), **check if your test setup calls `TestWidgetsFlutterBinding.ensureInitialized()`**. This binding replaces the standard `HttpClient` with a test version that **blocks all real network requests** and returns 400 status codes.
   - **SOLUTION**: For integration tests that require *real* network interaction (like hitting this mock server), **DO NOT** use `TestWidgetsFlutterBinding.ensureInitialized()`. If you need a binding (e.g., for plugins or Hive setup outside a pure widget test), ensure it's appropriate for integration testing or remove it if unnecessary for the specific test suite.

## Debugging

The server includes extensive debug logging. Look for:
- `=== DEBUG: Incoming Request ===` - Shows incoming request details
- `=== DEBUG: Outgoing Response ===` - Shows outgoing response details
- `DEBUG CREATE JOB:` - Shows multipart form processing details

For additional debugging:
```bash
# Capture full request/response logs
flutter test --verbose test/features/jobs/data/datasources/job_datasources_integration_test.dart > test_log.txt 2>&1
```

## Stopping the Server

If running in the background, find and kill the process:

```bash
pkill -f "dart bin/server.dart"
```

Or use Ctrl+C if running in foreground.

## Running Integration Tests with Mock Server

1. **Start the mock server:**
   ```bash
   cd mock_api_server && dart bin/server.dart
   ```
   The mock server will start on port 8080 with predefined API endpoints.

2. **Run the Job Datasource integration test:**
   ```bash
   flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
   ```
   
   This test:
   - Automatically manages the mock server (starts/stops it)
   - Tests the complete flow of creating jobs with file uploads
   - Validates the integration between remote and local datasources
   
   If you need to run the test manually with a pre-running server, use:
   ```bash
   cd mock_api_server && dart bin/server.dart &
   flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
   ```

3. **One-liner (recommended):**
   For the cleanest test run that ensures no stale servers are running:
   ```bash
   cd mock_api_server && pkill -f "dart bin/server.dart" || true && echo "Mock server stopped. Now running the integration test:" && flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
   ```
   This command kills any existing mock server, outputs a status message, and runs the test with verbose output.

4. **Stopping the mock server:**
   If you started the server in the background, you can stop it with:
   ```bash
   lsof -ti :8080 | xargs kill -9
   ```