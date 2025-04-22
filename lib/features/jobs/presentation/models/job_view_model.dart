import 'package:equatable/equatable.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

/// Represents the data needed to display a job item in the UI.
/// Derived from the [Job] entity, simplified for presentation.
class JobViewModel extends Equatable {
  final String localId;
  final String text; // Simplified: Assuming we show main text for now
  final SyncStatus syncStatus;
  final bool hasFileIssue; // Derived: true if failedAudioDeletionAttempts > 0
  final DateTime displayDate; // What date/time to show (e.g., updatedAt)

  const JobViewModel({
    required this.localId,
    required this.text,
    required this.syncStatus,
    required this.hasFileIssue,
    required this.displayDate,
  });

  @override
  List<Object?> get props => [
    localId,
    text,
    syncStatus,
    hasFileIssue,
    displayDate,
  ];
}
