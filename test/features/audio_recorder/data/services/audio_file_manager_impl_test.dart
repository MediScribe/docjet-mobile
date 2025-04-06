// ignore_for_file: unused_import

import 'dart:io';

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_getter.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_file_manager_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'audio_file_manager_impl_test.mocks.dart';

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
  MockSpec<AudioDurationGetter>(),
  MockSpec<Directory>(),
  MockSpec<FileSystemEntity>(),
  MockSpec<FileStat>(),
])
void main() {
  late AudioFileManagerImpl fileManager;
  late MockFileSystem mockFileSystem;
  late MockPathProvider mockPathProvider;
  late MockAudioDurationGetter mockAudioDurationGetter;
  late MockDirectory mockDirectory;

  const tFakeDocPath = '/fake/documents';
  final tNow = DateTime.now();

  setUp(() {
    mockFileSystem = MockFileSystem();
    mockPathProvider = MockPathProvider();
    mockAudioDurationGetter = MockAudioDurationGetter();
    mockDirectory = MockDirectory();

    fileManager = AudioFileManagerImpl(
      fileSystem: mockFileSystem,
      pathProvider: mockPathProvider,
      audioDurationGetter: mockAudioDurationGetter,
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
      ).thenAnswer((_) async {}); // Completes normally

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

  group('listRecordingDetails', () {
    // Helper to create mock FileSystemEntity
    MockFileSystemEntity createMockEntity(String path) {
      final entity = MockFileSystemEntity();
      when(entity.path).thenReturn(path);
      return entity;
    }

    // Helper to create mock FileStat

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
        final result = await fileManager.listRecordingDetails();

        // Assert
        expect(result, isEmpty);
        verify(mockPathProvider.getApplicationDocumentsDirectory());
        verify(mockFileSystem.directoryExists(tFakeDocPath));
        verify(mockFileSystem.createDirectory(tFakeDocPath, recursive: true));
        verifyNever(mockFileSystem.listDirectory(any));
        verifyNever(mockFileSystem.stat(any));
        verifyNever(mockAudioDurationGetter.getDuration(any));
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

        // Act
        final result = await fileManager.listRecordingDetails();

        // Assert
        expect(result, isEmpty);
        verify(mockFileSystem.listDirectory(tFakeDocPath));
        verifyNever(mockFileSystem.stat(any));
        verifyNever(mockAudioDurationGetter.getDuration(any));
      },
    );

    test(
      'should return list of AudioRecords sorted descending by date for .m4a files',
      () async {
        // Arrange
        const pathOlder = '$tFakeDocPath/rec_older.m4a';
        const pathNewer = '$tFakeDocPath/rec_newer.m4a';
        const pathOther = '$tFakeDocPath/config.txt';

        final entityOlder = createMockEntity(pathOlder);
        final entityNewer = createMockEntity(pathNewer);
        final entityOther = createMockEntity(pathOther);

        final statOlder = FakeFileStat(
          modified: tNow.subtract(const Duration(hours: 1)),
          type: FileSystemEntityType.file,
        );
        final statNewer = FakeFileStat(
          modified: tNow,
          type: FileSystemEntityType.file,
        );

        const durationOlder = Duration(seconds: 15);
        const durationNewer = Duration(seconds: 30);

        when(mockFileSystem.listDirectory(tFakeDocPath)).thenAnswer(
          (_) => Stream.fromIterable([entityOlder, entityNewer, entityOther]),
        );

        when(mockFileSystem.stat(pathOlder)).thenAnswer((_) async => statOlder);
        when(mockFileSystem.stat(pathNewer)).thenAnswer((_) async => statNewer);

        when(
          mockAudioDurationGetter.getDuration(pathOlder),
        ).thenAnswer((_) async => durationOlder);
        when(
          mockAudioDurationGetter.getDuration(pathNewer),
        ).thenAnswer((_) async => durationNewer);

        // Act
        final result = await fileManager.listRecordingDetails();

        // Assert
        expect(result.length, 2);
        expect(result[0].filePath, pathNewer); // Newer first
        expect(result[0].duration, durationNewer);
        expect(result[0].createdAt, statNewer.modified);
        expect(result[1].filePath, pathOlder);
        expect(result[1].duration, durationOlder);
        expect(result[1].createdAt, statOlder.modified);

        verify(mockFileSystem.listDirectory(tFakeDocPath));
        verify(mockFileSystem.stat(pathOlder));
        verify(mockFileSystem.stat(pathNewer));
        verifyNever(mockFileSystem.stat(pathOther));
        verify(mockAudioDurationGetter.getDuration(pathOlder));
        verify(mockAudioDurationGetter.getDuration(pathNewer));
        verifyNever(mockAudioDurationGetter.getDuration(pathOther));
      },
    );

    test(
      'should ignore files that are not FileSystemEntityType.file even if they end in .m4a',
      () async {
        // Arrange
        const pathDirM4a = '$tFakeDocPath/directory.m4a';
        final entityDirM4a = createMockEntity(pathDirM4a);
        final statDirM4a = FakeFileStat(
          modified: tNow,
          type: FileSystemEntityType.directory, // It's a directory!
        );

        when(
          mockFileSystem.listDirectory(tFakeDocPath),
        ).thenAnswer((_) => Stream.fromIterable([entityDirM4a]));
        when(
          mockFileSystem.stat(pathDirM4a),
        ).thenAnswer((_) async => statDirM4a);

        // Act
        final result = await fileManager.listRecordingDetails();

        // Assert
        expect(result, isEmpty);
        verify(mockFileSystem.stat(pathDirM4a));
        verifyNever(
          mockAudioDurationGetter.getDuration(pathDirM4a),
        ); // Duration not called for non-files
      },
    );

    test(
      'should return partial list and log error when stat fails for a file',
      () async {
        // Arrange
        const pathGood = '$tFakeDocPath/good.m4a';
        const pathBadStat = '$tFakeDocPath/bad_stat.m4a';
        final entityGood = createMockEntity(pathGood);
        final entityBadStat = createMockEntity(pathBadStat);
        final statGood = FakeFileStat(
          modified: tNow,
          type: FileSystemEntityType.file,
        );
        const durationGood = Duration(seconds: 5);
        final statException = Exception('Stat permission error');

        when(
          mockFileSystem.listDirectory(tFakeDocPath),
        ).thenAnswer((_) => Stream.fromIterable([entityGood, entityBadStat]));
        when(mockFileSystem.stat(pathGood)).thenAnswer((_) async => statGood);
        when(mockFileSystem.stat(pathBadStat)).thenThrow(statException);
        when(
          mockAudioDurationGetter.getDuration(pathGood),
        ).thenAnswer((_) async => durationGood);

        // Act
        final result = await fileManager.listRecordingDetails();

        // Assert
        expect(result.length, 1);
        expect(result[0].filePath, pathGood);
        verify(mockFileSystem.stat(pathGood));
        verify(mockFileSystem.stat(pathBadStat)); // Stat attempted
        verify(mockAudioDurationGetter.getDuration(pathGood));
        verifyNever(
          mockAudioDurationGetter.getDuration(pathBadStat),
        ); // Duration not called
        // TODO: Verify debugPrint was called (requires more complex setup or test framework feature)
      },
    );

    test(
      'should return partial list and log error when getDuration fails for a file',
      () async {
        // Arrange
        const pathGood = '$tFakeDocPath/good.m4a';
        const pathBadDuration = '$tFakeDocPath/bad_duration.m4a';
        final entityGood = createMockEntity(pathGood);
        final entityBadDuration = createMockEntity(pathBadDuration);
        final statGood = FakeFileStat(
          modified: tNow,
          type: FileSystemEntityType.file,
        );
        final statBadDuration = FakeFileStat(
          modified: tNow.subtract(const Duration(minutes: 1)),
          type: FileSystemEntityType.file,
        );
        const durationGood = Duration(seconds: 5);
        final durationException = Exception('Invalid audio file');

        when(mockFileSystem.listDirectory(tFakeDocPath)).thenAnswer(
          (_) => Stream.fromIterable([entityGood, entityBadDuration]),
        );
        when(mockFileSystem.stat(pathGood)).thenAnswer((_) async => statGood);
        when(
          mockFileSystem.stat(pathBadDuration),
        ).thenAnswer((_) async => statBadDuration);
        when(
          mockAudioDurationGetter.getDuration(pathGood),
        ).thenAnswer((_) async => durationGood);
        when(
          mockAudioDurationGetter.getDuration(pathBadDuration),
        ).thenThrow(durationException);

        // Act
        final result = await fileManager.listRecordingDetails();

        // Assert
        expect(result.length, 1);
        expect(result[0].filePath, pathGood);
        verify(mockFileSystem.stat(pathGood));
        verify(mockFileSystem.stat(pathBadDuration));
        verify(mockAudioDurationGetter.getDuration(pathGood));
        verify(
          mockAudioDurationGetter.getDuration(pathBadDuration),
        ); // Duration attempted
        // TODO: Verify debugPrint was called
      },
    );

    test(
      'should throw AudioFileSystemException if listing directory fails',
      () async {
        // Arrange
        final exception = Exception('Cannot list dir');
        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => true);
        when(mockFileSystem.listDirectory(tFakeDocPath)).thenThrow(exception);

        // Act
        final call = fileManager.listRecordingDetails;

        // Assert
        expect(
          call,
          throwsA(
            isA<AudioFileSystemException>().having(
              (e) => e.originalException,
              'originalException',
              exception,
            ),
          ),
        );
      },
    );

    test(
      'should throw AudioFileSystemException if getting documents directory fails',
      () async {
        // Arrange
        final exception = Exception('Cannot get documents dir');
        when(
          mockPathProvider.getApplicationDocumentsDirectory(),
        ).thenThrow(exception);

        // Act
        final call = fileManager.listRecordingDetails;

        // Assert
        expect(
          call,
          throwsA(
            isA<AudioFileSystemException>().having(
              (e) => e.originalException,
              'originalException',
              exception,
            ),
          ),
        );
        verify(mockPathProvider.getApplicationDocumentsDirectory());
        verifyNever(mockFileSystem.directoryExists(any));
      },
    );
  });
}
