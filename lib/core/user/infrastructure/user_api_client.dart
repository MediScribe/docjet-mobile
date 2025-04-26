import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:docjet_mobile/core/user/infrastructure/dtos/user_profile_dto.dart';

/// Client responsible for authenticated user-related API calls
///
/// This client specializes in endpoints that require authentication, specifically
/// those related to user profile management. It works exclusively with the
/// authenticatedDio instance which has JWT token management configured.
///
/// Design note: This class is part of the Split Client pattern where:
/// - AuthenticationApiClient handles pre-authentication operations (login/refresh)
/// - UserApiClient handles authenticated user operations (profile/settings)
///
/// This separation ensures clear responsibilities and proper authentication flow.
class UserApiClient {
  /// HTTP client configured with authentication interceptors
  ///
  /// This MUST be the authenticatedDio instance that includes the AuthInterceptor
  /// for JWT token management. Using basicDio will result in auth failures.
  final Dio authenticatedHttpClient;

  /// Provider for authentication credentials
  final AuthCredentialsProvider credentialsProvider;

  /// Creates a new UserApiClient
  ///
  /// @param authenticatedHttpClient A Dio instance with authentication interceptors
  /// @param credentialsProvider Provider for accessing authentication credentials
  UserApiClient({
    required this.authenticatedHttpClient,
    required this.credentialsProvider,
  });

  /// Fetches the authenticated user's profile
  ///
  /// This is an authenticated endpoint that requires a valid JWT token.
  /// The authenticatedHttpClient automatically handles token injection and
  /// refresh flow if needed.
  ///
  /// @throws DioException with specific error context:
  ///   - DioExceptionType.badResponse - For HTTP errors (401, 403, etc)
  ///   - DioExceptionType.connectionError - For network connectivity issues
  ///   - DioExceptionType.unknown - For unexpected errors
  ///
  /// @returns UserProfileDto containing the user's profile information
  Future<UserProfileDto> getUserProfile() async {
    try {
      final response = await authenticatedHttpClient.get(
        ApiConfig.userProfileEndpoint,
      );

      if (response.statusCode == 200) {
        return UserProfileDto.fromJson(response.data);
      }

      throw DioException(
        requestOptions: RequestOptions(path: ApiConfig.userProfileEndpoint),
        error: 'Failed to get user profile. Status: ${response.statusCode}',
        type: DioExceptionType.badResponse,
        response: response,
      );
    } on DioException catch (e) {
      // Add more context to Dio exceptions before rethrowing
      if (e.type == DioExceptionType.connectionError) {
        throw DioException(
          requestOptions: e.requestOptions,
          error: 'Network error while fetching user profile: ${e.message}',
          type: e.type,
          response: e.response,
        );
      }

      // Handle authentication-specific errors
      if (e.response?.statusCode == 401) {
        throw DioException(
          requestOptions: e.requestOptions,
          error:
              'Authentication failed while fetching user profile. JWT token may be invalid.',
          type: e.type,
          response: e.response,
        );
      }

      rethrow;
    } catch (e) {
      // Wrap other exceptions in a DioException with clear context
      throw DioException(
        requestOptions: RequestOptions(path: ApiConfig.userProfileEndpoint),
        error: 'Unexpected error getting user profile: $e',
        type: DioExceptionType.unknown,
      );
    }
  }
}
