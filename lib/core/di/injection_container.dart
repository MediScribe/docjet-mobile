// Features - Jobs - Data
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/platform/file_system.dart'; // Actual implementation (IoFileSystem) & Interface
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Add Hive Flutter import

// Features - Jobs - Domain
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart'; // Add interface import
// Add concrete class import
// Add FlutterSecureStorage import
// Add AuthSessionProvider import
// Add AuthService import
// Add AuthApiClient import
// Add AuthServiceImpl import
import 'package:docjet_mobile/core/auth/auth_session_provider.dart'; // <<< ADDED
// <<< ADDED
// Import JwtValidator
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart'; // Import AuthEventBus
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart'; // Import DioFactory
import 'package:docjet_mobile/core/config/app_config.dart'; // Import AppConfig
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import Logger helpers
import 'package:docjet_mobile/core/auth/infrastructure/auth_module.dart'; // Import AuthModule
import 'package:docjet_mobile/features/jobs/di/jobs_module.dart'; // Import JobsModule
import 'package:docjet_mobile/core/di/core_module.dart'; // Import CoreModule
// Import HiveInterface
// Keep HiveInterface
import 'package:dio/dio.dart'; // Import Dio
import 'package:docjet_mobile/core/di/lazy_hive_service.dart'; // Import LazyHiveService
import 'package:path_provider/path_provider.dart'; // Import for documents dir path

final sl = GetIt.instance;

/// Optional list of functions to run for overriding registrations during testing or specific entry points.
typedef OverrideCallback = void Function();
List<OverrideCallback> overrides = [];

// Create providers that use GetIt for clean Riverpod integration
// -------------------------------------------------------
final authEventBusProvider = Provider<AuthEventBus>(
  (ref) => sl<AuthEventBus>(),
);
// -------------------------------------------------------

Future<void> init() async {
  final logger = LoggerFactory.getLogger('DI');
  final tag = logTag('DI');

  // --- Apply registered overrides FIRST ---
  if (overrides.isNotEmpty) {
    logger.i('$tag Applying ${overrides.length} registered override(s)...');

    for (final override in overrides) {
      override();
    }

    logger.i('$tag All overrides applied successfully');
  }

  // --- Initialize Hive SECOND ---
  logger.d('$tag Before Hive initialization');

  // No directory needed for Flutter, it finds the right path automatically
  await Hive.initFlutter();

  // Register Hive Adapters (CRITICAL!) - Check if already registered
  if (!Hive.isAdapterRegistered(JobHiveModelAdapter().typeId)) {
    Hive.registerAdapter(JobHiveModelAdapter());
    logger.d('$tag Registered JobHiveModelAdapter');
  } else {
    logger.d('$tag JobHiveModelAdapter already registered');
  }
  // TODO: Register any other Hive adapters needed for your models here (with checks)

  // --- Kick off background Hive initialisation via LazyHiveService ---
  // This *replaces* synchronous box opening to keep the UI thread free during
  // cold-start. Boxes will be opened lazily on first use.
  final appDocDir = await getApplicationDocumentsDirectory();
  await LazyHiveService.init(path: appDocDir.path);

  logger.d('$tag Hive (lazy) initialization complete');

  // --- Register AppConfig ---
  final isRegisteredBeforeCheck = sl.isRegistered<AppConfig>();
  logger.d(
    '$tag *** Checking AppConfig registration. Is registered BEFORE check? $isRegisteredBeforeCheck ***',
  );

  if (!isRegisteredBeforeCheck) {
    logger.d(
      '$tag AppConfig NOT registered, registering default from environment...',
    );
    final appConfig = AppConfig.fromEnvironment();
    sl.registerSingleton<AppConfig>(appConfig);
    logger.d('$tag Registered DEFAULT AppConfig: ${appConfig.toString()}');
  } else {
    logger.i(
      '$tag AppConfig already registered (likely by override). Skipping default registration.',
    );
  }
  final currentConfig = sl<AppConfig>();
  logger.i(
    '$tag *** Using AppConfig AFTER check: ${currentConfig.toString()} ***',
  );

  // --- Register Core Module THIRD ---
  logger.d('$tag Registering Core Module...');
  final coreModule = CoreModule();
  await coreModule.register(sl); // Await because FileSystem needs path_provider
  logger.i('$tag Core Module registration completed.');

  // --- Register Auth Module FOURTH ---
  logger.d('$tag Registering Auth Module...');
  // Resolve dependencies needed by AuthModule AFTER CoreModule has run
  final dioFactory = sl<DioFactory>();
  final credentialsProvider = sl<AuthCredentialsProvider>();
  final authEventBus = sl<AuthEventBus>();

  // Create AuthModule with explicit constructor dependencies
  final authModule = AuthModule(
    dioFactory: dioFactory,
    credentialsProvider: credentialsProvider,
    authEventBus: authEventBus,
  );

  // Call register without the dependencies (they're now held by the instance)
  authModule.register(sl);
  logger.i('$tag AuthModule registration completed via instance method.');

  // --- Features - Jobs FIFTH ---
  logger.d('$tag Registering Jobs Module...');
  // Now that AuthModule has run (and registered AuthSessionProvider), resolve Job deps
  // Resolve dependencies needed by JobsModule AFTER CoreModule & AuthModule have run
  final authSessionProvider = sl<AuthSessionProvider>();
  final networkInfo = sl<NetworkInfo>();
  final uuid = sl<Uuid>();
  final fileSystem = sl<FileSystem>();
  final hive = sl<HiveInterface>();
  final authenticatedDio = sl<Dio>(instanceName: 'authenticatedDio');
  // final authCredentialsProvider = sl<AuthCredentialsProvider>(); // Already resolved

  final jobsModule = JobsModule(
    authSessionProvider: authSessionProvider,
    authEventBus: authEventBus, // Already resolved
    networkInfo: networkInfo,
    uuid: uuid,
    fileSystem: fileSystem,
    hive: hive,
    authenticatedDio: authenticatedDio,
    authCredentialsProvider:
        credentialsProvider, // Use the one resolved for AuthModule
  );
  jobsModule.register(sl);
  logger.i('$tag JobsModule registration completed via instance method.');

  logger.i('$tag Dependency injection setup complete');
}

/// Resets GetIt for testing purposes
Future<void> resetLocator({bool dispose = true}) async {
  await sl.reset(dispose: dispose);
}

/// Adds an override function to be executed at the beginning of init()
void addOverride(OverrideCallback callback) {
  overrides.add(callback);
}

/// Clears all registered overrides
void clearOverrides() {
  overrides.clear();
}

// --- Riverpod Providers using GetIt ---
// Note: We keep the static AuthModule.providerOverrides for now
final riverpodOverridesProvider = Provider<List<Override>>((ref) {
  // Combine overrides from different modules if necessary
  return [...AuthModule.providerOverrides(sl)];
});
