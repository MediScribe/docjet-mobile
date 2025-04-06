import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../cubit/audio_recorder_cubit.dart';
import '../cubit/audio_recorder_state.dart';
import '../widgets/audio_player_widget.dart';
import 'audio_recorder_page.dart';

// Convert to StatefulWidget
class AudioRecorderListPage extends StatefulWidget {
  const AudioRecorderListPage({super.key});

  @override
  State<AudioRecorderListPage> createState() => _AudioRecorderListPageState();
}

class _AudioRecorderListPageState extends State<AudioRecorderListPage> {
  late final AudioRecorderCubit _audioRecorderCubit;

  @override
  void initState() {
    super.initState();
    debugPrint("[_AudioRecorderListPageState] initState: Creating Cubit.");
    _audioRecorderCubit = sl<AudioRecorderCubit>();
    debugPrint(
      "[_AudioRecorderListPageState] initState: Calling checkPermission.",
    );
    _audioRecorderCubit.checkPermission();
  }

  @override
  void dispose() {
    debugPrint("[_AudioRecorderListPageState] dispose: Closing Cubit.");
    _audioRecorderCubit.close(); // Close the cubit when the state is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use BlocProvider.value to provide the existing cubit instance
    debugPrint(
      "[_AudioRecorderListPageState] build: Providing existing Cubit.",
    );
    return BlocProvider.value(
      value: _audioRecorderCubit,
      child: const AudioRecorderListView(), // Child remains the same
    );
  }
}

class AudioRecorderListView extends StatefulWidget {
  const AudioRecorderListView({super.key});

  @override
  State<AudioRecorderListView> createState() => _AudioRecorderListViewState();
}

class _AudioRecorderListViewState extends State<AudioRecorderListView> {
  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} $hour:$minute:$second';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showRecordingOptions(BuildContext context, AudioRecordState recording) {
    final cubit = context.read<AudioRecorderCubit>();

    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        return BlocProvider.value(
          value: cubit,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ListTile(
                //   leading: const Icon(Icons.add),
                //   title: const Text('Append Recording'),
                //   onTap: () async {
                //     Navigator.pop(bottomSheetContext); // Close bottom sheet
                //     final result = await Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder:
                //             (context) => BlocProvider.value(
                //               value: cubit,
                //               child: AudioRecorderPage(appendTo: recording),
                //             ),
                //       ),
                //     );
                //     if (result == true && context.mounted) {
                //       cubit.loadRecordings();
                //       if (context.mounted) {
                //         setState(() {}); // Force rebuild
                //       }
                //     }
                //   },
                // ),
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Delete Recording'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext); // Close bottom sheet
                    cubit.deleteRecording(recording.filePath);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[AudioRecorderListView] build() called.");

    return Scaffold(
      appBar: AppBar(title: const Text('Recordings')),
      body: BlocConsumer<AudioRecorderCubit, AudioRecorderState>(
        listener: (context, state) {
          debugPrint(
            "[AudioRecorderListView] Listener received state: ${state.runtimeType}",
          );
          if (state is AudioRecorderError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is AudioRecorderPermissionDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Microphone permission is required to record audio',
                ),
              ),
            );
          } else if (state is AudioRecorderReady) {
            // ADDED: Trigger load when permission is confirmed ready
            debugPrint(
              "[AudioRecorderListView] Listener received Ready state. Triggering loadRecordings.",
            );
            context.read<AudioRecorderCubit>().loadRecordings();
          }
        },
        builder: (context, state) {
          debugPrint(
            "[AudioRecorderListView] Builder received state: ${state.runtimeType}",
          );
          if (state is AudioRecorderLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is AudioRecorderPermissionDenied) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Microphone permission denied.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed:
                        () => context.read<AudioRecorderCubit>().openSettings(),
                    child: const Text('Open Settings'),
                  ),
                  ElevatedButton(
                    // Add button to retry permission check/request
                    onPressed:
                        () =>
                            context
                                .read<AudioRecorderCubit>()
                                .requestPermission(),
                    child: const Text('Retry Permission'),
                  ),
                ],
              ),
            );
          } else if (state is AudioRecorderError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.message}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    // Add retry button for errors
                    onPressed:
                        () =>
                            context.read<AudioRecorderCubit>().loadRecordings(),
                    child: const Text('Retry Loading'),
                  ),
                ],
              ),
            );
          } else if (state is AudioRecorderListLoaded) {
            if (state.recordings.isEmpty) {
              return const Center(
                child: Text('No recordings yet. Tap + to start recording.'),
              );
            }
            return ListView.builder(
              itemCount: state.recordings.length,
              itemBuilder: (context, index) {
                final recording = state.recordings[index];
                final startTime = recording.createdAt;
                final endTime = startTime.add(recording.duration);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text(
                          'Recording ${index + 1}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Start: ${_formatDateTime(startTime)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'End: ${_formatDateTime(endTime)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'Duration: ${_formatDuration(recording.duration)}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed:
                              () => _showRecordingOptions(context, recording),
                        ),
                      ),
                      AudioPlayerWidget(
                        filePath: recording.filePath,
                        onDelete: () {
                          context.read<AudioRecorderCubit>().deleteRecording(
                            recording.filePath,
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }

          // Fallback for Initial state or any other unexpected state (like Ready briefly)
          return const Center(child: Text('Initializing...'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'list_fab',
        onPressed: () {
          final cubit = context.read<AudioRecorderCubit>();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            enableDrag: true,
            isDismissible: true,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            builder: (sheetContext) {
              return const AudioRecorderPage();
            },
          ).then((result) {
            if (result == true && context.mounted) {
              cubit.loadRecordings();
            }
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
