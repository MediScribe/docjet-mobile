import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/audio_recorder_cubit.dart';
import '../cubit/audio_recorder_state.dart';
import '../widgets/audio_player_widget.dart';

class AudioRecorderPage extends StatelessWidget {
  final AudioRecordState? appendTo;

  const AudioRecorderPage({super.key, this.appendTo});

  @override
  Widget build(BuildContext context) {
    return AudioRecorderView(appendTo: appendTo);
  }
}

class AudioRecorderView extends StatefulWidget {
  final AudioRecordState? appendTo;

  const AudioRecorderView({super.key, this.appendTo});

  @override
  State<AudioRecorderView> createState() => _AudioRecorderViewState();
}

class _AudioRecorderViewState extends State<AudioRecorderView> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    context.read<AudioRecorderCubit>().checkPermission();
  }

  // Method to show the permission request bottom sheet
  void _showPermissionSheet(BuildContext context) {
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
                    context.read<AudioRecorderCubit>().openSettings();
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

  void _handleNavigation(BuildContext context) {
    if (!_isNavigating) {
      _isNavigating = true;

      // Force refresh the recordings list
      final cubit = context.read<AudioRecorderCubit>();
      cubit.loadRecordings();

      // Return true to indicate success
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        _handleNavigation(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.appendTo != null ? 'Append Recording' : 'Record Audio',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleNavigation(context),
          ),
        ),
        body: BlocConsumer<AudioRecorderCubit, AudioRecorderState>(
          listener: (context, state) {
            if (state is AudioRecorderError) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            } else if (state is AudioRecorderPermissionDenied) {
              // Show the bottom sheet instead of just a snackbar
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  // Ensure widget is still in the tree
                  _showPermissionSheet(context);
                }
              });
              // _handleNavigation(context); // Ensure this is still removed
            } else if (state is AudioRecorderStopped) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _handleNavigation(context);
                }
              });
            }
          },
          builder: (context, state) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.appendTo != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Appending to recording from ${widget.appendTo!.createdAt.toString()}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  const SizedBox(height: 16), // Consistent spacing
                  // --- Main Content Area based on State ---
                  if (state is AudioRecorderInitial ||
                      state is AudioRecorderLoading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Checking permissions...'),
                  ] else if (state is AudioRecorderReady) ...[
                    // Show only the initial record button
                    _buildRecordButton(context, state),
                  ] else if (state is AudioRecorderRecording ||
                      state is AudioRecorderPaused) ...[
                    // Show timer and active controls
                    Text(
                      _formatDuration(
                        state is AudioRecorderRecording
                            ? state.duration
                            : (state as AudioRecorderPaused).duration,
                      ),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRecordButton(context, state), // Stop button
                        const SizedBox(width: 16),
                        _buildPauseResumeButton(context, state),
                      ],
                    ),
                  ] else if (state is AudioRecorderStopped) ...[
                    // Show playback widget and Done button
                    const Text('Recording Complete'), // Simple title
                    const SizedBox(height: 16),
                    AudioPlayerWidget(
                      filePath: state.record.filePath,
                      onDelete: () {
                        context.read<AudioRecorderCubit>().deleteRecording(
                          state.record.filePath,
                        );
                        // Maybe navigate back automatically after delete?
                        // _handleNavigation(context);
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _handleNavigation(context),
                      child: const Text('Done'),
                    ),
                  ],
                  // Note: AudioRecorderPermissionDenied is handled by the bottom sheet
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecordButton(BuildContext context, AudioRecorderState state) {
    final isRecording = state is AudioRecorderRecording;
    final isPaused = state is AudioRecorderPaused;

    return FloatingActionButton(
      heroTag: 'record_fab',
      onPressed: () {
        if (isRecording || isPaused) {
          context.read<AudioRecorderCubit>().stopRecording();
        } else {
          context.read<AudioRecorderCubit>().startRecording(
            appendTo: widget.appendTo,
          );
        }
      },
      backgroundColor: isRecording || isPaused ? Colors.red : null,
      child: Icon(isRecording || isPaused ? Icons.stop : Icons.mic),
    );
  }

  Widget _buildPauseResumeButton(
    BuildContext context,
    AudioRecorderState state,
  ) {
    final isRecording = state is AudioRecorderRecording;

    return FloatingActionButton(
      heroTag: 'pause_resume_fab',
      onPressed: () {
        if (isRecording) {
          context.read<AudioRecorderCubit>().pauseRecording();
        } else {
          context.read<AudioRecorderCubit>().resumeRecording();
        }
      },
      child: Icon(isRecording ? Icons.pause : Icons.play_arrow),
    );
  }
}
