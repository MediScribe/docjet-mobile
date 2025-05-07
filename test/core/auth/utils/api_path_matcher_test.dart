import 'package:docjet_mobile/core/auth/utils/api_path_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiPathMatcher', () {
    group('isUserProfile', () {
      test('matches basic user profile path', () {
        expect(ApiPathMatcher.isUserProfile('/users/me'), isTrue);
      });

      test('matches versioned user profile paths', () {
        expect(ApiPathMatcher.isUserProfile('/v1/users/me'), isTrue);
        expect(ApiPathMatcher.isUserProfile('/v2/users/me'), isTrue);
        expect(ApiPathMatcher.isUserProfile('/api/v1/users/me'), isTrue);
        expect(ApiPathMatcher.isUserProfile('/api/v2/users/me'), isTrue);
      });

      test('matches user profile paths with query parameters', () {
        expect(ApiPathMatcher.isUserProfile('/users/me?param=value'), isTrue);
        expect(
          ApiPathMatcher.isUserProfile('/v1/users/me?param=value'),
          isTrue,
        );
        expect(
          ApiPathMatcher.isUserProfile('/users/me?param=value&other=123'),
          isTrue,
        );
        expect(
          ApiPathMatcher.isUserProfile('/api/v3/users/me?foo=bar&complex=true'),
          isTrue,
        );
      });

      test('does not match paths that continue after profile', () {
        expect(ApiPathMatcher.isUserProfile('/users/me/details'), isFalse);
        expect(ApiPathMatcher.isUserProfile('/v1/users/me/avatar'), isFalse);
      });

      test('does not match unrelated paths', () {
        expect(ApiPathMatcher.isUserProfile('/users'), isFalse);
        expect(ApiPathMatcher.isUserProfile('/users/settings'), isFalse);
        expect(ApiPathMatcher.isUserProfile('/me'), isFalse);
        expect(ApiPathMatcher.isUserProfile('/api/users'), isFalse);
      });
    });
  });
}
