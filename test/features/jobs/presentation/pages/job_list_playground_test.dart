import 'dart:async';

import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_state.dart';
import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/presentation/pages/job_list_playground.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([JobListCubit])
import 'job_list_playground_test.mocks.dart';

// Create a stub AuthNotifier that extends the real AuthNotifier
class _StubAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.initial();

  // Avoid hitting real services
  @override
  Future<void> checkAuthStatus() async {}
}

void main() {
  group('JobListPlayground', () {
    late MockJobListCubit mockJobListCubit;
    late StreamController<JobListState> streamController;

    final testJobs = [
      JobViewModel.forTest(
        localId: 'job_123',
        title: 'Test Job 1',
        text: 'Job description 1',
        displayDate: DateTime.now(),
        syncStatus: SyncStatus.synced,
        jobStatus: JobStatus.created,
      ),
      JobViewModel.forTest(
        localId: 'job_456',
        title: 'Test Job 2',
        text: 'Job description 2',
        displayDate: DateTime.now().subtract(const Duration(hours: 1)),
        syncStatus: SyncStatus.synced,
        jobStatus: JobStatus.created,
      ),
    ];

    setUp(() {
      streamController = StreamController<JobListState>.broadcast();
      mockJobListCubit = MockJobListCubit();

      // Stub smartDeleteJob to return successfully
      when(mockJobListCubit.smartDeleteJob(any)).thenAnswer((_) async {});

      // Set up the cubit state
      final jobListLoaded = JobListLoaded(testJobs);
      when(mockJobListCubit.state).thenReturn(jobListLoaded);

      // Set up the stream
      when(mockJobListCubit.stream).thenAnswer((_) => streamController.stream);

      // Add the initial state to the stream
      streamController.add(jobListLoaded);
    });

    tearDown(() {
      streamController.close();
    });

    testWidgets('swipe to delete calls smartDeleteJob on cubit', (
      WidgetTester tester,
    ) async {
      // Arrange - Build widget tree with mocked cubit
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(() => _StubAuthNotifier()),
          ],
          child: MaterialApp(
            theme: createLightTheme(),
            home: BlocProvider<JobListCubit>.value(
              value: mockJobListCubit,
              child: const JobListPlayground(),
            ),
          ),
        ),
      );

      // Wait for widget to build
      await tester.pumpAndSettle();

      // Verify the job list is displayed
      expect(find.text('Test Job 1'), findsOneWidget);

      // Act - Perform the swipe gesture from right to left
      await tester.drag(find.text('Test Job 1'), const Offset(-500, 0));

      // Allow the Dismissible animation to complete
      await tester.pumpAndSettle();

      // Assert - Verify that the smartDeleteJob method was called with the correct ID
      verify(mockJobListCubit.smartDeleteJob('job_123')).called(1);
    });
  });
}
