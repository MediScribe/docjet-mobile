import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import 'package:docjet_mobile/core/platform/src/path_resolver.dart';
// Import the AppSeeder
import 'package:docjet_mobile/core/services/app_seeder.dart';
import 'package:docjet_mobile/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source_impl.dart';
// Import Fake Data Source
import 'package:docjet_mobile/features/audio_recorder/data/datasources/fake_transcription_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/local_job_store_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/repositories/audio_recorder_repository_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/transcription_merge_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/mappers/playback_state_mapper.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/transcription_remote_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/transcription_merge_service.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_cubit.dart';
import 'package:get_it/get_it.dart';
// Import Hive and related components
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:record/record.dart';
// Import SharedPreferences
import 'package:shared_preferences/shared_preferences.dart';

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

  // + Register SharedPreferences (Async)
  sl.registerSingletonAsync<SharedPreferences>(
    () => SharedPreferences.getInstance(),
  );
  // Ensure SharedPreferences is ready before proceeding
  await sl.isReady<SharedPreferences>();

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
      audioPlayerAdapter: sl(),
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
  sl.registerLazySingleton(() => just_audio.AudioPlayer());

  // --- Core Platform Implementations ---
  // Register concrete implementations for the platform interfaces
  sl.registerLazySingleton<PathProvider>(() => AppPathProvider());

  // Create FileSystem first with a simple path resolver
  final pathProvider = sl<PathProvider>();
  final tempFileSystem = IoFileSystem(pathProvider);

  // Now register PathResolver using the temporary FileSystem
  sl.registerLazySingleton<PathResolver>(
    () => PathResolverImpl(
      pathProvider: pathProvider,
      fileExists: (path) => tempFileSystem.fileExists(path),
    ),
  );

  // Register the final FileSystem
  sl.registerLazySingleton<FileSystem>(() => tempFileSystem);
  sl.registerLazySingleton<PermissionHandler>(() => AppPermissionHandler());

  // --- Core ---
  // Register core dependencies if any (e.g., NetworkClient, Logger)

  // --- Other Features ---
  // Register dependencies for other features

  sl.registerLazySingleton<AudioConcatenationService>(
    () => DummyAudioConcatenator(),
  );

  // Register AudioFileManager
  sl.registerLazySingleton<AudioFileManager>(
    () => AudioFileManagerImpl(
      fileSystem: sl(),
      pathProvider: sl(),
      audioPlayerAdapter: sl(),
    ),
  );

  // Add adapter registration
  sl.registerLazySingleton<AudioPlayerAdapter>(
    () => AudioPlayerAdapterImpl(
      sl<just_audio.AudioPlayer>(),
      pathResolver: sl<PathResolver>(),
    ),
  );

  // Add mapper registration
  sl.registerLazySingleton<PlaybackStateMapper>(
    () => PlaybackStateMapperImpl(),
  );

  // + Register Audio Playback Service
  sl.registerLazySingleton<AudioPlaybackService>(() {
    // Resolve dependencies first
    final adapter = sl<AudioPlayerAdapter>();
    final mapper = sl<PlaybackStateMapper>();

    // **** THE CRITICAL WIRING STEP ****
    // Initialize the mapper with the adapter's streams
    // We MUST cast mapper back to its implementation type to access initialize
    (mapper as PlaybackStateMapperImpl).initialize(
      positionStream: adapter.onPositionChanged,
      durationStream: adapter.onDurationChanged,
      completeStream: adapter.onPlayerComplete,
      playerStateStream: adapter.onPlayerStateChanged,
    );
    // ***********************************

    // Now create the service instance with the wired dependencies
    return AudioPlaybackServiceImpl(
      audioPlayerAdapter: adapter,
      playbackStateMapper: mapper,
    );
  });

  // + Register TranscriptionMergeService
  sl.registerLazySingleton<TranscriptionMergeService>(
    () => TranscriptionMergeServiceImpl(),
  );

  // + Register AppSeeder (Corrected Dependencies)
  sl.registerLazySingleton<AppSeeder>(
    () => AppSeeder(
      localJobStore: sl(),
      fileSystem: sl(),
      audioPlayerAdapter: sl(),
      prefs: sl(), // Use the registered instance
    ),
  );
}

// Function to reset the GetIt container, useful for testing
Future<void> resetInjectionContainer() => sl.reset();
