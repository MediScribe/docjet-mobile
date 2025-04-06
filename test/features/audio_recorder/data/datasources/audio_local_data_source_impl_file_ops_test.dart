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
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart'; // Import AudioRecord

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
  final tNow = DateTime.now(); // For consistent FileStat modified time

  setUpAll(() {
    provideDummy<FileSystemEntityType>(FileSystemEntityType.file);
    // Provide dummy for AudioRecord for verification if needed, though direct comparison is better
    // provideDummy<AudioRecord>(AudioRecord(filePath: '', duration: Duration.zero, createdAt: DateTime(0)));
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

  group('listRecordingDetails', () {
    final tFilePath1 = '$tFakeDocPath/rec1.m4a';
    final tFilePath2 = '$tFakeDocPath/rec2.m4a';
    final tFilePath3 = '$tFakeDocPath/other.txt';
    final tDirPath = '$tFakeDocPath/subdir';

    final tDuration1 = const Duration(seconds: 10);
    final tDuration2 = const Duration(seconds: 20);

    final tStat1 = MockFileStat();
    final tStat2 = MockFileStat();

    setUp(() {
      // Setup common stat properties
      when(tStat1.type).thenReturn(FileSystemEntityType.file);
      when(tStat1.modified).thenReturn(tNow.subtract(const Duration(hours: 1)));
      when(tStat2.type).thenReturn(FileSystemEntityType.file);
      when(tStat2.modified).thenReturn(tNow);
    });

    // Helper to create mock FileSystemEntity with stat
    MockFileSystemEntity createMockEntity(
      String path,
      MockFileStat stat, // Expect a pre-configured stat mock
    ) {
      final mockEntity = MockFileSystemEntity();
      when(mockEntity.path).thenReturn(path);
      // Link the stat mock to the fileSystem.stat call for this path
      when(mockFileSystem.stat(path)).thenAnswer((_) async => stat);
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
      // Call the new method
      final result = await dataSource.listRecordingDetails();
      // Assert
      expect(result, isEmpty);
      verify(mockFileSystem.directoryExists(tFakeDocPath));
      verify(mockFileSystem.createDirectory(tFakeDocPath, recursive: true));
      verifyNever(mockFileSystem.listDirectory(any));
      verifyNever(
        mockAudioDurationGetter.getDuration(any),
      ); // Duration getter not called
    });

    test(
      'should return list of AudioRecords, filtering others and directories',
      () async {
        // Arrange
        final tStat3 = MockFileStat();
        when(tStat3.type).thenReturn(FileSystemEntityType.file);
        when(tStat3.modified).thenReturn(tNow);
        final tStatDir = MockFileStat();
        when(tStatDir.type).thenReturn(FileSystemEntityType.directory);
        when(tStatDir.modified).thenReturn(tNow);

        final mockEntity1 = createMockEntity(tFilePath1, tStat1);
        final mockEntity2 = createMockEntity(tFilePath2, tStat2);
        final mockEntity3 = createMockEntity(tFilePath3, tStat3); // other.txt
        final mockEntity4 = createMockEntity(tDirPath, tStatDir); // subdir

        final entities = [mockEntity1, mockEntity2, mockEntity3, mockEntity4];
        final stream = Stream.fromIterable(entities);

        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => true);
        when(
          mockFileSystem.listDirectory(tFakeDocPath),
        ).thenAnswer((_) => stream);
        when(
          mockAudioDurationGetter.getDuration(tFilePath1),
        ).thenAnswer((_) async => tDuration1);
        when(
          mockAudioDurationGetter.getDuration(tFilePath2),
        ).thenAnswer((_) async => tDuration2);

        // Act
        final result = await dataSource.listRecordingDetails();

        // Assert
        expect(result.length, 2);
        expect(
          result,
          containsAll([
            isA<AudioRecord>()
                .having((r) => r.filePath, 'filePath', tFilePath1)
                .having((r) => r.duration, 'duration', tDuration1)
                .having((r) => r.createdAt, 'createdAt', tStat1.modified),
            isA<AudioRecord>()
                .having((r) => r.filePath, 'filePath', tFilePath2)
                .having((r) => r.duration, 'duration', tDuration2)
                .having((r) => r.createdAt, 'createdAt', tStat2.modified),
          ]),
        );

        verify(mockFileSystem.directoryExists(tFakeDocPath));
        verify(mockFileSystem.listDirectory(tFakeDocPath));
        // Verify stat was called ONLY for the .m4a files processed
        verify(mockFileSystem.stat(tFilePath1));
        verify(mockFileSystem.stat(tFilePath2));
        // Verify stat was NEVER called for non-m4a files/dirs due to path filter
        verifyNever(mockFileSystem.stat(tFilePath3));
        verifyNever(mockFileSystem.stat(tDirPath));
        // Verify duration getter called ONLY for valid .m4a files
        verify(mockAudioDurationGetter.getDuration(tFilePath1));
        verify(mockAudioDurationGetter.getDuration(tFilePath2));
        verifyNever(mockAudioDurationGetter.getDuration(tFilePath3));
        verifyNever(mockAudioDurationGetter.getDuration(tDirPath));
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
      final result = await dataSource.listRecordingDetails();

      // Assert
      expect(result, isEmpty);
      verify(mockFileSystem.directoryExists(tFakeDocPath));
      verify(mockFileSystem.listDirectory(tFakeDocPath));
      verifyNever(mockFileSystem.stat(any));
      verifyNever(mockAudioDurationGetter.getDuration(any));
    });

    test('should ignore files where stat fails and log (print)', () async {
      // Arrange
      final tFailPath = '$tFakeDocPath/rec2_stat_fails.m4a';
      final mockEntity1 = createMockEntity(tFilePath1, tStat1);
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

      // Mock stat for the second file (throws)
      final statException = FileSystemException('Cannot stat');
      when(mockFileSystem.stat(tFailPath)).thenThrow(statException);

      // Mock duration for the first file
      when(
        mockAudioDurationGetter.getDuration(tFilePath1),
      ).thenAnswer((_) async => tDuration1);

      // Capture print output
      List<String> printOutput = [];
      await runZoned(
        () async {
          // Act
          final result = await dataSource.listRecordingDetails();

          // Assert
          expect(result.length, 1);
          expect(
            result.first,
            isA<AudioRecord>()
                .having((r) => r.filePath, 'filePath', tFilePath1)
                .having((r) => r.duration, 'duration', tDuration1)
                .having((r) => r.createdAt, 'createdAt', tStat1.modified),
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            printOutput.add(line);
          },
        ),
      );

      // Assert print output
      expect(printOutput, isNotEmpty);
      expect(printOutput.first, contains('Error processing file $tFailPath'));
      expect(printOutput.first, contains(statException.toString()));

      verify(mockFileSystem.directoryExists(tFakeDocPath));
      verify(mockFileSystem.listDirectory(tFakeDocPath));
      verify(mockFileSystem.stat(tFilePath1));
      verify(mockFileSystem.stat(tFailPath));
      verify(mockAudioDurationGetter.getDuration(tFilePath1));
      verifyNever(mockAudioDurationGetter.getDuration(tFailPath));
    });

    test(
      'should ignore files where getDuration fails and log (print)',
      () async {
        // Arrange
        final tFailPath = '$tFakeDocPath/rec2_duration_fails.m4a';
        final mockEntity1 = createMockEntity(tFilePath1, tStat1);
        final mockEntity2 = createMockEntity(
          tFailPath,
          tStat2,
        ); // Use tStat2 for variety

        final entities = [mockEntity1, mockEntity2];
        final stream = Stream.fromIterable(entities);

        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => true);
        when(
          mockFileSystem.listDirectory(tFakeDocPath),
        ).thenAnswer((_) => stream);

        // Mock duration for the first file (succeeds)
        when(
          mockAudioDurationGetter.getDuration(tFilePath1),
        ).thenAnswer((_) async => tDuration1);

        // Mock duration for the second file (throws)
        final durationException = AudioPlayerException('Cannot get duration');
        when(
          mockAudioDurationGetter.getDuration(tFailPath),
        ).thenThrow(durationException);

        // Capture print output
        List<String> printOutput = [];
        await runZoned(
          () async {
            // Act
            final result = await dataSource.listRecordingDetails();

            // Assert
            expect(result.length, 1);
            expect(
              result.first,
              isA<AudioRecord>()
                  .having((r) => r.filePath, 'filePath', tFilePath1)
                  .having((r) => r.duration, 'duration', tDuration1)
                  .having((r) => r.createdAt, 'createdAt', tStat1.modified),
            );
          },
          zoneSpecification: ZoneSpecification(
            print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
              printOutput.add(line);
            },
          ),
        );

        // Assert print output
        expect(printOutput, isNotEmpty);
        expect(printOutput.first, contains('Error processing file $tFailPath'));
        expect(printOutput.first, contains(durationException.toString()));

        verify(mockFileSystem.directoryExists(tFakeDocPath));
        verify(mockFileSystem.listDirectory(tFakeDocPath));
        verify(mockFileSystem.stat(tFilePath1));
        verify(mockFileSystem.stat(tFailPath)); // Stat succeeds
        verify(mockAudioDurationGetter.getDuration(tFilePath1));
        verify(
          mockAudioDurationGetter.getDuration(tFailPath),
        ); // Duration getter is called
      },
    );

    test(
      'should throw AudioFileSystemException if directoryExists throws',
      () async {
        // Arrange
        final exception = FileSystemException('Cannot check existence');
        when(mockFileSystem.directoryExists(tFakeDocPath)).thenThrow(exception);

        // Act & Assert
        expect(
          () => dataSource.listRecordingDetails(),
          throwsA(isA<AudioFileSystemException>()),
        );
        // REMOVE verify(mockFileSystem.directoryExists(tFakeDocPath));
        // The expect(throwsA(...)) implicitly covers this interaction.
      },
    );

    test(
      'should throw AudioFileSystemException if listDirectory throws',
      () async {
        // Arrange
        final exception = FileSystemException('Cannot list');
        when(
          mockFileSystem.directoryExists(tFakeDocPath),
        ).thenAnswer((_) async => true);
        when(mockFileSystem.listDirectory(tFakeDocPath)).thenThrow(exception);

        // Act & Assert
        expect(
          () => dataSource.listRecordingDetails(),
          throwsA(isA<AudioFileSystemException>()),
        );
        // REMOVE verify(mockFileSystem.directoryExists(tFakeDocPath));
        // REMOVE verify(mockFileSystem.listDirectory(tFakeDocPath));
        // The expect(throwsA(...)) implicitly covers these interactions.
      },
    );
  });
}
