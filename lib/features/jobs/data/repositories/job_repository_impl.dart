import 'dart:async';

import 'package:dartz/dartz.dart'; // Import dartz
import '../../../../core/error/failures.dart'; // Import Failure
import '../../../../core/utils/log_helpers.dart'; // Import Logger
import '../../domain/entities/job.dart';
import '../../domain/repositories/job_repository.dart';
import '../models/job_update_data.dart';
import '../services/job_deleter_service.dart';
import '../services/job_reader_service.dart';
import '../services/job_sync_service.dart';
import '../services/job_writer_service.dart';

/// Main implementation of [JobRepository] that orchestrates operations
/// by delegating to specialized service classes.
class JobRepositoryImpl implements JobRepository {
  final JobReaderService _readerService;
  final JobWriterService _writerService;
  final JobDeleterService _deleterService;
  final JobSyncService _syncService;
  final Logger _logger = LoggerFactory.getLogger(JobRepositoryImpl);
  static final String _tag = logTag(JobRepositoryImpl);

  /// Creates an instance of [JobRepositoryImpl].
  ///
  /// Requires instances of all the specialized job services.
  JobRepositoryImpl({
    required JobReaderService readerService,
    required JobWriterService writerService,
    required JobDeleterService deleterService,
    required JobSyncService syncService,
  }) : _readerService = readerService,
       _writerService = writerService,
       _deleterService = deleterService,
       _syncService = syncService {
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
      '$_tag Delegating createJob(audioFilePath: $audioFilePath, text: $text) to JobWriterService...',
    );
    return _writerService.createJob(audioFilePath: audioFilePath, text: text);
  }

  @override
  Future<Either<Failure, Job>> updateJob({
    required String localId,
    required JobUpdateData updates,
  }) {
    _logger.d(
      '$_tag Delegating updateJob(localId: $localId, updates: ...) to JobWriterService...',
    );
    return _writerService.updateJob(localId: localId, updates: updates);
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
    _logger.d('$_tag Delegating syncPendingJobs to JobSyncService...');
    return _syncService.syncPendingJobs();
  }

  @override
  Future<Either<Failure, Job>> syncSingleJob(Job job) {
    _logger.d(
      '$_tag Delegating syncSingleJob(job: ${job.localId}) to JobSyncService...',
    );
    return _syncService.syncSingleJob(job);
  }
}
