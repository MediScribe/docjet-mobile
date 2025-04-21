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

// Features - Jobs - Domain
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart'; // Needed for getApplicationDocumentsDirectory
import 'package:uuid/uuid.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // --- Features - Jobs ---

  // Repository (depends on services)
  sl.registerLazySingleton<JobRepository>(
    () => JobRepositoryImpl(
      readerService: sl(),
      writerService: sl(),
      deleterService: sl(),
      orchestratorService: sl<JobSyncOrchestratorService>(),
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
    () => JobWriterService(localDataSource: sl(), uuid: sl()),
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
    ), // Depends on Dio & AuthProvider
  );

  // --- Core Dependencies ---

  // External
  sl.registerLazySingleton<Uuid>(() => const Uuid());
  sl.registerLazySingleton<Dio>(() => Dio()); // Basic Dio instance
  sl.registerLazySingleton<Connectivity>(() => Connectivity());
  // Assume HiveInterface is registered elsewhere (e.g., main.dart during init)
  // If not, it needs registration: sl.registerLazySingleton<HiveInterface>(() => Hive);
  // Assume AuthCredentialsProvider is registered elsewhere
  // If not, it needs registration: sl.registerLazySingleton<AuthCredentialsProvider>(() => YourAuthProviderImpl());
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

  // Network Interfaces - Handled by registering Dio directly

  // Database Interfaces - Not needed for this feature

  // TODO: Ensure HiveInterface and AuthCredentialsProvider are registered elsewhere,
  // likely during app startup before this init() is called.
  // TODO: Consider Dio setup (interceptors, base URL) if needed.
  // TODO: Consider Hive setup (init, box opening) if needed.
}
