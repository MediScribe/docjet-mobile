import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart'; // Import JobStatus
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

/// A Material list item for displaying job information with Cupertino iconography.
class JobListItem extends StatelessWidget {
  final JobViewModel job;
  final bool isOffline;
  final ValueChanged<JobViewModel>? onTapJob;

  /// Create a JobListItem
  ///
  /// [job] contains all the job information to display
  /// [isOffline] indicates if the app is in offline mode, disabling network-dependent actions
  /// [onTapJob] optional callback triggered when the job item is tapped
  const JobListItem({
    super.key,
    required this.job,
    this.isOffline = false,
    this.onTapJob,
  });

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
    final appTokens = getAppColors(context); // Get AppColorTokens
    final formattedDate = _formatDate(job.displayDate);
    // final progressValue = _getProgressValue(job.jobStatus); // Use getter instead
    // final progressColor = _getProgressColor(job.jobStatus, appTokens); // Determine color directly

    // Determine progress bar color directly based on status
    final progressColor =
        job.jobStatus == JobStatus.error
            ? appTokens
                .dangerFg // Use danger color for errors
            : appTokens.successFg; // Use success color otherwise

    // WRAP ListTile with Material to provide context needed for ink splashes etc.
    // Use MaterialType.transparency to avoid drawing a Material background.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        // Wrap ListTile content and Progress Bar
        mainAxisSize:
            MainAxisSize.min, // Prevent Column from expanding vertically
        children: [
          ListTile(
            leading: Icon(
              _getJobItemIcon(job),
              color: _getIconColor(context, job),
            ),
            title: Text(
              job.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              formattedDate,
              style: TextStyle(
                fontSize: 12.0,
                color:
                    colorScheme.onSurfaceVariant, // Use color scheme for text
              ),
            ),
            onTap:
                isOffline
                    ? null // Disable interaction when offline
                    : () {
                      // Only log and call if the callback is actually provided
                      if (onTapJob != null) {
                        _logger.i('$_tag Tapped on job: ${job.localId}');
                        onTapJob!(job);
                      }
                    },
          ),
          // Add padding to position the progress bar nicely below the text
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
            ), // Match ListTile horizontal padding
            child: SizedBox(
              // Constrain height of the progress bar
              height: 4.0, // Thin progress bar
              child: LinearProgressIndicator(
                value: job.progressValue, // Use the getter directly
                color: progressColor,
                backgroundColor:
                    appTokens
                        .outlineColor, // Use theme outline color for background
                // Consider minHeight for very thin bars if needed, but SizedBox works
              ),
            ),
          ),
          // Add a small gap below the progress bar before the next item
          const SizedBox(height: 4.0),
        ],
      ),
    );
  }
}
