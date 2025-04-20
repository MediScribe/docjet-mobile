import 'package:get_it/get_it.dart';
import 'package:job_sync/core/network/network_info.dart';
import 'package:job_sync/core/utils/file_system.dart';
import 'package:job_sync/data/data_sources/local_data_source.dart';
import 'package:job_sync/data/data_sources/remote_data_source.dart';
import 'package:job_sync/data/repositories/job_repository_impl.dart';
import 'package:job_sync/domain/repositories/job_repository.dart';
import 'package:job_sync/domain/services/job_sync_orchestrator_service.dart';
import 'package:job_sync/domain/services/job_sync_processor_service.dart';

final sl = GetIt.I;

void setupInjectionContainer() {
  // ... existing code ...

  sl
    ..registerLazySingleton<JobSyncProcessorService>(
      () => JobSyncProcessorService(
        localDataSource: sl(),
        remoteDataSource: sl(),
        fileSystem: sl(),
      ),
    )
    ..registerLazySingleton<JobSyncOrchestratorService>(
      () => JobSyncOrchestratorService(
        localDataSource: sl(),
        networkInfo: sl(),
        processorService: sl(),
      ),
    )
    ..registerLazySingleton<JobRepository>(
      () => JobRepositoryImpl(
        readerService: sl(),
        writerService: sl(),
        deleterService: sl(),
        orchestratorService: sl(),
      ),
    )

    // External
  // ... existing code ...
} 