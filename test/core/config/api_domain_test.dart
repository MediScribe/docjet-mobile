import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/config/api_config.dart';
import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  group('API Domain Configuration', () {
    setUp(() {
      // Register AppConfig in GetIt
      if (!GetIt.instance.isRegistered<AppConfig>()) {
        GetIt.instance.registerSingleton<AppConfig>(
          // Use a specific test config, don't rely on environment defaults
          AppConfig.test(
            apiDomain: 'test-staging.docjet.ai',
            apiKey: 'test-key',
          ),
        );
      }
    });

    tearDown(() async {
      // Clean up - unregister AppConfig
      if (GetIt.instance.isRegistered<AppConfig>()) {
        await GetIt.instance.unregister<AppConfig>();
      }
    });

    test('DioFactory uses API_DOMAIN from injected AppConfig', () {
      // Arrange: Get the registered AppConfig
      final appConfig = GetIt.instance<AppConfig>();
      // Instantiate the factory with the config from GetIt
      final dioFactory = DioFactory(appConfig: appConfig);

      // Act: Get the Dio instance using the factory instance
      final dio = dioFactory.createBasicDio();

      // Assert: Check against the specific domain used in setUp
      expect(
        dio.options.baseUrl,
        ApiConfig.baseUrlFromDomain('test-staging.docjet.ai'),
      );
      expect(dio.options.baseUrl, startsWith('https://'));
    });

    test('ApiConfig selects correct protocol based on domain', () {
      // Test localhost domains use http://
      final localhostUrl = ApiConfig.baseUrlFromDomain('localhost:8080');
      expect(localhostUrl, startsWith('http://'));
      expect(localhostUrl, 'http://localhost:8080/api/v1/');

      // Test IP addresses use http://
      final ipUrl = ApiConfig.baseUrlFromDomain('127.0.0.1:3000');
      expect(ipUrl, startsWith('http://'));
      expect(ipUrl, 'http://127.0.0.1:3000/api/v1/');

      // Test regular domains use https://
      final regularUrl = ApiConfig.baseUrlFromDomain('api.docjet.com');
      expect(regularUrl, startsWith('https://'));
      expect(regularUrl, 'https://api.docjet.com/api/v1/');

      // Test mock server domain (may be used in scripts)
      final mockServerUrl = ApiConfig.baseUrlFromDomain('localhost:8080');
      expect(mockServerUrl, startsWith('http://'));
      expect(mockServerUrl, 'http://localhost:8080/api/v1/');
    });

    test('ApiConfig handles domains with port correctly', () {
      final urlWithPort = ApiConfig.baseUrlFromDomain('dev.docjet.com:8080');
      expect(urlWithPort, 'https://dev.docjet.com:8080/api/v1/');

      final urlWithPortLocalhost = ApiConfig.baseUrlFromDomain(
        'localhost:9000',
      );
      expect(urlWithPortLocalhost, 'http://localhost:9000/api/v1/');
    });

    test('run_with_mock.sh integration', () {
      // Documentation test for how run_with_mock.sh should be structured
      // This verifies the expected environment variable configuration

      // Expected command structure:
      // flutter run --dart-define=API_KEY=mock-key --dart-define=API_DOMAIN=localhost:8080

      const mockServerDomain = 'localhost:8080';
      final expectedBaseUrl = ApiConfig.baseUrlFromDomain(mockServerDomain);

      expect(expectedBaseUrl, 'http://localhost:8080/api/v1/');
    });
  });
}
