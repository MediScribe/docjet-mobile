import 'package:flutter_test/flutter_test.dart';
// Removed GetIt import as 'sl' is used directly
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:docjet_mobile/core/di/injection_container.dart' as di;
import 'package:docjet_mobile/core/di/injection_container.dart'
    show sl; // Direct import of sl
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/config/app_config.dart';
// Removed kDebugMode import
import 'package:docjet_mobile/core/utils/log_helpers.dart';

// Add a MockAuthSessionProvider class (Simplified)
class MockAuthSessionProvider implements AuthSessionProvider {
  Future<void> clearSession() async {}

  @override
  Future<String> getCurrentUserId() async => 'test-user-id';

  @override
  Future<bool> isAuthenticated() async => true;

  bool get isActive => true;
}

// Create a mock for FlutterSecureStoragePlatform (Simplified)
class MockFlutterSecureStoragePlatform
    with MockPlatformInterfaceMixin
    implements FlutterSecureStoragePlatform {
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return false; // Simple mock behavior
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {} // Simple mock behavior

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {} // Simple mock behavior

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    return {}; // Simple mock behavior
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return null; // Simple mock behavior
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {} // Simple mock behavior
}

// Create a mock for PathProviderPlatform (Simplified)
class MockPathProviderPlatform
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return '/tmp'; // Simple mock behavior
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return '/tmp/support'; // Simple mock behavior
  }

  @override
  Future<String?> getLibraryPath() async {
    return '/tmp/lib'; // Simple mock behavior
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '/tmp/docs'; // Simple mock behavior
  }

  @override
  Future<String?> getApplicationCachePath() async {
    return '/tmp/cache'; // Simple mock behavior
  }

  @override
  Future<String?> getExternalStoragePath() async {
    return '/tmp/external'; // Simple mock behavior
  }

  @override
  Future<List<String>?> getExternalCachePaths() async {
    return ['/tmp/cache']; // Simple mock behavior
  }

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    return ['/tmp/storage']; // Simple mock behavior
  }

  @override
  Future<String?> getDownloadsPath() async {
    return '/tmp/downloads'; // Simple mock behavior
  }
}

void main() {
  // Setup logger for DI tests
  final logger = LoggerFactory.getLogger('DITests');
  final tag = logTag('DITests'); // Removed leading underscore

  setUp(() {
    // Reset GetIt first to ensure a clean slate
    sl.reset();

    // Set platform interface mocks BEFORE di.init() runs
    PathProviderPlatform.instance = MockPathProviderPlatform();
    FlutterSecureStoragePlatform.instance = MockFlutterSecureStoragePlatform();

    // Register mocks NEEDED BY di.init() BEFORE it runs
    // If di.init() expects certain types to be already registered (like mocks for testing),
    // they should be registered here.
    // Example: AuthSessionProvider seems needed by JobRepository
    sl.registerSingleton<AuthSessionProvider>(MockAuthSessionProvider());
  });

  tearDown(() {
    sl.reset();
  });

  testWidgets('should initialize dependencies and resolve JobListCubit', (
    WidgetTester tester,
  ) async {
    // Arrange: Ensure Flutter bindings are initialized
    TestWidgetsFlutterBinding.ensureInitialized();

    // Act: Initialize the container
    await tester.runAsync(() async {
      await di.init();
    });

    // Assert: Try to resolve JobListCubit and check its type
    expect(() => sl<JobListCubit>(), returnsNormally);
    final cubit = sl<JobListCubit>();
    expect(cubit, isA<JobListCubit>());
  });

  testWidgets('AppConfig registration and initialization', (
    WidgetTester tester,
  ) async {
    // Arrange: Ensure Flutter bindings are initialized
    TestWidgetsFlutterBinding.ensureInitialized();

    logger.i('$tag Testing AppConfig registration as part of di.init()');

    // Verify AppConfig isn't registered yet (before init)
    expect(
      sl.isRegistered<AppConfig>(),
      isFalse,
      reason: "AppConfig should not be registered before di.init()",
    );

    // Act: Run di.init() to register all dependencies including AppConfig
    await tester.runAsync(() async {
      await di.init();
    });

    // Assert: Check if AppConfig is registered after init
    expect(
      sl.isRegistered<AppConfig>(),
      isTrue,
      reason: "AppConfig should be registered after di.init() runs",
    );

    // Verify we can retrieve the AppConfig
    expect(() => sl<AppConfig>(), returnsNormally);
    final config = sl<AppConfig>();
    expect(config, isA<AppConfig>());
  });

  // Removed the excessive diagnostic tests
}
