// Mocks generated by Mockito 5.4.5 from annotations
// in docjet_mobile/test/features/jobs/e2e/e2e_setup_helpers.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i10;
import 'dart:io' as _i2;
import 'dart:typed_data' as _i12;

import 'package:dartz/dartz.dart' as _i8;
import 'package:dio/dio.dart' as _i3;
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart' as _i4;
import 'package:docjet_mobile/core/auth/auth_session_provider.dart' as _i5;
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart' as _i24;
import 'package:docjet_mobile/core/auth/events/auth_events.dart' as _i25;
import 'package:docjet_mobile/core/error/failures.dart' as _i18;
import 'package:docjet_mobile/core/interfaces/network_info.dart' as _i9;
import 'package:docjet_mobile/core/platform/file_system.dart' as _i6;
import 'package:docjet_mobile/features/jobs/data/datasources/api_job_remote_data_source_impl.dart'
    as _i13;
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart'
    as _i15;
import 'package:docjet_mobile/features/jobs/data/models/job_api_dto.dart'
    as _i14;
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart'
    as _i16;
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart'
    as _i21;
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart'
    as _i22;
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart'
    as _i19;
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart'
    as _i23;
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart'
    as _i20;
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart' as _i7;
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart'
    as _i17;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i11;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeFileStat_0 extends _i1.SmartFake implements _i2.FileStat {
  _FakeFileStat_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeDio_1 extends _i1.SmartFake implements _i3.Dio {
  _FakeDio_1(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeAuthCredentialsProvider_2 extends _i1.SmartFake
    implements _i4.AuthCredentialsProvider {
  _FakeAuthCredentialsProvider_2(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeAuthSessionProvider_3 extends _i1.SmartFake
    implements _i5.AuthSessionProvider {
  _FakeAuthSessionProvider_3(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeFileSystem_4 extends _i1.SmartFake implements _i6.FileSystem {
  _FakeFileSystem_4(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeJob_5 extends _i1.SmartFake implements _i7.Job {
  _FakeJob_5(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeUnit_6 extends _i1.SmartFake implements _i8.Unit {
  _FakeUnit_6(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeEither_7<L, R> extends _i1.SmartFake implements _i8.Either<L, R> {
  _FakeEither_7(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [NetworkInfo].
///
/// See the documentation for Mockito's code generation for more information.
class MockNetworkInfo extends _i1.Mock implements _i9.NetworkInfo {
  MockNetworkInfo() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i10.Future<bool> get isConnected => (super.noSuchMethod(
        Invocation.getter(#isConnected),
        returnValue: _i10.Future<bool>.value(false),
      ) as _i10.Future<bool>);

  @override
  _i10.Stream<bool> get onConnectivityChanged => (super.noSuchMethod(
        Invocation.getter(#onConnectivityChanged),
        returnValue: _i10.Stream<bool>.empty(),
      ) as _i10.Stream<bool>);
}

/// A class which mocks [AuthCredentialsProvider].
///
/// See the documentation for Mockito's code generation for more information.
class MockAuthCredentialsProvider extends _i1.Mock
    implements _i4.AuthCredentialsProvider {
  MockAuthCredentialsProvider() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i10.Future<String?> getApiKey() => (super.noSuchMethod(
        Invocation.method(
          #getApiKey,
          [],
        ),
        returnValue: _i10.Future<String?>.value(),
      ) as _i10.Future<String?>);

  @override
  _i10.Future<void> setAccessToken(String? token) => (super.noSuchMethod(
        Invocation.method(
          #setAccessToken,
          [token],
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);

  @override
  _i10.Future<String?> getAccessToken() => (super.noSuchMethod(
        Invocation.method(
          #getAccessToken,
          [],
        ),
        returnValue: _i10.Future<String?>.value(),
      ) as _i10.Future<String?>);

  @override
  _i10.Future<void> deleteAccessToken() => (super.noSuchMethod(
        Invocation.method(
          #deleteAccessToken,
          [],
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);

  @override
  _i10.Future<void> setRefreshToken(String? token) => (super.noSuchMethod(
        Invocation.method(
          #setRefreshToken,
          [token],
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);

  @override
  _i10.Future<String?> getRefreshToken() => (super.noSuchMethod(
        Invocation.method(
          #getRefreshToken,
          [],
        ),
        returnValue: _i10.Future<String?>.value(),
      ) as _i10.Future<String?>);

  @override
  _i10.Future<void> deleteRefreshToken() => (super.noSuchMethod(
        Invocation.method(
          #deleteRefreshToken,
          [],
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);

  @override
  _i10.Future<void> setUserId(String? userId) => (super.noSuchMethod(
        Invocation.method(
          #setUserId,
          [userId],
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);

  @override
  _i10.Future<String?> getUserId() => (super.noSuchMethod(
        Invocation.method(
          #getUserId,
          [],
        ),
        returnValue: _i10.Future<String?>.value(),
      ) as _i10.Future<String?>);

  @override
  _i10.Future<bool> isAccessTokenValid() => (super.noSuchMethod(
        Invocation.method(
          #isAccessTokenValid,
          [],
        ),
        returnValue: _i10.Future<bool>.value(false),
      ) as _i10.Future<bool>);

  @override
  _i10.Future<bool> isRefreshTokenValid() => (super.noSuchMethod(
        Invocation.method(
          #isRefreshTokenValid,
          [],
        ),
        returnValue: _i10.Future<bool>.value(false),
      ) as _i10.Future<bool>);
}

/// A class which mocks [AuthSessionProvider].
///
/// See the documentation for Mockito's code generation for more information.
class MockAuthSessionProvider extends _i1.Mock
    implements _i5.AuthSessionProvider {
  MockAuthSessionProvider() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i10.Future<String> getCurrentUserId() => (super.noSuchMethod(
        Invocation.method(
          #getCurrentUserId,
          [],
        ),
        returnValue: _i10.Future<String>.value(_i11.dummyValue<String>(
          this,
          Invocation.method(
            #getCurrentUserId,
            [],
          ),
        )),
      ) as _i10.Future<String>);

  @override
  _i10.Future<bool> isAuthenticated() => (super.noSuchMethod(
        Invocation.method(
          #isAuthenticated,
          [],
        ),
        returnValue: _i10.Future<bool>.value(false),
      ) as _i10.Future<bool>);
}

/// A class which mocks [FileSystem].
///
/// See the documentation for Mockito's code generation for more information.
class MockFileSystem extends _i1.Mock implements _i6.FileSystem {
  MockFileSystem() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i10.Future<_i2.FileStat> stat(String? path) => (super.noSuchMethod(
        Invocation.method(
          #stat,
          [path],
        ),
        returnValue: _i10.Future<_i2.FileStat>.value(_FakeFileStat_0(
          this,
          Invocation.method(
            #stat,
            [path],
          ),
        )),
      ) as _i10.Future<_i2.FileStat>);

  @override
  _i10.Future<bool> fileExists(String? path) => (super.noSuchMethod(
        Invocation.method(
          #fileExists,
          [path],
        ),
        returnValue: _i10.Future<bool>.value(false),
      ) as _i10.Future<bool>);

  @override
  _i10.Future<void> deleteFile(String? path) => (super.noSuchMethod(
        Invocation.method(
          #deleteFile,
          [path],
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);

  @override
  _i10.Future<bool> directoryExists(String? path) => (super.noSuchMethod(
        Invocation.method(
          #directoryExists,
          [path],
        ),
        returnValue: _i10.Future<bool>.value(false),
      ) as _i10.Future<bool>);

  @override
  _i10.Future<void> createDirectory(
    String? path, {
    bool? recursive = false,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #createDirectory,
          [path],
          {#recursive: recursive},
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);

  @override
  _i10.Stream<_i2.FileSystemEntity> listDirectory(String? path) =>
      (super.noSuchMethod(
        Invocation.method(
          #listDirectory,
          [path],
        ),
        returnValue: _i10.Stream<_i2.FileSystemEntity>.empty(),
      ) as _i10.Stream<_i2.FileSystemEntity>);

  @override
  _i10.Future<void> writeFile(
    String? path,
    _i12.Uint8List? bytes,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #writeFile,
          [
            path,
            bytes,
          ],
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);

  @override
  _i10.Future<List<int>> readFile(String? path) => (super.noSuchMethod(
        Invocation.method(
          #readFile,
          [path],
        ),
        returnValue: _i10.Future<List<int>>.value(<int>[]),
      ) as _i10.Future<List<int>>);

  @override
  String resolvePath(String? path) => (super.noSuchMethod(
        Invocation.method(
          #resolvePath,
          [path],
        ),
        returnValue: _i11.dummyValue<String>(
          this,
          Invocation.method(
            #resolvePath,
            [path],
          ),
        ),
      ) as String);
}

/// A class which mocks [ApiJobRemoteDataSourceImpl].
///
/// See the documentation for Mockito's code generation for more information.
class MockApiJobRemoteDataSourceImpl extends _i1.Mock
    implements _i13.ApiJobRemoteDataSourceImpl {
  MockApiJobRemoteDataSourceImpl() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Dio get dio => (super.noSuchMethod(
        Invocation.getter(#dio),
        returnValue: _FakeDio_1(
          this,
          Invocation.getter(#dio),
        ),
      ) as _i3.Dio);

  @override
  _i4.AuthCredentialsProvider get authCredentialsProvider =>
      (super.noSuchMethod(
        Invocation.getter(#authCredentialsProvider),
        returnValue: _FakeAuthCredentialsProvider_2(
          this,
          Invocation.getter(#authCredentialsProvider),
        ),
      ) as _i4.AuthCredentialsProvider);

  @override
  _i5.AuthSessionProvider get authSessionProvider => (super.noSuchMethod(
        Invocation.getter(#authSessionProvider),
        returnValue: _FakeAuthSessionProvider_3(
          this,
          Invocation.getter(#authSessionProvider),
        ),
      ) as _i5.AuthSessionProvider);

  @override
  _i6.FileSystem get fileSystem => (super.noSuchMethod(
        Invocation.getter(#fileSystem),
        returnValue: _FakeFileSystem_4(
          this,
          Invocation.getter(#fileSystem),
        ),
      ) as _i6.FileSystem);

  @override
  _i10.Future<_i7.Job> fetchJobById(String? id) => (super.noSuchMethod(
        Invocation.method(
          #fetchJobById,
          [id],
        ),
        returnValue: _i10.Future<_i7.Job>.value(_FakeJob_5(
          this,
          Invocation.method(
            #fetchJobById,
            [id],
          ),
        )),
      ) as _i10.Future<_i7.Job>);

  @override
  _i10.Future<List<_i14.JobApiDTO>> fetchJobs() => (super.noSuchMethod(
        Invocation.method(
          #fetchJobs,
          [],
        ),
        returnValue:
            _i10.Future<List<_i14.JobApiDTO>>.value(<_i14.JobApiDTO>[]),
      ) as _i10.Future<List<_i14.JobApiDTO>>);

  @override
  _i10.Future<_i7.Job> createJob({
    required String? audioFilePath,
    String? text,
    String? additionalText,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #createJob,
          [],
          {
            #audioFilePath: audioFilePath,
            #text: text,
            #additionalText: additionalText,
          },
        ),
        returnValue: _i10.Future<_i7.Job>.value(_FakeJob_5(
          this,
          Invocation.method(
            #createJob,
            [],
            {
              #audioFilePath: audioFilePath,
              #text: text,
              #additionalText: additionalText,
            },
          ),
        )),
      ) as _i10.Future<_i7.Job>);

  @override
  _i10.Future<_i7.Job> updateJob({
    required String? jobId,
    required Map<String, dynamic>? updates,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #updateJob,
          [],
          {
            #jobId: jobId,
            #updates: updates,
          },
        ),
        returnValue: _i10.Future<_i7.Job>.value(_FakeJob_5(
          this,
          Invocation.method(
            #updateJob,
            [],
            {
              #jobId: jobId,
              #updates: updates,
            },
          ),
        )),
      ) as _i10.Future<_i7.Job>);

  @override
  _i10.Future<List<_i7.Job>> syncJobs(List<_i7.Job>? jobsToSync) =>
      (super.noSuchMethod(
        Invocation.method(
          #syncJobs,
          [jobsToSync],
        ),
        returnValue: _i10.Future<List<_i7.Job>>.value(<_i7.Job>[]),
      ) as _i10.Future<List<_i7.Job>>);

  @override
  _i10.Future<_i8.Unit> deleteJob(String? serverId) => (super.noSuchMethod(
        Invocation.method(
          #deleteJob,
          [serverId],
        ),
        returnValue: _i10.Future<_i8.Unit>.value(_FakeUnit_6(
          this,
          Invocation.method(
            #deleteJob,
            [serverId],
          ),
        )),
      ) as _i10.Future<_i8.Unit>);
}

/// A class which mocks [JobLocalDataSource].
///
/// See the documentation for Mockito's code generation for more information.
class MockJobLocalDataSource extends _i1.Mock
    implements _i15.JobLocalDataSource {
  MockJobLocalDataSource() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i10.Future<List<_i16.JobHiveModel>> getAllJobHiveModels() =>
      (super.noSuchMethod(
        Invocation.method(
          #getAllJobHiveModels,
          [],
        ),
        returnValue:
            _i10.Future<List<_i16.JobHiveModel>>.value(<_i16.JobHiveModel>[]),
      ) as _i10.Future<List<_i16.JobHiveModel>>);

  @override
  _i10.Future<_i16.JobHiveModel?> getJobHiveModelById(String? id) =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobHiveModelById,
          [id],
        ),
        returnValue: _i10.Future<_i16.JobHiveModel?>.value(),
      ) as _i10.Future<_i16.JobHiveModel?>);

  @override
  _i10.Future<void> saveJobHiveModel(_i16.JobHiveModel? model) =>
      (super.noSuchMethod(
        Invocation.method(
          #saveJobHiveModel,
          [model],
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);

  @override
  _i10.Future<void> deleteJobHiveModel(String? id) => (super.noSuchMethod(
        Invocation.method(
          #deleteJobHiveModel,
          [id],
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);

  @override
  _i10.Future<DateTime?> getLastFetchTime() => (super.noSuchMethod(
        Invocation.method(
          #getLastFetchTime,
          [],
        ),
        returnValue: _i10.Future<DateTime?>.value(),
      ) as _i10.Future<DateTime?>);

  @override
  _i10.Future<void> saveLastFetchTime(DateTime? time) => (super.noSuchMethod(
        Invocation.method(
          #saveLastFetchTime,
          [time],
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);

  @override
  _i10.Future<List<_i7.Job>> getJobsToSync() => (super.noSuchMethod(
        Invocation.method(
          #getJobsToSync,
          [],
        ),
        returnValue: _i10.Future<List<_i7.Job>>.value(<_i7.Job>[]),
      ) as _i10.Future<List<_i7.Job>>);

  @override
  _i10.Future<void> updateJobSyncStatus(
    String? id,
    _i17.SyncStatus? status,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #updateJobSyncStatus,
          [
            id,
            status,
          ],
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);

  @override
  _i10.Future<List<_i7.Job>> getSyncedJobs() => (super.noSuchMethod(
        Invocation.method(
          #getSyncedJobs,
          [],
        ),
        returnValue: _i10.Future<List<_i7.Job>>.value(<_i7.Job>[]),
      ) as _i10.Future<List<_i7.Job>>);

  @override
  _i10.Future<List<_i7.Job>> getJobsToRetry(
    int? maxRetries,
    Duration? baseBackoffDuration,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobsToRetry,
          [
            maxRetries,
            baseBackoffDuration,
          ],
        ),
        returnValue: _i10.Future<List<_i7.Job>>.value(<_i7.Job>[]),
      ) as _i10.Future<List<_i7.Job>>);

  @override
  _i10.Future<List<_i7.Job>> getJobs() => (super.noSuchMethod(
        Invocation.method(
          #getJobs,
          [],
        ),
        returnValue: _i10.Future<List<_i7.Job>>.value(<_i7.Job>[]),
      ) as _i10.Future<List<_i7.Job>>);

  @override
  _i10.Future<_i7.Job> getJobById(String? localId) => (super.noSuchMethod(
        Invocation.method(
          #getJobById,
          [localId],
        ),
        returnValue: _i10.Future<_i7.Job>.value(_FakeJob_5(
          this,
          Invocation.method(
            #getJobById,
            [localId],
          ),
        )),
      ) as _i10.Future<_i7.Job>);

  @override
  _i10.Future<_i8.Unit> saveJob(_i7.Job? job) => (super.noSuchMethod(
        Invocation.method(
          #saveJob,
          [job],
        ),
        returnValue: _i10.Future<_i8.Unit>.value(_FakeUnit_6(
          this,
          Invocation.method(
            #saveJob,
            [job],
          ),
        )),
      ) as _i10.Future<_i8.Unit>);

  @override
  _i10.Future<_i8.Unit> deleteJob(String? localId) => (super.noSuchMethod(
        Invocation.method(
          #deleteJob,
          [localId],
        ),
        returnValue: _i10.Future<_i8.Unit>.value(_FakeUnit_6(
          this,
          Invocation.method(
            #deleteJob,
            [localId],
          ),
        )),
      ) as _i10.Future<_i8.Unit>);

  @override
  _i10.Future<List<_i7.Job>> getJobsByStatus(_i17.SyncStatus? status) =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobsByStatus,
          [status],
        ),
        returnValue: _i10.Future<List<_i7.Job>>.value(<_i7.Job>[]),
      ) as _i10.Future<List<_i7.Job>>);

  @override
  _i10.Stream<_i8.Either<_i18.Failure, List<_i7.Job>>> watchJobs() =>
      (super.noSuchMethod(
        Invocation.method(
          #watchJobs,
          [],
        ),
        returnValue:
            _i10.Stream<_i8.Either<_i18.Failure, List<_i7.Job>>>.empty(),
      ) as _i10.Stream<_i8.Either<_i18.Failure, List<_i7.Job>>>);

  @override
  _i10.Stream<_i8.Either<_i18.Failure, _i7.Job?>> watchJobById(String? id) =>
      (super.noSuchMethod(
        Invocation.method(
          #watchJobById,
          [id],
        ),
        returnValue: _i10.Stream<_i8.Either<_i18.Failure, _i7.Job?>>.empty(),
      ) as _i10.Stream<_i8.Either<_i18.Failure, _i7.Job?>>);

  @override
  _i10.Future<List<_i16.JobHiveModel>> getJobsPendingSync() =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobsPendingSync,
          [],
        ),
        returnValue:
            _i10.Future<List<_i16.JobHiveModel>>.value(<_i16.JobHiveModel>[]),
      ) as _i10.Future<List<_i16.JobHiveModel>>);

  @override
  _i10.Future<void> clearUserData() => (super.noSuchMethod(
        Invocation.method(
          #clearUserData,
          [],
        ),
        returnValue: _i10.Future<void>.value(),
        returnValueForMissingStub: _i10.Future<void>.value(),
      ) as _i10.Future<void>);
}

/// A class which mocks [JobReaderService].
///
/// See the documentation for Mockito's code generation for more information.
class MockJobReaderService extends _i1.Mock implements _i19.JobReaderService {
  MockJobReaderService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i10.Future<_i8.Either<_i18.Failure, List<_i7.Job>>> getJobs() =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobs,
          [],
        ),
        returnValue: _i10.Future<_i8.Either<_i18.Failure, List<_i7.Job>>>.value(
            _FakeEither_7<_i18.Failure, List<_i7.Job>>(
          this,
          Invocation.method(
            #getJobs,
            [],
          ),
        )),
      ) as _i10.Future<_i8.Either<_i18.Failure, List<_i7.Job>>>);

  @override
  _i10.Future<_i8.Either<_i18.Failure, _i7.Job>> getJobById(String? localId) =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobById,
          [localId],
        ),
        returnValue: _i10.Future<_i8.Either<_i18.Failure, _i7.Job>>.value(
            _FakeEither_7<_i18.Failure, _i7.Job>(
          this,
          Invocation.method(
            #getJobById,
            [localId],
          ),
        )),
      ) as _i10.Future<_i8.Either<_i18.Failure, _i7.Job>>);

  @override
  _i10.Future<_i8.Either<_i18.Failure, List<_i7.Job>>> getJobsByStatus(
          _i17.SyncStatus? status) =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobsByStatus,
          [status],
        ),
        returnValue: _i10.Future<_i8.Either<_i18.Failure, List<_i7.Job>>>.value(
            _FakeEither_7<_i18.Failure, List<_i7.Job>>(
          this,
          Invocation.method(
            #getJobsByStatus,
            [status],
          ),
        )),
      ) as _i10.Future<_i8.Either<_i18.Failure, List<_i7.Job>>>);

  @override
  _i10.Stream<_i8.Either<_i18.Failure, List<_i7.Job>>> watchJobs() =>
      (super.noSuchMethod(
        Invocation.method(
          #watchJobs,
          [],
        ),
        returnValue:
            _i10.Stream<_i8.Either<_i18.Failure, List<_i7.Job>>>.empty(),
      ) as _i10.Stream<_i8.Either<_i18.Failure, List<_i7.Job>>>);

  @override
  _i10.Stream<_i8.Either<_i18.Failure, _i7.Job?>> watchJobById(
          String? localId) =>
      (super.noSuchMethod(
        Invocation.method(
          #watchJobById,
          [localId],
        ),
        returnValue: _i10.Stream<_i8.Either<_i18.Failure, _i7.Job?>>.empty(),
      ) as _i10.Stream<_i8.Either<_i18.Failure, _i7.Job?>>);
}

/// A class which mocks [JobWriterService].
///
/// See the documentation for Mockito's code generation for more information.
class MockJobWriterService extends _i1.Mock implements _i20.JobWriterService {
  MockJobWriterService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i10.Future<_i8.Either<_i18.Failure, _i7.Job>> createJob({
    required String? audioFilePath,
    String? text,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #createJob,
          [],
          {
            #audioFilePath: audioFilePath,
            #text: text,
          },
        ),
        returnValue: _i10.Future<_i8.Either<_i18.Failure, _i7.Job>>.value(
            _FakeEither_7<_i18.Failure, _i7.Job>(
          this,
          Invocation.method(
            #createJob,
            [],
            {
              #audioFilePath: audioFilePath,
              #text: text,
            },
          ),
        )),
      ) as _i10.Future<_i8.Either<_i18.Failure, _i7.Job>>);

  @override
  _i10.Future<_i8.Either<_i18.Failure, _i7.Job>> updateJob({
    required String? localId,
    required _i21.JobUpdateData? updates,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #updateJob,
          [],
          {
            #localId: localId,
            #updates: updates,
          },
        ),
        returnValue: _i10.Future<_i8.Either<_i18.Failure, _i7.Job>>.value(
            _FakeEither_7<_i18.Failure, _i7.Job>(
          this,
          Invocation.method(
            #updateJob,
            [],
            {
              #localId: localId,
              #updates: updates,
            },
          ),
        )),
      ) as _i10.Future<_i8.Either<_i18.Failure, _i7.Job>>);

  @override
  _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>> updateJobSyncStatus({
    required String? localId,
    required _i17.SyncStatus? status,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #updateJobSyncStatus,
          [],
          {
            #localId: localId,
            #status: status,
          },
        ),
        returnValue: _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>>.value(
            _FakeEither_7<_i18.Failure, _i8.Unit>(
          this,
          Invocation.method(
            #updateJobSyncStatus,
            [],
            {
              #localId: localId,
              #status: status,
            },
          ),
        )),
      ) as _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>>);

  @override
  _i10.Future<_i8.Either<_i18.Failure, _i7.Job>> resetDeletionFailureCounter(
          String? localId) =>
      (super.noSuchMethod(
        Invocation.method(
          #resetDeletionFailureCounter,
          [localId],
        ),
        returnValue: _i10.Future<_i8.Either<_i18.Failure, _i7.Job>>.value(
            _FakeEither_7<_i18.Failure, _i7.Job>(
          this,
          Invocation.method(
            #resetDeletionFailureCounter,
            [localId],
          ),
        )),
      ) as _i10.Future<_i8.Either<_i18.Failure, _i7.Job>>);
}

/// A class which mocks [JobDeleterService].
///
/// See the documentation for Mockito's code generation for more information.
class MockJobDeleterService extends _i1.Mock implements _i22.JobDeleterService {
  MockJobDeleterService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>> deleteJob(String? localId) =>
      (super.noSuchMethod(
        Invocation.method(
          #deleteJob,
          [localId],
        ),
        returnValue: _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>>.value(
            _FakeEither_7<_i18.Failure, _i8.Unit>(
          this,
          Invocation.method(
            #deleteJob,
            [localId],
          ),
        )),
      ) as _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>>);

  @override
  _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>> permanentlyDeleteJob(
          String? localId) =>
      (super.noSuchMethod(
        Invocation.method(
          #permanentlyDeleteJob,
          [localId],
        ),
        returnValue: _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>>.value(
            _FakeEither_7<_i18.Failure, _i8.Unit>(
          this,
          Invocation.method(
            #permanentlyDeleteJob,
            [localId],
          ),
        )),
      ) as _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>>);

  @override
  _i10.Future<_i8.Either<_i18.Failure, bool>> attemptSmartDelete(
          String? localId) =>
      (super.noSuchMethod(
        Invocation.method(
          #attemptSmartDelete,
          [localId],
        ),
        returnValue: _i10.Future<_i8.Either<_i18.Failure, bool>>.value(
            _FakeEither_7<_i18.Failure, bool>(
          this,
          Invocation.method(
            #attemptSmartDelete,
            [localId],
          ),
        )),
      ) as _i10.Future<_i8.Either<_i18.Failure, bool>>);
}

/// A class which mocks [JobSyncOrchestratorService].
///
/// See the documentation for Mockito's code generation for more information.
class MockJobSyncOrchestratorService extends _i1.Mock
    implements _i23.JobSyncOrchestratorService {
  MockJobSyncOrchestratorService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  bool get isLogoutInProgress => (super.noSuchMethod(
        Invocation.getter(#isLogoutInProgress),
        returnValue: false,
      ) as bool);

  @override
  _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>> syncPendingJobs() =>
      (super.noSuchMethod(
        Invocation.method(
          #syncPendingJobs,
          [],
        ),
        returnValue: _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>>.value(
            _FakeEither_7<_i18.Failure, _i8.Unit>(
          this,
          Invocation.method(
            #syncPendingJobs,
            [],
          ),
        )),
      ) as _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>>);

  @override
  _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>> resetFailedJob(
          {required String? localId}) =>
      (super.noSuchMethod(
        Invocation.method(
          #resetFailedJob,
          [],
          {#localId: localId},
        ),
        returnValue: _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>>.value(
            _FakeEither_7<_i18.Failure, _i8.Unit>(
          this,
          Invocation.method(
            #resetFailedJob,
            [],
            {#localId: localId},
          ),
        )),
      ) as _i10.Future<_i8.Either<_i18.Failure, _i8.Unit>>);

  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [AuthEventBus].
///
/// See the documentation for Mockito's code generation for more information.
class MockAuthEventBus extends _i1.Mock implements _i24.AuthEventBus {
  MockAuthEventBus() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i10.Stream<_i25.AuthEvent> get stream => (super.noSuchMethod(
        Invocation.getter(#stream),
        returnValue: _i10.Stream<_i25.AuthEvent>.empty(),
      ) as _i10.Stream<_i25.AuthEvent>);

  @override
  void add(_i25.AuthEvent? event) => super.noSuchMethod(
        Invocation.method(
          #add,
          [event],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValueForMissingStub: null,
      );
}
