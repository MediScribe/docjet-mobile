import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Import the DI container for sl
// Import the specific Cubits and States needed
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_cubit.dart';
// import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_list_state.dart';

// ADD THIS IMPORT
import 'package:docjet_mobile/core/utils/logger.dart';

// Remove old imports
// import '../cubit/audio_recorder_cubit.dart';
// import '../cubit/audio_recorder_state.dart';
import '../widgets/audio_player_widget.dart';
import 'audio_recorder_page.dart';

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

  // Navigation logic updated
  Future<void> _showAudioRecorderPage(BuildContext context) async {
    logger.i("[AudioRecorderListView] _showAudioRecorderPage called.");
    // Get the List Cubit instance BEFORE the await for refresh logic
    final listCubit = context.read<AudioListCubit>();

    // Use Navigator.push and await the result
    final bool? shouldRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        // No need to read/provide the cubit here anymore.
        // AudioRecorderPage will access the globally provided instance.
        builder: (_) => const AudioRecorderPage(),
        /* // REMOVE this section
        builder: (_) {
          // Get the EXISTING cubit instance from the current context
          final audioRecordingCubit = context.read<AudioRecordingCubit>();
          // Provide THIS instance to the new page
          return BlocProvider<AudioRecordingCubit>.value(
            value: audioRecordingCubit, // Use the instance from context
            child: const AudioRecorderPage(),
          );
        },
        */
      ),
    );

    logger.d(
      "[AudioRecorderListView] Returned from AudioRecorderPage. shouldRefresh: $shouldRefresh",
    );

    // If the recorder page popped with 'true', refresh the list
    // Use the cubit instance captured before the await, AFTER checking mounted
    if (shouldRefresh == true && mounted) {
      logger.i("[AudioRecorderListView] Refreshing recordings list.");
      listCubit.loadAudioRecordings(); // Use the captured instance
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
                        () =>
                            context
                                .read<AudioListCubit>()
                                .loadAudioRecordings(),
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
            if (state.transcriptions.isEmpty) {
              logger.i("[AudioRecorderListView] Builder: ListLoaded is empty.");
              return const Center(
                child: Text('No recordings yet. Tap + to start recording.'),
              );
            }
            logger.d(
              "[AudioRecorderListView] Builder: ListLoaded has ${state.transcriptions.length} items.",
            );
            // state.recordings is already sorted by the Cubit
            final sortedTranscriptions = state.transcriptions;
            final playbackInfo = state.playbackInfo;

            return ListView.builder(
              // Use sorted list
              itemCount: sortedTranscriptions.length,
              itemBuilder: (context, index) {
                // Use Transcription type
                final transcription = sortedTranscriptions[index];
                // Use Transcription properties
                final startTime = transcription.localCreatedAt;
                final duration =
                    transcription.localDurationMillis != null
                        ? Duration(
                          milliseconds: transcription.localDurationMillis!,
                        )
                        : Duration.zero;
                final endTime = startTime?.add(duration);
                final title =
                    transcription.displayTitle ?? 'Recording ${index + 1}';

                final isActiveItem =
                    playbackInfo.activeFilePath == transcription.localFilePath;
                final itemIsPlaying = isActiveItem && playbackInfo.isPlaying;
                final itemIsLoading = isActiveItem && playbackInfo.isLoading;
                final itemPosition =
                    isActiveItem ? playbackInfo.currentPosition : Duration.zero;
                // Use playbackInfo.totalDuration ONLY if active, otherwise use file's duration
                // but ensure canSeek only uses playbackInfo.totalDuration
                final displayDuration =
                    isActiveItem && playbackInfo.totalDuration > Duration.zero
                        ? playbackInfo.totalDuration
                        : duration; // Duration shown on the widget
                final itemError = isActiveItem ? playbackInfo.error : null;
                // Slider should only be enabled if this IS the active item and duration is known
                final canSeek =
                    isActiveItem && playbackInfo.totalDuration > Duration.zero;

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
                          title, // Use transcription title
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Path: ${transcription.localFilePath.split('/').last}', // Use transcription path
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (startTime != null)
                              Text(
                                'Start: ${_formatDateTime(startTime)}', // Use transcription start time
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            if (endTime != null)
                              Text(
                                'End: ${_formatDateTime(endTime)}', // Use calculated end time
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            Text(
                              'Duration: ${_formatDuration(displayDuration)}', // Use displayDuration
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            // Optionally display status
                            Text(
                              'Status: ${transcription.status.name}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            logger.d(
                              "[ListView] More icon tapped for ${transcription.localFilePath}",
                            );
                            // TODO: Update _showRecordingOptions to accept Transcription or path
                            // For now, casting to AudioRecord will fail, need to adjust options logic
                            // _showRecordingOptions(context, transcription); // This will fail
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Options not implemented yet.'),
                              ),
                            );
                          },
                        ),
                      ),
                      // Integrate the AudioPlayerWidget for playback controls
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          bottom: 8.0,
                        ),
                        child: AudioPlayerWidget(
                          key: ValueKey(
                            transcription.localFilePath,
                          ), // Add key for state management
                          filePath: transcription.localFilePath,
                          onDelete: () {
                            context.read<AudioListCubit>().deleteRecording(
                              transcription.localFilePath,
                            );
                          },
                          isPlaying: itemIsPlaying,
                          isLoading: itemIsLoading,
                          currentPosition: itemPosition,
                          totalDuration:
                              displayDuration, // Pass displayDuration
                          error: itemError,
                          // Pass canSeek explicitly? No, widget calculates it internally based on props
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
            logger.w(
              "[AudioRecorderListView] Builder: Received unexpected state: ${state.runtimeType}",
            );
            // Show loading or an empty message as a fallback
            return const Center(
              child: Text('Initializing or unexpected state...'),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAudioRecorderPage(context),
        tooltip: 'New Recording',
        child: const Icon(Icons.add),
      ),
    );
  }
}
