import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'job_api_dto.g.dart'; // For json_serializable

@JsonSerializable()
class JobApiDTO extends Equatable {
  @JsonKey(name: 'id')
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'job_status') // Map API field name
  final String jobStatus;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'display_title')
  final String? displayTitle;
  @JsonKey(name: 'display_text')
  final String? displayText;
  @JsonKey(name: 'error_code')
  final int? errorCode;
  @JsonKey(name: 'error_message')
  final String? errorMessage;
  @JsonKey(name: 'text')
  final String? text;
  @JsonKey(name: 'additional_text')
  final String? additionalText;

  const JobApiDTO({
    required this.id,
    required this.userId,
    required this.jobStatus,
    required this.createdAt,
    required this.updatedAt,
    this.displayTitle,
    this.displayText,
    this.errorCode,
    this.errorMessage,
    this.text,
    this.additionalText,
  });

  // Factory constructor for creating a new JobApiDTO instance from a map.
  factory JobApiDTO.fromJson(Map<String, dynamic> json) =>
      _$JobApiDTOFromJson(json); // Use generated function

  // Method for converting a JobApiDTO instance to a map.
  Map<String, dynamic> toJson() =>
      _$JobApiDTOToJson(this); // Use generated function

  @override
  List<Object?> get props => [
    id,
    userId,
    jobStatus,
    createdAt,
    updatedAt,
    displayTitle,
    displayText,
    errorCode,
    errorMessage,
    text,
    additionalText,
  ];
}
