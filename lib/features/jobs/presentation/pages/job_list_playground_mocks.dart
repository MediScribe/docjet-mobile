/// This is a temporary file for generating mock JobViewModels for the JobListPlayground.
/// It's intended to be deleted or kept for future debugging after visual testing of icon states is complete.
///
/// HOW TO USE THESE MOCKS IN JobListPlayground.dart:
/// --------------------------------------------------
/// 1. IMPORT THIS FILE:
///    In 'lib/features/jobs/presentation/pages/job_list_playground.dart',
///    add the import:
///    import 'package:docjet_mobile/features/jobs/presentation/pages/job_list_playground_mocks.dart';
///
/// 2. INITIALIZE _mockJobs LIST:
///    In the '_JobListPlaygroundContentState' class within 'job_list_playground.dart',
///    find the '_mockJobs' field and change its initialization to call this function:
///    final List<JobViewModel> _mockJobs = generateAllMockPlaygroundJobs();
///
/// 3. (RECOMMENDED) DISPLAY THE MOCKS (Choose one approach):
///    To actually see these mocks instead of/in addition to real jobs from the JobListCubit,
///    you'll need to modify the BlocBuilder<JobListCubit, JobListState> logic.
///
///    OPTION A (Simple Override - Show ONLY Mocks):
///    Inside the BlocBuilder's builder function, you can temporarily force it to always show mocks:
///    builder: (context, state) {
///      // TEMPORARILY FORCE MOCK DISPLAY:
///      return ListView.builder(
///        padding: const EdgeInsets.only(bottom: 120.0),
///        itemCount: _mockJobs.length,
///        itemBuilder: (context, index) {
///          return JobListItem(
///            job: _mockJobs[index],
///            isOffline: widget.isOffline, // or a fixed value if widget.isOffline is not in scope
///            onTapJob: (_) {},
///          );
///        },
///      );
///      // Original BlocBuilder logic for JobListLoading, JobListLoaded, etc., would be bypassed.
///    }
///
///    OPTION B (Conditional Toggle - More Flexible):
///    a. Add a state variable to '_JobListPlaygroundContentState':
///       bool _showMockJobsOverride = false;
///    b. Add a button/method to toggle this variable with setState:
///       void _toggleMockOverride() => setState(() => _showMockJobsOverride = !_showMockJobsOverride);
///    c. In the BlocBuilder, prioritize mocks if the override is true:
///       builder: (context, state) {
///         if (_showMockJobsOverride) {
///           // Show mocks (as in Option A's ListView.builder)
///         }
///         // ... then proceed with original logic for state is JobListLoading, JobListLoaded, etc.
///         // You might also want the fallback at the end of the BlocBuilder to use _mockJobs.
///       }
///
/// REMEMBER TO REVERT CHANGES to 'job_list_playground.dart' after you're done
/// visually inspecting the mock states, unless you intend to keep the toggle/override permanently.
///--------------------------------------------------

// ignore_for_file: dangling_library_doc_comments, unintended_html_in_doc_comment

import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';

