import 'package:docjet_mobile/core/auth/utils/api_path_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiPathMatcher', () {
    group('isUserProfile', () {
      test('matches basic user profile path', () {
        expect(ApiPathMatcher.isUserProfile('/users/profile'), isTrue);
      });

      test('matches versioned user profile paths', () {
        expect(ApiPathMatcher.isUserProfile('/v1/users/profile'), isTrue);
        expect(ApiPathMatcher.isUserProfile('/v2/users/profile'), isTrue);
        expect(ApiPathMatcher.isUserProfile('/api/v1/users/profile'), isTrue);
        expect(ApiPathMatcher.isUserProfile('/api/v2/users/profile'), isTrue);
      });

      test('matches user profile paths with query parameters', () {
        expect(
          ApiPathMatcher.isUserProfile('/users/profile?param=value'),
          isTrue,
        );
        expect(
          ApiPathMatcher.isUserProfile('/v1/users/profile?param=value'),
          isTrue,
        );
        expect(
          ApiPathMatcher.isUserProfile('/users/profile?param=value&other=123'),
          isTrue,
        );
      });

      test('does not match paths that continue after profile', () {
        expect(ApiPathMatcher.isUserProfile('/users/profile/details'), isFalse);
        expect(
          ApiPathMatcher.isUserProfile('/v1/users/profile/avatar'),
          isFalse,
        );
      });

      test('does not match unrelated paths', () {
        expect(ApiPathMatcher.isUserProfile('/users'), isFalse);
        expect(ApiPathMatcher.isUserProfile('/users/settings'), isFalse);
        expect(ApiPathMatcher.isUserProfile('/profile'), isFalse);
        expect(ApiPathMatcher.isUserProfile('/api/users'), isFalse);
      });
    });
  });
}
