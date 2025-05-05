import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/job_list_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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

  group('JobListItem - Rendering', () {
    testWidgets('renders job title, text, and formatted date', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a job view model
      final testDate = DateTime(2023, 10, 26, 14, 30);
      final jobViewModel = JobViewModel(
        localId: 'test-job-id',
        title: 'Test Job Title',
        text: 'Test job text',
        syncStatus: SyncStatus.synced,
        jobStatus: JobStatus.completed,
        hasFileIssue: false,
        displayDate: testDate,
      );

      // Act: Pump the widget
      await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));

      // Assert: Job title and date should be displayed
      expect(
        find.text('Test Job Title'),
        findsOneWidget,
        reason: 'Should display job title',
      );

      // Format the date the same way the widget does
      final formattedDate = DateFormat.MMMMd().add_jm().format(testDate);

      // Verify date formatting for a specific date
      expect(
        find.text(formattedDate),
        findsOneWidget,
        reason: 'Should display formatted date for non-today dates',
      );
    });

    testWidgets('displays Today for current day dates', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a job view model with today's date
      final now = DateTime.now();
      final jobViewModel = JobViewModel(
        localId: 'test-job-id-today',
        title: 'Today Job',
        text: 'This job is from today',
        syncStatus: SyncStatus.synced,
        jobStatus: JobStatus.completed,
        hasFileIssue: false,
        displayDate: now,
      );

      // Act: Pump the widget
      await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));

      // Assert: Should display "Today at [time]"
      expect(
        find.textContaining('Today at'),
        findsOneWidget,
        reason: 'Should display "Today at" for current day',
      );
    });

    testWidgets('shows warning icon for jobs with file issues', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a job view model with file issue
      final jobViewModel = JobViewModel(
        localId: 'test-job-id-file-issue',
        title: 'File Issue Job',
        text: 'This job has a file issue',
        syncStatus: SyncStatus.synced,
        jobStatus: JobStatus.completed,
        hasFileIssue: true,
        displayDate: DateTime(2023, 10, 26),
      );

      // Act: Pump the widget
      await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));

      // Assert: Warning icon should be shown
      expect(
        find.byIcon(CupertinoIcons.exclamationmark_triangle_fill),
        findsOneWidget,
        reason: 'Should show warning icon for jobs with file issues',
      );
    });

    testWidgets('shows document icon for normal jobs', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a normal job view model
      final jobViewModel = JobViewModel(
        localId: 'test-job-id-normal',
        title: 'Normal Job',
        text: 'This is a normal job',
        syncStatus: SyncStatus.synced,
        jobStatus: JobStatus.completed,
        hasFileIssue: false,
        displayDate: DateTime(2023, 10, 26),
      );

      // Act: Pump the widget
      await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));

      // Assert: Document icon should be shown
      expect(
        find.byIcon(CupertinoIcons.doc_text),
        findsOneWidget,
        reason: 'Should show document icon for normal jobs',
      );
    });
  });

  group('JobListItem - Interaction', () {
    testWidgets('tapping the item works when online', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a job view model
      final jobViewModel = JobViewModel(
        localId: 'test-job-id',
        title: 'Test Job',
        text: 'Test job text',
        syncStatus: SyncStatus.synced,
        jobStatus: JobStatus.completed,
        hasFileIssue: false,
        displayDate: DateTime(2023, 10, 26),
      );

      // Act: Pump the widget and tap it
      await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));
      await tester.tap(find.byType(ListTile));
      await tester.pump();

      // Assert: The tap should be processed (would need a callback validation in a real test)
      // This test currently just verifies that tapping doesn't crash
    });

    testWidgets('tapping the item is disabled when offline', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a job view model with offline mode
      final jobViewModel = JobViewModel(
        localId: 'test-job-id',
        title: 'Test Job',
        text: 'Test job text',
        syncStatus: SyncStatus.synced,
        jobStatus: JobStatus.completed,
        hasFileIssue: false,
        displayDate: DateTime(2023, 10, 26),
      );

      // Act: Pump the widget in offline mode
      await tester.pumpWidget(
        createTestWidget(jobViewModel: jobViewModel, isOffline: true),
      );

      // Find the ListTile
      final listTile = tester.widget<ListTile>(find.byType(ListTile));

      // Assert: onTap should be null when offline
      expect(
        listTile.onTap,
        isNull,
        reason: 'onTap should be null when offline',
      );
    });
  });
}
