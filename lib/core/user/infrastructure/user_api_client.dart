import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_exception.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:docjet_mobile/core/network/connectivity_error.dart';
import 'package:docjet_mobile/core/user/infrastructure/hack_profile_endpoint_workaround.dart';
import 'package:docjet_mobile/core/user/infrastructure/dtos/user_profile_dto.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

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
  /// Logger for UserApiClient
  final _logger = LoggerFactory.getLogger('UserApiClient');
  final _tag = logTag('UserApiClient');

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

  /// Checks if a specific DioException type represents a network connectivity issue
  ///
  /// Returns true for connection errors and timeouts that typically occur when
  /// the device is offline or the server is unreachable.
  bool _isConnectivityError(DioExceptionType type) {
    return isNetworkConnectivityError(type);
  }

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
  /// @throws AuthException.offlineOperationFailed for connectivity issues
  ///
  /// @returns UserProfileDto containing the user's profile information
  Future<UserProfileDto> getUserProfile() async {
    // Get the endpoint path once, either default or from workaround
    final endpointPath = await _resolveProfileEndpoint();

    _logger.d('$_tag Getting user profile from $endpointPath');

    try {
      _logger.d('$_tag Making request with authenticatedHttpClient');
      final response = await authenticatedHttpClient.get(endpointPath);

      if (response.statusCode == 200) {
        _logger.d('$_tag Received 200 response, parsing user profile data');
        try {
          // Ensure we have a proper Map<String, dynamic> for JSON deserialization
          final responseData = Map<String, dynamic>.from(response.data as Map);
          _logger.d(
            '$_tag Successfully converted response data to Map<String, dynamic>',
          );

          return UserProfileDto.fromJson(responseData);
        } catch (e) {
          _logger.e('$_tag Data conversion error: ${e.toString()}');
          throw DioException(
            requestOptions: RequestOptions(path: endpointPath),
            error:
                'Failed to parse user profile data: ${e.toString()}. '
                'Expected JSON map with keys "id", "email", etc.',
            type: DioExceptionType.unknown,
          );
        }
      }

      _logger.w('$_tag Received non-200 status code: ${response.statusCode}');
      throw DioException(
        requestOptions: RequestOptions(path: endpointPath),
        error: 'Failed to get user profile. Status: ${response.statusCode}',
        type: DioExceptionType.badResponse,
        response: response,
      );
    } on DioException catch (e) {
      // Classify connectivity errors as offline operations
      if (_isConnectivityError(e.type)) {
        _logger.w('$_tag Network connectivity error: ${e.type} - ${e.message}');
        // Use custom message with context but with the offlineOperation error type
        final exception = AuthException.offlineOperationFailed(e.stackTrace);
        // Log the original message for debugging purposes
        _logger.i('$_tag Original error message: ${e.message}');
        throw exception;
      }

      // Handle authentication-specific errors
      if (e.response?.statusCode == 401) {
        _logger.e('$_tag Authentication failed (401 Unauthorized)');
        throw DioException(
          requestOptions: e.requestOptions,
          error:
              'Authentication failed while fetching user profile. JWT token may be invalid or missing.',
          type: e.type,
          response: e.response,
        );
      }

      _logger.e('$_tag Dio exception: ${e.type} - ${e.message}');
      rethrow;
    } catch (e) {
      // Wrap other exceptions in a DioException with clear context
      _logger.e('$_tag Unexpected error: ${e.toString()}');
      throw DioException(
        requestOptions: RequestOptions(path: endpointPath),
        error: 'Unexpected error getting user profile: ${e.toString()}',
        type: DioExceptionType.unknown,
      );
    }
  }

  /// ⚠️ TEMPORARY HACK-TODO: Resolves the profile endpoint
  ///
  /// Either returns the standard endpoint from ApiConfig or uses the workaround
  /// to get a user-specific endpoint. Tests will still work because they mock
  /// the HTTP call, not this internal method.
  Future<String> _resolveProfileEndpoint() async {
    // HACK-TODO: This is a temporary workaround for the missing /users/profile endpoint
    // TODO: Remove this workaround once the proper endpoint is implemented
    return ProfileEndpointWorkaround.transformProfileEndpoint(
      ApiConfig.userProfileEndpoint,
      credentialsProvider,
    );

    // Standard endpoint - uncomment this and remove the above when API is fixed:
    // return ApiConfig.userProfileEndpoint;
  }
}
