import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:record/record.dart';
import 'package:dartz/dartz.dart';

// Core imports
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';

import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/data/repositories/audio_recorder_repository_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/transcription_remote_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/transcription_merge_service.dart';

// Import entities only if needed
// For loadRecordings test

@GenerateNiceMocks([
  MockSpec<AudioLocalDataSource>(),
  MockSpec<AudioFileManager>(),
  MockSpec<LocalJobStore>(),
  MockSpec<TranscriptionRemoteDataSource>(),
  MockSpec<TranscriptionMergeService>(),
  MockSpec<AudioRecorder>(),
  MockSpec<FileSystem>(),
  MockSpec<PathProvider>(),
  MockSpec<PermissionHandler>(),
  MockSpec<AudioConcatenationService>(),
  MockSpec<Directory>(),
  MockSpec<FileStat>(),
  MockSpec<FileSystemEntity>(),
])
import 'audio_recorder_repository_impl_misc_test.mocks.dart'; // Adjusted mock import name

void main() {
  late AudioRecorderRepositoryImpl repository;
  late MockAudioLocalDataSource mockAudioLocalDataSource;
  late MockAudioFileManager mockFileManager;
  late MockLocalJobStore mockLocalJobStore;
  late MockTranscriptionRemoteDataSource mockRemoteDataSource;
  late MockTranscriptionMergeService mockTranscriptionMergeService;

  setUp(() {
    mockAudioLocalDataSource = MockAudioLocalDataSource();
    mockFileManager = MockAudioFileManager();
    mockLocalJobStore = MockLocalJobStore();
    mockRemoteDataSource = MockTranscriptionRemoteDataSource();
    mockTranscriptionMergeService = MockTranscriptionMergeService();
    repository = AudioRecorderRepositoryImpl(
      localDataSource: mockAudioLocalDataSource,
      fileManager: mockFileManager,
      localJobStore: mockLocalJobStore,
      remoteDataSource: mockRemoteDataSource,
      transcriptionMergeService: mockTranscriptionMergeService,
    );
  });

  // --- Test Groups for Miscellaneous/Deprecated Methods ---

  group('appendToRecording', () {
    test('should throw UnimplementedError when called', () async {
      // Arrange
      const segmentPath = 'test_segment.m4a';

      // Act
      final result = await repository.appendToRecording(segmentPath);

      // Assert
      // Check that it returns Left with a PlatformFailure
      expect(result, isA<Left<Failure, String>>());
      result.fold(
        (failure) => expect(failure, isA<PlatformFailure>()),
        (success) => fail('Expected Failure but got Success'),
      );
    });

    // If appendToRecording ever relied on the internal _currentRecordingPath state,
    // you might add another test case where startRecording was called first,
    // but for now, testing the unimplemented state is sufficient.

    // test(
    //   'should throw UnimplementedError when called WITH active recording',
    //   () async {
    //     // Arrange
    //     // Simulate startRecording if needed
    //     when(mockAudioLocalDataSource.startRecording()).thenAnswer((_) async => '/active/path.m4a');
    //     await repository.startRecording();

    //     // Act & Assert
    //     expect(
    //       () => repository.appendToRecording(tRecordingPath),
    //       throwsA(isA<UnimplementedError>()),
    //     );
    //     verifyNever(mockAudioLocalDataSource.concatenateRecordings(any));
    //   },
    // );
  });
}
