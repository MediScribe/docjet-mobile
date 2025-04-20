import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

// Import the individual test files
import 'job_sync_processor_service/_sync_success_test.dart' as sync_success;
import 'job_sync_processor_service/_sync_error_test.dart' as sync_error;
import 'job_sync_processor_service/_deletion_success_test.dart' as deletion_success;
import 'job_sync_processor_service/_deletion_error_test.dart' as deletion_error;

// Generate mocks for all processor tests
@GenerateNiceMocks([
  MockSpec<JobLocalDataSource>(),
  MockSpec<JobRemoteDataSource>(),
  MockSpec<FileSystem>(),
])
void main() {
  group('JobSyncProcessorService Tests', () {
    // Run the tests from each imported file
    sync_success.main();
    sync_error.main();
    deletion_success.main();
    deletion_error.main();
  });
}