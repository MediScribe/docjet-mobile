import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/pages/job_list_playground.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/job_list_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Renamed from TranscriptionsPage
class JobListPage extends ConsumerWidget {
  const JobListPage({super.key});

  // Get logger instance for this class
  static final Logger _logger = LoggerFactory.getLogger(JobListPage);
  // Create standard log tag
  static final String _tag = logTag(JobListPage);

  // Function to navigate to the playground
  void _navigateToPlayground(BuildContext context) {
    _logger.d('$_tag Navigating to JobListPlayground...');
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (_) => const JobListPlayground()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get offline status from auth state
    final authState = ref.watch(authNotifierProvider);
    final isOffline = authState.isOffline;
    if (kDebugMode) {
      _logger.d('$_tag Using auth state, isOffline: $isOffline');
    }

    // Wrap the CupertinoNavigationBar with a GestureDetector for debug access
    final navBar = CupertinoNavigationBar(
      middle: const Text('Job List'),
      // Show playground button only in debug mode
      trailing:
          kDebugMode
              ? CupertinoButton(
                padding: EdgeInsets.zero,
                // Disable when offline
                onPressed:
                    isOffline ? null : () => _navigateToPlayground(context),
                child: const Icon(CupertinoIcons.lab_flask_solid),
              )
              : null, // No button in release builds
    );

    // Use BlocProvider.value to get the existing JobListCubit from the parent
    // This prevents recreating the cubit on every rebuild
    return CupertinoPageScaffold(
      navigationBar: navBar,
      child: BlocBuilder<JobListCubit, JobListState>(
        builder: (context, state) {
          if (state is JobListLoading) {
            if (kDebugMode) {
              _logger.d('$_tag Showing loading indicator');
            }
            return const Center(child: CupertinoActivityIndicator());
          } else if (state is JobListLoaded) {
            if (kDebugMode) {
              _logger.d(
                '$_tag JobListLoaded state: ${state.jobs.length} jobs loaded',
              );
            }
            if (state.jobs.isEmpty) {
              if (kDebugMode) {
                _logger.d(
                  '$_tag Jobs list is empty, showing "No jobs yet." message.',
                );
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No jobs yet.'),
                    if (!isOffline) // Only show Create Job button when online
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: CupertinoButton.filled(
                          child: const Text('Create Job'),
                          onPressed: () {
                            // TODO: Implement job creation
                            _logger.i('$_tag Create Job button pressed');
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
              if (kDebugMode) {
                _logger.d('$_tag Jobs list is not empty, rendering ListView.');
              }
              final jobs = state.jobs;
              return SafeArea(
                child: ListView.builder(
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final jobViewModel = jobs[index];
                    return JobListItem(
                      job: jobViewModel,
                      // Pass isOffline to disable actions if needed
                      isOffline: isOffline,
                    );
                  },
                ),
              );
            }
          } else if (state is JobListError) {
            _logger.e('$_tag JobListError state: ${state.message}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${state.message}'),
              ),
            );
          }

          // Initial state or unhandled state type
          if (kDebugMode) {
            _logger.d('$_tag Initial or unhandled state: ${state.runtimeType}');
          }
          return const Center(child: Text('Loading jobs...'));
        },
      ),
    );
  }
}
