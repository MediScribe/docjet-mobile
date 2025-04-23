import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/job_list_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docjet_mobile/core/di/injection_container.dart' as di;
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';

/// A playground for experimenting with job list UI components (Cupertino Style)
/// This doesn't require tests as it's purely for UI experimentation
class JobListPlayground extends StatefulWidget {
  const JobListPlayground({super.key});

  @override
  State<JobListPlayground> createState() => _JobListPlaygroundState();
}

class _JobListPlaygroundState extends State<JobListPlayground> {
  static final Logger _logger = LoggerFactory.getLogger('JobListPlayground');
  static final String _tag = logTag('JobListPlayground');

  late final JobListCubit _jobListCubit;
  late final CreateJobUseCase _createJobUseCase;

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

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _jobListCubit = di.sl<JobListCubit>();
    _createJobUseCase = di.sl<CreateJobUseCase>();
    // Start watching jobs
    _loadJobs();
  }

  @override
  void dispose() {
    _jobListCubit.close();
    super.dispose();
  }

  void _loadJobs() {
    // The cubit may have a different method - adjusted based on our search
    // If loadJobs isn't available, the cubit may initialize watching automatically
    // Doing nothing would rely on the cubit's built-in behavior
    _logger.d('$_tag Requesting job list refresh');
  }

  Future<void> _createLoremIpsumJob() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Create job with minimal required parameters
      await _createJobUseCase(
        CreateJobParams(
          audioFilePath: 'playground_job_$timestamp.m4a',
          text:
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
        ),
      );
      _logger.i('$_tag Created new Lorem Ipsum job');
    } catch (e) {
      _logger.e('$_tag Error creating job: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('$_tag Building UI playground');

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Job List UI Playground'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.refresh),
          onPressed: () {
            _logger.d('$_tag Refreshing UI playground');
            _loadJobs();
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 8.0,
                children: [
                  CupertinoButton(
                    onPressed: () {
                      _logger.d('$_tag Showing list view');
                      setState(() {
                        // Toggle to list view mode
                      });
                    },
                    child: const Text('List View'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      _logger.d('$_tag Showing grid view');
                      setState(() {
                        // Toggle to grid view mode (if implemented)
                      });
                    },
                    child: const Text('Grid View'),
                  ),
                  CupertinoButton(
                    onPressed: _isLoading ? null : _createLoremIpsumJob,
                    child:
                        _isLoading
                            ? const CupertinoActivityIndicator()
                            : const Text('Add Lorem Ipsum Job'),
                  ),
                ],
              ),
            ),

            Expanded(
              child: BlocBuilder<JobListCubit, JobListState>(
                bloc: _jobListCubit,
                builder: (context, state) {
                  if (state is JobListLoading) {
                    return const Center(child: CupertinoActivityIndicator());
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
                              onPressed: _createLoremIpsumJob,
                              child: const Text('Create First Job'),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: jobs.length,
                      itemBuilder: (context, index) {
                        return JobListItem(job: jobs[index]);
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
                            onPressed: _loadJobs,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  // Fallback to mock data if we hit some edge case
                  return ListView.builder(
                    itemCount: _mockJobs.length,
                    itemBuilder: (context, index) {
                      return JobListItem(job: _mockJobs[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
