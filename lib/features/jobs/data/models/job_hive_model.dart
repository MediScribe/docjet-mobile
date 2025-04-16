import 'package:hive/hive.dart';

part 'job_hive_model.g.dart'; // Hive generator directive

// Data Transfer Object (DTO) specifically for storing Job data in Hive.
// Includes Hive annotations (`@HiveType`, `@HiveField`) required for persistence,
// separating these details from the pure domain `Job` entity.
@HiveType(typeId: 0) // Use the same typeId as the original Job attempt
class JobHiveModel extends HiveObject {
  @HiveField(0)
  late String id; // UUID

  @HiveField(1)
  late String status;

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

  // Default constructor (required by Hive for generation)
  JobHiveModel();

  // Optional: Add a constructor to initialize fields if needed,
  // but Hive primarily uses the generated adapter for instantiation.
}
