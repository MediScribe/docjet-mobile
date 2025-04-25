import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:docjet_mobile/core/interfaces/app_config_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('AppConfig correctly loads environment values by default', () {
      // Because we can't easily set dart-defines in unit tests,
      // we expect the default values here.
      final AppConfigInterface config = AppConfig.fromEnvironment();
      expect(config.apiDomain, 'staging.docjet.ai'); // Default value
      expect(config.apiKey, ''); // Default value
    });

    test('AppConfig.development creates development config', () {
      final AppConfigInterface config = AppConfig.development();
      expect(config.apiDomain, 'localhost:8080');
      expect(config.apiKey, 'test-api-key');
      expect(config.isDevelopment, isTrue);
    });

    test(
      'AppConfig.fromEnvironment creates non-development config by default',
      () {
        final AppConfigInterface config = AppConfig.fromEnvironment();
        expect(config.isDevelopment, isFalse);
      },
    );

    test('toString method provides useful representation', () {
      final AppConfigInterface config = AppConfig.development();
      expect(
        config.toString(),
        'AppConfig(apiDomain: localhost:8080, apiKey: [REDACTED])',
      );

      final AppConfigInterface prodConfig = AppConfig.fromEnvironment();
      expect(
        prodConfig.toString(),
        'AppConfig(apiDomain: staging.docjet.ai, apiKey: [REDACTED])',
      );
    });

    // Add more tests later for development factory, toString, etc.
  });
}
