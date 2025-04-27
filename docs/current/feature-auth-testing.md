# Authentication Testing Guide

This document explains how to test the authentication system in DocJet Mobile.

## Testing Levels

Authentication testing is conducted at multiple levels:

1. **Unit Tests**: Testing individual components in isolation
2. **Integration Tests**: Testing interactions between components
3. **End-to-End Tests**: Testing complete flows from UI to data layer

## Unit Testing Auth Components

Unit tests focus on testing individual components in isolation:

- **AuthException**: Tests for different exception types and factory methods
- **AuthCredentialsProvider**: Tests secure storage of tokens and validation
- **JWT Validation**: Tests token validation and expiry detection
- **AuthenticationApiClient**: Tests non-authenticated operations (login, refresh) ensuring `basicDio` is used and errors are mapped correctly
- **UserApiClient**: Tests authenticated operations (profile) ensuring `authenticatedDio` is used and errors are mapped correctly
- **AuthService**: Tests implementation (`AuthServiceImpl`) verifying delegation to the correct API client (`AuthenticationApiClient` or `UserApiClient`) based on the method called
- **AuthInterceptor**: Tests token refresh logic, ensuring it correctly uses the provided `refreshTokenFunction` (from `AuthenticationApiClient`) and handles 401s appropriately for requests made via `authenticatedDio`

## End-to-End Authentication Flow Testing

End-to-end tests validate the complete authentication flow. Our approach uses mock UI components to isolate testing from real UI implementation details while still validating the full flow.

### File Location

The end-to-end authentication tests are located at: `test/e2e/auth_flow_test.dart`

### Key Flows Tested

1. **Login Flow**: User can log in and navigate to the authenticated screen
   - Test enters credentials and submits login form
   - Verifies loading state is shown during login
   - Verifies successful navigation to home screen with user details

2. **Token Refresh**: Verifies token refresh mechanism works
   - Tests that expired tokens are refreshed automatically
   - Verifies that original requests succeed after refresh

3. **Logout Flow**: User can log out and return to login screen
   - Tests that logout button works
   - Verifies navigation back to login screen
   - Verifies auth state is reset

### Test Architecture

The tests use a specialized testing infrastructure:

1. **MockLoginScreen & MockHomeScreen**: Lightweight UI mocks that avoid dependencies on real UI components

2. **TestAuthApp**: A test-specific app that simulates the real app's authentication flows:
   - State management for auth states
   - Navigation between screens based on auth state
   - Callbacks for login, logout, and profile fetching

3. **Mock Services**: Implementations of auth services for testing:
   - MockAuthService
   - MockAuthEventBus
   - MockAuthSessionProvider

### Running the E2E Authentication Tests

Run the end-to-end auth tests with:

```bash
flutter test test/e2e/auth_flow_test.dart
```

## Troubleshooting Common Test Issues

### Loading State Not Visible in Tests

If tests for loading states fail, ensure you're allowing sufficient frames for the loading indicator to appear:

```dart
// Tap action that triggers loading
await tester.tap(find.text('Login')); 

// Process first frame
await tester.pump();

// Wait for loading state to appear
await tester.pump(const Duration(milliseconds: 100)); 

// Now test for loading indicator
expect(find.byType(CircularProgressIndicator), findsOneWidget);
```

### Widget Not Found Errors

If tests can't find widgets, check:

1. Widget hierarchy - ensure widgets are actually rendered
2. Text matching - check for exact text matching
3. Timing - ensure sufficient pump calls for async operations

### Dependency Errors

If tests fail with dependency errors:

1. Use TestAuthApp which avoids real dependencies
2. Provide all required mock implementations
3. Don't rely on actual GetIt or ProviderScope dependencies in tests 