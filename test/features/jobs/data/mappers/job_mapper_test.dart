import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_api_dto.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:uuid/uuid.dart';

void main() {
  final uuid = const Uuid();

  group('JobMapper: API DTO <-> Entity', () {
    test('should map JobApiDTO to Job entity correctly (Server ID)', () {
      // Arrange: Create a sample JobApiDTO (represents data FROM server)
      final now = DateTime.now();
      final serverId = 'server-job-123';
      final jobApiDto = JobApiDTO(
        id: serverId, // API DTO's id IS the serverId
        userId: 'user-456',
        jobStatus: 'completed', // API sends string
        createdAt: now,
        updatedAt: now,
        displayTitle: 'Test Job Title',
        displayText: 'Test Job Text',
        errorCode: null,
        errorMessage: null,
        text: 'Transcribed text',
        additionalText: 'Additional info',
        // Note: audioFilePath is not in the DTO, expected null in Job entity
      );

      // Act: Call the (non-existent) mapper function
      // This line WILL cause a compile error initially (RED step)
      final jobEntity = JobMapper.fromApiDto(jobApiDto);

      // Assert: Check if the Job entity has the correct values
      expect(jobEntity, isA<Job>());
      expect(jobEntity.localId, isNotNull); // Should be generated if null
      expect(jobEntity.serverId, serverId); // serverId comes from DTO id
      expect(jobEntity.userId, 'user-456');
      expect(jobEntity.status, JobStatus.completed); // Assert Enum
      expect(jobEntity.createdAt, now);
      expect(jobEntity.updatedAt, now);
      expect(jobEntity.displayTitle, 'Test Job Title');
      expect(jobEntity.displayText, 'Test Job Text');
      expect(jobEntity.errorCode, null);
      expect(jobEntity.errorMessage, null);
      expect(jobEntity.text, 'Transcribed text');
      expect(jobEntity.additionalText, 'Additional info');
      expect(jobEntity.audioFilePath, null); // DTO doesn't have this field
      expect(
        jobEntity.syncStatus,
        SyncStatus.synced,
      ); // Data from server is synced
    });

    test('should map a list of JobApiDTOs to a list of Job entities', () {
      // Arrange: Create a list of sample JobApiDTOs
      final now1 = DateTime.now();
      final now2 = now1.add(const Duration(minutes: 1));
      final serverId1 = 'server-job-1';
      final serverId2 = 'server-job-2';
      final dtoList = [
        JobApiDTO(
          id: serverId1,
          userId: 'user-1',
          jobStatus: 'submitted', // API sends string
          createdAt: now1,
          updatedAt: now1,
        ),
        JobApiDTO(
          id: serverId2,
          userId: 'user-1',
          jobStatus: 'completed', // API sends string
          createdAt: now2,
          updatedAt: now2,
          displayTitle: 'Completed Job',
          text: 'Some text',
        ),
      ];

      // Act: Call the (non-existent) list mapper function
      // This line WILL cause a compile error initially (RED step)
      final jobList = JobMapper.fromApiDtoList(dtoList);

      // Assert: Check if the list and its elements are correct
      expect(jobList, isA<List<Job>>());
      expect(jobList.length, 2);

      // Check first job
      expect(jobList[0].localId, isNotNull);
      expect(jobList[0].serverId, serverId1);
      expect(jobList[0].status, JobStatus.submitted); // Assert Enum
      expect(jobList[0].createdAt, now1);
      expect(jobList[0].displayTitle, isNull);
      expect(jobList[0].syncStatus, SyncStatus.synced);

      // Check second job
      expect(jobList[1].localId, isNotNull);
      expect(jobList[1].serverId, serverId2);
      expect(jobList[1].status, JobStatus.completed); // Assert Enum
      expect(jobList[1].updatedAt, now2);
      expect(jobList[1].displayTitle, 'Completed Job');
      expect(jobList[1].text, 'Some text');
      expect(jobList[1].syncStatus, SyncStatus.synced);
    });

    test(
      'should map Job entity WITH serverId back to JobApiDTO correctly (for Update)',
      () {
        // Arrange: Create a sample Job entity that HAS been synced
        final now = DateTime.now();
        final localId = uuid.v4();
        final serverId = 'server-job-789';
        final jobEntity = Job(
          localId: localId,
          serverId: serverId, // Has serverId
          userId: 'user-101',
          status: JobStatus.error, // Use Enum
          createdAt: now,
          updatedAt: now,
          displayTitle: 'Update Test Job',
          displayText: null,
          errorCode: 123,
          errorMessage: 'Processing Error',
          audioFilePath:
              'local/path/to/audio.mp4', // This field won't be in the DTO
          text: 'Submitted text',
          additionalText: null,
          syncStatus: SyncStatus.synced, // Example status
        );

        // Act: Call the (non-existent) reverse mapper function
        // This line WILL cause a compile error initially (RED step)
        final jobApiDto = JobMapper.toApiDto(jobEntity);

        // Assert: Check if the JobApiDTO has the correct values
        expect(jobApiDto, isA<JobApiDTO>());
        expect(jobApiDto.id, serverId); // DTO id should be the serverId
        expect(jobApiDto.userId, 'user-101');
        expect(
          jobApiDto.jobStatus,
          'error',
        ); // DTO uses string status, check lowercase 'error'
        expect(jobApiDto.createdAt, now);
        expect(jobApiDto.updatedAt, now);
        expect(jobApiDto.displayTitle, 'Update Test Job');
        expect(jobApiDto.displayText, null);
        expect(jobApiDto.errorCode, 123);
        expect(jobApiDto.errorMessage, 'Processing Error');
        expect(jobApiDto.text, 'Submitted text');
        expect(jobApiDto.additionalText, null);
        // Note: audioFilePath is not part of JobApiDTO
      },
    );

    test(
      'should map Job entity WITHOUT serverId back to JobApiDTO correctly (for Create)',
      () {
        // Arrange: Create a sample Job entity that has NOT been synced
        final now = DateTime.now();
        final localId = uuid.v4();
        final jobEntity = Job(
          localId: localId,
          serverId: null, // No serverId yet
          userId: 'user-202',
          status: JobStatus.created,
          createdAt: now,
          updatedAt: now,
          displayTitle: 'New Job',
          audioFilePath: 'local/path/new_audio.mp4',
          syncStatus: SyncStatus.pending,
        );

        // Act: Call the reverse mapper function
        final jobApiDto = JobMapper.toApiDto(jobEntity);

        // Assert: Check if the JobApiDTO has the correct values
        expect(jobApiDto, isA<JobApiDTO>());
        expect(
          jobApiDto.id,
          localId,
        ); // DTO id should be the localId for creation
        expect(jobApiDto.userId, 'user-202');
        expect(jobApiDto.jobStatus, 'created');
        expect(jobApiDto.createdAt, now);
        expect(jobApiDto.updatedAt, now);
        expect(jobApiDto.displayTitle, 'New Job');
        // Other fields might be null or default depending on API contract for creation
      },
    );

    // TODO: Add tests for edge cases (e.g., empty list, list with errors)
  });

  group('JobMapper Status Conversion', () {
    // --- Test _jobStatusToString (assuming it becomes accessible or we test via public methods) ---
    test('_jobStatusToString should convert enum to correct string', () {
      expect(JobMapper.jobStatusToString(JobStatus.created), 'created');
      expect(JobMapper.jobStatusToString(JobStatus.submitted), 'submitted');
      expect(
        JobMapper.jobStatusToString(JobStatus.transcribing),
        'transcribing',
      );
      expect(JobMapper.jobStatusToString(JobStatus.transcribed), 'transcribed');
      expect(JobMapper.jobStatusToString(JobStatus.generating), 'generating');
      expect(JobMapper.jobStatusToString(JobStatus.generated), 'generated');
      expect(JobMapper.jobStatusToString(JobStatus.completed), 'completed');
      expect(JobMapper.jobStatusToString(JobStatus.error), 'error');
    });

    // --- Test _stringToJobStatus (assuming it becomes accessible or we test via public methods) ---
    test('_stringToJobStatus should convert known string to correct enum', () {
      expect(JobMapper.stringToJobStatus('created'), JobStatus.created);
      expect(JobMapper.stringToJobStatus('submitted'), JobStatus.submitted);
      expect(
        JobMapper.stringToJobStatus('transcribing'),
        JobStatus.transcribing,
      );
      expect(JobMapper.stringToJobStatus('transcribed'), JobStatus.transcribed);
      expect(JobMapper.stringToJobStatus('generating'), JobStatus.generating);
      expect(JobMapper.stringToJobStatus('generated'), JobStatus.generated);
      expect(JobMapper.stringToJobStatus('completed'), JobStatus.completed);
      expect(JobMapper.stringToJobStatus('error'), JobStatus.error);
    });

    test(
      '_stringToJobStatus should return JobStatus.error for unknown or null string',
      () {
        expect(JobMapper.stringToJobStatus('unknown_status'), JobStatus.error);
        expect(JobMapper.stringToJobStatus(''), JobStatus.error);
        // expect(JobMapper.stringToJobStatus(null), JobStatus.error); // Depends on nullability
      },
    );
  });

  group('JobMapper: Hive Model <-> Entity', () {
    test('should map JobHiveModel to Job entity correctly', () {
      // Arrange
      final now = DateTime.now();
      final lastSyncTime = now.subtract(const Duration(minutes: 5));
      final localId = uuid.v4();
      final serverId = 'server-id-from-hive';
      final hiveModel = JobHiveModel(
        localId: localId,
        serverId: serverId,
        userId: 'user-from-hive',
        status: JobStatus.generating.index, // Stored as int
        syncStatus: SyncStatus.error.index, // Stored as int
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
        displayTitle: 'Hive Title',
        displayText: 'Hive Text',
        errorCode: 404,
        errorMessage: 'Not Found',
        audioFilePath: 'hive/path/audio.aac',
        text: 'Hive Job Text',
        additionalText: 'Hive Additional',
        retryCount: 3, // Test retry count mapping
        lastSyncAttemptAt:
            lastSyncTime.toIso8601String(), // Test datetime mapping
      );

      // Act
      final jobEntity = JobMapper.fromHiveModel(hiveModel);

      // Assert
      expect(jobEntity, isA<Job>());
      expect(jobEntity.localId, localId);
      expect(jobEntity.serverId, serverId);
      expect(jobEntity.userId, 'user-from-hive');
      expect(jobEntity.status, JobStatus.generating);
      expect(jobEntity.syncStatus, SyncStatus.error);
      expect(jobEntity.createdAt.toIso8601String(), now.toIso8601String());
      expect(jobEntity.updatedAt.toIso8601String(), now.toIso8601String());
      expect(jobEntity.displayTitle, 'Hive Title');
      expect(jobEntity.displayText, 'Hive Text');
      expect(jobEntity.errorCode, 404);
      expect(jobEntity.errorMessage, 'Not Found');
      expect(jobEntity.audioFilePath, 'hive/path/audio.aac');
      expect(jobEntity.text, 'Hive Job Text');
      expect(jobEntity.additionalText, 'Hive Additional');
      expect(jobEntity.retryCount, 3); // Verify retry count
      expect(
        jobEntity.lastSyncAttemptAt?.toIso8601String(),
        lastSyncTime.toIso8601String(),
      ); // Verify datetime
    });

    test(
      'should map JobHiveModel with null retry/syncTime to Job entity with defaults',
      () {
        // Arrange
        final now = DateTime.now();
        final localId = uuid.v4();
        final hiveModel = JobHiveModel(
          localId: localId,
          userId: 'user-defaults',
          status: JobStatus.created.index,
          syncStatus: SyncStatus.pending.index,
          createdAt: now.toIso8601String(),
          updatedAt: now.toIso8601String(),
          // retryCount and lastSyncAttemptAt are null
        );

        // Act
        final jobEntity = JobMapper.fromHiveModel(hiveModel);

        // Assert
        expect(jobEntity.retryCount, 0); // Should default to 0
        expect(jobEntity.lastSyncAttemptAt, isNull); // Should be null
        expect(jobEntity.syncStatus, SyncStatus.pending);
        expect(jobEntity.status, JobStatus.created);
      },
    );

    test('should map Job entity back to JobHiveModel correctly', () {
      // Arrange
      final now = DateTime.now();
      final lastSyncTime = now.subtract(const Duration(hours: 1));
      final localId = uuid.v4();
      final serverId = 'server-id-to-hive';
      final jobEntity = Job(
        localId: localId,
        serverId: serverId,
        userId: 'user-to-hive',
        status: JobStatus.completed,
        syncStatus: SyncStatus.synced,
        createdAt: now,
        updatedAt: now,
        displayTitle: 'Entity Title',
        displayText: 'Entity Text',
        errorCode: null,
        errorMessage: null,
        audioFilePath: 'entity/path/audio.ogg',
        text: 'Entity Job Text',
        additionalText: 'Entity Additional',
        retryCount: 5, // Test retry count mapping
        lastSyncAttemptAt: lastSyncTime, // Test datetime mapping
      );

      // Act
      final hiveModel = JobMapper.toHiveModel(jobEntity);

      // Assert
      expect(hiveModel, isA<JobHiveModel>());
      expect(hiveModel.localId, localId);
      expect(hiveModel.serverId, serverId);
      expect(hiveModel.userId, 'user-to-hive');
      expect(hiveModel.status, JobStatus.completed.index);
      expect(hiveModel.syncStatus, SyncStatus.synced.index);
      expect(hiveModel.createdAt, now.toIso8601String());
      expect(hiveModel.updatedAt, now.toIso8601String());
      expect(hiveModel.displayTitle, 'Entity Title');
      expect(hiveModel.displayText, 'Entity Text');
      expect(hiveModel.errorCode, null);
      expect(hiveModel.errorMessage, null);
      expect(hiveModel.audioFilePath, 'entity/path/audio.ogg');
      expect(hiveModel.text, 'Entity Job Text');
      expect(hiveModel.additionalText, 'Entity Additional');
      expect(hiveModel.retryCount, 5); // Verify retry count
      expect(
        hiveModel.lastSyncAttemptAt,
        lastSyncTime.toIso8601String(),
      ); // Verify datetime string
    });

    test(
      'should map Job entity with null retry/syncTime back to JobHiveModel',
      () {
        // Arrange
        final now = DateTime.now();
        final localId = uuid.v4();
        final jobEntity = Job(
          localId: localId,
          serverId: null,
          userId: 'user-nulls-to-hive',
          status: JobStatus.created,
          syncStatus: SyncStatus.pending,
          createdAt: now,
          updatedAt: now,
          // retryCount defaults to 0 in entity
          lastSyncAttemptAt: null, // Explicitly null
        );

        // Act
        final hiveModel = JobMapper.toHiveModel(jobEntity);

        // Assert
        expect(hiveModel.retryCount, 0); // Should be 0
        expect(hiveModel.lastSyncAttemptAt, isNull); // Should be null
        expect(hiveModel.syncStatus, SyncStatus.pending.index);
        expect(hiveModel.status, JobStatus.created.index);
      },
    );

    test('should map a list of JobHiveModels to a list of Job entities', () {
      // Arrange
      final now1 = DateTime.now();
      final now2 = now1.add(const Duration(minutes: 5));
      final lastSyncTime1 = now1.subtract(const Duration(days: 1));
      final localId1 = uuid.v4();
      final serverId1 = 'server1';
      final localId2 = uuid.v4(); // No serverId for second job

      final hiveList = [
        JobHiveModel(
          localId: localId1,
          serverId: serverId1,
          userId: 'user1',
          status: JobStatus.completed.index,
          syncStatus: SyncStatus.synced.index,
          createdAt: now1.toIso8601String(),
          updatedAt: now1.toIso8601String(),
          retryCount: 1,
          lastSyncAttemptAt: lastSyncTime1.toIso8601String(),
        ),
        JobHiveModel(
          localId: localId2,
          serverId: null,
          userId: 'user2',
          status: JobStatus.created.index,
          syncStatus: SyncStatus.pending.index,
          createdAt: now2.toIso8601String(),
          updatedAt: now2.toIso8601String(),
          audioFilePath: 'path/local.wav',
          // retryCount and lastSyncAttemptAt are null
        ),
      ];

      // Act
      final entityList = JobMapper.fromHiveModelList(hiveList);

      // Assert
      expect(entityList, isA<List<Job>>());
      expect(entityList.length, 2);

      expect(entityList[0].localId, localId1);
      expect(entityList[0].serverId, serverId1);
      expect(entityList[0].status, JobStatus.completed);
      expect(entityList[0].syncStatus, SyncStatus.synced);
      expect(entityList[0].createdAt.toIso8601String(), now1.toIso8601String());
      expect(entityList[0].retryCount, 1);
      expect(
        entityList[0].lastSyncAttemptAt?.toIso8601String(),
        lastSyncTime1.toIso8601String(),
      );

      expect(entityList[1].localId, localId2);
      expect(entityList[1].serverId, isNull);
      expect(entityList[1].status, JobStatus.created);
      expect(entityList[1].syncStatus, SyncStatus.pending);
      expect(entityList[1].createdAt.toIso8601String(), now2.toIso8601String());
      expect(entityList[1].audioFilePath, 'path/local.wav');
      expect(entityList[1].retryCount, 0); // Default
      expect(entityList[1].lastSyncAttemptAt, isNull);
    });

    test('should map a list of Job entities to a list of JobHiveModels', () {
      // Arrange
      final now1 = DateTime.now();
      final now2 = now1.add(const Duration(minutes: 5));
      final lastSyncTime1 = now1.subtract(const Duration(days: 1));
      final localId1 = uuid.v4();
      final serverId1 = 'server1-to-hive';
      final localId2 = uuid.v4(); // No serverId for second job

      final entityList = [
        Job(
          localId: localId1,
          serverId: serverId1,
          userId: 'user1-to-hive',
          status: JobStatus.error,
          syncStatus: SyncStatus.error,
          createdAt: now1,
          updatedAt: now1,
          errorMessage: 'Failed hard',
          retryCount: 4,
          lastSyncAttemptAt: lastSyncTime1,
        ),
        Job(
          localId: localId2,
          serverId: null,
          userId: 'user2-local-to-hive',
          status: JobStatus.submitted,
          syncStatus: SyncStatus.pending,
          createdAt: now2,
          updatedAt: now2,
          audioFilePath: 'path/local-entity.wav',
          // retryCount defaults to 0, lastSyncAttemptAt is null
        ),
      ];

      // Act
      final hiveList = JobMapper.toHiveModelList(entityList);

      // Assert
      expect(hiveList, isA<List<JobHiveModel>>());
      expect(hiveList.length, 2);

      expect(hiveList[0].localId, localId1);
      expect(hiveList[0].serverId, serverId1);
      expect(hiveList[0].status, JobStatus.error.index);
      expect(hiveList[0].syncStatus, SyncStatus.error.index);
      expect(hiveList[0].createdAt, now1.toIso8601String());
      expect(hiveList[0].errorMessage, 'Failed hard');
      expect(hiveList[0].retryCount, 4);
      expect(hiveList[0].lastSyncAttemptAt, lastSyncTime1.toIso8601String());

      expect(hiveList[1].localId, localId2);
      expect(hiveList[1].serverId, isNull);
      expect(hiveList[1].status, JobStatus.submitted.index);
      expect(hiveList[1].syncStatus, SyncStatus.pending.index);
      expect(hiveList[1].createdAt, now2.toIso8601String());
      expect(hiveList[1].audioFilePath, 'path/local-entity.wav');
      expect(hiveList[1].retryCount, 0); // Default
      expect(hiveList[1].lastSyncAttemptAt, isNull);
    });
  });

  // TODO: Add tests for the main mapping functions (from/to HiveModel, from/to ApiDto)
  // verifying they use the status conversion correctly.
}
