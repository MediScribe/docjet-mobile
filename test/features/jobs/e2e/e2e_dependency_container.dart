import 'package:dio/dio.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';

// Import the mocks generated for the helper file
import 'e2e_setup_helpers.mocks.dart';

/// Container for dependencies created during E2E test setup.
/// This avoids using the global service locator (sl) within tests.
class E2EDependencyContainer {
  // Mocks
  final MockNetworkInfo mockNetworkInfo;
  final MockAuthCredentialsProvider mockAuthCredentialsProvider;
  final MockAuthSessionProvider mockAuthSessionProvider;
  final MockFileSystem mockFileSystem;
  final MockApiJobRemoteDataSourceImpl mockApiJobRemoteDataSource;
  final MockAuthEventBus mockAuthEventBus;
  // Potentially mock local data source too if needed for specific tests
  // final MockJobLocalDataSource mockJobLocalDataSource;

  // Real Instances (or potentially mocks depending on setup)
  final Dio dio;
  final Uuid uuid;
  final HiveInterface hive;
  final Box<JobHiveModel> jobBox;
  final JobLocalDataSource jobLocalDataSource; // Usually real Hive impl
  final JobRemoteDataSource jobRemoteDataSource; // Could be real or mock impl
  final JobRepository jobRepository; // Usually real impl using other deps
  final AuthEventBus authEventBus; // Usually real instance

  E2EDependencyContainer({
    // Mocks
    required this.mockNetworkInfo,
    required this.mockAuthCredentialsProvider,
    required this.mockAuthSessionProvider,
    required this.mockFileSystem,
    required this.mockApiJobRemoteDataSource,
    required this.mockAuthEventBus,

    // Real Instances
    required this.dio,
    required this.uuid,
    required this.hive,
    required this.jobBox,
    required this.jobLocalDataSource,
    required this.jobRemoteDataSource,
    required this.jobRepository,
    required this.authEventBus,
  });
}
