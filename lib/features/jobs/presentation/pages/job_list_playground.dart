import 'dart:io'; // For Directory type

import 'package:docjet_mobile/core/audio/audio_cubit.dart';
import 'package:docjet_mobile/core/audio/audio_player_service_impl.dart';
import 'package:docjet_mobile/core/audio/audio_recorder_service_impl.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:docjet_mobile/core/widgets/record_button.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/job_status.dart';
import 'package:docjet_mobile/features/jobs/domain/entities/sync_status.dart';
import 'package:docjet_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:docjet_mobile/features/jobs/domain/usecases/create_job_use_case.dart';
import 'package:docjet_mobile/features/jobs/presentation/cubit/job_list_cubit.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';
import 'package:docjet_mobile/features/jobs/presentation/states/job_list_state.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/job_list_item.dart';
import 'package:docjet_mobile/features/jobs/presentation/widgets/recorder_modal.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as path_pkg; // For relative path calculation
import 'package:path_provider/path_provider.dart'
    as path_provider_pkg; // For app docs path

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

  // For managing AudioCubit lifecycle within the modal presentation
  AudioCubit? _audioCubitForModal;

  // Restore original single mock job
  final List<JobViewModel> _mockJobs = [
    JobViewModel(
      localId: 'job_123456789',
      title: 'This is a mock job (not from data source)',
      text: 'This is displayed when no real jobs exist yet',
      syncStatus: SyncStatus.synced,
      jobStatus: JobStatus.submitted,
      hasFileIssue: false,
      displayDate: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  Future<void> _createJobFromAudioFile(String absoluteAudioPath) async {
    if (widget.isOffline) {
      _logger.i('$_tag Job creation skipped because offline (from audio file)');
      return;
    }

    _logger.i(
      '$_tag Starting job creation from audio file: $absoluteAudioPath',
    );

    try {
      final Directory appDocDir =
          await path_provider_pkg.getApplicationDocumentsDirectory();

      // Ensure the file ends up inside <docs>/audio/<filename>
      final String persistentDir = path_pkg.join(appDocDir.path, 'audio');
      await Directory(persistentDir).create(recursive: true);

      String finalAbsPath = absoluteAudioPath;

      if (!path_pkg.isWithin(appDocDir.path, absoluteAudioPath)) {
        // Move the file for persistence. Prefer rename; fall back to copy+delete.
        final String filename = path_pkg.basename(absoluteAudioPath);
        final String targetPath = path_pkg.join(persistentDir, filename);

        try {
          finalAbsPath =
              (await File(absoluteAudioPath).rename(targetPath)).path;
        } on FileSystemException {
          _logger.w('$_tag rename failed, falling back to copy+delete.');
          await File(absoluteAudioPath).copy(targetPath);
          await File(absoluteAudioPath).delete();
          finalAbsPath = targetPath;
        }

        _logger.i('$_tag Moved recording to persistent path: $finalAbsPath');
      }

      // Compute path relative to docs dir; guard against edge-cases.
      String relativeAudioPath = path_pkg.relative(
        finalAbsPath,
        from: appDocDir.path,
      );
      if (relativeAudioPath == '.' || relativeAudioPath.isEmpty) {
        relativeAudioPath = path_pkg.basename(finalAbsPath);
      }

      _logger.i('$_tag Using relative audio path: $relativeAudioPath');

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final params = CreateJobParams(
        audioFilePath: relativeAudioPath,
        text: 'Audio Job: $timestamp - recorded audio.',
      );

      if (!mounted) return;

      context.read<JobListCubit>().createJob(params);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creating new job from recording... Check status!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('$_tag Error creating job from audio file: $e');
      _logger.e('$_tag Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating job from audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRecordButtonTap() async {
    _logger.i('$_tag Record button tapped, preparing to show modal.');
    if (widget.isOffline) {
      _logger.i('$_tag Record button action skipped because offline');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot record audio while offline.')),
      );
      return;
    }

    // Instantiate services and cubit for the modal
    // This is clunky for a widget but okay for a playground.
    // In a real app, these would be provided via GetIt or a higher-level BlocProvider.
    final recorderService =
        AudioRecorderServiceImpl(); // ASSUMPTION: Default constructor
    final playerService =
        AudioPlayerServiceImpl(); // Assumes default constructor is fine

    _audioCubitForModal = AudioCubit(
      recorderService: recorderService,
      playerService: playerService,
    );

    final String? recordedFilePath = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => BlocProvider<AudioCubit>.value(
            value: _audioCubitForModal!,
            child: const RecorderModal(),
          ),
    );

    // IMPORTANT: Dispose the cubit when the modal is done.
    // The cubit might still be used by the modal if it was dismissed by dragging,
    // so a slight delay or ensuring it's fully gone might be needed in complex scenarios.
    // For now, a simple close and nullify.
    await _audioCubitForModal?.close();
    _audioCubitForModal = null;
    _logger.d('$_tag AudioCubit for modal closed and nulled.');

    if (recordedFilePath != null && recordedFilePath.isNotEmpty) {
      _logger.i('$_tag Recorder modal returned file path: $recordedFilePath');
      // Now create a job with this file path
      await _createJobFromAudioFile(recordedFilePath);
    } else {
      _logger.i('$_tag Recorder modal was dismissed or returned no file path.');
    }
  }

  // Restore original _handleManualSync function (was _handleMockToggle)
  Future<void> _handleManualSync() async {
    _logger.i('$_tag Manual sync triggered!');
    if (widget.isOffline) {
      _logger.i('$_tag Manual sync skipped because offline');
      return;
    }
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
  void dispose() {
    // Ensure the modal's AudioCubit is closed if the playground itself is disposed
    // while the modal might somehow still be active or the cubit instance exists.
    _audioCubitForModal?.close();
    super.dispose();
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
              // Restore original onPressed and icon for the sync button
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
                  child: Material(
                    color: Colors.transparent,
                    child: RefreshIndicator.adaptive(
                      // Use adaptive for platform look
                      onRefresh:
                          () => context.read<JobListCubit>().refreshJobs(),
                      child: BlocBuilder<JobListCubit, JobListState>(
                        builder: (context, state) {
                          // Remove the _showMockJobsOverride check

                          // Original logic if not overriding
                          if (state is JobListLoading) {
                            return Container();
                          }

                          if (state is JobListLoaded) {
                            final jobs = state.jobs;

                            if (jobs.isEmpty) {
                              // Revert to original behavior when no real jobs are loaded
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20.0,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center, // Center content vertically
                                    children: <Widget>[
                                      Text(
                                        'No jobs available. Hit the Record Button to create your first Job.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.copyWith(
                                          color: CupertinoColors.secondaryLabel,
                                        ),
                                      ),
                                    ],
                                  ),
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
                                  onTapJob: (_) {
                                    _logger.i(
                                      '$_tag Tapped on job: ${jobs[index].localId}',
                                    );
                                  },
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
                                    onPressed:
                                        isOffline
                                            ? null
                                            : () =>
                                                context
                                                    .read<JobListCubit>()
                                                    .refreshJobs(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Fallback to mock data if cubit is in an unexpected state
                          // This should ideally not be hit if cubit handles all states.
                          _logger.w(
                            '$_tag JobListCubit in unexpected state: $state, showing mock jobs as fallback.',
                          );
                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 120.0),
                            itemCount:
                                _mockJobs
                                    .length, // This now refers to the single original mock
                            itemBuilder: (context, index) {
                              return JobListItem(
                                job: _mockJobs[index],
                                isOffline: isOffline,
                                onTapJob: (_) {},
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: RecordButton(
              onTap: isOffline ? null : _handleRecordButtonTap,
            ),
          ),
        ],
      ),
    );
  }
}
