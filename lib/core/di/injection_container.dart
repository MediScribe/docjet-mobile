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
import 'package:docjet_mobile/core/auth/auth_service.dart'; // Add AuthService import
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart'; // Add AuthApiClient import
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart'; // Add AuthServiceImpl import
// Add SecureStorageAuthSessionProvider
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

  if (!sl.isRegistered<AuthEventBus>()) {
    sl.registerLazySingleton<AuthEventBus>(() => AuthEventBus());
  }

  // External
  if (!sl.isRegistered<Uuid>()) {
    sl.registerLazySingleton<Uuid>(() => const Uuid());
  }
  // NOTE: Basic Dio instance without name removed - only named instances used now
  // if (!sl.isRegistered<Dio>()) {
  //   sl.registerLazySingleton<Dio>(() => Dio());
  // }
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
  }

  // Auth Concrete Provider
  if (!sl.isRegistered<SecureStorageAuthCredentialsProvider>()) {
    sl.registerLazySingleton<SecureStorageAuthCredentialsProvider>(
      () => SecureStorageAuthCredentialsProvider(
        secureStorage: sl(),
        jwtValidator: sl(),
      ),
    );
  }
  // Auth Interface Provider
  if (!sl.isRegistered<AuthCredentialsProvider>()) {
    sl.registerLazySingleton<AuthCredentialsProvider>(
      () => sl<SecureStorageAuthCredentialsProvider>(),
    );
  }

  // --- DioFactory and Named Dio Instances ---
  if (!sl.isRegistered<DioFactory>()) {
    sl.registerLazySingleton<DioFactory>(
      () => DioFactory(appConfig: sl<AppConfig>()),
    );
  }
  if (!sl.isRegistered<Dio>(instanceName: 'basicDio')) {
    sl.registerLazySingleton<Dio>(
      () => sl<DioFactory>().createBasicDio(),
      instanceName: 'basicDio',
    );
  }
  if (!sl.isRegistered<AuthApiClient>()) {
    sl.registerLazySingleton<AuthApiClient>(
      () => AuthApiClient(
        httpClient: sl<Dio>(instanceName: 'basicDio'),
        credentialsProvider: sl<AuthCredentialsProvider>(),
      ),
    );
  }
  if (!sl.isRegistered<Dio>(instanceName: 'authenticatedDio')) {
    sl.registerLazySingleton<Dio>(
      () => sl<DioFactory>().createAuthenticatedDio(
        authApiClient: sl(),
        credentialsProvider: sl(),
        authEventBus: sl(),
      ),
      instanceName: 'authenticatedDio',
    );
  }

  // --- Call Auth Module Registration ---
  // This ensures AuthService and AuthSessionProvider are registered
  // respecting any mocks provided in tests or overrides.
  AuthModule.register(sl);
  logger.d('$tag AuthModule registration complete.');

  // --- Dependencies using Named Dio ---
  if (!sl.isRegistered<JobRemoteDataSource>()) {
    sl.registerLazySingleton<JobRemoteDataSource>(
      () => ApiJobRemoteDataSourceImpl(
        dio: sl(instanceName: 'authenticatedDio'),
        authCredentialsProvider: sl(),
        authSessionProvider: sl(),
      ),
    );
  }

  // --- Remaining Auth Components ---
  if (!sl.isRegistered<AuthService>()) {
    sl.registerLazySingleton<AuthService>(
      () => AuthServiceImpl(
        apiClient: sl<AuthApiClient>(),
        credentialsProvider: sl<AuthCredentialsProvider>(),
        eventBus: sl<AuthEventBus>(),
      ),
    );
  }
  // NOTE: AuthSessionProvider registration is typically done in tests or specific entry points
  // if (!sl.isRegistered<AuthSessionProvider>()) {
  //   sl.registerLazySingleton<AuthSessionProvider>(
  //     () => SecureStorageAuthSessionProvider(
  //       credentialsProvider: sl(),
  //     ),
  //   );
  // }

  // --- Platform Interfaces ---
  if (!sl.isRegistered<FileSystem>()) {
    final appDocDir = await getApplicationDocumentsDirectory();
    final documentsPath = appDocDir.path;
    sl.registerLazySingleton<FileSystem>(() => IoFileSystem(documentsPath));
  }
  if (!sl.isRegistered<NetworkInfo>()) {
    sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  }

  logger.i('$tag Dependency injection initialization complete.');
}
