import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  final logger = Logger();
  final dio = Dio();
  late File testFile;

  setUp(() async {
    // Create a temporary test file directly without path_provider
    testFile = File('test_audio.mp3');
    testFile.writeAsStringSync('This is test audio content');
  });

  tearDown(() async {
    if (testFile.existsSync()) {
      await testFile.delete();
    }
  });

  test('httpbin test with default Dio multipart behavior', () async {
    // Create form data
    final formData = FormData.fromMap({
      'user_id': '12345',
      'text': 'Transcribe this audio',
      'additional_text': 'Additional context',
      'file': await MultipartFile.fromFile(
        testFile.path,
        filename: 'test_audio.mp3',
      ),
    });

    logger.d('Sending request with default boundary handling...');

    // Send to httpbin
    final response = await dio.post(
      'https://httpbin.org/post',
      data: formData,
      options: Options(headers: {'X-Api-Key': 'test-api-key'}),
    );

    // Log response details
    logger.d('Response status: ${response.statusCode}');
    logger.d('Response headers: ${response.headers}');
    logger.d('Response data: ${response.data}');

    // Verify response
    expect(response.statusCode, 200);
    expect(response.data['files'].containsKey('file'), true);
    expect(response.data['form']['user_id'], '12345');
    expect(response.data['form']['text'], 'Transcribe this audio');
    expect(response.data['form']['additional_text'], 'Additional context');
  });

  test('httpbin test with custom boundary approach', () async {
    // Custom boundary
    final boundary =
        '------------------------${DateTime.now().millisecondsSinceEpoch}';

    // Create form data
    final formData = FormData();

    // Add text fields
    formData.fields.add(MapEntry('user_id', '12345'));
    formData.fields.add(MapEntry('text', 'Transcribe this audio'));
    formData.fields.add(MapEntry('additional_text', 'Additional context'));

    // Add file
    formData.files.add(
      MapEntry(
        'file',
        await MultipartFile.fromFile(testFile.path, filename: 'test_audio.mp3'),
      ),
    );

    logger.d('Sending request with custom boundary: $boundary');

    // Send to httpbin with explicit content-type header including boundary
    final response = await dio.post(
      'https://httpbin.org/post',
      data: formData,
      options: Options(
        headers: {
          'X-Api-Key': 'test-api-key',
          'Content-Type': 'multipart/form-data; boundary=$boundary',
        },
      ),
    );

    // Log response details
    logger.d('Response status: ${response.statusCode}');
    logger.d('Response headers: ${response.headers}');
    logger.d('Response data: ${response.data}');

    // Verify response
    expect(response.statusCode, 200);
    expect(response.data['files'].containsKey('file'), true);
    expect(response.data['form']['user_id'], '12345');
    expect(response.data['form']['text'], 'Transcribe this audio');
    expect(response.data['form']['additional_text'], 'Additional context');
  });
}
