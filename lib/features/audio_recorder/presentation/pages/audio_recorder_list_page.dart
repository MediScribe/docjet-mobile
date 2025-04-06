import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// import '../../../../core/di/injection_container.dart'; // REMOVED Unused import
import '../cubit/audio_recorder_cubit.dart';
import '../cubit/audio_recorder_state.dart';
import '../widgets/audio_player_widget.dart';
import 'audio_recorder_page.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';

// Convert to StatefulWidget (REMOVED local state management)
class AudioRecorderListPage extends StatelessWidget {
  // Changed to StatelessWidget
  const AudioRecorderListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // No longer need BlocProvider.value here, it's provided above.
    debugPrint(
      "[AudioRecorderListPage] build: Using Cubit provided from above.",
    );
    // Initial action moved to BlocProvider create in main.dart
    // context.read<AudioRecorderCubit>().checkPermission(); NO - done in main.dart
    return const AudioRecorderListView(); // Child remains the same
  }
}

class AudioRecorderListView extends StatefulWidget {
  const AudioRecorderListView({super.key});

  @override
  State<AudioRecorderListView> createState() => _AudioRecorderListViewState();
}

class _AudioRecorderListViewState extends State<AudioRecorderListView> {
  @override
  void initState() {
    super.initState();
    // REMOVED: Direct call to loadRecordings() from initState.
    /*
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint(
          "[AudioRecorderListView] initState: Triggering loadRecordings().",
        );
        context.read<AudioRecorderCubit>().loadRecordings();
      }
    });
    */
  }

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

  void _showRecordingOptions(BuildContext context, AudioRecord recording) {
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        // Use the cubit from the context, not a local field
        final cubit = context.read<AudioRecorderCubit>();
        return BlocProvider.value(
          value: cubit, // Pass the cubit found in the context
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Delete Recording'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext); // Close bottom sheet
                    // Use context.read here
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
          }
          // RESTORED: Trigger loadRecordings from listener when Ready
          else if (state is AudioRecorderReady) {
            debugPrint(
              "[AudioRecorderListView] Listener received Ready state. Triggering loadRecordings.",
            );
            context
                .read<AudioRecorderCubit>()
                .loadRecordings(); // Use context.read
          }
        },
        builder: (context, state) {
          debugPrint(
            "[AudioRecorderListView] Builder received state: ${state.runtimeType}",
          );
          // ADDED: Print before the cascade
          debugPrint("[AudioRecorderListView] Builder: Checking state type...");
          if (state is AudioRecorderLoading) {
            debugPrint(
              "[AudioRecorderListView] Builder: State IS AudioRecorderLoading.",
            );
            return const Center(child: CircularProgressIndicator());
          } else if (state is AudioRecorderPermissionDenied) {
            debugPrint(
              "[AudioRecorderListView] Builder: State IS AudioRecorderPermissionDenied.",
            );
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Microphone permission denied.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Request permission again or guide user to settings
                      // Example: Open app settings
                      context.read<AudioRecorderCubit>().openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                  ElevatedButton(
                    // Add button to retry permission check/request
                    onPressed:
                        // Use context.read here
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
            debugPrint(
              "[AudioRecorderListView] Builder: State IS AudioRecorderError.",
            );
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.message}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    // Add retry button for errors
                    onPressed:
                        // Use context.read here
                        () =>
                            context.read<AudioRecorderCubit>().loadRecordings(),
                    child: const Text('Retry Loading'),
                  ),
                ],
              ),
            );
          } else if (state is AudioRecorderLoaded) {
            debugPrint(
              "[AudioRecorderListView] Builder: State IS AudioRecorderLoaded.",
            );
            if (state.recordings.isEmpty) {
              debugPrint(
                "[AudioRecorderListView] Builder: ListLoaded is empty. Returning 'No recordings' text.",
              );
              return const Center(
                child: Text('No recordings yet. Tap + to start recording.'),
              );
            }
            debugPrint(
              "[AudioRecorderListView] Builder: ListLoaded has ${state.recordings.length} items. Returning ListView.",
            );
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
          // ADDED: Handler for AudioRecorderReady state in BUILDER
          else if (state is AudioRecorderReady) {
            debugPrint(
              "[AudioRecorderListView] Builder: State IS AudioRecorderReady. Showing loading indicator while load is triggered by initState.",
            );
            return const Center(
              child: CircularProgressIndicator(),
            ); // Show loading while list loads
          }

          // Fallback for Initial state or any other unexpected state
          // ADDED: Print inside fallback
          debugPrint(
            "[AudioRecorderListView] Builder: State (${state.runtimeType}) did NOT match any specific handler. Returning FALLBACK 'Initializing...'.",
          );
          return const Center(child: Text('Initializing...'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'list_fab',
        onPressed: () => _showAudioRecorderPage(context),
        tooltip: 'New Recording',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Updated function to use Navigator.push
  void _showAudioRecorderPage(BuildContext context) {
    // Get the cubit instance from context BEFORE the async gap
    final cubit = context.read<AudioRecorderCubit>();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => BlocProvider.value(
              value: cubit,
              child: const AudioRecorderPage(),
            ),
      ),
    ).then((result) {
      // Refresh list if recording was successful (result == true)
      if (result == true) {
        cubit.loadRecordings(); // Use the cubit instance obtained earlier
      }
    });
  }
}
