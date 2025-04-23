import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/job_list_item.dart';
import 'package:flutter/cupertino.dart';

/// A playground for experimenting with job list UI components (Cupertino Style)
/// This doesn't require tests as it's purely for UI experimentation
class JobListPlayground extends StatefulWidget {
  const JobListPlayground({super.key});

  @override
  State<JobListPlayground> createState() => _JobListPlaygroundState();
}

class _JobListPlaygroundState extends State<JobListPlayground> {
  static final Logger _logger = LoggerFactory.getLogger('JobListPlayground');
  static final String _tag = logTag('JobListPlayground');

  // Mock data for rapid UI iteration
  final List<JobViewModel> _mockJobs = [
    // Normal job with long title
    JobViewModel(
      localId: 'job_123456789',
      title:
          'This is a very long job title that might need wrapping or truncation in the UI',
      text: 'Some text content here',
      syncStatus: SyncStatus.synced,
      hasFileIssue: false,
      displayDate: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    // Job with file issues
    JobViewModel(
      localId: 'job_file_issue',
      title: 'Job with file issues',
      text: 'Job with file deletion problems',
      syncStatus: SyncStatus.synced,
      hasFileIssue: true,
      displayDate: DateTime.now().subtract(const Duration(days: 1)),
    ),
    // Job with sync pending
    JobViewModel(
      localId: 'job_sync_pending',
      title: 'Pending sync job',
      text: 'Waiting to be synced',
      syncStatus: SyncStatus.pending,
      hasFileIssue: false,
      displayDate: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    // Job with sync error
    JobViewModel(
      localId: 'job_sync_error',
      title: 'Sync error job',
      text: 'Failed to sync to server',
      syncStatus: SyncStatus.error,
      hasFileIssue: false,
      displayDate: DateTime.now().subtract(const Duration(days: 2)),
    ),
    // Job pending deletion
    JobViewModel(
      localId: 'job_pending_deletion',
      title: 'Pending deletion',
      text: 'Will be deleted soon',
      syncStatus: SyncStatus.pendingDeletion,
      hasFileIssue: false,
      displayDate: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    _logger.d(
      '$_tag Building UI playground with ${_mockJobs.length} mock jobs',
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Job List UI Playground'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.refresh),
          onPressed: () {
            _logger.d('$_tag Refreshing UI playground');
            setState(() {
              // Reset or change state as needed for testing
            });
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 8.0,
                children: [
                  CupertinoButton(
                    onPressed: () {
                      _logger.d('$_tag Showing list view');
                      setState(() {
                        // Toggle to list view mode
                      });
                    },
                    child: const Text('List View'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      _logger.d('$_tag Showing grid view');
                      setState(() {
                        // Toggle to grid view mode (if implemented)
                      });
                    },
                    child: const Text('Grid View'),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: _mockJobs.length,
                itemBuilder: (context, index) {
                  final jobViewModel = _mockJobs[index];
                  return JobListItem(job: jobViewModel);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
