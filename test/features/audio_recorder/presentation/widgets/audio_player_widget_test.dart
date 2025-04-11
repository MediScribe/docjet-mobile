import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockAudioListCubit extends Mock implements AudioListCubit {}

// Fallback value registration
class FakeDuration extends Fake implements Duration {}

void main() {
  late MockAudioListCubit mockAudioListCubit;

  setUpAll(() {
    // Register a fallback value for Duration for mocktail
    registerFallbackValue(Duration.zero);
    // Alternative using Fake if Duration() constructor wasn't simple:
    // registerFallbackValue(FakeDuration());
  });

  setUp(() {
    mockAudioListCubit = MockAudioListCubit();
    // Provide default stub for the state stream if needed, though not strictly necessary for UI tests
    when(
      () => mockAudioListCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockAudioListCubit.state,
    ).thenReturn(AudioListInitial()); // Default state
  });

  // Helper function to pump the widget tree
  Future<void> pumpWidget(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<AudioListCubit>.value(
            value: mockAudioListCubit,
            child: widget,
          ),
        ),
      ),
    );
  }

  group('AudioPlayerWidget', () {
    const testFilePath = 'test/path/audio.mp3';

    testWidgets('renders CircularProgressIndicator when isLoading is true', (
      WidgetTester tester,
    ) async {
      // Arrange
      final widget = AudioPlayerWidget(
        key: const ValueKey('audio_player'),
        filePath: testFilePath,
        onDelete: () {},
        isPlaying: false,
        isLoading: true, // <<< Loading state
        currentPosition: Duration.zero,
        totalDuration: Duration.zero,
        error: null,
      );

      // Act
      await pumpWidget(tester, widget);

      // Assert
      expect(find.byKey(const ValueKey('audio_player')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byType(Slider),
        findsNothing,
      ); // Ensure player controls are not shown
      expect(find.byIcon(Icons.play_circle_filled), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(
        find.textContaining('Error:'),
        findsNothing,
      ); // Ensure error message is not shown
    });

    testWidgets(
      'renders error message and delete button when error is not null',
      (WidgetTester tester) async {
        // Arrange
        const errorMessage = 'Failed to load audio';
        final widget = AudioPlayerWidget(
          key: const ValueKey('audio_player_error'),
          filePath: testFilePath,
          onDelete: () {},
          isPlaying: false,
          isLoading: false,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
          error: errorMessage, // <<< Error state
        );

        // Act
        await pumpWidget(tester, widget);

        // Assert
        expect(
          find.byKey(const ValueKey('audio_player_error')),
          findsOneWidget,
        );
        expect(find.textContaining('Error: $errorMessage'), findsOneWidget);
        expect(
          find.byIcon(Icons.delete),
          findsOneWidget,
        ); // Regular delete button in error state
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(Slider), findsNothing);
        expect(find.byIcon(Icons.play_circle_filled), findsNothing);
        expect(find.byIcon(Icons.pause_circle_filled), findsNothing);
      },
    );

    testWidgets('renders player controls when not loading and no error', (
      WidgetTester tester,
    ) async {
      // Arrange
      const totalDuration = Duration(minutes: 1, seconds: 30);
      const currentPosition = Duration(seconds: 45);
      final widget = AudioPlayerWidget(
        key: const ValueKey('audio_player_controls'),
        filePath: testFilePath,
        onDelete: () {},
        isPlaying: false, // Initial state: paused
        isLoading: false,
        currentPosition: currentPosition,
        totalDuration: totalDuration,
        error: null,
      );

      // Act
      await pumpWidget(tester, widget);

      // Assert
      expect(
        find.byKey(const ValueKey('audio_player_controls')),
        findsOneWidget,
      );
      // Player controls should be visible
      expect(
        find.byIcon(Icons.play_circle_filled),
        findsOneWidget,
      ); // Should show play initially
      expect(find.byIcon(Icons.pause_circle_filled), findsNothing);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('00:45'), findsOneWidget); // Current position
      expect(find.text('01:30'), findsOneWidget); // Total duration
      expect(
        find.byIcon(Icons.delete_outline),
        findsOneWidget,
      ); // Delete outline button

      // Loading and error indicators should NOT be visible
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Error:'), findsNothing);
    });

    testWidgets('calls cubit.playRecording when play button is tapped', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        () => mockAudioListCubit.playRecording(any()),
      ).thenAnswer((_) async {}); // Stub the method

      final widget = AudioPlayerWidget(
        key: const ValueKey('audio_player_play_tap'),
        filePath: testFilePath,
        onDelete: () {},
        isPlaying: false, // Start paused
        isLoading: false,
        currentPosition: Duration.zero,
        totalDuration: const Duration(seconds: 60),
        error: null,
      );

      await pumpWidget(tester, widget);

      // Act
      await tester.tap(find.byIcon(Icons.play_circle_filled));
      await tester.pump(); // Allow time for the tap event to process

      // Assert
      verify(() => mockAudioListCubit.playRecording(testFilePath)).called(1);
    });

    testWidgets('calls cubit.pauseRecording when pause button is tapped', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        () => mockAudioListCubit.pauseRecording(),
      ).thenAnswer((_) async {}); // Stub the method

      final widget = AudioPlayerWidget(
        key: const ValueKey('audio_player_pause_tap'),
        filePath: testFilePath,
        onDelete: () {},
        isPlaying: true, // Start playing
        isLoading: false,
        currentPosition: const Duration(seconds: 30),
        totalDuration: const Duration(seconds: 60),
        error: null,
      );

      await pumpWidget(tester, widget);

      // Assert precondition: pause button should be visible
      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);

      // Act
      await tester.tap(find.byIcon(Icons.pause_circle_filled));
      await tester.pump();

      // Assert
      verify(() => mockAudioListCubit.pauseRecording()).called(1);
    });

    testWidgets(
      'calls onDelete callback when delete outline button is tapped',
      (WidgetTester tester) async {
        // Arrange
        bool onDeleteCalled = false;
        void testOnDelete() {
          onDeleteCalled = true;
        }

        final widget = AudioPlayerWidget(
          key: const ValueKey('audio_player_delete_tap'),
          filePath: testFilePath,
          onDelete: testOnDelete, // Use the test callback
          isPlaying: false,
          isLoading: false,
          currentPosition: Duration.zero,
          totalDuration: const Duration(seconds: 60),
          error: null,
        );

        await pumpWidget(tester, widget);

        // Act
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pump();

        // Assert
        expect(onDeleteCalled, isTrue);
      },
    );

    testWidgets(
      'calls onDelete callback when delete button is tapped in error state',
      (WidgetTester tester) async {
        // Arrange
        bool onDeleteCalled = false;
        void testOnDelete() {
          onDeleteCalled = true;
        }

        final widget = AudioPlayerWidget(
          key: const ValueKey('audio_player_delete_error_tap'),
          filePath: testFilePath,
          onDelete: testOnDelete, // Use the test callback
          isPlaying: false,
          isLoading: false,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
          error: 'Some error',
        );

        await pumpWidget(tester, widget);

        // Act
        await tester.tap(
          find.byIcon(Icons.delete),
        ); // Regular delete icon in error state
        await tester.pump();

        // Assert
        expect(onDeleteCalled, isTrue);
      },
    );

    testWidgets('calls cubit.seekRecording when slider is changed', (
      WidgetTester tester,
    ) async {
      // Arrange
      const totalDuration = Duration(seconds: 120);
      const seekPositionSeconds = 75.0;
      final expectedSeekDuration = Duration(
        seconds: seekPositionSeconds.toInt(),
      );

      when(
        () => mockAudioListCubit.seekRecording(any()),
      ).thenAnswer((_) async {}); // Stub

      final widget = AudioPlayerWidget(
        key: const ValueKey('audio_player_slider_seek'),
        filePath: testFilePath,
        onDelete: () {},
        isPlaying: false,
        isLoading: false,
        currentPosition: Duration.zero,
        totalDuration: totalDuration,
        error: null,
      );

      await pumpWidget(tester, widget);

      // Act
      // Drag the slider - find the slider and simulate interaction
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // Note: tester.drag works, but setting the value directly via onChanged is more common in flutter tests
      // We'll simulate the onChanged callback directly for precision
      final Slider sliderWidget = tester.widget(sliderFinder);
      expect(sliderWidget.onChanged, isNotNull);
      sliderWidget.onChanged!(
        seekPositionSeconds,
      ); // Simulate changing the value
      await tester.pump(); // Allow state updates

      // Assert
      verify(
        () => mockAudioListCubit.seekRecording(
          testFilePath,
          any(named: "position"),
        ),
      ).called(1);
    });

    testWidgets('calls cubit.seekRecording when dragging ends', (
      WidgetTester tester,
    ) async {
      // Arrange
      const totalDuration = Duration(seconds: 120);
      const seekPositionSeconds = 75.0;
      final expectedSeekDuration = Duration(
        seconds: seekPositionSeconds.toInt(),
      );

      when(
        () => mockAudioListCubit.seekRecording(any()),
      ).thenAnswer((_) async {}); // Stub

      final widget = AudioPlayerWidget(
        key: const ValueKey('audio_player_slider_seek'),
        filePath: testFilePath,
        onDelete: () {},
        isPlaying: false,
        isLoading: false,
        currentPosition: Duration.zero,
        totalDuration: totalDuration,
        error: null,
      );

      await pumpWidget(tester, widget);

      // Act
      // Simulate user interaction: drag slider and release
      final Offset sliderCenter = tester.getCenter(find.byType(Slider));
      await tester.drag(find.byType(Slider), Offset(50.0, 0.0)); // Drag
      await tester.pump(); // Settle drag

      // Verify seekRecording was called on the cubit with path and duration
      // Note: The exact duration depends on slider calculation, mock verification is easier
      verify(
        () => mockAudioListCubit.seekRecording(
          testFilePath,
          any(named: "position"),
        ),
      ).called(1);
    });
  });
}
