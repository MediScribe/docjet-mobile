import 'dart:async';
import 'dart:io'; // Keep for FileSystemEntityType, FileSystemException

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_getter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:permission_handler/permission_handler.dart'
    show Permission, PermissionStatus; // Use specific imports if needed
import 'package:record/record.dart'; // For mocking AudioRecorder

// Import generated mocks (will be created after running build_runner)
import 'audio_local_data_source_impl_test.mocks.dart';

// Generate mocks for ALL dependencies of AudioLocalDataSourceImpl
@GenerateNiceMocks([
  MockSpec<AudioRecorder>(),
  MockSpec<FileSystem>(),
  MockSpec<PathProvider>(),
  MockSpec<PermissionHandler>(),
  MockSpec<AudioDurationGetter>(),
  MockSpec<AudioConcatenationService>(),
  // Mocks needed for dependencies' return values
  MockSpec<Directory>(),
  MockSpec<FileStat>(),
  MockSpec<FileSystemEntity>(),
])
void main() {
  late AudioLocalDataSourceImpl dataSource;
  // Declare mocks for all dependencies
  late MockAudioRecorder mockAudioRecorder;
  late MockFileSystem mockFileSystem;
  late MockPathProvider mockPathProvider;
  late MockPermissionHandler mockPermissionHandler;
  late MockAudioDurationGetter mockAudioDurationGetter;
  late MockAudioConcatenationService mockAudioConcatenationService;
  // Declare mocks for dependency return values
  late MockDirectory mockDirectory;

  const tFakeDocPath = '/fake/doc/path';
  final tNow = DateTime.now();

  setUpAll(() {
    // Provide dummies if needed by mockito for verification matching
    provideDummy<FileSystemEntityType>(FileSystemEntityType.file);
    provideDummy<PermissionStatus>(PermissionStatus.granted);
    provideDummy<Map<Permission, PermissionStatus>>({});
    provideDummy<AudioRecord>(
      AudioRecord(
        filePath: '',
        duration: Duration.zero,
        createdAt: DateTime(0),
      ),
    );
  });

  setUp(() {
    // Instantiate all mocks
    mockAudioRecorder = MockAudioRecorder();
    mockFileSystem = MockFileSystem();
    mockPathProvider = MockPathProvider();
    mockPermissionHandler = MockPermissionHandler();
    mockAudioDurationGetter = MockAudioDurationGetter();
    mockAudioConcatenationService = MockAudioConcatenationService();
    mockDirectory = MockDirectory();

    // Instantiate the DataSource with all mocks
    dataSource = AudioLocalDataSourceImpl(
      recorder: mockAudioRecorder,
      fileSystem: mockFileSystem,
      pathProvider: mockPathProvider,
      permissionHandler: mockPermissionHandler,
      audioDurationGetter: mockAudioDurationGetter,
      audioConcatenationService: mockAudioConcatenationService,
    );

    // Common mock setup for path provider
    when(mockDirectory.path).thenReturn(tFakeDocPath);
    when(
      mockPathProvider.getApplicationDocumentsDirectory(),
    ).thenAnswer((_) async => mockDirectory);
  });

  // --- Test groups will go here ---
  group('Permissions', () {
    // TODO: Add tests for checkPermission and requestPermission
  });

  group('Recording Lifecycle', () {
    // TODO: Add tests for startRecording, stopRecording, pauseRecording, resumeRecording
  });

  group('File Operations', () {
    // --- deleteRecording Tests ---
    group('deleteRecording', () {
      const tFilePath = '$tFakeDocPath/test_to_delete.m4a';

      test(
        'should call fileSystem.deleteFile and complete normally when file exists',
        () async {
          // Arrange
          when(
            mockFileSystem.fileExists(tFilePath),
          ).thenAnswer((_) async => true);
          when(
            mockFileSystem.deleteFile(tFilePath),
          ).thenAnswer((_) async {}); // Completes normally

          // Act
          await dataSource.deleteRecording(tFilePath);

          // Assert
          verify(mockFileSystem.fileExists(tFilePath)).called(1);
          verify(mockFileSystem.deleteFile(tFilePath)).called(1);
        },
      );

      test(
        'should throw RecordingFileNotFoundException when file does not exist',
        () async {
          // Arrange
          when(
            mockFileSystem.fileExists(tFilePath),
          ).thenAnswer((_) async => false); // File doesn't exist

          // Act
          final call = dataSource.deleteRecording(tFilePath);

          // Assert
          await expectLater(
            call,
            throwsA(isA<RecordingFileNotFoundException>()),
          );
          verify(mockFileSystem.fileExists(tFilePath)).called(1);
          verifyNever(mockFileSystem.deleteFile(any));
        },
      );

      test(
        'should throw AudioFileSystemException when deleteFile throws',
        () async {
          // Arrange
          const tException = FileSystemException('Disk full');
          when(
            mockFileSystem.fileExists(tFilePath),
          ).thenAnswer((_) async => true);
          when(mockFileSystem.deleteFile(tFilePath)).thenThrow(tException);

          // Act
          final call = dataSource.deleteRecording(tFilePath);

          // Assert
          await expectLater(call, throwsA(isA<AudioFileSystemException>()));
          verify(mockFileSystem.fileExists(tFilePath)).called(1);
          verify(mockFileSystem.deleteFile(tFilePath)).called(1);
        },
      );
    }); // End deleteRecording group

    // --- listRecordingDetails Tests ---
    group('listRecordingDetails', () {
      // Helper to create mock FileSystemEntity
      MockFileSystemEntity createMockEntity(String path) {
        final entity = MockFileSystemEntity();
        when(entity.path).thenReturn(path);
        return entity;
      }

      // Helper to create mock FileStat
      MockFileStat createMockStat(
        DateTime modified,
        FileSystemEntityType type,
      ) {
        final stat = MockFileStat();
        when(stat.modified).thenReturn(modified);
        when(stat.type).thenReturn(type);
        return stat;
      }

      setUp(() {
        // Common setup: Directory exists
        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => true);
      });

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
          final result = await dataSource.listRecordingDetails();

          // Assert
          expect(result, isEmpty);
          verify(mockFileSystem.listDirectory(tFakeDocPath)).called(1);
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

          final statOlder = createMockStat(
            tNow.subtract(const Duration(hours: 1)),
            FileSystemEntityType.file,
          );
          final statNewer = createMockStat(tNow, FileSystemEntityType.file);

          const durationOlder = Duration(seconds: 15);
          const durationNewer = Duration(seconds: 30);

          when(mockFileSystem.listDirectory(tFakeDocPath)).thenAnswer(
            (_) => Stream.fromIterable([entityOlder, entityNewer, entityOther]),
          );

          // Mock stat calls
          when(
            mockFileSystem.stat(pathOlder),
          ).thenAnswer((_) async => statOlder);
          when(
            mockFileSystem.stat(pathNewer),
          ).thenAnswer((_) async => statNewer);
          // No stat mock needed for pathOther as it's filtered out

          // Mock duration calls
          when(
            mockAudioDurationGetter.getDuration(pathOlder),
          ).thenAnswer((_) async => durationOlder);
          when(
            mockAudioDurationGetter.getDuration(pathNewer),
          ).thenAnswer((_) async => durationNewer);

          // Act
          final result = await dataSource.listRecordingDetails();

          // Assert
          expect(result.length, 2);
          // Check order: Newer first
          expect(result[0].filePath, pathNewer);
          expect(result[0].duration, durationNewer);
          expect(result[0].createdAt, statNewer.modified);
          // Check order: Older second
          expect(result[1].filePath, pathOlder);
          expect(result[1].duration, durationOlder);
          expect(result[1].createdAt, statOlder.modified);

          // Verify interactions
          verify(mockFileSystem.listDirectory(tFakeDocPath)).called(1);
          verify(mockFileSystem.stat(pathOlder)).called(1);
          verify(mockFileSystem.stat(pathNewer)).called(1);
          verifyNever(mockFileSystem.stat(pathOther)); // Should be filtered
          verify(mockAudioDurationGetter.getDuration(pathOlder)).called(1);
          verify(mockAudioDurationGetter.getDuration(pathNewer)).called(1);
        },
      );

      test(
        'should return partial list when some file stats fail, without throwing',
        () async {
          // Arrange
          const pathGood1 = '$tFakeDocPath/rec_good1.m4a';
          const pathBadStat = '$tFakeDocPath/rec_bad_stat.m4a';
          const pathGood2 = '$tFakeDocPath/rec_good2.m4a'; // Newer than good1

          final entityGood1 = createMockEntity(pathGood1);
          final entityBadStat = createMockEntity(pathBadStat);
          final entityGood2 = createMockEntity(pathGood2);

          final statGood1 = createMockStat(
            tNow.subtract(const Duration(minutes: 10)),
            FileSystemEntityType.file,
          );
          final statGood2 = createMockStat(
            tNow,
            FileSystemEntityType.file,
          ); // Newer
          const statException = FileSystemException('Cannot stat file');

          const durationGood1 = Duration(seconds: 5);
          const durationGood2 = Duration(seconds: 25);

          when(mockFileSystem.listDirectory(tFakeDocPath)).thenAnswer(
            (_) =>
                Stream.fromIterable([entityGood1, entityBadStat, entityGood2]),
          );

          // Mock stat calls
          when(
            mockFileSystem.stat(pathGood1),
          ).thenAnswer((_) async => statGood1);
          when(
            mockFileSystem.stat(pathGood2),
          ).thenAnswer((_) async => statGood2);
          when(
            mockFileSystem.stat(pathBadStat),
          ).thenThrow(statException); // Error case

          // Mock duration calls (only for successful stats)
          when(
            mockAudioDurationGetter.getDuration(pathGood1),
          ).thenAnswer((_) async => durationGood1);
          when(
            mockAudioDurationGetter.getDuration(pathGood2),
          ).thenAnswer((_) async => durationGood2);

          // Act
          final result = await dataSource.listRecordingDetails();

          // Assert
          expect(result.length, 2); // Only the two good files
          // Check order: good2 (Newer) first
          expect(result[0].filePath, pathGood2);
          expect(result[0].duration, durationGood2);
          expect(result[0].createdAt, statGood2.modified);
          // Check order: good1 second
          expect(result[1].filePath, pathGood1);
          expect(result[1].duration, durationGood1);
          expect(result[1].createdAt, statGood1.modified);

          // Verify interactions
          verify(mockFileSystem.listDirectory(tFakeDocPath)).called(1);
          // Stat should be attempted for all .m4a files
          verify(mockFileSystem.stat(pathGood1)).called(1);
          verify(mockFileSystem.stat(pathGood2)).called(1);
          verify(mockFileSystem.stat(pathBadStat)).called(1);
          // Duration should only be called for files where stat succeeded
          verify(mockAudioDurationGetter.getDuration(pathGood1)).called(1);
          verify(mockAudioDurationGetter.getDuration(pathGood2)).called(1);
          verifyNever(mockAudioDurationGetter.getDuration(pathBadStat));
          // Although we can't easily check debugPrint output without extra setup,
          // the fact that the call completed and returned partial data implies
          // the error was caught and handled internally.
        },
      );

      test(
        'should return partial list when some getDuration calls fail, without throwing',
        () async {
          // Arrange
          const pathGood1 = '$tFakeDocPath/rec_good1.m4a';
          const pathBadDuration = '$tFakeDocPath/rec_bad_duration.m4a';
          const pathGood2 = '$tFakeDocPath/rec_good2.m4a';

          final entityGood1 = createMockEntity(pathGood1);
          final entityBadDuration = createMockEntity(pathBadDuration);
          final entityGood2 = createMockEntity(pathGood2);

          final statGood1 = createMockStat(
            tNow.subtract(const Duration(hours: 2)),
            FileSystemEntityType.file,
          );
          final statBadDuration = createMockStat(
            tNow.subtract(const Duration(hours: 1)),
            FileSystemEntityType.file,
          );
          final statGood2 = createMockStat(
            tNow,
            FileSystemEntityType.file,
          ); // Newest

          const durationGood1 = Duration(seconds: 11);
          const durationGood2 = Duration(seconds: 22);
          final durationException = Exception('Cannot parse duration');

          when(mockFileSystem.listDirectory(tFakeDocPath)).thenAnswer(
            (_) => Stream.fromIterable([
              entityGood1,
              entityBadDuration,
              entityGood2,
            ]),
          );

          // Mock stat calls (all succeed)
          when(
            mockFileSystem.stat(pathGood1),
          ).thenAnswer((_) async => statGood1);
          when(
            mockFileSystem.stat(pathBadDuration),
          ).thenAnswer((_) async => statBadDuration);
          when(
            mockFileSystem.stat(pathGood2),
          ).thenAnswer((_) async => statGood2);

          // Mock duration calls (one fails)
          when(
            mockAudioDurationGetter.getDuration(pathGood1),
          ).thenAnswer((_) async => durationGood1);
          when(
            mockAudioDurationGetter.getDuration(pathGood2),
          ).thenAnswer((_) async => durationGood2);
          when(
            mockAudioDurationGetter.getDuration(pathBadDuration),
          ).thenThrow(durationException);

          // Act
          final result = await dataSource.listRecordingDetails();

          // Assert
          expect(result.length, 2); // Only the two good files
          // Check order: good2 (Newest) first
          expect(result[0].filePath, pathGood2);
          expect(result[0].duration, durationGood2);
          expect(result[0].createdAt, statGood2.modified);
          // Check order: good1 second
          expect(result[1].filePath, pathGood1);
          expect(result[1].duration, durationGood1);
          expect(result[1].createdAt, statGood1.modified);

          // Verify interactions
          verify(mockFileSystem.listDirectory(tFakeDocPath)).called(1);
          // Stat called for all
          verify(mockFileSystem.stat(pathGood1)).called(1);
          verify(mockFileSystem.stat(pathBadDuration)).called(1);
          verify(mockFileSystem.stat(pathGood2)).called(1);
          // Duration attempted for all (since stat succeeded for all)
          verify(mockAudioDurationGetter.getDuration(pathGood1)).called(1);
          verify(
            mockAudioDurationGetter.getDuration(pathBadDuration),
          ).called(1);
          verify(mockAudioDurationGetter.getDuration(pathGood2)).called(1);
        },
      );

      test('should ignore entities ending in .m4a that are not files', () async {
        // Arrange
        const pathFile = '$tFakeDocPath/rec_real_file.m4a';
        const pathDir =
            '$tFakeDocPath/rec_fake_dir.m4a'; // Directory named like a recording

        final entityFile = createMockEntity(pathFile);
        final entityDir = createMockEntity(pathDir);

        final statFile = createMockStat(tNow, FileSystemEntityType.file);
        final statDir = createMockStat(
          tNow.subtract(const Duration(minutes: 5)),
          FileSystemEntityType.directory,
        );

        const durationFile = Duration(seconds: 45);

        when(
          mockFileSystem.listDirectory(tFakeDocPath),
        ).thenAnswer((_) => Stream.fromIterable([entityFile, entityDir]));

        // Mock stat calls
        when(mockFileSystem.stat(pathFile)).thenAnswer((_) async => statFile);
        when(mockFileSystem.stat(pathDir)).thenAnswer((_) async => statDir);

        // Mock duration call (only for the actual file)
        when(
          mockAudioDurationGetter.getDuration(pathFile),
        ).thenAnswer((_) async => durationFile);

        // Act
        final result = await dataSource.listRecordingDetails();

        // Assert
        expect(result.length, 1);
        expect(result[0].filePath, pathFile);
        expect(result[0].duration, durationFile);
        expect(result[0].createdAt, statFile.modified);

        // Verify interactions
        verify(mockFileSystem.listDirectory(tFakeDocPath)).called(1);
        // Stat called for both .m4a entities
        verify(mockFileSystem.stat(pathFile)).called(1);
        verify(mockFileSystem.stat(pathDir)).called(1);
        // Duration should only be called for the entity identified as a file
        verify(mockAudioDurationGetter.getDuration(pathFile)).called(1);
        verifyNever(mockAudioDurationGetter.getDuration(pathDir));
      });
    }); // End listRecordingDetails group

    // TODO: Add more tests for listRecordingDetails (e.g., duration error, non-file .m4a)
  });

  group('Concatenation (Dummy)', () {
    // TODO: Add tests for appendRecording (interactions with dummy service)
  });
} // End of main
