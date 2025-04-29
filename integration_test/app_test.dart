// This file contains End-to-End (E2E) tests for the DocJet Mobile app UI.
// It uses the 'integration_test' package to drive the app on a device/emulator.
// IMPORTANT: These tests rely on a mock API server being run externally.
// Use the './run_e2e_tests.sh' script to launch the tests and manage the server.

// Remove dotenv import
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv

// Import the main app entry point. Make sure it can be configured
// (e.g., via environment variables or passed params) to use the mock server.
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart'; // Import User entity
import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:docjet_mobile/core/di/injection_container.dart' as di;
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import log helpers
import 'package:docjet_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/main.dart' as app;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';

// Import the generated mocks
import 'app_test.mocks.dart';

// GetIt instance
final sl = di.sl;

// We create our own version of MyApp rather than using the one from main.dart
// This lets us control the environment and providers precisely
// REMOVED TestApp - no longer needed with explicit DI test setups

// Annotate classes to generate mocks for
@GenerateMocks([AuthService, AuthEventBus, JobListCubit])
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Declare mocks - these will be instantiated per test as needed
  // late MockAuthService mockAuthService;
  // late MockAuthEventBus mockAuthEventBus;
  // late MockJobListCubit mockJobListCubit;

  // REMOVED setUpAll - Global mocks registered via sl are an anti-pattern
  // setUpAll(() async {
  //   // ... removed sl registration logic ...
  // });

  // REMOVED - This test relied on the removed TestApp and global sl setup.
  // We can test the fundamental app launch within other tests that use the real app structure.
  // testWidgets('App launches and finds initial MaterialApp widget', (
  //   WidgetTester tester,
  // ) async {
  //   // ... removed test logic ...
  // });

  setUp(() {
    // Reset GetIt before each test
    GetIt.I.reset();
    // Clear overrides before each test
    di.overrides = [];
  });

  testWidgets('App initializes and shows LoginScreen', (
    WidgetTester tester,
  ) async {
    // Arrange: Create mocks
    final mockAuthService = MockAuthService();
    final mockAuthEventBus =
        MockAuthEventBus(); // Create separate mock for event bus

    // Arrange: Configure mock behaviors
    when(
      mockAuthService.isAuthenticated(
        validateTokenLocally: anyNamed('validateTokenLocally'),
      ),
    ).thenAnswer((_) async => false); // Assume not authenticated
    when(
      mockAuthService.getUserProfile(),
    ).thenAnswer((_) => Future.value(const User(id: 'mock-user-id')));
    // No need to stub mockAuthService.authEventBus here
    when(
      mockAuthEventBus.stream,
    ).thenAnswer((_) => const Stream.empty()); // Stub the event bus stream

    // Arrange: Set up DI overrides BEFORE calling init()
    di.overrides = [
      () {
        // Override AuthService
        if (di.sl.isRegistered<AuthService>()) {
          di.sl.unregister<AuthService>();
        }
        di.sl.registerSingleton<AuthService>(mockAuthService);

        // Override AuthEventBus
        if (di.sl.isRegistered<AuthEventBus>()) {
          di.sl.unregister<AuthEventBus>();
        }
        di.sl.registerSingleton<AuthEventBus>(mockAuthEventBus);
      },
    ];

    // Arrange: Initialize dependencies, applying overrides
    await di.init();

    // Act: Build our actual app and trigger a frame.
    // Use the SAME mock instance for the Riverpod provider override
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          // Override the authEventBusProvider to provide the mocked event bus
          authEventBusProvider.overrideWithValue(mockAuthEventBus),
        ],
        child: const app.MyApp(),
      ),
    );
    await tester.pumpAndSettle(); // Wait for animations/transitions

    // Assert: Verify that the LoginScreen is displayed
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Login'), findsWidgets); // Check for Login text/button
  });

  testWidgets('App correctly loads AppConfig for development mode', (
    WidgetTester tester,
  ) async {
    // Arrange: Get logger for the test
    final logger = LoggerFactory.getLogger('AppConfigOverrideTest');
    final tag = logTag('AppConfigOverrideTest');

    // Arrange: Define the override for AppConfig
    di.overrides = [
      () {
        // Unregister default if already registered (e.g., during hot restart in test)
        if (di.sl.isRegistered<AppConfig>()) {
          di.sl.unregister<AppConfig>();
        }
        final devConfig = AppConfig.development();
        di.sl.registerSingleton<AppConfig>(devConfig);
        logger.d('$tag Registered AppConfig override: $devConfig');
      },
    ];

    // NO LONGER MANUALLY EXECUTE OVERRIDES
    // Let di.init() handle applying overrides internally
    // The overrides will be executed at the beginning of di.init()
    logger.d('$tag Calling di.init(), expecting it to apply overrides...');
    await di.init();

    // Assert: Verify AppConfig IS the development instance
    logger.d('$tag Verifying AppConfig instance...');
    final config = di.sl<AppConfig>();
    expect(config.isDevelopment, isTrue);
    expect(config.apiDomain, 'localhost:8080');
    expect(config.apiKey, 'test-api-key');
    logger.i('$tag AppConfig verification successful!');
  });
}
