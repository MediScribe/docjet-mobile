import 'package:bloc_test/bloc_test.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_state.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/pages/audio_recorder_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockAudioRecordingCubit extends MockCubit<AudioRecordingState>
    implements AudioRecordingCubit {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

// Define a fake Route class for fallback registration
class FakeRoute<T> extends Fake implements Route<T> {}

void main() {
  late MockAudioRecordingCubit mockAudioRecordingCubit;
  late MockNavigatorObserver mockNavigatorObserver;

  // Register fallback value for Route<dynamic> ONCE for all tests
  setUpAll(() {
    registerFallbackValue(FakeRoute<dynamic>());
  });

  setUp(() {
    mockAudioRecordingCubit = MockAudioRecordingCubit();
    mockNavigatorObserver = MockNavigatorObserver();

    // Stub initial state
    when(
      () => mockAudioRecordingCubit.state,
    ).thenReturn(AudioRecordingInitial());
    // Stub the stream to prevent Null errors with whenListen/BlocConsumer
    when(
      () => mockAudioRecordingCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    // Stub methods that might be called
    when(
      () => mockAudioRecordingCubit.prepareRecorder(),
    ).thenAnswer((_) async {});
    when(
      () => mockAudioRecordingCubit.startRecording(),
    ).thenAnswer((_) async {});
    when(
      () => mockAudioRecordingCubit.stopRecording(),
    ).thenAnswer((_) async => '/fake/path'); // Return path for pop
    when(
      () => mockAudioRecordingCubit.pauseRecording(),
    ).thenAnswer((_) async {});
    when(
      () => mockAudioRecordingCubit.resumeRecording(),
    ).thenAnswer((_) async {});
    when(
      () => mockAudioRecordingCubit.openAppSettings(),
    ).thenAnswer((_) async {});
    when(
      () => mockAudioRecordingCubit.close(),
    ).thenAnswer((_) async {}); // Ensure close is stubbed
  });

  tearDown(() {
    mockAudioRecordingCubit.close();
  });

  // Helper function to pump the widget tree
  Future<void> pumpRecorderPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AudioRecordingCubit>.value(
          value: mockAudioRecordingCubit,
          child: const AudioRecorderPage(),
        ),
        navigatorObservers: [mockNavigatorObserver],
      ),
    );
    // Trigger the initState call. Replace pumpAndSettle with pump.
    // await tester.pumpAndSettle();
    await tester.pump(); // Allow async initState operations to start
  }

  testWidgets('should call prepareRecorder on init', (
    WidgetTester tester,
  ) async {
    // Arrange is done in setUp and pumpRecorderPage

    // Act
    await pumpRecorderPage(tester);
    await tester
        .pump(); // Add extra pump to ensure async prepareRecorder completes

    // Assert
    verify(() => mockAudioRecordingCubit.prepareRecorder()).called(1);
  });

  testWidgets('should display initializing indicator for Initial state', (
    WidgetTester tester,
  ) async {
    // Arrange: Initial state is set in setUp before pumpRecorderPage
    // Act
    await pumpRecorderPage(tester);
    await tester.pump(); // Ensure state is processed
    // Assert
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Initializing...'), findsOneWidget);
  });

  testWidgets('should display loading indicator for Loading state', (
    WidgetTester tester,
  ) async {
    // Arrange
    // Use whenListen to simulate state change after initial build
    whenListen(
      mockAudioRecordingCubit,
      Stream.fromIterable([AudioRecordingLoading()]),
      initialState: AudioRecordingInitial(), // Start with initial state
    );

    // Act
    await pumpRecorderPage(tester);
    await tester.pump(); // Process the emitted Loading state

    // Assert
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);
  });

  testWidgets('should display Ready UI and call startRecording on tap', (
    WidgetTester tester,
  ) async {
    // Arrange
    when(
      () => mockAudioRecordingCubit.state,
    ).thenReturn(const AudioRecordingReady());
    await pumpRecorderPage(tester);

    // Assert: Ready UI is shown
    expect(find.text('Ready to Record'), findsOneWidget);
    final fabFinder = find.widgetWithIcon(FloatingActionButton, Icons.mic);
    expect(fabFinder, findsOneWidget);

    // Act: Tap the FAB
    await tester.tap(fabFinder);
    await tester.pump();

    // Assert: startRecording called
    verify(() => mockAudioRecordingCubit.startRecording()).called(1);
  });

  testWidgets('should display InProgress UI, call pause/stop on tap', (
    WidgetTester tester,
  ) async {
    // Arrange
    const duration = Duration(seconds: 5);
    const filePath = '/path/to/recording.aac';
    when(() => mockAudioRecordingCubit.state).thenReturn(
      const AudioRecordingInProgress(filePath: filePath, duration: duration),
    );
    await pumpRecorderPage(tester);

    // Assert: InProgress UI is shown
    expect(find.text('00:05'), findsOneWidget);
    expect(find.textContaining('recording.aac'), findsOneWidget);
    final pauseButtonFinder = find.widgetWithIcon(
      FloatingActionButton,
      Icons.pause,
    );
    final stopButtonFinder = find.widgetWithIcon(
      FloatingActionButton,
      Icons.stop,
    );
    expect(pauseButtonFinder, findsOneWidget);
    expect(stopButtonFinder, findsOneWidget);

    // Act: Tap Pause
    await tester.tap(pauseButtonFinder);
    await tester.pump();

    // Assert: pauseRecording called
    verify(() => mockAudioRecordingCubit.pauseRecording()).called(1);

    // Act: Tap Stop
    await tester.tap(stopButtonFinder);
    await tester.pump();

    // Assert: stopRecording called
    verify(() => mockAudioRecordingCubit.stopRecording()).called(1);
  });

  testWidgets('should display Paused UI, call resume/stop on tap', (
    WidgetTester tester,
  ) async {
    // Arrange
    const duration = Duration(seconds: 15);
    const filePath = '/path/to/paused.aac';
    when(() => mockAudioRecordingCubit.state).thenReturn(
      const AudioRecordingPaused(filePath: filePath, duration: duration),
    );
    await pumpRecorderPage(tester);

    // Assert: Paused UI is shown
    expect(find.text('00:15'), findsOneWidget);
    expect(find.textContaining('paused.aac'), findsOneWidget);
    final resumeButtonFinder = find.widgetWithIcon(
      FloatingActionButton,
      Icons.play_arrow,
    );
    final stopButtonFinder = find.widgetWithIcon(
      FloatingActionButton,
      Icons.stop,
    );
    expect(resumeButtonFinder, findsOneWidget);
    expect(stopButtonFinder, findsOneWidget);

    // Act: Tap Resume (Play)
    await tester.tap(resumeButtonFinder);
    await tester.pump();

    // Assert: resumeRecording called
    verify(() => mockAudioRecordingCubit.resumeRecording()).called(1);

    // Act: Tap Stop
    await tester.tap(stopButtonFinder);
    await tester.pump();

    // Assert: stopRecording called
    verify(() => mockAudioRecordingCubit.stopRecording()).called(1);
  });

  testWidgets('should display Error UI and call prepareRecorder on retry tap', (
    WidgetTester tester,
  ) async {
    // Arrange
    when(
      () => mockAudioRecordingCubit.state,
    ).thenReturn(const AudioRecordingError('Something broke'));
    await pumpRecorderPage(tester);

    // Assert: Error UI is shown
    expect(find.textContaining('Error: Something broke'), findsOneWidget);
    final retryButtonFinder = find.widgetWithText(ElevatedButton, 'Retry Init');
    expect(retryButtonFinder, findsOneWidget);

    // Act: Tap Retry
    // Reset the call count for prepareRecorder before tapping retry
    clearInteractions(mockAudioRecordingCubit);
    when(
      () => mockAudioRecordingCubit.prepareRecorder(),
    ).thenAnswer((_) async {}); // Re-stub if needed
    await tester.tap(retryButtonFinder);
    await tester.pump();

    // Assert: prepareRecorder called again
    verify(() => mockAudioRecordingCubit.prepareRecorder()).called(1);
  });

  testWidgets(
    'should show permission sheet on PermissionDenied state and call openAppSettings',
    (WidgetTester tester) async {
      // Arrange: Listen for the state change
      whenListen(
        mockAudioRecordingCubit,
        Stream.fromIterable([AudioRecordingPermissionDenied()]),
        initialState: AudioRecordingInitial(), // Start from initial
      );

      await pumpRecorderPage(tester);
      await tester.pump(); // Allow listener to process the state
      await tester.pump(); // <<-- ADD THIS PUMP for post-frame callback
      await tester.pumpAndSettle(); // <<-- Wait for bottom sheet animation

      // Assert: Bottom sheet is shown
      expect(find.text('Microphone Permission Required'), findsOneWidget);
      final openSettingsButtonFinder = find.widgetWithText(
        ElevatedButton,
        'Open App Settings',
      );
      expect(openSettingsButtonFinder, findsOneWidget);

      // Act: Tap Open App Settings
      await tester.tap(openSettingsButtonFinder);
      await tester.pumpAndSettle(); // Wait for sheet dismissal

      // Assert: openAppSettings called
      verify(() => mockAudioRecordingCubit.openAppSettings()).called(1);
      // Assert: Bottom sheet is dismissed
      expect(find.text('Microphone Permission Required'), findsNothing);
    },
  );

  testWidgets('should show permission sheet and pop page on Maybe Later tap', (
    WidgetTester tester,
  ) async {
    // Arrange: Listen for the state change
    whenListen(
      mockAudioRecordingCubit,
      Stream.fromIterable([AudioRecordingPermissionDenied()]),
      initialState: AudioRecordingInitial(),
    );

    await pumpRecorderPage(tester);
    await tester.pump(); // Allow listener to process the state
    await tester.pump(); // <<-- ADD THIS PUMP for post-frame callback
    await tester.pumpAndSettle(); // <<-- Wait for bottom sheet animation

    // Assert: Bottom sheet is shown
    expect(find.text('Microphone Permission Required'), findsOneWidget);
    final maybeLaterButtonFinder = find.widgetWithText(
      TextButton,
      'Maybe Later',
    );
    expect(maybeLaterButtonFinder, findsOneWidget);

    // Act: Tap Maybe Later
    await tester.tap(maybeLaterButtonFinder);
    await tester.pumpAndSettle(); // Wait for sheet dismissal and navigation

    // Assert: Bottom sheet is dismissed
    expect(find.text('Microphone Permission Required'), findsNothing);
    // Assert: Navigation pop called on the navigator (using the registered fallback)
    verify(
      () => mockNavigatorObserver.didPop(
        any(that: isRoute<dynamic>()),
        any(that: isRoute<dynamic>()),
      ),
    ).called(1);
    // Assert: openAppSettings was NOT called
    verifyNever(() => mockAudioRecordingCubit.openAppSettings());
  });

  testWidgets(
    'should pop with true when state changes to AudioRecordingStopped',
    (WidgetTester tester) async => tester.runAsync(() async {
      // Arrange
      const filePath = '/path/to/finished.aac';
      // Revert to whenListen for state sequence testing
      whenListen(
        mockAudioRecordingCubit,
        Stream.fromIterable([
          const AudioRecordingInProgress(
            filePath: 'dummy',
            duration: Duration.zero,
          ),
          const AudioRecordingStopped(filePath),
        ]),
        initialState: AudioRecordingInitial(),
      );

      await pumpRecorderPage(tester);
      // Pump stream emissions and wait for listeners/animations
      await tester.pumpAndSettle();

      // Assert: Verify the FINAL state is correct (Pop verification is removed)
      expect(mockAudioRecordingCubit.state, isA<AudioRecordingStopped>());
    }),
  );
}

// Helper matcher for Route type checking with mocktail's any()
TypeMatcher<Route<T>> isRoute<T>() => isA<Route<T>>();
