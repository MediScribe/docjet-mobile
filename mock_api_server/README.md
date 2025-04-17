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

## API Job Remote Data Source Debug Test

We have a dedicated test for debugging API job remote data source interactions with the mock server. This test helps diagnose multipart upload issues and verify proper communication with the server.

### Running the Debug Test

```bash
# First, make sure mocks are generated (only needed once or after changes)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the debug test
flutter test test/features/jobs/data/datasources/api_job_remote_data_source_debug_test.dart
```

This test:
- Automatically starts and stops the mock server
- Creates a test multipart form with audio file
- Sends the request to the mock server
- Logs detailed request/response information
- Validates a successful response

### Debug Test Output

The test provides verbose logging including:
- FormData construction with fields and files
- HTTP request headers and payload
- HTTP response data
- Request processing by the mock server

### Troubleshooting Debug Test Issues

If you encounter issues:
1. Check the mock server logs for specific errors
2. Verify that `test-api-key` and auth token headers are properly included
3. Check that FormData is constructed with both fields and files
4. Ensure no port conflicts (kill any running mock server instances)
5. Verify that no Content-Type header is manually set for multipart requests

## Multipart Upload Testing with httpbin.org

We've created dedicated tests to validate multipart upload behavior against httpbin.org, which is helpful for troubleshooting issues with the mock server.

### Running httpbin Tests

From the project root:

```bash
flutter test test/features/jobs/data/datasources/httpbin_multipart_test.dart
```

This test validates:
- Default Dio FormData behavior
- Custom boundary approaches
- Proper header handling

The httpbin tests are crucial for isolating issues with multipart uploads from the mock server implementation.

### Quick Diagnostic Tests

If you suspect issues with multipart handling, run:

```bash
flutter test test/features/jobs/data/datasources/debug_multipart_test.dart
```

This test performs more detailed logging and diagnostics of multipart request handling.

## Running Integration Tests

Integration tests require the mock server to be running properly. Follow these steps:

1. **Important**: Make sure no previous mock server is running:
   ```bash
   pkill -f "dart bin/server.dart" || true
   ```

2. Run the integration tests from the project root:
   ```bash
   flutter test test/features/jobs/data/datasources/job_datasources_integration_test.dart
   ```

3. Note: The integration test will automatically start/stop the mock server as needed, but it's good practice to ensure no server is running before starting.

4. If you encounter `400 Bad Request` errors in the integration test:
   - Check that you're using `isJsonRequest: false` when getting options for multipart requests
   - Make sure FormData is properly configured with all required fields
   - Let Dio handle setting the Content-Type header with the boundary
   - Check the URL in your requests (common error: `'${_mockBaseUrl}api/v1/jobs'` should be `'$_mockBaseUrl/jobs'`)

## Running All Tests

To run all relevant tests in sequence:

```bash
# Kill any existing server first
pkill -f "dart bin/server.dart" || true

# 1. Run isolated httpbin tests (no mock server needed)
flutter test test/features/jobs/data/datasources/httpbin_multipart_test.dart

# 2. Run debug diagnostics
flutter test test/features/jobs/data/datasources/debug_multipart_test.dart

# 3. Run the API job remote data source debug test
flutter test test/features/jobs/data/datasources/api_job_remote_data_source_debug_test.dart

# 4. Run integration tests
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