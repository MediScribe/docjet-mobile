import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_api_dto.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:uuid/uuid.dart';

/// Mapper for transforming between Job domain entities and data models (DTOs).
/// Note: Does NOT generate localIds; expects them to be provided or handled upstream.
class JobMapper {
  // Private constructor to prevent instantiation
  JobMapper._();

  // Logger setup
  static final Logger _logger = LoggerFactory.getLogger(JobMapper);
  static final String _tag = logTag(JobMapper);
  static final Uuid _uuid = const Uuid();

  /// Maps a JobHiveModel to a JobEntity.
  static Job fromHiveModel(JobHiveModel model) {
    final jobStatus = _intToJobStatus(model.status);
    final syncStatus = _intToSyncStatus(model.syncStatus);
    DateTime? createdAt, updatedAt, lastSyncAttemptAt;
    try {
      createdAt = DateTime.tryParse(model.createdAt ?? '');
      updatedAt = DateTime.tryParse(model.updatedAt ?? '');
      // Parse nullable DateTime from ISO string
      lastSyncAttemptAt =
          model.lastSyncAttemptAt != null
              ? DateTime.tryParse(model.lastSyncAttemptAt!)
              : null;
    } catch (e) {
      _logger.e(
        '$_tag Error parsing dates from Hive model: ${model.localId}',
        error: e,
      );
    }

    return Job(
      localId: model.localId,
      serverId: model.serverId,
      status: jobStatus,
      syncStatus: syncStatus,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      userId: model.userId ?? '',
      displayTitle: model.displayTitle,
      displayText: model.displayText,
      errorCode: model.errorCode,
      errorMessage: model.errorMessage,
      audioFilePath: model.audioFilePath,
      text: model.text,
      additionalText: model.additionalText,
      // Default retryCount to 0 if null in Hive model
      retryCount: model.retryCount ?? 0,
      lastSyncAttemptAt: lastSyncAttemptAt,
    );
  }

  /// Maps a JobEntity to a JobHiveModel.
  static JobHiveModel toHiveModel(Job entity) {
    final model = JobHiveModel(
      localId: entity.localId,
      serverId: entity.serverId,
      userId: entity.userId,
      status: entity.status.index,
      syncStatus: entity.syncStatus.index,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
      displayTitle: entity.displayTitle,
      displayText: entity.displayText,
      errorCode: entity.errorCode,
      errorMessage: entity.errorMessage,
      audioFilePath: entity.audioFilePath,
      text: entity.text,
      additionalText: entity.additionalText,
      retryCount: entity.retryCount,
      // Store nullable DateTime as ISO string or null
      lastSyncAttemptAt: entity.lastSyncAttemptAt?.toIso8601String(),
    );
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
  /// Requires a localId to be generated/provided externally if missing.
  /// Assumes data from API is always synced.
  static Job fromApiDto(JobApiDTO dto, {String? localId}) {
    final jobStatus = stringToJobStatus(dto.jobStatus);
    // Data from API is considered the source of truth, hence synced.
    final syncStatus = SyncStatus.synced;
    // Use provided localId, or generate a new one ONLY if needed (should be rare)
    final effectiveLocalId = localId ?? _uuid.v4();
    if (localId == null) {
      _logger.w(
        '$_tag No localId provided for JobApiDTO mapping (serverId: ${dto.id}), generating new UUID. This might indicate an issue upstream.',
      );
    }

    return Job(
      localId: effectiveLocalId,
      serverId: dto.id,
      status: jobStatus,
      syncStatus: syncStatus,
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
  /// Uses serverId for DTO's id if available, otherwise uses localId (for creation).
  static JobApiDTO toApiDto(Job entity) {
    return JobApiDTO(
      id: entity.serverId ?? entity.localId,
      userId: entity.userId,
      jobStatus: jobStatusToString(entity.status),
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
  /// Requires localIds to be handled externally (e.g., fetched from local storage).
  static List<Job> fromApiDtoList(
    List<JobApiDTO> dtos, {
    Map<String, String>? serverIdToLocalIdMap,
  }) {
    // TODO: Enhance mapper with improved support for dual-ID system (localId/serverId)
    return dtos.map((dto) {
      final localId = serverIdToLocalIdMap?[dto.id];
      return fromApiDto(dto, localId: localId);
    }).toList();
  }

  /// Converts an integer index back to a JobStatus enum.
  static JobStatus _intToJobStatus(int? index) {
    if (index == null || index < 0 || index >= JobStatus.values.length) {
      _logger.w('$_tag Invalid JobStatus index: $index, defaulting to error');
      return JobStatus.error;
    }
    return JobStatus.values[index];
  }

  /// Converts an integer index back to a SyncStatus enum.
  static SyncStatus _intToSyncStatus(int? index) {
    if (index == null || index < 0 || index >= SyncStatus.values.length) {
      _logger.w(
        '$_tag Invalid SyncStatus index: $index, defaulting to pending',
      );
      // Defaulting to pending might be safer than error for sync status
      return SyncStatus.pending;
    }
    return SyncStatus.values[index];
  }
}
