import 'package:hive/hive.dart';
// import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart'; // No longer needed directly
// import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart'; // No longer needed directly

part 'job_hive_model.g.dart'; // Hive generator directive

// Data Transfer Object (DTO) specifically for storing Job data in Hive.
// Includes Hive annotations (`@HiveType`, `@HiveField`) required for persistence,
// separating these details from the pure domain `Job` entity.
@HiveType(typeId: 0) // Use the same typeId as the original Job attempt
class JobHiveModel extends HiveObject {
  @HiveField(0)
  late String localId; // UUID

  @HiveField(1)
  int? status; // Stored as enum index (int)

  @HiveField(2)
  String? createdAt; // Store as ISO8601 String

  @HiveField(3)
  String? updatedAt; // Store as ISO8601 String

  @HiveField(4)
  String? userId; // UUID - Make nullable for safety

  @HiveField(5)
  String? displayTitle;

  @HiveField(6)
  String? displayText;

  @HiveField(7)
  int? errorCode;

  @HiveField(8)
  String? errorMessage;

  @HiveField(9)
  String? audioFilePath;

  @HiveField(10)
  String? text;

  @HiveField(11)
  String? additionalText;

  @HiveField(12)
  int? syncStatus; // Stored as enum index (int)

  @HiveField(13) // New field for server-assigned ID
  String? serverId;

  // Constructor with required fields and optionals
  JobHiveModel({
    required this.localId,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.displayTitle,
    this.displayText,
    this.errorCode,
    this.errorMessage,
    this.audioFilePath,
    this.text,
    this.additionalText,
    this.syncStatus,
    this.serverId,
  });

  // Default constructor (required by Hive for generation) - keep it for generator
  // JobHiveModel();

  // Remove helper methods - no longer needed
  // Helper method to get status as enum
  // JobStatus getStatusEnum() { ... }
  // Helper method to set status from enum
  // void setStatusEnum(JobStatus jobStatus) { ... }
}
