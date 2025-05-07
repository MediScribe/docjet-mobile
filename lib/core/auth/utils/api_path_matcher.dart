import 'package:docjet_mobile/core/utils/log_helpers.dart';

/// Utility class to reliably match API endpoints using regex patterns
///
/// This provides a consistent way to match endpoints regardless of
/// version prefixes, query parameters, or trailing slashes.
class ApiPathMatcher {
  static const String _tag = 'ApiPathMatcher';
  static final Logger _logger = LoggerFactory.getLogger(ApiPathMatcher);

  /// Precompiled regex for user profile path
  /// Matches /users/me with optional:
  /// - Path prefix (like /v1/)
  /// - Trailing slash
  /// - Query parameters
  static final RegExp _profileRegex = RegExp(r'^.*\/users\/me(\/?(\?.*)?)?$');

  /// Matches paths that end with /users/me
  ///
  /// This will match endpoints like:
  /// - /users/me
  /// - /users/me/ (with trailing slash)
  /// - /v1/users/me
  /// - /api/v2/users/me
  /// - /users/me?param=value
  ///
  /// It's anchored at the end to avoid matching /users/me/other-things
  static bool isUserProfile(String path) {
    final isMatch = _profileRegex.hasMatch(path);

    _logger.d(
      '$_tag Checking if path is user profile: $path, result: $isMatch',
    );

    return isMatch;
  }
}
