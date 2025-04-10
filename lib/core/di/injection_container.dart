import 'package:get_it/get_it.dart';
import 'package:record/record.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_retriever.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_retriever_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/repositories/audio_recorder_repository_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager_impl.dart';

// Import Hive and related components
import 'package:hive_flutter/hive_flutter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/local_job_store_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
// Import Fake Data Source
import 'package:docjet_mobile/features/audio_recorder/data/datasources/fake_transcription_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/transcription_remote_data_source.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // --- Core Initialization ---
  // Initialize Hive FIRST
  await Hive.initFlutter();
  // Open boxes needed at startup (currently just LocalJob)
  final localJobBox = await HiveLocalJobStoreImpl.openBox();

  // --- Feature: Audio Recorder ---

  // Cubits (Now depend directly on Repository)
  sl.registerFactory(() => AudioListCubit(repository: sl()));
  sl.registerFactory(() => AudioRecordingCubit(repository: sl()));

  // Repository (Depends on Data Sources)
  sl.registerLazySingleton<AudioRecorderRepository>(
    () => AudioRecorderRepositoryImpl(
      localDataSource: sl(),
      fileManager: sl(),
      // TODO: Inject TranscriptionRemoteDataSource and LocalJobStore in Step 5
    ),
  );

  // Data Sources (Local)
  sl.registerLazySingleton<AudioLocalDataSource>(
    () => AudioLocalDataSourceImpl(
      recorder: sl(),
      pathProvider: sl(),
      permissionHandler: sl(),
      audioConcatenationService: sl(),
      fileSystem: sl(),
      // TODO: Inject LocalJobStore later when needed by the implementation
      // localJobStore: sl(),
    ),
  );

  // Data Sources (Remote - FAKE for now)
  sl.registerLazySingleton<TranscriptionRemoteDataSource>(
    () => FakeTranscriptionDataSourceImpl(),
  );

  // Local Job Storage (Hive)
  sl.registerLazySingleton<Box<LocalJob>>(() => localJobBox);
  sl.registerLazySingleton(() => HiveLocalJobStoreImpl(sl()));
  sl.registerLazySingleton<LocalJobStore>(() => sl<HiveLocalJobStoreImpl>());

  // --- External Dependencies ---
  sl.registerLazySingleton(() => AudioRecorder()); // From 'record' package

  // --- Core Platform Implementations ---
  // Register concrete implementations for the platform interfaces
  sl.registerLazySingleton<FileSystem>(() => IoFileSystem());
  sl.registerLazySingleton<PathProvider>(() => AppPathProvider());
  sl.registerLazySingleton<PermissionHandler>(() => AppPermissionHandler());

  // --- Core ---
  // Register core dependencies if any (e.g., NetworkClient, Logger)

  // --- Other Features ---
  // Register dependencies for other features

  // Audio Services
  sl.registerLazySingleton<AudioDurationRetriever>(
    () => AudioDurationRetrieverImpl(),
  );

  sl.registerLazySingleton<AudioConcatenationService>(
    () => DummyAudioConcatenator(),
  );

  // Register AudioFileManager
  sl.registerLazySingleton<AudioFileManager>(
    () => AudioFileManagerImpl(
      fileSystem: sl(),
      pathProvider: sl(),
      audioDurationRetriever: sl(),
    ),
  );
}
