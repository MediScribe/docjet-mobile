// API version (should match ApiConfig.apiVersion in the app)
const String apiVersion = 'v1';
const String apiPrefix = 'api';
const String versionedApiPath = '$apiPrefix/$apiVersion';

// Hardcoded API key for mock validation, matching the test
const String expectedApiKey = 'test-api-key';

const String mockJwtSecret = 'mock-secret-key'; // Define JWT secret
const Duration accessTokenDuration =
    Duration(seconds: 10); // Access token lifetime
const Duration refreshTokenDuration =
    Duration(minutes: 5); // Refresh token lifetime
