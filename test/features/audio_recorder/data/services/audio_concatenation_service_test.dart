import 'dart:io';

import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'audio_concatenation_service_test.mocks.dart';

// Mock FFmpegKit statically if needed, or use wrapper if preferred
// For simplicity, we might mock the static methods directly if feasible
// or mock Session/ReturnCode if FFmpegKit.executeAsync returns those.

@GenerateNiceMocks([
  MockSpec<FileSystem>(),
  MockSpec<PathProvider>(),
  MockSpec<Directory>(),
  // Mocks for FFmpegKit interaction (might need adjustment based on mocking strategy)
  MockSpec<FFmpegSession>(),
  MockSpec<ReturnCode>(),
])
void main() {
  late FFmpegAudioConcatenator concatenationService;
  late MockFileSystem mockFileSystem;
  late MockPathProvider mockPathProvider;
  late MockDirectory mockDirectory;
  // Mocks for ffmpeg interaction
  late MockFFmpegSession mockFFmpegSession;
  late MockReturnCode mockReturnCode;

  const tFakeDocPath = '/fake/doc/path';
  const tInputPath1 = '$tFakeDocPath/input1.m4a';
  const tInputPath2 = '$tFakeDocPath/input2.m4a';
  final tInputPaths = [tInputPath1, tInputPath2];

  setUp(() {
    mockFileSystem = MockFileSystem();
    mockPathProvider = MockPathProvider();
    mockDirectory = MockDirectory();
    mockFFmpegSession = MockFFmpegSession();
    mockReturnCode = MockReturnCode();

    concatenationService = FFmpegAudioConcatenator(
      fileSystem: mockFileSystem,
      pathProvider: mockPathProvider,
    );

    // Common setup
    when(mockDirectory.path).thenReturn(tFakeDocPath);
    when(
      mockPathProvider.getApplicationDocumentsDirectory(),
    ).thenAnswer((_) async => mockDirectory);
    when(mockFileSystem.fileExists(any)).thenAnswer((_) async => true);

    // Mock FFmpeg interaction (adjust based on actual FFmpegKit API usage)
    // Assuming FFmpegKit.executeAsync returns a Future<FFmpegSession>
    // Need to mock the static method or use a wrapper. This part is tricky.
    // For now, let's assume we can mock the session and return code.
    when(
      mockFFmpegSession.getReturnCode(),
    ).thenAnswer((_) async => mockReturnCode);
    when(
      mockFFmpegSession.getLogsAsString(),
    ).thenAnswer((_) async => 'Success log');
    when(mockReturnCode.isValueSuccess()).thenReturn(true); // Mock success case

    // TODO: Figure out proper static mocking or wrapper for FFmpegKit.executeAsync
    // This setup is incomplete without mocking the static call.
  });

  test(
    'should throw ArgumentError if less than two input paths provided',
    () async {
      // Arrange
      final invalidPaths = [tInputPath1];
      // Act & Assert
      expect(
        () => concatenationService.concatenate(invalidPaths),
        throwsArgumentError,
      );
    },
  );

  test(
    'should throw RecordingFileNotFoundException if an input file does not exist',
    () async {
      // Arrange
      when(
        mockFileSystem.fileExists(tInputPath2),
      ).thenAnswer((_) async => false);

      // Act
      try {
        await concatenationService.concatenate(tInputPaths);
        fail(
          "Should have thrown RecordingFileNotFoundException",
        ); // Fail if no exception
      } on RecordingFileNotFoundException {
        // Assert: Exception was thrown as expected. Now verify the calls.
        // Verify input1 was checked (should have happened before the throw)
        verify(mockFileSystem.fileExists(tInputPath1)).called(1);
        // Verify input2 was checked (this call triggered the exception)
        verify(mockFileSystem.fileExists(tInputPath2)).called(1);
      } catch (e) {
        fail("Threw unexpected exception type: $e"); // Fail on other exceptions
      }
    },
  );

  test(
    'should throw AudioFileSystemException if file existence check fails',
    () async {
      // Arrange
      final exception = Exception('Disk error');
      when(mockFileSystem.fileExists(tInputPath1)).thenThrow(exception);
      // Act & Assert
      expect(
        () => concatenationService.concatenate(tInputPaths),
        throwsA(isA<AudioFileSystemException>()),
      );
    },
  );

  // TODO: Add tests for successful concatenation
  // - Verifies correct ffmpeg command is generated (needs capture)
  // - Verifies list file is created with correct content and deleted
  // - Verifies output file existence is checked
  // - Returns correct output path

  // TODO: Add tests for FFmpeg execution failure
  // - Mocks FFmpegKit.executeAsync to return failure ReturnCode
  // - Verifies AudioConcatenationException is thrown with logs
  // - Verifies list file is still deleted

  // TODO: Add tests for exceptions during list file writing/deletion
  // - Mock dart:io File operations or enhance FileSystem abstraction
}
