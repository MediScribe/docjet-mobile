/// Enum representing all possible UI icon states for a job.
///
/// This enum is used by the `JobViewModel` to determine which icon
/// should be displayed in the `JobListItem`.
enum JobUIIcon {
  /// Job has been created locally, pending initial sync or first action.
  created,

  /// Job is created locally but has not yet been successfully synced.
  /// This is a legacy state and might be combined with `created` if sync is implicit.
  /// For now, keeping it distinct as per initial plan.
  pendingSync,

  /// An error occurred during the synchronization process, but it might be recoverable.
  syncError,

  /// The synchronization process failed definitively.
  syncFailed,

  /// There is an issue with the file(s) associated with the job (e.g., missing, corrupted).
  /// This has the highest precedence among error states.
  fileIssue,

  /// The job is currently being processed by the server (e.g., submitted, transcribing, generating).
  processing,

  /// An error occurred on the server while processing the job.
  serverError,

  /// The job has been successfully completed.
  completed,

  /// The job is marked for deletion and is awaiting confirmation or processing.
  pendingDeletion,

  /// The job's state is unknown or cannot be determined.
  /// This serves as a fallback to prevent UI errors.
  unknown,
}
