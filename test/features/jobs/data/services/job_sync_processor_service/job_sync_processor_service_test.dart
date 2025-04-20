import 'package:flutter_test/flutter_test.dart';

// Import the individual test files
import '_sync_success_test.dart' as sync_success;
import '_sync_error_test.dart' as sync_error;
import '_deletion_success_test.dart' as deletion_success;
import '_deletion_error_test.dart' as deletion_error;

void main() {
  group('JobSyncProcessorService Tests', () {
    // Run the tests from each imported file
    sync_success.main();
    sync_error.main();
    deletion_success.main();
    deletion_error.main();
  });
}
