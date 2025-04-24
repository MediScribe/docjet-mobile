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
import 'package:docjet_mobile/core/auth/auth_session_provider.dart'; // Add AuthSessionProvider import
import 'package:docjet_mobile/core/auth/auth_service.dart'; // Add AuthService import
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart'; // Add AuthApiClient import
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart'; // Add AuthServiceImpl import
import 'package:docjet_mobile/core/auth/infrastructure/secure_storage_auth_session_provider.dart'; // Add SecureStorageAuthSessionProvider
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart'; // Import JwtValidator
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart'; // Import AuthEventBus
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart'; // Import DioFactory

final sl = GetIt.instance;

// --- Riverpod Providers --- Accessing GetIt Singletons ---

/// Riverpod provider for accessing the singleton AuthEventBus instance from GetIt.
final authEventBusProvider = Provider<AuthEventBus>(
  (ref) => sl<AuthEventBus>(),
);

// Add other bridge providers here if needed...

// -------------------------------------------------------

Future<void> init() async {
  // --- Initialize Hive FIRST ---
  // No directory needed for Flutter, it finds the right path automatically
  await Hive.initFlutter();
  // Register Hive Adapters (CRITICAL!)
  Hive.registerAdapter(JobHiveModelAdapter());
  // TODO: Register any other Hive adapters needed for your models here

  // --- Open Hive Boxes ---
  // Open boxes needed by the application BEFORE registering dependencies that use them.
  // Using the constants from HiveJobLocalDataSourceImpl
  await Hive.openBox<JobHiveModel>(HiveJobLocalDataSourceImpl.jobsBoxName);
  await Hive.openBox<dynamic>(HiveJobLocalDataSourceImpl.metadataBoxName);
  // ---------------------------

  // --- Features - Jobs ---

  // Repository (depends on services)
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

  // Services (depend on data sources, core utils)
  sl.registerLazySingleton<JobReaderService>(
    () => JobReaderService(
      localDataSource: sl(),
      remoteDataSource: sl(),
      deleterService: sl<JobDeleterService>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );
  sl.registerLazySingleton<JobWriterService>(
    () => JobWriterService(
      localDataSource: sl(),
      uuid: sl(),
      authSessionProvider: sl(),
    ),
  );
  sl.registerLazySingleton<JobDeleterService>(
    () => JobDeleterService(localDataSource: sl(), fileSystem: sl()),
  );
  sl.registerLazySingleton<JobSyncProcessorService>(
    () => JobSyncProcessorService(
      localDataSource: sl(),
      remoteDataSource: sl(),
      fileSystem: sl(),
    ),
  );
  sl.registerLazySingleton<JobSyncOrchestratorService>(
    () => JobSyncOrchestratorService(
      localDataSource: sl(),
      networkInfo: sl(),
      processorService: sl(),
    ),
  );

  // Data Sources Interfaces (depend on core services like DB, API Client)
  // Register JobLocalDataSourceImpl (using HiveInterface)
  sl.registerLazySingleton<JobLocalDataSource>(
    () => HiveJobLocalDataSourceImpl(hive: sl()), // Depends on HiveInterface
  );
  // Register JobRemoteDataSourceImpl (using Dio)
  sl.registerLazySingleton<JobRemoteDataSource>(
    () => ApiJobRemoteDataSourceImpl(
      dio: sl(),
      authCredentialsProvider: sl(),
      authSessionProvider: sl(),
    ), // Depends on Dio, AuthCredentialsProvider, and AuthSessionProvider
  );

  // Features - Jobs - Domain - Use Cases (Register necessary use cases)
  sl.registerLazySingleton(() => WatchJobByIdUseCase(repository: sl()));
  sl.registerLazySingleton(() => WatchJobsUseCase(repository: sl()));
  sl.registerLazySingleton(() => CreateJobUseCase(sl()));

  // Register mapper for view models
  sl.registerLazySingleton(() => JobViewModelMapper());

  // Features - Jobs - Presentation
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

  // Register AuthEventBus using GetIt
  sl.registerLazySingleton<AuthEventBus>(() => AuthEventBus());

  // External
  sl.registerLazySingleton<Uuid>(() => const Uuid());
  sl.registerLazySingleton<Dio>(() => Dio()); // Basic Dio instance
  sl.registerLazySingleton<Connectivity>(() => Connectivity());

  // Register HiveInterface now that it's initialized and boxes are open
  sl.registerLazySingleton<HiveInterface>(() => Hive);

  // Register FlutterSecureStorage FIRST
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  // Register the JwtValidator
  sl.registerLazySingleton<JwtValidator>(() => JwtValidator());

  // Register the concrete provider (CORRECTED)
  sl.registerLazySingleton<SecureStorageAuthCredentialsProvider>(
    () => SecureStorageAuthCredentialsProvider(
      secureStorage: sl(),
      jwtValidator: sl(), // Add JwtValidator injection
    ),
  );

  // Register the AuthCredentialsProvider INTERFACE
  // This now points to the correctly configured concrete instance
  sl.registerLazySingleton<AuthCredentialsProvider>(
    () => sl<SecureStorageAuthCredentialsProvider>(),
  );

  // Register a basic Dio instance for auth API client
  sl.registerLazySingleton<Dio>(
    () =>
        DioFactory.createBasicDio(), // Use DioFactory to get proper URL from environment
    instanceName: 'basicDio',
  );

  // Register the real AuthApiClient
  sl.registerLazySingleton<AuthApiClient>(
    () => AuthApiClient(
      httpClient: sl<Dio>(instanceName: 'basicDio'),
      credentialsProvider: sl<AuthCredentialsProvider>(),
    ),
  );

  // Register AuthService with real implementation for development/testing
  sl.registerLazySingleton<AuthService>(
    () => AuthServiceImpl(
      apiClient: sl<AuthApiClient>(),
      credentialsProvider: sl<AuthCredentialsProvider>(),
      eventBus: sl<AuthEventBus>(),
    ),
  );

  // Register the AuthSessionProvider with SecureStorageAuthSessionProvider implementation
  sl.registerLazySingleton<AuthSessionProvider>(
    () => SecureStorageAuthSessionProvider(
      credentialsProvider: sl(), // Use the registered AuthCredentialsProvider
    ),
  );

  // Get document path once during init
  final appDocDir = await getApplicationDocumentsDirectory();
  final documentsPath = appDocDir.path;

  // Platform Interfaces
  // Register FileSystem (using IoFileSystem with the actual path)
  sl.registerLazySingleton<FileSystem>(() => IoFileSystem(documentsPath));
  // Register NetworkInfo (using NetworkInfoImpl)
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl()),
  ); // Depends on Connectivity
}
