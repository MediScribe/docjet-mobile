import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/job_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Renamed from TranscriptionsPage
class JobListPage extends StatelessWidget {
  const JobListPage({super.key});

  // Get logger instance for this class
  static final Logger _logger = LoggerFactory.getLogger(JobListPage);
  // Create standard log tag
  static final String _tag = logTag(JobListPage);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job List')),
      body: BlocBuilder<JobListCubit, JobListState>(
        builder: (context, state) {
          if (state is JobListLoading) {
            _logger.d('$_tag State is JobListLoading, showing indicator.');
            return const Center(child: CircularProgressIndicator());
          } else if (state is JobListLoaded) {
            _logger.d(
              '$_tag State is JobListLoaded with ${state.jobs.length} jobs.',
            );
            if (state.jobs.isEmpty) {
              _logger.d(
                '$_tag Jobs list is empty, showing "No jobs yet." message.',
              );
              return const Center(child: Text('No jobs yet.'));
            } else {
              // Use the real JobViewModel list
              _logger.d('$_tag Jobs list is not empty, rendering ListView.');
              final jobs = state.jobs;
              return ListView.builder(
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  // Get the job view model for the current item
                  final jobViewModel = jobs[index];
                  // Use the dedicated JobListItem widget
                  return JobListItem(job: jobViewModel);
                },
              );
            }
          } else if (state is JobListError) {
            // Handle Error state
            _logger.e(
              '$_tag State is JobListError: ${state.message}',
              error: 'UI Display', // Optional: add context
              stackTrace: StackTrace.current, // Optional: capture stack
            );
            return Center(child: Text(state.message));
          }
          // Fallback/Initial state handling (can be more specific if needed)
          _logger.d(
            '$_tag State is ${state.runtimeType}, showing placeholder.',
          );
          // Placeholder for initial or other unhandled states
          return const Center(child: Text('Initializing...'));
        },
      ),
    );
  }
}
