// Features - Jobs - Data
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
// import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source_impl.dart'; // TODO: Implement
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
// import 'package:docjet_mobile/core/platform/file_system_impl.dart'; // TODO: Implement
// import 'package:docjet_mobile/core/network/api_client.dart'; // TODO: Implement
// import 'package:docjet_mobile/core/network/dio_client.dart'; // TODO: Implement
// import 'package:docjet_mobile/core/services/database/database_service.dart'; // TODO: Implement
// import 'package:docjet_mobile/core/services/database/hive_database_service.dart'; // TODO: Implement
// import 'package:docjet_mobile/core/platform/network_info_impl.dart'; // TODO: Implement

// Features - Jobs - Domain
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:get_it/get_it.dart';
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
      syncService: sl(),
    ),
  );

  // Services (depend on data sources, core utils)
  sl.registerLazySingleton<JobReaderService>(
    () => JobReaderService(localDataSource: sl(), remoteDataSource: sl()),
  );
  sl.registerLazySingleton<JobWriterService>(
    () => JobWriterService(localDataSource: sl(), uuid: sl()),
  );
  sl.registerLazySingleton<JobDeleterService>(
    () => JobDeleterService(localDataSource: sl(), fileSystem: sl()),
  );
  sl.registerLazySingleton<JobSyncService>(
    () => JobSyncService(
      localDataSource: sl(),
      remoteDataSource: sl(),
      networkInfo: sl(),
      fileSystem: sl(),
    ),
  );

  // Data Sources Interfaces (depend on core services like DB, API Client)
  // TODO: Implement and register JobLocalDataSourceImpl
  // sl.registerLazySingleton<JobLocalDataSource>(
  //   () => JobLocalDataSourceImpl(databaseService: sl()),
  // );
  // TODO: Implement and register JobRemoteDataSourceImpl
  // sl.registerLazySingleton<JobRemoteDataSource>(
  //   () => JobRemoteDataSourceImpl(apiClient: sl()),
  // );

  // --- Core Dependencies (Examples) ---

  // External
  sl.registerLazySingleton<Uuid>(() => const Uuid());

  // Platform Interfaces
  // TODO: Implement and register FileSystemImpl
  // sl.registerLazySingleton<FileSystem>(() => FileSystemImpl());
  // TODO: Implement and register NetworkInfoImpl
  // sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());

  // Network Interfaces
  // TODO: Implement and register ApiClient (e.g., DioClient)
  // sl.registerLazySingleton<ApiClient>(
  //   () => DioClient(/* Pass Dio instance if needed */),
  // );

  // Database Interfaces
  // TODO: Implement and register DatabaseService (e.g., HiveDatabaseService)
  // sl.registerLazySingleton<DatabaseService>(() => HiveDatabaseService());
  // TODO: Initialize HiveDatabaseService (e.g., await sl<DatabaseService>().init();)
}
