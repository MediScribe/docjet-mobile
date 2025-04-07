import 'dart:io'; // Import needed for FileStat, Directory etc.
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:record/record.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
import 'package:docjet_mobile/features/audio_recorder/data/repositories/audio_recorder_repository_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/transcription_remote_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/transcription_merge_service.dart';

// Import entities needed only if used by these specific tests (likely not for permissions)
// import 'package:docjet_mobile/features/audio_recorder/domain/entities/local_job.dart';
// import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
// import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';

// Import the generated mock file - IMPORTANT: Use a unique name for the output
@GenerateNiceMocks(
  [
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
  ],
  // Custom mock output name if needed to avoid clashes, or ensure consistent naming across files
  // customMocks: [MockSpec<YourType>(as: #MockYourTypeCustomName)],
)
import 'audio_recorder_repository_impl_permissions_test.mocks.dart'; // Adjusted mock import name

void main() {
  late AudioRecorderRepositoryImpl repository;
  late MockAudioLocalDataSource mockAudioLocalDataSource;
  late MockAudioFileManager mockFileManager;
  late MockLocalJobStore mockLocalJobStore;
  late MockTranscriptionRemoteDataSource mockRemoteDataSource;
  late MockTranscriptionMergeService mockTranscriptionMergeService;

  setUp(() {
    // Reset mocks for every test
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

  // --- Test Groups for Permissions ---
  group('checkPermission', () {
    test(
      'should return true when local data source check is successful',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.checkPermission(),
        ).thenAnswer((_) async => true);
        // Act
        final result = await repository.checkPermission();
        // Assert
        expect(result, equals(const Right(true)));
        verify(mockAudioLocalDataSource.checkPermission());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
        // Verify other mocks not used
        verifyZeroInteractions(mockFileManager);
        verifyZeroInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return false when local data source check returns false',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.checkPermission(),
        ).thenAnswer((_) async => false);
        // Act
        final result = await repository.checkPermission();
        // Assert
        expect(result, equals(const Right(false)));
        verify(mockAudioLocalDataSource.checkPermission());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
        // Verify other mocks not used
        verifyZeroInteractions(mockFileManager);
        verifyZeroInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return PermissionFailure when local data source throws AudioPermissionException',
      () async {
        // Arrange
        const exception = AudioPermissionException('Permission check failed');
        when(mockAudioLocalDataSource.checkPermission()).thenThrow(exception);
        // Act
        final result = await repository.checkPermission();
        // Assert
        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<PermissionFailure>());
        verify(mockAudioLocalDataSource.checkPermission());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
        // Verify other mocks not used
        verifyZeroInteractions(mockFileManager);
        verifyZeroInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockRemoteDataSource);
      },
    );

    test('should return PlatformFailure for unexpected exceptions', () async {
      // Arrange
      final exception = Exception('Unexpected error');
      when(mockAudioLocalDataSource.checkPermission()).thenThrow(exception);
      // Act
      final result = await repository.checkPermission();
      // Assert
      expect(result.isLeft(), isTrue);
      final failure = result.fold((l) => l, (r) => null);
      expect(failure, isA<PlatformFailure>());
      verify(mockAudioLocalDataSource.checkPermission());
      verifyNoMoreInteractions(mockAudioLocalDataSource);
      // Verify other mocks not used
      verifyZeroInteractions(mockFileManager);
      verifyZeroInteractions(mockLocalJobStore);
      verifyZeroInteractions(mockRemoteDataSource);
    });
  });

  group('requestPermission', () {
    test(
      'should return true when local data source request is successful',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.requestPermission(),
        ).thenAnswer((_) async => true);
        // Act
        final result = await repository.requestPermission();
        // Assert
        expect(result, equals(const Right(true)));
        verify(mockAudioLocalDataSource.requestPermission());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
        // Verify other mocks not used
        verifyZeroInteractions(mockFileManager);
        verifyZeroInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return false when local data source request returns false',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.requestPermission(),
        ).thenAnswer((_) async => false);
        // Act
        final result = await repository.requestPermission();
        // Assert
        expect(result, equals(const Right(false)));
        verify(mockAudioLocalDataSource.requestPermission());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
        // Verify other mocks not used
        verifyZeroInteractions(mockFileManager);
        verifyZeroInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return PermissionFailure when local data source throws AudioPermissionException',
      () async {
        // Arrange
        const exception = AudioPermissionException('Permission request failed');
        when(mockAudioLocalDataSource.requestPermission()).thenThrow(exception);
        // Act
        final result = await repository.requestPermission();
        // Assert
        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<PermissionFailure>());
        verify(mockAudioLocalDataSource.requestPermission());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
        // Verify other mocks not used
        verifyZeroInteractions(mockFileManager);
        verifyZeroInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockRemoteDataSource);
      },
    );

    test('should return PlatformFailure for unexpected exceptions', () async {
      // Arrange
      final exception = Exception('Unexpected error');
      when(mockAudioLocalDataSource.requestPermission()).thenThrow(exception);
      // Act
      final result = await repository.requestPermission();
      // Assert
      expect(result.isLeft(), isTrue);
      final failure = result.fold((l) => l, (r) => null);
      expect(failure, isA<PlatformFailure>());
      verify(mockAudioLocalDataSource.requestPermission());
      verifyNoMoreInteractions(mockAudioLocalDataSource);
      // Verify other mocks not used
      verifyZeroInteractions(mockFileManager);
      verifyZeroInteractions(mockLocalJobStore);
      verifyZeroInteractions(mockRemoteDataSource);
    });
  });

  group('openAppSettings', () {
    // ... tests remain unchanged ...
  });
}
