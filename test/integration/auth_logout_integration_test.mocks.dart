// Mocks generated by Mockito 5.4.5 from annotations
// in docjet_mobile/test/integration/auth_logout_integration_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i6;

import 'package:dartz/dartz.dart' as _i3;
import 'package:docjet_mobile/core/auth/auth_service.dart' as _i17;
import 'package:docjet_mobile/core/auth/auth_session_provider.dart' as _i10;
import 'package:docjet_mobile/core/auth/entities/user.dart' as _i4;
import 'package:docjet_mobile/core/error/failures.dart' as _i9;
import 'package:docjet_mobile/features/jobs/data/datasources/job_local_data_source.dart'
    as _i5;
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart'
    as _i7;
import 'package:docjet_mobile/features/jobs/data/models/job_update_data.dart'
    as _i14;
import 'package:docjet_mobile/features/jobs/data/services/job_deleter_service.dart'
    as _i15;
import 'package:docjet_mobile/features/jobs/data/services/job_reader_service.dart'
    as _i12;
import 'package:docjet_mobile/features/jobs/data/services/job_sync_orchestrator_service.dart'
    as _i16;
import 'package:docjet_mobile/features/jobs/data/services/job_writer_service.dart'
    as _i13;
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart' as _i2;
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart'
    as _i8;
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

