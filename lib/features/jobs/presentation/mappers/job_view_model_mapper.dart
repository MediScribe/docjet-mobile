import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';

/// Maps between the domain [Job] entity and the presentation [JobViewModel].
class JobViewModelMapper {
  /// Converts a [Job] entity to a [JobViewModel].
  JobViewModel toViewModel(Job job) {
    return JobViewModel(
      localId: job.localId,
      // Use displayText if available, otherwise fallback to text, or empty
      text: job.displayText ?? job.text ?? '',
      syncStatus: job.syncStatus,
      hasFileIssue: job.failedAudioDeletionAttempts > 0,
      // Display the last updated time as the primary date for the UI
      displayDate: job.updatedAt,
    );
  }

  // Potential future method: toViewModelList(List<Job> jobs) if needed
}
