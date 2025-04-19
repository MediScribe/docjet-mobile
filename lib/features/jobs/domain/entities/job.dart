import 'package:equatable/equatable.dart'; // Add Equatable for value comparison
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart'; // Import the enum
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart'; // Import SyncStatus

// Represents a single recording job and its metadata. This is the pure Domain Entity with no persistence concerns.
class Job extends Equatable {
  final String localId; // UUID
  final String? serverId; // New: Nullable server-assigned ID
  final JobStatus status; // USE ENUM INSTEAD OF STRING
  final SyncStatus syncStatus; // New: Sync status
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
  final int retryCount; // New: Number of sync retry attempts
  final DateTime? lastSyncAttemptAt; // New: Timestamp of the last sync attempt

  const Job({
    required this.localId,
    this.serverId, // New: Optional server ID
    required this.status, // USE ENUM INSTEAD OF STRING
    required this.syncStatus, // New: Required
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
    this.retryCount = 0, // New: Default to 0
    this.lastSyncAttemptAt, // New: Nullable
  });

  // Equatable props for value comparison
  @override
  List<Object?> get props => [
    localId,
    serverId, // New
    status, // USE ENUM INSTEAD OF STRING
    syncStatus, // New
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
    retryCount, // New
    lastSyncAttemptAt, // New
  ];

  // Optional: Add copyWith if needed for state management
  Job copyWith({
    String? localId,
    String? serverId, // New
    JobStatus? status, // USE ENUM INSTEAD OF STRING
    SyncStatus? syncStatus, // New
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
    int? retryCount, // New
    DateTime? lastSyncAttemptAt, // New
  }) {
    return Job(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId, // New
      status: status ?? this.status, // USE ENUM INSTEAD OF STRING
      syncStatus: syncStatus ?? this.syncStatus, // New
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
      retryCount: retryCount ?? this.retryCount, // New
      lastSyncAttemptAt: lastSyncAttemptAt ?? this.lastSyncAttemptAt, // New
    );
  }
}
