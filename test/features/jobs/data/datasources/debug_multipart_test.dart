import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Multipart Debug Tests', () {
    late Dio dio;
    late File testFile;
    late Directory tempDir;

    setUp(() async {
      dio = Dio();
      dio.interceptors.add(
        LogInterceptor(
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
        ),
      );

      tempDir = await Directory.systemTemp.createTemp('test_audio_');
      testFile = File(p.join(tempDir.path, 'test_audio.mp3'));
      await testFile.writeAsString('dummy audio content');
      print('Created test file at: ${testFile.path}');
    });

    tearDown(() async {
      dio.close();
      await tempDir.delete(recursive: true);
    });

    test('Default Dio multipart behavior', () async {
      // Create FormData with default settings
      final formData = FormData();

      // Add fields and files
      formData.fields.add(MapEntry('user_id', 'test_user'));
      formData.fields.add(MapEntry('text', 'Test text'));
      formData.files.add(
        MapEntry(
          'audio_file',
          await MultipartFile.fromFile(
            testFile.path,
            filename: p.basename(testFile.path),
          ),
        ),
      );

      print('Sending request with default Dio behavior...');
      final response = await dio.post(
        'https://httpbin.org/post',
        data: formData,
      );

      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      expect(response.statusCode, 200);
      expect(response.data['files'], isNotEmpty);
    });

    test('Manual boundary approach', () async {
      // Create FormData
      final formData = FormData();

      // Add fields and files
      formData.fields.add(MapEntry('user_id', 'test_user'));
      formData.fields.add(MapEntry('text', 'Test text'));
      formData.files.add(
        MapEntry(
          'audio_file',
          await MultipartFile.fromFile(
            testFile.path,
            filename: p.basename(testFile.path),
          ),
        ),
      );

      // Create a custom boundary
      final boundary =
          '------------------------${DateTime.now().millisecondsSinceEpoch}';

      // Set content-type with boundary
      final options = Options(
        headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
      );

      print('Sending request with manual boundary approach...');
      print('Using boundary: $boundary');

      final response = await dio.post(
        'https://httpbin.org/post',
        data: formData,
        options: options,
      );

      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      expect(response.statusCode, 200);
      expect(response.data['files'], isNotEmpty);
    });
  });
}
