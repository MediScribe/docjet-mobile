import 'package:bloc_test/bloc_test.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_state.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_state.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/pages/audio_recorder_list_page.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/pages/audio_recorder_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/services.dart'; // Import for Services

// Mocks
class MockAudioListCubit extends MockCubit<AudioListState>
    implements AudioListCubit {}

class MockAudioRecordingCubit extends MockCubit<AudioRecordingState>
    implements AudioRecordingCubit {}

// Mock Navigator Observer if needed for navigation verification
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

// Mock AudioRecord for testing data
final tAudioRecord1 = AudioRecord(
  filePath: '/path/to/recording1.aac',
  duration: const Duration(seconds: 10),
  createdAt: DateTime(2023, 1, 1, 10, 0, 0),
);
final tAudioRecord2 = AudioRecord(
  filePath: '/path/to/recording2.aac',
  duration: const Duration(seconds: 25),
  createdAt: DateTime(2023, 1, 1, 10, 5, 0),
);
final tAudioRecordings = [tAudioRecord1, tAudioRecord2];

void main() {
  late MockAudioListCubit mockAudioListCubit;
  late MockAudioRecordingCubit mockAudioRecordingCubit;
  late GetIt sl;

  // Ensure TestWidgetsFlutterBinding is initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeRoute<dynamic>());
  });

  setUp(() async {
    // Mock the audioplayers platform channel BEFORE initializing GetIt/Cubits
    const MethodChannel channel = MethodChannel('xyz.luan/audioplayers');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          // Return null or default values for common methods called by the plugin
          // during initialization or basic operations within the widget tests.
          // We don't need specific behavior, just prevent crashes.
          // print('Mock Audioplayers Channel: ${methodCall.method}');
          if (methodCall.method == 'create') {
            return 1; // Must return an int for create
          }
          return null;
        });

    // Reset GetIt before each test
    sl = GetIt.instance;
    sl.reset();

    mockAudioListCubit = MockAudioListCubit();
    mockAudioRecordingCubit =
        MockAudioRecordingCubit(); // Needed for navigation mock

    // Stub the initial states
    when(() => mockAudioListCubit.state).thenReturn(AudioListInitial());
    when(
      () => mockAudioRecordingCubit.state,
    ).thenReturn(AudioRecordingInitial()); // Initial state for recording cubit

    // Register mocks in GetIt
    sl.registerFactory<AudioListCubit>(() => mockAudioListCubit);
    sl.registerFactory<AudioRecordingCubit>(() => mockAudioRecordingCubit);

    // Stub the prepareRecorder method which is called during navigation
    when(
      () => mockAudioRecordingCubit.prepareRecorder(),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    // Clear the mock handler after each test
    const MethodChannel channel = MethodChannel('xyz.luan/audioplayers');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    // Close the cubits after each test
    mockAudioListCubit.close();
    mockAudioRecordingCubit.close();
    sl.reset(); // Clean up GetIt
  });

  // Helper function to pump the widget tree
  Future<void> pumpListPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AudioListCubit>.value(
          value: mockAudioListCubit,
          child: const AudioRecorderListPage(), // Use the outer StatelessWidget
        ),
        // Register mock navigator observer if needed later
        // navigatorObservers: [mockNavigatorObserver],
      ),
    );
  }

  testWidgets(
    'should display loading indicator when state is AudioListLoading',
    (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioListCubit.state).thenReturn(AudioListLoading());

      // Act
      await pumpListPage(tester);

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'should display message when state is AudioListLoaded with empty list',
    (WidgetTester tester) async {
      // Arrange
      when(
        () => mockAudioListCubit.state,
      ).thenReturn(const AudioListLoaded([]));

      // Act
      await pumpListPage(tester);
      await tester.pump(); // Ensure state change is reflected

      // Assert
      expect(
        find.text('No recordings yet. Tap + to start recording.'),
        findsOneWidget,
      );
      expect(find.byType(ListView), findsNothing);
    },
  );

  testWidgets(
    'should display ListView when state is AudioListLoaded with recordings',
    (WidgetTester tester) async => tester.runAsync(() async {
      // Arrange
      // Ensure recordings are sorted descending by createdAt for consistent testing
      final sortedRecordings = List<AudioRecord>.from(tAudioRecordings)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      when(
        () => mockAudioListCubit.state,
      ).thenReturn(AudioListLoaded(sortedRecordings));

      // Act
      await pumpListPage(tester);
      await tester.pump(); // Ensure state change is reflected

      // Assert
      expect(find.byType(ListView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(ListTile),
        ),
        findsNWidgets(sortedRecordings.length),
      );
      // Verify the first item displayed is the newest one (tAudioRecord2)
      expect(find.textContaining('recording2.aac'), findsOneWidget);
      expect(find.text('Duration: 00:25'), findsOneWidget); // Exact match
      // Verify the second item displayed is the older one (tAudioRecord1)
      expect(find.textContaining('recording1.aac'), findsOneWidget);
      expect(find.text('Duration: 00:10'), findsOneWidget); // Exact match
    }),
  );

  testWidgets(
    'should display error message and retry button when state is AudioListError',
    (WidgetTester tester) async {
      // Arrange
      when(
        () => mockAudioListCubit.state,
      ).thenReturn(const AudioListError('Failed to load'));

      // Act
      await pumpListPage(tester);
      await tester.pump(); // Ensure state change is reflected

      // Assert
      expect(
        find.textContaining('Error loading recordings: Failed to load'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, 'Retry Loading'),
        findsOneWidget,
      );

      // Act: Tap retry button
      when(
        () => mockAudioListCubit.loadRecordings(),
      ).thenAnswer((_) async {}); // Stub the method call
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry Loading'));
      await tester.pump();

      // Assert: Verify loadRecordings was called
      verify(() => mockAudioListCubit.loadRecordings()).called(1);
    },
  );

  testWidgets(
    'tapping FAB navigates to AudioRecorderPage and refreshes list on return true',
    (WidgetTester tester) async {
      // Arrange: Start in a loaded state so FAB is present
      when(
        () => mockAudioListCubit.state,
      ).thenReturn(const AudioListLoaded([]));
      when(
        () => mockAudioListCubit.loadRecordings(),
      ).thenAnswer((_) async {}); // Stub loadRecordings

      await pumpListPage(tester);
      await tester.pump(); // Ensure state is stable

      // Act: Find and tap the FAB
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
      await tester.tap(fabFinder);
      await tester.pump(); // Allow navigation push animation to start
      await tester.pump(); // Allow navigation push animation to complete

      // Assert: Verify navigation occurred
      // We expect AudioRecorderPage to be pushed
      expect(find.byType(AudioRecorderPage), findsOneWidget);

      // Simulate popping from AudioRecorderPage with result 'true'
      Navigator.of(tester.element(find.byType(AudioRecorderPage))).pop(true);
      await tester.pump(); // Allow navigation pop animation to start
      await tester.pump(); // Allow navigation pop animation to complete

      // Assert: Verify AudioRecorderPage is gone
      expect(find.byType(AudioRecorderPage), findsNothing);
      // Assert: Verify loadRecordings was called because result was true
      verify(() => mockAudioListCubit.loadRecordings()).called(1);
    },
  );

  testWidgets(
    'tapping FAB navigates to AudioRecorderPage and DOES NOT refresh list on return false/null',
    (WidgetTester tester) async {
      // Arrange: Start in a loaded state so FAB is present
      when(
        () => mockAudioListCubit.state,
      ).thenReturn(const AudioListLoaded([]));
      when(
        () => mockAudioListCubit.loadRecordings(),
      ).thenAnswer((_) async {}); // Stub loadRecordings

      await pumpListPage(tester);
      await tester.pump(); // Ensure state is stable

      // Act: Find and tap the FAB
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
      await tester.tap(fabFinder);
      await tester.pump(); // Allow navigation push animation to start
      await tester.pump(); // Allow navigation push animation to complete

      // Assert: Verify navigation occurred
      expect(find.byType(AudioRecorderPage), findsOneWidget);

      // Simulate popping from AudioRecorderPage with result 'false'
      Navigator.of(tester.element(find.byType(AudioRecorderPage))).pop(false);
      await tester.pump(); // Allow navigation pop animation to start
      await tester.pump(); // Allow navigation pop animation to complete

      // Assert: Verify loadRecordings was NOT called
      verifyNever(() => mockAudioListCubit.loadRecordings());

      // Act: Tap FAB again
      await tester.tap(fabFinder);
      await tester.pump(); // Allow navigation push animation to start
      await tester.pump(); // Allow navigation push animation to complete

      // Simulate popping from AudioRecorderPage with result 'null' (e.g., system back)
      Navigator.of(
        tester.element(find.byType(AudioRecorderPage)),
      ).pop(); // Defaults to null
      await tester.pump(); // Allow navigation pop animation to start
      await tester.pump(); // Allow navigation pop animation to complete

      // Assert: Verify loadRecordings was NOT called
      verifyNever(() => mockAudioListCubit.loadRecordings());
    },
  );

  testWidgets('tapping delete action calls deleteRecording', (
    WidgetTester tester,
  ) async {
    // Arrange
    final sortedRecordings = List<AudioRecord>.from(tAudioRecordings)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // t2 is first
    when(
      () => mockAudioListCubit.state,
    ).thenReturn(AudioListLoaded(sortedRecordings));
    when(
      () => mockAudioListCubit.deleteRecording(tAudioRecord2.filePath),
    ).thenAnswer((_) async {});

    // Pump initial widget
    await pumpListPage(tester);
    await tester.pumpAndSettle(); // Settle initial build

    // Act: Find the "more" icon for tAudioRecord2 (should be the first item)
    final record2TileFinder = find.ancestor(
      of: find.textContaining(tAudioRecord2.filePath.split('/').last),
      matching: find.byType(ListTile),
    );
    final moreIconFinder = find.descendant(
      of: record2TileFinder,
      matching: find.byIcon(Icons.more_vert),
    );
    expect(moreIconFinder, findsOneWidget);

    // Tap the more icon
    await tester.tap(moreIconFinder);
    await tester.pumpAndSettle(); // Wait for bottom sheet animation

    // Assert: Verify bottom sheet is shown
    final deleteOptionFinder = find.widgetWithText(
      ListTile,
      'Delete Recording',
    );
    expect(deleteOptionFinder, findsOneWidget);

    // Act: Tap the delete button in the bottom sheet
    await tester.tap(deleteOptionFinder);
    await tester
        .pumpAndSettle(); // Wait for sheet dismissal and potential cubit calls

    // Assert: Verify deleteRecording was called
    verify(
      () => mockAudioListCubit.deleteRecording(tAudioRecord2.filePath),
    ).called(1);
  });
}

class FakeRoute<T> extends Fake implements Route<T> {}

// Helper to initialize GetIt - called from setUp
// This might not be strictly necessary if using sl directly in setUp,
// but can be useful if more complex setup is needed.
// Future<void> initializeGetIt() async {
//   di.sl.reset(); // Ensure clean slate
//   // Register any core dependencies needed by the feature's DI setup if not mocked
//   // Example: sl.registerLazySingleton<SomeCoreService>(() => MockSomeCoreService());
//   // Initialize the specific feature module dependencies
//   // await di.init(); // Assuming your main init calls feature inits
// }
