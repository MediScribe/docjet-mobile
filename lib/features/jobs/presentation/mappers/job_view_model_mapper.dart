import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';

/// Maps between the domain [Job] entity and the presentation [JobViewModel].
class JobViewModelMapper {
  static const int _titleMaxLength = 50; // Max length for title snippet

  /// Converts a [Job] entity to a [JobViewModel].
  JobViewModel toViewModel(Job job) {
    // Create a concise title for list display
    final String title = _createTitle(job.text);

    return JobViewModel(
      localId: job.localId,
      title: title, // Use the generated title
      text: job.text ?? '', // Keep the full text
      syncStatus: job.syncStatus,
      jobStatus: job.status,
      hasFileIssue: job.failedAudioDeletionAttempts > 0,
      // Display the last updated time as the primary date for the UI
      displayDate: job.updatedAt,
    );
  }

  /// Helper to generate a short title from the job text.
  String _createTitle(String? text) {
    if (text == null || text.isEmpty) {
      return 'Untitled Job';
    }
    final lines = text.split('\n');
    final firstLine = lines.first.trim();
    if (firstLine.isEmpty && lines.length > 1) {
      // If first line is empty but there's more, use next line
      return lines[1].trim().substring(
        0,
        lines[1].trim().length > _titleMaxLength
            ? _titleMaxLength
            : lines[1].trim().length,
      );
    }
    if (firstLine.length > _titleMaxLength) {
      return '${firstLine.substring(0, _titleMaxLength)}...';
    }
    return firstLine;
  }

  // Potential future method: toViewModelList(List<Job> jobs) if needed
}
