import 'package:equatable/equatable.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

/// Represents the data needed to display a job item in the UI.
/// Derived from the [Job] entity, simplified for presentation.
class JobViewModel extends Equatable {
  final String localId;
  final String title; // Derived: Short representation for list display
  final String text; // Full text, maybe for detail view?
  final SyncStatus syncStatus;
  final JobStatus jobStatus;
  final bool hasFileIssue; // Derived: true if failedAudioDeletionAttempts > 0
  final DateTime displayDate; // What date/time to show (e.g., updatedAt)

  const JobViewModel({
    required this.localId,
    required this.title, // Added
    required this.text,
    required this.syncStatus,
    required this.jobStatus,
    required this.hasFileIssue,
    required this.displayDate,
  });

  /// Provides a user-friendly string representation of the sync status.
  String get syncStatusText {
    switch (syncStatus) {
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
