# Test File Logger Setup Checklist

**Goal**: Ensure every test file includes the standard logging setup.

**For each unchecked file below:**
1. Add the appropriate relative import: `import '../[relative_path]/test_utils.d.dart';`
2. Inside the `main()` function, add the following lines *before* any `group` or `test` calls:
   ```dart
   // Sets up logging, defaulting to error level.
   // Override default level with environment variable TEST_LOG_LEVEL=debug (or other levels)
   // Or, force a level for this file ONLY by uncommenting & modifying the line below:
   // setUpAll(() => setupTestLogging(LogLevel.debug));
   setUpAll(setupTestLogging); // Default: use environment variable or error level
   tearDownAll(teardownTestLogging);
   ```

---

- [x] `test/example/test_logger_example_test.dart` (Simplified existing setup)
- [ ] `test/example/test_utils_example_test.dart`
- [ ] `test/features/audio_recorder/data/datasources/audio_local_data_source_impl_test.dart`
- [ ] `test/features/audio_recorder/data/datasources/audio_local_data_source_impl_permission_test.dart`
- [ ] `test/features/audio_recorder/data/datasources/fake_transcription_data_source_impl_test.dart`
- [ ] `test/features/audio_recorder/data/repositories/audio_recorder_repository_impl_recording_test.dart`
- [ ] `test/features/audio_recorder/data/repositories/audio_recorder_repository_impl_misc_test.dart`
- [ ] `test/features/audio_recorder/data/repositories/audio_recorder_repository_impl_merge_upload_test.dart`
- [ ] `test/features/audio_recorder/data/repositories/audio_recorder_repository_impl_permissions_test.dart`
- [ ] `test/features/audio_recorder/data/adapters/audio_player_adapter_impl_test.dart`
- [ ] `test/features/audio_recorder/data/factories/audio_playback_service_factory_test.dart`
- [ ] `test/features/audio_recorder/data/mappers/playback_state_mapper_impl_test.dart`
- [ ] `test/features/audio_recorder/data/services/audio_playback_service_impl_test.dart`
- [ ] `test/features/audio_recorder/data/services/transcription_merge_service_impl_test.dart`
- [x] `test/features/audio_recorder/data/services/audio_playback_service_orchestration_test.dart` (Already done)
- [ ] `test/features/audio_recorder/data/services/audio_file_manager_impl_test.dart`
- [ ] `test/features/audio_recorder/data/services/audio_playback_service_lifecycle_test.dart`
- [ ] `test/features/audio_recorder/data/services/audio_playback_service_pause_seek_stop_test.dart`
- [ ] `test/features/audio_recorder/data/services/audio_duration_retriever_impl_test.dart`
- [ ] `test/features/audio_recorder/data/services/audio_playback_service_event_handling_test.dart`
- [ ] `test/features/audio_recorder/data/services/audio_playback_service_play_test.dart`
- [x] `test/features/audio_recorder/domain/entities/local_job_test.dart`
- [ ] `test/features/audio_recorder/domain/entities/transcription_test.dart`
- [ ] `test/features/audio_recorder/domain/entities/transcription_status_test.dart`
- [ ] `test/features/audio_recorder/presentation/cubit/audio_list_cubit_test.dart`
- [ ] `test/features/audio_recorder/presentation/cubit/audio_recording_cubit_test.dart`
- [ ] `test/features/audio_recorder/presentation/pages/audio_recorder_list_page_test.dart`
- [ ] `test/features/audio_recorder/presentation/pages/audio_recorder_page_test.dart`
- [ ] `test/features/audio_recorder/presentation/widgets/audio_player_widget_test.dart` 