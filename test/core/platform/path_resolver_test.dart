import 'dart:io';

import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/src/path_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'path_resolver_test.mocks.dart';

@GenerateMocks([PathProvider])
void main() {
  group('PathResolver', () {
    late PathResolver pathResolver;
    late MockPathProvider mockPathProvider;
    late String mockDocsDir;

    setUp(() {
      mockPathProvider = MockPathProvider();
      mockDocsDir = '/mock/documents';
    });

    /// Helper to create a PathResolver with a custom file existence function
    PathResolver createResolver({required bool fileExists}) {
      return PathResolverImpl(
        pathProvider: mockPathProvider,
        fileExists: (path) async => fileExists,
      );
    }

    /// Helper to stub the docs dir for tests that need it
    void stubDocsDir() {
      when(
        mockPathProvider.getApplicationDocumentsDirectory(),
      ).thenAnswer((_) async => Directory(mockDocsDir));
    }

    test('resolves relative path to absolute using PathProvider', () async {
      pathResolver = createResolver(fileExists: true);
      stubDocsDir();
      final relativePath = 'audio/test.m4a';
      final expected = '/mock/documents/audio/test.m4a';
      final result = await pathResolver.resolve(relativePath);
      expect(result, expected);
    });

    test('returns absolute path if it exists', () async {
      pathResolver = createResolver(fileExists: true);
      final absolutePath = '/already/absolute/test.m4a';
      final result = await pathResolver.resolve(absolutePath, mustExist: true);
      expect(result, absolutePath);
    });

    test(
      'throws PathResolutionException if absolute path does not exist and mustExist is true',
      () async {
        pathResolver = createResolver(fileExists: false);
        final absolutePath = '/does/not/exist.m4a';
        expect(
          () => pathResolver.resolve(absolutePath, mustExist: true),
          throwsA(isA<PathResolutionException>()),
        );
      },
    );

    test(
      'throws PathResolutionException if relative path does not exist and mustExist is true',
      () async {
        pathResolver = createResolver(fileExists: false);
        stubDocsDir();
        final relativePath = 'audio/missing.m4a';
        expect(
          () => pathResolver.resolve(relativePath, mustExist: true),
          throwsA(isA<PathResolutionException>()),
        );
      },
    );

    test('handles subdirectories and platform-specific separators', () async {
      pathResolver = createResolver(fileExists: true);
      stubDocsDir();
      final relativePath = 'subdir\\file.m4a'; // Windows-style
      final expected = '/mock/documents/subdir/file.m4a';
      final result = await pathResolver.resolve(relativePath);
      expect(result, expected);
    });

    /// iOS/Android: POSIX absolute path is returned as-is if mustExist is false
    test('returns POSIX absolute path as-is (iOS/Android)', () async {
      pathResolver = createResolver(fileExists: true);
      final posixAbsolute = '/data/user/0/com.example.app/files/foo.txt';
      final result = await pathResolver.resolve(posixAbsolute);
      expect(result, posixAbsolute);
    });

    /// Relative path with mixed separators is normalized and joined
    test('normalizes and joins relative path with mixed separators', () async {
      pathResolver = createResolver(fileExists: true);
      stubDocsDir();
      final mixed = 'foo/bar\\baz/file.txt';
      final expected = '/mock/documents/foo/bar/baz/file.txt';
      final result = await pathResolver.resolve(mixed);
      expect(result, expected);
    });

    /// Path with .. and . is normalized
    test('normalizes path with .. and .', () async {
      pathResolver = createResolver(fileExists: true);
      stubDocsDir();
      final weird = 'foo/./bar/../baz/file.txt';
      final expected = '/mock/documents/foo/baz/file.txt';
      final result = await pathResolver.resolve(weird);
      expect(result, expected);
    });

    /// Path with trailing slash is normalized and joined
    test('normalizes and joins path with trailing slash', () async {
      pathResolver = createResolver(fileExists: true);
      stubDocsDir();
      final trailing = 'foo/bar/';
      final expected = '/mock/documents/foo/bar';
      final result = await pathResolver.resolve(trailing);
      expect(result, expected);
    });

    // Checks that PathResolver resolves a simple relative path
    test('resolves simple relative path', () async {
      pathResolver = createResolver(fileExists: true);
      stubDocsDir();
      final input = 'foo.txt';
      final result = await pathResolver.resolve(input);
      expect(result, endsWith('foo.txt'));
    });

    // Checks that PathResolver resolves a nested relative path
    test('resolves nested relative path', () async {
      pathResolver = createResolver(fileExists: true);
      stubDocsDir();
      final input = 'bar/baz.txt';
      final result = await pathResolver.resolve(input);
      expect(result, contains('bar'));
      expect(result, endsWith('baz.txt'));
    });

    // Checks that PathResolver returns absolute path as-is
    test('returns absolute path as-is', () async {
      pathResolver = createResolver(fileExists: true);
      final absPath = '/tmp/absolute.txt';
      final result = await pathResolver.resolve(absPath);
      expect(result, absPath);
    });

    // Checks that PathResolver throws for non-existent file if mustExist is true
    test('throws if mustExist is true and file does not exist', () async {
      pathResolver = createResolver(fileExists: false);
      stubDocsDir();
      final input = 'does_not_exist.txt';
      expect(
        () => pathResolver.resolve(input, mustExist: true),
        throwsA(isA<Exception>()),
      );
    });

    // Checks that PathResolver resolves subdirectory paths
    test('resolves subdirectory path', () async {
      pathResolver = createResolver(fileExists: true);
      stubDocsDir();
      final input = 'subdir/foo.txt';
      final result = await pathResolver.resolve(input);
      expect(result, contains('subdir'));
      expect(result, endsWith('foo.txt'));
    });

    // Checks that PathResolver normalizes redundant slashes
    test('normalizes redundant slashes', () async {
      pathResolver = createResolver(fileExists: true);
      stubDocsDir();
      final input = 'foo//bar///baz.txt';
      final result = await pathResolver.resolve(input);
      expect(result, contains('foo/bar/baz.txt'));
    });

    // Checks that PathResolver handles dot segments
    test('handles dot segments', () async {
      pathResolver = createResolver(fileExists: true);
      stubDocsDir();
      final input = './foo/../bar.txt';
      final result = await pathResolver.resolve(input);
      expect(result, endsWith('bar.txt'));
    });
  });
}
