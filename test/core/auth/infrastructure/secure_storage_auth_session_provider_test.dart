import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart'; // Re-added
import 'package:docjet_mobile/core/auth/infrastructure/secure_storage_auth_session_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for dependencies
@GenerateMocks([AuthCredentialsProvider])
import 'secure_storage_auth_session_provider_test.mocks.dart';

void main() {
  late MockAuthCredentialsProvider mockCredentialsProvider;
  late SecureStorageAuthSessionProvider authSessionProvider;

  setUp(() {
    mockCredentialsProvider = MockAuthCredentialsProvider();
    authSessionProvider = SecureStorageAuthSessionProvider(
      credentialsProvider: mockCredentialsProvider,
    );
  });

  group('SecureStorageAuthSessionProvider', () {
    group('isAuthenticated', () {
      test(
        'returns true when credentials provider has an access token',
        () async {
          // Arrange
          when(
            mockCredentialsProvider.getAccessToken(),
          ).thenAnswer((_) async => 'some-access-token');

          // Act
          final result =
              await authSessionProvider.isAuthenticated(); // Use await

          // Assert
          expect(result, isTrue);
          verify(mockCredentialsProvider.getAccessToken()).called(1);
        },
      );

      test(
        'returns false when credentials provider has no access token',
        () async {
          // Arrange
          when(
            mockCredentialsProvider.getAccessToken(),
          ).thenAnswer((_) async => null);

          // Act
          final result =
              await authSessionProvider.isAuthenticated(); // Use await

          // Assert
          expect(result, isFalse);
          verify(mockCredentialsProvider.getAccessToken()).called(1);
        },
      );

      test(
        'returns false when credentials provider throws exception',
        () async {
          // Arrange
          when(
            mockCredentialsProvider.getAccessToken(),
          ).thenThrow(Exception('Storage error'));

          // Act
          final result =
              await authSessionProvider.isAuthenticated(); // Use await

          // Assert
          expect(result, isFalse);
          verify(mockCredentialsProvider.getAccessToken()).called(1);
        },
      );
    });

    group('getCurrentUserId', () {
      test('returns userId when credentials provider has userId', () async {
        // Arrange
        const expectedUserId = 'user-123';
        when(
          mockCredentialsProvider.getUserId(),
        ).thenAnswer((_) async => expectedUserId);

        // Act
        final result =
            await authSessionProvider.getCurrentUserId(); // Use await

        // Assert
        expect(result, expectedUserId);
        verify(mockCredentialsProvider.getUserId()).called(1);
      });

      test(
        'throws AuthException when credentials provider has no userId',
        () async {
          // Arrange
          when(
            mockCredentialsProvider.getUserId(),
          ).thenAnswer((_) async => null);

          // Act & Assert
          expect(
            // Use expectLater for async throws
            () => authSessionProvider.getCurrentUserId(), // Use await
            throwsA(
              isA<AuthException>().having(
                (e) => e.message,
                'message',
                'No authenticated user ID found.',
              ),
            ),
          );
          verify(mockCredentialsProvider.getUserId()).called(1);
        },
      );

      test(
        'throws AuthException when credentials provider throws exception',
        () async {
          // Arrange
          final exception = Exception('Storage error');
          when(mockCredentialsProvider.getUserId()).thenThrow(exception);

          // Act & Assert
          expect(
            () => authSessionProvider.getCurrentUserId(), // Use await
            throwsA(
              isA<AuthException>().having(
                (e) => e.message,
                'message',
                contains('Failed to retrieve user ID'),
              ),
            ),
          );
          verify(mockCredentialsProvider.getUserId()).called(1);
        },
      );
    });
  });
}
