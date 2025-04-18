import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart'; // This import will fail initially, that's expected

void main() {
  group('JobStatus Enum', () {
    test('should contain all expected status values', () {
      // Assert
      expect(JobStatus.values, contains(JobStatus.created));
      expect(JobStatus.values, contains(JobStatus.submitted));
      expect(JobStatus.values, contains(JobStatus.transcribing));
      expect(JobStatus.values, contains(JobStatus.transcribed));
      expect(JobStatus.values, contains(JobStatus.generating));
      expect(JobStatus.values, contains(JobStatus.generated));
      expect(JobStatus.values, contains(JobStatus.completed));
      expect(JobStatus.values, contains(JobStatus.error));
      expect(JobStatus.values.length, 8); // Ensure no extra values slipped in
    });
  });
}
