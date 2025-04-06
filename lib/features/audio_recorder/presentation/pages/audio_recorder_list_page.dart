import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Import the DI container for sl
import 'package:docjet_mobile/core/di/injection_container.dart';
// Import the specific Cubits and States needed
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_state.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_cubit.dart';

// ADD THIS IMPORT
import 'package:docjet_mobile/core/utils/logger.dart';

// Remove old imports
// import '../cubit/audio_recorder_cubit.dart';
// import '../cubit/audio_recorder_state.dart';
import '../widgets/audio_player_widget.dart';
import 'audio_recorder_page.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';

// This outer widget can remain StatelessWidget, it just provides the context
class AudioRecorderListPage extends StatelessWidget {
  const AudioRecorderListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The BlocProvider<AudioListCubit> is now handled in main.dart
    logger.d(
      "[AudioRecorderListPage] build: Using AudioListCubit provided from above.",
    );
    return const AudioRecorderListView(); // Child remains the same
  }
}

// The main view is StatefulWidget to potentially handle local UI state if needed,
// but core logic is driven by the BlocConsumer below.
class AudioRecorderListView extends StatefulWidget {
  const AudioRecorderListView({super.key});

  @override
  State<AudioRecorderListView> createState() => _AudioRecorderListViewState();
}

class _AudioRecorderListViewState extends State<AudioRecorderListView> {
  // initState is no longer needed as loadRecordings is called in main.dart's provider

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
    // Get the AudioListCubit instance from the context
    final listCubit = context.read<AudioListCubit>();
    logger.d(
      "[ListView] _showRecordingOptions called for ${recording.filePath}",
    );
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete Recording'),
                onTap: () {
                  logger.d(
                    "[BottomSheet] Delete tapped for ${recording.filePath}",
                  );
                  Navigator.pop(bottomSheetContext); // Close bottom sheet
                  logger.d(
                    "[BottomSheet] Calling listCubit.deleteRecording(${recording.filePath})",
                  );
                  listCubit.deleteRecording(recording.filePath);
                  logger.d(
                    "[BottomSheet] listCubit.deleteRecording(${recording.filePath}) call finished.",
                  );
                },
              ),
              // Add other options like Rename, Share later if needed
            ],
          ),
        );
      },
    ).whenComplete(() {
      logger.d("[ListView] Bottom sheet closed for ${recording.filePath}");
    });
  }

  // Navigation logic updated
  Future<void> _showAudioRecorderPage(BuildContext context) async {
    logger.i("[AudioRecorderListView] _showAudioRecorderPage called.");
    // <<--- Get the Cubit instance BEFORE the await --- >>
    final listCubit = context.read<AudioListCubit>();

    // Use Navigator.push and await the result
    final bool? shouldRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => BlocProvider<AudioRecordingCubit>.value(
              // Create a NEW, SCOPED instance of AudioRecordingCubit for this page
              value: sl<AudioRecordingCubit>()..prepareRecorder(),
              child: const AudioRecorderPage(),
            ),
      ),
    );

    logger.d(
      "[AudioRecorderListView] Returned from AudioRecorderPage. shouldRefresh: $shouldRefresh",
    );

    // If the recorder page popped with 'true', refresh the list
    // Use the cubit instance captured before the await, AFTER checking mounted
    if (shouldRefresh == true && mounted) {
      logger.i("[AudioRecorderListView] Refreshing recordings list.");
      listCubit.loadRecordings(); // Use the captured instance
    }
  }

  @override
  Widget build(BuildContext context) {
    logger.d("[AudioRecorderListView] build() called.");

    return Scaffold(
      appBar: AppBar(title: const Text('Recordings')),
      // Use the correct Cubit and State types
      body: BlocConsumer<AudioListCubit, AudioListState>(
        listener: (context, state) {
          logger.d(
            "[AudioRecorderListView] Listener received state: ${state.runtimeType}",
          );
          // Only handle errors relevant to the list loading process
          if (state is AudioListError) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar() // Hide previous snackbar if any
              ..showSnackBar(
                SnackBar(content: Text("List Error: ${state.message}")),
              );
          }
          // Removed listener logic for PermissionDenied and Ready states
          // as they belong to the recording cubit, not the list cubit.
        },
        builder: (context, state) {
          logger.d(
            "[AudioRecorderListView] Builder received state: ${state.runtimeType}",
          );

          // Handle Loading state
          if (state is AudioListLoading) {
            logger.d(
              "[AudioRecorderListView] Builder: State IS AudioListLoading.",
            );
            return const Center(child: CircularProgressIndicator());
          }
          // Removed PermissionDenied state handling - this page doesn't manage that
          /*
          else if (state is AudioRecorderPermissionDenied) { ... }
          */
          // Handle Error state
          else if (state is AudioListError) {
            logger.d(
              "[AudioRecorderListView] Builder: State IS AudioListError.",
            );
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading recordings: ${state.message}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    // Use the correct cubit to retry loading
                    onPressed:
                        () => context.read<AudioListCubit>().loadRecordings(),
                    child: const Text('Retry Loading'),
                  ),
                ],
              ),
            );
          }
          // Handle Loaded state
          else if (state is AudioListLoaded) {
            logger.d(
              "[AudioRecorderListView] Builder: State IS AudioListLoaded.",
            );
            if (state.recordings.isEmpty) {
              logger.i("[AudioRecorderListView] Builder: ListLoaded is empty.");
              return const Center(
                child: Text('No recordings yet. Tap + to start recording.'),
              );
            }
            logger.d(
              "[AudioRecorderListView] Builder: ListLoaded has ${state.recordings.length} items.",
            );
            // Sort recordings by creation date, newest first
            final sortedRecordings = List<AudioRecord>.from(state.recordings)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return ListView.builder(
              // Use sorted list
              itemCount: sortedRecordings.length,
              itemBuilder: (context, index) {
                // Use sorted list
                final recording = sortedRecordings[index];
                // Calculate end time based on duration (assuming domain entity has duration)
                final startTime = recording.createdAt;
                final endTime = startTime.add(
                  recording.duration,
                ); // Requires duration in AudioRecord

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        // Display index + 1 for user-friendly numbering
                        title: Text(
                          'Recording ${index + 1}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Path: ${recording.filePath.split('/').last}', // Show only filename
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Start: ${_formatDateTime(startTime)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'End: ${_formatDateTime(endTime)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ), // Requires endTime calculation
                            Text(
                              'Duration: ${_formatDuration(recording.duration)}', // Requires duration
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            logger.d(
                              "[ListView] More icon tapped for ${recording.filePath}",
                            );
                            _showRecordingOptions(context, recording);
                          },
                        ),
                        // Optional: Add onTap for the whole tile if needed
                        // onTap: () { /* Playback or details? */ },
                      ),
                      // Integrate the AudioPlayerWidget for playback controls
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          bottom: 8.0,
                        ),
                        // Ensure AudioPlayerWidget exists and takes filePath
                        child: AudioPlayerWidget(
                          filePath: recording.filePath,
                          // Add the required onDelete callback
                          onDelete: () {
                            // Use the cubit from context to delete
                            context.read<AudioListCubit>().deleteRecording(
                              recording.filePath,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }
          // Handle Initial state or other unexpected states
          else {
            logger.d(
              "[AudioRecorderListView] Builder: State is unexpected (${state.runtimeType}). Showing initial/empty view.",
            );
            // Show a default view, maybe loading or empty text
            // Could also be an error state if this shouldn't happen
            return const Center(child: Text('Initializing...'));
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        // Update onPressed to call the new navigation method
        onPressed: () {
          logger.i("[ListView] FAB tapped, showing recorder page.");
          _showAudioRecorderPage(context);
        },
        tooltip: 'Start New Recording',
        child: const Icon(Icons.add),
      ),
    );
  }
}
