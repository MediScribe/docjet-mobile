import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/core/widgets/record_button.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/job_list_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A playground for experimenting with job list UI components (Cupertino Style)
/// This doesn't require tests as it's purely for UI experimentation.
/// It now demonstrates getting dependencies via BlocProvider/context instead of sl.
class JobListPlayground extends ConsumerWidget {
  const JobListPlayground({super.key});

  // Get logger instance for this class
  static final Logger _logger = LoggerFactory.getLogger(JobListPlayground);
  // Create standard log tag
  static final String _tag = logTag(JobListPlayground);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get offline status from auth state
    final authState = ref.watch(authNotifierProvider);
    final isOffline = authState.isOffline;

    if (kDebugMode) {
      _logger.d('$_tag Building UI playground');
    }

    // Access the existing JobListCubit from the parent context
    // instead of creating a new one on every rebuild
    final parentCubit = BlocProvider.of<JobListCubit>(context, listen: false);

    return BlocProvider.value(
      value: parentCubit,
      child: _JobListPlaygroundContent(isOffline: isOffline),
    );
  }
}

class _JobListPlaygroundContent extends StatefulWidget {
  final bool isOffline;

  const _JobListPlaygroundContent({required this.isOffline});

  @override
  State<_JobListPlaygroundContent> createState() =>
      _JobListPlaygroundContentState();
}

class _JobListPlaygroundContentState extends State<_JobListPlaygroundContent> {
  static final Logger _logger = LoggerFactory.getLogger('JobListPlayground');
  static final String _tag = logTag('JobListPlayground');

  // We'll keep a small set of mock jobs as fallback
  final List<JobViewModel> _mockJobs = [
    JobViewModel(
      localId: 'job_123456789',
      title: 'This is a mock job (not from data source)',
      text: 'This is displayed when no real jobs exist yet',
      syncStatus: SyncStatus.synced,
      hasFileIssue: false,
      displayDate: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  Future<void> _createLoremIpsumJob() async {
    if (widget.isOffline) {
      _logger.i('$_tag Job creation skipped because offline');
      return;
    }

    try {
      // Get FileSystem instance
      final fileSystem = GetIt.instance<FileSystem>();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Define a relative path for the temporary file
      final tempFilename = 'playground_temp_$timestamp.m4a';

      // Create an empty file
      await fileSystem.writeFile(tempFilename, Uint8List(0));
      _logger.i('$_tag Created empty temporary file: $tempFilename');

      // Use the created filename (relative path) in params
      final params = CreateJobParams(
        audioFilePath: tempFilename, // Pass the valid relative path
        text:
            'Job: $timestamp: Lorem ipsum dolor sit amet,\nconsectetur adipiscing elit.', // Formatted as requested
      );

      // Check if the widget is still mounted before using context
      if (!mounted) return;

      // Get Cubit from context and call its createJob method
      context.read<JobListCubit>().createJob(params);

      _logger.i(
        '$_tag Called Cubit to create new Lorem Ipsum job with temp file: $tempFilename',
      );
    } catch (e) {
      _logger.e('$_tag Error creating job: $e');
      // Optionally show an error message to the user
    }
  }

  // Helper to handle data refresh (no action needed, just logs)
  void _handleRefresh() {
    _logger.d(
      '$_tag Refresh button pressed (does nothing - Cubit watches stream)',
    );
  }

  // Helper to handle manual sync
  Future<void> _handleManualSync() async {
    _logger.i('$_tag Manual sync triggered!');
    try {
      // TODO: [ARCH] Direct repository access is BAD PRACTICE.
      // This is only acceptable here because it's a playground
      // for quick testing/debugging. In real features, use a
      // Cubit/Notifier and a Use Case.
      final repo = GetIt.instance<JobRepository>();
      final result = await repo.syncPendingJobs();
      result.fold(
        (failure) => _logger.e('$_tag Sync failed: $failure'),
        (_) => _logger.i('$_tag Sync successful!'),
      );
    } catch (e) {
      _logger.e('$_tag Error during manual sync: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('$_tag Building UI playground');

    // Get offline status from widget
    final isOffline = widget.isOffline;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Job List UI Playground'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              // Disable refresh when offline
              onPressed: isOffline ? null : _handleRefresh,
              child: const Icon(CupertinoIcons.refresh),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              // Disable sync when offline
              onPressed: isOffline ? null : _handleManualSync,
              child: const Icon(CupertinoIcons.cloud_upload),
            ),
          ],
        ),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: BlocBuilder<JobListCubit, JobListState>(
                    builder: (context, state) {
                      if (state is JobListLoading) {
                        return const Center(
                          child: CupertinoActivityIndicator(),
                        );
                      }

                      if (state is JobListLoaded) {
                        final jobs = state.jobs;

                        if (jobs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('No jobs available'),
                                const SizedBox(height: 16),
                                CupertinoButton(
                                  onPressed:
                                      isOffline ? null : _createLoremIpsumJob,
                                  child: const Text('Create First Job'),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 120.0),
                          itemCount: jobs.length,
                          itemBuilder: (context, index) {
                            return JobListItem(
                              job: jobs[index],
                              isOffline: isOffline,
                            );
                          },
                        );
                      }

                      if (state is JobListError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Error: ${state.message}'),
                              const SizedBox(height: 16),
                              CupertinoButton(
                                onPressed: isOffline ? null : _handleRefresh,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      // Fallback to mock data if we hit some edge case
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120.0),
                        itemCount: _mockJobs.length,
                        itemBuilder: (context, index) {
                          return JobListItem(
                            job: _mockJobs[index],
                            isOffline: isOffline,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: RecordButton(onTap: isOffline ? null : _createLoremIpsumJob),
          ),
        ],
      ),
    );
  }
}
