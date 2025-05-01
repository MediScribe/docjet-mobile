import 'package:docjet_mobile/core/utils/log_helpers.dart';

/// Utility class to reliably match API endpoints using regex patterns
///
/// This provides a consistent way to match endpoints regardless of
/// version prefixes, query parameters, or trailing slashes.
class ApiPathMatcher {
  static const String _tag = 'ApiPathMatcher';
  static final Logger _logger = LoggerFactory.getLogger(ApiPathMatcher);

  /// Precompiled regex for user profile path
  /// Matches /users/profile with optional:
  /// - Path prefix (like /v1/)
  /// - Trailing slash
  /// - Query parameters
  static final RegExp _profileRegex = RegExp(r'\/users\/profile(\/?(\?.*)?)?$');

  /// Matches paths that end with /users/profile
  ///
  /// This will match endpoints like:
  /// - /users/profile
  /// - /users/profile/ (with trailing slash)
  /// - /v1/users/profile
  /// - /api/v2/users/profile
  /// - /users/profile?param=value
  ///
  /// It's anchored at the end to avoid matching /users/profile/other-things
  static bool isUserProfile(String path) {
    final isMatch = _profileRegex.hasMatch(path);

    _logger.d(
      '$_tag Checking if path is user profile: $path, result: $isMatch',
    );

    return isMatch;
  }
}
