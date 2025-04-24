import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart';
// Import needed for mock setup

// Mock the JwtDecoder.isExpired function for testing purposes
// This requires a bit more setup than a simple mock usually,
// as static methods are harder to mock directly without specific frameworks.
// For simplicity here, we'll rely on real tokens for basic cases
// and potentially use dependency injection in the real implementation if needed.

void main() {
  late JwtValidator jwtValidator;

  // A sample expired JWT token (replace with a real expired token if needed for testing)
  // You can generate these online or using libraries. This one is structurally valid but likely expired.
  const String expiredToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyMzkwMjJ9.4_tC9-Q9zI-FSF-Gwq8Qv6dJ73t1_5Jt2a_B5n5f0t0';

  // A sample valid (not expired) JWT token
  // This token expires far in the future
  const String validToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjI1MTYyMzkwMjJ9.0_vP3-_u9yR6jK4M4FhH8_z7y8P5F0z-x7q8S9e0j0Q';

  // A structurally invalid token
  const String invalidToken = 'this.is.not.a.jwt';

  // A token with no expiry claim
  const String tokenWithoutExpiry =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

  setUp(() {
    jwtValidator = JwtValidator();
  });

  group('JwtValidator', () {
    group('isTokenExpired', () {
      test('should return true for an expired token', () {
        // ACT
        final result = jwtValidator.isTokenExpired(expiredToken);
        // ASSERT
        expect(result, isTrue);
      });

      test('should return false for a valid token', () {
        // ACT
        final result = jwtValidator.isTokenExpired(validToken);
        // ASSERT
        expect(result, isFalse);
      });

      test('should return true for a token without an expiry claim', () {
        // ACT & ASSERT
        // The token without 'exp' causes an error in jwt_decoder, but our
        // implementation catches this and returns true (treating as expired)
        // This is safer behavior as we don't want to trust tokens with missing required fields
        final result = jwtValidator.isTokenExpired(tokenWithoutExpiry);
        expect(result, isTrue);
        // No assertion for exception since it's caught internally
      });

      test('should throw exception for an invalid token string', () {
        // ACT & ASSERT
        expect(
          () => jwtValidator.isTokenExpired(invalidToken),
          throwsA(isA<FormatException>()), // jwt_decoder throws FormatException
        );
      });

      test('should throw exception for a null token', () {
        // ACT & ASSERT
        expect(
          () => jwtValidator.isTokenExpired(null),
          throwsA(isA<ArgumentError>()), // Or appropriate error based on impl
        );
      });
    });
  });
}
