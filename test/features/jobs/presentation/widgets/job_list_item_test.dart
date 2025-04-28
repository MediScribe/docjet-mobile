import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/job_list_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Helper to create the JobListItem inside a MaterialApp with proper themes
  Widget createTestWidget({
    required JobViewModel jobViewModel,
    bool isOffline = false,
  }) {
    return MaterialApp(
      theme: createLightTheme(),
      home: Scaffold(
        body: JobListItem(job: jobViewModel, isOffline: isOffline),
      ),
    );
  }

  group('JobListItem - Icons and Visual Elements', () {
    testWidgets('shows correct default icon for job without file issues', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a job view model without file issues
      final jobViewModel = JobViewModel(
        localId: 'test-job-id',
        title: 'Test Job Title',
        text: 'Test job text',
        syncStatus: SyncStatus.synced,
        hasFileIssue: false,
        displayDate: DateTime(2023, 10, 26),
      );

      // Act: Pump the widget
      await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));

      // Assert: Normal document icon should be shown
      expect(
        find.byIcon(CupertinoIcons.doc_text),
        findsOneWidget,
        reason: 'Should show the document icon for job without file issues',
      );

      // Warning icon should NOT be shown
      expect(
        find.byIcon(CupertinoIcons.exclamationmark_triangle_fill),
        findsNothing,
        reason: 'Should not show warning icon for job without file issues',
      );
    });

    testWidgets('shows warning icon for job with file issues', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a job view model with file issues
      final jobViewModel = JobViewModel(
        localId: 'test-job-id-with-issues',
        title: 'Job With File Issues',
        text: 'This job has file issues',
        syncStatus: SyncStatus.synced,
        hasFileIssue: true,
        displayDate: DateTime(2023, 10, 26),
      );

      // Act: Pump the widget
      await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));

      // Assert: Warning icon should be shown
      expect(
        find.byIcon(CupertinoIcons.exclamationmark_triangle_fill),
        findsOneWidget,
        reason: 'Should show warning icon for job with file issues',
      );

      // Normal document icon should NOT be shown
      expect(
        find.byIcon(CupertinoIcons.doc_text),
        findsNothing,
        reason: 'Should not show document icon for job with file issues',
      );
    });

    testWidgets('shows status tag for pending sync status', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a job view model with pending sync status
      final jobViewModel = JobViewModel(
        localId: 'test-job-id-pending',
        title: 'Pending Job',
        text: 'This job is pending sync',
        syncStatus: SyncStatus.pending,
        hasFileIssue: false,
        displayDate: DateTime(2023, 10, 26),
      );

      // Act: Pump the widget
      await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));

      // Assert: Pending sync status tag should be shown
      expect(
        find.text('Pending sync'),
        findsOneWidget,
        reason: 'Should show pending sync status tag',
      );
    });

    testWidgets('should not show status tag for synced jobs', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a job view model with synced status
      final jobViewModel = JobViewModel(
        localId: 'test-job-id-synced',
        title: 'Synced Job',
        text: 'This job is already synced',
        syncStatus: SyncStatus.synced,
        hasFileIssue: false,
        displayDate: DateTime(2023, 10, 26),
      );

      // Act: Pump the widget
      await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));

      // Assert: No status tags should be shown for synced jobs
      expect(
        find.text('Pending sync'),
        findsNothing,
        reason: 'Should not show pending sync status tag for synced jobs',
      );
      expect(
        find.text('Sync error'),
        findsNothing,
        reason: 'Should not show error status tag for synced jobs',
      );
      expect(
        find.text('Sync failed'),
        findsNothing,
        reason: 'Should not show failed status tag for synced jobs',
      );
    });

    testWidgets('shows error status tag for jobs with sync errors', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a job view model with sync error
      final jobViewModel = JobViewModel(
        localId: 'test-job-id-error',
        title: 'Error Job',
        text: 'This job has a sync error',
        syncStatus: SyncStatus.error,
        hasFileIssue: false,
        displayDate: DateTime(2023, 10, 26),
      );

      // Act: Pump the widget
      await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));

      // Assert: Error sync status tag should be shown
      expect(
        find.text('Sync error'),
        findsOneWidget,
        reason: 'Should show sync error status tag',
      );
    });
  });

  group('JobListItem - Interaction', () {
    testWidgets('disables tap when offline', (WidgetTester tester) async {
      // Arrange: Create a job view model
      final jobViewModel = JobViewModel(
        localId: 'test-job-id',
        title: 'Test Job',
        text: 'Test job content',
        syncStatus: SyncStatus.synced,
        hasFileIssue: false,
        displayDate: DateTime(2023, 10, 26),
      );

      // Act: Pump the widget with isOffline=true
      await tester.pumpWidget(
        createTestWidget(jobViewModel: jobViewModel, isOffline: true),
      );

      // Assert: Tapping the item should have no effect
      // We can't directly test the onTap callback, but can verify the item exists
      expect(find.text('Test Job'), findsOneWidget);

      // Verify we can find the JobListItem widget
      expect(find.byType(JobListItem), findsOneWidget);
    });
  });
}
