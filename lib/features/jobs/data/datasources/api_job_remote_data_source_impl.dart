import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart'; // Import the new provider
import 'package:docjet_mobile/core/auth/auth_session_provider.dart'; // Import the AuthSessionProvider
import 'package:docjet_mobile/core/error/exceptions.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import logging helpers
import 'package:docjet_mobile/features/jobs/data/mappers/job_mapper.dart'; // Import the mapper
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:dartz/dartz.dart'; // Import dartz for Unit

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

  /// Provider for authentication credentials (JWT, API Key).
  final AuthCredentialsProvider authCredentialsProvider;

  /// Provider for authentication session information like user ID.
  final AuthSessionProvider authSessionProvider;

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
    required this.authCredentialsProvider,
    required this.authSessionProvider,
    // Default to the actual static method for production
    MultipartFileCreator multipartFileCreator = MultipartFile.fromFile,
  }) : _multipartFileCreator = multipartFileCreator;

  // ===========================================================================
  // ==                          Private Helper Methods                       ==
  // ===========================================================================

  /// Asynchronously retrieves authentication credentials and creates Dio [Options].
  ///
  /// Fetches the API key and access token using the injected [AuthCredentialsProvider].
  /// Sets the required `X-API-Key` and `Authorization` headers.
  /// Sets `Content-Type` based on the `isJsonRequest` flag.
  ///
  /// Throws [ApiException] if credentials cannot be obtained.
  Future<Options> _getOptionsWithAuth({bool isJsonRequest = true}) async {
    try {
      final apiKey = await authCredentialsProvider.getApiKey();
      final accessToken = await authCredentialsProvider.getAccessToken();

      final headers = <String, dynamic>{'X-API-Key': apiKey};

      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      // Only set Content-Type for JSON requests
      // For multipart/form-data, don't set any content-type and let Dio handle it
      // automatically with the correct boundary
      if (isJsonRequest) {
        headers['Content-Type'] = 'application/json';
      }

      return Options(headers: headers);
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to get authentication credentials or create options',
        error: e,
        stackTrace: stackTrace,
      );
      // Wrap any credential retrieval errors in ApiException
      throw ApiException(
        message: 'Failed to prepare request options: ${e.toString()}',
      );
    }
  }

  /// Safely maps a JSON map (typically from an API response) to a [Job] entity.
  ///
  /// Handles potential parsing errors and wraps them in an [ApiException].
  Job _mapJsonToJob(Map<String, dynamic> json) {
    try {
      // Helper function for safe casting with type checking
      T safeCast<T>(dynamic value, String key) {
        if (value is T) {
          return value;
        }
        throw FormatException(
          'Invalid type for key "$key": Expected $T but got ${value?.runtimeType ?? 'null'}',
        );
      }

      // Helper for safe DateTime parsing
      DateTime parseDateTime(dynamic value, String key) {
        if (value is String) {
          try {
            return DateTime.parse(value);
          } catch (e) {
            throw FormatException(
              'Invalid DateTime format for key "$key": "$value"',
            );
          }
        }
        throw FormatException(
          'Invalid type for key "$key": Expected String but got ${value?.runtimeType ?? 'null'}',
        );
      }

      return Job(
        localId: '', // Or null. Local ID is not returned by GET endpoints.
        serverId: safeCast<String>(
          json['id'],
          'id',
        ), // API 'id' IS the serverId
        userId: safeCast<String>(json['user_id'], 'user_id'),
        // Use JobMapper to convert the status string to the enum
        status: JobMapper.stringToJobStatus(json['job_status'] as String?),
        syncStatus: SyncStatus.synced, // API data is considered synced
        createdAt: parseDateTime(json['created_at'], 'created_at'),
        updatedAt: parseDateTime(json['updated_at'], 'updated_at'),
        // Optional fields - allow null if missing or null
        errorCode: json['error_code'] as int?,
        errorMessage: json['error_message'] as String?,
        text: json['text'] as String?,
        additionalText: json['additional_text'] as String?,
        displayTitle: json['display_title'] as String?,
        displayText: json['display_text'] as String?,
        // audioFilePath is not expected in GET responses according to spec
        audioFilePath: null,
      );
    } on FormatException catch (e) {
      // Catch specific parsing errors
      _logger.e(
        '$_tag Failed to parse job data: ${e.message}. JSON: $json',
        error: e,
      );
      throw ApiException(message: 'Failed to parse job data: ${e.message}');
    } catch (e, stackTrace) {
      // Catch other potential errors during construction
      _logger.e(
        '$_tag Unexpected error mapping JSON to Job: $json',
        error: e,
        stackTrace: stackTrace,
      );
      throw ApiException(
        message: 'Unexpected error processing job data: ${e.toString()}',
      );
    }
  }

  /// Creates a [FormData] object for the `createJob` request.
  ///
  /// Uses the injected [_multipartFileCreator] to handle file creation,
  /// allowing for mocking during tests.
  Future<FormData> _createJobFormData({
    required String audioFilePath,
    String? text,
    String? additionalText,
  }) async {
    _logger.d('$_tag Preparing FormData for job creation...');

    // Get the current user ID from the auth session provider
    // This should be outside the main try-catch to properly handle auth errors
    // Authentication errors should not be caught by the regular error handling
    if (!await authSessionProvider.isAuthenticated()) {
      const errorMessage = 'Cannot create job: No authenticated user';
      _logger.e(
        '$_tag Authentication error in _createJobFormData: $errorMessage',
      );
      throw ApiException(message: errorMessage);
    }

    String userId;
    try {
      userId = await authSessionProvider.getCurrentUserId();
    } catch (e) {
      // Convert any auth-related exceptions to ApiException with clear message
      final errorMessage =
          e is ApiException
              ? e.message
              : 'Authentication failed: ${e.toString()}';

      _logger.e(
        '$_tag Authentication error in _createJobFormData: $errorMessage',
        error: e,
      );

      throw ApiException(message: errorMessage);
    }

    try {
      // Use Dio's default boundary handling.
      final formData = FormData();

      // Use the injected creator function to create the audio file
      final audioFile = await _multipartFileCreator(audioFilePath);

      // Add fields and files manually
      formData.fields.add(MapEntry('user_id', userId));
      if (text != null) {
        formData.fields.add(MapEntry('text', text));
      }
      if (additionalText != null) {
        formData.fields.add(MapEntry('additional_text', additionalText));
      }
      formData.files.add(MapEntry('audio_file', audioFile));

      // Build the form data map for logging
      final formMap = <String, dynamic>{
        'user_id': userId,
        if (text != null) 'text': text,
        if (additionalText != null) 'additional_text': additionalText,
        'audio_file': 'Instance of \\\'MultipartFile\\\'',
      };

      _logger.d('$_tag FormData map prepared: $formMap');
      _logger.d('$_tag FormData using boundary: ${formData.boundary}');
      return formData;
    } catch (e, stackTrace) {
      _logger.e(
        '$_tag Failed to create MultipartFile or FormData',
        error: e,
        stackTrace: stackTrace,
      );
      // Wrap file system or other errors in an ApiException to be caught upstream
      if (e is ApiException) {
        rethrow; // Don't rewrap already-wrapped exceptions
      }
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
      final options = await _getOptionsWithAuth();
      final response = await dio.get(endpoint, options: options);

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
        String errorMessage =
            'Failed to fetch job. Status: ${response.statusCode}';
        if (response.data is Map<String, dynamic> &&
            (response.data as Map<String, dynamic>).containsKey('error')) {
          errorMessage =
              (response.data as Map<String, dynamic>)['error'].toString();
        }
        _logger.w(
          '$_tag Failed to fetch job $id. Status: ${response.statusCode}, Response: ${response.data}',
        );
        throw ApiException(
          message: errorMessage, // Use parsed error message
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
      // Re-throw if it's already an ApiException
      if (e is ApiException) {
        rethrow;
      }
      // Otherwise, wrap it
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
      final options = await _getOptionsWithAuth();
      final response = await dio.get(endpoint, options: options);

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
    required String audioFilePath,
    String? text,
    String? additionalText,
  }) async {
    final urlPath = '/jobs';
    _logger.d('$_tag Creating job with audio $audioFilePath at $urlPath');

    try {
      // Prepare FormData using the helper method
      final formData = await _createJobFormData(
        audioFilePath: audioFilePath,
        text: text,
        additionalText: additionalText,
      );

      // Get options WITHOUT specifying json content type
      final options = await _getOptionsWithAuth(isJsonRequest: false);

      // Post the form data
      final response = await dio.post(
        urlPath,
        data: formData,
        options: options,
      );

      // --- Success Case (201 Created or 200 OK) ---
      if ((response.statusCode == 201 || response.statusCode == 200) &&
          response.data != null) {
        _logger.i(
          '$_tag Job created successfully (${response.statusCode}). Response: ${response.data}',
        );

        // API wraps the job object in a "data" key
        final Map<String, dynamic> jobData = response.data['data'];

        // Manually map the response JSON to a Job entity
        // TODO: Consider using JobApiDTO and JobMapper here for consistency
        try {
          // IMPORTANT: When creating, the Job returned should represent the SERVER state,
          // but we DON'T have the original localId here. This function's return value
          // should probably only contain the fields returned by the server.
          // The SyncProcessorService will use this data to update the original local Job.
          return Job(
            // DO NOT use jobData['id'] as localId. LocalId is client-generated.
            // Leave localId empty or null here, as this Job represents the remote state.
            localId: '', // Or null
            serverId: jobData['id'] as String, // API 'id' IS the serverId
            userId: jobData['user_id'] as String,
            status: JobMapper.stringToJobStatus(
              jobData['job_status'] as String?,
            ),
            syncStatus:
                SyncStatus
                    .synced, // Newly created job starts as synced since it came from API
            createdAt: DateTime.parse(jobData['created_at'] as String),
            updatedAt: DateTime.parse(jobData['updated_at'] as String),
            text: jobData['text'] as String?,
            additionalText: jobData['additional_text'] as String?,
            // Fields not present in create response according to spec
            displayTitle: null,
            displayText: null,
            errorCode: null,
            errorMessage: null,
            audioFilePath: audioFilePath, // Keep the original path
          );
        } catch (e, stackTrace) {
          _logger.e(
            '$_tag Failed to parse createJob response JSON: $jobData',
            error: e,
            stackTrace: stackTrace,
          );
          throw ApiException(
            message:
                'Failed to process server response after job creation: ${e.toString()}',
          );
        }
      }
      // --- Error Case (Non-201/200) ---
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
    // --- Other Unexpected Error Case ---
    catch (e, stackTrace) {
      _logger.e(
        '$_tag Unexpected error in createJob: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      );
      // Re-throw if it's already an ApiException
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
    final urlPath = '/jobs/$jobId';
    _logger.d(
      '$_tag updateJob called for jobId: $jobId with updates: $updates at $urlPath',
    );

    try {
      // --- Make API Call ---
      final options = await _getOptionsWithAuth();
      final response = await dio.patch(
        urlPath,
        data: updates, // Send the updates map as the request body
        options: options,
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

  @override
  Future<List<Job>> syncJobs(List<Job> jobsToSync) async {
    // TODO: Implement actual sync logic with the backend API.
    // This will likely involve iterating through jobsToSync,
    // determining if it's a create/update/delete based on status and serverId,
    // and calling the appropriate API endpoints (POST/PATCH/DELETE).
    // Need to handle responses and update local job state accordingly.
    // Need robust error handling for network issues or API errors.
    _logger.w('$_tag syncJobs is not implemented yet.');
    // For now, return the input list as a placeholder to satisfy the interface.
    // In a real scenario, this would return the jobs after API interaction (e.g., with server IDs).
    return jobsToSync;
  }

  @override
  Future<Unit> deleteJob(String serverId) async {
    final urlPath = '/jobs/$serverId';
    _logger.d('$_tag Deleting job with serverId: $serverId from $urlPath');

    try {
      final options = await _getOptionsWithAuth();
      final response = await dio.delete(urlPath, options: options);

      // --- Success Case (200 OK or 204 No Content) ---
      if (response.statusCode == 200 || response.statusCode == 204) {
        _logger.i(
          '$_tag Successfully deleted job $serverId. Status: ${response.statusCode}',
        );
        return unit; // Return Unit on success
      }
      // --- Error Case (Non-200/204) ---
      else {
        String errorMessage =
            'Failed to delete job. Status: ${response.statusCode}';
        if (response.data is Map<String, dynamic> &&
            (response.data as Map<String, dynamic>).containsKey('error')) {
          errorMessage =
              (response.data as Map<String, dynamic>)['error'].toString();
        }
        _logger.w(
          '$_tag Failed to delete job $serverId. Status: ${response.statusCode}, Response: ${response.data}',
        );
        throw ApiException(
          message: errorMessage,
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      _logger.e(
        '$_tag DioException during delete job $serverId: ${e.message}',
        error: e,
        stackTrace: e.stackTrace,
      );
      throw ServerException();
    } catch (e, stackTrace) {
      // Catch other errors (e.g., getting auth options, unexpected)
      _logger.e(
        '$_tag Unexpected error during delete job $serverId: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException();
    }
  }

  // TODO: Define methods for GET /api/v1/jobs/{id}/documents if needed directly by this layer.
}