List<JobViewModel> generateAllMockPlaygroundJobs() {
  final now = DateTime.now();
  return [
    // --- Happy Paths ---
    JobViewModel(
      localId: 'mock_created_pending_sync',
      title: 'Job: Created (Pending Sync)',
      text: 'This job was just created locally and is waiting to sync.',
      syncStatus:
          SyncStatus
              .pending, // or null, uiIcon logic handles both for 'created'
      jobStatus: JobStatus.created,
      hasFileIssue: false,
      displayDate: now.subtract(const Duration(minutes: 5)),
      // Assuming other fields like audioFilePath, duration, etc., are not strictly needed for icon display
    ),
    JobViewModel(
      localId: 'mock_processing_submitted',
      title: 'Job: Processing (Submitted)',
      text: 'This job is submitted and being processed by the server.',
      syncStatus: SyncStatus.synced,
      jobStatus: JobStatus.submitted, // Example of a processing state
      hasFileIssue: false,
      displayDate: now.subtract(const Duration(minutes: 10)),
    ),
    JobViewModel(
      localId: 'mock_processing_transcribing',
      title: 'Job: Processing (Transcribing)',
      text: 'This job is currently transcribing.',
      syncStatus: SyncStatus.synced,
      jobStatus: JobStatus.transcribing,
      hasFileIssue: false,
      displayDate: now.subtract(const Duration(minutes: 12)),
    ),
    JobViewModel(
      localId: 'mock_completed',
      title: 'Job: Completed',
      text: 'This job has been successfully completed.',
      syncStatus: SyncStatus.synced,
      jobStatus: JobStatus.completed,
      hasFileIssue: false,
      displayDate: now.subtract(const Duration(hours: 1)),
    ),

    // --- Unhappy Paths & Edge Cases ---
    JobViewModel(
      localId: 'mock_file_issue',
      title: 'Job: File Issue',
      text: 'This job has a problem with its local file.',
      syncStatus:
          SyncStatus
              .pending, // Sync status can be anything if file issue takes precedence
      jobStatus: JobStatus.created, // Job status can be anything
      hasFileIssue: true, // THE CRITICAL FLAG
      displayDate: now.subtract(const Duration(minutes: 15)),
    ),
    JobViewModel(
      localId: 'mock_sync_failed',
      title: 'Job: Sync Failed',
      text: 'Synchronization has permanently failed for this job.',
      syncStatus: SyncStatus.failed, // THE CRITICAL FLAG
      jobStatus: JobStatus.created, // Job status could be created or submitted
      hasFileIssue: false,
      displayDate: now.subtract(const Duration(minutes: 20)),
    ),
    JobViewModel(
      localId: 'mock_sync_error',
      title: 'Job: Sync Error',
      text: 'A temporary error occurred during synchronization.',
      syncStatus: SyncStatus.error, // THE CRITICAL FLAG
      jobStatus: JobStatus.created,
      hasFileIssue: false,
      displayDate: now.subtract(const Duration(minutes: 25)),
    ),
    JobViewModel(
      localId: 'mock_server_error',
      title: 'Job: Server Error',
      text: 'The server encountered an error processing this job.',
      syncStatus:
          SyncStatus.synced, // Assumes it synced, then server reported error
      jobStatus: JobStatus.error, // THE CRITICAL FLAG
      hasFileIssue: false,
      displayDate: now.subtract(const Duration(minutes: 30)),
    ),
    JobViewModel(
      localId: 'mock_pending_deletion_jobstatus',
      title: 'Job: Pending Deletion (JobStatus)',
      text: 'This job is marked for deletion via JobStatus.',
      syncStatus: SyncStatus.synced,
      jobStatus: JobStatus.pendingDeletion, // THE CRITICAL FLAG
      hasFileIssue: false,
      displayDate: now.subtract(const Duration(minutes: 35)),
    ),
    JobViewModel(
      localId: 'mock_pending_deletion_syncstatus',
      title: 'Job: Pending Deletion (SyncStatus)',
      text: 'This job is marked for deletion via SyncStatus.',
      syncStatus: SyncStatus.pendingDeletion, // THE CRITICAL FLAG
      jobStatus:
          JobStatus.completed, // Job could have been completed before deletion
      hasFileIssue: false,
      displayDate: now.subtract(const Duration(minutes: 40)),
    ),
    JobViewModel(
      localId: 'mock_unknown_state',
      title: 'Job: Unknown State',
      text:
          'This job is in a state not explicitly handled by icon logic (should show unknown icon).',
      // Forcing an unknown state: Use a combination that doesn't map to any specific icon
      // e.g. a new JobStatus that uiIcon getter doesn't know, or an unexpected combo.
      // For robust testing of 'unknown', one might temporarily add a new JobStatus/SyncStatus value
      // and use it here, then revert. Or, ensure the default case in uiIcon is reachable.
      // Here, we'll use a state that should fall through existing logic.
      // Let's assume 'jobStatus: JobStatus.created' with 'syncStatus: SyncStatus.synced'
      // without being 'completed' or any error state would be unusual enough to hit 'unknown'
      // if the 'created' logic specifically checks for pending/null sync.
      syncStatus: SyncStatus.synced,
      jobStatus:
          JobStatus
              .created, // This combination should fall to unknown if not 'completed' or error
      hasFileIssue: false,
      displayDate: now.subtract(const Duration(minutes: 45)),
    ),
    // Keep the original example mock if it's different or useful
    // This one seems to be a general "submitted" state, which is covered by "processing_submitted"
    // JobViewModel(
    //   localId: 'job_123456789',
    //   title: 'Original Mock Job (Submitted)',
    //   text: 'This is displayed when no real jobs exist yet',
    //   syncStatus: SyncStatus.synced,
    //   jobStatus: JobStatus.submitted,
    //   hasFileIssue: false,
    //   displayDate: now.subtract(const Duration(hours: 2)),
    // ),
  ];
}
