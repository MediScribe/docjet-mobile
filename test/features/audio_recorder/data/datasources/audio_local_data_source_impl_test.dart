import 'dart:io'; // Keep for Directory/File types used in mocks if needed

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:permission_handler/permission_handler.dart'
    show Permission, PermissionStatus;
import 'package:record/record.dart';

// Import interfaces and exceptions
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';

// Import generated mocks
import 'audio_local_data_source_impl_test.mocks.dart';

// Update mock annotations
@GenerateMocks([
  AudioRecorder,
  FileSystem,
  PathProvider,
  PermissionHandler,
  Directory, // Mock Directory for pathProvider return
  File, // Mock File for listDirectorySync results
  FileSystemEntity, // Mock base class for listDirectorySync
])
void main() {
  late AudioLocalDataSourceImpl dataSource;
  late MockAudioRecorder mockAudioRecorder;
  late MockFileSystem mockFileSystem;
  late MockPathProvider mockPathProvider;
  late MockPermissionHandler mockPermissionHandler;
  late MockDirectory mockDirectory;

  final tPermission = Permission.microphone;
  const tFakeDocPath = '/fake/doc/path';

  setUp(() {
    // Keep the main setup for initializing mocks
    mockAudioRecorder = MockAudioRecorder();
    mockFileSystem = MockFileSystem();
    mockPathProvider = MockPathProvider();
    mockPermissionHandler = MockPermissionHandler();
    mockDirectory = MockDirectory();

    dataSource = AudioLocalDataSourceImpl(
      recorder: mockAudioRecorder,
      fileSystem: mockFileSystem,
      pathProvider: mockPathProvider,
      permissionHandler: mockPermissionHandler,
    );

    // Minimal common setup - moved specific path setup into tests
    when(mockDirectory.path).thenReturn(tFakeDocPath);
  });

  // --- Test Groups (Rewritten) ---

  group('checkPermission', () {
    test(
      'should return true when permission handler status is granted',
      () async {
        // Arrange
        when(
          mockPermissionHandler.status(tPermission),
        ).thenAnswer((_) async => PermissionStatus.granted);
        // Act
        final result = await dataSource.checkPermission();
        // Assert
        expect(result, isTrue);
        verify(mockPermissionHandler.status(tPermission));
      },
    );

    test(
      'should return false when permission handler status is denied',
      () async {
        // Arrange
        when(
          mockPermissionHandler.status(tPermission),
        ).thenAnswer((_) async => PermissionStatus.denied);
        // Act
        final result = await dataSource.checkPermission();
        // Assert
        expect(result, isFalse);
        verify(mockPermissionHandler.status(tPermission));
      },
    );

    test(
      'should throw AudioPermissionException when permission handler status throws',
      () async {
        // Arrange
        final exception = Exception('Handler error');
        when(mockPermissionHandler.status(tPermission)).thenThrow(exception);
        // Act & Assert
        expect(
          () => dataSource.checkPermission(),
          throwsA(isA<AudioPermissionException>()),
        );
        verify(mockPermissionHandler.status(tPermission));
      },
    );
  });

  group('requestPermission', () {
    test('should return true when permission request is granted', () async {
      // Arrange
      when(
        mockPermissionHandler.request([tPermission]),
      ).thenAnswer((_) async => {tPermission: PermissionStatus.granted});
      // Act
      final result = await dataSource.requestPermission();
      // Assert
      expect(result, isTrue);
      verify(mockPermissionHandler.request([tPermission]));
    });

    test('should return false when permission request is denied', () async {
      // Arrange
      when(
        mockPermissionHandler.request([tPermission]),
      ).thenAnswer((_) async => {tPermission: PermissionStatus.denied});
      // Act
      final result = await dataSource.requestPermission();
      // Assert
      expect(result, isFalse);
      verify(mockPermissionHandler.request([tPermission]));
    });

    test(
      'should throw AudioPermissionException when permission request throws',
      () async {
        // Arrange
        final exception = Exception('Request failed');
        when(mockPermissionHandler.request([tPermission])).thenThrow(exception);
        // Act & Assert
        expect(
          () => dataSource.requestPermission(),
          throwsA(isA<AudioPermissionException>()),
        );
        verify(mockPermissionHandler.request([tPermission]));
      },
    );
  });

  group('startRecording', () {
    const tFilePathPrefix = '$tFakeDocPath/recording_';

    test(
      'should throw AudioPermissionException if checkPermission returns false',
      () async {
        // Arrange
        when(
          mockPermissionHandler.status(tPermission),
        ).thenAnswer((_) async => PermissionStatus.denied);
        // Act & Assert
        expect(
          () => dataSource.startRecording(),
          throwsA(isA<AudioPermissionException>()),
        );
        verify(mockPermissionHandler.status(tPermission));
        verifyNever(mockPathProvider.getApplicationDocumentsDirectory());
        verifyNever(mockAudioRecorder.start(any, path: anyNamed('path')));
      },
    );

    test(
      'should call recorder.start with generated path and return path on success (dir exists)',
      () async {
        // Arrange
        when(
          mockPermissionHandler.status(tPermission),
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          mockPathProvider.getApplicationDocumentsDirectory(),
        ).thenAnswer((_) async => mockDirectory); // Setup path provider
        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => true);
        when(
          mockAudioRecorder.start(any, path: anyNamed('path')),
        ).thenAnswer((_) async => Future.value());

        // Act
        final resultPath = await dataSource.startRecording();

        // Assert
        expect(resultPath, startsWith(tFilePathPrefix));
        expect(resultPath, endsWith('.m4a'));
        final pathCapture =
            verify(
              mockAudioRecorder.start(any, path: captureAnyNamed('path')),
            ).captured.single;
        expect(pathCapture, resultPath);
        verify(mockPathProvider.getApplicationDocumentsDirectory());
        verify(mockFileSystem.directoryExists(tFakeDocPath));
        verifyNever(
          mockFileSystem.createDirectory(any, recursive: anyNamed('recursive')),
        );
      },
    );

    test(
      'should create directory if it does not exist then start recording',
      () async {
        // Arrange
        when(
          mockPermissionHandler.status(tPermission),
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          mockPathProvider.getApplicationDocumentsDirectory(),
        ).thenAnswer((_) async => mockDirectory); // Setup path provider
        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => false);
        when(
          mockFileSystem.createDirectory(tFakeDocPath, recursive: true),
        ).thenAnswer((_) async => Future.value());
        when(
          mockAudioRecorder.start(any, path: anyNamed('path')),
        ).thenAnswer((_) async => Future.value());

        // Act
        final resultPath = await dataSource.startRecording();

        // Assert
        expect(resultPath, startsWith(tFilePathPrefix));
        verify(mockPermissionHandler.status(tPermission));
        verify(mockPathProvider.getApplicationDocumentsDirectory());
        verify(mockFileSystem.directoryExists(tFakeDocPath));
        verify(mockFileSystem.createDirectory(tFakeDocPath, recursive: true));
        verify(mockAudioRecorder.start(any, path: captureAnyNamed('path')));
      },
    );

    test(
      'should throw AudioRecordingException if recorder.start throws',
      () async {
        // Arrange
        when(
          mockPermissionHandler.status(tPermission),
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          mockPathProvider.getApplicationDocumentsDirectory(),
        ).thenAnswer((_) async => mockDirectory);
        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => true);
        final exception = Exception('Recorder failed');
        when(
          mockAudioRecorder.start(any, path: anyNamed('path')),
        ).thenThrow(exception);

        // Act
        AudioRecordingException? caughtException;
        try {
          await dataSource.startRecording();
        } on AudioRecordingException catch (e) {
          caughtException = e;
        }

        // Assert
        expect(
          caughtException,
          isNotNull,
          reason: 'Expected AudioRecordingException was not thrown.',
        );
        expect(caughtException, isA<AudioRecordingException>());
        expect(
          dataSource.currentRecordingPath,
          isNull,
          reason:
              'currentRecordingPath should be null after startRecording fails.',
        );
        verify(mockAudioRecorder.start(any, path: anyNamed('path')));
      },
    );
  });

  group('stopRecording', () {
    const tPath = '$tFakeDocPath/test.m4a';

    test(
      'should return path when recorder stops successfully and file exists',
      () async {
        // Arrange
        dataSource.testingSetCurrentRecordingPath = tPath;
        when(mockAudioRecorder.stop()).thenAnswer((_) async => Future.value());
        when(mockFileSystem.fileExists(tPath)).thenAnswer((_) async => true);
        // Act
        final result = await dataSource.stopRecording();
        // Assert
        expect(result, tPath);
        expect(dataSource.currentRecordingPath, isNull);
        verify(mockAudioRecorder.stop());
        verify(mockFileSystem.fileExists(tPath));
      },
    );

    test(
      'should throw RecordingFileNotFoundException if file does not exist after stop',
      () async {
        // Arrange
        dataSource.testingSetCurrentRecordingPath = tPath;
        when(mockAudioRecorder.stop()).thenAnswer((_) async => Future.value());
        when(mockFileSystem.fileExists(tPath)).thenAnswer((_) async => false);

        // Act
        RecordingFileNotFoundException? caughtException;
        try {
          await dataSource.stopRecording();
        } on RecordingFileNotFoundException catch (e) {
          caughtException = e;
        }

        // Assert
        expect(
          caughtException,
          isNotNull,
          reason: 'Expected RecordingFileNotFoundException was not thrown.',
        );
        expect(caughtException, isA<RecordingFileNotFoundException>());
        expect(
          dataSource.currentRecordingPath,
          isNull,
          reason:
              'currentRecordingPath should be null after stopRecording fails due to missing file.',
        );
        verify(mockAudioRecorder.stop());
        verify(mockFileSystem.fileExists(tPath));
      },
    );

    test(
      'should throw NoActiveRecordingException if path is null initially',
      () async {
        // Arrange
        dataSource.testingSetCurrentRecordingPath = null;
        when(mockAudioRecorder.stop()).thenAnswer((_) async => Future.value());

        // Act & Assert
        expect(
          () => dataSource.stopRecording(),
          throwsA(isA<NoActiveRecordingException>()),
        );
        verifyNever(mockAudioRecorder.stop());
        verifyNever(mockFileSystem.fileExists(any));
      },
    );

    test(
      'should throw AudioRecordingException if recorder.stop throws',
      () async {
        // Arrange
        dataSource.testingSetCurrentRecordingPath = tPath;
        final exception = Exception('Stop failed');
        when(mockAudioRecorder.stop()).thenThrow(exception);
        // Act & Assert
        expect(
          () => dataSource.stopRecording(),
          throwsA(isA<AudioRecordingException>()),
        );
        expect(dataSource.currentRecordingPath, isNull);
        verify(mockAudioRecorder.stop());
        verifyNever(mockFileSystem.fileExists(any));
      },
    );
  });

  group('pauseRecording', () {
    const tPath = '$tFakeDocPath/pause_test.m4a';

    test('should call recorder.pause when recording path is set', () async {
      // Arrange
      dataSource.testingSetCurrentRecordingPath = tPath;
      when(mockAudioRecorder.pause()).thenAnswer((_) async => Future.value());
      // Act
      await dataSource.pauseRecording();
      // Assert
      verify(mockAudioRecorder.pause());
    });

    test('should throw NoActiveRecordingException if path is null', () async {
      // Arrange
      dataSource.testingSetCurrentRecordingPath = null;
      // Act & Assert
      expect(
        () => dataSource.pauseRecording(),
        throwsA(isA<NoActiveRecordingException>()),
      );
      verifyNever(mockAudioRecorder.pause());
    });

    test(
      'should throw AudioRecordingException if recorder.pause throws',
      () async {
        // Arrange
        dataSource.testingSetCurrentRecordingPath = tPath;
        final exception = Exception('Pause failed');
        when(mockAudioRecorder.pause()).thenThrow(exception);
        // Act & Assert
        expect(
          () => dataSource.pauseRecording(),
          throwsA(isA<AudioRecordingException>()),
        );
        verify(mockAudioRecorder.pause());
      },
    );
  });

  group('resumeRecording', () {
    const tPath = '$tFakeDocPath/resume_test.m4a';

    test('should call recorder.resume when recording path is set', () async {
      // Arrange
      dataSource.testingSetCurrentRecordingPath = tPath;
      when(mockAudioRecorder.resume()).thenAnswer((_) async => Future.value());
      // Act
      await dataSource.resumeRecording();
      // Assert
      verify(mockAudioRecorder.resume());
    });

    test('should throw NoActiveRecordingException if path is null', () async {
      // Arrange
      dataSource.testingSetCurrentRecordingPath = null;
      // Act & Assert
      expect(
        () => dataSource.resumeRecording(),
        throwsA(isA<NoActiveRecordingException>()),
      );
      verifyNever(mockAudioRecorder.resume());
    });

    test(
      'should throw AudioRecordingException if recorder.resume throws',
      () async {
        // Arrange
        dataSource.testingSetCurrentRecordingPath = tPath;
        final exception = Exception('Resume failed');
        when(mockAudioRecorder.resume()).thenThrow(exception);
        // Act & Assert
        expect(
          () => dataSource.resumeRecording(),
          throwsA(isA<AudioRecordingException>()),
        );
        verify(mockAudioRecorder.resume());
      },
    );
  });

  group('deleteRecording', () {
    const tFilePath = '$tFakeDocPath/delete_me.m4a';

    test('should call fileSystem.deleteFile if file exists', () async {
      // Arrange
      when(mockFileSystem.fileExists(tFilePath)).thenAnswer((_) async => true);
      when(
        mockFileSystem.deleteFile(tFilePath),
      ).thenAnswer((_) async => Future.value());
      // Act
      await dataSource.deleteRecording(tFilePath);
      // Assert
      verify(mockFileSystem.fileExists(tFilePath));
      verify(mockFileSystem.deleteFile(tFilePath));
    });

    test(
      'should throw RecordingFileNotFoundException if file does not exist',
      () async {
        // Arrange
        when(
          mockFileSystem.fileExists(tFilePath),
        ).thenAnswer((_) async => false);
        // Act & Assert
        expect(
          () => dataSource.deleteRecording(tFilePath),
          throwsA(isA<RecordingFileNotFoundException>()),
        );
        verify(mockFileSystem.fileExists(tFilePath));
        verifyNever(mockFileSystem.deleteFile(any));
      },
    );

    test(
      'should throw AudioFileSystemException if fileSystem.deleteFile throws',
      () async {
        // Arrange
        when(
          mockFileSystem.fileExists(tFilePath),
        ).thenAnswer((_) async => true);
        final exception = Exception('Delete failed');
        when(mockFileSystem.deleteFile(tFilePath)).thenThrow(exception);

        // Act
        AudioFileSystemException? caughtException;
        try {
          await dataSource.deleteRecording(tFilePath);
        } on AudioFileSystemException catch (e) {
          caughtException = e;
        }

        // Assert
        expect(
          caughtException,
          isNotNull,
          reason: 'Expected AudioFileSystemException was not thrown.',
        );
        expect(caughtException, isA<AudioFileSystemException>());
        verify(mockFileSystem.fileExists(tFilePath));
        verify(
          mockFileSystem.deleteFile(tFilePath),
        ); // Verify the call that threw
      },
    );
  });

  group('getAudioDuration', () {
    // Still skipped because AudioPlayer is created internally
    test(
      'should return duration when player gets it successfully',
      () async {},
      skip: 'Cannot mock internal AudioPlayer() creation easily.',
    );
    test(
      'should throw AudioPlayerException if setFilePath returns null',
      () async {},
      skip: 'Cannot mock internal AudioPlayer() creation easily.',
    );
    test(
      'should throw AudioPlayerException if setFilePath throws',
      () async {},
      skip: 'Cannot mock internal AudioPlayer() creation easily.',
    );
    test(
      'should always call dispose even if setFilePath throws',
      () async {},
      skip: 'Cannot mock internal AudioPlayer() creation easily.',
    );
    test(
      'should throw RecordingFileNotFoundException if file does not exist before getting duration',
      () async {},
      skip: 'Cannot mock internal AudioPlayer() creation easily.',
    );
  });

  group('listRecordingFiles', () {
    final tDirPath = tFakeDocPath; // Use constant
    final tFile1Path = '$tDirPath/rec1.m4a';
    final tFile2Path = '$tDirPath/rec2.m4a';
    final tOtherFilePath = '$tDirPath/other.txt';

    test(
      'should return list of .m4a file paths when directory exists',
      () async {
        // Arrange
        final mockFile1 = MockFile(); // Create mocks locally
        final mockFile2 = MockFile();
        final mockOtherFile = MockFile();
        when(mockFile1.path).thenReturn(tFile1Path);
        when(mockFile2.path).thenReturn(tFile2Path);
        when(mockOtherFile.path).thenReturn(tOtherFilePath);

        when(
          mockPathProvider.getApplicationDocumentsDirectory(),
        ).thenAnswer((_) async => mockDirectory); // Setup path provider
        when(
          mockFileSystem.directoryExists(tDirPath),
        ).thenAnswer((_) async => true);
        when(
          mockFileSystem.listDirectorySync(tDirPath),
        ).thenReturn([mockFile1, mockOtherFile, mockFile2]);

        // Act
        final result = await dataSource.listRecordingFiles();

        // Assert
        expect(result, equals([tFile1Path, tFile2Path]));
        verify(mockPathProvider.getApplicationDocumentsDirectory());
        verify(mockFileSystem.directoryExists(tDirPath));
        verify(mockFileSystem.listDirectorySync(tDirPath));
        verifyNever(
          mockFileSystem.createDirectory(any, recursive: anyNamed('recursive')),
        );
      },
    );

    test(
      'should return empty list and create directory if it does not exist',
      () async {
        // Arrange
        when(
          mockPathProvider.getApplicationDocumentsDirectory(),
        ).thenAnswer((_) async => mockDirectory); // Setup path provider
        when(
          mockFileSystem.directoryExists(tDirPath),
        ).thenAnswer((_) async => false);
        when(
          mockFileSystem.createDirectory(tDirPath, recursive: true),
        ).thenAnswer((_) async => Future.value());

        // Act
        final result = await dataSource.listRecordingFiles();

        // Assert
        expect(result, isEmpty);
        verify(mockPathProvider.getApplicationDocumentsDirectory());
        verify(mockFileSystem.directoryExists(tDirPath));
        verify(mockFileSystem.createDirectory(tDirPath, recursive: true));
        verifyNever(mockFileSystem.listDirectorySync(any));
      },
    );

    test(
      'should throw AudioFileSystemException if listDirectorySync throws',
      () async {
        // Arrange
        when(
          mockPathProvider.getApplicationDocumentsDirectory(),
        ).thenAnswer((_) async => mockDirectory);
        when(
          mockFileSystem.directoryExists(tDirPath),
        ).thenAnswer((_) async => true);
        final exception = Exception('List failed');
        when(mockFileSystem.listDirectorySync(tDirPath)).thenThrow(exception);

        // Act
        AudioFileSystemException? caughtException;
        try {
          await dataSource.listRecordingFiles();
        } on AudioFileSystemException catch (e) {
          caughtException = e;
        }

        // Assert
        expect(
          caughtException,
          isNotNull,
          reason: 'Expected AudioFileSystemException was not thrown.',
        );
        expect(caughtException, isA<AudioFileSystemException>());
        verify(mockPathProvider.getApplicationDocumentsDirectory());
        verify(mockFileSystem.directoryExists(tDirPath));
        verify(
          mockFileSystem.listDirectorySync(tDirPath),
        ); // Verify the call that threw
      },
    );
  });
}
