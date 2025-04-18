import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_api_dto.dart';

// Maps between the domain Job entity, Hive JobHiveModel DTO, and API JobApiDTO
class JobMapper {
  // Cannot be instantiated
  JobMapper._();

  static JobHiveModel toHiveModel(Job job) {
    // Create an empty model first, then assign fields.
    // This is often necessary because HiveObject properties might not be assignable via constructor.
    final model =
        JobHiveModel()
          ..id = job.id
          ..status = job.status
          ..createdAt = job.createdAt
          ..updatedAt = job.updatedAt
          ..userId = job.userId
          ..displayTitle = job.displayTitle
          ..displayText = job.displayText
          ..errorCode = job.errorCode
          ..errorMessage = job.errorMessage
          ..audioFilePath = job.audioFilePath
          ..text = job.text
          ..additionalText = job.additionalText;
    return model;
  }

  static Job fromHiveModel(JobHiveModel model) {
    return Job(
      id: model.id,
      status: model.status,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      userId: model.userId,
      displayTitle: model.displayTitle,
      displayText: model.displayText,
      errorCode: model.errorCode,
      errorMessage: model.errorMessage,
      audioFilePath: model.audioFilePath,
      text: model.text,
      additionalText: model.additionalText,
    );
  }

  static List<Job> fromHiveModelList(List<JobHiveModel> models) {
    return models.map(fromHiveModel).toList();
  }

  // We might not need this direction often, but good to have
  static List<JobHiveModel> toHiveModelList(List<Job> jobs) {
    return jobs.map(toHiveModel).toList();
  }

  // --- API DTO Mapping ---
  static Job fromApiDto(JobApiDTO dto) {
    return Job(
      id: dto.id,
      status: dto.jobStatus, // Map string status directly for now
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
      userId: dto.userId,
      displayTitle: dto.displayTitle,
      displayText: dto.displayText,
      errorCode: dto.errorCode,
      errorMessage: dto.errorMessage,
      text: dto.text,
      additionalText: dto.additionalText,
      audioFilePath:
          null, // API DTO doesn't contain audio file path information
    );
  }

  static List<Job> fromApiDtoList(List<JobApiDTO> dtos) {
    // Handle null or empty lists gracefully
    if (dtos.isEmpty) {
      return [];
    }
    // Map each DTO in the list using the fromApiDto method
    return dtos.map(fromApiDto).toList();
  }

  // --- Reverse API DTO Mapping ---
  static JobApiDTO toApiDto(Job job) {
    return JobApiDTO(
      id: job.id,
      userId: job.userId,
      jobStatus: job.status, // Map string status directly
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
      displayTitle: job.displayTitle,
      displayText: job.displayText,
      errorCode: job.errorCode,
      errorMessage: job.errorMessage,
      text: job.text,
      additionalText: job.additionalText,
      // Note: audioFilePath from Job entity is not sent to the API DTO
    );
  }
}
