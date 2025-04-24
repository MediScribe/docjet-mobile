// ignore_for_file: avoid_print, no_leading_underscores_for_local_identifiers

import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_processor_service.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
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

  final tPendingJobNew = createTestJob(
    localId: 'pendingNewJob1',
    serverId: null,
    syncStatus: SyncStatus.pending,
    retryCount: 0,
    audioFilePath: '/local/new_pending.mp3',
    text: 'Some initial text',
    additionalText: 'Some additional text',
    displayTitle: 'New Pending Job Sync Test',
  );

  final tSyncedJobFromServer = createTestJob(
    localId: 'pendingNewJob1',
    serverId: 'serverGeneratedId123',
    syncStatus: SyncStatus.synced,
    retryCount: 0,
    status: JobStatus.created,
    audioFilePath: '/local/new_pending.mp3',
    text: 'Some initial text',
    additionalText: 'Some additional text',
    displayTitle: 'New Pending Job Sync Test',
    updatedAt: DateTime.parse('2025-04-20T10:41:39.784035Z'),
  );

  final tExistingJobPendingUpdate = createTestJob(
    localId: 'existingJob1-local',
    serverId: 'existingJob1-server',
    syncStatus: SyncStatus.pending,
    retryCount: 1,
    status: JobStatus.transcribing,
    audioFilePath: '/local/existing.mp3',
    text: 'Updated text locally',
    additionalText: null,
    displayTitle: 'Updated Job Title Locally',
  );

  final tUpdatedJobFromServer = createTestJob(
    localId: 'existingJob1-local',
    serverId: 'existingJob1-server',
    syncStatus: SyncStatus.synced,
    retryCount: 0,
    status: JobStatus.transcribing,
    audioFilePath: '/local/existing.mp3',
    text: 'Updated text locally',
    additionalText: null,
    displayTitle: 'Updated Job Title Locally',
    updatedAt: DateTime.parse('2025-04-20T10:41:39.784035Z'),
  );

  setUp(() {
    printLog('[JobSyncProcessorTest][SyncSuccess] Setting up test...');
    mockLocalDataSource = MockJobLocalDataSource();
    mockRemoteDataSource = MockJobRemoteDataSource();
    mockFileSystem = MockFileSystem();
    service = JobSyncProcessorService(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
      fileSystem: mockFileSystem,
    );
    printLog('[JobSyncProcessorTest][SyncSuccess] Test setup complete');
  });

  group('processJobSync - Success Cases', () {
    test(
      'should call remote createJob and save returned job when serverId is null',
      () async {
        printLog(
          '[JobSyncProcessorTest][SyncSuccess] Starting test: should call remote createJob...',
        );
        // Arrange
        printLog('[JobSyncProcessorTest][SyncSuccess] Arranging mocks...');
        when(
          mockRemoteDataSource.createJob(
            audioFilePath: anyNamed('audioFilePath'),
            text: anyNamed('text'),
            additionalText: anyNamed('additionalText'),
          ),
        ).thenAnswer((_) async {
          printLog(
            '[JobSyncProcessorTest][SyncSuccess] Mock createJob called, returning tSyncedJobFromServer',
          );
          return tSyncedJobFromServer;
        });
        when(mockLocalDataSource.saveJob(any)).thenAnswer((invocation) async {
          printLog(
            '[JobSyncProcessorTest][SyncSuccess] Mock saveJob called, returning unit',
          );
          return unit;
        });
        printLog(
          '[JobSyncProcessorTest][SyncSuccess] Test arranged, starting action...',
        );

        // Act
        printLog(
          '[JobSyncProcessorTest][SyncSuccess] Calling service.processJobSync...',
        );
        final result = await service.processJobSync(tPendingJobNew);
        printLog(
          '[JobSyncProcessorTest][SyncSuccess] service.processJobSync completed with result: $result',
        );

        // Assert
        printLog('[JobSyncProcessorTest][SyncSuccess] Starting assertions');
        expect(result.isRight(), isTrue);
        verify(
          mockRemoteDataSource.createJob(
            audioFilePath: tPendingJobNew.audioFilePath!,
            text: tPendingJobNew.text,
            additionalText: tPendingJobNew.additionalText,
          ),
        );
        final captured =
            verify(mockLocalDataSource.saveJob(captureAny)).captured.single;
        printLog(
          '[JobSyncProcessorTest][SyncSuccess] Captured job in saveJob: syncStatus=${captured.syncStatus}, retryCount=${captured.retryCount}, lastSyncAttemptAt=${captured.lastSyncAttemptAt}',
        );
        expect(captured.localId, tSyncedJobFromServer.localId);
        expect(captured.serverId, tSyncedJobFromServer.serverId);
        expect(captured.syncStatus, SyncStatus.synced);
        expect(captured.retryCount, 0);
        expect(captured.updatedAt, tSyncedJobFromServer.updatedAt);

        verifyNoMoreInteractions(mockRemoteDataSource);
        printLog(
          '[JobSyncProcessorTest][SyncSuccess] Test completed successfully',
        );
      },
    );

    test(
      'should call remote updateJob and save returned job when serverId is NOT null',
      () async {
        printLog(
          '[JobSyncProcessorTest][SyncSuccess] Starting test: should call remote updateJob...',
        );
        // Arrange
        printLog('[JobSyncProcessorTest][SyncSuccess] Arranging mocks...');
        final expectedUpdates = <String, dynamic>{
          'status': tExistingJobPendingUpdate.status.name,
          'display_title': tExistingJobPendingUpdate.displayTitle,
          'text': tExistingJobPendingUpdate.text,
        };
        when(
          mockRemoteDataSource.updateJob(
            jobId: tExistingJobPendingUpdate.serverId!,
            updates: expectedUpdates,
          ),
        ).thenAnswer((_) async {
          printLog(
            '[JobSyncProcessorTest][SyncSuccess] Mock updateJob called, returning tUpdatedJobFromServer',
          );
          return tUpdatedJobFromServer;
        });
        when(mockLocalDataSource.saveJob(any)).thenAnswer((_) async {
          printLog(
            '[JobSyncProcessorTest][SyncSuccess] Mock saveJob called, returning unit',
          );
          return unit;
        });
        printLog(
          '[JobSyncProcessorTest][SyncSuccess] Test arranged, starting action...',
        );

        // Act
        printLog(
          '[JobSyncProcessorTest][SyncSuccess] Calling service.processJobSync...',
        );
        final result = await service.processJobSync(tExistingJobPendingUpdate);
        printLog(
          '[JobSyncProcessorTest][SyncSuccess] service.processJobSync completed with result: $result',
        );

        // Assert
        printLog('[JobSyncProcessorTest][SyncSuccess] Starting assertions');
        expect(result.isRight(), isTrue);
        verify(
          mockRemoteDataSource.updateJob(
            jobId: tExistingJobPendingUpdate.serverId!,
            updates: expectedUpdates,
          ),
        );
        final capturedUpdate =
            verify(mockLocalDataSource.saveJob(captureAny)).captured.single;
        printLog(
          '[JobSyncProcessorTest][SyncSuccess] Captured job in saveJob: syncStatus=${capturedUpdate.syncStatus}, retryCount=${capturedUpdate.retryCount}',
        );
        expect(capturedUpdate.localId, tUpdatedJobFromServer.localId);
        expect(capturedUpdate.serverId, tUpdatedJobFromServer.serverId);
        expect(capturedUpdate.syncStatus, SyncStatus.synced);
        expect(capturedUpdate.retryCount, 0);
        expect(capturedUpdate.updatedAt, tUpdatedJobFromServer.updatedAt);

        verifyNoMoreInteractions(mockRemoteDataSource);
        printLog(
          '[JobSyncProcessorTest][SyncSuccess] Test completed successfully',
        );
      },
    );
  });
}

void printLog(String message) {
  print(message);
}
