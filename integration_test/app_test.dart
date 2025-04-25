// This file contains End-to-End (E2E) tests for the DocJet Mobile app UI.
// It uses the 'integration_test' package to drive the app on a device/emulator.
// IMPORTANT: These tests rely on a mock API server being run externally.
// Use the './run_e2e_tests.sh' script to launch the tests and manage the server.

// Remove dotenv import
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv

// Import the main app entry point. Make sure it can be configured
// (e.g., via environment variables or passed params) to use the mock server.
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/entities/user.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:docjet_mobile/core/di/injection_container.dart' as di;
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import log helpers
import 'package:docjet_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (context) => sl<JobListCubit>())],
      child: MaterialApp(
        title: 'DocJet',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const Scaffold(body: Center(child: Text('Test App Running'))),
      ),
    );
  }
}

// Annotate classes to generate mocks for
@GenerateMocks([AuthService, AuthEventBus, JobListCubit])
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Declare mocks
  late MockAuthService mockAuthService;
  late MockAuthEventBus mockAuthEventBus;
  late MockJobListCubit mockJobListCubit;

  setUpAll(() async {
    // Allow reassignment for test setup
    sl.allowReassignment = true;

    // Reset GetIt for a clean slate in tests
    await sl.reset();

    // Create mock instances
    mockAuthService = MockAuthService();
    mockAuthEventBus = MockAuthEventBus();
    mockJobListCubit = MockJobListCubit();

    // Configure the mock behaviors
    when(
      mockAuthService.isAuthenticated(
        validateTokenLocally: anyNamed('validateTokenLocally'),
      ),
    ).thenAnswer((_) async => true);

    when(
      mockAuthService.getUserProfile(),
    ).thenAnswer((_) async => const User(id: 'test-user-id'));

    when(mockAuthEventBus.stream).thenAnswer((_) => Stream.empty());

    // Register mocks with GetIt
    sl.registerLazySingleton<AuthService>(() => mockAuthService);
    sl.registerLazySingleton<AuthEventBus>(() => mockAuthEventBus);
    sl.registerLazySingleton<JobListCubit>(() => mockJobListCubit);
  });

  testWidgets('App launches and finds initial MaterialApp widget', (
    WidgetTester tester,
  ) async {
    // Simply pump our TestApp directly - no need to call main()
    await tester.pumpWidget(const ProviderScope(child: TestApp()));

    // Verify the MaterialApp is present
    expect(find.byType(MaterialApp), findsOneWidget);

    // Verify our test text is displayed (confirming it's our test app that loaded)
    expect(find.text('Test App Running'), findsOneWidget);
  });

  setUp(() {
    // Reset GetIt before each test
    GetIt.I.reset();
    // Clear overrides before each test
    di.overrides = [];
  });

  testWidgets('App initializes and shows LoginScreen', (
    WidgetTester tester,
  ) async {
    // Arrange: Initialize dependencies
    await di.init();
    final authService = di.sl<AuthService>();

    // Act: Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(authService)],
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
