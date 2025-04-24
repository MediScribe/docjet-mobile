import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('API Domain Configuration', () {
    test('DioFactory uses API_DOMAIN from environment', () {
      // We can't directly set environment variables in tests,
      // but we can check that DioFactory is properly using String.fromEnvironment
      // for API_DOMAIN, with appropriate defaults

      // Get the Dio instance from the factory
      final dio = DioFactory.createBasicDio();

      // Without explicitly setting API_DOMAIN, it should use the default
      expect(
        dio.options.baseUrl,
        ApiConfig.baseUrlFromDomain('staging.docjet.ai'),
      );

      // The baseUrl should use https:// for non-localhost domains
      expect(dio.options.baseUrl, startsWith('https://'));
    });

    test('ApiConfig selects correct protocol based on domain', () {
      // Test localhost domains use http://
      final localhostUrl = ApiConfig.baseUrlFromDomain('localhost:8080');
      expect(localhostUrl, startsWith('http://'));
      expect(localhostUrl, 'http://localhost:8080/api/v1');

      // Test IP addresses use http://
      final ipUrl = ApiConfig.baseUrlFromDomain('127.0.0.1:3000');
      expect(ipUrl, startsWith('http://'));
      expect(ipUrl, 'http://127.0.0.1:3000/api/v1');

      // Test regular domains use https://
      final regularUrl = ApiConfig.baseUrlFromDomain('api.docjet.com');
      expect(regularUrl, startsWith('https://'));
      expect(regularUrl, 'https://api.docjet.com/api/v1');

      // Test mock server domain (may be used in scripts)
      final mockServerUrl = ApiConfig.baseUrlFromDomain('localhost:8080');
      expect(mockServerUrl, startsWith('http://'));
      expect(mockServerUrl, 'http://localhost:8080/api/v1');
    });

    test('ApiConfig handles domains with port correctly', () {
      final urlWithPort = ApiConfig.baseUrlFromDomain('dev.docjet.com:8080');
      expect(urlWithPort, 'https://dev.docjet.com:8080/api/v1');

      final urlWithPortLocalhost = ApiConfig.baseUrlFromDomain(
        'localhost:9000',
      );
      expect(urlWithPortLocalhost, 'http://localhost:9000/api/v1');
    });

    test('run_with_mock.sh integration', () {
      // Documentation test for how run_with_mock.sh should be structured
      // This verifies the expected environment variable configuration

      // Expected command structure:
      // flutter run --dart-define=API_KEY=mock-key --dart-define=API_DOMAIN=localhost:8080

      final mockServerDomain = 'localhost:8080';
      final expectedBaseUrl = ApiConfig.baseUrlFromDomain(mockServerDomain);

      expect(expectedBaseUrl, 'http://localhost:8080/api/v1');
    });
  });
}
