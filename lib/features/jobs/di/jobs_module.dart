import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/api_job_remote_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_trigger_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_auth_gate.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/delete_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_job_by_id_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/watch_jobs_use_case.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/smart_delete_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_detail_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/mappers/job_view_model_mapper.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Registers dependencies related to the Jobs feature.
class JobsModule {
  final AuthSessionProvider _authSessionProvider;
  final AuthEventBus _authEventBus;
  final NetworkInfo _networkInfo;
  final Uuid _uuid;
  final FileSystem _fileSystem;
  final HiveInterface _hive;
  final Dio _authenticatedDio;
  final AuthCredentialsProvider _authCredentialsProvider;

  /// Creates an instance of JobsModule requiring its external dependencies.
  JobsModule({
    required AuthSessionProvider authSessionProvider,
    required AuthEventBus authEventBus,
    required NetworkInfo networkInfo,
    required Uuid uuid,
    required FileSystem fileSystem,
    required HiveInterface hive,
    required Dio authenticatedDio,
    required AuthCredentialsProvider authCredentialsProvider,
  }) : _authSessionProvider = authSessionProvider,
       _authEventBus = authEventBus,
       _networkInfo = networkInfo,
       _uuid = uuid,
       _fileSystem = fileSystem,
       _hive = hive,
       _authenticatedDio = authenticatedDio,
       _authCredentialsProvider = authCredentialsProvider;

