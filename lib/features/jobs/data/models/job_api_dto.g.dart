// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_api_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobApiDTO _$JobApiDTOFromJson(Map<String, dynamic> json) => JobApiDTO(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      jobStatus: json['job_status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      displayTitle: json['display_title'] as String?,
      displayText: json['display_text'] as String?,
      errorCode: (json['error_code'] as num?)?.toInt(),
      errorMessage: json['error_message'] as String?,
      text: json['text'] as String?,
      additionalText: json['additional_text'] as String?,
    );

Map<String, dynamic> _$JobApiDTOToJson(JobApiDTO instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'job_status': instance.jobStatus,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'display_title': instance.displayTitle,
      'display_text': instance.displayText,
      'error_code': instance.errorCode,
      'error_message': instance.errorMessage,
      'text': instance.text,
      'additional_text': instance.additionalText,
    };
