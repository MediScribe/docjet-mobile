import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'job_remote_data_source.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logging helpers

// Type definition for the MultipartFile creator function. This allows injecting
// a mock creator for testing without needing the actual file system.
typedef MultipartFileCreator = Future<MultipartFile> Function(String path);

/// {@template api_job_remote_data_source_impl}
/// Implements the [JobRemoteDataSource] interface using the Dio package
/// for HTTP requests to interact with the backend jobs API.
///
/// Handles fetching, creating, and updating job data.
/// {@endtemplate}
class ApiJobRemoteDataSourceImpl implements JobRemoteDataSource {
  /// The Dio client instance used for making HTTP requests.
  final Dio dio;

  /// Function used to create a [MultipartFile] from a file path.
  /// Injected for testability.
  final MultipartFileCreator _multipartFileCreator;

  /// Logger instance for logging events within this data source.
  final Logger _logger = LoggerFactory.getLogger(ApiJobRemoteDataSourceImpl);

  /// Static log tag for identifying logs from this class.
  static final String _tag = logTag(ApiJobRemoteDataSourceImpl);

  /// {@macro api_job_remote_data_source_impl}
  /// Creates an instance of [ApiJobRemoteDataSourceImpl].
  ///
  /// Requires a [Dio] instance and optionally accepts a [multipartFileCreator]
  /// function. If no creator is provided, it defaults to [MultipartFile.fromFile].
  ApiJobRemoteDataSourceImpl({
    required this.dio,
    // Default to the actual static method for production
    MultipartFileCreator multipartFileCreator = MultipartFile.fromFile,
  }) : _multipartFileCreator = multipartFileCreator;

  // ===========================================================================
  // ==                          Private Helper Methods                       ==
  // ===========================================================================

  /// Adds required headers (e.g., JWT, API Key) to Dio requests.
  ///
  /// TODO: Implement actual header retrieval logic (e.g., from auth state/storage).
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

