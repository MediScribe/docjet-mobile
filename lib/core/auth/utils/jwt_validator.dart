import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// A utility class for validating JWT tokens.
class JwtValidator {
  // Get a logger for this specific class
  final Logger _logger = LoggerFactory.getLogger(JwtValidator);
  static final String _tag = logTag(JwtValidator);

  /// Checks if the given JWT token has expired.
  ///
  /// Returns `true` if the token is expired or does not contain an expiry claim,
  /// `false` otherwise.
  ///
  /// Throws [ArgumentError] if the token is null.
  /// Throws [FormatException] if the token string is invalid.
  bool isTokenExpired(String? token) {
    if (token == null) {
      // No logger needed here, throwing is sufficient
      throw ArgumentError.notNull('token');
    }
    try {
      return JwtDecoder.isExpired(token);
    } on FormatException {
      // Re-throw FormatException for invalid tokens
      // Let the caller handle logging if necessary
      rethrow;
    } catch (e, stackTrace) {
      // Catch any other potential exceptions from JwtDecoder
      // and treat the token as expired for safety.
      // Log the unexpected error.
      _logger.e(
        '$_tag Unexpected error validating JWT token',
        error: e,
        stackTrace: stackTrace,
      );
      return true;
    }
  }
}
