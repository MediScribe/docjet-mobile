import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/api_job_remote_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/hive_job_local_data_source_impl.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;

/// A simple implementation for interacting with the mock server jobs API
class JobsDatasource {
  final Dio dio;
  final AuthCredentialsProvider credentialsProvider;
  final String baseUrl;
  final String apiKey;
  final Logger _logger = LoggerFactory.getLogger('JobsDatasource');
  final String _tag = 'JobsDatasource';

  JobsDatasource({
    required this.dio,
    required this.credentialsProvider,
    required this.baseUrl,
    required this.apiKey,
  });

  Future<Map<String, dynamic>> createJob({
    required String userId,
    String? text,
    required Uint8List audioFile,
    required String audioFileName,
  }) async {
    try {
      final accessToken = await credentialsProvider.getAccessToken();
      final headers = {
        'X-API-Key': apiKey,
        'Authorization': 'Bearer $accessToken',
      };

      // Create FormData with fields and file
      final formData = FormData();
      formData.fields.add(MapEntry('user_id', userId));
      if (text != null) {
        formData.fields.add(MapEntry('text', text));
      }

      final multipartFile = MultipartFile.fromBytes(
        audioFile,
        filename: audioFileName,
      );
      formData.files.add(MapEntry('audio_file', multipartFile));

      // Make the request with proper headers and let Dio handle content-type
      final response = await dio.post(
        '$baseUrl/jobs',
        data: formData,
        options: Options(headers: headers),
      );

      _logger.i('$_tag Response status: ${response.statusCode}');
      _logger.i('$_tag Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['data'];
      } else {
        throw ApiException(
          message: 'Failed to create job. Status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      _logger.e('$_tag DioException in createJob: ${e.message}', error: e);
      throw ApiException(
        message: 'API request failed: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      _logger.e('$_tag Error in createJob: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'An unexpected error occurred: $e');
    }
  }
}

// Mock implementation for AuthCredentialsProvider
class MockAuthCredentialsProvider extends Mock
    implements AuthCredentialsProvider {
  @override
  Future<String> getApiKey() async => _testApiKey;

  @override
  Future<String?> getAccessToken() async => 'fake-access-token-from-test';

  @override
  Future<String?> getRefreshToken() async => 'fake-refresh-token-from-test';

  @override
  Future<String?> getUserId() async => _testUserId;

  @override
  Future<void> saveCredentials({
    String? accessToken,
    String? refreshToken,
    String? userId,
  }) async {}

  @override
  Future<void> clearCredentials() async {}
}

// Hardcoded API key and Base URL matching the mock server and test setup
const String _testApiKey = 'test-api-key';
const String _mockBaseUrl = 'http://localhost:8080/api/v1';
const String _testUserId = 'fake-user-id-123';
const String _mockServerPath = 'mock_api_server/bin/server.dart';

/// Dio logging interceptor to debug HTTP requests
class DioDiagnosticInterceptor extends Interceptor {
  final Logger logger;
  final String tag;

  DioDiagnosticInterceptor(this.logger, this.tag);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger.i('$tag 🔷 REQUEST[${options.method}] => PATH: ${options.path}');
    logger.i('$tag Headers:');
    options.headers.forEach((k, v) => logger.i('$tag   $k: $v'));

    if (options.data != null) {
      if (options.data is FormData) {
        final formData = options.data as FormData;
        logger.i('$tag FormData:');
        logger.i('$tag   Boundary: ${formData.boundary}');

        // Log form fields
        for (final field in formData.fields) {
          logger.i('$tag   Field: ${field.key} = ${field.value}');
        }

        // Log files
        for (final file in formData.files) {
          logger.i(
            '$tag   File: ${file.key}, filename: ${file.value.filename}',
          );
          logger.i('$tag     Content-Type: ${file.value.contentType}');
          logger.i('$tag     Length: ${file.value.length} bytes');
        }
      } else {
        try {
          logger.i('$tag Body: ${options.data}');
        } catch (e) {
          logger.i('$tag Body: [Could not stringify body: $e]');
        }
      }
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    logger.i(
      '$tag 🔶 RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}',
    );
    logger.i('$tag Response headers:');
    response.headers.forEach?.call((k, v) => logger.i('$tag   $k: $v'));

    try {
      logger.i('$tag Response: ${response.data}');
    } catch (e) {
      logger.i('$tag Response: [Could not stringify response: $e]');
    }

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.e(
      '$tag ⛔ ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}',
    );
    logger.e('$tag Error: ${err.message}');

    if (err.response != null) {
      try {
        logger.e('$tag Response: ${err.response?.data}');
      } catch (e) {
        logger.e('$tag Response: [Could not stringify response: $e]');
      }
    }

    super.onError(err, handler);
  }
}

void main() {
  final Logger _logger = LoggerFactory.getLogger(
    'JobDatasourcesIntegrationTest',
  );
  final String _tag = logTag('JobDatasourcesIntegrationTest');

  // Define the port (make it a constant)
  const int mockServerPort = 8080;

  late Dio dio;
  late JobRemoteDataSource remoteDataSource;
  late Box<JobHiveModel> jobBox;
  Process? mockServerProcess;
  late Directory testTempDir;
  late MockAuthCredentialsProvider mockAuthProvider;

  setUpAll(() async {
    _logger.i('$_tag Setting up integration tests...');

    // --- Force kill any process listening on the mock server port ---
    _logger.i('$_tag Attempting to clear port $mockServerPort...');
    try {
      // Find process IDs listening on the port
      final lsofResult = await Process.run('lsof', ['-ti', ':$mockServerPort']);
      if (lsofResult.exitCode == 0 && lsofResult.stdout.toString().isNotEmpty) {
        final pids =
            lsofResult.stdout
                .toString()
                .split('\n')
                .where((pid) => pid.isNotEmpty)
                .toList();
        _logger.w(
          '$_tag Found processes on port $mockServerPort: $pids. Killing...',
        );
        for (final pid in pids) {
          final killResult = await Process.run('kill', ['-9', pid]);
          if (killResult.exitCode == 0) {
            _logger.i('$_tag Killed process $pid.');
          } else {
            _logger.w(
              '$_tag Failed to kill process $pid. Stderr: ${killResult.stderr}',
            );
          }
        }
        // Wait a moment for ports to free up
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        _logger.i('$_tag Port $mockServerPort appears to be clear.');
      }
    } catch (e, stackTrace) {
      // Log error but continue, server start might still succeed or fail clearly
      _logger.e(
        '$_tag Error trying to clear port $mockServerPort',
        error: e,
        stackTrace: stackTrace,
      );
    }
    // ------------------------------------------------------------------

    // 1. Set up a temporary directory for Hive
    _logger.d('$_tag Initializing Hive...');
    testTempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(testTempDir.path);
    _logger.d('$_tag Hive initialized in: ${testTempDir.path}');

    // 2. Register Hive Adapters
    _logger.d('$_tag Registering Hive adapters...');
    if (!Hive.isAdapterRegistered(JobHiveModelAdapter().typeId)) {
      Hive.registerAdapter(JobHiveModelAdapter());
      _logger.d('$_tag Registered JobHiveModelAdapter.');
    }

    // 3. Open Hive boxes
    _logger.d('$_tag Opening Hive boxes...');
    jobBox = await Hive.openBox<JobHiveModel>(
      HiveJobLocalDataSourceImpl.jobsBoxName,
    );
    _logger.d('$_tag Opened box: ${HiveJobLocalDataSourceImpl.jobsBoxName}');

    // 4. Start the mock server
    _logger.i('$_tag Starting mock server on port $mockServerPort...');
    try {
      mockServerProcess = await Process.start('dart', [
        _mockServerPath,
      ], workingDirectory: Directory.current.path);
      _logger.i('$_tag Mock server started (PID: ${mockServerProcess?.pid})');
      mockServerProcess?.stdout
          .transform(utf8.decoder)
          .listen((line) => _logger.d('$_tag SERVER STDOUT: $line'));
      mockServerProcess?.stderr
          .transform(utf8.decoder)
          .listen((line) => _logger.e('$_tag SERVER STDERR: $line'));

      // Wait a bit longer for the server to be ready - 5 seconds to be safe
      _logger.i('$_tag Waiting for server to initialize...');
      await Future.delayed(const Duration(seconds: 5));

      // Simple check to see if server is responding
      final healthCheckDio = Dio();
      try {
        final headers = {
          'X-API-Key': _testApiKey,
          'Authorization': 'Bearer fake-access-token-from-test',
          'Accept': 'application/json',
        };

        final response = await healthCheckDio.get(
          'http://localhost:$mockServerPort/api/v1/jobs',
          options: Options(headers: headers),
        );

        if (response.statusCode == 200) {
          _logger.i('$_tag Mock server responded successfully.');
        } else {
          _logger.w(
            '$_tag Mock server returned unexpected status: ${response.statusCode}',
          );
        }
      } catch (e) {
        _logger.w('$_tag Health check failed: $e');
      } finally {
        healthCheckDio.close();
      }
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Error starting mock server',
        error: e,
        stackTrace: stackTrace,
      );
      mockServerProcess?.kill();
      throw Exception('Failed to start mock server: $e');
    }
    _logger.i('$_tag Setup complete.');
  });

  tearDownAll(() async {
    _logger.i('$_tag Tearing down integration tests...');
    _logger.i('$_tag Stopping mock server (PID: ${mockServerProcess?.pid})...');
    mockServerProcess?.kill(ProcessSignal.sigterm);
    await Future.delayed(const Duration(seconds: 2));
    mockServerProcess?.kill(ProcessSignal.sigkill);
    _logger.i('$_tag Mock server stopped.');

    _logger.d('$_tag Closing Hive boxes...');
    await jobBox.close();
    await Hive.close();
    _logger.d('$_tag Cleaning up Hive test directory...');
    try {
      if (await testTempDir.exists()) {
        await testTempDir.delete(recursive: true);
        _logger.i('$_tag Cleaned up Hive test directory: ${testTempDir.path}');
      }
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Error cleaning up Hive test directory',
        error: e,
        stackTrace: stackTrace,
      );
    }
    _logger.i('$_tag Teardown complete.');
  });

