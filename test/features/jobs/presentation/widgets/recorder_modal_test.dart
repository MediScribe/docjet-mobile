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

@GenerateMocks([AudioCubit, Stream])
void main() {
  late MockAudioCubit mockAudioCubit;
  late StreamController<AudioState> audioStateController;

  setUp(() {
    mockAudioCubit = MockAudioCubit();
    audioStateController = StreamController<AudioState>.broadcast();

    // Stub the stream getter
    when(mockAudioCubit.stream).thenAnswer((_) => audioStateController.stream);
    // Stub the state getter
    when(mockAudioCubit.state).thenReturn(const AudioState.initial());

    // Stub other methods that might be called during interactions
    when(mockAudioCubit.startRecording()).thenAnswer((_) async {});
    when(mockAudioCubit.stopRecording()).thenAnswer((_) async {
      // Simulate file path being available after stopping
      audioStateController.add(
        const AudioState(
          phase: AudioPhase.idle,
          filePath: '/fake/path/to/audio.m4a',
          position: Duration.zero,
          duration: Duration(seconds: 10),
        ),
      );
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
    // It's good practice to close the mock cubit if it had a close method,
    // but since we're mocking it with thenAnswer for close(), it's fine.
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: createLightTheme(), // Added theme
      home: Scaffold(
        body: BlocProvider<AudioCubit>.value(
          value: mockAudioCubit,
          child: child,
        ),
      ),
    );
  }

  // Removed unused openRecorderModal function
  // Future<void> openRecorderModal(WidgetTester tester) async { ... }

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
}