class _FakeJob_0 extends _i1.SmartFake implements _i2.Job {
  _FakeJob_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeUnit_1 extends _i1.SmartFake implements _i3.Unit {
  _FakeUnit_1(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeEither_2<L, R> extends _i1.SmartFake implements _i3.Either<L, R> {
  _FakeEither_2(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeUser_3 extends _i1.SmartFake implements _i4.User {
  _FakeUser_3(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [JobLocalDataSource].
///
/// See the documentation for Mockito's code generation for more information.
class MockJobLocalDataSource extends _i1.Mock
    implements _i5.JobLocalDataSource {
  MockJobLocalDataSource() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<List<_i7.JobHiveModel>> getAllJobHiveModels() =>
      (super.noSuchMethod(
        Invocation.method(
          #getAllJobHiveModels,
          [],
        ),
        returnValue:
            _i6.Future<List<_i7.JobHiveModel>>.value(<_i7.JobHiveModel>[]),
      ) as _i6.Future<List<_i7.JobHiveModel>>);

  @override
  _i6.Future<_i7.JobHiveModel?> getJobHiveModelById(String? id) =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobHiveModelById,
          [id],
        ),
        returnValue: _i6.Future<_i7.JobHiveModel?>.value(),
      ) as _i6.Future<_i7.JobHiveModel?>);

  @override
  _i6.Future<void> saveJobHiveModel(_i7.JobHiveModel? model) =>
      (super.noSuchMethod(
        Invocation.method(
          #saveJobHiveModel,
          [model],
        ),
        returnValue: _i6.Future<void>.value(),
        returnValueForMissingStub: _i6.Future<void>.value(),
      ) as _i6.Future<void>);

  @override
  _i6.Future<void> deleteJobHiveModel(String? id) => (super.noSuchMethod(
        Invocation.method(
          #deleteJobHiveModel,
          [id],
        ),
        returnValue: _i6.Future<void>.value(),
        returnValueForMissingStub: _i6.Future<void>.value(),
      ) as _i6.Future<void>);

  @override
  _i6.Future<DateTime?> getLastFetchTime() => (super.noSuchMethod(
        Invocation.method(
          #getLastFetchTime,
          [],
        ),
        returnValue: _i6.Future<DateTime?>.value(),
      ) as _i6.Future<DateTime?>);

  @override
  _i6.Future<void> saveLastFetchTime(DateTime? time) => (super.noSuchMethod(
        Invocation.method(
          #saveLastFetchTime,
          [time],
        ),
        returnValue: _i6.Future<void>.value(),
        returnValueForMissingStub: _i6.Future<void>.value(),
      ) as _i6.Future<void>);

  @override
  _i6.Future<List<_i2.Job>> getJobsToSync() => (super.noSuchMethod(
        Invocation.method(
          #getJobsToSync,
          [],
        ),
        returnValue: _i6.Future<List<_i2.Job>>.value(<_i2.Job>[]),
      ) as _i6.Future<List<_i2.Job>>);

  @override
  _i6.Future<void> updateJobSyncStatus(
    String? id,
    _i8.SyncStatus? status,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #updateJobSyncStatus,
          [
            id,
            status,
          ],
        ),
        returnValue: _i6.Future<void>.value(),
        returnValueForMissingStub: _i6.Future<void>.value(),
      ) as _i6.Future<void>);

  @override
  _i6.Future<List<_i2.Job>> getSyncedJobs() => (super.noSuchMethod(
        Invocation.method(
          #getSyncedJobs,
          [],
        ),
        returnValue: _i6.Future<List<_i2.Job>>.value(<_i2.Job>[]),
      ) as _i6.Future<List<_i2.Job>>);

  @override
  _i6.Future<List<_i2.Job>> getJobsToRetry(
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
        returnValue: _i6.Future<List<_i2.Job>>.value(<_i2.Job>[]),
      ) as _i6.Future<List<_i2.Job>>);

  @override
  _i6.Future<List<_i2.Job>> getJobs() => (super.noSuchMethod(
        Invocation.method(
          #getJobs,
          [],
        ),
        returnValue: _i6.Future<List<_i2.Job>>.value(<_i2.Job>[]),
      ) as _i6.Future<List<_i2.Job>>);

  @override
  _i6.Future<_i2.Job> getJobById(String? localId) => (super.noSuchMethod(
        Invocation.method(
          #getJobById,
          [localId],
        ),
        returnValue: _i6.Future<_i2.Job>.value(_FakeJob_0(
          this,
          Invocation.method(
            #getJobById,
            [localId],
          ),
        )),
      ) as _i6.Future<_i2.Job>);

  @override
  _i6.Future<_i3.Unit> saveJob(_i2.Job? job) => (super.noSuchMethod(
        Invocation.method(
          #saveJob,
          [job],
        ),
        returnValue: _i6.Future<_i3.Unit>.value(_FakeUnit_1(
          this,
          Invocation.method(
            #saveJob,
            [job],
          ),
        )),
      ) as _i6.Future<_i3.Unit>);

  @override
  _i6.Future<_i3.Unit> deleteJob(String? localId) => (super.noSuchMethod(
        Invocation.method(
          #deleteJob,
          [localId],
        ),
        returnValue: _i6.Future<_i3.Unit>.value(_FakeUnit_1(
          this,
          Invocation.method(
            #deleteJob,
            [localId],
          ),
        )),
      ) as _i6.Future<_i3.Unit>);

  @override
  _i6.Future<List<_i2.Job>> getJobsByStatus(_i8.SyncStatus? status) =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobsByStatus,
          [status],
        ),
        returnValue: _i6.Future<List<_i2.Job>>.value(<_i2.Job>[]),
      ) as _i6.Future<List<_i2.Job>>);

  @override
  _i6.Stream<_i3.Either<_i9.Failure, List<_i2.Job>>> watchJobs() =>
      (super.noSuchMethod(
        Invocation.method(
          #watchJobs,
          [],
        ),
        returnValue: _i6.Stream<_i3.Either<_i9.Failure, List<_i2.Job>>>.empty(),
      ) as _i6.Stream<_i3.Either<_i9.Failure, List<_i2.Job>>>);

  @override
  _i6.Stream<_i3.Either<_i9.Failure, _i2.Job?>> watchJobById(String? id) =>
      (super.noSuchMethod(
        Invocation.method(
          #watchJobById,
          [id],
        ),
        returnValue: _i6.Stream<_i3.Either<_i9.Failure, _i2.Job?>>.empty(),
      ) as _i6.Stream<_i3.Either<_i9.Failure, _i2.Job?>>);

  @override
  _i6.Future<List<_i7.JobHiveModel>> getJobsPendingSync() =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobsPendingSync,
          [],
        ),
        returnValue:
            _i6.Future<List<_i7.JobHiveModel>>.value(<_i7.JobHiveModel>[]),
      ) as _i6.Future<List<_i7.JobHiveModel>>);

  @override
  _i6.Future<void> clearUserData() => (super.noSuchMethod(
        Invocation.method(
          #clearUserData,
          [],
        ),
        returnValue: _i6.Future<void>.value(),
        returnValueForMissingStub: _i6.Future<void>.value(),
      ) as _i6.Future<void>);
}

/// A class which mocks [AuthSessionProvider].
///
/// See the documentation for Mockito's code generation for more information.
class MockAuthSessionProvider extends _i1.Mock
    implements _i10.AuthSessionProvider {
  MockAuthSessionProvider() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<String> getCurrentUserId() => (super.noSuchMethod(
        Invocation.method(
          #getCurrentUserId,
          [],
        ),
        returnValue: _i6.Future<String>.value(_i11.dummyValue<String>(
          this,
          Invocation.method(
            #getCurrentUserId,
            [],
          ),
        )),
      ) as _i6.Future<String>);

  @override
  _i6.Future<bool> isAuthenticated() => (super.noSuchMethod(
        Invocation.method(
          #isAuthenticated,
          [],
        ),
        returnValue: _i6.Future<bool>.value(false),
      ) as _i6.Future<bool>);
}