  setUp(() {
    mockAuthProvider = MockAuthCredentialsProvider();

    // Restore original Dio configuration
    dio = Dio(
      BaseOptions(
        baseUrl: _mockBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        validateStatus: (_) => true, // Accept all status codes for testing
      ),
    );

    // Add logging interceptor for debugging
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: true,
        error: true,
        logPrint: (obj) => _logger.d('$_tag DIO LOG: $obj'),
      ),
    );

    // Initialize data sources
    remoteDataSource = ApiJobRemoteDataSourceImpl(
      dio: dio,
      authCredentialsProvider: mockAuthProvider,
    );

    jobBox.clear();
  });

  tearDown(() {
    dio.close();
  });

  group('Job Datasources Integration Tests', () {
    test(
      'RemoteDataSource - createJob successfully posts data and returns Job entity',
      () async {
        // Arrange
        final tempDir = await Directory.systemTemp.createTemp('test_audio_');
        final testFile = File(p.join(tempDir.path, 'test_audio.mp3'));
        await testFile.writeAsString('dummy audio content');

        _logger.i('$_tag Created test file at: ${testFile.path}');
        _logger.i(
          '$_tag File exists: ${await testFile.exists()}, size: ${await testFile.length()} bytes',
        );

        const text = 'Optional transcription text';
        const additionalText = 'Additional context';

        try {
          // Act - Just call the repository method directly as intended
          final Job createdJob = await remoteDataSource.createJob(
            userId: _testUserId,
            audioFilePath: testFile.path,
            text: text,
            additionalText: additionalText,
          );

          // Assert
          expect(createdJob, isA<Job>());
          expect(createdJob.userId, _testUserId);
          expect(createdJob.status, 'submitted');
          expect(createdJob.text, text);
          expect(createdJob.additionalText, additionalText);
          expect(createdJob.id, isNotEmpty);
          expect(createdJob.createdAt, isA<DateTime>());
          expect(createdJob.updatedAt, isA<DateTime>());
        } on ApiException catch (e) {
          // Remove the skipping behavior - we want the test to fail properly
          _logger.e(
            '$_tag Got error from server: ${e.message}, statusCode: ${e.statusCode}',
          );
          // Add more diagnostic logging to help debug
          _logger.e('$_tag Check these common issues:');
          _logger.e(
            '$_tag 1. Content-Type header is being manually set (should be left to Dio)',
          );
          _logger.e(
            '$_tag 2. Missing or incorrect "user_id" field in FormData',
          );
          _logger.e('$_tag 3. Missing or improperly formatted "audio_file"');
          _logger.e(
            '$_tag 4. URL concatenation issues (check for double slashes)',
          );

          // Fail the test so we get proper error reports
          fail('API request failed with ${e.statusCode}: ${e.message}');
        } catch (e) {
          _logger.e('$_tag Unexpected error: $e');
          rethrow;
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    /* // COMMENT OUT EXTRA TEST 1
    // Direct diagnostic test with very verbse HTTP request tracing
    test('Minimal direct HttpClient multipart debug', () async {
      _logger.i('$_tag Creating direct verbose request to server...');
      final tempDir = await Directory.systemTemp.createTemp('test_minimal_');
      final testFile = File(p.join(tempDir.path, 'test_minimal.mp3'));
      await testFile.writeAsString('minimal debug test content');
      _logger.i('$_tag Created test file at: ${testFile.path}');
      _logger.i(
        '$_tag File exists: ${await testFile.exists()}, size: ${await testFile.length()} bytes',
      );

      try {
        _logger.i('$_tag Opening HttpClient connection...');
        final client = HttpClient();
        final request = await client.postUrl(
          Uri.parse('http://localhost:8080/api/v1/jobs'),
        );
        _logger.i('$_tag Request created, setting headers...');

        // Set required headers but NO Content-Type (will be set automatically)
        request.headers.set('X-API-Key', _testApiKey);
        request.headers.set('Authorization', 'Bearer fake-direct-test-token');

        // Log all request headers
        _logger.i('$_tag Request headers set:');
        request.headers.forEach((name, values) {
          _logger.i('$_tag   $name: $values');
        });

        // Create boundary string
        final boundary = 'BOUNDARY-${DateTime.now().millisecondsSinceEpoch}';
        _logger.i('$_tag Setting content-type with boundary: $boundary');
        request.headers.set(
          'Content-Type',
          'multipart/form-data; boundary=$boundary',
        );

        // Build the multipart body manually
        final bodyParts = <List<int>>[];
        final addString = (String s) => bodyParts.add(utf8.encode(s));

        // Add user_id field
        _logger.i('$_tag Adding user_id field...');
        addString('--$boundary\r\n');
        addString('Content-Disposition: form-data; name="user_id"\r\n\r\n');
        addString('$_testUserId\r\n');

        // Add text field
        _logger.i('$_tag Adding text field...');
        addString('--$boundary\r\n');
        addString('Content-Disposition: form-data; name="text"\r\n\r\n');
        addString('Minimal test text\r\n');

        // Add file field
        _logger.i('$_tag Adding audio_file field...');
        addString('--$boundary\r\n');
        addString(
          'Content-Disposition: form-data; name="audio_file"; filename="test_minimal.mp3"\r\n',
        );
        addString('Content-Type: audio/mpeg\r\n\r\n');

        // Add file content
        final fileBytes = await testFile.readAsBytes();
        bodyParts.add(fileBytes);
        addString('\r\n');

        // Add closing boundary
        addString('--$boundary--\r\n');

        // Calculate total content length
        final contentLength = bodyParts.fold<int>(
          0,
          (prev, element) => prev + element.length,
        );

        // Log the raw multipart body for debugging
        final debugBody = bodyParts
            .map((bytes) {
              try {
                return utf8.decode(bytes);
              } catch (_) {
                return '[BINARY DATA: ${bytes.length} bytes]';
              }
            })
            .join('');
        _logger.i('$_tag Raw multipart body:\n$debugBody');

        // Set content length
        _logger.i('$_tag Setting content length: $contentLength');
        request.contentLength = contentLength;

        // Write body parts
        _logger.i('$_tag Writing body parts to request...');
        for (final part in bodyParts) {
          request.add(part);
        }

        // Close the request to send it
        _logger.i('$_tag Sending request...');
        final response = await request.close();
        _logger.i(
          '$_tag Received response with status: ${response.statusCode}',
        );

        // Read response headers
        _logger.i('$_tag Response headers:');
        response.headers.forEach((name, values) {
          _logger.i('$_tag   $name: $values');
        });

        // Read response body
        final responseBody = await response.transform(utf8.decoder).join();
        _logger.i('$_tag Response body: $responseBody');

        // Just log, don't assert (we need diagnostics, not passes)
        _logger.i('$_tag Debug test complete');
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
    */

    /* // COMMENT OUT EXTRA TEST 2
    test('create job multipart request', () async {
      final tempDir = await Directory.systemTemp.createTemp('test_');
      try {
        final testFile = File(p.join(tempDir.path, 'test.mp3'));
        await testFile.writeAsString('test content');
        _logger.i(
          '$_tag Created test file at ${testFile.path}, size: ${await testFile.length()}',
        );

        // Create a fresh Dio instance with logging
        final dio = Dio();
        dio.interceptors.add(DioDiagnosticInterceptor(_logger, _tag));

        final authCredentialsProvider = MockAuthCredentialsProvider();

        final jobsDatasource = JobsDatasource(
          dio: dio,
          credentialsProvider: authCredentialsProvider,
          baseUrl: 'http://localhost:8080/api/v1',
          apiKey: _testApiKey,
        );

        try {
          _logger.i('$_tag Attempting to create job...');
          final result = await jobsDatasource.createJob(
            userId: _testUserId,
            text: 'test text',
            audioFile: await testFile.readAsBytes(),
            audioFileName: 'test.mp3',
          );
          _logger.i('$_tag Created job successfully: $result');
        } on ApiException catch (e) {
          // Remove the skipping behavior here too
          _logger.e(
            '$_tag Error from mock server: ${e.message}, statusCode: ${e.statusCode}',
          );
          // Fail the test instead of skipping
          fail('API request failed with ${e.statusCode}: ${e.message}');
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
    */

    // TODO: Add tests for:
    // - remoteDataSource.fetchJobById
    // - remoteDataSource.fetchJobs
    // - remoteDataSource.updateJob
    // - remoteDataSource.fetchJobDocuments
    // - localDataSource interactions (saveJobHiveModel, getAllJobHiveModels, etc.)
  });
}
