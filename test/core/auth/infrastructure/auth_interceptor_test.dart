import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_interceptor.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dtos/auth_response_dto.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([AuthApiClient, AuthCredentialsProvider, Dio])
import 'auth_interceptor_test.mocks.dart';

// Mock interceptor handlers
class MockRequestInterceptorHandler extends Mock
    implements RequestInterceptorHandler {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

void main() {
  late MockAuthApiClient mockApiClient;
  late MockAuthCredentialsProvider mockCredProvider;
  late MockDio mockDio;
  late AuthInterceptor interceptor;
  late RequestOptions requestOptions;
  late MockRequestInterceptorHandler mockRequestHandler;
  late MockErrorInterceptorHandler mockErrorHandler;

  const testAccessToken = 'test-access-token';
  const testRefreshToken = 'test-refresh-token';
  const testNewAccessToken = 'new-access-token';
  const testNewRefreshToken = 'new-refresh-token';
  const testUserId = 'test-user-id';

  setUp(() {
    mockApiClient = MockAuthApiClient();
    mockCredProvider = MockAuthCredentialsProvider();
    mockDio = MockDio();
    mockRequestHandler = MockRequestInterceptorHandler();
    mockErrorHandler = MockErrorInterceptorHandler();

    interceptor = AuthInterceptor(
      apiClient: mockApiClient,
      credentialsProvider: mockCredProvider,
      dio: mockDio,
    );

    // Setup request options for tests
    requestOptions = RequestOptions(
      path: '${ApiConfig.versionedApiPath}/some-endpoint',
      headers: {'Authorization': 'Bearer $testAccessToken'},
    );
  });

  group('onRequest', () {
    test('should add access token to request headers if available', () async {
      // Arrange
      when(
        mockCredProvider.getAccessToken(),
      ).thenAnswer((_) async => testAccessToken);

      // Act
      await interceptor.onRequest(requestOptions, mockRequestHandler);

      // Assert
      expect(
        requestOptions.headers['Authorization'],
        'Bearer $testAccessToken',
      );
      verify(mockCredProvider.getAccessToken()).called(1);
      verify(mockRequestHandler.next(requestOptions)).called(1);
    });

    test('should not add access token to auth endpoints', () async {
      // Arrange
      requestOptions = RequestOptions(path: ApiConfig.loginEndpoint);

      // Act
      await interceptor.onRequest(requestOptions, mockRequestHandler);

      // Assert
      expect(requestOptions.headers['Authorization'], isNull);
      verifyNever(mockCredProvider.getAccessToken());
      verify(mockRequestHandler.next(requestOptions)).called(1);
    });
  });

  group('onError', () {
    late DioException dioError;
    late Response<dynamic> unauthorizedResponse;

    setUp(() {
      unauthorizedResponse = Response(
        statusCode: 401,
        requestOptions: requestOptions,
      );

      dioError = DioException(
        requestOptions: requestOptions,
        response: unauthorizedResponse,
        type: DioExceptionType.badResponse,
      );
    });

    test('should refresh token and retry on 401 error', () async {
      // Arrange
      final successResponse = Response(
        data: {'success': true},
        statusCode: 200,
        requestOptions: requestOptions,
      );

      when(
        mockCredProvider.getRefreshToken(),
      ).thenAnswer((_) async => testRefreshToken);

      when(mockApiClient.refreshToken(testRefreshToken)).thenAnswer(
        (_) async => AuthResponseDto(
          accessToken: testNewAccessToken,
          refreshToken: testNewRefreshToken,
          userId: testUserId,
        ),
      );

      when(
        mockCredProvider.setAccessToken(testNewAccessToken),
      ).thenAnswer((_) async => {});

      when(
        mockCredProvider.setRefreshToken(testNewRefreshToken),
      ).thenAnswer((_) async => {});

      when(
        mockDio.fetch<dynamic>(any),
      ).thenAnswer((_) async => successResponse);

      // Act
      await interceptor.onError(dioError, mockErrorHandler);

      // Assert
      verify(mockCredProvider.getRefreshToken()).called(1);
      verify(mockApiClient.refreshToken(testRefreshToken)).called(1);
      verify(mockCredProvider.setAccessToken(testNewAccessToken)).called(1);
      verify(mockCredProvider.setRefreshToken(testNewRefreshToken)).called(1);
      verify(mockDio.fetch<dynamic>(any)).called(1);
      verify(mockErrorHandler.resolve(successResponse)).called(1);
    });

    test('should not handle non-401 errors', () async {
      // Arrange
      final otherError = DioException(
        requestOptions: requestOptions,
        response: Response(statusCode: 500, requestOptions: requestOptions),
        type: DioExceptionType.badResponse,
      );

      // Act
      await interceptor.onError(otherError, mockErrorHandler);

      // Assert
      verify(mockErrorHandler.next(otherError)).called(1);
      verifyNever(mockCredProvider.getRefreshToken());
      verifyNever(mockApiClient.refreshToken(any));
    });

    test('should propagate error when refresh token is missing', () async {
      // Arrange
      when(mockCredProvider.getRefreshToken()).thenAnswer((_) async => null);

      // Act
      await interceptor.onError(dioError, mockErrorHandler);

      // Assert
      verify(mockCredProvider.getRefreshToken()).called(1);
      verify(mockErrorHandler.next(dioError)).called(1);
      verifyNever(mockApiClient.refreshToken(any));
      verifyNever(mockDio.fetch<dynamic>(any));
    });

    test('should propagate error when token refresh fails', () async {
      // Arrange
      when(
        mockCredProvider.getRefreshToken(),
      ).thenAnswer((_) async => testRefreshToken);

      when(
        mockApiClient.refreshToken(testRefreshToken),
      ).thenThrow(AuthException.tokenExpired());

      // Act
      await interceptor.onError(dioError, mockErrorHandler);

      // Assert
      verify(mockCredProvider.getRefreshToken()).called(1);
      verify(mockApiClient.refreshToken(testRefreshToken)).called(1);
      verify(mockErrorHandler.next(dioError)).called(1);
      verifyNever(mockCredProvider.setAccessToken(any));
      verifyNever(mockCredProvider.setRefreshToken(any));
      verifyNever(mockDio.fetch<dynamic>(any));
    });
  });
}
