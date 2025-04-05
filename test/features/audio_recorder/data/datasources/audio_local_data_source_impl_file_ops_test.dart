import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart'; // Needed for DataSource constructor

// Import interfaces and exceptions
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_getter.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';

// Import generated mocks
import 'audio_local_data_source_impl_file_ops_test.mocks.dart';

// Generate mocks ONLY for what's needed in these tests + DataSource dependencies
@GenerateNiceMocks([
  MockSpec<FileSystem>(),
  MockSpec<PathProvider>(),
  MockSpec<AudioDurationGetter>(),
  MockSpec<Directory>(), // Mock Directory for pathProvider return
  MockSpec<FileStat>(),
  MockSpec<FileSystemEntity>(),
  // Add mocks for unused dependencies required by constructor
  MockSpec<AudioRecorder>(),
  MockSpec<PermissionHandler>(), // Keep mock spec
  MockSpec<AudioConcatenationService>(), // Add mock spec for the new service
])
void main() {
  late AudioLocalDataSourceImpl dataSource;
  late MockFileSystem mockFileSystem;
  late MockPathProvider mockPathProvider;
  late MockAudioDurationGetter mockAudioDurationGetter;
  late MockDirectory mockDirectory;
  // Declare unused mocks
  late MockAudioRecorder mockAudioRecorder;
  late MockPermissionHandler mockPermissionHandler; // Keep mock declaration
  late MockAudioConcatenationService
  mockAudioConcatenationService; // Declare mock

  const tFakeDocPath = '/fake/doc/path';

  setUpAll(() {
    provideDummy<FileSystemEntityType>(FileSystemEntityType.file);
  });

  setUp(() {
    mockFileSystem = MockFileSystem();
    mockPathProvider = MockPathProvider();
    mockAudioDurationGetter = MockAudioDurationGetter();
    mockDirectory = MockDirectory();
    // Instantiate unused mocks
    mockAudioRecorder = MockAudioRecorder();
    mockPermissionHandler = MockPermissionHandler(); // Keep instantiation
    mockAudioConcatenationService =
        MockAudioConcatenationService(); // Instantiate mock

    dataSource = AudioLocalDataSourceImpl(
      recorder: mockAudioRecorder, // Provide unused mock
      fileSystem: mockFileSystem, // Provide used mock
      pathProvider: mockPathProvider, // Provide used mock
      permissionHandler: mockPermissionHandler, // Keep passing mock
      audioDurationGetter: mockAudioDurationGetter, // Provide used mock
      audioConcatenationService: mockAudioConcatenationService, // Provide mock
    );

    // Common setup for path provider
    when(mockDirectory.path).thenReturn(tFakeDocPath);
    when(
      mockPathProvider.getApplicationDocumentsDirectory(),
    ).thenAnswer((_) async => mockDirectory);
  });

  group('deleteRecording', () {
    const tFilePath = '$tFakeDocPath/test.m4a';

    test('should call fileSystem.deleteFile when file exists', () async {
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
      'should throw RecordingFileNotFoundException when file does not exist',
      () async {
        // Arrange
        when(
          mockFileSystem.fileExists(tFilePath),
        ).thenAnswer((_) async => false); // File doesn't exist
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
      'should throw AudioFileSystemException when fileExists throws',
      () async {
        // Arrange
        final exception = FileSystemException('Cannot check');
        when(mockFileSystem.fileExists(tFilePath)).thenThrow(exception);
        // Act & Assert
        expect(
          () => dataSource.deleteRecording(tFilePath),
          throwsA(isA<AudioFileSystemException>()),
        );
        verify(mockFileSystem.fileExists(tFilePath));
        verifyNever(mockFileSystem.deleteFile(any));
      },
    );

    test(
      'should throw AudioFileSystemException when deleteFile throws',
      () async {
        // Arrange
        final exception = FileSystemException('Cannot delete');
        when(
          mockFileSystem.fileExists(tFilePath),
        ).thenAnswer((_) async => true);
        when(mockFileSystem.deleteFile(tFilePath)).thenThrow(exception);

        // Act & Assert
        expect(() async {
          try {
            await dataSource.deleteRecording(tFilePath);
          } catch (e) {
            verify(mockFileSystem.deleteFile(tFilePath));
            rethrow;
          }
        }, throwsA(isA<AudioFileSystemException>()));
        verify(mockFileSystem.fileExists(tFilePath));
      },
    );
  });

  group('getAudioDuration', () {
    const tFilePath = '$tFakeDocPath/test.m4a';
    const tDuration = Duration(seconds: 30);

    test(
      'should return duration from audioDurationGetter on success',
      () async {
        // Arrange
        when(
          mockAudioDurationGetter.getDuration(tFilePath),
        ).thenAnswer((_) async => tDuration);
        // Act
        final result = await dataSource.getAudioDuration(tFilePath);
        // Assert
        expect(result, tDuration);
        verify(mockAudioDurationGetter.getDuration(tFilePath));
      },
    );

    test('should rethrow RecordingFileNotFoundException from getter', () async {
      // Arrange
      final exception = RecordingFileNotFoundException('Not found');
      when(mockAudioDurationGetter.getDuration(tFilePath)).thenThrow(exception);
      // Act & Assert
      expect(
        () => dataSource.getAudioDuration(tFilePath),
        throwsA(isA<RecordingFileNotFoundException>()),
      );
      verify(mockAudioDurationGetter.getDuration(tFilePath));
    });

    test('should rethrow AudioPlayerException from getter', () async {
      // Arrange
      final exception = AudioPlayerException('Player error');
      when(mockAudioDurationGetter.getDuration(tFilePath)).thenThrow(exception);
      // Act & Assert
      expect(
        () => dataSource.getAudioDuration(tFilePath),
        throwsA(isA<AudioPlayerException>()),
      );
      verify(mockAudioDurationGetter.getDuration(tFilePath));
    });

    test(
      'should wrap unexpected exceptions from getter in AudioPlayerException',
      () async {
        // Arrange
        final exception = Exception('Unexpected');
        when(
          mockAudioDurationGetter.getDuration(tFilePath),
        ).thenThrow(exception);
        // Act & Assert
        expect(
          () => dataSource.getAudioDuration(tFilePath),
          throwsA(isA<AudioPlayerException>()),
        );
        verify(mockAudioDurationGetter.getDuration(tFilePath));
      },
    );
  });

  group('listRecordingFiles', () {
    final tFilePath1 = '$tFakeDocPath/rec1.m4a';
    final tFilePath2 = '$tFakeDocPath/rec2.m4a';
    final tFilePath3 = '$tFakeDocPath/other.txt';
    final tDirPath = '$tFakeDocPath/subdir';

    // Helper to create mock FileSystemEntity with stat
    MockFileSystemEntity createMockEntity(
      String path,
      FileSystemEntityType type,
    ) {
      final mockEntity = MockFileSystemEntity();
      final mockStat = MockFileStat();
      when(mockEntity.path).thenReturn(path);
      when(mockStat.type).thenReturn(type);
      when(mockFileSystem.stat(path)).thenAnswer((_) async => mockStat);
      return mockEntity;
    }

    test('should return empty list if directory does not exist', () async {
      // Arrange
      when(
        mockFileSystem.directoryExists(tFakeDocPath),
      ).thenAnswer((_) async => false);
      when(
        mockFileSystem.createDirectory(tFakeDocPath, recursive: true),
      ).thenAnswer((_) async => Future.value()); // Assume creation succeeds
      // Act
      final result = await dataSource.listRecordingFiles();
      // Assert
      expect(result, isEmpty);
      verify(mockFileSystem.directoryExists(tFakeDocPath));
      verify(mockFileSystem.createDirectory(tFakeDocPath, recursive: true));
      verifyNever(mockFileSystem.listDirectory(any));
    });

    test(
      'should return list of .m4a file paths, filtering others and directories',
      () async {
        // Arrange
        final mockEntity1 = createMockEntity(
          tFilePath1,
          FileSystemEntityType.file,
        );
        final mockEntity2 = createMockEntity(
          tFilePath2,
          FileSystemEntityType.file,
        );
        final mockEntity3 = createMockEntity(
          tFilePath3,
          FileSystemEntityType.file,
        ); // other.txt
        final mockEntity4 = createMockEntity(
          tDirPath,
          FileSystemEntityType.directory,
        );

        final entities = [mockEntity1, mockEntity2, mockEntity3, mockEntity4];
        final stream = Stream.fromIterable(entities);

        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => true);
        when(
          mockFileSystem.listDirectory(tFakeDocPath),
        ).thenAnswer((_) => stream);

        // Add specific stat mocks needed due to refactor
        final mockStatFile = MockFileStat();
        when(mockStatFile.type).thenReturn(FileSystemEntityType.file);
        when(
          mockFileSystem.stat(tFilePath1),
        ).thenAnswer((_) async => mockStatFile);
        when(
          mockFileSystem.stat(tFilePath2),
        ).thenAnswer((_) async => mockStatFile);
        // Stat for other.txt is needed even if filtered later by path
        when(
          mockFileSystem.stat(tFilePath3),
        ).thenAnswer((_) async => mockStatFile);
        // Stat for directory
        final mockStatDir = MockFileStat();
        when(mockStatDir.type).thenReturn(FileSystemEntityType.directory);
        when(
          mockFileSystem.stat(tDirPath),
        ).thenAnswer((_) async => mockStatDir);

        // Act
        final result = await dataSource.listRecordingFiles();

        // Assert
        expect(result, containsAll([tFilePath1, tFilePath2]));
        expect(result, isNot(contains(tFilePath3)));
        expect(result, isNot(contains(tDirPath)));
        expect(result.length, 2);
        verify(mockFileSystem.directoryExists(tFakeDocPath));
        verify(mockFileSystem.listDirectory(tFakeDocPath));
        verify(mockFileSystem.stat(tFilePath1));
        verify(mockFileSystem.stat(tFilePath2));
        // Stat should NOT be called for .txt file because of .m4a filter
        verifyNever(mockFileSystem.stat(tFilePath3));
        // Stat shouldn't be called for the directory if path doesn't end with .m4a
        verifyNever(mockFileSystem.stat(tDirPath));
      },
    );

    test('should handle empty directory correctly', () async {
      // Arrange
      when(
        mockFileSystem.directoryExists(tFakeDocPath),
      ).thenAnswer((_) async => true);
      when(
        mockFileSystem.listDirectory(tFakeDocPath),
      ).thenAnswer((_) => Stream.fromIterable([])); // Empty stream

      // Act
      final result = await dataSource.listRecordingFiles();

      // Assert
      expect(result, isEmpty);
      verify(mockFileSystem.directoryExists(tFakeDocPath));
      verify(mockFileSystem.listDirectory(tFakeDocPath));
    });

    test('should ignore files where stat fails', () async {
      // Arrange
      final tFailPath = '$tFakeDocPath/rec2_stat_fails.m4a';
      final mockEntity1 = createMockEntity(
        tFilePath1,
        FileSystemEntityType.file,
      );
      final mockEntity2 = MockFileSystemEntity(); // Entity for the failing stat
      when(mockEntity2.path).thenReturn(tFailPath);

      final entities = [mockEntity1, mockEntity2];
      final stream = Stream.fromIterable(entities);

      when(
        mockFileSystem.directoryExists(tFakeDocPath),
      ).thenAnswer((_) async => true);
      when(
        mockFileSystem.listDirectory(tFakeDocPath),
      ).thenAnswer((_) => stream);

      // Mock stat for the first file (succeeds)
      final mockStatGood = MockFileStat();
      when(mockStatGood.type).thenReturn(FileSystemEntityType.file);
      when(
        mockFileSystem.stat(tFilePath1),
      ).thenAnswer((_) async => mockStatGood);

      // Mock stat for the second file (throws)
      final statException = FileSystemException('Cannot stat');
      when(mockFileSystem.stat(tFailPath)).thenThrow(statException);

      // Act
      final result = await dataSource.listRecordingFiles();

      // Assert
      expect(result, contains(tFilePath1));
      expect(result, isNot(contains(tFailPath)));
      expect(result.length, 1);
      verify(mockFileSystem.directoryExists(tFakeDocPath));
      verify(mockFileSystem.listDirectory(tFakeDocPath));
      verify(mockFileSystem.stat(tFilePath1));
      verify(mockFileSystem.stat(tFailPath));
    });

    test(
      'should throw AudioFileSystemException if directoryExists throws',
      () async {
        // Arrange
        final exception = FileSystemException('Cannot check existence');
        when(mockFileSystem.directoryExists(tFakeDocPath)).thenThrow(exception);

        // Use manual try/catch
        try {
          await dataSource.listRecordingFiles();
          fail('Expected AudioFileSystemException was not thrown.');
        } on AudioFileSystemException {
          // Expected
        } catch (e) {
          fail('Caught unexpected exception type: $e');
        }

        // Verify directoryExists was called (even though it threw)
        verify(mockFileSystem.directoryExists(tFakeDocPath));
        verifyNever(
          mockFileSystem.createDirectory(any, recursive: anyNamed('recursive')),
        );
        verifyNever(mockFileSystem.listDirectory(any));
      },
    );

    test(
      'should throw AudioFileSystemException if listDirectory throws',
      () async {
        // Arrange
        final exception = FileSystemException('Cannot list');
        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => true); // Directory exists
        when(mockFileSystem.listDirectory(tFakeDocPath)).thenThrow(exception);

        // Use manual try/catch
        try {
          await dataSource.listRecordingFiles();
          fail('Expected AudioFileSystemException was not thrown.');
        } on AudioFileSystemException {
          // Expected
        } catch (e) {
          fail('Caught unexpected exception type: $e');
        }

        // Verify directoryExists was called and returned true
        verify(mockFileSystem.directoryExists(tFakeDocPath));
        // Verify listDirectory was called (even though it threw)
        verify(mockFileSystem.listDirectory(tFakeDocPath));
      },
    );
  });
}
