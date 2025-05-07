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
- `GET /api/v1/users/me` - Get current user profile (requires auth token)

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

## Debug Endpoints

These endpoints are provided for testing and debugging job status progression. They are not part of the standard API and should only be used in development/testing environments.

### `POST /api/v1/debug/jobs/start`

Starts the automatic progression of a job's status through the defined lifecycle (`submitted`, `transcribing`, `transcribed`, `generating`, `generated`, `completed`).

**Query Parameters:**

- `id` (optional): The ID of the job to start progression for. If not provided, progression is started for ALL jobs in the system.
- `interval_seconds` (optional, double, default: 3.0): The time in seconds between each status update.
- `fast_test_mode` (optional, boolean, default: false): If `true`, the job immediately progresses through all statuses to `completed`, ignoring the interval.

**Example (Timed Progression for Single Job):**

```bash
curl -v -X POST "http://localhost:8080/api/v1/debug/jobs/start?id=<your-job-id>&interval_seconds=1.5"
```

**Example (Fast Mode for Single Job):**

```bash
curl -v -X POST "http://localhost:8080/api/v1/debug/jobs/start?id=<your-job-id>&fast_test_mode=true"
```

**Example (Start Progression for ALL Jobs):**

```bash
curl -v -X POST "http://localhost:8080/api/v1/debug/jobs/start?fast_test_mode=true"
```

### `POST /api/v1/debug/jobs/stop`

Stops any active automatic status progression timer for a specific job or all jobs.

**Query Parameters:**

- `id` (optional): The ID of the job whose progression timer should be stopped. If not provided, stops progression for ALL jobs with active timers.

**Example (Stop Single Job):**

```bash
curl -v -X POST "http://localhost:8080/api/v1/debug/jobs/stop?id=<your-job-id>"
```