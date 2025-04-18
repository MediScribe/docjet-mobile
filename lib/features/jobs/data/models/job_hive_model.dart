import 'package:hive/hive.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';

part 'job_hive_model.g.dart'; // Hive generator directive

// Data Transfer Object (DTO) specifically for storing Job data in Hive.
// Includes Hive annotations (`@HiveType`, `@HiveField`) required for persistence,
// separating these details from the pure domain `Job` entity.
@HiveType(typeId: 0) // Use the same typeId as the original Job attempt
class JobHiveModel extends HiveObject {
  @HiveField(0)
  late String id; // UUID

  @HiveField(1)
  late String status; // Stored as String, but mapped to/from JobStatus enum

  @HiveField(2)
  late DateTime createdAt;

  @HiveField(3)
  late DateTime updatedAt;

  @HiveField(4)
  late String userId; // UUID

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
  SyncStatus syncStatus = SyncStatus.synced; // Default to synced

  // Default constructor (required by Hive for generation)
  JobHiveModel();

  // Helper method to get status as enum
  JobStatus getStatusEnum() {
    return JobStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == status.toLowerCase(),
      orElse: () => JobStatus.error,
    );
  }

  // Helper method to set status from enum
  void setStatusEnum(JobStatus jobStatus) {
    status = jobStatus.name;
  }
}
