import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:docjet_mobile/core/di/injection_container.dart' as di;
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logging
import 'package:docjet_mobile/main.dart' as app;
import 'package:flutter/foundation.dart'; // Import kDebugMode

void main() {
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
