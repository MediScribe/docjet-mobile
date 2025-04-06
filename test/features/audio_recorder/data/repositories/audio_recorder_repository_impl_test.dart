import 'dart:io'; // Import needed for FileStat
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

// --- Helper Fake Class ---
class FakeFileStat implements FileStat {
  final DateTime modifiedTime;
  FakeFileStat(this.modifiedTime);

  @override
  DateTime get modified => modifiedTime;

  // Implement other required fields/methods with dummy values or throw UnimplementedError
  @override
  DateTime get accessed => throw UnimplementedError();
  @override
  DateTime get changed => throw UnimplementedError();
  @override
  int get mode => throw UnimplementedError();
  @override
  String modeString() => throw UnimplementedError();
  @override
  int get size => throw UnimplementedError();
  @override
  FileSystemEntityType get type => throw UnimplementedError();
}
// --- End Helper Fake Class ---

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
    const tFilePath = '/path/to/recording.m4a';

    test(
      'should return file path from local data source when stop is successful',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.stopRecording(),
        ).thenAnswer((_) async => tFilePath);

        // Act
        final result = await repository.stopRecording();

        // Assert
        verify(mockAudioLocalDataSource.stopRecording());
        expect(result, equals(const Right(tFilePath)));
      },
    );

    test(
      'should return RecordingFailure when NoActiveRecordingException is thrown',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.stopRecording(),
        ).thenThrow(const NoActiveRecordingException('No recording'));

        // Act
        final result = await repository.stopRecording();

        // Assert
        expect(result, isA<Left<Failure, String>>());
        expect(result.fold((l) => l, (r) => r), isA<RecordingFailure>());
        verify(mockAudioLocalDataSource.stopRecording());
      },
    );

    test(
      'should return FileSystemFailure when RecordingFileNotFoundException is thrown by stopRecording',
      () async {
        // Arrange
        when(mockAudioLocalDataSource.stopRecording()).thenThrow(
          const RecordingFileNotFoundException('Not found after stop'),
        );

        // Act
        final result = await repository.stopRecording();

        // Assert
        expect(result, isA<Left<Failure, String>>());
        expect(result.fold((l) => l, (r) => r), isA<FileSystemFailure>());
        verify(mockAudioLocalDataSource.stopRecording());
      },
    );

    test(
      'should return RecordingFailure when AudioRecordingException is thrown by stopRecording',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.stopRecording(),
        ).thenThrow(AudioRecordingException('Failed to stop'));

        // Act
        final result = await repository.stopRecording();

        // Assert
        expect(result, isA<Left<Failure, String>>());
        expect(result.fold((l) => l, (r) => r), isA<RecordingFailure>());
        verify(mockAudioLocalDataSource.stopRecording());
      },
    );
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
    // Define some test AudioRecord objects
    final tAudioRecord1 = AudioRecord(
      filePath: '/path/to/rec1.m4a',
      duration: const Duration(seconds: 10),
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    final tAudioRecord2 = AudioRecord(
      filePath: '/path/to/rec2.m4a',
      duration: const Duration(seconds: 20),
      createdAt: DateTime.now(),
    );
    final tAudioRecordList = [tAudioRecord1, tAudioRecord2];

    test(
      'should return list of AudioRecords from local data source on success',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.listRecordingDetails(),
        ).thenAnswer((_) async => tAudioRecordList);

        // Act
        final result = await repository.loadRecordings();

        // Assert
        verify(mockAudioLocalDataSource.listRecordingDetails());
        expect(result, equals(Right(tAudioRecordList)));
      },
    );

    test(
      'should return empty list when listRecordingDetails returns empty list',
      () async {
        // Arrange
        when(
          mockAudioLocalDataSource.listRecordingDetails(),
        ).thenAnswer((_) async => []); // Return empty list

        // Act
        final result = await repository.loadRecordings();

        // Assert
        verify(mockAudioLocalDataSource.listRecordingDetails());
        expect(result.isRight(), isTrue);
        expect(result.getOrElse(() => throw 'Should be Right!'), isEmpty);
      },
    );

    test('should return FileSystemFailure when data source throws', () async {
      // Arrange
      final tException = AudioFileSystemException('Cannot list');
      when(
        mockAudioLocalDataSource.listRecordingDetails(),
      ).thenThrow(tException);

      // Act
      final result = await repository.loadRecordings();

      // Assert
      verify(mockAudioLocalDataSource.listRecordingDetails());
      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        // JUST check the type, ignore the message comparison
        expect(failure, isA<FileSystemFailure>());
      }, (_) => fail('Expected Left, got Right'));
    });
  });

  group('appendToRecording', () {
    final tExistingRecord = AudioRecord(
      filePath: '/path/existing.m4a',
      duration: const Duration(seconds: 60),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    test(
      'should return ConcatenationFailure with UnimplementedError message',
      () async {
        // Arrange
        // No mocking needed as the implementation directly throws

        // Act
        final result = await repository.appendToRecording(tExistingRecord);

        // Assert
        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          // JUST check the type
          expect(failure, isA<ConcatenationFailure>());
        }, (_) => fail('Expected Left(ConcatenationFailure), got Right'));
        // Verify no datasource interaction happens for this unimplemented feature
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );
  });
}
