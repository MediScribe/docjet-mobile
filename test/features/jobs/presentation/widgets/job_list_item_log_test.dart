import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/job_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart';

// Create a logger for test diagnostics
final Logger _testLogger = LoggerFactory.getLogger("JobListItemLogTest");
final String _tag = logTag("JobListItemLogTest");

// Utility to create a sample job view model
JobViewModel createSampleJob({bool hasFileIssue = false}) {
  _testLogger.d('$_tag Creating sample job (hasFileIssue: $hasFileIssue)');
  return JobViewModel(
    localId: '123',
    title: 'Test Job',
    text: 'Sample text',
    syncStatus: SyncStatus.synced,
    jobStatus: JobStatus.completed,
    hasFileIssue: hasFileIssue,
    displayDate: DateTime(2023, 10, 1),
  );
}

void main() {
  group('JobListItem Logging Behavior', () {
    setUp(() {
      _testLogger.i('$_tag Test setup starting');
      // Clear logs before each test
      LoggerFactory.clearLogs();
      _testLogger.i('$_tag Test setup complete, logs cleared');
    });

    testWidgets('logs at most once per frame for identical rebuilds', (
      WidgetTester tester,
    ) async {
      _testLogger.i('$_tag Starting log spam test');
      // Create sample job
      final sampleJob = createSampleJob();
      _testLogger.i('$_tag Sample job created');

      // Track onTap callback invocations
      bool onTapCalled = false;
      void onTapCallback(JobViewModel job) {
        onTapCalled = true;
        _testLogger.i('$_tag onTap callback invoked');
      }

      // First build
      _testLogger.i('$_tag Pumping initial widget');
      await tester.pumpWidget(
        MaterialApp(
          // Use the correct theme from app_theme.dart
          theme: createLightTheme(),
          home: Scaffold(
            body: JobListItem(
              job: sampleJob,
              onTapJob: onTapCallback, // Add onTapJob callback
            ),
          ),
        ),
      );
      _testLogger.i('$_tag Initial widget pumped');

      // Capture initial log count, excluding our diagnostic logs
      LoggerFactory.clearLogs(); // Clear our setup logs
      _testLogger.i('$_tag Cleared logs again to establish baseline');

      // Force identical rebuild
      _testLogger.i('$_tag Forcing identical rebuild');
      await tester.pump();
      _testLogger.i('$_tag Rebuild complete');

      // Check for absence of specific logs after rebuild
      final containsTapLog = LoggerFactory.containsLog('Tapped on job: 123');
      _testLogger.i('$_tag Contains tap log after rebuild: $containsTapLog');
      expect(
        containsTapLog,
        isFalse,
        reason: 'JobListItem should not log tap events on identical rebuild',
      );
      _testLogger.i('$_tag Rebuild log verification complete');

      // Tap on the item to trigger a log - since it uses onTap with _logger.i
      _testLogger.i('$_tag Tapping JobListItem');
      try {
        await tester.tap(find.byType(JobListItem));
        _testLogger.i('$_tag Tap successful');
      } catch (e) {
        _testLogger.e('$_tag Error during tap: $e');
        rethrow;
      }

      _testLogger.i('$_tag Pumping after tap');
      await tester.pump();
      _testLogger.i('$_tag Pump after tap complete');

      // Now we should see the log about tapping
      final afterTapContainsLog = LoggerFactory.containsLog(
        'Tapped on job: 123',
      );
      _testLogger.i('$_tag Contains tap log after tap: $afterTapContainsLog');
      expect(
        afterTapContainsLog,
        isTrue,
        reason: 'JobListItem should log tap event after being tapped',
      );
      _testLogger.i('$_tag Tap log verification complete');

      // Verify callback was called
      expect(
        onTapCalled,
        isTrue,
        reason: 'onTapJob callback should be called when tapped',
      );
      _testLogger.i('$_tag Callback verification complete');

      // Force another identical rebuild
      _testLogger.i('$_tag Forcing second identical rebuild');
      await tester.pump();
      _testLogger.i('$_tag Second rebuild complete');

      // Clear logs to verify no new logs after the second rebuild
      LoggerFactory.clearLogs();
      _testLogger.i('$_tag Cleared logs before second verification');

      await tester.pump(); // Another pump to ensure nothing happens

      // Check that no new tap log is created after the rebuild
      final afterRebuildContainsLog = LoggerFactory.containsLog(
        'Tapped on job: 123',
      );
      _testLogger.i(
        '$_tag Contains tap log after second rebuild: $afterRebuildContainsLog',
      );
      expect(
        afterRebuildContainsLog,
        isFalse,
        reason:
            'JobListItem should not log additional tap events on second identical rebuild',
      );
      _testLogger.i('$_tag Second rebuild log verification complete');
      _testLogger.i('$_tag Test completed successfully');
    });

    // New Test: Offline Tap Logging
    testWidgets('does not log tap when offline', (WidgetTester tester) async {
      _testLogger.i('$_tag Starting offline tap log test');
      // Create sample job
      final sampleJob = createSampleJob();
      _testLogger.i('$_tag Sample job created');

      // Define a dummy onTap callback
      bool callbackCalled = false;
      void dummyOnTap(JobViewModel job) {
        callbackCalled = true;
        _testLogger.w('$_tag DUMMY CALLBACK CALLED - THIS SHOULD NOT HAPPEN!');
      }

      _testLogger.i('$_tag Pumping initial widget (offline)');
      await tester.pumpWidget(
        MaterialApp(
          theme: createLightTheme(),
          home: Scaffold(
            body: JobListItem(
              job: sampleJob,
              isOffline: true, // Set offline state
              onTapJob: dummyOnTap, // Provide a callback
            ),
          ),
        ),
      );
      _testLogger.i('$_tag Initial widget pumped');

      // Clear logs before tap
      LoggerFactory.clearLogs();
      _testLogger.i('$_tag Logs cleared before tap');

      // Tap on the item
      _testLogger.i('$_tag Tapping JobListItem (while offline)');
      await tester.tap(find.byType(ListTile));
      await tester.pump(); // Let UI settle
      _testLogger.i('$_tag Tap and pump complete');

      // Verify NO logs from JobListItem were emitted
      final logCount = LoggerFactory.getLogsFor(JobListItem).length;
      _testLogger.i('$_tag JobListItem logs after offline tap: $logCount');
      expect(
        logCount,
        equals(0),
        reason: 'JobListItem should not log when tapped in offline mode',
      );

      // Also verify the dummy callback wasn't called
      expect(
        callbackCalled,
        isFalse,
        reason: 'onTapJob callback should not be called when offline',
      );

      _testLogger.i('$_tag Offline tap test completed successfully');
    });
  });
}
