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
    test('should return 1.0 for error status', () {
      final viewModel = createProgressViewModel(JobStatus.error);
      expect(viewModel.progressValue, 1.0);
    });

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

    // --- Test cases for Cycle 2: Error & Edge States ---

    group('Error States', () {
      test(
        'uiIcon should return JobUIIcon.fileIssue if hasFileIssue is true (highest priority)',
        () {
          final jobViewModel = JobViewModel.forTest(
            jobStatus: JobStatus.completed, // Any other status
            syncStatus: SyncStatus.synced, // Any other status
            hasFileIssue: true,
          );
          expect(jobViewModel.uiIcon, JobUIIcon.fileIssue);
        },
      );

      test(
        'uiIcon should return JobUIIcon.syncFailed if syncStatus is failed',
        () {
          final jobViewModel = JobViewModel.forTest(
            jobStatus:
                JobStatus
                    .created, // Any other status that isn't an error itself
            syncStatus: SyncStatus.failed,
            hasFileIssue: false, // Ensure fileIssue isn't masking this
          );
          expect(jobViewModel.uiIcon, JobUIIcon.syncFailed);
        },
      );

      test(
        'uiIcon should return JobUIIcon.syncError if syncStatus is error',
        () {
          final jobViewModel = JobViewModel.forTest(
            jobStatus: JobStatus.created, // Any other status
            syncStatus: SyncStatus.error,
            hasFileIssue: false, // Ensure fileIssue isn't masking this
          );
          expect(jobViewModel.uiIcon, JobUIIcon.syncError);
        },
      );

      test(
        'uiIcon should return JobUIIcon.serverError if jobStatus is error (and no higher priority local errors)',
        () {
          final jobViewModel = JobViewModel.forTest(
            jobStatus: JobStatus.error,
            syncStatus: SyncStatus.synced, // Not a sync error
            hasFileIssue: false, // Not a file issue
          );
          expect(jobViewModel.uiIcon, JobUIIcon.serverError);
        },
      );
    });

    group('Edge Cases', () {
      test(
        'uiIcon should return JobUIIcon.pendingDeletion if jobStatus is pendingDeletion',
        () {
          final jobViewModel = JobViewModel.forTest(
            jobStatus: JobStatus.pendingDeletion,
            // Other statuses don't matter as much if it's pending deletion by jobStatus
            syncStatus: SyncStatus.synced,
            hasFileIssue: false,
          );
          expect(jobViewModel.uiIcon, JobUIIcon.pendingDeletion);
        },
      );

      test(
        'uiIcon should return JobUIIcon.pendingDeletion if syncStatus is pendingDeletion',
        () {
          // This test assumes that a syncStatus of pendingDeletion should also lead to the pendingDeletion icon,
          // regardless of jobStatus, unless a higher priority error (like fileIssue) is present.
          final jobViewModel = JobViewModel.forTest(
            jobStatus: JobStatus.created, // Any job status
            syncStatus: SyncStatus.pendingDeletion,
            hasFileIssue: false, // No higher priority error
          );
          expect(jobViewModel.uiIcon, JobUIIcon.pendingDeletion);

          // Also test with a completed jobStatus to ensure syncStatus.pendingDeletion takes precedence
          final jobViewModelCompleted = JobViewModel.forTest(
            jobStatus: JobStatus.completed,
            syncStatus: SyncStatus.pendingDeletion,
            hasFileIssue: false,
          );
          expect(jobViewModelCompleted.uiIcon, JobUIIcon.pendingDeletion);
        },
      );
    });

    group('Precedence Rules', () {
      test('uiIcon should correctly prioritize fileIssue over syncFailed', () {
        final jobViewModel = JobViewModel.forTest(
          jobStatus: JobStatus.created,
          syncStatus: SyncStatus.failed,
          hasFileIssue: true, // fileIssue takes precedence
        );
        expect(jobViewModel.uiIcon, JobUIIcon.fileIssue);
      });

      test('uiIcon should correctly prioritize syncFailed over syncError', () {
        final jobViewModelDirect = JobViewModel.forTest(
          jobStatus: JobStatus.created,
          syncStatus: SyncStatus.failed, // Explicitly failed
          // syncError would be another case SyncStatus.error
          hasFileIssue: false,
        );
        expect(jobViewModelDirect.uiIcon, JobUIIcon.syncFailed);
      });

      test(
        'uiIcon should correctly prioritize syncError over serverError (jobStatus.error)',
        () {
          final jobViewModel = JobViewModel.forTest(
            jobStatus: JobStatus.error, // Server error
            syncStatus: SyncStatus.error, // Sync error takes precedence
            hasFileIssue: false,
          );
          expect(jobViewModel.uiIcon, JobUIIcon.syncError);
        },
      );

      // Removed placeholder test for unhandled state combinations as it was redundant
      // and didn't verify specific behavior. Existing tests for `JobUIIcon.unknown` cover fallbacks.
    });
  });
}

// No more TODO here, it has been addressed.