  /// Safely maps a JSON map (typically from an API response) to a [Job] entity.
  ///
  /// Handles potential parsing errors and wraps them in an [ApiException].
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
      _logger.e('$_tag Failed to parse job data: $json', error: e);
      throw ApiException(message: 'Failed to parse job data: ${e.toString()}');
    }
  }

  /// Creates a [FormData] object for the `createJob` request.
  ///
  /// Uses the injected [_multipartFileCreator] to handle file creation,
  /// allowing for mocking during tests.
  Future<FormData> _createJobFormData({
    required String userId,
    required String audioFilePath,
    String? text,
    String? additionalText,
  }) async {
    _logger.d('$_tag Preparing FormData for job creation...');
    try {
      // Use the injected creator function
      final audioFile = await _multipartFileCreator(audioFilePath);

      // Build the form data map
      final formMap = <String, dynamic>{
        'user_id': userId,
        if (text != null) 'text': text,
        if (additionalText != null) 'additional_text': additionalText,
        'audio_file': audioFile,
      };

      _logger.d('$_tag FormData map prepared: $formMap');
      return FormData.fromMap(formMap);
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to create MultipartFile or FormData',
        error: e,
        stackTrace: stackTrace,
      );
      // Wrap file system or other errors in an ApiException to be caught upstream
      throw ApiException(
        message: 'Failed to prepare data for upload: ${e.toString()}',
      );
    }
  }

  // ===========================================================================
  // ==                    JobRemoteDataSource Implementation                 ==
  // ===========================================================================

  @override
  Future<Job> fetchJobById(String id) async {
    final String endpoint = '/jobs/$id';
    _logger.d('$_tag Fetching job by ID: $id from $endpoint');

    try {
      final response = await dio.get(endpoint, options: _getHeaders());

      // --- Success Case (200 OK) ---
      if (response.statusCode == 200 && response.data != null) {
        _logger.i(
          '$_tag Successfully fetched job $id (200). Response: ${response.data}',
        );
        // API wraps the job object in a "data" key
        final Map<String, dynamic> jobData = response.data['data'];
        return _mapJsonToJob(jobData);
      }
      // --- Error Case (Non-200) ---
      else {
        _logger.w(
          '$_tag Failed to fetch job $id. Status: ${response.statusCode}, Response: ${response.data}',
        );
        throw ApiException(
          message: 'Failed to fetch job. Status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    }
    // --- Dio/Network Error Case ---
    on DioException catch (e) {
      _logger.e(
        '$_tag DioException while fetching job $id: ${e.message}',
        error: e,
        stackTrace: e.stackTrace,
      );
      throw ApiException(
        message: 'API request failed: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
    // --- Other Unexpected Error Case ---
    catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error while fetching job $id: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      );
      throw ApiException(
        message: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<Job>> fetchJobs() async {
    const String endpoint = '/jobs';
    _logger.d('$_tag Fetching all jobs from $endpoint');

    try {
      final response = await dio.get(endpoint, options: _getHeaders());

      // --- Success Case (200 OK) ---
      if (response.statusCode == 200 && response.data != null) {
        _logger.i(
          '$_tag Successfully fetched jobs (200). Response: ${response.data}',
        );
        // API wraps the job list in a "data" key
        final List<dynamic> jobListJson = response.data['data'] as List;
        // Map each item in the list using the helper method
        final List<Job> jobs =
            jobListJson
                .map(
                  (jobJson) => _mapJsonToJob(jobJson as Map<String, dynamic>),
                )
                .toList();
        _logger.d('$_tag Parsed ${jobs.length} jobs.');
        return jobs;
      }
      // --- Error Case (Non-200) ---
      else {
        _logger.w(
          '$_tag Failed to fetch jobs. Status: ${response.statusCode}, Response: ${response.data}',
        );
        throw ApiException(
          message: 'Failed to fetch jobs. Status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    }
    // --- Dio/Network Error Case ---
    on DioException catch (e) {
      _logger.e(
        '$_tag DioException while fetching jobs: ${e.message}',
        error: e,
        stackTrace: e.stackTrace,
      );
      throw ApiException(
        message: 'API request failed: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
    // --- Other Unexpected Error Case ---
    catch (e, stackTrace) {
      // Includes potential parsing errors from the mapping
      _logger.e(
        '$_tag Unexpected error while fetching jobs: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      );
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
  }) async {
    const String endpoint = '/jobs';
    _logger.d(
      '$_tag createJob called with userId: $userId, audioFilePath: $audioFilePath, text: $text, additionalText: $additionalText',
    );

    try {
      // --- Prepare Data ---
      // Use helper to create FormData, which includes the audio file
      final formData = await _createJobFormData(
        userId: userId,
        audioFilePath: audioFilePath,
        text: text,
        additionalText: additionalText,
      );

      // --- Make API Call ---
      _logger.d('$_tag Sending POST request to $endpoint');
      final response = await dio.post(
        endpoint,
        data: formData, // Send the prepared FormData
        options: _getHeaders(),
      );

      // --- Handle Response ---
      // Success Case (201 Created)
      if (response.statusCode == 201 && response.data != null) {
        _logger.i(
          '$_tag createJob successful (201). Response data: ${response.data}',
        );
        // API returns the created job object wrapped in "data"
        final Map<String, dynamic> jobData = response.data['data'];
        return _mapJsonToJob(jobData);
      }
      // Error Case (Non-201)
      else {
        _logger.w(
          '$_tag createJob received unexpected status: ${response.statusCode}. Response data: ${response.data}',
        );
        throw ApiException(
          message: 'Failed to create job. Status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    }
    // --- Dio/Network Error Case ---
    on DioException catch (e) {
      _logger.e(
        '$_tag DioException in createJob: ${e.message}',
        error: e,
        stackTrace: e.stackTrace,
      );
      throw ApiException(
        message: 'API request failed: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
    // --- Other Unexpected Error Case (includes FormData creation errors) ---
    catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error in createJob: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      );
      // Re-throw if it's already an ApiException (e.g., from _createJobFormData)
      if (e is ApiException) {
        rethrow;
      }
      // Otherwise, wrap it
      throw ApiException(
        message:
            'An unexpected error occurred during job creation: ${e.toString()}',
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
      // --- Make API Call ---
      final response = await dio.patch(
        endpoint,
        data: updates, // Send the updates map as the request body
        options:
            _getHeaders(), // Ensure correct headers are sent (like Content-Type: application/json)
      );

      // --- Handle Response ---
      // Success Case (200 OK)
      if (response.statusCode == 200 && response.data != null) {
        _logger.i(
          '$_tag updateJob successful (200) for jobId: $jobId. Response data: ${response.data}',
        );
        // API returns the updated job object wrapped in "data"
        final Map<String, dynamic> updatedJobData = response.data['data'];
        return _mapJsonToJob(updatedJobData);
      }
      // Error Case (Non-200)
      else {
        _logger.w(
          '$_tag updateJob for jobId: $jobId received unexpected status: ${response.statusCode}. Response data: ${response.data}',
        );
        throw ApiException(
          message: 'Failed to update job. Status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    }
    // --- Dio/Network Error Case ---
    on DioException catch (e) {
      _logger.e(
        '$_tag DioException in updateJob for jobId: $jobId: ${e.message}',
        error: e,
        stackTrace: e.stackTrace,
      );
      throw ApiException(
        message: 'API request failed during update: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
    // --- Other Unexpected Error Case ---
    catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error in updateJob for jobId: $jobId: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      );
      // Re-throw if it's already an ApiException, otherwise wrap it.
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(
        message: 'An unexpected error occurred during update: ${e.toString()}',
      );
    }
  }
}
