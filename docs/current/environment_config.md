# Environment Configuration Guide

This document outlines how to configure the DocJet Mobile app for different environments.

## Environment Variables

The app uses the following environment variables:

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `API_KEY` | API key for authentication | None (required) |
| `API_DOMAIN` | Domain for API calls | `staging.docjet.ai` |

## Running with Different Configurations

### Using secrets.json (Recommended)

Create a `secrets.json` file at the project root with your environment variables:

```json
{
  "API_KEY": "your-api-key",
  "API_DOMAIN": "api.docjet.com"
}
```

Then run the app with:

```bash
flutter run --dart-define-from-file=secrets.json
```

### Using Direct Parameters

Alternatively, you can pass the parameters directly:

```bash
flutter run --dart-define=API_KEY=your-api-key --dart-define=API_DOMAIN=api.docjet.com
```

## Testing with Mock Server

For local testing with the mock server, use:

```bash
./scripts/run_with_mock.sh
```

This script:
1. Starts the mock server on port 8080
2. Uses `secrets.test.json` which contains:
   ```json
   {
     "API_KEY": "test-api-key",
     "API_DOMAIN": "localhost:8080"
   }
   ```
3. Automatically connects the app to the mock server
4. Cleans up when you exit

## How It Works

The app determines the API URL based on the provided domain:

- For `localhost` or IP addresses: Uses `http://` protocol
- For all other domains: Uses `https://` protocol
- Automatically adds `/api/v1` to all URLs

For example:
- `localhost:8080` → `http://localhost:8080/api/v1`
- `api.docjet.com` → `https://api.docjet.com/api/v1`

## Technical Implementation

- The `DioFactory` reads `API_DOMAIN` from environment variables using `String.fromEnvironment`
- `ApiConfig.baseUrlFromDomain()` determines the appropriate protocol based on the domain
- Authentication endpoints use the configured domain for all requests 