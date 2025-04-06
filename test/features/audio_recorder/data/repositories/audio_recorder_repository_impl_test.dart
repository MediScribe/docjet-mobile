import 'dart:io'; // Import needed for FileStat
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
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager.dart';

// Import the generated mock file
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

// Define mocks for ALL dependencies needed by the repository AND its dependencies
// This ensures the .mocks.dart file is self-contained for this test suite.
@GenerateNiceMocks([
  MockSpec<AudioLocalDataSource>(),
  MockSpec<AudioFileManager>(),
  // Include mocks potentially needed by the above mocks or test setup
  MockSpec<AudioRecorder>(),
  MockSpec<FileSystem>(),
  MockSpec<PathProvider>(),
  MockSpec<PermissionHandler>(),
  MockSpec<AudioConcatenationService>(),
  MockSpec<Directory>(),
  MockSpec<FileStat>(),
  MockSpec<FileSystemEntity>(),
])
void main() {
  late AudioRecorderRepositoryImpl repository;
  late MockAudioLocalDataSource mockAudioLocalDataSource;
  late MockAudioFileManager mockFileManager;

  setUp(() {
    mockAudioLocalDataSource = MockAudioLocalDataSource();
    mockFileManager = MockAudioFileManager();
    repository = AudioRecorderRepositoryImpl(
      localDataSource: mockAudioLocalDataSource,
      fileManager: mockFileManager,
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
      // Check type and value separately
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(
          failure,
          isA<PlatformFailure>().having(
            (f) => f.message,
            'message',
            'An unexpected error occurred: ${exception.toString()}',
          ),
        ),
        (_) => fail('Expected Left, got Right'),
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
      // Check type and value separately
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(
          failure,
          isA<PlatformFailure>().having(
            (f) => f.message,
            'message',
            'An unexpected error occurred: ${exception.toString()}',
          ),
        ),
        (_) => fail('Expected Left, got Right'),
      );
      verify(mockAudioLocalDataSource.requestPermission());
      verifyNoMoreInteractions(mockAudioLocalDataSource);
    });
  });

  group('startRecording', () {
    const tRecordingPath = '/path/to/recording.m4a';

    test('should call localDataSource.startRecording and store path', () async {
      // Arrange
      when(
        mockAudioLocalDataSource.startRecording(),
      ).thenAnswer((_) async => tRecordingPath);
      // Act
      final result = await repository.startRecording();
      // Assert
      expect(
        result,
        equals(const Right(tRecordingPath)),
      ); // Repository now returns path
      verify(mockAudioLocalDataSource.startRecording());
    });

    test(
      'should return Failure when localDataSource.startRecording throws',
      () async {
        // Arrange
        const tException = AudioRecordingException('Start failed');
        when(mockAudioLocalDataSource.startRecording()).thenThrow(tException);
        // Act
        final result = await repository.startRecording();
        // Assert
        expect(result, equals(Left(RecordingFailure(tException.message))));
        verify(mockAudioLocalDataSource.startRecording());
      },
    );
  });

  group('stopRecording', () {
    const tRecordingPath = '/path/to/stop/recording.m4a';
    const tFinalPath = '$tRecordingPath-final';

    test(
      'should call localDataSource.stopRecording with stored path and return Right(finalPath)',
      () async {
        // Arrange: Simulate startRecording first to set the path
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tRecordingPath);
        await repository.startRecording(); // Set internal state

        when(
          mockAudioLocalDataSource.stopRecording(recordingPath: tRecordingPath),
        ).thenAnswer((_) async => tFinalPath);

        // Act
        final result = await repository.stopRecording();

        // Assert
        expect(result, equals(const Right(tFinalPath)));
        verify(
          mockAudioLocalDataSource.stopRecording(recordingPath: tRecordingPath),
        ).called(1);
      },
    );

    test(
      'should return Left(RecordingFailure) when stopRecording throws',
      () async {
        // Arrange: Simulate startRecording first
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tRecordingPath);
        await repository.startRecording(); // Set internal state

        const tException = AudioRecordingException('Stop failed');
        when(
          mockAudioLocalDataSource.stopRecording(recordingPath: tRecordingPath),
        ).thenThrow(tException);

        // Act
        final result = await repository.stopRecording();

        // Assert
        expect(result, equals(Left(RecordingFailure(tException.message))));
        verify(
          mockAudioLocalDataSource.stopRecording(recordingPath: tRecordingPath),
        ).called(1);
      },
    );

    test(
      'should return Left(RecordingFailure) if startRecording was not called first',
      () async {
        // Arrange: No call to startRecording, repository state is null

        // Act
        final result = await repository.stopRecording();

        // Assert
        expect(
          result,
          equals(
            const Left(
              RecordingFailure('No recording path stored in repository.'),
            ),
          ),
        );
        verifyNever(
          mockAudioLocalDataSource.stopRecording(
            recordingPath: anyNamed('recordingPath'),
          ),
        );
      },
    );
  });

  group('pauseRecording', () {
    const tRecordingPath = '/path/to/pause/recording.m4a';

    test(
      'should call localDataSource.pauseRecording with stored path',
      () async {
        // Arrange: Simulate startRecording first
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tRecordingPath);
        await repository.startRecording(); // Set internal state

        when(
          mockAudioLocalDataSource.pauseRecording(
            recordingPath: tRecordingPath,
          ),
        ).thenAnswer((_) async {}); // Completes normally

        // Act
        final result = await repository.pauseRecording();

        // Assert
        expect(result, equals(const Right(null))); // Returns Right(void)
        verify(
          mockAudioLocalDataSource.pauseRecording(
            recordingPath: tRecordingPath,
          ),
        ).called(1);
      },
    );

    test(
      'should return Left(RecordingFailure) when pauseRecording throws',
      () async {
        // Arrange: Simulate startRecording first
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tRecordingPath);
        await repository.startRecording(); // Set internal state

        const tException = AudioRecordingException('Pause failed');
        when(
          mockAudioLocalDataSource.pauseRecording(
            recordingPath: tRecordingPath,
          ),
        ).thenThrow(tException);

        // Act
        final result = await repository.pauseRecording();

        // Assert
        expect(result, equals(Left(RecordingFailure(tException.message))));
        verify(
          mockAudioLocalDataSource.pauseRecording(
            recordingPath: tRecordingPath,
          ),
        ).called(1);
      },
    );

    test(
      'should return Left(RecordingFailure) if startRecording was not called first',
      () async {
        // Arrange: No call to startRecording, repository state is null

        // Act
        final result = await repository.pauseRecording();

        // Assert
        expect(
          result,
          equals(
            const Left(
              RecordingFailure('No recording path stored in repository.'),
            ),
          ),
        );
        verifyNever(
          mockAudioLocalDataSource.pauseRecording(
            recordingPath: anyNamed('recordingPath'),
          ),
        );
      },
    );
  });

  group('resumeRecording', () {
    const tRecordingPath = '/path/to/resume/recording.m4a';

    test(
      'should call localDataSource.resumeRecording with stored path',
      () async {
        // Arrange: Simulate startRecording first
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tRecordingPath);
        await repository.startRecording(); // Set internal state

        when(
          mockAudioLocalDataSource.resumeRecording(
            recordingPath: tRecordingPath,
          ),
        ).thenAnswer((_) async {}); // Completes normally

        // Act
        final result = await repository.resumeRecording();

        // Assert
        expect(result, equals(const Right(null))); // Returns Right(void)
        verify(
          mockAudioLocalDataSource.resumeRecording(
            recordingPath: tRecordingPath,
          ),
        ).called(1);
      },
    );

    test(
      'should return Left(RecordingFailure) when resumeRecording throws',
      () async {
        // Arrange: Simulate startRecording first
        when(
          mockAudioLocalDataSource.startRecording(),
        ).thenAnswer((_) async => tRecordingPath);
        await repository.startRecording(); // Set internal state

        const tException = AudioRecordingException('Resume failed');
        when(
          mockAudioLocalDataSource.resumeRecording(
            recordingPath: tRecordingPath,
          ),
        ).thenThrow(tException);

        // Act
        final result = await repository.resumeRecording();

        // Assert
        expect(result, equals(Left(RecordingFailure(tException.message))));
        verify(
          mockAudioLocalDataSource.resumeRecording(
            recordingPath: tRecordingPath,
          ),
        ).called(1);
      },
    );

    test(
      'should return Left(RecordingFailure) if startRecording was not called first',
      () async {
        // Arrange: No call to startRecording, repository state is null

        // Act
        final result = await repository.resumeRecording();

        // Assert
        expect(
          result,
          equals(
            const Left(
              RecordingFailure('No recording path stored in repository.'),
            ),
          ),
        );
        verifyNever(
          mockAudioLocalDataSource.resumeRecording(
            recordingPath: anyNamed('recordingPath'),
          ),
        );
      },
    );
  });

  group('deleteRecording', () {
    const tFilePath = '/path/to/delete.m4a';

    test(
      'should call fileManager.deleteRecording and return Right(null)',
      () async {
        // Arrange
        when(
          mockFileManager.deleteRecording(any),
        ).thenAnswer((_) async => Future.value());
        // Act
        final result = await repository.deleteRecording(tFilePath);
        // Assert
        expect(result, equals(const Right(null)));
        verify(mockFileManager.deleteRecording(tFilePath));
        verifyNoMoreInteractions(mockFileManager);
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return FileSystemFailure when fileManager throws RecordingFileNotFoundException',
      () async {
        // Arrange
        const exception = RecordingFileNotFoundException('File not found');
        when(mockFileManager.deleteRecording(any)).thenThrow(exception);
        // Act
        final result = await repository.deleteRecording(tFilePath);
        // Assert
        expect(result, equals(Left(FileSystemFailure(exception.message))));
        verify(mockFileManager.deleteRecording(tFilePath));
        verifyNoMoreInteractions(mockFileManager);
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return FileSystemFailure when fileManager throws AudioFileSystemException',
      () async {
        // Arrange
        const exception = AudioFileSystemException('Cannot delete file');
        when(mockFileManager.deleteRecording(any)).thenThrow(exception);
        // Act
        final result = await repository.deleteRecording(tFilePath);
        // Assert
        expect(result, equals(Left(FileSystemFailure(exception.message))));
        verify(mockFileManager.deleteRecording(tFilePath));
        verifyNoMoreInteractions(mockFileManager);
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );

    test('should return PlatformFailure for unexpected exceptions', () async {
      // Arrange
      final exception = Exception('Unexpected error');
      when(mockFileManager.deleteRecording(any)).thenThrow(exception);
      // Act
      final result = await repository.deleteRecording(tFilePath);
      // Assert
      // Check type and value separately
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(
          failure,
          isA<PlatformFailure>().having(
            (f) => f.message,
            'message',
            'An unexpected error occurred: ${exception.toString()}',
          ),
        ),
        (_) => fail('Expected Left, got Right'),
      );
      verify(mockFileManager.deleteRecording(tFilePath));
      verifyNoMoreInteractions(mockFileManager);
      verifyZeroInteractions(mockAudioLocalDataSource);
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
      'should call fileManager.listRecordingDetails and return Right(List<AudioRecord>)',
      () async {
        // Arrange
        when(
          mockFileManager.listRecordingDetails(),
        ).thenAnswer((_) async => tAudioRecordList);

        // Act
        final result = await repository.loadRecordings();

        // Assert
        verify(mockFileManager.listRecordingDetails());
        expect(result, equals(Right(tAudioRecordList)));
      },
    );

    test(
      'should return empty list when listRecordingDetails returns empty list',
      () async {
        // Arrange
        when(
          mockFileManager.listRecordingDetails(),
        ).thenAnswer((_) async => []); // Return empty list

        // Act
        final result = await repository.loadRecordings();

        // Assert
        verify(mockFileManager.listRecordingDetails());
        expect(result.isRight(), isTrue);
        expect(result.getOrElse(() => throw 'Should be Right!'), isEmpty);
      },
    );

    test(
      'should return Left(FileSystemFailure) on AudioFileSystemException',
      () async {
        // Arrange
        final exception = AudioFileSystemException(
          'Cannot list dir',
          Exception(),
        );
        when(mockFileManager.listRecordingDetails()).thenThrow(exception);
        // Act
        final result = await repository.loadRecordings();
        // Assert
        expect(result, equals(Left(FileSystemFailure(exception.message))));
        verify(mockFileManager.listRecordingDetails());
        verifyNoMoreInteractions(mockFileManager);
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );

    test(
      'should return Left(PlatformFailure) on unexpected Exception',
      () async {
        // Arrange
        final exception = Exception('Unexpected error');
        when(mockFileManager.listRecordingDetails()).thenThrow(exception);
        // Act
        final result = await repository.loadRecordings();
        // Assert
        expect(
          result.fold((l) => l, (r) => r),
          isA<PlatformFailure>().having(
            (f) => f.message,
            'message',
            contains('An unexpected error occurred'),
          ),
        );
        verify(mockFileManager.listRecordingDetails());
        verifyNoMoreInteractions(mockFileManager);
        verifyZeroInteractions(mockAudioLocalDataSource);
      },
    );
  });

  group('appendToRecording', () {
    const tRecordingPath = '/path/to/recording.m4a';

    test(
      'should throw UnimplementedError when called with active recording',
      () async {
        // Arrange
        // Simulate state being set
        // Act & Assert
        expect(
          () => repository.appendToRecording(tRecordingPath),
          throwsA(isA<UnimplementedError>()),
        );
        // Verify internal state is unchanged and datasource not called
        verifyNever(mockAudioLocalDataSource.concatenateRecordings(any));
      },
    );

    test(
      'should throw UnimplementedError when called without active recording',
      () async {
        // Arrange
        // Ensure state is null
        // Act & Assert
        expect(
          () => repository.appendToRecording(tRecordingPath),
          throwsA(isA<UnimplementedError>()),
        );
        // Verify internal state is unchanged and datasource not called
        verifyNever(mockAudioLocalDataSource.concatenateRecordings(any));
      },
    );
  });
}
