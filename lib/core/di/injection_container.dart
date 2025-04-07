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
import 'package:audioplayers/audioplayers.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';

// Import Hive and related components
import 'package:hive_flutter/hive_flutter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/local_job_store_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
// Import Fake Data Source
import 'package:docjet_mobile/features/audio_recorder/data/datasources/fake_transcription_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/transcription_remote_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/transcription_merge_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/transcription_merge_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // --- Core Initialization ---
  // Initialize Hive FIRST
  await Hive.initFlutter();

  // Register Hive Adapters BEFORE opening boxes
  Hive.registerAdapter(LocalJobAdapter());
  Hive.registerAdapter(TranscriptionStatusAdapter());

  // Open boxes needed at startup (currently just LocalJob)
  final localJobBox = await HiveLocalJobStoreImpl.openBox();

  // --- Feature: Audio Recorder ---

  // Cubits (Now depend directly on Repository)
  sl.registerFactory(
    () => AudioListCubit(repository: sl(), audioPlaybackService: sl()),
  );
  sl.registerFactory(() => AudioRecordingCubit(repository: sl()));

  // Repository (Depends on Data Sources AND Merge Service)
  sl.registerLazySingleton<AudioRecorderRepository>(
    () => AudioRecorderRepositoryImpl(
      localDataSource: sl(),
      fileManager: sl(),
      localJobStore: sl(),
      remoteDataSource: sl(),
      transcriptionMergeService: sl(),
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
      localJobStore: sl(),
      audioDurationRetriever: sl(),
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

  // + Register Audio Player (audioplayers package)
  sl.registerLazySingleton(() => AudioPlayer());

  // + Register Audio Playback Service
  sl.registerLazySingleton<AudioPlaybackService>(
    () => AudioPlaybackServiceImpl(audioPlayer: sl()),
  );

  // + Register TranscriptionMergeService
  sl.registerLazySingleton<TranscriptionMergeService>(
    () => TranscriptionMergeServiceImpl(),
  );
}
