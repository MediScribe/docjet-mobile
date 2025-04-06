import 'package:get_it/get_it.dart';
import 'package:record/record.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_getter.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/just_audio_duration_getter_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/repositories/audio_recorder_repository_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager_impl.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // --- Feature: Audio Recorder ---

  // Cubits (Now depend directly on Repository)
  sl.registerFactory(() => AudioListCubit(repository: sl()));
  sl.registerFactory(() => AudioRecordingCubit(repository: sl()));

  // Repository (Depends on Data Source)
  sl.registerLazySingleton<AudioRecorderRepository>(
    () => AudioRecorderRepositoryImpl(localDataSource: sl(), fileManager: sl()),
  );

  // Data Source (Depends on external libs and core platform interfaces)
  sl.registerLazySingleton<AudioLocalDataSource>(
    () => AudioLocalDataSourceImpl(
      recorder: sl(),
      pathProvider: sl(),
      permissionHandler: sl(),
      audioConcatenationService: sl(),
      fileSystem: sl(),
    ),
  );

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
  sl.registerLazySingleton<AudioDurationGetter>(
    () => JustAudioDurationGetterImpl(fileSystem: sl()),
  );

  sl.registerLazySingleton<AudioConcatenationService>(
    () => DummyAudioConcatenator(),
  );

  // Register AudioFileManager
  sl.registerLazySingleton<AudioFileManager>(
    () => AudioFileManagerImpl(
      fileSystem: sl(),
      pathProvider: sl(),
      audioDurationGetter: sl(),
    ),
  );
}
