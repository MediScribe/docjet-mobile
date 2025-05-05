import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:docjet_mobile/core/di/injection_container.dart' as di;
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logging
import 'package:docjet_mobile/main.dart' as app;
import 'package:flutter/foundation.dart'; // Import kDebugMode
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/widgets.dart'; // For WidgetsFlutterBinding
import 'dart:io' show Platform;

Future<void> main() async {
  // Ensure binding for plugin access before calling FlutterSecureStorage
  WidgetsFlutterBinding.ensureInitialized();

  // --- Optional purge of auth tokens when requested via --dart-define ---
  const purgeFlagConst = bool.fromEnvironment(
    'PURGE_TOKENS',
    defaultValue: false,
  );
  final purgeFlagRuntime = Platform.environment['PURGE_TOKENS'] == 'true';
  final shouldPurgeTokens = purgeFlagConst || purgeFlagRuntime;

  if (shouldPurgeTokens) {
    final logger = LoggerFactory.getLogger('main_dev');
    logger.i('[main_dev] PURGE_TOKENS flag is true – deleting stored JWTs.');

    const storage = FlutterSecureStorage();
    try {
      await storage.delete(key: 'accessToken');
      await storage.delete(key: 'refreshToken');
      await storage.delete(key: 'userId');
      logger.i(
        '[main_dev] Successfully purged all tokens from secure storage.',
      );
    } catch (e) {
      logger.e('[main_dev] Error purging tokens from secure storage: $e');
      // Continue app startup despite token purge failure
    }
  }

  // Continue with normal init
  final logger = LoggerFactory.getLogger('main_dev');
  final tag = logTag('main_dev');

  // --- Setup Development Overrides ---
  // Set the overrides BEFORE calling the main app's initialization sequence.
  di.overrides = [
    () {
      // Unregister default if already registered (e.g., during hot restart)
      if (di.sl.isRegistered<AppConfig>()) {
        di.sl.unregister<AppConfig>();
      }
      // Register the development configuration
      di.sl.registerSingleton<AppConfig>(AppConfig.development());
      logger.i(
        '$tag Registered AppConfig override: ${AppConfig.development()}',
      );
    },
    // Add other overrides here if needed for development
  ];

  logger.i(
    '$tag *** OVERRIDES SET in main_dev.dart. Count: ${di.overrides.length} ***',
  );

  if (kDebugMode) {
    logger.i(
      '$tag Running in DEVELOPMENT mode with mock server configuration via main_dev.dart',
    );
  }

  // --- Start the main application ---
  // The regular main() function will now use the overrides when it calls di.init()
  // (assuming we implement step 5c correctly).
  app.main();
}
