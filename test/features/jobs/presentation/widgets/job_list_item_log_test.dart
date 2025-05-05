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

      // First build
      _testLogger.i('$_tag Pumping initial widget');
      await tester.pumpWidget(
        MaterialApp(
          // Use the correct theme from app_theme.dart
          theme: createLightTheme(),
          home: Scaffold(body: JobListItem(job: sampleJob)),
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

      // We'll only count JobListItem logs, not our diagnostic logs
      final logCount = LoggerFactory.getLogsFor(JobListItem).length;
      _testLogger.i('$_tag JobListItem logs after rebuild: $logCount');
      expect(
        logCount,
        equals(0),
        reason: 'JobListItem should not log on identical rebuild',
      );
      _testLogger.i('$_tag Rebuild log count verification complete');

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

      // Now we should see exactly one more log from JobListItem
      final afterTapLogCount = LoggerFactory.getLogsFor(JobListItem).length;
      _testLogger.i('$_tag JobListItem logs after tap: $afterTapLogCount');
      expect(
        afterTapLogCount,
        equals(1),
        reason: 'JobListItem should log exactly once for tap action',
      );
      _testLogger.i('$_tag Tap log count verification complete');

      // Force another identical rebuild
      _testLogger.i('$_tag Forcing second identical rebuild');
      await tester.pump();
      _testLogger.i('$_tag Second rebuild complete');

      // The log count shouldn't increase after another rebuild
      final afterSecondRebuildLogCount =
          LoggerFactory.getLogsFor(JobListItem).length;
      _testLogger.i(
        '$_tag JobListItem logs after second rebuild: $afterSecondRebuildLogCount',
      );
      expect(
        afterSecondRebuildLogCount,
        equals(1),
        reason:
            'JobListItem should not log additional messages on second identical rebuild',
      );
      _testLogger.i('$_tag Second rebuild log count verification complete');
      _testLogger.i('$_tag Test completed successfully');
    });
  });
}
