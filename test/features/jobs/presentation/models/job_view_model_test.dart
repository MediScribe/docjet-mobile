import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JobViewModel - progressValue Getter', () {
    // Helper to create JobViewModel with a specific status
    JobViewModel createViewModel(JobStatus status) {
      return JobViewModel(
        localId: 'test-id',
        title: 'Test Job',
        text: 'Test Text',
        syncStatus: SyncStatus.synced,
        jobStatus: status,
        hasFileIssue: false,
        displayDate: DateTime.now(),
      );
    }

    test('should return 0.0 for created status', () {
      final viewModel = createViewModel(JobStatus.created);
      expect(viewModel.progressValue, 0.0);
    });

    test('should return 0.1 for submitted status', () {
      final viewModel = createViewModel(JobStatus.submitted);
      expect(viewModel.progressValue, 0.1);
    });

    test('should return 0.3 for transcribing status', () {
      final viewModel = createViewModel(JobStatus.transcribing);
      expect(viewModel.progressValue, 0.3);
    });

    test('should return 0.5 for transcribed status', () {
      final viewModel = createViewModel(JobStatus.transcribed);
      expect(viewModel.progressValue, 0.5);
    });

    test('should return 0.7 for generating status', () {
      final viewModel = createViewModel(JobStatus.generating);
      expect(viewModel.progressValue, 0.7);
    });

    test('should return 0.9 for generated status', () {
      final viewModel = createViewModel(JobStatus.generated);
      expect(viewModel.progressValue, 0.9);
    });

    test('should return 1.0 for completed status', () {
      final viewModel = createViewModel(JobStatus.completed);
      expect(viewModel.progressValue, 1.0);
    });

    // TODO: Update this test when error progress logic is refined
    test(
      'should return placeholder 0.7 for error status (pending proper implementation)',
      () {
        final viewModel = createViewModel(JobStatus.error);
        expect(viewModel.progressValue, 0.7); // Reflects current placeholder
      },
    );

    test('should return 0.0 for pendingDeletion status', () {
      final viewModel = createViewModel(JobStatus.pendingDeletion);
      expect(viewModel.progressValue, 0.0);
    });
  });
}
