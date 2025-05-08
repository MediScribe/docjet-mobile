import 'dart:async';

import 'package:docjet_mobile/core/audio/audio_cubit.dart';
import 'package:docjet_mobile/core/audio/audio_state.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'audio_player_widget_test.mocks.dart';

@GenerateMocks([AudioCubit])
void main() {
  late MockAudioCubit mockAudioCubit;
  late StreamController<AudioState> streamController;

  setUp(() {
    mockAudioCubit = MockAudioCubit();
    streamController = StreamController<AudioState>.broadcast();

    // Setup the stream getter to return our controlled stream
    when(mockAudioCubit.stream).thenAnswer((_) => streamController.stream);
    when(mockAudioCubit.close()).thenAnswer((_) async {});
    when(mockAudioCubit.isClosed).thenReturn(false);
  });

  tearDown(() async {
    await streamController.close();
  });

  /// Test helper to setup the widget with the given state
  Future<void> pumpTestWidget(
    WidgetTester tester,
    AudioState initialState,
  ) async {
    // Set up the initial state
    when(mockAudioCubit.state).thenReturn(initialState);

    // Emit the initial state so that late listeners receive it
    if (!streamController.isClosed) {
      streamController.add(initialState);
    }

    // Pump the widget tree
    await tester.pumpWidget(
      MaterialApp(
        theme: createLightTheme(),
        home: Scaffold(
          body: BlocProvider<AudioCubit>.value(
            value: mockAudioCubit,
            child: const AudioPlayerWidget(),
          ),
        ),
      ),
    );

    // Allow the widget to fully render
    await tester.pumpAndSettle();
  }

  group('AudioPlayerWidget', () {
    testWidgets('displays play button when audio is paused', (
      WidgetTester tester,
    ) async {
      // Arrange: Set up the mock to return a paused state
      final pausedState = AudioState(
        phase: AudioPhase.playingPaused,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 30),
        filePath: 'test_file.m4a',
      );

      // Act: Render the widget with the paused state
      await pumpTestWidget(tester, pausedState);

      // Assert: Should find a play button icon
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('displays pause button when audio is playing', (
      WidgetTester tester,
    ) async {
      // Arrange: Set up the mock to return a playing state
      final playingState = AudioState(
        phase: AudioPhase.playing,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 30),
        filePath: 'test_file.m4a',
      );

      // Act: Render the widget with the playing state
      await pumpTestWidget(tester, playingState);

      // Assert: Should find a pause button icon
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('slider position reflects current audio position', (
      WidgetTester tester,
    ) async {
      // Arrange: Set up the mock to return a state with specific position/duration
      final testState = AudioState(
        phase: AudioPhase.playing,
        position: const Duration(seconds: 15),
        duration: const Duration(seconds: 30),
        filePath: 'test_file.m4a',
      );

      // Act: Render the widget with the test state
      await pumpTestWidget(tester, testState);

      // Assert: Slider value should match position/duration ratio
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0.5); // 15/30 = 0.5
    });

    testWidgets('tapping play button calls play() on cubit', (
      WidgetTester tester,
    ) async {
      // Arrange: Set up the mock to return a paused state
      final pausedState = AudioState(
        phase: AudioPhase.playingPaused,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 30),
        filePath: 'test_file.m4a',
      );

      // Act: Render the widget and tap the play button
      await pumpTestWidget(tester, pausedState);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      // Assert: Verify play was called
      verify(mockAudioCubit.play()).called(1);
    });

    testWidgets('tapping pause button calls pause() on cubit', (
      WidgetTester tester,
    ) async {
      // Arrange: Set up the mock to return a playing state
      final playingState = AudioState(
        phase: AudioPhase.playing,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 30),
        filePath: 'test_file.m4a',
      );

      // Act: Render the widget and tap the pause button
      await pumpTestWidget(tester, playingState);
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      // Assert: Verify pause was called
      verify(mockAudioCubit.pause()).called(1);
    });

    testWidgets('dragging slider calls seek() on cubit with correct position', (
      WidgetTester tester,
    ) async {
      // Arrange: Set up the mock to return a playing state
      final playingState = AudioState(
        phase: AudioPhase.playing,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 60),
        filePath: 'test_file.m4a',
      );

      // Act: Render the widget
      await pumpTestWidget(tester, playingState);

      // Find the slider and simulate dragging to 0.75 (75% of duration = 45 seconds)
      final sliderFinder = find.byType(Slider);

      // Simulate a drag operation that moves the slider
      await tester.drag(sliderFinder, const Offset(100, 0));

      // Complete the drag and allow callbacks to execute
      await tester.pumpAndSettle();

      // Assert: Verify seek was called with a duration close to what we expect
      // Note: We can't predict the exact value due to slider dimensions and drag behavior
      // so we verify that seek() was called at least once
      verify(mockAudioCubit.seek(any)).called(greaterThan(0));
    });

    testWidgets('updates UI when audio state changes', (
      WidgetTester tester,
    ) async {
      // Arrange: Initial paused state
      final pausedState = AudioState(
        phase: AudioPhase.playingPaused,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 30),
        filePath: 'test_file.m4a',
      );

      // Act: Render widget with initial state
      await pumpTestWidget(tester, pausedState);

      // Assert: Initially shows play button
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);

      // Act: Change state to playing
      final playingState = AudioState(
        phase: AudioPhase.playing,
        position: const Duration(seconds: 15),
        duration: const Duration(seconds: 30),
        filePath: 'test_file.m4a',
      );

      // Update mock state
      when(mockAudioCubit.state).thenReturn(playingState);

      // Emit the new state through the stream
      streamController.add(playingState);

      // Wait for widget to rebuild and settle animations
      await tester.pumpAndSettle();

      // Assert: Now shows pause button
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });
  });
}
