import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
// Import app_theme.dart for theme
import 'package:flutter/material.dart';
// Add Cupertino import
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart'; // Use mockito
import 'package:mockito/annotations.dart'; // For annotations

// Import test helpers
import '../test_helpers/job_list_test_helpers.dart' as helpers;

// Import the generated mocks file
import 'job_list_page_test.mocks.dart';

// Mocks
@GenerateMocks([JobListCubit]) // Use mockito annotation
void main() {
  late MockJobListCubit mockJobListCubit;

  setUp(() {
    mockJobListCubit = MockJobListCubit();
    // Use mockito's `when` for stubbing stream and state
    when(
      mockJobListCubit.stream,
    ).thenAnswer((_) => Stream.value(const JobListInitial()));
    when(
      mockJobListCubit.state,
    ).thenReturn(const JobListInitial()); // Default state
  });

  // Local helper to create test widget using the helpers module
  Widget createWidget() {
    return helpers.createTestWidget(mockJobListCubit: mockJobListCubit);
  }

  group('JobListPage', () {
    testWidgets(
      'renders CircularProgressIndicator when state is JobListLoading',
      (WidgetTester tester) async {
        // Arrange: Stub the cubit's stream to emit the loading state
        when(
          mockJobListCubit.stream,
        ).thenAnswer((_) => Stream.value(const JobListLoading()));
        when(mockJobListCubit.state).thenReturn(
          const JobListLoading(),
        ); // Set state directly for initial build check

        // Act: Pump the widget
        await tester.pumpWidget(createWidget());

        // Assert: Verify the loading indicator is present
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Assert: Verify no list or error message is shown
        expect(find.byType(ListView), findsNothing);
        expect(
          find.textContaining('Error'),
          findsNothing,
        ); // Generic error check
        expect(
          find.textContaining('No jobs'),
          findsNothing,
        ); // Empty state check
      },
    );

    testWidgets(
      'renders "No jobs yet" message when state is JobListLoaded with empty list',
      (WidgetTester tester) async {
        // Arrange: Stub the cubit to emit JobListLoaded with an empty list
        when(
          mockJobListCubit.stream,
        ).thenAnswer((_) => Stream.value(const JobListLoaded([])));
        when(
          mockJobListCubit.state,
        ).thenReturn(const JobListLoaded([])); // Set state directly

        // Act: Pump the widget
        await tester.pumpWidget(createWidget());

        // Assert: Verify the "No jobs yet" message is present
        expect(find.text('No jobs yet.'), findsOneWidget);
        // Assert: Verify loading indicator is not present
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // Assert: Verify ListView is not present
        expect(find.byType(ListView), findsNothing);
        // Assert: Verify no error message is shown
        expect(find.textContaining('Error'), findsNothing);
      },
    );

    testWidgets(
      'renders ListView with job items when state is JobListLoaded with data',
      (WidgetTester tester) async {
        // Arrange: Create sample job view models
        final viewModels = [
          JobViewModel(
            localId: '11111111-aaaa-bbbb-cccc-dddddddddddd',
            title: 'Job 1 Title',
            text: 'Full text for Job 1',
            syncStatus: SyncStatus.synced,
            hasFileIssue: false,
            displayDate: DateTime(2023, 10, 26, 10, 0, 0),
          ),
          JobViewModel(
            localId: '22222222-eeee-ffff-gggg-hhhhhhhhhhhh',
            title: 'Job 2 Title - Pending',
            text: 'Full text for Job 2',
            syncStatus: SyncStatus.pending,
            hasFileIssue: true,
            displayDate: DateTime(2023, 10, 26, 11, 30, 0),
          ),
        ];

        // Arrange: Stub the cubit with the real ViewModel list type
        when(
          mockJobListCubit.stream,
        ).thenAnswer((_) => Stream.value(JobListLoaded(viewModels)));
        when(
          mockJobListCubit.state,
        ).thenReturn(JobListLoaded(viewModels)); // Set state directly

        // Act: Pump the widget
        await tester.pumpWidget(createWidget());

        // Assert: Verify ListView is present
        expect(find.byType(ListView), findsOneWidget);
        // Assert: Verify list items are present (check for titles)
        expect(find.text('Job 1 Title'), findsOneWidget); // Check the title
        expect(
          find.text('Job 2 Title - Pending'),
          findsOneWidget,
        ); // Check the title

        // Assert: Verify other states' widgets are not present
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('No jobs yet.'), findsNothing);
        expect(find.textContaining('Error'), findsNothing);
      },
    );

    // Test for Error State
    testWidgets('renders error message when state is JobListError', (
      WidgetTester tester,
    ) async {
      // Arrange: Define the error message
      const String errorMessage = 'Failed to load jobs';

      // Arrange: Stub the cubit
      when(
        mockJobListCubit.stream,
      ).thenAnswer((_) => Stream.value(const JobListError(errorMessage)));
      when(
        mockJobListCubit.state,
      ).thenReturn(const JobListError(errorMessage)); // Set state directly

      // Act: Pump the widget
      await tester.pumpWidget(createWidget());

      // Assert: Verify the error message is present
      expect(find.text(errorMessage), findsOneWidget);
      // Assert: Verify other states' widgets are not present
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ListView), findsNothing);
      expect(find.text('No jobs yet.'), findsNothing);
    });
  });

  // Note: We need to create a more simplified test for offline functionality
  // that doesn't rely on complex provider overrides. Will add separately.
}
