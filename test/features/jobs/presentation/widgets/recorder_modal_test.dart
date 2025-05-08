import 'dart:async';

import 'package:docjet_mobile/core/audio/audio_cubit.dart';
import 'package:docjet_mobile/core/audio/audio_state.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart'; // Import for createLightTheme
import 'package:docjet_mobile/core/widgets/buttons/record_start_button.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/recorder_modal.dart'; // Assuming this will be the location
import 'package:docjet_mobile/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'recorder_modal_test.mocks.dart';

// ignore_for_file: void_checks

// Manual Navigator Observer mock
class MockNavigatorObserver extends Mock implements NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {}
}

@GenerateMocks([AudioCubit, Stream])
void main() {
  late MockAudioCubit mockAudioCubit;
  late StreamController<AudioState> audioStateController;
  late MockNavigatorObserver mockNavigatorObserver;

  setUp(() {
    mockAudioCubit = MockAudioCubit();
    audioStateController = StreamController<AudioState>.broadcast();
    mockNavigatorObserver = MockNavigatorObserver();

    // Stub the stream getter
    when(mockAudioCubit.stream).thenAnswer((_) => audioStateController.stream);
    // Stub the state getter with the initial state
    when(mockAudioCubit.state).thenReturn(const AudioState.initial());

    // Stub methods that might be called during interactions
    when(mockAudioCubit.startRecording()).thenAnswer((_) async {
      // We don't emit from here as tests will control state transitions
    });

    when(mockAudioCubit.pauseRecording()).thenAnswer((_) async {
      // We don't emit from here as tests will control state transitions
    });

    when(mockAudioCubit.resumeRecording()).thenAnswer((_) async {
      // We don't emit from here as tests will control state transitions
    });

    when(mockAudioCubit.stopRecording()).thenAnswer((_) async {
      // We don't emit from here as tests will control state transitions
    });

    when(mockAudioCubit.loadAudio(any)).thenAnswer((_) async {});
    when(mockAudioCubit.play()).thenAnswer((_) async {});
    when(mockAudioCubit.pause()).thenAnswer((_) async {});
    when(mockAudioCubit.close()).thenAnswer((_) async {
      return;
    });
  });

  tearDown(() {
    audioStateController.close();
  });

  /// Helper function to emit a specific AudioState and update mockAudioCubit.state
  void emitAudioState(AudioState state) {
    when(mockAudioCubit.state).thenReturn(state);
    audioStateController.add(state);
  }

  /// Helper function to create test states for each AudioPhase
  AudioState createAudioState({
    AudioPhase phase = AudioPhase.idle,
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
    String? filePath,
  }) {
    return AudioState(
      phase: phase,
      position: position,
      duration: duration,
      filePath: filePath,
    );
  }

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: createLightTheme(), // Added theme
      navigatorObservers: [mockNavigatorObserver],
      home: Scaffold(
        body: BlocProvider<AudioCubit>.value(
          value: mockAudioCubit,
          child: child,
        ),
      ),
    );
  }

  testWidgets('tapping record shows modal, stopping reveals player', (
    WidgetTester tester,
  ) async {
    // Arrange: Initial state - audio player not visible
    // For this test, we assume the modal is launched from a button.
    // The actual trigger will be in `JobListPlayground`.

    // Stub the initial state for the AudioCubit
    audioStateController.add(const AudioState.initial());
    await tester.pump();

    // Act: Tap button to show the RecorderModal
    // We'll need a way to simulate this. For now, let's assume RecorderModal
    // can be instantiated directly or via a helper.
    // This part will need to be adjusted once RecorderModal and its trigger are defined.
    // For now, let's assume we are testing RecorderModal directly.
    await tester.pumpWidget(createTestWidget(RecorderModal()));
    await tester.pumpAndSettle(); // Let the widget build

    // Assert: Modal is visible (or at least its specific record button)
    expect(
      find.byType(RecordStartButton),
      findsOneWidget,
      reason: "RecordStartButton should be visible in the modal initially",
    );
    expect(
      find.byType(AudioPlayerWidget),
      findsNothing,
      reason: "AudioPlayer should not be visible initially",
    );

    // Act: Simulate tapping the record button within the modal
    await tester.tap(find.byType(RecordStartButton));
    await tester
        .pumpAndSettle(); // Reflect state change from starting recording

    // Simulate some recording progress if necessary for the UI
    const recordingState = AudioState(
      phase: AudioPhase.recording,
      position: Duration(seconds: 1),
      duration: Duration.zero,
    );
    when(mockAudioCubit.state).thenReturn(recordingState);
    audioStateController.add(recordingState);
    await tester.pumpAndSettle(); // << Ensure full rebuild after state change

    // Act: Simulate tapping a stop button within the modal
    // This assumes RecorderModal has a stop button (e.g., Icons.stop)
    // that appears and calls mockAudioCubit.stopRecording()
    // For the test to make sense, RecorderModal needs to show a stop button after recording starts.
    // Let's assume it appears.
    // We'll need to find it. For now, let's assume it's an icon.
    // If stop button is not present initially, this test will fail here, which is good.
    expect(
      find.byTooltip('Stop Recording'),
      findsOneWidget,
      reason:
          "Stop button (via tooltip) should be visible after starting recording",
    );
    await tester.tap(find.byTooltip('Stop Recording'));
    await tester
        .pumpAndSettle(); // Reflect state change from stopping recording and revealing player

    // Simulate audio loaded state after stopping
    const stoppedState = AudioState(
      phase:
          AudioPhase
              .idle, // Or playingPaused, or whatever indicates ready for playback
      filePath: '/fake/path/to/audio.m4a',
      position: Duration.zero,
      duration: Duration(seconds: 10),
    );
    when(mockAudioCubit.state).thenReturn(stoppedState);
    audioStateController.add(stoppedState);
    await tester
        .pumpAndSettle(); // Reflect state change from stopping recording and revealing player

    // Assert: AudioPlayerWidget is now visible
    expect(
      find.byType(AudioPlayerWidget),
      findsOneWidget,
      reason: "AudioPlayerWidget should be visible after stopping recording",
    );
    // And the record button might be gone or changed
    expect(
      find.byType(RecordStartButton),
      findsNothing,
      reason: "RecordStartButton should be replaced after recording is stopped",
    );
  });

  // Testing IDLE state (no recording)
  testWidgets('in idle state, only RecordStartButton is visible', (
    WidgetTester tester,
  ) async {
    // Set up initial idle state (no file)
    emitAudioState(createAudioState(phase: AudioPhase.idle));

    // Build modal
    await tester.pumpWidget(createTestWidget(const RecorderModal()));
    await tester.pumpAndSettle();

    // Verify only RecordStartButton is visible
    expect(
      find.byType(RecordStartButton),
      findsOneWidget,
      reason: "RecordStartButton should be visible in idle state",
    );

    // Verify other elements are not visible
    expect(
      find.byType(AudioPlayerWidget),
      findsNothing,
      reason: "AudioPlayerWidget should not be visible in idle state",
    );
    expect(
      find.text("Recording"),
      findsNothing,
      reason: "Recording text should not be visible in idle state",
    );
    expect(
      find.text("Recording paused"),
      findsNothing,
      reason: "Recording paused text should not be visible in idle state",
    );
    expect(
      find.byTooltip("Pause"),
      findsNothing,
      reason: "Pause button should not be visible in idle state",
    );
    expect(
      find.byTooltip("Resume"),
      findsNothing,
      reason: "Resume button should not be visible in idle state",
    );
    expect(
      find.byTooltip("Stop Recording"),
      findsNothing,
      reason: "Stop button should not be visible in idle state",
    );

    // Verify no action buttons
    expect(
      find.text("Accept"),
      findsNothing,
      reason: "Accept button should not be visible in idle state",
    );
    expect(
      find.text("Cancel"),
      findsNothing,
      reason: "Cancel button should not be visible in idle state",
    );
  });

  // Testing RECORDING state
  testWidgets('in recording state, shows timer, pause and stop buttons', (
    WidgetTester tester,
  ) async {
    // Set up recording state
    final recordingState = createAudioState(
      phase: AudioPhase.recording,
      position: const Duration(minutes: 1, seconds: 30),
    );
    emitAudioState(recordingState);

    // Build modal
    await tester.pumpWidget(createTestWidget(const RecorderModal()));
    await tester.pumpAndSettle();

    // Verify timer is displayed with correct format
    expect(
      find.text("01:30"),
      findsOneWidget,
      reason: "Timer should show correct duration in recording state",
    );

    // Verify "Recording" text is displayed
    expect(
      find.text("Recording"),
      findsOneWidget,
      reason: "'Recording' text should be displayed in recording state",
    );

    // Verify correct buttons are shown
    expect(
      find.byTooltip("Pause"),
      findsOneWidget,
      reason: "Pause button should be visible in recording state",
    );
    expect(
      find.byTooltip("Stop Recording"),
      findsOneWidget,
      reason: "Stop button should be visible in recording state",
    );

    // Verify other elements are not visible
    expect(
      find.byType(RecordStartButton),
      findsNothing,
      reason: "RecordStartButton should not be visible in recording state",
    );
    expect(
      find.byType(AudioPlayerWidget),
      findsNothing,
      reason: "AudioPlayerWidget should not be visible in recording state",
    );
    expect(
      find.byTooltip("Resume"),
      findsNothing,
      reason: "Resume button should not be visible in recording state",
    );

    // Verify action buttons are not visible
    expect(
      find.text("Accept"),
      findsNothing,
      reason: "Accept button should not be visible in recording state",
    );
    expect(
      find.text("Cancel"),
      findsNothing,
      reason: "Cancel button should not be visible in recording state",
    );

    // Verify tapping pause button calls pauseRecording
    await tester.tap(find.byTooltip("Pause"));
    verify(mockAudioCubit.pauseRecording()).called(1);

    // Verify tapping stop button calls stopRecording
    await tester.tap(find.byTooltip("Stop Recording"));
    verify(mockAudioCubit.stopRecording()).called(1);
  });

  // Testing RECORDING PAUSED state
  testWidgets(
    'in recording paused state, shows timer, resume and stop buttons',
    (WidgetTester tester) async {
      // Set up recording paused state
      final pausedState = createAudioState(
        phase: AudioPhase.recordingPaused,
        position: const Duration(minutes: 2, seconds: 15),
      );
      emitAudioState(pausedState);

      // Build modal
      await tester.pumpWidget(createTestWidget(const RecorderModal()));
      await tester.pumpAndSettle();

      // Verify timer is displayed with correct format
      expect(
        find.text("02:15"),
        findsOneWidget,
        reason: "Timer should show correct duration in paused state",
      );

      // Verify "Recording paused" text is displayed
      expect(
        find.text("Recording paused"),
        findsOneWidget,
        reason: "'Recording paused' text should be displayed in paused state",
      );

      // Verify correct buttons are shown
      expect(
        find.byTooltip("Resume"),
        findsOneWidget,
        reason: "Resume button should be visible in paused state",
      );
      expect(
        find.byTooltip("Stop Recording"),
        findsOneWidget,
        reason: "Stop button should be visible in paused state",
      );

      // Verify other elements are not visible
      expect(
        find.byType(RecordStartButton),
        findsNothing,
        reason: "RecordStartButton should not be visible in paused state",
      );
      expect(
        find.byType(AudioPlayerWidget),
        findsNothing,
        reason: "AudioPlayerWidget should not be visible in paused state",
      );
      expect(
        find.byTooltip("Pause"),
        findsNothing,
        reason: "Pause button should not be visible in paused state",
      );

      // Verify action buttons are not visible
      expect(
        find.text("Accept"),
        findsNothing,
        reason: "Accept button should not be visible in paused state",
      );
      expect(
        find.text("Cancel"),
        findsNothing,
        reason: "Cancel button should not be visible in paused state",
      );

      // Verify tapping resume button calls resumeRecording
      await tester.tap(find.byTooltip("Resume"));
      verify(mockAudioCubit.resumeRecording()).called(1);

      // Verify tapping stop button calls stopRecording
      await tester.tap(find.byTooltip("Stop Recording"));
      verify(mockAudioCubit.stopRecording()).called(1);
    },
  );

  // Testing LOADED state (idle with filePath)
  testWidgets(
    'in loaded state, shows AudioPlayerWidget and accept/cancel buttons',
    (WidgetTester tester) async {
      // Set up loaded state (idle with filePath)
      final loadedState = createAudioState(
        phase: AudioPhase.idle,
        filePath: '/fake/path/to/audio.m4a',
        duration: const Duration(seconds: 45),
      );
      emitAudioState(loadedState);

      // Build modal
      await tester.pumpWidget(createTestWidget(const RecorderModal()));
      await tester.pumpAndSettle();

      // Verify AudioPlayerWidget is displayed
      expect(
        find.byType(AudioPlayerWidget),
        findsOneWidget,
        reason: "AudioPlayerWidget should be visible in loaded state",
      );

      // Verify action buttons are visible
      expect(
        find.text("Accept"),
        findsOneWidget,
        reason: "Accept button should be visible in loaded state",
      );
      expect(
        find.text("Cancel"),
        findsOneWidget,
        reason: "Cancel button should be visible in loaded state",
      );

      // Verify other elements are not visible
      expect(
        find.byType(RecordStartButton),
        findsNothing,
        reason: "RecordStartButton should not be visible in loaded state",
      );
      expect(
        find.text("Recording"),
        findsNothing,
        reason: "Recording text should not be visible in loaded state",
      );
      expect(
        find.text("Recording paused"),
        findsNothing,
        reason: "Recording paused text should not be visible in loaded state",
      );

      // TODO: navigation pop assertions require integration testing via NavigatorObserver.
    },
  );
}
