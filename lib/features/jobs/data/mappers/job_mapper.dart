import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_api_dto.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';

/// Mapper for transforming between Job domain entities and data models (DTOs).
class JobMapper {
  // Private constructor to prevent instantiation
  JobMapper._();

  // Logger setup
  static final Logger _logger = LoggerFactory.getLogger(JobMapper);
  static final String _tag = logTag(JobMapper);

  /// Maps a JobHiveModel to a JobEntity.
  static Job fromHiveModel(JobHiveModel model) {
    final status = stringToJobStatus(model.status);
    return Job(
      localId: model.localId,
      status: status,
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

  /// Maps a JobEntity to a JobHiveModel.
  static JobHiveModel toHiveModel(Job entity) {
    final model =
        JobHiveModel()
          ..localId = entity.localId
          ..status = entity.status.name
          ..createdAt = entity.createdAt
          ..updatedAt = entity.updatedAt
          ..userId = entity.userId
          ..displayTitle = entity.displayTitle
          ..displayText = entity.displayText
          ..errorCode = entity.errorCode
          ..errorMessage = entity.errorMessage
          ..audioFilePath = entity.audioFilePath
          ..text = entity.text
          ..additionalText = entity.additionalText;
    return model;
  }

  /// Maps a `List<JobHiveModel>` to a `List<Job>`
  static List<Job> fromHiveModelList(List<JobHiveModel> models) {
    return models.map((model) => fromHiveModel(model)).toList();
  }

  /// Maps a `List<Job>` to a `List<JobHiveModel>`
  static List<JobHiveModel> toHiveModelList(List<Job> entities) {
    return entities.map((entity) => toHiveModel(entity)).toList();
  }

  /// Converts a status string (from API/Hive) to JobStatus enum.
  static JobStatus stringToJobStatus(String? statusStr) {
    if (statusStr == null || statusStr.isEmpty) {
      _logger.w('$_tag Null or empty status string, defaulting to error');
      return JobStatus.error;
    }

    try {
      // Try to find a matching enum by name (case-insensitive)
      return JobStatus.values.firstWhere(
        (status) => status.name.toLowerCase() == statusStr.toLowerCase(),
        orElse: () {
          _logger.w(
            '$_tag Unknown status string: "$statusStr", defaulting to error',
          );
          return JobStatus.error;
        },
      );
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Error converting status string "$statusStr" to enum',
        error: e,
        stackTrace: stackTrace,
      );
      return JobStatus.error;
    }
  }

  /// Converts a JobStatus enum to a string representation.
  /// Simply returns the lowercase name of the enum value.
  static String jobStatusToString(JobStatus status) {
    return status.name;
  }

  /// Maps a JobApiDTO to a JobEntity.
  static Job fromApiDto(JobApiDTO dto) {
    final status = stringToJobStatus(dto.jobStatus);
    return Job(
      localId: dto.id,
      status: status,
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
      userId: dto.userId,
      displayTitle: dto.displayTitle,
      displayText: dto.displayText,
      errorCode: dto.errorCode,
      errorMessage: dto.errorMessage,
      text: dto.text,
      additionalText: dto.additionalText,
    );
  }

  /// Maps a JobEntity to a JobApiDTO.
  static JobApiDTO toApiDto(Job entity) {
    return JobApiDTO(
      id: entity.localId,
      userId: entity.userId,
      jobStatus: entity.status.name,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      displayTitle: entity.displayTitle,
      displayText: entity.displayText,
      errorCode: entity.errorCode,
      errorMessage: entity.errorMessage,
      text: entity.text,
      additionalText: entity.additionalText,
    );
  }

  /// Maps a `List<JobApiDTO>` to a `List<Job>`
  static List<Job> fromApiDtoList(List<JobApiDTO> dtos) {
    return dtos.map((dto) => fromApiDto(dto)).toList();
  }
}
