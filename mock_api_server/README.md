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

## Known Issues

1. Integration tests may fail with `400 Bad Request` when using Dio to create FormData directly
   - Workaround: Let Dio handle the Content-Type header automatically, don't override it
   - Ensure your api_job_remote_data_source_impl.dart is using `isJsonRequest: false` when getting options

2. The boundary format is crucial for multipart requests
   - If custom boundary is needed, follow standard format (`----WebKitFormBoundary...` or similar)

3. For integration tests, use the helper method `_directDioUpload` in the test file instead of direct API calls

## Debugging

The server includes extensive debug logging. Look for:
- `=== DEBUG: Incoming Request ===` - Shows incoming request details
- `=== DEBUG: Outgoing Response ===` - Shows outgoing response details
- `DEBUG CREATE JOB:` - Shows multipart form processing details

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