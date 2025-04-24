import 'dart:async';

import 'package:dartz/dartz.dart'; // Import dartz
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/error/failures.dart'; // Import Failure
import 'package:docjet_mobile/core/utils/log_helpers.dart'; // Import Logger
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_update_details.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart';
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart';

/// Main implementation of [JobRepository] that orchestrates operations
/// by delegating to specialized service classes.
class JobRepositoryImpl implements JobRepository {
  final JobReaderService _readerService;
  final JobWriterService _writerService;
  final JobDeleterService _deleterService;
  final JobSyncOrchestratorService _orchestratorService;
  // Currently unused - will be needed for authz validation in future methods
  final AuthSessionProvider _authSessionProvider;
  final Logger _logger = LoggerFactory.getLogger(JobRepositoryImpl);
  static final String _tag = logTag(JobRepositoryImpl);

  /// Creates an instance of [JobRepositoryImpl].
  ///
  /// Requires instances of all the specialized job services and an AuthSessionProvider
  /// to provide the authenticated user's context.
  JobRepositoryImpl({
    required JobReaderService readerService,
    required JobWriterService writerService,
    required JobDeleterService deleterService,
    required JobSyncOrchestratorService orchestratorService,
    required AuthSessionProvider authSessionProvider,
  }) : _readerService = readerService,
       _writerService = writerService,
       _deleterService = deleterService,
       _orchestratorService = orchestratorService,
       _authSessionProvider = authSessionProvider {
    _logger.i('$_tag JobRepositoryImpl initialized.');
  }

  // --- FETCHING OPERATIONS ---

  @override
  Future<Either<Failure, List<Job>>> getJobs() {
    _logger.d('$_tag Delegating getJobs to JobReaderService...');
    return _readerService.getJobs();
  }

  @override
  Future<Either<Failure, Job>> getJobById(String localId) {
    _logger.d('$_tag Delegating getJobById($localId) to JobReaderService...');
    return _readerService.getJobById(localId);
  }

  // --- WRITE OPERATIONS ---

  @override
  Future<Either<Failure, Job>> createJob({
    required String audioFilePath,
    String? text,
  }) {
    _logger.d(
      '$_tag createJob called with audioFilePath: $audioFilePath, text: $text',
    );

    // No longer need to get userId here - JobWriterService will get it from AuthSessionProvider
    return _writerService.createJob(audioFilePath: audioFilePath, text: text);
  }

  @override
  Future<Either<Failure, Job>> updateJob({
    required String localId,
    required JobUpdateDetails updates,
  }) {
    _logger.d(
      '$_tag Delegating updateJob(localId: $localId, updates: ...) to JobWriterService...',
    );
    final updateData = JobUpdateData(text: updates.text);
    return _writerService.updateJob(localId: localId, updates: updateData);
  }

  // --- DELETE OPERATIONS ---

  @override
  Future<Either<Failure, Unit>> deleteJob(String localId) {
    _logger.d('$_tag Delegating deleteJob($localId) to JobDeleterService...');
    return _deleterService.deleteJob(localId);
  }

  // --- SYNC OPERATIONS ---

  @override
  Future<Either<Failure, Unit>> syncPendingJobs() {
    _logger.d('Delegating syncPendingJobs to JobSyncOrchestratorService');
    return _orchestratorService.syncPendingJobs();
  }

  @override
  Future<Either<Failure, Unit>> resetFailedJob(String localId) {
    _logger.d(
      'Delegating resetFailedJob for localId: $localId to JobSyncOrchestratorService',
    );
    // Delegate directly to the orchestrator service's method
    return _orchestratorService.resetFailedJob(localId: localId);
  }

  // --- Stream Operations ---

  @override
  Stream<Either<Failure, List<Job>>> watchJobs() {
    _logger.d('$_tag watchJobs called');
    return _readerService.watchJobs();
  }

  @override
  Stream<Either<Failure, Job?>> watchJobById(String localId) {
    _logger.d('$_tag watchJobById called for id: $localId');
    return _readerService.watchJobById(localId);
  }
}
