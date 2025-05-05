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
    ValueChanged<JobViewModel>? onTapJob,
  }) {
    return MaterialApp(
      theme: createLightTheme(),
      home: Scaffold(
        body: JobListItem(
          job: jobViewModel,
          isOffline: isOffline,
          onTapJob: onTapJob,
        ),
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

    testWidgets('calls onTapJob when item is tapped', (
      WidgetTester tester,
    ) async {
      // Arrange: Create job and callback
      bool callbackCalled = false;
      JobViewModel? callbackJob;

      final jobViewModel = JobViewModel(
        localId: 'callback-test-job',
        title: 'Callback Test',
        text: 'This job tests the callback',
        syncStatus: SyncStatus.synced,
        jobStatus: JobStatus.submitted,
        hasFileIssue: false,
        displayDate: DateTime.now(),
      );

      // Callback function that tracks being called
      void onTapCallback(JobViewModel job) {
        callbackCalled = true;
        callbackJob = job;
      }

      // Act: Pump widget with callback and tap it
      await tester.pumpWidget(
        createTestWidget(jobViewModel: jobViewModel, onTapJob: onTapCallback),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pump();

      // Assert: Callback should be called with the job
      expect(callbackCalled, isTrue, reason: 'Callback should be called');
      expect(
        callbackJob?.localId,
        equals('callback-test-job'),
        reason: 'Callback should receive the job',
      );
    });
  });

  group('JobListItem - Progress Bar', () {
    testWidgets(
      'should display LinearProgressIndicator with correct value for completed status',
      (WidgetTester tester) async {
        // Arrange
        final jobViewModel = JobViewModel(
          localId: 'job-completed',
          title: 'Completed Job',
          text: '',
          syncStatus: SyncStatus.synced,
          jobStatus: JobStatus.completed, // Status under test
          hasFileIssue: false,
          displayDate: DateTime.now(),
        );
        await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));

        // Act
        final progressBarFinder = find.byType(LinearProgressIndicator);

        // Assert
        expect(
          progressBarFinder,
          findsOneWidget,
          reason: 'Should find a LinearProgressIndicator',
        );
        final progressBar = tester.widget<LinearProgressIndicator>(
          progressBarFinder,
        );
        expect(
          progressBar.value,
          1.0,
          reason: 'Progress should be 1.0 for completed status',
        );
        // Assuming default green for completed - will add color test
      },
    );

    testWidgets(
      'should display LinearProgressIndicator with correct value and color for transcribing status',
      (WidgetTester tester) async {
        // Arrange
        final jobViewModel = JobViewModel(
          localId: 'job-transcribing',
          title: 'Transcribing Job',
          text: '',
          syncStatus: SyncStatus.synced,
          jobStatus: JobStatus.transcribing, // Status under test
          hasFileIssue: false,
          displayDate: DateTime.now(),
        );
        await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));
        final appColors = getAppColors(tester.element(find.byType(Scaffold)));

        // Act
        final progressBarFinder = find.byType(LinearProgressIndicator);

        // Assert
        expect(progressBarFinder, findsOneWidget);
        final progressBar = tester.widget<LinearProgressIndicator>(
          progressBarFinder,
        );
        expect(
          progressBar.value,
          0.3, // Based on our mapping
          reason: 'Progress should be 0.3 for transcribing status',
        );
        expect(
          progressBar.color,
          appColors.successFg, // Use theme SUCCESS color
          reason: 'Progress bar color should be the theme success color',
        );
        expect(
          progressBar.backgroundColor,
          appColors.outlineColor, // Use theme OUTLINE color
          reason: 'Progress bar background should be the theme outline color',
        );
      },
    );

    testWidgets(
      'should display LinearProgressIndicator with correct value and RED color for error status (previously generating)',
      (WidgetTester tester) async {
        // Arrange - *Simulating error occurred after generating*
        // NOTE: We need a way to represent the 'previous' status for error,
        // or the ViewModel needs to provide the progress value directly.
        // For now, we test the expected outcome assuming this logic exists.
        // Let's assume the ViewModel holds 'last known progress before error'
        // or the mapping logic handles JobStatus.error specifically.
        // We'll test the RED color and a plausible progress value (0.7 for generating)
        final jobViewModel = JobViewModel(
          localId: 'job-error',
          title: 'Error Job',
          text: '',
          syncStatus: SyncStatus.synced,
          jobStatus: JobStatus.error, // Status under test
          // We'll need to adjust the ViewModel or mapping later if needed
          // to correctly pass the pre-error progress value.
          // For testing, we assume the widget receives/calculates 0.7 for an error
          // that occurred after 'generating'.
          hasFileIssue: false,
          displayDate: DateTime.now(),
        );
        await tester.pumpWidget(createTestWidget(jobViewModel: jobViewModel));
        final appColors = getAppColors(tester.element(find.byType(Scaffold)));

        // Act
        final progressBarFinder = find.byType(LinearProgressIndicator);

        // Assert
        expect(progressBarFinder, findsOneWidget);
        final progressBar = tester.widget<LinearProgressIndicator>(
          progressBarFinder,
        );

        // !!! IMPORTANT: This assumes the widget/mapper calculates 0.7 for error after generating !!!
        expect(
          progressBar.value,
          0.7,
          reason:
              'Progress should reflect state before error (e.g., 0.7 if error after generating)',
        );
        expect(
          progressBar.color,
          appColors.dangerFg, // Use theme DANGER color
          reason:
              'Progress bar color should be the theme danger color for error status',
        );
        expect(
          progressBar.backgroundColor,
          appColors.outlineColor, // Use theme OUTLINE color
          reason:
              'Progress bar background should still be the theme outline color',
        );
      },
    );
  });
}
