import 'dart:convert';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

/// ⚠️ TEMPORARY HACK-TODO: Profile Endpoint Workaround ⚠️
///
/// This is a TEMPORARY solution to work around the missing /users/profile endpoint
/// on staging. This code will be REMOVED once the proper endpoint is implemented.
///
/// Instead of using /users/profile, this hack uses /users/{userId} which is already
/// available on the staging API.
class ProfileEndpointWorkaround {
  static final _logger = LoggerFactory.getLogger('ProfileEndpointWorkaround');
  static final _tag = logTag('ProfileEndpointWorkaround');

  /// Transforms /users/profile endpoint to /users/{userId}
  ///
  /// @param originalEndpoint The original endpoint path (should be users/profile)
  /// @param credentialsProvider The auth credentials provider to get userId or token
  /// @returns The transformed endpoint path
  static Future<String> transformProfileEndpoint(
    String originalEndpoint,
    AuthCredentialsProvider credentialsProvider,
  ) async {
    if (!originalEndpoint.contains('users/profile')) {
      _logger.w('$_tag Called with non-profile endpoint: $originalEndpoint');
      return originalEndpoint; // Return unchanged if not the profile endpoint
    }

    _logger.w(
      '$_tag ⚠️ USING TEMPORARY WORKAROUND for missing /users/profile endpoint ⚠️',
    );

    // Try to get userId from credentials first (most reliable)
    String? userId = await credentialsProvider.getUserId();

    // If we don't have userId stored, try to extract it from JWT
    if (userId == null || userId.isEmpty) {
      _logger.d('$_tag No stored userId, attempting to extract from JWT');
      userId = await _extractUserIdFromJwt(credentialsProvider);
    }

    if (userId == null || userId.isEmpty) {
      _logger.e('$_tag Failed to get userId for profile endpoint workaround');
      // If we can't get the userId, return the original endpoint as a fallback
      return originalEndpoint;
    }

    // Replace /users/profile with /users/{userId}
    final newEndpoint = originalEndpoint.replaceAll(
      'users/profile',
      'users/$userId',
    );
    _logger.i('$_tag Transformed endpoint: $originalEndpoint → $newEndpoint');

    return newEndpoint;
  }

  /// Extracts user ID from JWT token
  ///
  /// JWT tokens have a payload that includes user info like ID in the 'sub' claim
  static Future<String?> _extractUserIdFromJwt(
    AuthCredentialsProvider credentialsProvider,
  ) async {
    try {
      final token = await credentialsProvider.getAccessToken();
      if (token == null || token.isEmpty) {
        _logger.w('$_tag No access token available to extract userId');
        return null;
      }

      // Split the JWT - format is header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) {
        _logger.w('$_tag Invalid JWT format');
        return null;
      }

      // Decode the payload (middle part)
      String normalizedPayload = parts[1];
      // Add padding if needed
      while (normalizedPayload.length % 4 != 0) {
        normalizedPayload += '=';
      }

      // Decode from base64
      final payloadBytes = base64Url.decode(normalizedPayload);
      final payloadString = utf8.decode(payloadBytes);
      final payload = json.decode(payloadString) as Map<String, dynamic>;

      // Extract user ID from 'sub' claim
      final userId = payload['sub'] as String?;
      if (userId == null) {
        _logger.w('$_tag JWT payload does not contain "sub" claim');
        return null;
      }

      _logger.d('$_tag Successfully extracted userId from JWT: $userId');
      return userId;
    } catch (e) {
      _logger.e('$_tag Error extracting userId from JWT: $e');
      return null;
    }
  }
}
