import 'package:dartz/dartz.dart';
import 'package:docjet_mobile/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JobRemoteDataSource Interface', () {
    // This test verifies the interface method signatures
    test('createJob method should not accept userId parameter', () {
      // This is not a real implementation test, but a compilation validation
      // We're verifying that the method signature is as expected

      // Create a type that implements JobRemoteDataSource for testing the interface
      // This won't be instantiated, just used to verify the interface
      const implementation = _TestImplementation();

      // If this compiles successfully, then the test passes
      // We're verifying that the createJob method can be implemented without
      // requiring a userId parameter
      expect(implementation, isA<JobRemoteDataSource>());
    });
  });
}

// Test implementation used to verify the interface
// This doesn't need to actually do anything, just implement the interface
class _TestImplementation implements JobRemoteDataSource {
  const _TestImplementation();

  @override
  Future<Job> createJob({
    required String audioFilePath,
    String? text,
    String? additionalText,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Unit> deleteJob(String serverId) async {
    throw UnimplementedError();
  }

  @override
  Future<Job> fetchJobById(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Job>> fetchJobs() async {
    throw UnimplementedError();
  }

  @override
  Future<List<Job>> syncJobs(List<Job> jobsToSync) async {
    throw UnimplementedError();
  }

  @override
  Future<Job> updateJob({
    required String jobId,
    required Map<String, dynamic> updates,
  }) async {
    throw UnimplementedError();
  }
}