  /// Registers all necessary components for the Jobs feature with the provided [GetIt] instance.
  /// Uses the dependencies provided in the constructor.
  void register(GetIt getIt) {
    // Repository
    if (!getIt.isRegistered<JobRepository>()) {
      getIt.registerLazySingleton<JobRepository>(
        () => JobRepositoryImpl(
          readerService: getIt(),
          writerService: getIt(),
          deleterService: getIt(),
          orchestratorService: getIt<JobSyncOrchestratorService>(),
          authSessionProvider: _authSessionProvider, // Use injected
          authEventBus: _authEventBus, // Use injected
          localDataSource: getIt(),
        ),
      );
    }

    // Services
    if (!getIt.isRegistered<JobReaderService>()) {
      getIt.registerLazySingleton<JobReaderService>(
        () => JobReaderService(
          localDataSource: getIt(),
          remoteDataSource: getIt(),
          deleterService: getIt<JobDeleterService>(),
          networkInfo: _networkInfo, // Use injected
        ),
      );
    }
    if (!getIt.isRegistered<JobWriterService>()) {
      getIt.registerLazySingleton<JobWriterService>(
        () => JobWriterService(
          localDataSource: getIt(),
          uuid: _uuid, // Use injected
          authSessionProvider: _authSessionProvider, // Use injected
        ),
      );
    }
    if (!getIt.isRegistered<JobDeleterService>()) {
      // NOTE: remoteDataSource is registered later; factory is lazy so this is safe.
      getIt.registerLazySingleton<JobDeleterService>(
        () => JobDeleterService(
          localDataSource: getIt(),
          remoteDataSource: getIt(),
          networkInfo: getIt(),
          fileSystem: getIt(),
        ),
      );
    }
    if (!getIt.isRegistered<JobSyncProcessorService>()) {
      getIt.registerLazySingleton<JobSyncProcessorService>(
        () => JobSyncProcessorService(
          localDataSource: getIt(),
          remoteDataSource: getIt(),
          fileSystem: getIt(),
          // Defer lookup of orchestrator until runtime to avoid circular dependency
          isLogoutInProgress:
              () => getIt<JobSyncOrchestratorService>().isLogoutInProgress,
        ),
      );
    }
    if (!getIt.isRegistered<JobSyncOrchestratorService>()) {
      // NOTE: This is registered as a lazy singleton but its dispose() method is never
      // automatically called since singletons live for the app's entire lifecycle.
      //
      // RESOURCE MANAGEMENT:
      // - The service maintains a StreamSubscription to AuthEventBus
      // - During testing, ensure test helpers call dispose() after use
      // - For production code, consider adding an onAppTerminate handler in the
      //   main.dart that calls: getIt<JobSyncOrchestratorService>().dispose()
      //   to properly clean up resources when the app is shutting down
      getIt.registerLazySingleton<JobSyncOrchestratorService>(
        () => JobSyncOrchestratorService(
          localDataSource: getIt(),
          networkInfo: _networkInfo, // Use injected
          processorService: getIt(),
          authEventBus: _authEventBus, // Pass the auth event bus
        ),
      );
    }
    if (!getIt.isRegistered<JobSyncTriggerService>()) {
      getIt.registerLazySingleton<JobSyncTriggerService>(() {
        final service = JobSyncTriggerService(
          jobRepository: getIt(),
          // Use a shorter interval for testing if running in test mode
          syncInterval: const Duration(seconds: 15),
        );
        // We don't call init() here; it should be called during app initialization
        // This allows for proper timing control and avoids premature lifecycle observation
        return service;
      });
    }
    if (!getIt.isRegistered<JobSyncAuthGate>()) {
      // Gate that starts/stops the trigger service based on auth events
      getIt.registerLazySingleton<JobSyncAuthGate>(
        () => JobSyncAuthGate(
          syncService: getIt<JobSyncTriggerService>(),
          authStream: _authEventBus.stream,
        ),
      );
    }

    // Data Sources Interfaces
    if (!getIt.isRegistered<JobLocalDataSource>()) {
      getIt.registerLazySingleton<JobLocalDataSource>(
        // Use injected HiveInterface
        () => HiveJobLocalDataSourceImpl(hive: _hive),
      );
    }
    if (!getIt.isRegistered<JobRemoteDataSource>()) {
      getIt.registerLazySingleton<JobRemoteDataSource>(
        () => ApiJobRemoteDataSourceImpl(
          // Use injected Dio instance and Auth providers
          dio: _authenticatedDio,
          authSessionProvider: _authSessionProvider,
          authCredentialsProvider: _authCredentialsProvider,
          fileSystem: _fileSystem, // Add FileSystem for path resolution
        ),
      );
    }

    // Use Cases (depend on internal JobRepository)
    if (!getIt.isRegistered<WatchJobByIdUseCase>()) {
      getIt.registerLazySingleton(
        () => WatchJobByIdUseCase(repository: getIt()),
      );
    }
    if (!getIt.isRegistered<WatchJobsUseCase>()) {
      getIt.registerLazySingleton(() => WatchJobsUseCase(repository: getIt()));
    }
    if (!getIt.isRegistered<CreateJobUseCase>()) {
      // CreateJobUseCase takes JobRepository, which is internal to this module.
      // We resolve it using getIt() as it's registered just above.
      getIt.registerLazySingleton(() => CreateJobUseCase(getIt()));
    }
    if (!getIt.isRegistered<DeleteJobUseCase>()) {
      getIt.registerLazySingleton(() => DeleteJobUseCase(getIt()));
    }
    if (!getIt.isRegistered<SmartDeleteJobUseCase>()) {
      getIt.registerLazySingleton(
        () => SmartDeleteJobUseCase(repository: getIt<JobRepository>()),
      );
    }

    // Mapper (no dependencies)
    if (!getIt.isRegistered<JobViewModelMapper>()) {
      getIt.registerLazySingleton(() => JobViewModelMapper());
    }

    // Presentation (depend on internal UseCases/Mappers)
    // Factories don't usually need checks, they create new instances
    getIt.registerFactoryParam<JobDetailCubit, String, void>(
      (localId, _) => JobDetailCubit(
        watchJobByIdUseCase: getIt<WatchJobByIdUseCase>(),
        jobId: localId,
      ),
    );
    // NOTE: JobListCubit is provided at the app-shell level (see main.dart).
    // Registering another factory here risks multiple Cubits listening to the
    // same stream and causing duplicated UI updates.  Intentionally removed.
  }
}
