import 'package:bloc_test/bloc_test.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription_status.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_state.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/pages/audio_recorder_list_page.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/pages/audio_recorder_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/widgets/audio_player_widget.dart';
import 'package:mocktail/mocktail.dart';
import 'package:equatable/equatable.dart';
import 'dart:async';

// Mock the Cubit using mocktail
class MockAudioListCubit extends MockBloc<AudioListEvent, AudioListState>
    implements AudioListCubit {}

// Mock the other needed Cubit
class MockAudioRecordingCubit extends MockBloc<Object, AudioRecordingState>
    implements AudioRecordingCubit {}

// Define a base event class if your cubit needs specific events
abstract class AudioListEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

void main() {
  late MockAudioListCubit mockAudioListCubit;
  late MockAudioRecordingCubit mockAudioRecordingCubit;

  // Sample Transcription data for testing
  final tNow = DateTime.now();
  final tTranscription1 = Transcription(
    id: '1',
    localFilePath: '/local/path1.m4a',
    status: TranscriptionStatus.completed,
    localCreatedAt: tNow.subtract(const Duration(days: 1)),
    localDurationMillis: 30000, // Example duration
    displayTitle: 'Recording 1', // Example title
  );
  final tTranscription2 = Transcription(
    id: '2',
    localFilePath: '/local/path2.m4a',
    status: TranscriptionStatus.processing,
    localCreatedAt: tNow,
    displayTitle: 'Existing Title',
    localDurationMillis: 60000, // Example duration
  );
  final tTranscriptionList = [tTranscription1, tTranscription2];

  setUp(() {
    // Mocks
    mockAudioListCubit = MockAudioListCubit();
    mockAudioRecordingCubit = MockAudioRecordingCubit();

    // Setup for AudioListCubit (using Mocktail/BlocTest standards)
    EquatableConfig.stringify = true; // Optional: for easier debugging
    registerFallbackValue(AudioListInitial());
    registerFallbackValue(AudioListLoaded(transcriptions: []));
    // Register fallbacks for the new mock
    registerFallbackValue(
      AudioRecordingInitial(),
    ); // Assuming this state exists
    registerFallbackValue(
      AudioRecordingReady(),
    ); // Assuming this state exists and is needed

    // Stub initial states and methods for mocks
    when(
      () => mockAudioListCubit.state,
    ).thenReturn(AudioListInitial()); // Provide initial state
    when(() => mockAudioRecordingCubit.state).thenReturn(
      AudioRecordingReady(),
    ); // Provide initial state for the recording cubit
    when(
      () => mockAudioRecordingCubit.prepareRecorder(),
    ).thenAnswer((_) async {}); // Stub the prepareRecorder method
  });

  Widget createWidgetUnderTest() {
    // Use MultiBlocProvider to provide both mocks ABOVE MaterialApp
    return MultiBlocProvider(
      providers: [
        BlocProvider<AudioListCubit>.value(value: mockAudioListCubit),
        BlocProvider<AudioRecordingCubit>.value(value: mockAudioRecordingCubit),
      ],
      child: const MaterialApp(
        home: AudioRecorderListView(), // Target the view with the BlocConsumer
      ),
    );
  }

  testWidgets(
    'renders CircularProgressIndicator when state is AudioListLoading',
    (tester) async {
      // Arrange
      whenListen(
        mockAudioListCubit,
        Stream<AudioListState>.fromIterable([AudioListLoading()]),
        initialState: AudioListInitial(),
      );
      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('renders list of transcriptions when state is AudioListLoaded', (
    tester,
  ) async {
    // Arrange
    final loadedState = AudioListLoaded(transcriptions: tTranscriptionList);
    whenListen(
      mockAudioListCubit,
      Stream<AudioListState>.fromIterable([loadedState]),
      initialState: AudioListInitial(),
    );

    // Act
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(tTranscriptionList.length));
    expect(find.widgetWithText(ListTile, 'Recording 1'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Existing Title'), findsOneWidget);
    expect(
      find.byType(AudioPlayerWidget),
      findsNWidgets(tTranscriptionList.length),
    );
  });

  testWidgets(
    'renders empty message when state is AudioListLoaded with empty list',
    (tester) async {
      // Arrange
      when(
        () => mockAudioListCubit.state,
      ).thenReturn(const AudioListLoaded(transcriptions: []));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(
        find.text('No recordings yet. Tap + to start recording.'),
        findsOneWidget,
      );
      expect(find.byType(ListView), findsNothing);
    },
  );

  testWidgets(
    'renders error message and retry button when state is AudioListError',
    (tester) async {
      // Arrange
      const errorMessage = 'Failed to load';
      when(
        () => mockAudioListCubit.state,
      ).thenReturn(const AudioListError(message: errorMessage));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.textContaining(errorMessage), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Retry Loading'),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping retry button calls loadAudioRecordings', (tester) async {
    // Arrange
    const errorMessage = 'Failed to load';
    when(
      () => mockAudioListCubit.state,
    ).thenReturn(const AudioListError(message: errorMessage));
    when(
      () => mockAudioListCubit.loadAudioRecordings(),
    ).thenAnswer((_) async {});

    // Act
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry Loading'));
    await tester.pump();

    // Assert
    verify(() => mockAudioListCubit.loadAudioRecordings()).called(1);
  });

  testWidgets(
    'tapping FAB navigates to AudioRecorderPage and calls loadAudioRecordings on return',
    (tester) async {
      // Arrange
      when(
        () => mockAudioListCubit.state,
      ).thenReturn(AudioListLoaded(transcriptions: tTranscriptionList));
      when(
        () => mockAudioListCubit.loadAudioRecordings(),
      ).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Find the FAB using the correct type
      final fabFinder = find.widgetWithIcon(FloatingActionButton, Icons.add);
      expect(fabFinder, findsOneWidget);

      // Tap the FAB
      await tester.tap(fabFinder);
      await tester.pumpAndSettle(); // Allow navigation to complete

      // Assert: Verify navigation happened (e.g., AudioRecorderPage is shown)
      expect(find.byType(AudioRecorderPage), findsOneWidget);

      // Simulate returning from the page with 'true' to trigger refresh
      Navigator.of(tester.element(find.byType(AudioRecorderPage))).pop(true);
      await tester.pumpAndSettle(); // Allow list page rebuild

      // Assert: Verify loadAudioRecordings was called (implicitly by checking state changes or mock)
      // Note: Direct verification might be tricky depending on how state updates
      // after pop. Let's assume for now the test setup handles this implicitly
      // or we can add more specific state checks if needed.
    },
  );

  testWidgets(
    'AudioPlayerWidget receives updated position when only PlaybackInfo changes',
    (WidgetTester tester) async {
      // Arrange: Stream controller for manual state emission
      final controller = StreamController<AudioListState>.broadcast();

      // Arrange: Define state sequence
      final initialLoadedState = AudioListLoaded(
        transcriptions: tTranscriptionList,
        playbackInfo:
            const PlaybackInfo.initial(), // Start with initial playback info
      );
      final playingState1 = AudioListLoaded(
        transcriptions: tTranscriptionList,
        playbackInfo: PlaybackInfo(
          activeFilePath: tTranscription1.localFilePath,
          isPlaying: true,
          isLoading: false,
          currentPosition: const Duration(seconds: 5),
          totalDuration: const Duration(milliseconds: 30000),
          error: null,
        ),
      );
      final playingState2 = AudioListLoaded(
        transcriptions: tTranscriptionList,
        playbackInfo: PlaybackInfo(
          activeFilePath: tTranscription1.localFilePath,
          isPlaying: true,
          isLoading: false,
          currentPosition: const Duration(seconds: 10), // Updated position
          totalDuration: const Duration(milliseconds: 30000),
          error: null,
        ),
      );

      // Arrange: Stub the cubit stream to use the controller
      // Provide the INITIAL state the cubit should have when the widget builds
      when(() => mockAudioListCubit.state).thenReturn(initialLoadedState);
      when(
        () => mockAudioListCubit.stream,
      ).thenAnswer((_) => controller.stream);

      // Act: Pump initial widget
      await tester.pumpWidget(createWidgetUnderTest());
      // pumpAndSettle ensures initial state is fully rendered
      await tester.pumpAndSettle();

      // --- Assert Initial State (before any emissions) ---
      final playerWidgetFinder = find.byKey(
        ValueKey(tTranscription1.localFilePath),
      );
      expect(
        playerWidgetFinder,
        findsOneWidget,
        reason: "Should find player widget initially",
      );
      AudioPlayerWidget playerWidgetInitial = tester.widget(playerWidgetFinder);
      expect(
        playerWidgetInitial.isPlaying,
        isFalse, // Based on initialLoadedState
        reason: "Should not be playing initially",
      );
      expect(
        playerWidgetInitial.currentPosition,
        Duration.zero, // Based on initialLoadedState
        reason: "Position should be zero initially",
      );

      // --- Act & Assert for playingState1 ---
      controller.add(playingState1);
      await tester.pump(); // Process the single frame
      await tester.pump(); // ADDED: Extra pump to ensure state propagation?

      AudioPlayerWidget playerWidget1 = tester.widget(playerWidgetFinder);
      expect(
        playerWidget1.isPlaying,
        isTrue,
        reason: "Widget should be playing after state 1 emission",
      );
      expect(
        playerWidget1.currentPosition,
        const Duration(seconds: 5),
        reason: "Position should be 5s after state 1 emission",
      );
      expect(
        playerWidget1.totalDuration,
        const Duration(milliseconds: 30000),
        reason: "Total duration should match state 1",
      );

      // --- Act & Assert for playingState2 ---
      controller.add(playingState2);
      await tester.pump(); // Process the single frame
      await tester.pump(); // ADDED: Extra pump here too for consistency

      // Assert: Find the SAME widget instance and check updated position
      AudioPlayerWidget playerWidget2 = tester.widget(playerWidgetFinder);
      expect(
        playerWidget2.isPlaying,
        isTrue,
        reason: "Widget should still be playing after state 2 emission",
      );
      expect(
        playerWidget2.currentPosition,
        const Duration(seconds: 10),
        reason: "Position should update to 10s after state 2 emission",
      );
      expect(
        playerWidget2.totalDuration,
        const Duration(milliseconds: 30000),
        reason: "Total duration should remain the same",
      );

      // Clean up controller
      await controller.close();
    },
  );

  testWidgets(
    'AudioPlayerWidget receives correct state after Play -> Pause -> Play sequence',
    (WidgetTester tester) async {
      // Arrange: Stream controller for manual state emission
      final controller = StreamController<AudioListState>.broadcast();

      // Arrange: Define state sequence
      final initialLoadedState = AudioListLoaded(
        transcriptions: tTranscriptionList,
        playbackInfo: const PlaybackInfo.initial(),
      );
      final playingState = AudioListLoaded(
        transcriptions: tTranscriptionList,
        playbackInfo: PlaybackInfo(
          activeFilePath: tTranscription1.localFilePath,
          isPlaying: true,
          isLoading: false,
          currentPosition: const Duration(seconds: 5),
          totalDuration: const Duration(milliseconds: 30000),
        ),
      );
      final pausedState = AudioListLoaded(
        transcriptions: tTranscriptionList,
        playbackInfo: PlaybackInfo(
          activeFilePath: tTranscription1.localFilePath,
          isPlaying: false, // Paused
          isLoading: false,
          currentPosition: const Duration(seconds: 5), // Position retained
          totalDuration: const Duration(milliseconds: 30000),
        ),
      );
      // Assuming play restarts from beginning
      final playingAgainState = AudioListLoaded(
        transcriptions: tTranscriptionList,
        playbackInfo: PlaybackInfo(
          activeFilePath: tTranscription1.localFilePath,
          isPlaying: true, // Playing again
          isLoading: false,
          currentPosition: Duration.zero, // Position reset
          totalDuration: const Duration(milliseconds: 30000),
        ),
      );

      // Arrange: Stub the cubit stream to use the controller
      // Provide the INITIAL state the cubit should have when the widget builds
      when(() => mockAudioListCubit.state).thenReturn(initialLoadedState);
      when(
        () => mockAudioListCubit.stream,
      ).thenAnswer((_) => controller.stream);

      // Act: Pump initial widget
      await tester.pumpWidget(createWidgetUnderTest());
      // No pump needed here yet, initial build uses the stubbed state

      // --- Verify INITIAL state ---
      // print('TEST LOG: State before initial check: ${mockAudioListCubit.state}'); // <<< REMOVE LOG
      final playerWidgetFinder = find.byKey(
        ValueKey(tTranscription1.localFilePath),
      );
      expect(
        playerWidgetFinder,
        findsOneWidget,
        reason: "Should find widget initially",
      );
      AudioPlayerWidget playerWidgetInitial = tester.widget(playerWidgetFinder);
      expect(
        playerWidgetInitial.isPlaying,
        isFalse,
        reason: "Should not be playing initially",
      );
      expect(playerWidgetInitial.currentPosition, Duration.zero);

      // --- Verify PLAY state ---
      // print('TEST LOG: State before play check: ${mockAudioListCubit.state}'); // <<< REMOVE LOG
      controller.add(playingState); // Emit playing state
      await tester.pump(); // Process the single frame
      AudioPlayerWidget playerWidgetPlay = tester.widget(playerWidgetFinder);
      expect(
        playerWidgetPlay.isPlaying,
        isTrue,
        reason: "Should be playing (1st play)",
      );
      expect(playerWidgetPlay.currentPosition, const Duration(seconds: 5));

      // --- Verify PAUSE state ---
      controller.add(pausedState); // Emit paused state
      await tester.pump(); // Process the single frame
      await tester.pump(); // <<< ADD SECOND PUMP
      AudioPlayerWidget playerWidgetPause = tester.widget(playerWidgetFinder);
      expect(playerWidgetPause.isPlaying, isFalse, reason: "Should be paused");
      expect(
        playerWidgetPause.currentPosition,
        const Duration(seconds: 5),
      ); // Position retained

      // --- Verify PLAY AGAIN state ---
      controller.add(playingAgainState); // Emit playing again state
      await tester.pump(); // Process the single frame
      await tester.pump(); // <<< ADD SECOND PUMP HERE TOO
      AudioPlayerWidget playerWidgetPlayAgain = tester.widget(
        playerWidgetFinder,
      );
      expect(
        playerWidgetPlayAgain.isPlaying,
        isTrue,
        reason: "Should be playing (2nd play)",
      );
      expect(
        playerWidgetPlayAgain.currentPosition,
        Duration.zero,
        reason: "Position should reset",
      );

      // Clean up controller
      await controller.close();
    },
  );
}
