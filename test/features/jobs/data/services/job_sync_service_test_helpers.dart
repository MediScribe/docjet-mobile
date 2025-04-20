import 'package:docjet_mobile/features/jobs/data/config/job_sync_config.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';

// Generate mocks here if needed globally, or keep in respective files if preferred
// Example:
// @GenerateMocks([JobLocalDataSource, JobRemoteDataSource, NetworkInfo, FileSystem])

// --- Sample Job Data ---

final tNow = DateTime.now(); // Use a consistent 'now' for comparisons

final tPendingJobNew = Job(
  localId: 'pendingNewJob1',
  userId: 'user123',
  status: JobStatus.created,
  syncStatus: SyncStatus.pending,
  displayTitle: 'New Pending Job Sync Test',
  audioFilePath: '/local/new_pending.mp3',
  text: 'Some initial text',
  additionalText: 'Some additional text',
  createdAt: tNow.subtract(const Duration(minutes: 10)),
  updatedAt: tNow.subtract(const Duration(minutes: 5)),
  serverId: null,
  retryCount: 0,
  lastSyncAttemptAt: null,
);

final tSyncedJobFromServer = tPendingJobNew.copyWith(
  serverId: 'serverGeneratedId123',
  syncStatus: SyncStatus.synced,
  updatedAt: tNow,
);

final tExistingJobPendingUpdate = Job(
  localId: 'existingJob1-local',
  serverId: 'existingJob1-server',
  userId: 'user456',
  status: JobStatus.transcribing,
  syncStatus: SyncStatus.pending,
  displayTitle: 'Updated Job Title Locally',
  audioFilePath: '/local/existing.mp3',
  text: 'Updated text locally',
  additionalText: null,
  createdAt: tNow.subtract(const Duration(days: 1)),
  updatedAt: tNow.subtract(const Duration(hours: 1)),
  retryCount: 0,
  lastSyncAttemptAt: null,
);

final tUpdatedJobFromServer = tExistingJobPendingUpdate.copyWith(
  syncStatus: SyncStatus.synced,
  updatedAt: tNow,
);

final tJobPendingDeletionWithServerId = Job(
  localId: 'deleteMe-local',
  serverId: 'deleteMe-server',
  userId: 'user789',
  status: JobStatus.completed,
  syncStatus: SyncStatus.pendingDeletion,
  displayTitle: 'Job To Be Deleted',
  audioFilePath: '/local/delete_me.mp3',
  text: 'Final text',
  additionalText: null,
  createdAt: tNow.subtract(const Duration(days: 2)),
  updatedAt: tNow.subtract(const Duration(days: 1)),
  retryCount: 0,
  lastSyncAttemptAt: null,
);

final tJobInErrorRetryEligible = Job(
  localId: 'errorRetryJob1-local',
  serverId: 'errorRetryJob1-server',
  userId: 'userError1',
  status: JobStatus.transcribing,
  syncStatus: SyncStatus.error,
  displayTitle: 'Job Failed, Ready to Retry',
  audioFilePath: '/local/error_retry.mp3',
  text: 'Some text',
  additionalText: null,
  createdAt: tNow.subtract(const Duration(hours: 2)),
  updatedAt: tNow.subtract(const Duration(hours: 1)),
  retryCount: 2,
  lastSyncAttemptAt: tNow.subtract(const Duration(minutes: 30)),
);

final tJobInErrorMaxRetries = tJobInErrorRetryEligible.copyWith(
  localId: 'errorMaxRetryJob1-local',
  retryCount: maxRetryAttempts,
  lastSyncAttemptAt: tNow.subtract(const Duration(minutes: 5)),
);

// --- Common Mock Setup Helper (Optional) ---
// You could put a function here that sets up default mocks
// void setupDefaultMocks(
//   MockJobLocalDataSource local,
//   MockJobRemoteDataSource remote,
//   MockNetworkInfo network,
//   MockFileSystem fs,
// ) {
//   when(network.isConnected).thenAnswer((_) async => true);
//   when(local.getJobsByStatus(SyncStatus.pending)).thenAnswer((_) async => []);
//   when(local.getJobsByStatus(SyncStatus.pendingDeletion)).thenAnswer((_) async => []);
//   when(local.getJobsToRetry(any, any)).thenAnswer((_) async => []);
//   when(local.saveJob(any)).thenAnswer((_) async => unit);
//   when(local.deleteJob(any)).thenAnswer((_) async => unit);
//   when(fs.deleteFile(any)).thenAnswer((_) async => unit);
// }

// --- Helper Functions ---

// Simple logger for tests
void printLog(String message) {
  // ignore: avoid_print
  print(message);
}

// Helper function to create a Job entity (copied from job_lifecycle_test.dart)
Job createTestJob({
  required String localId,
  String? serverId,
  required SyncStatus syncStatus,
  required int retryCount,
  String? audioFilePath,
  String? text,
  String? additionalText,
  String? displayTitle,
  JobStatus status = JobStatus.created,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? lastSyncAttemptAt,
  String userId = 'test-user-id',
}) {
  final now = DateTime.now();
  return Job(
    localId: localId,
    serverId: serverId,
    userId: userId,
    status: status,
    syncStatus: syncStatus,
    displayTitle: displayTitle ?? 'Test Job $localId',
    displayText: '', // Default empty, can be overridden by test data
    audioFilePath: audioFilePath,
    text: text,
    additionalText: additionalText,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? createdAt ?? now,
    retryCount: retryCount,
    lastSyncAttemptAt: lastSyncAttemptAt,
  );
}
