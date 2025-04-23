import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // For logging taps
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

/// A widget representing a single item in the job list.
class JobListItem extends StatelessWidget {
  final JobViewModel job;

  const JobListItem({required this.job, super.key});

  // Logger setup
  static final Logger _logger = LoggerFactory.getLogger(JobListItem);
  static final String _tag = logTag(JobListItem);

  @override
  Widget build(BuildContext context) {
    // Date formatting
    final DateFormat formatter = DateFormat('MMM d, yyyy - HH:mm');
    final String displayDateString = formatter.format(job.displayDate);

    return ListTile(
      leading: Icon(
        job.hasFileIssue ? Icons.warning_amber_rounded : Icons.article_outlined,
        color: job.hasFileIssue ? Colors.orange : null,
      ), // Show warning if file issue
      title: Text(job.title),
      subtitle: Text(
        '${job.syncStatusText} - $displayDateString\nID: ${job.localId.substring(0, 8)}...',
      ),
      isThreeLine: true, // Allow more space for subtitle
      trailing: _buildSyncIcon(job.syncStatus), // Add sync status icon
      onTap: () {
        _logger.i('$_tag Tapped on job: ${job.localId}');
        // TODO: Implement navigation or action
      },
    );
  }

  /// Builds an icon representing the sync status.
  Widget _buildSyncIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return const Icon(Icons.cloud_done_outlined, color: Colors.green);
      case SyncStatus.pending:
      case SyncStatus.pendingDeletion:
        return const Icon(Icons.cloud_upload_outlined, color: Colors.blue);
      case SyncStatus.error:
        return const Icon(Icons.sync_problem_outlined, color: Colors.orange);
      case SyncStatus.failed:
        return const Icon(Icons.error_outline, color: Colors.red);
    }
  }
}
