import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// import '../../../../core/di/injection_container.dart'; // REMOVED sl import
import '../cubit/audio_recorder_cubit.dart';
import '../cubit/audio_recorder_state.dart';

class AudioRecorderPage extends StatelessWidget {
  final AudioRecord? appendTo;

  const AudioRecorderPage({super.key, this.appendTo});

  @override
  Widget build(BuildContext context) {
    // ADDED Debug Print
    debugPrint(
      '[AudioRecorderPage ${identityHashCode(this)}] build() called. appendTo: ${appendTo?.createdAt.toIso8601String()}',
    );
    return AudioRecorderView(appendTo: appendTo);
  }
}

class AudioRecorderView extends StatefulWidget {
  final AudioRecord? appendTo;

  const AudioRecorderView({super.key, this.appendTo});

  @override
  State<AudioRecorderView> createState() => _AudioRecorderViewState();
}

class _AudioRecorderViewState extends State<AudioRecorderView> {
  // bool _isNavigating = false; // REMOVED
  // late final AudioRecorderCubit _cubit; // REMOVED Cubit field

  @override
  void initState() {
    super.initState();
    // ADDED Debug Print
    debugPrint(
      '[AudioRecorderView ${identityHashCode(this)}] initState() called. appendTo: ${widget.appendTo?.createdAt.toIso8601String()}',
    );
    // ADDED: Call prepareRecorder on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint(
          '[AudioRecorderView ${identityHashCode(this)}] initState: Calling prepareRecorder().',
        );
        context.read<AudioRecorderCubit>().prepareRecorder();
      }
    });

    // REMOVED the redundant checkPermission call. Permission should be handled
    // by the list page before navigating here.
    /*
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final initialState = context.read<AudioRecorderCubit>().state;
        debugPrint(
          '[AudioRecorderPage] initState: Initial state received: ${initialState.runtimeType}',
        );
        // context.read<AudioRecorderCubit>().checkPermission(); // REMOVED
        debugPrint('[AudioRecorderPage] initState: checkPermission() called.'); // REMOVED
      }
    });
    */
  }

  // Method to show the permission request bottom sheet
  void _showPermissionSheet(BuildContext context) {
    // ADDED Debug Print
    debugPrint(
      '[AudioRecorderView ${identityHashCode(this)}] _showPermissionSheet() called.',
    );
    showModalBottomSheet(
      context: context,
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
                    context
                        .read<AudioRecorderCubit>()
                        .openAppSettings(); // Use context.read
                  },
                ),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(sheetContext).pop(),
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
    // REMOVED PopScope wrapper
    // ADDED Debug Print
    debugPrint('[AudioRecorderView ${identityHashCode(this)}] build() called.');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.appendTo != null ? 'Append Recording' : 'Record Audio',
        ),
        // Use default back button behavior or simple pop
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(), // Simple pop
        ),
      ),
      body: BlocConsumer<AudioRecorderCubit, AudioRecorderState>(
        listener: (context, state) {
          debugPrint(
            '[AudioRecorderView ${identityHashCode(this)}] Listener received state: ${state.runtimeType} (State Hash: ${identityHashCode(state)})', // Enhanced log
          );
          if (state is AudioRecorderError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is AudioRecorderPermissionDenied) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                debugPrint(
                  '[AudioRecorderView ${identityHashCode(this)}] Listener: Scheduling _showPermissionSheet for PermissionDenied state.',
                ); // Enhanced log
                _showPermissionSheet(context);
              }
            });
          } else if (state is AudioRecorderStopped) {
            debugPrint(
              '[AudioRecorderView ${identityHashCode(this)}] Listener: Received AudioRecorderStopped. Navigating back.', // Enhanced log
            );
            // Directly pop with result when recording stops successfully
            // No need for _isNavigating flag or addPostFrameCallback here
            if (mounted) {
              // Ensure widget is still mounted before popping
              Navigator.of(context).pop(true);
            }
          }
        },
        builder: (context, state) {
          // More detailed logging for ALL states
          debugPrint(
            '[AudioRecorderView ${identityHashCode(this)}] Builder received state: ${state.runtimeType} (State Hash: ${identityHashCode(state)})', // Enhanced log
          );

          Widget mainContent;
          if (state is AudioRecorderInitial) {
            debugPrint(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is Initial. Building Loading UI.',
            ); // Enhanced log
            mainContent = _buildLoadingUI(); // Show loading for initial too
          } else if (state is AudioRecorderLoading) {
            debugPrint(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is Loading. Building Loading UI.',
            ); // Enhanced log
            mainContent = _buildLoadingUI();
          } else if (state is AudioRecorderReady) {
            debugPrint(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is Ready. Building Ready UI.',
            ); // Enhanced log
            mainContent = _buildReadyUI(context);
          } else if (state is AudioRecorderRecording ||
              state is AudioRecorderPaused) {
            debugPrint(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is ${state.runtimeType}. Building Recording/Paused UI.',
            ); // Enhanced log
            mainContent = _buildRecordingPausedUI(context, state);
          } else if (state is AudioRecorderStopped) {
            debugPrint(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is Stopped. Building Loading UI.',
            ); // Enhanced log
            mainContent = _buildLoadingUI();
          } else if (state is AudioRecorderPermissionDenied) {
            debugPrint(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is PermissionDenied. Building minimal text (sheet shown by listener).',
            ); // Enhanced log
            // Listener handles showing the sheet, builder can show minimal info or loading
            mainContent = const Center(child: Text('Permission Required'));
          } else if (state is AudioRecorderError) {
            debugPrint(
              '[AudioRecorderView ${identityHashCode(this)}] Builder: State is Error. Building error text.',
            ); // Enhanced log
            // Listener shows snackbar, builder shows simple message
            mainContent = Center(child: Text('Error: ${state.message}'));
          } else {
            // Catch-all for unexpected states
            debugPrint(
              '[AudioRecorderView ${identityHashCode(this)}] Builder received UNHANDLED state: ${state.runtimeType}. Showing empty box.',
            );
            // ADDED: Include state name in fallback text for easier debugging
            mainContent = Center(
              child: Text('Unhandled State: ${state.runtimeType}'),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.appendTo != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Appending to recording from ${widget.appendTo!.createdAt.toIso8601String()}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                const SizedBox(height: 16), // Consistent spacing
                // --- Main Content Area based on State ---
                mainContent, // Use the determined widget
                // Note: AudioRecorderPermissionDenied is handled by the bottom sheet listener
              ],
            ),
          );
        },
      ),
    );
  }

  // --- START: New UI Builder Methods ---

  Widget _buildLoadingUI() {
    // ADDED Debug Print
    debugPrint(
      '[AudioRecorderView ${identityHashCode(this)}] _buildLoadingUI() called.',
    );
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Processing...'), // More generic message
      ],
    );
  }

  Widget _buildReadyUI(BuildContext context) {
    // ADDED Debug Print
    debugPrint(
      '[AudioRecorderView ${identityHashCode(this)}] _buildReadyUI() called.',
    );
    // Use context.read here
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.mic),
        label: Text(
          widget.appendTo != null
              ? 'Append Not Supported Yet'
              : 'Start Recording', // Indicate append is not ready
        ),
        onPressed:
            widget.appendTo != null
                ? null // Disable button if appendTo is set (temporary)
                : () {
                  context
                      .read<AudioRecorderCubit>()
                      .startRecording(); // Always start new for now
                },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          backgroundColor:
              widget.appendTo != null
                  ? Colors.grey
                  : null, // Grey out if append
        ),
      ),
    );
  }

  Widget _buildRecordingPausedUI(
    BuildContext context,
    AudioRecorderState state,
  ) {
    // ADDED Debug Print
    debugPrint(
      '[AudioRecorderView ${identityHashCode(this)}] _buildRecordingPausedUI() called with state: ${state.runtimeType}.',
    );
    // final recordState = state as AudioRecordState; // REMOVED INCORRECT CAST
    final isRecording = state is AudioRecorderRecording;

    // Access duration directly from state (exists on both Recording and Paused)
    Duration currentDuration = Duration.zero;
    if (state is AudioRecorderRecording) {
      currentDuration = state.duration;
    } else if (state is AudioRecorderPaused) {
      currentDuration = state.duration;
    }

    // Use context.read here
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatDuration(currentDuration), // Use the extracted duration
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pause/Resume Button
            ElevatedButton(
              onPressed: () {
                if (isRecording) {
                  context
                      .read<AudioRecorderCubit>()
                      .pauseRecording(); // Use context.read
                } else {
                  context
                      .read<AudioRecorderCubit>()
                      .resumeRecording(); // Use context.read
                }
              },
              child: Icon(isRecording ? Icons.pause : Icons.play_arrow),
            ),
            const SizedBox(width: 20),
            // Stop Button
            ElevatedButton(
              onPressed:
                  () =>
                      context
                          .read<AudioRecorderCubit>()
                          .stopRecording(), // Use context.read
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Icon(Icons.stop),
            ),
          ],
        ),
      ],
    );
  }

  // --- END: New UI Builder Methods ---
}
