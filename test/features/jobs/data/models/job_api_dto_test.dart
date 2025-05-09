import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_api_dto.dart'; // This import will fail initially

void main() {
  group('JobApiDTO', () {
    final tJobApiDto = JobApiDTO(
      id: 'job-123',
      userId: 'user-abc',
      jobStatus: 'COMPLETED', // Note: API uses job_status
      createdAt:
          DateTime.parse('2023-01-01T10:00:00.000Z').toUtc(), // Ensure UTC
      updatedAt:
          DateTime.parse('2023-01-01T12:00:00.000Z').toUtc(), // Ensure UTC
      displayTitle: 'Test Job Title',
      displayText: 'Test Job Snippet',
      errorCode: null,
      errorMessage: null,
      text: 'Original text',
      additionalText: 'Extra info',
    );

    final tJobJsonMap = {
      'id': 'job-123',
      'user_id': 'user-abc',
      'status': 'COMPLETED', // API key
      'created_at': '2023-01-01T10:00:00.000Z', // ISO 8601 format UTC
      'updated_at': '2023-01-01T12:00:00.000Z', // ISO 8601 format UTC
      'display_title': 'Test Job Title',
      'display_text': 'Test Job Snippet',
      'error_code': null,
      'error_message': null,
      'text': 'Original text',
      'additional_text': 'Extra info',
    };

    test('should correctly deserialize from JSON map', () {
      // Act
      final result = JobApiDTO.fromJson(tJobJsonMap);

      // Assert
      expect(result, tJobApiDto);
    });

    test('should correctly serialize to JSON map', () {
      // Act
      final result = tJobApiDto.toJson();

      // Assert
      expect(result, tJobJsonMap);
    });
  });
}
