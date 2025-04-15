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
    late bool fileExists;

    setUp(() {
      mockPathProvider = MockPathProvider();
      mockDocsDir = '/mock/documents';
      fileExists = true;
    });

    /// Helper to create a PathResolver with a custom file existence function
    PathResolver createResolver() {
      return PathResolverImpl(
        pathProvider: mockPathProvider,
        fileExists: (path) async => fileExists,
      );
    }

    test('resolves relative path to absolute using PathProvider', () async {
      pathResolver = createResolver();
      when(
        mockPathProvider.getApplicationDocumentsDirectory(),
      ).thenAnswer((_) async => Directory(mockDocsDir));
      final relativePath = 'audio/test.m4a';
      final expected = '/mock/documents/audio/test.m4a';
      final result = await pathResolver.resolve(relativePath);
      expect(result, expected);
    });

    test('returns absolute path if it exists', () async {
      pathResolver = createResolver();
      final absolutePath = '/already/absolute/test.m4a';
      fileExists = true;
      final result = await pathResolver.resolve(absolutePath, mustExist: true);
      expect(result, absolutePath);
    });

    test(
      'throws PathResolutionException if absolute path does not exist and mustExist is true',
      () async {
        pathResolver = createResolver();
        final absolutePath = '/does/not/exist.m4a';
        fileExists = false;
        expect(
          () => pathResolver.resolve(absolutePath, mustExist: true),
          throwsA(isA<PathResolutionException>()),
        );
      },
    );

    test(
      'throws PathResolutionException if relative path does not exist and mustExist is true',
      () async {
        pathResolver = createResolver();
        when(
          mockPathProvider.getApplicationDocumentsDirectory(),
        ).thenAnswer((_) async => Directory(mockDocsDir));
        final relativePath = 'audio/missing.m4a';
        fileExists = false;
        expect(
          () => pathResolver.resolve(relativePath, mustExist: true),
          throwsA(isA<PathResolutionException>()),
        );
      },
    );

    test('handles subdirectories and platform-specific separators', () async {
      pathResolver = createResolver();
      when(
        mockPathProvider.getApplicationDocumentsDirectory(),
      ).thenAnswer((_) async => Directory(mockDocsDir));
      final relativePath = 'subdir\\file.m4a'; // Windows-style
      final expected = '/mock/documents/subdir/file.m4a';
      final result = await pathResolver.resolve(relativePath);
      expect(result, expected);
    });

    /// iOS/Android: POSIX absolute path is returned as-is if mustExist is false
    test('returns POSIX absolute path as-is (iOS/Android)', () async {
      pathResolver = createResolver();
      final posixAbsolute = '/data/user/0/com.example.app/files/foo.txt';
      final result = await pathResolver.resolve(posixAbsolute);
      expect(result, posixAbsolute);
    });

    /// Relative path with mixed separators is normalized and joined
    test('normalizes and joins relative path with mixed separators', () async {
      pathResolver = createResolver();
      when(
        mockPathProvider.getApplicationDocumentsDirectory(),
      ).thenAnswer((_) async => Directory(mockDocsDir));
      final mixed = 'foo/bar\\baz/file.txt';
      final expected = '/mock/documents/foo/bar/baz/file.txt';
      final result = await pathResolver.resolve(mixed);
      expect(result, expected);
    });

    /// Path with .. and . is normalized
    test('normalizes path with .. and .', () async {
      pathResolver = createResolver();
      when(
        mockPathProvider.getApplicationDocumentsDirectory(),
      ).thenAnswer((_) async => Directory(mockDocsDir));
      final weird = 'foo/./bar/../baz/file.txt';
      final expected = '/mock/documents/foo/baz/file.txt';
      final result = await pathResolver.resolve(weird);
      expect(result, expected);
    });

    /// Path with trailing slash is normalized and joined
    test('normalizes and joins path with trailing slash', () async {
      pathResolver = createResolver();
      when(
        mockPathProvider.getApplicationDocumentsDirectory(),
      ).thenAnswer((_) async => Directory(mockDocsDir));
      final trailing = 'foo/bar/';
      final expected = '/mock/documents/foo/bar';
      final result = await pathResolver.resolve(trailing);
      expect(result, expected);
    });
  });
}
