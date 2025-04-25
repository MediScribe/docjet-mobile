// Features - Jobs - Data
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/platform/file_system.dart'; // Actual implementation (IoFileSystem) & Interface
import 'package:docjet_mobile/core/platform/network_info_impl.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/api_job_remote_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Add Hive Flutter import

// Features - Jobs - Domain
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_job_by_id_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_jobs_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_detail_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/mappers/job_view_model_mapper.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart'; // Needed for getApplicationDocumentsDirectory
import 'package:uuid/uuid.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart'; // Add interface import
import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart'; // Add concrete class import
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Add FlutterSecureStorage import
// Add AuthSessionProvider import
// Add AuthService import
// Add AuthApiClient import
// Add AuthServiceImpl import
import 'package:docjet_mobile/core/auth/auth_session_provider.dart'; // <<< ADDED
import 'package:docjet_mobile/core/auth/infrastructure/secure_storage_auth_session_provider.dart'; // <<< ADDED
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart'; // Import JwtValidator
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart'; // Import AuthEventBus
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart'; // Import DioFactory
import 'package:docjet_mobile/core/config/app_config.dart'; // Import AppConfig
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import Logger helpers
import 'package:docjet_mobile/core/auth/infrastructure/auth_module.dart'; // Import AuthModule

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

  // --- Open Hive Boxes ---
  // Open boxes needed by the application BEFORE registering dependencies that use them.
  // Using the constants from HiveJobLocalDataSourceImpl
  await Hive.openBox<JobHiveModel>(HiveJobLocalDataSourceImpl.jobsBoxName);
  await Hive.openBox<dynamic>(HiveJobLocalDataSourceImpl.metadataBoxName);
  // ---------------------------

  logger.d('$tag Hive initialization complete');

  // --- Register AppConfig ---
  if (!sl.isRegistered<AppConfig>()) {
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

  // Log the currently registered AppConfig instance to confirm
  final currentConfig = sl<AppConfig>();
  logger.i('$tag Using AppConfig: ${currentConfig.toString()}');

  // --- Features - Jobs ---
  logger.d(
    '$tag Before registering other dependencies - AppConfig still registered? ${sl.isRegistered<AppConfig>()}',
  );

  // Repository
  if (!sl.isRegistered<JobRepository>()) {
    sl.registerLazySingleton<JobRepository>(
      () => JobRepositoryImpl(
        readerService: sl(),
        writerService: sl(),
        deleterService: sl(),
        orchestratorService: sl<JobSyncOrchestratorService>(),
        authSessionProvider: sl(),
        authEventBus: sl(),
        localDataSource: sl(),
      ),
    );
  }

  // Services
  if (!sl.isRegistered<JobReaderService>()) {
    sl.registerLazySingleton<JobReaderService>(
      () => JobReaderService(
        localDataSource: sl(),
        remoteDataSource: sl(),
        deleterService: sl<JobDeleterService>(),
        networkInfo: sl<NetworkInfo>(),
      ),
    );
  }
  if (!sl.isRegistered<JobWriterService>()) {
    sl.registerLazySingleton<JobWriterService>(
      () => JobWriterService(
        localDataSource: sl(),
        uuid: sl(),
        authSessionProvider: sl(),
      ),
    );
  }
  if (!sl.isRegistered<JobDeleterService>()) {
    sl.registerLazySingleton<JobDeleterService>(
      () => JobDeleterService(localDataSource: sl(), fileSystem: sl()),
    );
  }
  if (!sl.isRegistered<JobSyncProcessorService>()) {
    sl.registerLazySingleton<JobSyncProcessorService>(
      () => JobSyncProcessorService(
        localDataSource: sl(),
        remoteDataSource: sl(),
        fileSystem: sl(),
      ),
    );
  }
  if (!sl.isRegistered<JobSyncOrchestratorService>()) {
    sl.registerLazySingleton<JobSyncOrchestratorService>(
      () => JobSyncOrchestratorService(
        localDataSource: sl(),
        networkInfo: sl(),
        processorService: sl(),
      ),
    );
  }

  // Data Sources Interfaces
  if (!sl.isRegistered<JobLocalDataSource>()) {
    sl.registerLazySingleton<JobLocalDataSource>(
      () => HiveJobLocalDataSourceImpl(hive: sl()),
    );
  }
  // NOTE: JobRemoteDataSource registration moved below Dio instances

  // Use Cases
  if (!sl.isRegistered<WatchJobByIdUseCase>()) {
    sl.registerLazySingleton(() => WatchJobByIdUseCase(repository: sl()));
  }
  if (!sl.isRegistered<WatchJobsUseCase>()) {
    sl.registerLazySingleton(() => WatchJobsUseCase(repository: sl()));
  }
  if (!sl.isRegistered<CreateJobUseCase>()) {
    sl.registerLazySingleton(() => CreateJobUseCase(sl()));
  }

  // Mapper
  if (!sl.isRegistered<JobViewModelMapper>()) {
    sl.registerLazySingleton(() => JobViewModelMapper());
  }

  // Presentation
  // Factories don't usually need checks, they create new instances
  sl.registerFactoryParam<JobDetailCubit, String, void>(
    (localId, _) => JobDetailCubit(
      watchJobByIdUseCase: sl<WatchJobByIdUseCase>(),
      jobId: localId,
    ),
  );
  sl.registerFactory<JobListCubit>(
    () => JobListCubit(
      watchJobsUseCase: sl<WatchJobsUseCase>(),
      mapper: sl<JobViewModelMapper>(),
    ),
  );

  // --- Core Dependencies ---

  // Register DioFactory FIRST as AuthModule and others depend on it
  if (!sl.isRegistered<DioFactory>()) {
    sl.registerLazySingleton<DioFactory>(
      () => DioFactory(appConfig: sl<AppConfig>()),
    );
    logger.d('$tag Registered DioFactory');
  }

  if (!sl.isRegistered<AuthEventBus>()) {
    sl.registerLazySingleton<AuthEventBus>(() => AuthEventBus());
    logger.d('$tag Registered AuthEventBus');
  }

  // External
  if (!sl.isRegistered<Uuid>()) {
    sl.registerLazySingleton<Uuid>(() => const Uuid());
  }
  if (!sl.isRegistered<Connectivity>()) {
    sl.registerLazySingleton<Connectivity>(() => Connectivity());
  }
  if (!sl.isRegistered<HiveInterface>()) {
    sl.registerLazySingleton<HiveInterface>(() => Hive);
  }
  if (!sl.isRegistered<FlutterSecureStorage>()) {
    sl.registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(),
    );
  }
  if (!sl.isRegistered<JwtValidator>()) {
    sl.registerLazySingleton<JwtValidator>(() => JwtValidator());
    logger.d('$tag Registered JwtValidator');
  }

  // Auth Concrete Provider (Register AuthCredentialsProvider before AuthModule)
  // This ensures the correct implementation (or a mock from overrides) is available
  if (!sl.isRegistered<AuthCredentialsProvider>()) {
    sl.registerLazySingleton<AuthCredentialsProvider>(
      () => SecureStorageAuthCredentialsProvider(
        secureStorage: sl<FlutterSecureStorage>(),
        jwtValidator: sl<JwtValidator>(),
      ),
    );
    logger.d('$tag Registered AuthCredentialsProvider');
  }

  // --- Register Auth Module using INSTANCE method ---
  // Instantiate AuthModule (it has no constructor dependencies itself)
  final authModule = AuthModule();
  // Explicitly resolve dependencies needed by the register method
  final dioFactory = sl<DioFactory>();
  final credentialsProvider = sl<AuthCredentialsProvider>();
  final authEventBus = sl<AuthEventBus>();
  // Call the instance method, passing resolved dependencies
  // It will handle registering internal auth components like AuthService, ApiClient, etc.
  // and potentially default implementations for SecureStorage, JwtValidator, AuthSessionProvider
  // if they weren't already registered (e.g., by overrides).
  authModule.register(
    sl, // Pass the GetIt instance
    dioFactory: dioFactory,
    credentialsProvider: credentialsProvider,
    authEventBus: authEventBus,
    // We don't provide optional deps here; let AuthModule handle defaults/check GetIt
  );
  logger.i('$tag AuthModule registration completed via instance method.');

  // Ensure AuthSessionProvider is RESOLVABLE after AuthModule registration
  // This is crucial for components depending on it, like JobRepository
  // We register the default implementation here IF AuthModule didn't register it (e.g. via override)
  // Note: AuthModule.register now handles the logic of registering the default SecureStorageAuthSessionProvider
  // if no AuthSessionProvider (like a mock) was already registered or provided.
  // This check is now more for confirming it IS resolvable.
  if (!sl.isRegistered<AuthSessionProvider>()) {
    // This block should theoretically not be hit if overrides aren't used,
    // as AuthModule.register should have registered the default.
    logger.w(
      '$tag AuthSessionProvider was NOT registered by AuthModule. Registering default SecureStorageAuthSessionProvider now.',
    );
    sl.registerLazySingleton<AuthSessionProvider>(
      () => SecureStorageAuthSessionProvider(
        credentialsProvider: sl<AuthCredentialsProvider>(),
      ),
    );
  } else {
    logger.i(
      '$tag AuthSessionProvider confirmed registered (either by AuthModule or override).',
    );
  }

  // Register JobRemoteDataSource AFTER Dio instances are guaranteed to be registered by AuthModule
  if (!sl.isRegistered<JobRemoteDataSource>()) {
    sl.registerLazySingleton<JobRemoteDataSource>(
      () => ApiJobRemoteDataSourceImpl(
        dio: sl<Dio>(instanceName: 'authenticatedDio'),
        authSessionProvider:
            sl<AuthSessionProvider>(), // Now guaranteed to be resolvable
        authCredentialsProvider:
            sl<AuthCredentialsProvider>(), // <<< ADDED BACK
      ),
    );
    logger.d('$tag Registered JobRemoteDataSource');
  }

  // Platform
  if (!sl.isRegistered<FileSystem>()) {
    // Need path_provider to get the path
    final appDocDir = await getApplicationDocumentsDirectory();
    final documentsPath = appDocDir.path;
    sl.registerLazySingleton<FileSystem>(
      () => IoFileSystem(documentsPath),
    ); // <<< ADDED ARGUMENT
    logger.d('$tag Registered FileSystem');
  }
  if (!sl.isRegistered<NetworkInfo>()) {
    sl.registerLazySingleton<NetworkInfo>(
      () => NetworkInfoImpl(sl<Connectivity>()),
    );
    logger.d('$tag Registered NetworkInfo');
  }

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
