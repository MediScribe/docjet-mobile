import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

void main() {
  group('ApiConfig', () {
    test('apiVersion should be v1', () {
      expect(ApiConfig.apiVersion, 'v1');
    });

    test('baseUrlFromDomain constructs URLs correctly', () {
      // Test with localhost
      expect(
        ApiConfig.baseUrlFromDomain('localhost:8080'),
        'http://localhost:8080/api/v1/', // Note trailing slash
      );

      // Test with IP address
      expect(
        ApiConfig.baseUrlFromDomain('127.0.0.1:8080'),
        'http://127.0.0.1:8080/api/v1/', // Note trailing slash
      );

      // Test with dev domain
      expect(
        ApiConfig.baseUrlFromDomain('dev.docjet.com'),
        'https://dev.docjet.com/api/v1/', // Note trailing slash
      );

      // Test with production domain
      expect(
        ApiConfig.baseUrlFromDomain('api.docjet.com'),
        'https://api.docjet.com/api/v1/', // Note trailing slash
      );
    });

    test('joinPaths handles slashes correctly', () {
      // Test with base having trailing slash and path having leading slash
      expect(
        ApiConfig.joinPaths('https://api.example.com/', '/path/to/resource'),
        'https://api.example.com/path/to/resource',
      );

      // Test with base having no trailing slash and path having no leading slash
      expect(
        ApiConfig.joinPaths('https://api.example.com', 'path/to/resource'),
        'https://api.example.com/path/to/resource',
      );

      // Test with base having no trailing slash and path having leading slash
      expect(
        ApiConfig.joinPaths('https://api.example.com', '/path/to/resource'),
        'https://api.example.com/path/to/resource',
      );

      // Test with base having trailing slash and path having no leading slash
      expect(
        ApiConfig.joinPaths('https://api.example.com/', 'path/to/resource'),
        'https://api.example.com/path/to/resource',
      );

      // Test with API paths
      expect(
        ApiConfig.joinPaths('https://api.example.com/api/v1', 'auth/login'),
        'https://api.example.com/api/v1/auth/login',
      );

      // Test with multiple segments and combination of slashes
      expect(
        ApiConfig.joinPaths('https://api.example.com/api/v1/', '/auth/login/'),
        'https://api.example.com/api/v1/auth/login/',
      );
    });

    test('endpoint methods return unprefixed paths', () {
      expect(ApiConfig.loginEndpoint, 'auth/login');
      expect(ApiConfig.refreshEndpoint, 'auth/refresh-session');
      expect(ApiConfig.jobsEndpoint, 'jobs');
      expect(ApiConfig.jobEndpoint('job-123'), 'jobs/job-123');
      expect(
        ApiConfig.jobDocumentsEndpoint('job-123'),
        'jobs/job-123/documents',
      );
      expect(ApiConfig.healthEndpoint, 'health');
    });

    test('fullEndpoint methods return fully prefixed URLs', () {
      const domain = 'api.docjet.com';

      expect(
        ApiConfig.fullLoginEndpoint(domain),
        'https://api.docjet.com/api/v1/auth/login',
      );

      expect(
        ApiConfig.fullRefreshEndpoint(domain),
        'https://api.docjet.com/api/v1/auth/refresh-session',
      );

      expect(
        ApiConfig.fullJobsEndpoint(domain),
        'https://api.docjet.com/api/v1/jobs',
      );

      expect(
        ApiConfig.fullJobEndpoint(domain, 'job-123'),
        'https://api.docjet.com/api/v1/jobs/job-123',
      );

      expect(
        ApiConfig.fullJobDocumentsEndpoint(domain, 'job-123'),
        'https://api.docjet.com/api/v1/jobs/job-123/documents',
      );

      expect(
        ApiConfig.fullHealthEndpoint(domain),
        'https://api.docjet.com/api/v1/health',
      );
    });

    test('ApiConfig constructs URLs without double slashes', () {
      expect(
        ApiConfig.fullLoginEndpoint('staging.docjet.ai'),
        'https://staging.docjet.ai/api/v1/auth/login',
      ); // Should not have double slash
    });

    test('endpoints work correctly with Dio URL resolution', () {
      // This test verifies that endpoints are correctly resolved when used with Dio
      // First, set up Dio with a base URL that includes the api/v1 prefix
      final dio = Dio(BaseOptions(baseUrl: 'https://api.docjet.com/api/v1/'));

      // Create a request URL using ApiConfig.loginEndpoint (which doesn't have a leading slash)
      final requestOptions = RequestOptions(
        path: ApiConfig.loginEndpoint,
        baseUrl: dio.options.baseUrl,
      );

      // Verify that the resolved URL is correct
      // This is how Dio internally builds the URL
      final resolvedUrl = requestOptions.uri.toString();

      // The URL should be correctly formed
      expect(
        resolvedUrl,
        equals('https://api.docjet.com/api/v1/auth/login'),
        reason: 'Endpoint should resolve correctly with Dio url resolution',
      );

      // Try with trailing slash mismatches too (baseUrl with trailing but endpoint without leading)
      final dioWithTrailingSlash = Dio(
        BaseOptions(
          baseUrl: 'https://api.docjet.com/api/v1/', // Note trailing slash
        ),
      );

      final requestOptionsWithSlash = RequestOptions(
        path: ApiConfig.loginEndpoint, // No leading slash
        baseUrl: dioWithTrailingSlash.options.baseUrl,
      );

      final resolvedUrlWithSlash = requestOptionsWithSlash.uri.toString();

      // Should still build the correct URL
      expect(
        resolvedUrlWithSlash,
        equals('https://api.docjet.com/api/v1/auth/login'),
        reason:
            'Endpoint should resolve correctly even with trailing slash in baseUrl',
      );
    });
  });
}
