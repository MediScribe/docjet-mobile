import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/error/failures.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/audio_recorder_repository.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for the repository
@GenerateMocks([AudioRecorderRepository])
import 'audio_list_cubit_test.mocks.dart'; // Generated file

void main() {
  late MockAudioRecorderRepository mockAudioRecorderRepository;
  late AudioListCubit audioListCubit;

  // Sample data for testing
  final tAudioRecord = AudioRecord(
    filePath: 'test/path/recording.aac',
    duration: const Duration(seconds: 10),
    createdAt: DateTime(2023, 1, 1, 10, 0, 0),
  );
  final List<AudioRecord> tAudioRecordList = [tAudioRecord];
  const tFilePath = 'test/path/recording.aac';
  final tServerFailure = ServerFailure();

  setUp(() {
    // Create fresh mocks for each test
    mockAudioRecorderRepository = MockAudioRecorderRepository();
    // Create the Cubit instance, injecting the mock repository
    audioListCubit = AudioListCubit(repository: mockAudioRecorderRepository);
  });

  tearDown(() {
    audioListCubit.close(); // Close the cubit after each test
  });

  test('initial state should be AudioListInitial', () {
    expect(audioListCubit.state, equals(AudioListInitial()));
  });

  group('loadRecordings', () {
    blocTest<AudioListCubit, AudioListState>(
      'should emit [AudioListLoading, AudioListLoaded] when repository call is successful',
      build: () {
        // Arrange: Setup the mock repository response
        when(
          mockAudioRecorderRepository.loadRecordings(),
        ).thenAnswer((_) async => Right(tAudioRecordList));
        return audioListCubit;
      },
      act: (cubit) => cubit.loadRecordings(), // Act: Call the method under test
      expect:
          () => <AudioListState>[
            // Assert: Verify the emitted states
            AudioListLoading(),
            AudioListLoaded(tAudioRecordList),
          ],
      verify: (_) {
        // Verify: Check if the repository method was called
        verify(mockAudioRecorderRepository.loadRecordings());
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    blocTest<AudioListCubit, AudioListState>(
      'should emit [AudioListLoading, AudioListError] when repository call fails',
      build: () {
        // Arrange
        when(
          mockAudioRecorderRepository.loadRecordings(),
        ).thenAnswer((_) async => Left(tServerFailure));
        return audioListCubit;
      },
      act: (cubit) => cubit.loadRecordings(),
      expect:
          () => <AudioListState>[
            AudioListLoading(),
            AudioListError(
              'Failed to load recordings: ${tServerFailure.toString()}',
            ),
          ],
      verify: (_) {
        verify(mockAudioRecorderRepository.loadRecordings());
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );
  });

  group('deleteRecording', () {
    // Setup successful load first to have a state to delete from
    final initialState = AudioListLoaded(tAudioRecordList);

    blocTest<AudioListCubit, AudioListState>(
      'should emit [AudioListLoading, AudioListLoaded(empty)] when deletion is successful and reload works',
      setUp: () {
        // Arrange: Mock delete success
        when(mockAudioRecorderRepository.deleteRecording(any)).thenAnswer(
          (_) async => const Right(null),
        ); // Delete returns Right(null)
        // Arrange: Mock subsequent load success (empty list)
        when(
          mockAudioRecorderRepository.loadRecordings(),
        ).thenAnswer((_) async => const Right([]));
      },
      build: () => audioListCubit,
      seed: () => initialState, // Start from a loaded state
      act: (cubit) => cubit.deleteRecording(tFilePath),
      expect:
          () => <AudioListState>[
            // Note: We don't have a specific 'Deleting' state, so it goes Loading -> Loaded
            AudioListLoading(), // State during the loadRecordings call after delete
            AudioListLoaded([]), // State after successful reload
          ],
      verify: (_) {
        verify(
          mockAudioRecorderRepository.deleteRecording(tFilePath),
        ).called(1);
        verify(
          mockAudioRecorderRepository.loadRecordings(),
        ).called(1); // Verify reload happens
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );

    blocTest<AudioListCubit, AudioListState>(
      'should emit [AudioListError] when deletion fails (and does not reload)',
      setUp: () {
        // Arrange: Mock delete failure
        when(
          mockAudioRecorderRepository.deleteRecording(any),
        ).thenAnswer((_) async => Left(tServerFailure));
      },
      build: () => audioListCubit,
      seed: () => initialState, // Start from a loaded state
      act: (cubit) => cubit.deleteRecording(tFilePath),
      expect:
          () => <AudioListState>[
            // Only emits error, keeps previous loaded state implicitly before error
            AudioListError(
              'Failed to delete recording: ${tServerFailure.toString()}',
            ),
          ],
      verify: (_) {
        verify(
          mockAudioRecorderRepository.deleteRecording(tFilePath),
        ).called(1);
        // IMPORTANT: Verify loadRecordings is NOT called on failure
        verifyNever(mockAudioRecorderRepository.loadRecordings());
        verifyNoMoreInteractions(mockAudioRecorderRepository);
      },
    );
  });

  // Add more tests for other methods if the cubit grows (sorting, filtering etc.)
}
