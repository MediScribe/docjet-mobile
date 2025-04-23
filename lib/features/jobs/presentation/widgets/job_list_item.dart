import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // For logging taps
import 'package:flutter/cupertino.dart'; // Add Cupertino import
import 'package:flutter/material.dart'
    show
        ListTile,
        Colors,
        Material,
        MaterialType; // Keep ListTile & Colors, ADD Material
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

    // WRAP ListTile with Material to provide context needed for ink splashes etc.
    // Use MaterialType.transparency to avoid drawing a Material background.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Icon(
          job.hasFileIssue
              ? CupertinoIcons.exclamationmark_triangle_fill
              : CupertinoIcons.doc_text,
          color:
              job.hasFileIssue
                  ? Colors.orange
                  : CupertinoTheme.of(context).primaryColor, // Use theme color
        ), // Show warning if file issue
        title: Text(job.title),
        subtitle: Text(
          '${job.syncStatusText} - $displayDateString\nID: ${job.localId.substring(0, 8)}...',
        ),
        isThreeLine: true, // Allow more space for subtitle
        trailing: _buildSyncIcon(
          context,
          job.syncStatus,
        ), // Pass context for theme
        onTap: () {
          _logger.i('$_tag Tapped on job: ${job.localId}');
          // TODO: Implement navigation or action
        },
      ),
    );
  }

  /// Builds a Cupertino icon representing the sync status.
  Widget _buildSyncIcon(BuildContext context, SyncStatus status) {
    // Use CupertinoIcons and potentially theme colors
    final Color primaryColor = CupertinoTheme.of(context).primaryColor;
    switch (status) {
      case SyncStatus.synced:
        return Icon(
          CupertinoIcons.checkmark_alt_circle_fill,
          color: Colors.green,
        );
      case SyncStatus.pending:
      case SyncStatus.pendingDeletion:
        return Icon(CupertinoIcons.cloud_upload_fill, color: primaryColor);
      case SyncStatus.error:
        return Icon(
          CupertinoIcons.exclamationmark_circle_fill,
          color: Colors.orange,
        );
      case SyncStatus.failed:
        return Icon(CupertinoIcons.xmark_circle_fill, color: Colors.red);
    }
  }
}
