import 'package:docjet_mobile/core/theme/app_theme.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A stripped-down version of JobListPage for testing that just injects offline state
/// This avoids needing to mock the AuthNotifier with all its dependencies
class TestJobListPage extends StatelessWidget {
  final JobListCubit jobListCubit;
  final bool isOffline;

  const TestJobListPage({
    super.key,
    required this.jobListCubit,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: createLightTheme(),
      home: BlocProvider<JobListCubit>.value(
        value: jobListCubit,
        child: _TestJobListPageImpl(isOffline: isOffline),
      ),
    );
  }
}

/// Implementation of JobListPage that uses injected offline state
/// instead of reading from authNotifierProvider
class _TestJobListPageImpl extends StatelessWidget {
  final bool isOffline;

  const _TestJobListPageImpl({required this.isOffline});

  @override
  Widget build(BuildContext context) {
    return _TestJobListPageContent(isOffline: isOffline);
  }
}

/// A minimal version of JobListPage that gets all the same content
/// but with fixed isOffline state
class _TestJobListPageContent extends StatelessWidget {
  final bool isOffline;

  const _TestJobListPageContent({required this.isOffline});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job List')),
      body: BlocBuilder<JobListCubit, JobListState>(
        builder: (context, state) {
          if (state is JobListLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is JobListLoaded) {
            if (state.jobs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No jobs yet.'),
                    if (!isOffline) // Only show Create Job button when online
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: ElevatedButton(
                          child: const Text('Create Job'),
                          onPressed: () {
                            // No-op for test
                          },
                        ),
                      ),
                    if (isOffline)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Job creation disabled while offline',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            } else {
              return ListView.builder(
                itemCount: state.jobs.length,
                itemBuilder: (context, index) {
                  final job = state.jobs[index];
                  return ListTile(
                    title: Text(job.title),
                    subtitle: Text(job.text),
                    onTap:
                        isOffline
                            ? null
                            : () {
                              // No-op for test
                            },
                  );
                },
              );
            }
          } else if (state is JobListError) {
            return Center(child: Text(state.message));
          }
          return const Center(child: Text('Initializing...'));
        },
      ),
    );
  }
}

/// Creates a test widget with offline capabilities without needing auth provider
Widget createTestWidget({
  required JobListCubit mockJobListCubit,
  bool isOffline = false,
}) {
  return TestJobListPage(jobListCubit: mockJobListCubit, isOffline: isOffline);
}
