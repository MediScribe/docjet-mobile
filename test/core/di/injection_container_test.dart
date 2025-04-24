import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:docjet_mobile/core/di/injection_container.dart' as di;
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';

// Add a MockAuthSessionProvider class
class MockAuthSessionProvider implements AuthSessionProvider {
  @override
  String getCurrentUserId() {
    return 'test-user-id';
  }

  @override
  bool isAuthenticated() {
    return true;
  }
}

// Mock implementation of the platform interface
class MockFlutterSecureStoragePlatform
    with
        MockPlatformInterfaceMixin // Use the mixin for platform interface mocks
    implements FlutterSecureStoragePlatform {
  Map<String, String> _storage = {};

  // Implement only the methods needed for AuthCredentialsProvider or initialization
  // Most likely, we just need read, write, delete, containsKey

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return _storage.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _storage = {}; // Reset the internal map
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return _storage[key];
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    return Map.unmodifiable(_storage);
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _storage[key] = value;
  }

  // Implement other methods as needed, returning default values or throwing UnimplementedError if they are called unexpectedly
  // For this DI test, the above should suffice.
}

class MockPathProviderPlatform
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '.'; // Return a valid temporary directory for tests
  }

  // Implement other methods with dummy values if needed by di.init() or Hive
  @override
  Future<String?> getApplicationCachePath() async => '.';
  @override
  Future<String?> getApplicationSupportPath() async => '.';
  @override
  Future<String?> getDownloadsPath() async => '.';
  @override
  Future<List<String>?> getExternalCachePaths() async => ['.'];
  @override
  Future<String?> getExternalStoragePath() async => '.';
  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => ['.'];
  @override
  Future<String?> getLibraryPath() async => '.';
  @override
  Future<String?> getTemporaryPath() async => '.';
}

void main() {
  final getIt = GetIt.instance;

  setUp(() {
    // Reset GetIt first to ensure a clean slate
    getIt.reset();

    // Set platform interface mocks BEFORE di.init() runs
    PathProviderPlatform.instance = MockPathProviderPlatform();
    FlutterSecureStoragePlatform.instance = MockFlutterSecureStoragePlatform();

    // Register a mock AuthSessionProvider for tests
    getIt.registerSingleton<AuthSessionProvider>(MockAuthSessionProvider());

    // REMOVE GetIt registrations here. di.init() should handle them now,
    // using the platform mocks we just set.
    // getIt.registerLazySingleton<FlutterSecureStorage>(() => const FlutterSecureStorage());
    // final secureStorageProvider = SecureStorageAuthCredentialsProvider(secureStorage: getIt());
    // getIt.registerLazySingleton<SecureStorageAuthCredentialsProvider>(() => secureStorageProvider);
    // getIt.registerLazySingleton<AuthCredentialsProvider>(() => secureStorageProvider);
  });

  tearDown(() {
    // Just reset GetIt after each test.
    getIt.reset();
  });

  testWidgets('should initialize dependencies and resolve JobListCubit', (
    WidgetTester tester,
  ) async {
    // Arrange: Ensure Flutter bindings are initialized (needed for Hive.initFlutter)
    TestWidgetsFlutterBinding.ensureInitialized();

    // Act: Initialize the dependency container
    await tester.runAsync(() async {
      await di.init();

      // Override the AuthSessionProvider with our mock
      // This is necessary in case di.init() registers a real AuthSessionProvider
      if (getIt.isRegistered<AuthSessionProvider>()) {
        getIt.unregister<AuthSessionProvider>();
      }
      getIt.registerSingleton<AuthSessionProvider>(MockAuthSessionProvider());
    });

    // Assert: Try to resolve JobListCubit and check its type
    expect(() => getIt<JobListCubit>(), returnsNormally);
    expect(getIt<JobListCubit>(), isA<JobListCubit>());
  });

  // Add more tests here to verify other critical dependencies can be resolved
}