/// A class which mocks [JobReaderService].
///
/// See the documentation for Mockito's code generation for more information.
class MockJobReaderService extends _i1.Mock implements _i12.JobReaderService {
  MockJobReaderService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<_i3.Either<_i9.Failure, List<_i2.Job>>> getJobs() =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobs,
          [],
        ),
        returnValue: _i6.Future<_i3.Either<_i9.Failure, List<_i2.Job>>>.value(
            _FakeEither_2<_i9.Failure, List<_i2.Job>>(
          this,
          Invocation.method(
            #getJobs,
            [],
          ),
        )),
      ) as _i6.Future<_i3.Either<_i9.Failure, List<_i2.Job>>>);

  @override
  _i6.Future<_i3.Either<_i9.Failure, _i2.Job>> getJobById(String? localId) =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobById,
          [localId],
        ),
        returnValue: _i6.Future<_i3.Either<_i9.Failure, _i2.Job>>.value(
            _FakeEither_2<_i9.Failure, _i2.Job>(
          this,
          Invocation.method(
            #getJobById,
            [localId],
          ),
        )),
      ) as _i6.Future<_i3.Either<_i9.Failure, _i2.Job>>);

  @override
  _i6.Future<_i3.Either<_i9.Failure, List<_i2.Job>>> getJobsByStatus(
          _i8.SyncStatus? status) =>
      (super.noSuchMethod(
        Invocation.method(
          #getJobsByStatus,
          [status],
        ),
        returnValue: _i6.Future<_i3.Either<_i9.Failure, List<_i2.Job>>>.value(
            _FakeEither_2<_i9.Failure, List<_i2.Job>>(
          this,
          Invocation.method(
            #getJobsByStatus,
            [status],
          ),
        )),
      ) as _i6.Future<_i3.Either<_i9.Failure, List<_i2.Job>>>);

  @override
  _i6.Stream<_i3.Either<_i9.Failure, List<_i2.Job>>> watchJobs() =>
      (super.noSuchMethod(
        Invocation.method(
          #watchJobs,
          [],
        ),
        returnValue: _i6.Stream<_i3.Either<_i9.Failure, List<_i2.Job>>>.empty(),
      ) as _i6.Stream<_i3.Either<_i9.Failure, List<_i2.Job>>>);

  @override
  _i6.Stream<_i3.Either<_i9.Failure, _i2.Job?>> watchJobById(String? localId) =>
      (super.noSuchMethod(
        Invocation.method(
          #watchJobById,
          [localId],
        ),
        returnValue: _i6.Stream<_i3.Either<_i9.Failure, _i2.Job?>>.empty(),
      ) as _i6.Stream<_i3.Either<_i9.Failure, _i2.Job?>>);
}

