import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/pages/job_list_playground.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/job_list_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Renamed from TranscriptionsPage
class JobListPage extends StatelessWidget {
  const JobListPage({super.key});

  // Get logger instance for this class
  static final Logger _logger = LoggerFactory.getLogger(JobListPage);
  // Create standard log tag
  static final String _tag = logTag(JobListPage);

  // Function to navigate to the playground
  void _navigateToPlayground(BuildContext context) {
    _logger.i('$_tag Navigating to JobListPlayground...');
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (_) => const JobListPlayground()));
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the CupertinoNavigationBar with a GestureDetector for debug access
    final navBar = CupertinoNavigationBar(
      middle: const Text('Job List'),
      // Add a trailing button ONLY in debug mode for easier access
      // Swipe gestures on nav bars can be finicky
      trailing:
          kDebugMode
              ? CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.lab_flask_solid),
                onPressed: () => _navigateToPlayground(context),
              )
              : null, // No button in release builds
    );

    return CupertinoPageScaffold(
      navigationBar: navBar, // Use the potentially wrapped navBar
      child: BlocBuilder<JobListCubit, JobListState>(
        builder: (context, state) {
          if (state is JobListLoading) {
            _logger.d('$_tag State is JobListLoading, showing indicator.');
            return const Center(child: CupertinoActivityIndicator());
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
              _logger.d('$_tag Jobs list is not empty, rendering ListView.');
              final jobs = state.jobs;
              return SafeArea(
                child: ListView.builder(
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final jobViewModel = jobs[index];
                    return JobListItem(job: jobViewModel);
                  },
                ),
              );
            }
          } else if (state is JobListError) {
            _logger.e(
              '$_tag State is JobListError: ${state.message}',
              error: 'UI Display',
              stackTrace: StackTrace.current,
            );
            return Center(child: Text(state.message));
          }
          _logger.d(
            '$_tag State is ${state.runtimeType}, showing placeholder.',
          );
          return const Center(child: Text('Initializing...'));
        },
      ),
    );
  }
}
