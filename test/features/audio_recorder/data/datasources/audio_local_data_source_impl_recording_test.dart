import 'dart:io';

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
// Import interfaces needed for the DataSource constructor, even if not directly mocked/used here
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_getter.dart';
// Import the new service interface
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';

// Import generated mocks (will be generated for this file)
import 'audio_local_data_source_impl_recording_test.mocks.dart';

// Generate mocks ONLY for what's needed in these tests + DataSource dependencies
@GenerateNiceMocks([
  MockSpec<AudioRecorder>(),
  MockSpec<FileSystem>(),
  MockSpec<PathProvider>(),
  MockSpec<PermissionHandler>(),
  MockSpec<Directory>(), // Mock Directory for pathProvider return
  // Add mock for unused AudioDurationGetter
  MockSpec<AudioDurationGetter>(),
  MockSpec<AudioConcatenationService>(), // Add mock spec
])
void main() {
  late AudioLocalDataSourceImpl dataSource;
  late MockAudioRecorder mockAudioRecorder;
  late MockFileSystem mockFileSystem;
  late MockPathProvider mockPathProvider;
  late MockPermissionHandler mockPermissionHandler;
  late MockDirectory mockDirectory;
  // Declare unused mock
  late MockAudioDurationGetter mockAudioDurationGetter;
  late MockAudioConcatenationService
  mockAudioConcatenationService; // Declare mock (Fixed formatting)

  final tPermission = Permission.microphone;
  const tFakeDocPath = '/fake/doc/path';

  setUp(() {
    mockAudioRecorder = MockAudioRecorder();
    mockFileSystem = MockFileSystem();
    mockPathProvider = MockPathProvider();
    mockPermissionHandler = MockPermissionHandler();
    mockDirectory = MockDirectory();
    // Instantiate unused mock
    mockAudioDurationGetter = MockAudioDurationGetter();
    mockAudioConcatenationService =
        MockAudioConcatenationService(); // Instantiate mock (Fixed formatting)

    dataSource = AudioLocalDataSourceImpl(
      recorder: mockAudioRecorder, // Provide used mock
      fileSystem: mockFileSystem, // Provide used mock
      pathProvider: mockPathProvider, // Provide used mock
      permissionHandler: mockPermissionHandler, // Provide used mock
      audioDurationGetter: mockAudioDurationGetter, // Provide unused mock
      audioConcatenationService: mockAudioConcatenationService, // Provide mock
    );

    // Common setup for path provider
    when(mockDirectory.path).thenReturn(tFakeDocPath);
    when(
      mockPathProvider.getApplicationDocumentsDirectory(),
    ).thenAnswer((_) async => mockDirectory);
    // Assume permission granted by default for most recording tests
    when(
      mockPermissionHandler.status(tPermission),
    ).thenAnswer((_) async => PermissionStatus.granted);
    when(mockPermissionHandler.request(any)).thenAnswer(
      (_) async => {Permission.microphone: PermissionStatus.granted},
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
        // Permission granted in setUp
        // Path provider setup in setUp
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
        expect(
          dataSource.currentRecordingPath,
          resultPath,
        ); // Check internal state
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
        // Permission granted in setUp
        // Path provider setup in setUp
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
        expect(
          dataSource.currentRecordingPath,
          resultPath,
        ); // Check internal state
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
        final exception = Exception('Start failed');
        // Permission granted in setUp
        // Path provider setup in setUp
        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => true);
        when(
          mockAudioRecorder.start(any, path: anyNamed('path')),
        ).thenThrow(exception);

        // Act & Assert
        try {
          await dataSource.startRecording();
          fail('Expected AudioRecordingException was not thrown.');
        } on AudioRecordingException {
          // Expected
        } catch (e) {
          fail('Caught unexpected exception type: $e');
        }
        expect(
          dataSource.currentRecordingPath,
          isNull,
        ); // Check internal state reset
        // Verify start was called, even though it threw
        verify(mockAudioRecorder.start(any, path: anyNamed('path')));
      },
    );

    test(
      'should throw AudioRecordingException if directory creation fails',
      () async {
        // Arrange
        final exception = FileSystemException('Cannot create');
        // Permission granted in setUp
        // Path provider setup in setUp
        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => false);
        when(
          mockFileSystem.createDirectory(tFakeDocPath, recursive: true),
        ).thenThrow(exception);

        // Act & Assert
        // The exception gets wrapped in AudioRecordingException by startRecording
        try {
          await dataSource.startRecording();
          fail('Expected AudioRecordingException was not thrown.');
        } on AudioRecordingException {
          // Expected
        } catch (e) {
          fail('Caught unexpected exception type: $e');
        }
        expect(
          dataSource.currentRecordingPath,
          isNull,
        ); // Check internal state reset
        // Verify createDirectory was called
        verify(mockFileSystem.createDirectory(tFakeDocPath, recursive: true));
        verifyNever(mockAudioRecorder.start(any, path: anyNamed('path')));
      },
    );
  });

  group('stopRecording', () {
    const tRecordingPath = '$tFakeDocPath/recording_123.m4a';

    setUp(() {
      // Set internal state to simulate an active recording for stop/pause/resume
      dataSource.testingSetCurrentRecordingPath = tRecordingPath;
    });

    test(
      'should throw NoActiveRecordingException if currentRecordingPath is null',
      () async {
        // Arrange
        dataSource.testingSetCurrentRecordingPath = null; // Override setUp
        // Act & Assert
        expect(
          () => dataSource.stopRecording(),
          throwsA(isA<NoActiveRecordingException>()),
        );
        verifyNever(mockAudioRecorder.stop());
      },
    );

    test(
      'should call recorder.stop, check file existence and return path on success',
      () async {
        // Arrange
        when(mockAudioRecorder.stop()).thenAnswer((_) async => Future.value());
        when(
          mockFileSystem.fileExists(tRecordingPath),
        ).thenAnswer((_) async => true);
        // Act
        final resultPath = await dataSource.stopRecording();
        // Assert
        expect(resultPath, tRecordingPath);
        expect(
          dataSource.currentRecordingPath,
          isNull,
        ); // Check internal state reset
        verify(mockAudioRecorder.stop());
        verify(mockFileSystem.fileExists(tRecordingPath));
      },
    );

    test(
      'should throw RecordingFileNotFoundException if file does not exist after stop',
      () async {
        // Arrange
        when(mockAudioRecorder.stop()).thenAnswer((_) async => Future.value());
        when(
          mockFileSystem.fileExists(tRecordingPath),
        ).thenAnswer((_) async => false); // File missing
        // Act & Assert
        try {
          await dataSource.stopRecording();
          fail('Expected RecordingFileNotFoundException was not thrown.');
        } on RecordingFileNotFoundException {
          // Expected
        } catch (e) {
          fail('Caught unexpected exception type: $e');
        }
        // Verify internal state is reset AFTER the exception is caught
        expect(dataSource.currentRecordingPath, isNull);
        verify(mockAudioRecorder.stop());
        verify(mockFileSystem.fileExists(tRecordingPath));
      },
    );

    test(
      'should throw AudioRecordingException if recorder.stop throws',
      () async {
        // Arrange
        final exception = Exception('Stop failed');
        when(mockAudioRecorder.stop()).thenThrow(exception);
        // Act & Assert
        try {
          await dataSource.stopRecording();
          fail('Expected AudioRecordingException was not thrown.');
        } on AudioRecordingException {
          // Expected
        } catch (e) {
          fail('Caught unexpected exception type: $e');
        }
        // Verify internal state is reset AFTER the exception is caught
        expect(dataSource.currentRecordingPath, isNull);
        verify(mockAudioRecorder.stop());
        verifyNever(mockFileSystem.fileExists(any));
      },
    );

    test(
      'should throw AudioRecordingException wrapping FileSystemException if fileExists throws',
      () async {
        // Arrange
        final exception = FileSystemException('Cannot check');
        when(mockAudioRecorder.stop()).thenAnswer((_) async => Future.value());
        when(mockFileSystem.fileExists(tRecordingPath)).thenThrow(exception);

        // Act & Assert
        // The specific RecordingFileNotFoundException is thrown if fileExists returns false,
        // other exceptions from fileExists are wrapped.
        try {
          await dataSource.stopRecording();
          fail('Expected AudioRecordingException was not thrown.');
        } on AudioRecordingException {
          // Expected
        } catch (e) {
          fail('Caught unexpected exception type: $e');
        }
        // Verify internal state is reset AFTER the exception is caught
        expect(dataSource.currentRecordingPath, isNull);
        verify(mockAudioRecorder.stop());
        verify(mockFileSystem.fileExists(tRecordingPath));
      },
    );
  });

  group('pauseRecording', () {
    const tRecordingPath = '$tFakeDocPath/recording_123.m4a';

    setUp(() {
      // Set internal state to simulate an active recording
      dataSource.testingSetCurrentRecordingPath = tRecordingPath;
    });

    test(
      'should throw NoActiveRecordingException if currentRecordingPath is null',
      () async {
        // Arrange
        dataSource.testingSetCurrentRecordingPath = null; // Override setUp
        // Act & Assert
        expect(
          () => dataSource.pauseRecording(),
          throwsA(isA<NoActiveRecordingException>()),
        );
        verifyNever(mockAudioRecorder.pause());
      },
    );

    test('should call recorder.pause on success', () async {
      // Arrange
      when(mockAudioRecorder.pause()).thenAnswer((_) async => Future.value());
      // Act
      await dataSource.pauseRecording();
      // Assert
      expect(dataSource.currentRecordingPath, tRecordingPath); // Path unchanged
      verify(mockAudioRecorder.pause());
    });

    test(
      'should throw AudioRecordingException if recorder.pause throws',
      () async {
        // Arrange
        final exception = Exception('Pause failed');
        when(mockAudioRecorder.pause()).thenThrow(exception);
        // Act & Assert
        expect(
          () => dataSource.pauseRecording(),
          throwsA(isA<AudioRecordingException>()),
        );
        expect(
          dataSource.currentRecordingPath,
          tRecordingPath,
        ); // Path unchanged
        verify(mockAudioRecorder.pause());
      },
    );
  });

  group('resumeRecording', () {
    const tRecordingPath = '$tFakeDocPath/recording_123.m4a';

    setUp(() {
      // Set internal state to simulate an active recording
      dataSource.testingSetCurrentRecordingPath = tRecordingPath;
    });

    test(
      'should throw NoActiveRecordingException if currentRecordingPath is null',
      () async {
        // Arrange
        dataSource.testingSetCurrentRecordingPath = null; // Override setUp
        // Act & Assert
        expect(
          () => dataSource.resumeRecording(),
          throwsA(isA<NoActiveRecordingException>()),
        );
        verifyNever(mockAudioRecorder.resume());
      },
    );

    test('should call recorder.resume on success', () async {
      // Arrange
      when(mockAudioRecorder.resume()).thenAnswer((_) async => Future.value());
      // Act
      await dataSource.resumeRecording();
      // Assert
      expect(dataSource.currentRecordingPath, tRecordingPath); // Path unchanged
      verify(mockAudioRecorder.resume());
    });

    test(
      'should throw AudioRecordingException if recorder.resume throws',
      () async {
        // Arrange
        final exception = Exception('Resume failed');
        when(mockAudioRecorder.resume()).thenThrow(exception);
        // Act & Assert
        expect(
          () => dataSource.resumeRecording(),
          throwsA(isA<AudioRecordingException>()),
        );
        expect(
          dataSource.currentRecordingPath,
          tRecordingPath,
        ); // Path unchanged
        verify(mockAudioRecorder.resume());
      },
    );
  });
}
