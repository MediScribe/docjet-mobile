// ignore_for_file: avoid_print, no_leading_underscores_for_local_identifiers

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../job_sync_processor_service_test.mocks.dart';
import '../job_sync_service_test_helpers.dart';

@GenerateNiceMocks([
  MockSpec<JobLocalDataSource>(),
  MockSpec<JobRemoteDataSource>(),
  MockSpec<FileSystem>(),
])
void main() {
  late MockJobLocalDataSource mockLocalDataSource;
  late MockJobRemoteDataSource mockRemoteDataSource;
  late MockFileSystem mockFileSystem;
  late JobSyncProcessorService service;
  late MockJobSyncOrchestratorService mockJobSyncOrchestratorService;

  final tJobPendingDeletionWithServerId = createTestJob(
    localId: 'deleteMe-local',
    serverId: 'deleteMe-server',
    syncStatus: SyncStatus.pendingDeletion,
    audioFilePath: '/local/delete_me.mp3',
    retryCount: 0,
  );

  final tJobPendingDeletionWithoutServerId = createTestJob(
    localId: 'deleteMe-local-only',
    serverId: null,
    syncStatus: SyncStatus.pendingDeletion,
    audioFilePath: '/local/delete_me_local.mp3',
    retryCount: 0,
  );

  setUp(() {
    printLog('[JobSyncProcessorTest][DeletionSuccess] Setting up test...');
    mockLocalDataSource = MockJobLocalDataSource();
    mockRemoteDataSource = MockJobRemoteDataSource();
    mockFileSystem = MockFileSystem();
    mockJobSyncOrchestratorService = MockJobSyncOrchestratorService();

    service = JobSyncProcessorService(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
      fileSystem: mockFileSystem,
      isLogoutInProgress:
          () => mockJobSyncOrchestratorService.isLogoutInProgress,
    );

    // Add default stub for isLogoutInProgress
    when(mockJobSyncOrchestratorService.isLogoutInProgress).thenReturn(false);

    printLog('[JobSyncProcessorTest][DeletionSuccess] Test setup complete');
  });

  group('processJobDeletion - Success Cases', () {
    test(
      'should call remote deleteJob, local getJobById, local deleteJob, and fileSystem delete when serverId exists and has audio',
      () async {
        printLog(
          '[JobSyncProcessorTest][DeletionSuccess] Starting test: processJobDeletion - server delete success...',
        );
        when(mockRemoteDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(
          mockLocalDataSource.getJobById(
            tJobPendingDeletionWithServerId.localId,
          ),
        ).thenAnswer((_) async => tJobPendingDeletionWithServerId);
        when(mockLocalDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(mockFileSystem.deleteFile(any)).thenAnswer((_) async => unit);

        final result = await service.processJobDeletion(
          tJobPendingDeletionWithServerId,
        );

        expect(result, const Right(unit));
        verify(
          mockRemoteDataSource.deleteJob(
            tJobPendingDeletionWithServerId.serverId!,
          ),
        ).called(1);
        verify(
          mockLocalDataSource.getJobById(
            tJobPendingDeletionWithServerId.localId,
          ),
        ).called(1);
        verify(
          mockLocalDataSource.deleteJob(
            tJobPendingDeletionWithServerId.localId,
          ),
        ).called(1);
        verify(
          mockFileSystem.deleteFile(
            tJobPendingDeletionWithServerId.audioFilePath!,
          ),
        ).called(1);
        printLog(
          '[JobSyncProcessorTest][DeletionSuccess] Test completed successfully',
        );
      },
    );

    test(
      'should only call local getJobById, local deleteJob and fileSystem delete when serverId is null',
      () async {
        printLog(
          '[JobSyncProcessorTest][DeletionSuccess] Starting test: processJobDeletion - local-only delete success...',
        );
        when(
          mockLocalDataSource.getJobById(
            tJobPendingDeletionWithoutServerId.localId,
          ),
        ).thenAnswer((_) async => tJobPendingDeletionWithoutServerId);
        when(mockLocalDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(mockFileSystem.deleteFile(any)).thenAnswer((_) async => unit);

        final result = await service.processJobDeletion(
          tJobPendingDeletionWithoutServerId,
        );

        expect(result, const Right(unit));
        verifyNever(mockRemoteDataSource.deleteJob(any));
        verify(
          mockLocalDataSource.getJobById(
            tJobPendingDeletionWithoutServerId.localId,
          ),
        ).called(1);
        verify(
          mockLocalDataSource.deleteJob(
            tJobPendingDeletionWithoutServerId.localId,
          ),
        ).called(1);
        verify(
          mockFileSystem.deleteFile(
            tJobPendingDeletionWithoutServerId.audioFilePath!,
          ),
        ).called(1);
        printLog(
          '[JobSyncProcessorTest][DeletionSuccess] Test completed successfully',
        );
      },
    );

    test(
      'should call remote deleteJob, local getJobById, local deleteJob but NOT fileSystem delete when audioFilePath is null',
      () async {
        printLog(
          '[JobSyncProcessorTest][DeletionSuccess] Starting test: processJobDeletion - no audio file...',
        );
        final jobWithoutAudio = createTestJob(
          localId: 'deleteMe-local',
          serverId: 'deleteMe-server',
          syncStatus: SyncStatus.pendingDeletion,
          audioFilePath: null,
          retryCount: 0,
        );

        printLog(
          '[JobSyncProcessorTest][DeletionSuccess] Configured jobWithoutAudio with audioFilePath: ${jobWithoutAudio.audioFilePath}',
        );
        when(mockRemoteDataSource.deleteJob(any)).thenAnswer((_) async => unit);
        when(
          mockLocalDataSource.getJobById(jobWithoutAudio.localId),
        ).thenAnswer((invocation) async {
          printLog(
            '[JobSyncProcessorTest][DeletionSuccess] Mock getJobById for ${jobWithoutAudio.localId} returning job with audio: ${jobWithoutAudio.audioFilePath}',
          );
          return jobWithoutAudio;
        });
        when(mockLocalDataSource.deleteJob(any)).thenAnswer((_) async => unit);

        final result = await service.processJobDeletion(jobWithoutAudio);

        expect(result, const Right(unit));
        verify(
          mockRemoteDataSource.deleteJob(jobWithoutAudio.serverId!),
        ).called(1);
        verify(
          mockLocalDataSource.getJobById(jobWithoutAudio.localId),
        ).called(1);
        verify(
          mockLocalDataSource.deleteJob(jobWithoutAudio.localId),
        ).called(1);
        verifyNever(mockFileSystem.deleteFile(any));
        printLog(
          '[JobSyncProcessorTest][DeletionSuccess] Test completed successfully',
        );
      },
    );
  });
}

void printLog(String message) {
  print(message);
}
