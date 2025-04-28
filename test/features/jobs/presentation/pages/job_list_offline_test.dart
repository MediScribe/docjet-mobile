import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import '../test_helpers/job_list_test_helpers.dart';

// Generate mocks
@GenerateMocks([JobListCubit])
import 'job_list_offline_test.mocks.dart';

void main() {
  late MockJobListCubit mockJobListCubit;

  setUp(() {
    mockJobListCubit = MockJobListCubit();
    // Default state setup
    when(
      mockJobListCubit.stream,
    ).thenAnswer((_) => Stream.value(const JobListInitial()));
    when(mockJobListCubit.state).thenReturn(const JobListInitial());
  });

  group('JobListPage Offline Mode Tests', () {
    testWidgets('shows offline indicator for empty state', (
      WidgetTester tester,
    ) async {
      // Arrange: Set state to loaded with empty list
      when(
        mockJobListCubit.stream,
      ).thenAnswer((_) => Stream.value(const JobListLoaded([])));
      when(mockJobListCubit.state).thenReturn(const JobListLoaded([]));

      // Act: Pump the widget with isOffline=true
      await tester.pumpWidget(
        createTestWidget(mockJobListCubit: mockJobListCubit, isOffline: true),
      );
      await tester.pump();

      // Assert: Empty state message
      expect(find.text('No jobs yet.'), findsOneWidget);

      // Offline message should be visible
      expect(
        find.text('Job creation disabled while offline'),
        findsOneWidget,
        reason: 'Should show the offline message',
      );

      // Create job button should not be shown when offline
      expect(
        find.text('Create Job'),
        findsNothing,
        reason: 'Create Job button should not be visible in offline mode',
      );
    });

    testWidgets('disables job list items when offline', (
      WidgetTester tester,
    ) async {
      // Arrange: Create sample job view models
      final viewModels = [
        JobViewModel(
          localId: 'job1',
          title: 'Test Job 1',
          text: 'Sample job content',
          syncStatus: SyncStatus.synced,
          hasFileIssue: false,
          displayDate: DateTime(2023, 10, 26),
        ),
      ];

      // Set state to loaded with data
      when(
        mockJobListCubit.stream,
      ).thenAnswer((_) => Stream.value(JobListLoaded(viewModels)));
      when(mockJobListCubit.state).thenReturn(JobListLoaded(viewModels));

      // Act: Pump the widget with isOffline=true
      await tester.pumpWidget(
        createTestWidget(mockJobListCubit: mockJobListCubit, isOffline: true),
      );
      await tester.pump();

      // Assert: Jobs should be displayed
      expect(find.text('Test Job 1'), findsOneWidget);

      // Try to tap on the job - should not trigger navigation
      await tester.tap(find.text('Test Job 1'));
      await tester.pump();

      // Verify the widget is still present (we stay on the same page)
      expect(find.byType(TestJobListPage), findsOneWidget);
    });
  });
}
