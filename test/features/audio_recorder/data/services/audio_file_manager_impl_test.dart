// ignore_for_file: unused_import

import 'dart:io';

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_retriever.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/utils/logger.dart';

import 'audio_file_manager_impl_test.mocks.dart';

// Setup a null logger for tests to avoid output
// final logger = Logger(level: Level.off);
// Using centralized logger with level OFF
final logger = Logger(level: Level.off);

// Helper class for fake FileStat (consider moving to a shared test utility)
class FakeFileStat implements FileStat {
  @override
  final DateTime changed;
  @override
  final DateTime modified;
  @override
  final DateTime accessed;
  @override
  final FileSystemEntityType type;
  @override
  final int mode;
  @override
  final int size;

  FakeFileStat({
    required this.modified,
    required this.type,
    DateTime? changed,
    DateTime? accessed,
    this.mode = 0,
    this.size = 0,
  }) : changed = changed ?? modified,
       accessed = accessed ?? modified;

  @override
  String modeString() => 'rw-r--r--';
}

@GenerateNiceMocks([
  MockSpec<FileSystem>(),
  MockSpec<PathProvider>(),
  MockSpec<AudioDurationRetriever>(),
  MockSpec<Directory>(),
  MockSpec<FileSystemEntity>(),
  MockSpec<FileStat>(),
])
void main() {
  // No need to disable logging - our logger is already set to Level.nothing

  late AudioFileManagerImpl fileManager;
  late MockFileSystem mockFileSystem;
  late MockPathProvider mockPathProvider;
  late MockAudioDurationRetriever mockAudioDurationRetriever;
  late MockDirectory mockDirectory;

  // Helper to create mock FileSystemEntity
  MockFileSystemEntity createMockEntity(String path, {bool isFile = true}) {
    final mockEntity = MockFileSystemEntity();
    when(mockEntity.path).thenReturn(path);
    // Mock the type check used in listRecordingPaths by the implementation
    // Directly check the type in tests, don't mock isA here.
    // when(mockEntity).isA<File>().thenReturn(isFile);
    // when(mockEntity).isA<Directory>().thenReturn(!isFile);
    return mockEntity;
  }

  const tFakeDocPath = '/fake/documents';
  // final tNow = DateTime.now(); // Remove unused variable

  setUp(() {
    mockFileSystem = MockFileSystem();
    mockPathProvider = MockPathProvider();
    mockAudioDurationRetriever = MockAudioDurationRetriever();
    mockDirectory = MockDirectory();

    fileManager = AudioFileManagerImpl(
      fileSystem: mockFileSystem,
      pathProvider: mockPathProvider,
      audioDurationRetriever: mockAudioDurationRetriever,
    );

    // Common mock setup for pathProvider
    when(
      mockPathProvider.getApplicationDocumentsDirectory(),
    ).thenAnswer((_) async => mockDirectory);
    when(mockDirectory.path).thenReturn(tFakeDocPath);
  });

  group('deleteRecording', () {
    const tFilePath = '$tFakeDocPath/recording_to_delete.m4a';

    test('should call fileSystem.deleteFile when file exists', () async {
      // Arrange
      when(mockFileSystem.fileExists(any)).thenAnswer((_) async => true);
      when(
        mockFileSystem.deleteFile(any),
      ).thenAnswer((_) async {
        return;
      }); // Completes normally

      // Act
      await fileManager.deleteRecording(tFilePath);

      // Assert
      verify(mockFileSystem.fileExists(tFilePath));
      verify(mockFileSystem.deleteFile(tFilePath));
      verifyNoMoreInteractions(mockFileSystem);
    });

    test(
      'should throw RecordingFileNotFoundException when file does not exist',
      () async {
        // Enable logging only for this test if needed
        // TestLogger.enableLoggingForTag('[AUDIO]');

        // Arrange
        when(mockFileSystem.fileExists(any)).thenAnswer((_) async => false);

        // Act
        final call = fileManager.deleteRecording;

        // Assert
        expect(
          () => call(tFilePath),
          throwsA(isA<RecordingFileNotFoundException>()),
        );
        verify(mockFileSystem.fileExists(tFilePath));
        verifyNever(mockFileSystem.deleteFile(any));
        verifyNoMoreInteractions(mockFileSystem);
      },
    );

    test(
      'should throw AudioFileSystemException on other file system errors during deleteFile',
      () async {
        // Arrange
        final exception = Exception('Disk full');
        when(mockFileSystem.fileExists(any)).thenAnswer((_) async => true);
        when(mockFileSystem.deleteFile(any)).thenThrow(exception);

        // Act
        final call = fileManager.deleteRecording(tFilePath);

        // Assert
        verify(mockFileSystem.fileExists(tFilePath));
        expectLater(
          call,
          throwsA(
            isA<AudioFileSystemException>().having(
              (e) => e.originalException,
              'originalException',
              exception,
            ),
          ),
        );
        await untilCalled(mockFileSystem.deleteFile(tFilePath));
        verify(mockFileSystem.deleteFile(tFilePath));
        verifyNoMoreInteractions(mockFileSystem);
      },
    );

    test(
      'should throw AudioFileSystemException on other file system errors during fileExists',
      () async {
        // Arrange
        final exception = Exception('Permission denied');
        when(mockFileSystem.fileExists(any)).thenThrow(exception);

        // Act
        final call = fileManager.deleteRecording;

        // Assert
        expect(
          () => call(tFilePath),
          throwsA(
            isA<AudioFileSystemException>().having(
              (e) => e.originalException,
              'originalException',
              exception,
            ),
          ),
        );
        verify(mockFileSystem.fileExists(tFilePath));
        verifyNever(mockFileSystem.deleteFile(any));
        verifyNoMoreInteractions(mockFileSystem);
      },
    );
  });

  group('listRecordingPaths', () {
    setUp(() {
      // Common setup: Directory exists for list tests
      when(
        mockFileSystem.directoryExists(tFakeDocPath),
      ).thenAnswer((_) async => true);
    });

    test(
      'should return empty list and create directory if it does not exist',
      () async {
        // Arrange
        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => false);
        when(
          mockFileSystem.createDirectory(tFakeDocPath, recursive: true),
        ).thenAnswer((_) async => mockDirectory);

        // Act
        final result = await fileManager.listRecordingPaths();

        // Assert
        expect(result, isEmpty);
        verify(mockPathProvider.getApplicationDocumentsDirectory());
        verify(mockFileSystem.directoryExists(tFakeDocPath));
        verify(mockFileSystem.createDirectory(tFakeDocPath, recursive: true));
        verifyNever(mockFileSystem.listDirectory(any));
      },
    );

    test(
      'should return empty list if directory contains no .m4a files',
      () async {
        // Arrange
        final entities = [
          createMockEntity('$tFakeDocPath/notes.txt'),
          createMockEntity('$tFakeDocPath/image.jpg'),
        ];
        when(
          mockFileSystem.listDirectory(tFakeDocPath),
        ).thenAnswer((_) => Stream.fromIterable(entities));

        // ADDED: Mock stat call for non-.m4a files to prevent FakeUsedError
        final fakeStat = FakeFileStat(
          type: FileSystemEntityType.file,
          modified: DateTime.now(),
        );
        when(mockFileSystem.stat(any)).thenAnswer((_) async => fakeStat);

        // Act
        final result = await fileManager.listRecordingPaths();

        // Assert
        expect(result, isEmpty);
        verify(mockFileSystem.listDirectory(tFakeDocPath));
        // Verify stat was called for each non-m4a file
        verify(mockFileSystem.stat('$tFakeDocPath/notes.txt'));
        verify(mockFileSystem.stat('$tFakeDocPath/image.jpg'));
      },
    );

    test('should return list of .m4a file paths only', () async {
      // Arrange
      const pathM4a = '$tFakeDocPath/rec.m4a';
      const pathOther = '$tFakeDocPath/config.txt';
      final entityM4a = createMockEntity(pathM4a);
      final entityOther = createMockEntity(pathOther);

      when(
        mockFileSystem.listDirectory(tFakeDocPath),
      ).thenAnswer((_) => Stream.fromIterable([entityM4a, entityOther]));

      // Mock stat calls for each entity
      final tModifiedTime = DateTime.now();
      final statM4a = FakeFileStat(
        type: FileSystemEntityType.file,
        modified: tModifiedTime,
      );
      final statOther = FakeFileStat(
        type: FileSystemEntityType.file,
        modified: tModifiedTime,
      );
      when(mockFileSystem.stat(pathM4a)).thenAnswer((_) async => statM4a);
      when(mockFileSystem.stat(pathOther)).thenAnswer((_) async => statOther);

      // Act
      final result = await fileManager.listRecordingPaths();

      // Assert
      expect(result.length, 1);
      expect(result[0], pathM4a);
      verify(mockFileSystem.listDirectory(tFakeDocPath));
    });

    test('should ignore directories, even if named .m4a', () async {
      // Arrange
      const pathDirM4a = '$tFakeDocPath/directory.m4a';
      final entityDirM4a = createMockEntity(pathDirM4a, isFile: false);

      when(
        mockFileSystem.listDirectory(tFakeDocPath),
      ).thenAnswer((_) => Stream.fromIterable([entityDirM4a]));

      // Mock stat call for the directory entity
      final tModifiedTime = DateTime.now();
      final statDirM4a = FakeFileStat(
        type: FileSystemEntityType.directory,
        modified: tModifiedTime,
      );
      when(mockFileSystem.stat(pathDirM4a)).thenAnswer((_) async => statDirM4a);

      // Act
      final result = await fileManager.listRecordingPaths();

      // Assert
      expect(result, isEmpty);
      verify(mockFileSystem.listDirectory(tFakeDocPath));
    });

    test(
      'should throw AudioFileSystemException if listing directory fails',
      () async {
        // Arrange
        final exception = Exception('Cannot list dir');
        when(mockFileSystem.listDirectory(tFakeDocPath)).thenThrow(exception);

        // Act
        final call = fileManager.listRecordingPaths;

        // Assert
        expect(
          call,
          throwsA(
            isA<AudioFileSystemException>()
                .having(
                  (e) => e.message,
                  'message',
                  'Failed to list recording paths',
                )
                .having(
                  (e) => e.originalException,
                  'originalException',
                  exception,
                ),
          ),
        );
        // Verify the call that happens *before* the throwing call
        verify(mockPathProvider.getApplicationDocumentsDirectory());
      },
    );
  });
}
