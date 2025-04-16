import 'package:equatable/equatable.dart'; // Add Equatable for value comparison

// Represents a single recording job and its metadata. This is the pure Domain Entity with no persistence concerns.
class Job extends Equatable {
  final String id; // UUID
  final String status; // Consider using an Enum here later
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
    required this.id,
    required this.status,
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
    id,
    status,
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
    String? id,
    String? status,
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
      id: id ?? this.id,
      status: status ?? this.status,
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
