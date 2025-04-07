import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart'; // Use Transcription
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart'; // Import status
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'audio_list_cubit_test.mocks.dart';

@GenerateMocks([AudioRecorderRepository])
void main() {
  late MockAudioRecorderRepository mockRepository;
  late AudioListCubit cubit;

  // Sample Transcription data for testing
  final tNow = DateTime.now();
  const tPath1 = '/path/rec1.m4a';
  const tPath2 = '/path/rec2.m4a';

  final tTranscription1 = Transcription(
    id: 'uuid-1',
    localFilePath: tPath1,
    status: TranscriptionStatus.completed,
    localCreatedAt: tNow.subtract(const Duration(minutes: 10)),
    backendUpdatedAt: tNow.subtract(const Duration(minutes: 5)),
    localDurationMillis: 10000,
    displayTitle: 'Meeting Notes',
    displayText: 'Discussed project milestones...',
  );

  final tTranscription2 = Transcription(
    id: 'uuid-2',
    localFilePath: tPath2,
    status: TranscriptionStatus.processing,
    localCreatedAt: tNow,
    backendUpdatedAt: tNow,
    localDurationMillis: 20000,
  );

  final tTranscriptionList = [
    tTranscription2,
    tTranscription1,
  ]; // Sorted newest first

  setUp(() {
    mockRepository = MockAudioRecorderRepository();
    cubit = AudioListCubit(repository: mockRepository);
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state should be AudioListInitial', () {
    expect(cubit.state, AudioListInitial());
  });

  group('loadAudioRecordings', () {
    blocTest<AudioListCubit, AudioListState>(
      'emits [AudioListLoading, AudioListLoaded] when loadTranscriptions is successful',
      build: () {
        when(mockRepository.loadTranscriptions()) // Mock loadTranscriptions
        .thenAnswer((_) async => Right(tTranscriptionList));
        return cubit;
      },
      act: (cubit) => cubit.loadAudioRecordings(),
      expect:
          () => [
            AudioListLoading(),
            AudioListLoaded(
              recordings: tTranscriptionList,
            ), // Expect Transcription list
          ],
      verify: (_) {
        verify(
          mockRepository.loadTranscriptions(),
        ); // Verify loadTranscriptions called
        verifyNoMoreInteractions(mockRepository);
      },
    );

    blocTest<AudioListCubit, AudioListState>(
      'emits [AudioListLoading, AudioListLoaded with empty list] when loadTranscriptions returns empty list',
      build: () {
        when(
          mockRepository.loadTranscriptions(),
        ).thenAnswer((_) async => const Right([]));
        return cubit;
      },
      act: (cubit) => cubit.loadAudioRecordings(),
      expect:
          () => [
            AudioListLoading(),
            const AudioListLoaded(
              recordings: [],
            ), // Expect empty Transcription list
          ],
      verify: (_) {
        verify(mockRepository.loadTranscriptions());
        verifyNoMoreInteractions(mockRepository);
      },
    );

    blocTest<AudioListCubit, AudioListState>(
      'emits [AudioListLoading, AudioListError] when loadTranscriptions fails',
      build: () {
        when(mockRepository.loadTranscriptions()).thenAnswer(
          (_) async => const Left(FileSystemFailure('Failed to list files')),
        );
        return cubit;
      },
      act: (cubit) => cubit.loadAudioRecordings(),
      expect:
          () => [
            AudioListLoading(),
            const AudioListError(
              message: 'FileSystemFailure(Failed to list files)',
            ),
          ],
      verify: (_) {
        verify(mockRepository.loadTranscriptions());
        verifyNoMoreInteractions(mockRepository);
      },
    );

    // TODO: Add test for deleteRecording and its effect on the list
  });
}
