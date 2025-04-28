import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

/// A Cupertino-styled list item for displaying job information.
class JobListItem extends StatelessWidget {
  final JobViewModel job;
  final bool isOffline;

  /// Create a JobListItem
  ///
  /// [job] contains all the job information to display
  /// [isOffline] indicates if the app is in offline mode, disabling network-dependent actions
  const JobListItem({super.key, required this.job, this.isOffline = false});

  // Get logger instance for this class
  static final Logger _logger = LoggerFactory.getLogger(JobListItem);
  // Create standard log tag
  static final String _tag = logTag(JobListItem);

  /// Format the date as a readable string using intl package
  /// TODO(localization): Use proper localized strings for "Today" and "Yesterday"
  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final jobDate = DateTime(date.year, date.month, date.day);

    if (jobDate == DateTime(now.year, now.month, now.day)) {
      // Today, display time
      return 'Today at ${DateFormat.jm().format(date)}';
    } else if (jobDate == yesterday) {
      // Yesterday, display time
      return 'Yesterday at ${DateFormat.jm().format(date)}';
    } else {
      // Other date, display date
      return DateFormat.MMMMd().add_jm().format(date);
    }
  }

  /// Get the status text to display based on sync status
  static String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.pending:
        return 'Pending sync';
      case SyncStatus.pendingDeletion:
        return 'Pending deletion';
      case SyncStatus.synced:
        return ''; // No message when synced (common case)
      case SyncStatus.error:
        return 'Sync error';
      case SyncStatus.failed:
        return 'Sync failed';
    }
  }

  /// Get the appropriate icon for the job item
  static IconData _getJobItemIcon(JobViewModel job) {
    // Show warning icon if there are file issues, regardless of sync status
    if (job.hasFileIssue) {
      return CupertinoIcons.exclamationmark_triangle_fill;
    }

    // Default job icon
    return CupertinoIcons.doc_text;
  }

  /// Get the appropriate icon color for the job item
  static Color _getIconColor(BuildContext context, JobViewModel job) {
    final tokens = getAppColors(context);

    // Use warning color for file issues
    if (job.hasFileIssue) {
      return tokens.warningFg; // Semantic token for warnings
    }

    // Default icon color
    return tokens.infoFg; // Semantic token for info/neutral content
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors
    final colorScheme = Theme.of(context).colorScheme;

    // Determine if we should show status
    final statusText = _getStatusText(job.syncStatus);
    final showStatus = statusText.isNotEmpty;
    final formattedDate = _formatDate(job.displayDate);

    return CupertinoListTile(
      leading: Icon(_getJobItemIcon(job), color: _getIconColor(context, job)),
      title: Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (job.text.isNotEmpty)
            Text(
              job.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.0,
                color:
                    colorScheme.onSurfaceVariant, // Use color scheme for text
              ),
            ),
          Row(
            children: [
              // Date text
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12.0,
                  color:
                      colorScheme.onSurfaceVariant, // Use color scheme for text
                ),
              ),
              // Sync status if present
              if (showStatus) ...[
                const SizedBox(width: 8.0),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(50),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10.0,
                      color:
                          colorScheme
                              .onSurfaceVariant, // Use color scheme for text
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: const CupertinoListTileChevron(),
      onTap:
          isOffline
              ? null // Disable interaction when offline
              : () {
                _logger.i('$_tag Tapped on job: ${job.localId}');
                // TODO: Navigate to job detail page or other action
              },
    );
  }
}
