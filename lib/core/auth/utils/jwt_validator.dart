import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// A utility class for validating JWT tokens.
///
/// IMPORTANT CAVEATS WITH JWT HANDLING:
/// 1. This implementation manually checks the 'exp' claim instead of using JwtDecoder.isExpired()
///    which has known issues:
///    - JwtDecoder.isExpired() has zero clock-skew tolerance
///    - It fails if 'exp' is provided as a string (common in non-RFC 7519 implementations)
///    - It throws FormatException on malformed tokens instead of returning a boolean
///
/// 2. JwtDecoder intentionally ignores signatures - we're only validating expiry locally
///    - This is sufficient for our offline flow where tokens came from our own server
///    - For signature validation, consider using dart_jsonwebtoken's JWT.verify() method
///
/// 3. The current implementation handles various 'exp' claim types (int, String, double)
///    for maximum compatibility
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
    _logger.d('$_tag Attempting to validate token: ${token ?? "NULL"}');
    if (token == null) {
      _logger.e('$_tag Validation failed: Token is null.');
      throw ArgumentError.notNull('token');
    }
    try {
      // Manually decode JWT payload to check the 'exp' claim
      final Map<String, dynamic> payload = JwtDecoder.decode(token);
      if (!payload.containsKey('exp')) {
        _logger.w('$_tag Validation failed: Missing \'exp\' claim.');
        return true;
      }
      final dynamic expClaim = payload['exp'];
      late final int expSeconds;
      if (expClaim is int) {
        expSeconds = expClaim;
      } else if (expClaim is String) {
        expSeconds = int.tryParse(expClaim) ?? -1;
      } else if (expClaim is double) {
        expSeconds = expClaim.toInt();
      } else {
        _logger.e('$_tag Validation failed: Invalid \'exp\' claim type.');
        return true;
      }
      final int currentSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final bool isExpired = currentSeconds >= expSeconds;
      _logger.d(
        '$_tag expSeconds: $expSeconds, currentSeconds: $currentSeconds',
      );
      if (isExpired) {
        _logger.w('$_tag Validation result: Token IS expired (custom check).');
      } else {
        _logger.d(
          '$_tag Validation result: Token is NOT expired (custom check).',
        );
      }
      return isExpired;
    } on FormatException catch (e, stackTrace) {
      _logger.e(
        '$_tag Validation failed: Invalid token format.',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error during JWT validation, treating as expired.',
        error: e,
        stackTrace: stackTrace,
      );
      return true;
    }
  }
}
