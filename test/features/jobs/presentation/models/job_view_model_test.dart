import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_ui_icon.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JobViewModel - progressValue Getter', () {
    // Helper to create JobViewModel with a specific status - uses the new factory
    JobViewModel createProgressViewModel(JobStatus status) {
      return JobViewModel.forTest(
        jobStatus: status,
        syncStatus: SyncStatus.synced, // Default for progress tests
      );
    }

    test('should return 0.0 for created status', () {
      final viewModel = createProgressViewModel(JobStatus.created);
      expect(viewModel.progressValue, 0.0);
    });

    test('should return 0.1 for submitted status', () {
      final viewModel = createProgressViewModel(JobStatus.submitted);
      expect(viewModel.progressValue, 0.1);
    });

    test('should return 0.3 for transcribing status', () {
      final viewModel = createProgressViewModel(JobStatus.transcribing);
      expect(viewModel.progressValue, 0.3);
    });

    test('should return 0.5 for transcribed status', () {
      final viewModel = createProgressViewModel(JobStatus.transcribed);
      expect(viewModel.progressValue, 0.5);
    });

    test('should return 0.7 for generating status', () {
      final viewModel = createProgressViewModel(JobStatus.generating);
      expect(viewModel.progressValue, 0.7);
    });

    test('should return 0.9 for generated status', () {
      final viewModel = createProgressViewModel(JobStatus.generated);
      expect(viewModel.progressValue, 0.9);
    });

    test('should return 1.0 for completed status', () {
      final viewModel = createProgressViewModel(JobStatus.completed);
      expect(viewModel.progressValue, 1.0);
    });

    // TODO: Update this test when error progress logic is refined
    test(
      'should return placeholder 0.7 for error status (pending proper implementation)',
      () {
        final viewModel = createProgressViewModel(JobStatus.error);
        expect(viewModel.progressValue, 0.7); // Reflects current placeholder
      },
    );

    test('should return 0.0 for pendingDeletion status', () {
      final viewModel = createProgressViewModel(JobStatus.pendingDeletion);
      expect(viewModel.progressValue, 0.0);
    });
  });

  group('JobViewModel - uiIcon Getter', () {
    // The old createJobViewModel helper is no longer needed as JobViewModel.forTest covers this.

    test(
      'uiIcon should return JobUIIcon.created when jobStatus is created and syncStatus is pending',
      () {
        final jobViewModel = JobViewModel.forTest(
          jobStatus: JobStatus.created,
          syncStatus: SyncStatus.pending,
        );
        expect(jobViewModel.uiIcon, JobUIIcon.created);
      },
    );

    test(
      'uiIcon should return JobUIIcon.created when jobStatus is created and syncStatus is null',
      () {
        final jobViewModel = JobViewModel.forTest(
          jobStatus: JobStatus.created,
          syncStatus: null, // Factory default is null, but explicit for clarity
        );
        expect(jobViewModel.uiIcon, JobUIIcon.created);
      },
    );

    test(
      'uiIcon should return JobUIIcon.processing when jobStatus is submitted',
      () {
        final jobViewModel = JobViewModel.forTest(
          jobStatus: JobStatus.submitted,
        );
        expect(jobViewModel.uiIcon, JobUIIcon.processing);
      },
    );

    test(
      'uiIcon should return JobUIIcon.processing when jobStatus is transcribing',
      () {
        final jobViewModel = JobViewModel.forTest(
          jobStatus: JobStatus.transcribing,
        );
        expect(jobViewModel.uiIcon, JobUIIcon.processing);
      },
    );

    test(
      'uiIcon should return JobUIIcon.processing when jobStatus is transcribed',
      () {
        final jobViewModel = JobViewModel.forTest(
          jobStatus: JobStatus.transcribed,
        );
        expect(jobViewModel.uiIcon, JobUIIcon.processing);
      },
    );

    test(
      'uiIcon should return JobUIIcon.processing when jobStatus is generating',
      () {
        final jobViewModel = JobViewModel.forTest(
          jobStatus: JobStatus.generating,
        );
        expect(jobViewModel.uiIcon, JobUIIcon.processing);
      },
    );

    test(
      'uiIcon should return JobUIIcon.processing when jobStatus is generated',
      () {
        final jobViewModel = JobViewModel.forTest(
          jobStatus: JobStatus.generated,
        );
        expect(jobViewModel.uiIcon, JobUIIcon.processing);
      },
    );

    test(
      'uiIcon should return JobUIIcon.completed when jobStatus is completed and no errors',
      () {
        final jobViewModel = JobViewModel.forTest(
          jobStatus: JobStatus.completed,
          syncStatus: SyncStatus.synced, // Explicitly synced for completed
          hasFileIssue: false,
        );
        expect(jobViewModel.uiIcon, JobUIIcon.completed);
      },
    );

    test(
      'uiIcon should return JobUIIcon.unknown for unhandled state combinations',
      () {
        // Example: JobStatus.created but SyncStatus.synced (not covered by .created logic)
        final jobViewModel = JobViewModel.forTest(
          jobStatus: JobStatus.created,
          syncStatus: SyncStatus.synced, // This combination should fall through
        );
        expect(jobViewModel.uiIcon, JobUIIcon.unknown);

        // Example: JobStatus.completed but SyncStatus.pending (not covered by .completed logic)
        final jobViewModel2 = JobViewModel.forTest(
          jobStatus: JobStatus.completed,
          syncStatus: SyncStatus.pending,
        );
        expect(jobViewModel2.uiIcon, JobUIIcon.unknown);
      },
    );
  });
}

// No more TODO here, it has been addressed.
