import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiConfig', () {
    test('apiVersion should be v1', () {
      expect(ApiConfig.apiVersion, 'v1');
    });

    test('baseUrlFromDomain constructs URLs correctly', () {
      // Test with localhost
      expect(
        ApiConfig.baseUrlFromDomain('localhost:8080'),
        'http://localhost:8080/api/v1',
      );

      // Test with IP address
      expect(
        ApiConfig.baseUrlFromDomain('127.0.0.1:8080'),
        'http://127.0.0.1:8080/api/v1',
      );

      // Test with dev domain
      expect(
        ApiConfig.baseUrlFromDomain('dev.docjet.com'),
        'https://dev.docjet.com/api/v1',
      );

      // Test with production domain
      expect(
        ApiConfig.baseUrlFromDomain('api.docjet.com'),
        'https://api.docjet.com/api/v1',
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
  });
}
