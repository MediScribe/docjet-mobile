import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

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

    // Get app color tokens
    final appColors = getAppColors(context);

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
                  ? appColors
                      .warningFg // Use theme token for warning
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
    // Get app color tokens and primary color
    final appColors = getAppColors(context);
    final Color primaryColor = CupertinoTheme.of(context).primaryColor;

    switch (status) {
      case SyncStatus.synced:
        return Icon(
          CupertinoIcons.checkmark_alt_circle_fill,
          color: appColors.successFg, // Use theme token for success
        );
      case SyncStatus.pending:
      case SyncStatus.pendingDeletion:
        return Icon(CupertinoIcons.cloud_upload_fill, color: primaryColor);
      case SyncStatus.error:
        return Icon(
          CupertinoIcons.exclamationmark_circle_fill,
          color: appColors.warningFg, // Use theme token for warning
        );
      case SyncStatus.failed:
        return Icon(
          CupertinoIcons.xmark_circle_fill,
          color: appColors.dangerFg, // Use theme token for error/danger
        );
    }
  }
}
