import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'job_remote_data_source.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logging helpers

class ApiJobRemoteDataSourceImpl implements JobRemoteDataSource {
  final Dio dio;
  // Add logger instance
  final Logger _logger = LoggerFactory.getLogger(ApiJobRemoteDataSourceImpl);
  // Define log tag
  static final String _tag = logTag(ApiJobRemoteDataSourceImpl);

  // TODO: Inject base URL or read from config
  ApiJobRemoteDataSourceImpl({required this.dio});

  // Helper to add required headers (JWT, API Key)
  // TODO: Implement actual header retrieval logic (e.g., from auth state/storage)
  Options _getHeaders() {
    // Placeholder values - replace with actual token/key retrieval
    const String tempJwt = 'your_jwt_token_here';
    const String tempApiKey = 'your_api_key_here';
    return Options(
      headers: {
        'Authorization': 'Bearer $tempJwt',
        'X-API-Key': tempApiKey,
        'Content-Type':
            'application/json', // Default, may be overridden for POST
      },
    );
  }

  @override
  Future<Job> fetchJobById(String id) async {
    final String endpoint = '/jobs/$id';
    try {
      final response = await dio.get(endpoint, options: _getHeaders());

      if (response.statusCode == 200 && response.data != null) {
        // API wraps the job object in a "data" key
        final Map<String, dynamic> jobData = response.data['data'];
        return _mapJsonToJob(jobData); // Use a helper for mapping
      } else {
        // Handle non-200 status codes gracefully
        throw ApiException(
          message: 'Failed to fetch job. Status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      // Handle Dio specific errors (network, timeout, response errors)
      throw ApiException(
        message: 'API request failed: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      // Handle other unexpected errors (e.g., parsing)
      throw ApiException(
        message: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  // --- Helper method for mapping JSON to Job entity ---
  Job _mapJsonToJob(Map<String, dynamic> json) {
    try {
      return Job(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        // Map 'job_status' from API to 'status' in entity
        status: json['job_status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        errorCode: json['error_code'] as int?,
        errorMessage: json['error_message'] as String?,
        text: json['text'] as String?,
        additionalText: json['additional_text'] as String?,
        displayTitle: json['display_title'] as String?,
        displayText: json['display_text'] as String?,
        // audioFilePath is not expected in GET responses according to spec
        audioFilePath: null,
      );
    } catch (e) {
      // Catch potential parsing errors (wrong types, missing keys)
      throw ApiException(message: 'Failed to parse job data: ${e.toString()}');
    }
  }

  // --- Methods to be implemented ---

  @override
  Future<List<Job>> fetchJobs() async {
    const String endpoint = '/jobs';
    try {
      final response = await dio.get(endpoint, options: _getHeaders());

      if (response.statusCode == 200 && response.data != null) {
        // API wraps the job list in a "data" key
        final List<dynamic> jobListJson = response.data['data'] as List;
        // Map each item in the list using the helper method
        final List<Job> jobs =
            jobListJson
                .map(
                  (jobJson) => _mapJsonToJob(jobJson as Map<String, dynamic>),
                )
                .toList();
        return jobs;
      } else {
        throw ApiException(
          message: 'Failed to fetch jobs. Status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException(
        message: 'API request failed: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      // Includes potential parsing errors from the mapping
      throw ApiException(
        message: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  @override
  Future<Job> createJob({
    required String userId,
    required String audioFilePath,
    String? text,
    String? additionalText,
    // Add testing parameter - not part of the interface contract but helps with testing
    MultipartFile? testAudioFile,
  }) async {
    const String endpoint = '/jobs';
    // Log method entry
    _logger.d(
      '$_tag createJob called with userId: $userId, audioFilePath: $audioFilePath, text: $text, additionalText: $additionalText, hasTestAudioFile: ${testAudioFile != null}',
    );
    try {
      // Create FormData for multipart request
      final formMap = <String, dynamic>{
        'user_id': userId,
        // Add text fields only if they're not null
        if (text != null) 'text': text,
        if (additionalText != null) 'additional_text': additionalText,
        // Use provided test file or create one from the path
        'audio_file':
            testAudioFile ??
            await MultipartFile.fromFile(
              audioFilePath,
              filename:
                  audioFilePath.split('/').last, // Extract filename from path
            ),
      };
      // Log the map before creating FormData
      _logger.d('$_tag FormData map prepared: $formMap');
      final formData = FormData.fromMap(formMap);

      // Make the POST request with multipart/form-data
      // No need to explicitly set Content-Type - Dio handles this for FormData
      final response = await dio.post(
        endpoint,
        data: formData,
        options: _getHeaders(),
      );

      // Check response status and data
      if (response.statusCode == 201 && response.data != null) {
        // Log successful response
        _logger.i(
          '$_tag createJob successful (201). Response data: ${response.data}',
        );
        // API wraps the created job in a "data" object
        final Map<String, dynamic> jobData = response.data['data'];
        return _mapJsonToJob(jobData);
      } else {
        // Log unexpected success status
        _logger.w(
          '$_tag createJob received unexpected status: ${response.statusCode}. Response data: ${response.data}',
        );
        throw ApiException(
          message: 'Failed to create job. Status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      // Log DioException
      _logger.e(
        '$_tag DioException in createJob: ${e.message}',
        error: e,
        stackTrace: e.stackTrace,
      );
      // Handle network errors and response errors from DioException
      throw ApiException(
        message: 'API request failed: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e, stackTrace) {
      // Log other exceptions
      _logger.e(
        '$_tag Unexpected error in createJob: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      );
      // Re-throw if it's already an ApiException, otherwise wrap it.
      if (e is ApiException) {
        throw e;
      }
      // Handle other unexpected errors
      throw ApiException(
        message: 'An unexpected error occurred: ${e.toString()}',
        // Keep statusCode null for truly unexpected errors
      );
    }
  }

  @override
  Future<Job> updateJob({
    required String jobId,
    required Map<String, dynamic> updates,
  }) async {
    final String endpoint = '/jobs/$jobId';
    _logger.d(
      '$_tag updateJob called for jobId: $jobId with updates: $updates',
    );

    try {
      final response = await dio.patch(
        endpoint,
        data: updates, // Send the updates map as the request body
        options: _getHeaders(), // Ensure correct headers are sent
      );

      if (response.statusCode == 200 && response.data != null) {
        _logger.i(
          '$_tag updateJob successful (200) for jobId: $jobId. Response data: ${response.data}',
        );
        // API returns the updated job object wrapped in "data"
        final Map<String, dynamic> updatedJobData = response.data['data'];
        return _mapJsonToJob(updatedJobData);
      } else {
        _logger.w(
          '$_tag updateJob for jobId: $jobId received unexpected status: ${response.statusCode}. Response data: ${response.data}',
        );
        throw ApiException(
          message: 'Failed to update job. Status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      _logger.e(
        '$_tag DioException in updateJob for jobId: $jobId: ${e.message}',
        error: e,
        stackTrace: e.stackTrace,
      );
      throw ApiException(
        message: 'API request failed during update: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error in updateJob for jobId: $jobId: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      );
      // Re-throw if it's already an ApiException, otherwise wrap it.
      if (e is ApiException) {
        throw e;
      }
      throw ApiException(
        message: 'An unexpected error occurred during update: ${e.toString()}',
      );
    }
  }
}
