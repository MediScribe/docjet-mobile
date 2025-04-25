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

- The `DioFactory` reads environment variables using a centralized approach:
  - A `_environmentDefaults` map contains all default values in one place
  - The `getEnvironmentValue` method provides consistent access with proper fallbacks
  - Environment values can be overridden for testing via an optional map parameter
- `ApiConfig.baseUrlFromDomain()` determines the appropriate protocol based on the domain
- Authentication endpoints use the configured domain for all requests

## Adding New Environment Variables

When adding new environment variables to the app:

1. Add the variable name as a constant in the appropriate class (e.g., `DioFactory._newVarKey`)
2. Add a default value to the `_environmentDefaults` map in that class
3. Use `getEnvironmentValue` to retrieve the value
4. Update this documentation with the new variable name and purpose

This approach ensures consistency and makes maintenance easier when new environment variables are added. 