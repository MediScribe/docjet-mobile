import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_api_dto.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
// import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart'; // Removed - Status is String for now

void main() {
  group('JobMapper', () {
    test('should map JobApiDTO to Job entity correctly', () {
      // Arrange: Create a sample JobApiDTO
      final now = DateTime.now();
      final jobApiDto = JobApiDTO(
        id: 'job-123',
        userId: 'user-456',
        jobStatus:
            'COMPLETED', // API uses string status, Domain Entity also uses String currently
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
      expect(jobEntity.id, 'job-123');
      expect(jobEntity.userId, 'user-456');
      expect(jobEntity.status, 'COMPLETED'); // Asserting String status
      expect(jobEntity.createdAt, now);
      expect(jobEntity.updatedAt, now);
      expect(jobEntity.displayTitle, 'Test Job Title');
      expect(jobEntity.displayText, 'Test Job Text');
      expect(jobEntity.errorCode, null);
      expect(jobEntity.errorMessage, null);
      expect(jobEntity.text, 'Transcribed text');
      expect(jobEntity.additionalText, 'Additional info');
      expect(jobEntity.audioFilePath, null); // DTO doesn't have this field
    });

    test('should map a list of JobApiDTOs to a list of Job entities', () {
      // Arrange: Create a list of sample JobApiDTOs
      final now1 = DateTime.now();
      final now2 = now1.add(const Duration(minutes: 1));
      final dtoList = [
        JobApiDTO(
          id: 'job-1',
          userId: 'user-1',
          jobStatus: 'PENDING',
          createdAt: now1,
          updatedAt: now1,
        ),
        JobApiDTO(
          id: 'job-2',
          userId: 'user-1',
          jobStatus: 'COMPLETED',
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
      expect(jobList[0].id, 'job-1');
      expect(jobList[0].status, 'PENDING');
      expect(jobList[0].createdAt, now1);
      expect(jobList[0].displayTitle, isNull);

      // Check second job
      expect(jobList[1].id, 'job-2');
      expect(jobList[1].status, 'COMPLETED');
      expect(jobList[1].updatedAt, now2);
      expect(jobList[1].displayTitle, 'Completed Job');
      expect(jobList[1].text, 'Some text');
    });

    test('should map Job entity back to JobApiDTO correctly', () {
      // Arrange: Create a sample Job entity
      final now = DateTime.now();
      final jobEntity = Job(
        id: 'job-789',
        userId: 'user-101',
        status: 'PROCESSING', // Domain uses String status currently
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
      );

      // Act: Call the (non-existent) reverse mapper function
      // This line WILL cause a compile error initially (RED step)
      final jobApiDto = JobMapper.toApiDto(jobEntity);

      // Assert: Check if the JobApiDTO has the correct values
      expect(jobApiDto, isA<JobApiDTO>());
      expect(jobApiDto.id, 'job-789');
      expect(jobApiDto.userId, 'user-101');
      expect(jobApiDto.jobStatus, 'PROCESSING'); // DTO uses string status
      expect(jobApiDto.createdAt, now);
      expect(jobApiDto.updatedAt, now);
      expect(jobApiDto.displayTitle, 'Update Test Job');
      expect(jobApiDto.displayText, null);
      expect(jobApiDto.errorCode, 123);
      expect(jobApiDto.errorMessage, 'Processing Error');
      expect(jobApiDto.text, 'Submitted text');
      expect(jobApiDto.additionalText, null);
      // Note: audioFilePath is not part of JobApiDTO
    });

    // TODO: Add tests for edge cases (e.g., empty list, list with errors)
  });
}
