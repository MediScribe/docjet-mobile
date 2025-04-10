import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Import the correct Cubit and State
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_cubit.dart';
import 'package:docjet_mobile/features/audio_recorder/presentation/cubit/audio_recording_state.dart';

// ADD THIS IMPORT
import 'package:logger/logger.dart';

final logger = Logger();

// Remove old imports
// import '../cubit/audio_recorder_cubit.dart';
// import '../cubit/audio_recorder_state.dart';
// Removed unused domain entity import
// import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';

class AudioRecorderPage extends StatelessWidget {
  // Remove appendTo parameter
  // final AudioRecord? appendTo;

  // Updated constructor
  const AudioRecorderPage({super.key});

  @override
  Widget build(BuildContext context) {
    logger.d('[AudioRecorderPage ${identityHashCode(this)}] build() called.');
    // Remove appendTo parameter from view
    return const AudioRecorderView();
  }
}

class AudioRecorderView extends StatefulWidget {
  // Remove appendTo parameter
  // final AudioRecord? appendTo;

  // Updated constructor
  const AudioRecorderView({super.key});

  @override
  State<AudioRecorderView> createState() => _AudioRecorderViewState();
}

class _AudioRecorderViewState extends State<AudioRecorderView> {
  @override
  void initState() {
    super.initState();
    logger.d(
      '[AudioRecorderView ${identityHashCode(this)}] initState() called.',
    );
    // Call prepareRecorder on the correct Cubit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        logger.d(
          '[AudioRecorderView ${identityHashCode(this)}] initState: Calling prepareRecorder().',
        );
        context
            .read<AudioRecordingCubit>()
            .prepareRecorder(); // Use AudioRecordingCubit
      }
    });
  }

  // Method to show the permission request bottom sheet
  void _showPermissionSheet(BuildContext context) {
    logger.d(
      '[AudioRecorderView ${identityHashCode(this)}] _showPermissionSheet() called.',
    );
    showModalBottomSheet(
      context: context,
      isDismissible: false, // Prevent dismissing by tapping outside
      enableDrag: false, // Prevent dragging down
      builder:
          (sheetContext) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Microphone Permission Required',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This app needs access to your microphone to record audio. Please grant permission in the app settings.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  child: const Text('Open App Settings'),
                  onPressed: () {
                    Navigator.of(sheetContext).pop(); // Close the sheet
                    // Use the correct Cubit
                    context.read<AudioRecordingCubit>().openAppSettings();
                  },
                ),
                TextButton(
                  child: const Text('Maybe Later'), // Changed from Cancel
                  onPressed: () {
                    Navigator.of(sheetContext).pop(); // Close sheet
                    // Optionally pop the recorder page itself if user declines settings
                    if (mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    logger.d('[AudioRecorderView ${identityHashCode(this)}] build() called.');
    return Scaffold(
      appBar: AppBar(
        // Simplified title
        title: const Text('Record Audio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // Use the correct Cubit and State types
      body: BlocConsumer<AudioRecordingCubit, AudioRecordingState>(
        listener: (context, state) {
          logger.d(
            '[AudioRecorderView ${identityHashCode(this)}] Listener received state: ${state.runtimeType} (State Hash: ${identityHashCode(state)})',
          );
          // Use new state names
          if (state is AudioRecordingError) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text("Recorder Error: ${state.message}")),
              );
          } else if (state is AudioRecordingPermissionDenied) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                logger.d(
                  '[AudioRecorderView ${identityHashCode(this)}] Listener: Scheduling _showPermissionSheet for PermissionDenied state.',
                );
                _showPermissionSheet(context);
              }
            });
            // Use new state name for stopped state
          } else if (state is AudioRecordingStopped) {
            logger.i(
              '[AudioRecorderView ${identityHashCode(this)}] Listener: Received AudioRecordingStopped. Navigating back with result=true.',
            );
            if (mounted) {
              // Pop with true to signal success to the list page
              Navigator.of(context).pop(true);
            }
          }
        },
        builder: (context, state) {
          logger.d(
            '[AudioRecorderView ${identityHashCode(this)}] Builder received state: ${state.runtimeType} (State Hash: ${identityHashCode(state)})',
          );

          Widget mainContent;
          // Use new state names
          if (state is AudioRecordingInitial) {
            logger.d(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is Initial.',
            );
            mainContent = _buildLoadingUI("Initializing...");
          } else if (state is AudioRecordingLoading) {
            logger.d(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is Loading.',
            );
            mainContent = _buildLoadingUI("Loading...");
          } else if (state is AudioRecordingReady) {
            logger.d(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is Ready.',
            );
            mainContent = _buildReadyUI(context);
            // Use new state names
          } else if (state is AudioRecordingInProgress ||
              state is AudioRecordingPaused) {
            logger.d(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is ${state.runtimeType}.',
            );
            mainContent = _buildRecordingPausedUI(context, state);
            // Use new state name. Builder should not handle Stopped UI, just show loading briefly.
          } else if (state is AudioRecordingStopped) {
            logger.d(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is Stopped. Showing Loading UI briefly before pop.',
            );
            mainContent = _buildLoadingUI(
              "Saving...",
            ); // Show loading while listener pops
          } else if (state is AudioRecordingPermissionDenied) {
            logger.d(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is PermissionDenied.',
            );
            // Listener shows sheet, builder shows minimal text
            mainContent = const Center(child: Text('Permission Required'));
            // Use new state name
          } else if (state is AudioRecordingError) {
            logger.d(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is Error.',
            );
            // Listener shows snackbar, builder shows simple message + retry?
            mainContent = Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: ${state.message}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed:
                        () =>
                            context
                                .read<AudioRecordingCubit>()
                                .prepareRecorder(),
                    child: const Text('Retry Init'),
                  ),
                ],
              ),
            );
          } else {
            logger.w(
              '[AudioRecorderView ${identityHashCode(this)}] Builder received UNHANDLED state: ${state.runtimeType}.',
            );
            mainContent = Center(
              child: Text('Unhandled State: ${state.runtimeType}'),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Removed appendTo Text
                const SizedBox(height: 16),
                mainContent,
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI Builder Methods ---

  // Updated loading UI to accept a message
  Widget _buildLoadingUI(String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Widget _buildReadyUI(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mic_none, size: 64, color: Colors.grey),
        const SizedBox(height: 24),
        const Text('Ready to Record', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 40),
        FloatingActionButton.large(
          tooltip: 'Start Recording',
          onPressed:
              () =>
                  context
                      .read<AudioRecordingCubit>()
                      .startRecording(), // Use correct cubit
          child: const Icon(Icons.mic, size: 48),
        ),
      ],
    );
  }

  // Updated method to handle both RecordingInProgress and Paused states
  Widget _buildRecordingPausedUI(
    BuildContext context,
    AudioRecordingState state,
  ) {
    // Determine duration and file path from the specific state type
    Duration currentDuration = Duration.zero;
    String currentPath = "";
    bool isPaused = false;

    if (state is AudioRecordingInProgress) {
      currentDuration = state.duration;
      currentPath = state.filePath;
      isPaused = false;
    } else if (state is AudioRecordingPaused) {
      currentDuration = state.duration;
      currentPath = state.filePath;
      isPaused = true;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatDuration(currentDuration),
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // Optionally display the current file path (useful for debugging)
        Text(
          currentPath.split('/').last, // Show only filename
          style: Theme.of(context).textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pause/Resume Button
            FloatingActionButton(
              heroTag: 'pause_resume_fab',
              tooltip: isPaused ? 'Resume Recording' : 'Pause Recording',
              onPressed:
                  isPaused
                      ? () =>
                          context
                              .read<AudioRecordingCubit>()
                              .resumeRecording() // Use correct cubit
                      : () =>
                          context
                              .read<AudioRecordingCubit>()
                              .pauseRecording(), // Use correct cubit
              child: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            ),
            const SizedBox(width: 24),
            // Stop Button
            FloatingActionButton(
              heroTag: 'stop_fab',
              backgroundColor: Colors.red,
              tooltip: 'Stop Recording',
              onPressed: () async {
                // Call stop on the correct cubit
                // No need to check result here, listener handles navigation
                await context.read<AudioRecordingCubit>().stopRecording();
              },
              child: const Icon(Icons.stop),
            ),
          ],
        ),
      ],
    );
  }
}
