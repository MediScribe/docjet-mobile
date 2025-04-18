import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_api_dto.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logger

// Maps between the domain Job entity, Hive JobHiveModel DTO, and API JobApiDTO
class JobMapper {
  // Cannot be instantiated
  JobMapper._();

  // Logger setup
  static final Logger _logger = LoggerFactory.getLogger(JobMapper);
  static final String _tag = logTag(JobMapper);

  // --- Status Conversion Helpers ---

  /// Converts JobStatus enum to its string representation for storage/API.
  static String jobStatusToString(JobStatus status) {
    return status
        .name; // Use the enum's built-in name property (e.g., JobStatus.completed.name == 'completed')
  }

  /// Converts a status string (from API/Hive) to JobStatus enum.
  /// Defaults to JobStatus.error if the string is unknown or invalid.
  static JobStatus stringToJobStatus(String? statusString) {
    if (statusString == null) return JobStatus.error;
    try {
      return JobStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == statusString.toLowerCase(),
      );
    } catch (e) {
      // Log the error properly
      _logger.e(
        '$_tag Unknown JobStatus string received: $statusString. Defaulting to error.',
        error: e,
      );
      return JobStatus.error;
    }
  }

  // --- Hive Model Mapping ---

  static JobHiveModel toHiveModel(Job job) {
    final model =
        JobHiveModel()
          ..id = job.id
          ..status = jobStatusToString(job.status) // Use helper
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
    // Note: syncStatus is managed separately in the DataSource/Repository
    return model;
  }

  static Job fromHiveModel(JobHiveModel model) {
    return Job(
      id: model.id,
      status: stringToJobStatus(model.status), // Use helper
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

  static List<JobHiveModel> toHiveModelList(List<Job> jobs) {
    return jobs.map(toHiveModel).toList();
  }

  // --- API DTO Mapping ---
  static Job fromApiDto(JobApiDTO dto) {
    return Job(
      id: dto.id,
      status: stringToJobStatus(dto.jobStatus), // Use helper
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
    if (dtos.isEmpty) {
      return [];
    }
    return dtos.map(fromApiDto).toList();
  }

  static JobApiDTO toApiDto(Job job) {
    return JobApiDTO(
      id: job.id,
      userId: job.userId,
      jobStatus: jobStatusToString(job.status), // Use helper
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
      displayTitle: job.displayTitle,
      displayText: job.displayText,
      errorCode: job.errorCode,
      errorMessage: job.errorMessage,
      text: job.text,
      additionalText: job.additionalText,
    );
  }
}
