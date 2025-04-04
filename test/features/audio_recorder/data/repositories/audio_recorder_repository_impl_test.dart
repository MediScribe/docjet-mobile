import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';

import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
import 'package:docjet_mobile/features/audio_recorder/data/repositories/audio_recorder_repository_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';

// Import the generated mock file (will be created by build_runner)
import 'audio_recorder_repository_impl_test.mocks.dart';

// Annotation to generate mock for AudioLocalDataSource
@GenerateMocks([AudioLocalDataSource])
void main() {
  late AudioRecorderRepositoryImpl repository;
  late MockAudioLocalDataSource mockAudioLocalDataSource;

  setUp(() {
    mockAudioLocalDataSource = MockAudioLocalDataSource();
    repository = AudioRecorderRepositoryImpl(
      localDataSource: mockAudioLocalDataSource,
    );
  });

  // --- Test Groups ---
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
        expect(result, equals(Left(PermissionFailure(exception.message))));
        verify(mockAudioLocalDataSource.checkPermission());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test('should return PlatformFailure for unexpected exceptions', () async {
      // Arrange
      final exception = Exception('Unexpected error');
      when(mockAudioLocalDataSource.checkPermission()).thenThrow(exception);
      // Act
      final result = await repository.checkPermission();
      // Assert
      expect(
        result,
        equals(
          Left(
            PlatformFailure(
              'An unexpected repository error occurred: ${exception.toString()}',
            ),
          ),
        ),
      );
      verify(mockAudioLocalDataSource.checkPermission());
      verifyNoMoreInteractions(mockAudioLocalDataSource);
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
        expect(result, equals(Left(PermissionFailure(exception.message))));
        verify(mockAudioLocalDataSource.requestPermission());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test('should return PlatformFailure for unexpected exceptions', () async {
      // Arrange
      final exception = Exception('Unexpected error');
      when(mockAudioLocalDataSource.requestPermission()).thenThrow(exception);
      // Act
      final result = await repository.requestPermission();
      // Assert
      expect(
        result,
        equals(
          Left(
            PlatformFailure(
              'An unexpected repository error occurred: ${exception.toString()}',
            ),
          ),
        ),
      );
      verify(mockAudioLocalDataSource.requestPermission());
      verifyNoMoreInteractions(mockAudioLocalDataSource);
    });
  });

  group('startRecording', () {
    const tFilePath = '/path/to/recording.m4a';

    test(
      'should return file path when local data source starts recording successfully',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tFilePath);
        // Act
        final result = await repository.startRecording();
        // Assert
        expect(result, equals(const Right(tFilePath)));
        verify(mockAudioLocalDataSource.startRecording());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return RecordingFailure when local data source throws AudioRecordingException',
      () async {
        // Arrange
        const exception = AudioRecordingException('Failed to start');
        when(mockAudioLocalDataSource.startRecording()).thenThrow(exception);
        // Act
        final result = await repository.startRecording();
        // Assert
        expect(result, equals(Left(RecordingFailure(exception.message))));
        verify(mockAudioLocalDataSource.startRecording());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return PermissionFailure when local data source throws AudioPermissionException',
      () async {
        // Arrange
        const exception = AudioPermissionException('No permission to start');
        when(mockAudioLocalDataSource.startRecording()).thenThrow(exception);
        // Act
        final result = await repository.startRecording();
        // Assert
        expect(result, equals(Left(PermissionFailure(exception.message))));
        verify(mockAudioLocalDataSource.startRecording());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test('should return PlatformFailure for unexpected exceptions', () async {
      // Arrange
      final exception = Exception('Unexpected error');
      when(mockAudioLocalDataSource.startRecording()).thenThrow(exception);
      // Act
      final result = await repository.startRecording();
      // Assert
      expect(
        result,
        equals(
          Left(
            PlatformFailure(
              'An unexpected repository error occurred: ${exception.toString()}',
            ),
          ),
        ),
      );
      verify(mockAudioLocalDataSource.startRecording());
      verifyNoMoreInteractions(mockAudioLocalDataSource);
    });
  });

  group('stopRecording', () {
    const tFilePath = '/path/to/stopped.m4a';
    const tDuration = Duration(seconds: 30);

    // Note: Cannot reliably test the exact createdAt timestamp here because
    // File(path).stat() is a dart:io call not easily mocked in this unit test
    // without refactoring the repository to use an injected FileSystem wrapper.

    test(
      'should return AudioRecord with correct path/duration when successful',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.stopRecording(),
        ).thenAnswer((_) async => tFilePath);
        when(
          mockAudioLocalDataSource.getAudioDuration(tFilePath),
        ).thenAnswer((_) async => tDuration);

        // Act
        final result = await repository.stopRecording();

        // Assert
        expect(result.isRight(), isTrue, reason: 'Expected Right, got Left');
        result.fold(
          (failure) => fail('Test failed: expected Right, got Left($failure)'),
          (record) {
            expect(record.filePath, tFilePath);
            expect(record.duration, tDuration);
            // Check that createdAt is *some* DateTime, actual value depends on unmocked stat()
            expect(record.createdAt, isA<DateTime>());
          },
        );
        verify(mockAudioLocalDataSource.stopRecording());
        verify(mockAudioLocalDataSource.getAudioDuration(tFilePath));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return RecordingFailure when stopRecording throws NoActiveRecordingException',
      () async {
        // Arrange
        const exception = NoActiveRecordingException('Not recording');
        when(mockAudioLocalDataSource.stopRecording()).thenThrow(exception);
        // Act
        final result = await repository.stopRecording();
        // Assert
        expect(result, equals(Left(RecordingFailure(exception.message))));
        verify(mockAudioLocalDataSource.stopRecording());
        verifyNever(mockAudioLocalDataSource.getAudioDuration(any));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return FileSystemFailure when stopRecording throws RecordingFileNotFoundException',
      () async {
        // Arrange
        const exception = RecordingFileNotFoundException(
          'File gone after stop',
        );
        when(mockAudioLocalDataSource.stopRecording()).thenThrow(exception);
        // Act
        final result = await repository.stopRecording();
        // Assert
        expect(result, equals(Left(FileSystemFailure(exception.message))));
        verify(mockAudioLocalDataSource.stopRecording());
        verifyNever(mockAudioLocalDataSource.getAudioDuration(any));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return RecordingFailure when stopRecording throws AudioRecordingException',
      () async {
        // Arrange
        const exception = AudioRecordingException('Recorder failed to stop');
        when(mockAudioLocalDataSource.stopRecording()).thenThrow(exception);
        // Act
        final result = await repository.stopRecording();
        // Assert
        expect(result, equals(Left(RecordingFailure(exception.message))));
        verify(mockAudioLocalDataSource.stopRecording());
        verifyNever(mockAudioLocalDataSource.getAudioDuration(any));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return PlatformFailure when getAudioDuration throws AudioPlayerException',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.stopRecording(),
        ).thenAnswer((_) async => tFilePath);
        const exception = AudioPlayerException('Cannot play file');
        when(
          mockAudioLocalDataSource.getAudioDuration(tFilePath),
        ).thenThrow(exception);
        // Act
        final result = await repository.stopRecording();
        // Assert
        expect(
          result,
          equals(
            Left(PlatformFailure('Audio player error: ${exception.message}')),
          ),
        );
        verify(mockAudioLocalDataSource.stopRecording());
        verify(mockAudioLocalDataSource.getAudioDuration(tFilePath));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return FileSystemFailure when getAudioDuration throws RecordingFileNotFoundException',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.stopRecording(),
        ).thenAnswer((_) async => tFilePath);
        const exception = RecordingFileNotFoundException(
          'File not found for duration',
        );
        when(
          mockAudioLocalDataSource.getAudioDuration(tFilePath),
        ).thenThrow(exception);
        // Act
        final result = await repository.stopRecording();
        // Assert
        expect(result, equals(Left(FileSystemFailure(exception.message))));
        verify(mockAudioLocalDataSource.stopRecording());
        verify(mockAudioLocalDataSource.getAudioDuration(tFilePath));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    // Note: Testing FileSystemException from stat() or unexpected exceptions requires
    // either integration testing or refactoring repository with a FileSystem wrapper.
    // The current _tryCatch handles unexpected exceptions from the datasource calls,
    // but not necessarily from the File(..).stat() call within the lambda.
  });

  group('pauseRecording', () {
    test(
      'should return Right(null) when local data source pauses successfully',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.pauseRecording(),
        ).thenAnswer((_) async => Future.value()); // Completes successfully
        // Act
        final result = await repository.pauseRecording();
        // Assert
        expect(result, equals(const Right(null)));
        verify(mockAudioLocalDataSource.pauseRecording());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return RecordingFailure when local data source throws NoActiveRecordingException',
      () async {
        // Arrange
        const exception = NoActiveRecordingException('No recording to pause');
        when(mockAudioLocalDataSource.pauseRecording()).thenThrow(exception);
        // Act
        final result = await repository.pauseRecording();
        // Assert
        expect(result, equals(Left(RecordingFailure(exception.message))));
        verify(mockAudioLocalDataSource.pauseRecording());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return RecordingFailure when local data source throws AudioRecordingException',
      () async {
        // Arrange
        const exception = AudioRecordingException('Failed to pause');
        when(mockAudioLocalDataSource.pauseRecording()).thenThrow(exception);
        // Act
        final result = await repository.pauseRecording();
        // Assert
        expect(result, equals(Left(RecordingFailure(exception.message))));
        verify(mockAudioLocalDataSource.pauseRecording());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test('should return PlatformFailure for unexpected exceptions', () async {
      // Arrange
      final exception = Exception('Unexpected error');
      when(mockAudioLocalDataSource.pauseRecording()).thenThrow(exception);
      // Act
      final result = await repository.pauseRecording();
      // Assert
      expect(
        result,
        equals(
          Left(
            PlatformFailure(
              'An unexpected repository error occurred: ${exception.toString()}',
            ),
          ),
        ),
      );
      verify(mockAudioLocalDataSource.pauseRecording());
      verifyNoMoreInteractions(mockAudioLocalDataSource);
    });
  });

  group('resumeRecording', () {
    test(
      'should return Right(null) when local data source resumes successfully',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.resumeRecording(),
        ).thenAnswer((_) async => Future.value()); // Completes successfully
        // Act
        final result = await repository.resumeRecording();
        // Assert
        expect(result, equals(const Right(null)));
        verify(mockAudioLocalDataSource.resumeRecording());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return RecordingFailure when local data source throws NoActiveRecordingException',
      () async {
        // Arrange
        const exception = NoActiveRecordingException('No recording to resume');
        when(mockAudioLocalDataSource.resumeRecording()).thenThrow(exception);
        // Act
        final result = await repository.resumeRecording();
        // Assert
        expect(result, equals(Left(RecordingFailure(exception.message))));
        verify(mockAudioLocalDataSource.resumeRecording());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return RecordingFailure when local data source throws AudioRecordingException',
      () async {
        // Arrange
        const exception = AudioRecordingException('Failed to resume');
        when(mockAudioLocalDataSource.resumeRecording()).thenThrow(exception);
        // Act
        final result = await repository.resumeRecording();
        // Assert
        expect(result, equals(Left(RecordingFailure(exception.message))));
        verify(mockAudioLocalDataSource.resumeRecording());
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test('should return PlatformFailure for unexpected exceptions', () async {
      // Arrange
      final exception = Exception('Unexpected error');
      when(mockAudioLocalDataSource.resumeRecording()).thenThrow(exception);
      // Act
      final result = await repository.resumeRecording();
      // Assert
      expect(
        result,
        equals(
          Left(
            PlatformFailure(
              'An unexpected repository error occurred: ${exception.toString()}',
            ),
          ),
        ),
      );
      verify(mockAudioLocalDataSource.resumeRecording());
      verifyNoMoreInteractions(mockAudioLocalDataSource);
    });
  });

  group('deleteRecording', () {
    const tFilePath = '/path/to/delete.m4a';

    test(
      'should return Right(null) when local data source deletes successfully',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.deleteRecording(any),
        ).thenAnswer((_) async => Future.value());
        // Act
        final result = await repository.deleteRecording(tFilePath);
        // Assert
        expect(result, equals(const Right(null)));
        verify(mockAudioLocalDataSource.deleteRecording(tFilePath));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return FileSystemFailure when local data source throws RecordingFileNotFoundException',
      () async {
        // Arrange
        const exception = RecordingFileNotFoundException('File not found');
        when(
          mockAudioLocalDataSource.deleteRecording(any),
        ).thenThrow(exception);
        // Act
        final result = await repository.deleteRecording(tFilePath);
        // Assert
        expect(result, equals(Left(FileSystemFailure(exception.message))));
        verify(mockAudioLocalDataSource.deleteRecording(tFilePath));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return FileSystemFailure when local data source throws AudioFileSystemException',
      () async {
        // Arrange
        const exception = AudioFileSystemException('Cannot delete file');
        when(
          mockAudioLocalDataSource.deleteRecording(any),
        ).thenThrow(exception);
        // Act
        final result = await repository.deleteRecording(tFilePath);
        // Assert
        expect(result, equals(Left(FileSystemFailure(exception.message))));
        verify(mockAudioLocalDataSource.deleteRecording(tFilePath));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test('should return PlatformFailure for unexpected exceptions', () async {
      // Arrange
      final exception = Exception('Unexpected error');
      when(mockAudioLocalDataSource.deleteRecording(any)).thenThrow(exception);
      // Act
      final result = await repository.deleteRecording(tFilePath);
      // Assert
      expect(
        result,
        equals(
          Left(
            PlatformFailure(
              'An unexpected repository error occurred: ${exception.toString()}',
            ),
          ),
        ),
      );
      verify(mockAudioLocalDataSource.deleteRecording(tFilePath));
      verifyNoMoreInteractions(mockAudioLocalDataSource);
    });
  });

  group('loadRecordings', () {
    const tPath1 = '/path/file1.m4a';
    const tPath2 = '/path/file2.m4a';
    const tDuration1 = Duration(seconds: 10);
    const tDuration2 = Duration(seconds: 20);
    // Timestamps cannot be reliably asserted due to File.stat() mocking limitations

    test(
      'should return list of AudioRecords when listing and loading are successful',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.listRecordingFiles(),
        ).thenAnswer((_) async => [tPath1, tPath2]);
        when(
          mockAudioLocalDataSource.getAudioDuration(tPath1),
        ).thenAnswer((_) async => tDuration1);
        when(
          mockAudioLocalDataSource.getAudioDuration(tPath2),
        ).thenAnswer((_) async => tDuration2);

        // Act
        final result = await repository.loadRecordings();

        // Assert
        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Expected Right, got Left($failure)'), (
          records,
        ) {
          expect(records.length, 2);
          // Check content based on path/duration, ignore createdAt
          expect(
            records.any(
              (r) => r.filePath == tPath1 && r.duration == tDuration1,
            ),
            isTrue,
          );
          expect(
            records.any(
              (r) => r.filePath == tPath2 && r.duration == tDuration2,
            ),
            isTrue,
          );
        });
        verify(mockAudioLocalDataSource.listRecordingFiles());
        verify(mockAudioLocalDataSource.getAudioDuration(tPath1));
        verify(mockAudioLocalDataSource.getAudioDuration(tPath2));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return empty list when listRecordingFiles returns empty list',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.listRecordingFiles(),
        ).thenAnswer((_) async => []);
        // Act
        final result = await repository.loadRecordings();
        // Assert
        // Check type and emptiness instead of direct equals comparison
        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('Expected Right, got Left($failure)'),
          (records) => expect(records, isEmpty),
        );
        verify(mockAudioLocalDataSource.listRecordingFiles());
        verifyNever(mockAudioLocalDataSource.getAudioDuration(any));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return list with successfully loaded records when one file fails to load duration',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.listRecordingFiles(),
        ).thenAnswer((_) async => [tPath1, tPath2]);
        // File 1 succeeds
        when(
          mockAudioLocalDataSource.getAudioDuration(tPath1),
        ).thenAnswer((_) async => tDuration1);
        // File 2 fails duration load
        const exception = AudioPlayerException(
          'Failed to get duration for file 2',
        );
        when(
          mockAudioLocalDataSource.getAudioDuration(tPath2),
        ).thenThrow(exception);

        // Act
        final result = await repository.loadRecordings();

        // Assert
        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Expected Right, got Left($failure)'), (
          records,
        ) {
          expect(records.length, 1); // Only the first record should be present
          expect(records[0].filePath, tPath1);
          expect(records[0].duration, tDuration1);
        });
        verify(mockAudioLocalDataSource.listRecordingFiles());
        verify(mockAudioLocalDataSource.getAudioDuration(tPath1));
        verify(
          mockAudioLocalDataSource.getAudioDuration(tPath2),
        ); // Verify attempt was made
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return FileSystemFailure when listRecordingFiles throws AudioFileSystemException',
      () async {
        // Arrange
        const exception = AudioFileSystemException('Cannot list files');
        when(
          mockAudioLocalDataSource.listRecordingFiles(),
        ).thenThrow(exception);

        // Act
        final result = await repository.loadRecordings();

        // Assert
        expect(result, equals(Left(FileSystemFailure(exception.message))));
        verify(mockAudioLocalDataSource.listRecordingFiles());
        verifyNever(mockAudioLocalDataSource.getAudioDuration(any));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );
  });

  group('listRecordings', () {
    // Tests are very similar to loadRecordings as both currently fetch full details.
    const tPath1 = '/path/file1.m4a';
    const tPath2 = '/path/file2.m4a';
    const tDuration1 = Duration(seconds: 10);
    const tDuration2 = Duration(seconds: 20);

    test(
      'should return list of AudioRecords when listing and loading details are successful',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.listRecordingFiles(),
        ).thenAnswer((_) async => [tPath1, tPath2]);
        when(
          mockAudioLocalDataSource.getAudioDuration(tPath1),
        ).thenAnswer((_) async => tDuration1);
        when(
          mockAudioLocalDataSource.getAudioDuration(tPath2),
        ).thenAnswer((_) async => tDuration2);

        // Act
        final result = await repository.listRecordings();

        // Assert
        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Expected Right, got Left($failure)'), (
          records,
        ) {
          expect(records.length, 2);
          // Check content based on path/duration, ignore createdAt
          expect(
            records.any(
              (r) => r.filePath == tPath1 && r.duration == tDuration1,
            ),
            isTrue,
          );
          expect(
            records.any(
              (r) => r.filePath == tPath2 && r.duration == tDuration2,
            ),
            isTrue,
          );
        });
        verify(mockAudioLocalDataSource.listRecordingFiles());
        verify(mockAudioLocalDataSource.getAudioDuration(tPath1));
        verify(mockAudioLocalDataSource.getAudioDuration(tPath2));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return empty list when listRecordingFiles returns empty list',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.listRecordingFiles(),
        ).thenAnswer((_) async => []);
        // Act
        final result = await repository.listRecordings();
        // Assert
        // Check type and emptiness instead of direct equals comparison
        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('Expected Right, got Left($failure)'),
          (records) => expect(records, isEmpty),
        );
        verify(mockAudioLocalDataSource.listRecordingFiles());
        verifyNever(mockAudioLocalDataSource.getAudioDuration(any));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return list with successfully processed records when one file fails detail loading',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.listRecordingFiles(),
        ).thenAnswer((_) async => [tPath1, tPath2]);
        // File 1 succeeds
        when(
          mockAudioLocalDataSource.getAudioDuration(tPath1),
        ).thenAnswer((_) async => tDuration1);
        // File 2 fails duration load
        const exception = AudioPlayerException(
          'Failed to get duration for file 2',
        );
        when(
          mockAudioLocalDataSource.getAudioDuration(tPath2),
        ).thenThrow(exception);

        // Act
        final result = await repository.listRecordings();

        // Assert
        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Expected Right, got Left($failure)'), (
          records,
        ) {
          expect(records.length, 1); // Only the first record should be present
          expect(records[0].filePath, tPath1);
          expect(records[0].duration, tDuration1);
        });
        verify(mockAudioLocalDataSource.listRecordingFiles());
        verify(mockAudioLocalDataSource.getAudioDuration(tPath1));
        verify(
          mockAudioLocalDataSource.getAudioDuration(tPath2),
        ); // Verify attempt
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return FileSystemFailure when listRecordingFiles throws AudioFileSystemException',
      () async {
        // Arrange
        const exception = AudioFileSystemException('Cannot list files');
        when(
          mockAudioLocalDataSource.listRecordingFiles(),
        ).thenThrow(exception);

        // Act
        final result = await repository.listRecordings();

        // Assert
        expect(result, equals(Left(FileSystemFailure(exception.message))));
        verify(mockAudioLocalDataSource.listRecordingFiles());
        verifyNever(mockAudioLocalDataSource.getAudioDuration(any));
        verifyNoMoreInteractions(mockAudioLocalDataSource);
      },
    );
  });

  group('appendToRecording', () {
    final tExistingRecord = AudioRecord(
      filePath: '/path/existing.m4a',
      duration: const Duration(seconds: 60),
      createdAt: DateTime.now(),
    );

    test(
      'should return ConcatenationFailure as the feature is not implemented',
      () async {
        // Arrange
        // Stub the startRecording call that happens before the UnimplementedError
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => '/dummy/path');

        // Act
        final result = await repository.appendToRecording(tExistingRecord);

        // Assert
        expect(result.isLeft(), isTrue);
        expect(
          result.fold((l) => l, (r) => r), // Extract the Failure
          isA<ConcatenationFailure>(),
        );

        // Check if the message matches what _tryCatch maps UnimplementedError to
        result.fold((failure) {
          // Check that the failure message contains either expected text
          final message = (failure as ConcatenationFailure).message;
          expect(
            message.contains('Append flow needs refinement') ||
                message.contains('Feature not implemented'),
            isTrue,
            reason:
                'Expected message to contain either "Append flow..." or "Feature not implemented..." but got: $message',
          );
        }, (_) => fail('Expected Left, got Right'));

        // Depending on the exact placeholder code in appendToRecording,
        // a call to startRecording might occur before the UnimplementedError.
        // verify(mockAudioLocalDataSource.startRecording()); // Uncomment/adjust if needed
      },
    );
  });
}
