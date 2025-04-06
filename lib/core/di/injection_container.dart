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
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/check_permission.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/delete_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/pause_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/resume_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/start_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/stop_recording.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/load_recordings.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/usecases/request_permission.dart';
// TODO: Add imports for Append UseCases?
import '../../features/audio_recorder/presentation/cubit/audio_recorder_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // --- Feature: Audio Recorder ---

  // Cubit (Depends on Use Cases)
  sl.registerFactory(
    () => AudioRecorderCubit(
      checkPermissionUseCase: sl(),
      requestPermissionUseCase: sl(),
      startRecordingUseCase: sl(),
      stopRecordingUseCase: sl(),
      pauseRecordingUseCase: sl(),
      resumeRecordingUseCase: sl(),
      deleteRecordingUseCase: sl(),
      loadRecordingsUseCase: sl(),
      // TODO: Inject Append UseCases etc. when added
    ),
  );

  // Use Cases (Depend on Repository)
  sl.registerLazySingleton(() => CheckPermission(sl()));
  sl.registerLazySingleton(() => RequestPermission(sl()));
  sl.registerLazySingleton(() => StartRecording(sl()));
  sl.registerLazySingleton(() => StopRecording(sl()));
  sl.registerLazySingleton(() => PauseRecording(sl()));
  sl.registerLazySingleton(() => ResumeRecording(sl()));
  sl.registerLazySingleton(() => DeleteRecording(sl()));
  sl.registerLazySingleton(() => LoadRecordings(sl()));
  // TODO: Register Append UseCases etc.

  // Repository (Depends on Data Source)
  sl.registerLazySingleton<AudioRecorderRepository>(
    () => AudioRecorderRepositoryImpl(localDataSource: sl()),
  );

  // Data Source (Depends on external libs and core platform interfaces)
  sl.registerLazySingleton<AudioLocalDataSource>(
    () => AudioLocalDataSourceImpl(
      recorder: sl(),
      fileSystem: sl(),
      pathProvider: sl(),
      permissionHandler: sl(),
      audioDurationGetter: sl(),
      audioConcatenationService: sl(),
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
}
