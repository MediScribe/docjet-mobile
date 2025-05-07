import 'package:equatable/equatable.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_ui_icon.dart';

/// Represents the data needed to display a job item in the UI.
/// Derived from the [Job] entity, simplified for presentation.
class JobViewModel extends Equatable {
  final String localId;
  final String title; // Derived: Short representation for list display
  final String text; // Full text, maybe for detail view?
  final SyncStatus? syncStatus;
  final JobStatus jobStatus;
  final bool hasFileIssue; // Derived: true if failedAudioDeletionAttempts > 0
  final DateTime displayDate; // What date/time to show (e.g., updatedAt)

  static const List<JobStatus> _processingJobStates = [
    JobStatus.submitted,
    JobStatus.transcribing,
    JobStatus.transcribed,
    JobStatus.generating,
    JobStatus.generated,
  ];

  const JobViewModel({
    required this.localId,
    required this.title, // Added
    required this.text,
    this.syncStatus,
    required this.jobStatus,
    required this.hasFileIssue,
    required this.displayDate,
  });

  /// Factory constructor for creating [JobViewModel] instances for testing.
  /// Provides sensible defaults for most fields to reduce boilerplate in tests.
  factory JobViewModel.forTest({
    String localId = 'test_local_id',
    String title = 'Test Job Title',
    String text = 'Test job text content.',
    SyncStatus?
    syncStatus, // Default to null, aligning with a newly created job
    JobStatus jobStatus = JobStatus.created,
    bool hasFileIssue = false,
    DateTime? displayDate,
  }) {
    return JobViewModel(
      localId: localId,
      title: title,
      text: text,
      syncStatus: syncStatus,
      jobStatus: jobStatus,
      hasFileIssue: hasFileIssue,
      displayDate: displayDate ?? DateTime.now(),
    );
  }

  /// Provides a user-friendly string representation of the sync status.
  String get syncStatusText {
    if (syncStatus == null) {
      return 'Sync Status Unknown';
    }
    switch (syncStatus!) {
      case SyncStatus.pending:
        return 'Pending Sync';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.pendingDeletion:
        return 'Pending Deletion';
      case SyncStatus.error:
        return 'Sync Error';
      case SyncStatus.failed:
        return 'Sync Failed';
    }
  }

  /// Calculated progress value (0.0 - 1.0) based on jobStatus.
  ///
  /// This getter centralizes the logic for converting backend status
  /// into a UI-friendly progress representation.
  double get progressValue {
    switch (jobStatus) {
      case JobStatus.created:
        return 0.0;
      case JobStatus.submitted:
        return 0.1;
      case JobStatus.transcribing:
        return 0.3;
      case JobStatus.transcribed:
        return 0.5;
      case JobStatus.generating:
        return 0.7;
      case JobStatus.generated:
        return 0.9;
      case JobStatus.completed:
        return 1.0;
      case JobStatus.error:
        // TODO: Determine how to get the actual progress before the error.
        // Currently hardcoded based on previous implementation's assumption.
        // This needs refinement - perhaps add previousStatus to ViewModel?
        return 0.7;
      case JobStatus.pendingDeletion:
        return 0.0;
    }
    // Note: The switch is exhaustive for JobStatus enum, so default is unreachable.
    // Adding a fallback just in case, though it indicates an issue.
    // _logger.w('Unknown JobStatus encountered in progressValue: $jobStatus');
    // return 0.0;
  }

  /// Determines the appropriate [JobUIIcon] based on the job's state,
  /// crucial for providing clear visual feedback to the user.
  ///
  /// The logic follows a strict order of precedence to ensure that the most critical
  /// information is always displayed. Error states and pending actions take priority
  /// over regular operational states.
  ///
  /// Note on `syncStatus` nullability: For a `JobStatus.created` job, `syncStatus`
  /// can be `null` (representing a job not yet attempted to sync) or
  /// `SyncStatus.pending`. This is handled in the `.created` icon logic.
  ///
  /// **Precedence Order:**
  /// 1.  **`JobUIIcon.fileIssue`**: If `hasFileIssue` is true. This is the highest priority
  ///     as it indicates a local problem preventing further action.
  /// 2.  **`JobUIIcon.syncFailed`**: If `syncStatus` is `SyncStatus.failed`. Indicates a
  ///     critical, unrecoverable synchronization failure.
  /// 3.  **`JobUIIcon.syncError`**: If `syncStatus` is `SyncStatus.error`. Indicates a
  ///     recoverable synchronization error.
  /// 4.  **`JobUIIcon.serverError`**: If `jobStatus` is `JobStatus.error`. Indicates an
  ///     error reported by the server during processing. (Note: This takes precedence
  ///     over `pendingDeletion` if both conditions were met).
  /// 5.  **`JobUIIcon.pendingDeletion`**: If `jobStatus` is `JobStatus.pendingDeletion`
  ///     or `syncStatus` is `SyncStatus.pendingDeletion`. Indicates the job is
  ///     marked for deletion locally or via sync.
  /// 6.  **`JobUIIcon.created`**: If `jobStatus` is `JobStatus.created` AND (`syncStatus`
  ///     is `SyncStatus.pending` or `syncStatus == null`). Represents a newly created job.
  /// 7.  **`JobUIIcon.processing`**: If `jobStatus` is one of the states defined in
  ///     `_processingJobStates` (e.g., `submitted`, `transcribing`, `generated`).
  ///     Represents a job actively being processed by the server.
  /// 8.  **`JobUIIcon.completed`**: If `jobStatus` is `JobStatus.completed` AND
  ///     `syncStatus` is `SyncStatus.synced`. Represents a successfully completed
  ///     and synced job, assuming no overriding error states are present.
  /// 9.  **`JobUIIcon.unknown`**: Fallback for any state combination not explicitly
  ///     handled above. This should ideally not be reached if logic is complete.
  JobUIIcon get uiIcon {
    // Highest Precedence: Local File Issue
    if (hasFileIssue) {
      return JobUIIcon.fileIssue;
    }

    // Sync Status Errors (before general JobStatus error)
    if (syncStatus == SyncStatus.failed) {
      return JobUIIcon.syncFailed;
    }
    if (syncStatus == SyncStatus.error) {
      return JobUIIcon.syncError;
    }

    // General Job Status Error (server-side)
    if (jobStatus == JobStatus.error) {
      return JobUIIcon.serverError;
    }

    // Pending Deletion (can come from job or sync status)
    if (jobStatus == JobStatus.pendingDeletion ||
        syncStatus == SyncStatus.pendingDeletion) {
      return JobUIIcon.pendingDeletion;
    }

    // Happy path: Created
    if (jobStatus == JobStatus.created &&
        (syncStatus == SyncStatus.pending || syncStatus == null)) {
      return JobUIIcon.created;
    }

    // Happy path: Processing (covers multiple server-side states)
    if (_processingJobStates.contains(jobStatus)) {
      return JobUIIcon.processing;
    }

    // Happy path: Completed
    if (jobStatus == JobStatus.completed && syncStatus == SyncStatus.synced) {
      // In a later cycle, we will add checks for `hasFileIssue` and other errors here.
      return JobUIIcon.completed;
    }

    // Fallback for any unhandled state (errors will be handled with higher precedence later)
    return JobUIIcon.unknown;
  }

  @override
  List<Object?> get props => [
    localId,
    title, // Added
    text,
    syncStatus,
    jobStatus,
    hasFileIssue,
    displayDate,
  ];
}
