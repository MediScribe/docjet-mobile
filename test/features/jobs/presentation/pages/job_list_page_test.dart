import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/pages/job_list_page.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Add Cupertino import
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart'; // Use mockito
import 'package:mockito/annotations.dart'; // For annotations

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

  Widget createTestWidget() {
    return MaterialApp(
      home: BlocProvider<JobListCubit>.value(
        value: mockJobListCubit,
        child: const JobListPage(), // The page we will create
      ),
    );
  }

  group('JobListPage', () {
    testWidgets(
      'renders CupertinoActivityIndicator when state is JobListLoading',
      (WidgetTester tester) async {
        // Arrange: Stub the cubit's stream to emit the loading state
        when(
          mockJobListCubit.stream,
        ).thenAnswer((_) => Stream.value(const JobListLoading()));
        when(mockJobListCubit.state).thenReturn(
          const JobListLoading(),
        ); // Set state directly for initial build check

        // Act: Pump the widget
        await tester.pumpWidget(createTestWidget());
        // No need for extra pump when state is set directly before pumpWidget

        // Assert: Verify the loading indicator is present
        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
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
        await tester.pumpWidget(createTestWidget());

        // Assert: Verify the "No jobs yet" message is present
        expect(find.text('No jobs yet.'), findsOneWidget);
        // Assert: Verify loading indicator is not present
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        // Assert: Verify ListView is not present
        expect(find.byType(ListView), findsNothing);
        // Assert: Verify no error message is shown
        expect(find.textContaining('Error'), findsNothing);
      },
    );

    testWidgets(
      'renders ListView with job items when state is JobListLoaded with data',
      (WidgetTester tester) async {
        // Arrange: Create REAL view models
        final viewModels = [
          JobViewModel(
            localId: '11111111-aaaa-bbbb-cccc-dddddddddddd', // Use longer ID
            title: 'Job 1 Title', // Use the new title field
            text: 'Full text for Job 1',
            syncStatus: SyncStatus.synced,
            hasFileIssue: false,
            displayDate: DateTime(2023, 10, 26, 10, 0, 0),
          ),
          JobViewModel(
            localId: '22222222-eeee-ffff-gggg-hhhhhhhhhhhh', // Use longer ID
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
        await tester.pumpWidget(createTestWidget());

        // Assert: Verify ListView is present
        expect(find.byType(ListView), findsOneWidget);
        // Assert: Verify list items are present (check for titles)
        expect(find.text('Job 1 Title'), findsOneWidget); // Check the title
        expect(
          find.text('Job 2 Title - Pending'),
          findsOneWidget,
        ); // Check the title
        // Optionally, check for status or other details if rendered
        // expect(find.text('Synced'), findsOneWidget);

        // Assert: Verify other states' widgets are not present
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        expect(find.text('No jobs yet.'), findsNothing);
        expect(find.textContaining('Error'), findsNothing);
      },
    );

    // Test for Error State
    testWidgets('renders error message when state is JobListError', (
      WidgetTester tester,
    ) async {
      // Arrange: Define the error message
      const String errorMessage = 'Failed to load jobs, fuck!';

      // Arrange: Stub the cubit
      when(
        mockJobListCubit.stream,
      ).thenAnswer((_) => Stream.value(const JobListError(errorMessage)));
      when(
        mockJobListCubit.state,
      ).thenReturn(const JobListError(errorMessage)); // Set state directly

      // Act: Pump the widget
      await tester.pumpWidget(createTestWidget());

      // Assert: Verify the error message is present
      expect(find.text(errorMessage), findsOneWidget);
      // Assert: Verify other states' widgets are not present
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.byType(ListView), findsNothing);
      expect(find.text('No jobs yet.'), findsNothing);
    });

    testWidgets('displays warning icon for jobs with file issues', (
      WidgetTester tester,
    ) async {
      // Arrange: Create ViewModels - one with file issue, one without
      final viewModels = [
        JobViewModel(
          localId: '11111111-aaaa-bbbb-cccc-dddddddddddd',
          title: 'Job without issues',
          text: 'No file issues here',
          syncStatus: SyncStatus.synced,
          hasFileIssue: false, // No file issues
          displayDate: DateTime(2023, 10, 26, 10, 0, 0),
        ),
        JobViewModel(
          localId: '22222222-eeee-ffff-gggg-hhhhhhhhhhhh',
          title: 'Job with file issues',
          text: 'Has file deletion issues',
          syncStatus: SyncStatus.synced,
          hasFileIssue: true, // Has file issues
          displayDate: DateTime(2023, 10, 26, 11, 30, 0),
        ),
      ];

      // Arrange: Stub the cubit
      when(
        mockJobListCubit.stream,
      ).thenAnswer((_) => Stream.value(JobListLoaded(viewModels)));
      when(mockJobListCubit.state).thenReturn(JobListLoaded(viewModels));

      // Act: Pump the widget
      await tester.pumpWidget(createTestWidget());

      // Assert: Find all icons in the list
      final warningIcons = find.byIcon(
        CupertinoIcons.exclamationmark_triangle_fill,
      );
      final normalIcons = find.byIcon(CupertinoIcons.doc_text);

      // Should be exactly one of each icon type
      expect(
        warningIcons,
        findsOneWidget,
        reason: 'Should find warning icon for job with file issue',
      );
      expect(
        normalIcons,
        findsOneWidget,
        reason: 'Should find article icon for job without file issue',
      );

      // Verify they're associated with the correct list items
      expect(
        find.widgetWithText(ListTile, 'Job with file issues'),
        findsOneWidget,
        reason: 'Should find ListTile with title "Job with file issues"',
      );

      expect(
        find.widgetWithText(ListTile, 'Job without issues'),
        findsOneWidget,
        reason: 'Should find ListTile with title "Job without issues"',
      );

      // Find tiles containing specific text
      final tileWithIssues =
          find
                  .widgetWithText(ListTile, 'Job with file issues')
                  .evaluate()
                  .first
                  .widget
              as ListTile;
      final tileWithoutIssues =
          find
                  .widgetWithText(ListTile, 'Job without issues')
                  .evaluate()
                  .first
                  .widget
              as ListTile;

      // Verify icons are correct
      expect(
        tileWithIssues.leading,
        isA<Icon>().having(
          (icon) => (icon).icon,
          'icon data',
          equals(CupertinoIcons.exclamationmark_triangle_fill),
        ),
        reason: 'ListTile with issues should have warning icon',
      );

      expect(
        tileWithoutIssues.leading,
        isA<Icon>().having(
          (icon) => (icon).icon,
          'icon data',
          equals(CupertinoIcons.doc_text),
        ),
        reason: 'ListTile without issues should have article icon',
      );
    });
  });
}
