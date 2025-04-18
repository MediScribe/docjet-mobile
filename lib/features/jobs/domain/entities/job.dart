import 'package:equatable/equatable.dart'; // Add Equatable for value comparison
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart'; // Import the enum

// Represents a single recording job and its metadata. This is the pure Domain Entity with no persistence concerns.
class Job extends Equatable {
  final String localId; // UUID
  final String? serverId; // New: Nullable server-assigned ID
  final JobStatus status; // USE ENUM INSTEAD OF STRING
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId; // UUID
  final String? displayTitle; // Short UI label
  final String? displayText; // Transcript snippet for UI preview
  final int? errorCode; // Optional error code
  final String? errorMessage; // Optional error message
  final String?
  audioFilePath; // Path to the locally stored audio file before upload
  final String? text; // Optional text submitted with audio
  final String? additionalText; // Optional extra metadata

  const Job({
    required this.localId,
    this.serverId, // New: Optional server ID
    required this.status, // USE ENUM INSTEAD OF STRING
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    this.displayTitle,
    this.displayText,
    this.errorCode,
    this.errorMessage,
    this.audioFilePath,
    this.text,
    this.additionalText,
  });

  // Equatable props for value comparison
  @override
  List<Object?> get props => [
    localId,
    serverId, // New
    status, // USE ENUM INSTEAD OF STRING
    createdAt,
    updatedAt,
    userId,
    displayTitle,
    displayText,
    errorCode,
    errorMessage,
    audioFilePath,
    text,
    additionalText,
  ];

  // Optional: Add copyWith if needed for state management
  Job copyWith({
    String? localId,
    String? serverId, // New
    JobStatus? status, // USE ENUM INSTEAD OF STRING
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    String? displayTitle,
    String? displayText,
    int? errorCode,
    String? errorMessage,
    String? audioFilePath,
    String? text,
    String? additionalText,
  }) {
    return Job(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId, // New
      status: status ?? this.status, // USE ENUM INSTEAD OF STRING
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      displayTitle: displayTitle ?? this.displayTitle,
      displayText: displayText ?? this.displayText,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      text: text ?? this.text,
      additionalText: additionalText ?? this.additionalText,
    );
  }
}