/// A class which mocks [JobWriterService].
///
/// See the documentation for Mockito's code generation for more information.
class MockJobWriterService extends _i1.Mock implements _i13.JobWriterService {
  MockJobWriterService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<_i3.Either<_i9.Failure, _i2.Job>> createJob({
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
        returnValue: _i6.Future<_i3.Either<_i9.Failure, _i2.Job>>.value(
            _FakeEither_2<_i9.Failure, _i2.Job>(
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
      ) as _i6.Future<_i3.Either<_i9.Failure, _i2.Job>>);

  @override
  _i6.Future<_i3.Either<_i9.Failure, _i2.Job>> updateJob({
    required String? localId,
    required _i14.JobUpdateData? updates,
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
        returnValue: _i6.Future<_i3.Either<_i9.Failure, _i2.Job>>.value(
            _FakeEither_2<_i9.Failure, _i2.Job>(
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
      ) as _i6.Future<_i3.Either<_i9.Failure, _i2.Job>>);

  @override
  _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>> updateJobSyncStatus({
    required String? localId,
    required _i8.SyncStatus? status,
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
        returnValue: _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>>.value(
            _FakeEither_2<_i9.Failure, _i3.Unit>(
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
      ) as _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>>);

  @override
  _i6.Future<_i3.Either<_i9.Failure, _i2.Job>> resetDeletionFailureCounter(
          String? localId) =>
      (super.noSuchMethod(
        Invocation.method(
          #resetDeletionFailureCounter,
          [localId],
        ),
        returnValue: _i6.Future<_i3.Either<_i9.Failure, _i2.Job>>.value(
            _FakeEither_2<_i9.Failure, _i2.Job>(
          this,
          Invocation.method(
            #resetDeletionFailureCounter,
            [localId],
          ),
        )),
      ) as _i6.Future<_i3.Either<_i9.Failure, _i2.Job>>);
}

/// A class which mocks [JobDeleterService].
///
/// See the documentation for Mockito's code generation for more information.
class MockJobDeleterService extends _i1.Mock implements _i15.JobDeleterService {
  MockJobDeleterService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>> deleteJob(String? localId) =>
      (super.noSuchMethod(
        Invocation.method(
          #deleteJob,
          [localId],
        ),
        returnValue: _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>>.value(
            _FakeEither_2<_i9.Failure, _i3.Unit>(
          this,
          Invocation.method(
            #deleteJob,
            [localId],
          ),
        )),
      ) as _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>>);

  @override
  _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>> permanentlyDeleteJob(
          String? localId) =>
      (super.noSuchMethod(
        Invocation.method(
          #permanentlyDeleteJob,
          [localId],
        ),
        returnValue: _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>>.value(
            _FakeEither_2<_i9.Failure, _i3.Unit>(
          this,
          Invocation.method(
            #permanentlyDeleteJob,
            [localId],
          ),
        )),
      ) as _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>>);

  @override
  _i6.Future<_i3.Either<_i9.Failure, bool>> attemptSmartDelete(
          String? localId) =>
      (super.noSuchMethod(
        Invocation.method(
          #attemptSmartDelete,
          [localId],
        ),
        returnValue: _i6.Future<_i3.Either<_i9.Failure, bool>>.value(
            _FakeEither_2<_i9.Failure, bool>(
          this,
          Invocation.method(
            #attemptSmartDelete,
            [localId],
          ),
        )),
      ) as _i6.Future<_i3.Either<_i9.Failure, bool>>);
}

/// A class which mocks [JobSyncOrchestratorService].
///
/// See the documentation for Mockito's code generation for more information.
class MockJobSyncOrchestratorService extends _i1.Mock
    implements _i16.JobSyncOrchestratorService {
  MockJobSyncOrchestratorService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  bool get isLogoutInProgress => (super.noSuchMethod(
        Invocation.getter(#isLogoutInProgress),
        returnValue: false,
      ) as bool);

  @override
  _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>> syncPendingJobs() =>
      (super.noSuchMethod(
        Invocation.method(
          #syncPendingJobs,
          [],
        ),
        returnValue: _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>>.value(
            _FakeEither_2<_i9.Failure, _i3.Unit>(
          this,
          Invocation.method(
            #syncPendingJobs,
            [],
          ),
        )),
      ) as _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>>);

  @override
  _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>> resetFailedJob(
          {required String? localId}) =>
      (super.noSuchMethod(
        Invocation.method(
          #resetFailedJob,
          [],
          {#localId: localId},
        ),
        returnValue: _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>>.value(
            _FakeEither_2<_i9.Failure, _i3.Unit>(
          this,
          Invocation.method(
            #resetFailedJob,
            [],
            {#localId: localId},
          ),
        )),
      ) as _i6.Future<_i3.Either<_i9.Failure, _i3.Unit>>);

  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [AuthService].
///
/// See the documentation for Mockito's code generation for more information.
class MockAuthService extends _i1.Mock implements _i17.AuthService {
  MockAuthService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.Future<_i4.User> login(
    String? email,
    String? password,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #login,
          [
            email,
            password,
          ],
        ),
        returnValue: _i6.Future<_i4.User>.value(_FakeUser_3(
          this,
          Invocation.method(
            #login,
            [
              email,
              password,
            ],
          ),
        )),
      ) as _i6.Future<_i4.User>);

  @override
  _i6.Future<bool> refreshSession() => (super.noSuchMethod(
        Invocation.method(
          #refreshSession,
          [],
        ),
        returnValue: _i6.Future<bool>.value(false),
      ) as _i6.Future<bool>);

  @override
  _i6.Future<void> logout() => (super.noSuchMethod(
        Invocation.method(
          #logout,
          [],
        ),
        returnValue: _i6.Future<void>.value(),
        returnValueForMissingStub: _i6.Future<void>.value(),
      ) as _i6.Future<void>);

  @override
  _i6.Future<bool> isAuthenticated({bool? validateTokenLocally = false}) =>
      (super.noSuchMethod(
        Invocation.method(
          #isAuthenticated,
          [],
          {#validateTokenLocally: validateTokenLocally},
        ),
        returnValue: _i6.Future<bool>.value(false),
      ) as _i6.Future<bool>);

  @override
  _i6.Future<String> getCurrentUserId() => (super.noSuchMethod(
        Invocation.method(
          #getCurrentUserId,
          [],
        ),
        returnValue: _i6.Future<String>.value(_i11.dummyValue<String>(
          this,
          Invocation.method(
            #getCurrentUserId,
            [],
          ),
        )),
      ) as _i6.Future<String>);

  @override
  _i6.Future<_i4.User> getUserProfile({bool? acceptOfflineProfile = true}) =>
      (super.noSuchMethod(
        Invocation.method(
          #getUserProfile,
          [],
          {#acceptOfflineProfile: acceptOfflineProfile},
        ),
        returnValue: _i6.Future<_i4.User>.value(_FakeUser_3(
          this,
          Invocation.method(
            #getUserProfile,
            [],
            {#acceptOfflineProfile: acceptOfflineProfile},
          ),
        )),
      ) as _i6.Future<_i4.User>);
}
